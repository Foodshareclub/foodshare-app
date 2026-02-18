//
//  ChatPresenceService.swift
//  Foodshare
//
//  Real-time presence service for chat features
//  Supports typing indicators and online/offline status
//


#if !SKIP
import Foundation
@preconcurrency import Realtime
import Supabase

// MARK: - Presence State

/// User presence state for chat rooms
struct UserPresence: Codable, Sendable, Equatable {
    let userId: UUID
    let isTyping: Bool
    let lastSeenAt: Date

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case isTyping = "is_typing"
        case lastSeenAt = "last_seen_at"
    }

    // Custom decoding to handle the nested presence structure
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode UUID directly, or from string
        if let uuid = try? container.decode(UUID.self, forKey: .userId) {
            userId = uuid
        } else if let uuidString = try? container.decode(String.self, forKey: .userId),
                  let uuid = UUID(uuidString: uuidString) {
            userId = uuid
        } else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [CodingKeys.userId], debugDescription: "Invalid UUID"),
            )
        }

        // Decode isTyping from bool or string
        if let typing = try? container.decode(Bool.self, forKey: .isTyping) {
            isTyping = typing
        } else if let typingString = try? container.decode(String.self, forKey: .isTyping) {
            isTyping = typingString == "true"
        } else {
            isTyping = false
        }

        // Decode date from Date or string
        if let date = try? container.decode(Date.self, forKey: .lastSeenAt) {
            lastSeenAt = date
        } else if let dateString = try? container.decode(String.self, forKey: .lastSeenAt),
                  let date = ISO8601DateFormatter().date(from: dateString) {
            lastSeenAt = date
        } else {
            lastSeenAt = Date()
        }
    }

    init(userId: UUID, isTyping: Bool = false, lastSeenAt: Date = Date()) {
        self.userId = userId
        self.isTyping = isTyping
        self.lastSeenAt = lastSeenAt
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(isTyping, forKey: .isTyping)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
    }
}

/// Online status for a user
enum OnlineStatus: Sendable {
    case online
    case away
    case offline

    var displayColor: String {
        switch self {
        case .online: "success"
        case .away: "warning"
        case .offline: "textTertiary"
        }
    }
}

// MARK: - Presence Service Protocol

/// Protocol for chat presence operations
protocol ChatPresenceService: Sendable {
    /// Join a chat room's presence channel
    func joinRoom(roomId: UUID, userId: UUID) async throws

    /// Leave a chat room's presence channel
    func leaveRoom() async

    /// Update typing status
    func setTyping(_ isTyping: Bool) async throws

    /// Get presence updates as an async stream
    func presenceUpdates() async -> AsyncStream<[UserPresence]>

    /// Check if a specific user is typing
    func isUserTyping(_ userId: UUID) async -> Bool

    /// Get online status for a user based on last seen
    func onlineStatus(for userId: UUID) async -> OnlineStatus
}

// MARK: - Supabase Implementation

