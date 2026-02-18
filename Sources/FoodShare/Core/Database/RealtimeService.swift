

#if !SKIP
#if !SKIP
import Combine
#endif
import Foundation
import OSLog
@preconcurrency import Realtime
import Supabase

/// Protocol for real-time database subscriptions
protocol RealtimeService: Sendable {
    /// Subscribe to changes in a table
    func subscribe<T: Decodable & Sendable>(
        to table: String,
        filter: String?,
        onChange: @escaping @Sendable (RealtimeChange<T>) -> Void,
    ) async throws -> RealtimeChannelV2

    /// Unsubscribe from a channel
    func unsubscribe(from channel: RealtimeChannelV2) async
}

/// Real-time change event
enum RealtimeChange<T: Sendable>: Sendable {
    case insert(T)
    case update(T)
    case delete(UUID)
}

// MARK: - Realtime Channel Manager

/// Centralized manager for all realtime channel subscriptions
/// Ensures proper lifecycle management and cleanup of channels
actor RealtimeChannelManager {
    static let shared = RealtimeChannelManager()

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "RealtimeChannelManager")

    /// Active channels keyed by unique identifier
    private var channels: [String: ManagedChannel] = [:]

    /// Track channel creation timestamps for debugging
    private var channelCreatedAt: [String: Date] = [:]

    /// Holds channel reference with associated metadata
    struct ManagedChannel: Sendable {
        let channel: RealtimeChannelV2
        let table: String
        let filter: String?
        let subscribedAt: Date

        var identifier: String {
            filter.map { "\(table):\($0)" } ?? table
        }
    }

    private init() {}

    // MARK: - Channel Registration

    /// Register a channel for lifecycle tracking
    func register(
        channel: RealtimeChannelV2,
        table: String,
        filter: String?,
    ) {
        let identifier = filter.map { "\(table):\($0)" } ?? table
        let managed = ManagedChannel(
            channel: channel,
            table: table,
            filter: filter,
            subscribedAt: Date(),
        )
        channels[identifier] = managed
        channelCreatedAt[identifier] = Date()
        logger.info("Registered channel: \(identifier)")
    }

    /// Get existing channel if already subscribed
    func existingChannel(table: String, filter: String?) -> RealtimeChannelV2? {
        let identifier = filter.map { "\(table):\($0)" } ?? table
        return channels[identifier]?.channel
    }

    /// Unregister a specific channel
    func unregister(channel: RealtimeChannelV2) {
        let channelId = ObjectIdentifier(channel)
        if let key = channels.first(where: { ObjectIdentifier($0.value.channel) == channelId })?.key {
            channels.removeValue(forKey: key)
            channelCreatedAt.removeValue(forKey: key)
            logger.info("Unregistered channel: \(key)")
        }
    }

    /// Unregister channel by identifier
    func unregister(table: String, filter: String?) {
        let identifier = filter.map { "\(table):\($0)" } ?? table
        channels.removeValue(forKey: identifier)
        channelCreatedAt.removeValue(forKey: identifier)
        logger.info("Unregistered channel: \(identifier)")
    }

    // MARK: - Cleanup

    /// Unsubscribe and remove all channels
    func unsubscribeAll(using client: SupabaseClient) async {
        logger.info("Unsubscribing from all \(self.channels.count) channels")
        for (identifier, managed) in channels {
            await client.removeChannel(managed.channel)
            logger.debug("Removed channel: \(identifier)")
        }
        channels.removeAll()
        channelCreatedAt.removeAll()
    }

    /// Cleanup stale channels (subscribed longer than maxAge)
    func cleanupStaleChannels(maxAge: TimeInterval, using client: SupabaseClient) async {
        let now = Date()
        var staleKeys: [String] = []

        for (key, managed) in channels {
            if now.timeIntervalSince(managed.subscribedAt) > maxAge {
                staleKeys.append(key)
            }
        }

        for key in staleKeys {
            if let managed = channels[key] {
                await client.removeChannel(managed.channel)
                channels.removeValue(forKey: key)
                channelCreatedAt.removeValue(forKey: key)
                logger.info("Cleaned up stale channel: \(key)")
            }
        }
    }

    // MARK: - Diagnostics

    /// Get count of active channels
    var activeChannelCount: Int {
        channels.count
    }

    /// Get list of active channel identifiers
    var activeChannelIdentifiers: [String] {
        Array(channels.keys)
    }

    /// Get channel statistics for debugging
    func getStatistics() -> ChannelStatistics {
        let now = Date()
        var totalAge: TimeInterval = 0
        var oldestAge: TimeInterval = 0

        for managed in channels.values {
            let age = now.timeIntervalSince(managed.subscribedAt)
            totalAge += age
            oldestAge = max(oldestAge, age)
        }

        return ChannelStatistics(
            activeCount: channels.count,
            averageAge: channels.isEmpty ? 0 : totalAge / Double(channels.count),
            oldestAge: oldestAge,
            channelIdentifiers: Array(channels.keys),
        )
    }

    struct ChannelStatistics: Sendable {
        let activeCount: Int
        let averageAge: TimeInterval
        let oldestAge: TimeInterval
        let channelIdentifiers: [String]
    }
}

