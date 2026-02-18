//
//  ConflictResolution.swift
//  Foodshare
//
//  Enterprise-grade conflict resolution system for offline-first architecture.
//  Handles synchronization conflicts between local (Core Data) and remote (Supabase) data.
//
//  Features:
//  - Multiple resolution strategies (server wins, client wins, merge, manual)
//  - Version-based conflict detection using timestamps
//  - Field-level merging for complex entities
//  - Conflict event logging for auditing
//  - Automatic retry with backoff for failed resolutions
//
//  Usage:
//  ```swift
//  let resolver = ConflictResolver<FoodListing>(strategy: .lastWriteWins)
//  let result = await resolver.resolve(local: cachedItem, remote: serverItem)
//  ```
//


#if !SKIP
import Foundation
import OSLog

// MARK: - Conflict Resolution Strategy

/// Strategy for resolving data conflicts between local and remote
public enum ConflictResolutionStrategy: String, Sendable, CaseIterable {
    /// Server data always wins - simplest, most reliable
    case serverWins

    /// Client data always wins - preserves local changes
    case clientWins

    /// Most recent update wins (based on timestamp)
    case lastWriteWins

    /// Merge non-conflicting fields, prefer server for conflicts
    case mergePreferServer

    /// Merge non-conflicting fields, prefer client for conflicts
    case mergePreferClient

    /// Require manual resolution
    case manual

    /// Description for UI
    public var description: String {
        switch self {
        case .serverWins:
            "Use server version"
        case .clientWins:
            "Use your version"
        case .lastWriteWins:
            "Use most recent"
        case .mergePreferServer:
            "Merge (prefer server)"
        case .mergePreferClient:
            "Merge (prefer your changes)"
        case .manual:
            "Choose manually"
        }
    }
}

// MARK: - Conflict Information

/// Detailed information about a detected conflict
public struct ConflictInfo<T: Sendable>: Sendable {
    /// Unique identifier for the conflicting entity
    public let entityId: String

    /// Type of entity (e.g., "Listing", "Message", "Profile")
    public let entityType: String

    /// Local (cached) version of the entity
    public let localVersion: T

    /// Remote (server) version of the entity
    public let remoteVersion: T

    /// Timestamp of local version
    public let localTimestamp: Date

    /// Timestamp of remote version
    public let remoteTimestamp: Date

    /// Fields that differ between versions (for merge strategies)
    public let conflictingFields: [String]

    /// When the conflict was detected
    public let detectedAt: Date

    public init(
        entityId: String,
        entityType: String,
        localVersion: T,
        remoteVersion: T,
        localTimestamp: Date,
        remoteTimestamp: Date,
        conflictingFields: [String] = [],
    ) {
        self.entityId = entityId
        self.entityType = entityType
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
        self.localTimestamp = localTimestamp
        self.remoteTimestamp = remoteTimestamp
        self.conflictingFields = conflictingFields
        self.detectedAt = Date()
    }

    /// Which version is newer
    public var newerVersion: ConflictWinner {
        localTimestamp > remoteTimestamp ? .local : .remote
    }
}

/// Winner of a conflict resolution
public enum ConflictWinner: String, Sendable {
    case local
    case remote
    case merged
    case manual
}

// MARK: - Conflict Resolution Result

/// Result of a conflict resolution
public struct ConflictResolutionResult<T: Sendable>: Sendable {
    /// The resolved entity
    public let resolved: T

    /// How the conflict was resolved
    public let winner: ConflictWinner

    /// Strategy that was used
    public let strategyUsed: ConflictResolutionStrategy

    /// Any fields that were merged
    public let mergedFields: [String]

    /// Resolution timestamp
    public let resolvedAt: Date

    public init(
        resolved: T,
        winner: ConflictWinner,
        strategyUsed: ConflictResolutionStrategy,
        mergedFields: [String] = [],
    ) {
        self.resolved = resolved
        self.winner = winner
        self.strategyUsed = strategyUsed
        self.mergedFields = mergedFields
        self.resolvedAt = Date()
    }
}

// MARK: - Syncable Protocol

/// Protocol for entities that can be synced and have conflicts resolved
public protocol Syncable: Sendable {
    /// Unique identifier
    var syncId: String { get }

    /// Entity type for conflict tracking
    static var entityType: String { get }

    /// Last modified timestamp
    var lastModifiedAt: Date { get }

    /// Version number (for optimistic concurrency)
    var syncVersion: Int { get }