/// Supabase Realtime Presence implementation for chat
actor SupabaseChatPresenceService: ChatPresenceService {
    private let client: SupabaseClient
    private var channel: RealtimeChannelV2?
    private var currentRoomId: UUID?
    private var currentUserId: UUID?
    private var presenceState: [UserPresence] = []
    private var presenceContinuation: AsyncStream<[UserPresence]>.Continuation?
    private var typingDebounceTask: Task<Void, Never>?

    init(client: SupabaseClient) {
        self.client = client
    }

    deinit {
        typingDebounceTask?.cancel()
    }

    func joinRoom(roomId: UUID, userId: UUID) async throws {
        // Leave existing room first
        await leaveRoom()

        currentRoomId = roomId
        currentUserId = userId

        // Create presence channel for this room
        let channelName = "chat_presence:\(roomId.uuidString)"
        let channel = client.realtimeV2.channel(channelName)

        // Track presence with string values (Supabase requirement)
        try await channel.track([
            "user_id": userId.uuidString,
            "is_typing": "false",
            "last_seen_at": ISO8601DateFormatter().string(from: Date())
        ])

        // Subscribe to presence changes
        let presenceChanges = channel.presenceChange()

        try await channel.subscribeWithError()
        self.channel = channel

        // Handle presence updates in background
        Task { [weak self] in
            for await change in presenceChanges {
                await self?.handlePresenceChange(change)
            }
        }

        await AppLogger.shared.debug("Joined presence channel for room: \(roomId)")
    }

    func leaveRoom() async {
        typingDebounceTask?.cancel()
        typingDebounceTask = nil

        if let channel {
            await channel.untrack()
            await channel.unsubscribe()
        }
        channel = nil
        currentRoomId = nil
        currentUserId = nil
        presenceState = []
        presenceContinuation?.finish()
        presenceContinuation = nil
    }

    func setTyping(_ isTyping: Bool) async throws {
        guard currentUserId != nil else { return }

        // Cancel any pending debounce
        typingDebounceTask?.cancel()

        // Update presence immediately for typing start
        if isTyping {
            try await updatePresence(isTyping: true)

            // Auto-stop typing after 3 seconds of inactivity
            typingDebounceTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard !Task.isCancelled else { return }
                try? await self?.updatePresence(isTyping: false)
            }
        } else {
            // Stop typing
            try await updatePresence(isTyping: false)
        }
    }

    private func updatePresence(isTyping: Bool) async throws {
        guard let userId = currentUserId, let channel else { return }

        try await channel.track([
            "user_id": userId.uuidString,
            "is_typing": isTyping ? "true" : "false",
            "last_seen_at": ISO8601DateFormatter().string(from: Date())
        ])
    }

    func presenceUpdates() async -> AsyncStream<[UserPresence]> {
        let currentState = presenceState
        return AsyncStream { [weak self] continuation in
            Task { [weak self] in
                await self?.setContinuation(continuation)
            }

            // Send initial state
            continuation.yield(currentState)

            continuation.onTermination = { @Sendable [weak self] _ in
                Task { [weak self] in
                    await self?.clearContinuation()
                }
            }
        }
    }

    private func setContinuation(_ continuation: AsyncStream<[UserPresence]>.Continuation) {
        presenceContinuation = continuation
    }

    private func clearContinuation() {
        presenceContinuation = nil
    }

    func isUserTyping(_ userId: UUID) async -> Bool {
        presenceState.first { $0.userId == userId }?.isTyping ?? false
    }

    func onlineStatus(for userId: UUID) async -> OnlineStatus {
        guard let presence = presenceState.first(where: { $0.userId == userId }) else {
            return .offline
        }

        let timeSinceLastSeen = Date().timeIntervalSince(presence.lastSeenAt)

        if timeSinceLastSeen < 60 { // Active in last minute
            return .online
        } else if timeSinceLastSeen < 300 { // Active in last 5 minutes
            return .away
        } else {
            return .offline
        }
    }

    // MARK: - Private

    private func handlePresenceChange(_ change: any PresenceAction) async {
        // Parse presence from the change events
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var newPresences: [UserPresence] = []

        // Handle join events
        let joins = change.joins
        for (_, presenceData) in joins {
            // PresenceV2.state is a JSONObject (Dictionary<String, AnyJSON>)
            let stateDict = presenceData.state
            // Convert AnyJSON values to basic types for JSONSerialization
            var convertedDict: [String: Any] = [:]
            for (key, value) in stateDict {
                convertedDict[key] = value.value
            }
            if let data = try? JSONSerialization.data(withJSONObject: convertedDict),
               let userPresence = try? decoder.decode(UserPresence.self, from: data) {
                newPresences.append(userPresence)
            }
        }

        // Update current presence state
        // Merge new presences with existing, replacing by userId
        for newPresence in newPresences {
            presenceState.removeAll { $0.userId == newPresence.userId }
            presenceState.append(newPresence)
        }

        // Handle leave events
        let leaves = change.leaves
        for (_, presenceData) in leaves {
            let stateDict = presenceData.state
            var convertedDict: [String: Any] = [:]
            for (key, value) in stateDict {
                convertedDict[key] = value.value
            }
            if let data = try? JSONSerialization.data(withJSONObject: convertedDict),
               let userPresence = try? decoder.decode(UserPresence.self, from: data) {
                presenceState.removeAll { $0.userId == userPresence.userId }
            }
        }

        presenceContinuation?.yield(presenceState)
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
    final class MockChatPresenceService: ChatPresenceService, @unchecked Sendable {
        nonisolated(unsafe) var mockPresences: [UserPresence] = []
        nonisolated(unsafe) var didJoinRoom = false
        nonisolated(unsafe) var isTypingValue = false

        func joinRoom(roomId: UUID, userId: UUID) async throws {
            didJoinRoom = true
        }

        func leaveRoom() async {
            didJoinRoom = false
        }

        func setTyping(_ isTyping: Bool) async throws {
            isTypingValue = isTyping
        }

        func presenceUpdates() async -> AsyncStream<[UserPresence]> {
            let presences = mockPresences
            return AsyncStream { continuation in
                continuation.yield(presences)
            }
        }

        func isUserTyping(_ userId: UUID) async -> Bool {
            mockPresences.first { $0.userId == userId }?.isTyping ?? false
        }

        func onlineStatus(for userId: UUID) async -> OnlineStatus {
            .online
        }
    }
#endif

#endif