/// Supabase implementation of RealtimeService
/// Uses RealtimeChannelManager for centralized lifecycle management
actor SupabaseRealtimeService: RealtimeService {
    private let client: SupabaseClient
    private let channelManager: RealtimeChannelManager
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "RealtimeService")

    init(client: SupabaseClient, channelManager: RealtimeChannelManager = .shared) {
        self.client = client
        self.channelManager = channelManager
    }

    func subscribe<T: Decodable & Sendable>(
        to table: String,
        filter: String? = nil,
        onChange: @escaping @Sendable (RealtimeChange<T>) -> Void,
    ) async throws -> RealtimeChannelV2 {
        let channelName = filter.map { "\(table):\($0)" } ?? table

        // Return existing channel if already subscribed (via centralized manager)
        if let existingChannel = await channelManager.existingChannel(table: table, filter: filter) {
            logger.debug("Reusing existing channel: \(channelName)")
            return existingChannel
        }

        let channel = client.channel(channelName)

        // Configure the channel to listen to changes
        let changeStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: table,
        )

        // Subscribe to the channel
        try await channel.subscribeWithError()

        // Register with centralized manager
        await channelManager.register(channel: channel, table: table, filter: filter)

        // Handle changes in a background task
        Task { [weak self] in
            for await change in changeStream {
                await self?.handleChange(change: change, onChange: onChange)
            }
        }

        logger.info("Subscribed to channel: \(channelName)")
        return channel
    }

    func unsubscribe(from channel: RealtimeChannelV2) async {
        await client.removeChannel(channel)
        await channelManager.unregister(channel: channel)
    }

    /// Unsubscribe from all channels (for app termination/logout)
    func unsubscribeAll() async {
        await channelManager.unsubscribeAll(using: client)
    }

    /// Cleanup stale channels older than specified age
    func cleanupStaleChannels(maxAge: TimeInterval = 3600) async {
        await channelManager.cleanupStaleChannels(maxAge: maxAge, using: client)
    }

    /// Get current channel statistics
    func getChannelStatistics() async -> RealtimeChannelManager.ChannelStatistics {
        await channelManager.getStatistics()
    }

    // MARK: - Private

    private func handleChange<T: Decodable & Sendable>(
        change: AnyAction,
        onChange: @escaping @Sendable (RealtimeChange<T>) -> Void,
    ) async {
        do {
            switch change {
            case let .insert(action):
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let data = try JSONSerialization.data(withJSONObject: action.record)
                let record = try decoder.decode(T.self, from: data)
                onChange(.insert(record))

            case let .update(action):
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .iso8601
                let data = try JSONSerialization.data(withJSONObject: action.record)
                let record = try decoder.decode(T.self, from: data)
                onChange(.update(record))

            case let .delete(action):
                // Extract ID from old record
                if let idValue = action.oldRecord["id"] {
                    // Handle AnyJSON type properly
                    let idString: String? = "\(idValue)"

                    if let idString,
                       let id = UUID(uuidString: idString) {
                        onChange(.delete(id))
                    }
                }

            @unknown default:
                // Handle any future cases
                break
            }
        } catch {
            await AppLogger.shared.error("Failed to handle realtime change", error: error)
        }
    }
}


#endif