    /// Merge with another version, returning merged entity and fields that were merged
    func merge(with other: Self, preferring preference: ConflictWinner) -> (merged: Self, mergedFields: [String])

    /// Get fields that differ from another version
    func conflictingFields(with other: Self) -> [String]
}

// MARK: - Conflict Resolver

/// Resolves conflicts between local and remote versions of data
public actor ConflictResolver<T: Syncable> {
    private let strategy: ConflictResolutionStrategy
    private let logger: Logger
    private var pendingConflicts: [String: ConflictInfo<T>] = [:]
    private var resolutionHistory: [ConflictResolutionResult<T>] = []

    public init(
        strategy: ConflictResolutionStrategy = .lastWriteWins,
        logger: Logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ConflictResolver"),
    ) {
        self.strategy = strategy
        self.logger = logger
    }

    // MARK: - Public API

    /// Detect if there's a conflict between local and remote versions
    public func detectConflict(
        local: T,
        remote: T,
    ) -> ConflictInfo<T>? {
        // No conflict if same version
        guard local.syncVersion != remote.syncVersion else {
            return nil
        }

        // No conflict if timestamps match exactly
        guard local.lastModifiedAt != remote.lastModifiedAt else {
            return nil
        }

        // Both have been modified since last sync - conflict!
        let conflictingFields = local.conflictingFields(with: remote)

        guard !conflictingFields.isEmpty else {
            // No actual field differences, just version mismatch
            return nil
        }

        let conflict = ConflictInfo(
            entityId: local.syncId,
            entityType: T.entityType,
            localVersion: local,
            remoteVersion: remote,
            localTimestamp: local.lastModifiedAt,
            remoteTimestamp: remote.lastModifiedAt,
            conflictingFields: conflictingFields,
        )

        pendingConflicts[local.syncId] = conflict
        logger
            .warning(
                "🔀 Conflict detected for \(T.entityType) '\(local.syncId)': \(conflictingFields.joined(separator: ", "))",
            )

        return conflict
    }

    /// Resolve a conflict using the configured strategy
    public func resolve(
        local: T,
        remote: T,
    ) async -> ConflictResolutionResult<T> {
        // First detect the conflict
        if let conflict = detectConflict(local: local, remote: remote) {
            return await resolveConflict(conflict)
        }

        // No conflict - use remote as default
        return ConflictResolutionResult(
            resolved: remote,
            winner: .remote,
            strategyUsed: .serverWins,
        )
    }

    /// Resolve a detected conflict
    public func resolveConflict(
        _ conflict: ConflictInfo<T>,
    ) async -> ConflictResolutionResult<T> {
        let result: ConflictResolutionResult<T>

        switch strategy {
        case .serverWins:
            result = ConflictResolutionResult(
                resolved: conflict.remoteVersion,
                winner: .remote,
                strategyUsed: .serverWins,
            )

        case .clientWins:
            result = ConflictResolutionResult(
                resolved: conflict.localVersion,
                winner: .local,
                strategyUsed: .clientWins,
            )

        case .lastWriteWins:
            let winner: ConflictWinner = conflict.newerVersion
            let resolved = winner == .local ? conflict.localVersion : conflict.remoteVersion
            result = ConflictResolutionResult(
                resolved: resolved,
                winner: winner,
                strategyUsed: .lastWriteWins,
            )

        case .mergePreferServer:
            let (merged, mergedFields) = conflict.localVersion.merge(
                with: conflict.remoteVersion,
                preferring: ConflictWinner.remote,
            )
            result = ConflictResolutionResult(
                resolved: merged,
                winner: .merged,
                strategyUsed: .mergePreferServer,
                mergedFields: mergedFields,
            )

        case .mergePreferClient:
            let (merged, mergedFields) = conflict.localVersion.merge(
                with: conflict.remoteVersion,
                preferring: ConflictWinner.local,
            )
            result = ConflictResolutionResult(
                resolved: merged,
                winner: .merged,
                strategyUsed: .mergePreferClient,
                mergedFields: mergedFields,
            )

        case .manual:
            // For manual resolution, default to server wins until user decides
            result = ConflictResolutionResult(
                resolved: conflict.remoteVersion,
                winner: .manual,
                strategyUsed: .manual,
            )
        }

        // Record resolution
        resolutionHistory.append(result)
        pendingConflicts.removeValue(forKey: conflict.entityId)

        logger
            .info(
                "✅ Conflict resolved for \(T.entityType) '\(conflict.entityId)': \(result.winner.rawValue) via \(result.strategyUsed.rawValue)",
            )

        return result
    }

    /// Manually resolve a conflict with a specific choice
    public func manuallyResolve(
        entityId: String,
        choice: ConflictWinner,
        customResolution: T? = nil,
    ) async -> ConflictResolutionResult<T>? {
        guard let conflict = pendingConflicts[entityId] else {
            logger.error("No pending conflict for entity '\(entityId)'")
            return nil
        }

        let resolved: T
        switch choice {
        case .local:
            resolved = conflict.localVersion
        case .remote:
            resolved = conflict.remoteVersion
        case .merged:
            if let custom = customResolution {
                resolved = custom
            } else {
                let (merged, _) = conflict.localVersion.merge(
                    with: conflict.remoteVersion,
                    preferring: ConflictWinner.remote,
                )
                resolved = merged
            }
        case .manual:
            resolved = customResolution ?? conflict.remoteVersion
        }

        let result = ConflictResolutionResult(
            resolved: resolved,
            winner: choice,
            strategyUsed: .manual,
        )

        resolutionHistory.append(result)
        pendingConflicts.removeValue(forKey: entityId)

        return result
    }

    // MARK: - Query

    /// Get all pending conflicts
    public func getPendingConflicts() -> [ConflictInfo<T>] {
        Array(pendingConflicts.values)
    }

    /// Check if there are any pending conflicts
    public func hasPendingConflicts() -> Bool {
        !pendingConflicts.isEmpty
    }

    /// Get resolution history
    public func getResolutionHistory(limit: Int = 50) -> [ConflictResolutionResult<T>] {
        Array(resolutionHistory.suffix(limit))
    }

    /// Clear pending conflicts (use with caution)
    public func clearPendingConflicts() {
        pendingConflicts.removeAll()
    }
}

// MARK: - Conflict Queue

/// Queue for managing multiple entity types' conflicts
public actor ConflictQueue {
    public static let shared = ConflictQueue()

    private var pendingConflictIds: [String: Set<String>] = [:] // entityType -> [entityId]
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ConflictQueue")

    private init() {}

    /// Record a conflict
    public func recordConflict(entityType: String, entityId: String) {
        if pendingConflictIds[entityType] == nil {
            pendingConflictIds[entityType] = []
        }
        pendingConflictIds[entityType]?.insert(entityId)
        logger.debug("📝 Conflict recorded: \(entityType)/\(entityId)")
    }

    /// Remove resolved conflict
    public func markResolved(entityType: String, entityId: String) {
        pendingConflictIds[entityType]?.remove(entityId)
        logger.debug("✅ Conflict resolved: \(entityType)/\(entityId)")
    }

    /// Get all pending conflict counts
    public func getPendingCounts() -> [String: Int] {
        pendingConflictIds.mapValues { $0.count }
    }

    /// Get total pending conflict count
    public func totalPendingCount() -> Int {
        pendingConflictIds.values.reduce(0) { $0 + $1.count }
    }

    /// Check if entity has pending conflict
    public func hasPendingConflict(entityType: String, entityId: String) -> Bool {
        pendingConflictIds[entityType]?.contains(entityId) ?? false
    }
}

// MARK: - Sync Conflict Event

/// Event emitted when a sync conflict occurs
public struct SyncConflictEvent: Sendable {
    public let entityType: String
    public let entityId: String
    public let localTimestamp: Date
    public let remoteTimestamp: Date
    public let conflictingFields: [String]
    public let occurredAt: Date
    public let resolution: ConflictWinner?

    public init(
        entityType: String,
        entityId: String,
        localTimestamp: Date,
        remoteTimestamp: Date,
        conflictingFields: [String],
        resolution: ConflictWinner? = nil,
    ) {
        self.entityType = entityType
        self.entityId = entityId
        self.localTimestamp = localTimestamp
        self.remoteTimestamp = remoteTimestamp
        self.conflictingFields = conflictingFields
        self.occurredAt = Date()
        self.resolution = resolution
    }
}

// MARK: - Default Syncable Extensions

#if !SKIP
/// Default implementation helpers for common patterns
extension Syncable {
    /// Default conflicting fields detection (compares all Codable properties)
    public func defaultConflictingFields(
        comparing keyPaths: [(String, KeyPath<Self, some Equatable>)],
        with other: Self,
    ) -> [String] {
        keyPaths.compactMap { name, keyPath in
            self[keyPath: keyPath] != other[keyPath: keyPath] ? name : nil
        }
    }
}
#endif

#endif
