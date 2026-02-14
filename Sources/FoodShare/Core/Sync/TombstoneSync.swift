//
//  TombstoneSync.swift
//  FoodShare
//
//  Enterprise-grade tombstone synchronization for tracking soft deletes.
//  Manages bidirectional deletion tracking between local Core Data and Supabase.
//
//  Features:
//  - Track local deletions with timestamps
//  - Sync tombstones from Supabase sync_tombstones table
//  - Apply remote deletions to local cache
//  - Conflict resolution for delete vs update scenarios
//  - Automatic cleanup of old tombstones
//  - Thread-safe actor isolation
//
//  Usage:
//  ```swift
//  let tombstoneSync = TombstoneSync.shared
//  await tombstoneSync.recordDeletion(entityType: "posts", entityId: "123")
//  try await tombstoneSync.syncTombstones()
//  ```
//

#if !SKIP
import CoreData
#endif
import Foundation
import OSLog
import Supabase

// MARK: - Sync Tombstone Model

/// Represents a soft delete record for sync tracking
public struct SyncTombstone: Codable, Sendable, Identifiable {
    /// Unique identifier for the tombstone
    public let id: UUID

    /// Type of entity (e.g., "posts", "messages", "forum")
    public let entityType: String

    /// ID of the deleted entity (stored as string for flexibility)
    public let entityId: String

    /// When the entity was deleted
    public let deletedAt: Date

    /// When this tombstone was last synced to/from server
    public var syncedAt: Date?

    /// Profile ID of who deleted the entity (for audit trail)
    public let deletedBy: UUID?

    /// Whether this tombstone originated locally (true) or remotely (false)
    public let isLocalDeletion: Bool

    public init(
        id: UUID = UUID(),
        entityType: String,
        entityId: String,
        deletedAt: Date = Date(),
        syncedAt: Date? = nil,
        deletedBy: UUID? = nil,
        isLocalDeletion: Bool = true,
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.deletedAt = deletedAt
        self.syncedAt = syncedAt
        self.deletedBy = deletedBy
        self.isLocalDeletion = isLocalDeletion
    }
}

// MARK: - Tombstone Sync Configuration

/// Configuration for tombstone synchronization behavior
public struct TombstoneSyncConfiguration: Sendable {
    /// How long to keep tombstones before cleanup (default: 30 days)
    public let retentionPeriod: TimeInterval

    /// Whether to automatically apply remote deletions
    public let autoApplyRemoteDeletions: Bool

    /// Conflict resolution strategy for delete vs update
    public let conflictStrategy: TombstoneConflictStrategy

    /// Batch size for sync operations
    public let batchSize: Int

    public init(
        retentionPeriod: TimeInterval = 60 * 60 * 24 * 30, // 30 days
        autoApplyRemoteDeletions: Bool = true,
        conflictStrategy: TombstoneConflictStrategy = .deletionWins,
        batchSize: Int = 100,
    ) {
        self.retentionPeriod = retentionPeriod
        self.autoApplyRemoteDeletions = autoApplyRemoteDeletions
        self.conflictStrategy = conflictStrategy
        self.batchSize = batchSize
    }

    public static let `default` = TombstoneSyncConfiguration()
}

// MARK: - Conflict Strategy

/// Strategy for resolving conflicts between deletions and updates
public enum TombstoneConflictStrategy: String, Sendable {
    /// Deletion always wins - if deleted remotely, delete locally
    case deletionWins

    /// Update wins - if updated after deletion, resurrect the entity
    case updateWins

    /// Use timestamps - most recent operation wins
    case timestampWins

    /// Manual resolution required
    case manual
}

// MARK: - Tombstone Conflict

/// Information about a delete vs update conflict
public struct TombstoneConflict: Sendable {
    public let entityType: String
    public let entityId: String
    public let deletedAt: Date
    public let updatedAt: Date
    public let deletedBy: UUID?
    public let detectedAt: Date

    /// Which operation occurred first
    public var deletionWasFirst: Bool {
        deletedAt < updatedAt
    }

    public init(
        entityType: String,
        entityId: String,
        deletedAt: Date,
        updatedAt: Date,
        deletedBy: UUID? = nil,
    ) {
        self.entityType = entityType
        self.entityId = entityId
        self.deletedAt = deletedAt
        self.updatedAt = updatedAt
        self.deletedBy = deletedBy
        self.detectedAt = Date()
    }
}

// MARK: - Tombstone Sync Statistics

/// Statistics for tombstone sync operations
public struct TombstoneSyncStatistics: Sendable {
    public let totalProcessed: Int
    public let localDeletionsRecorded: Int
    public let remoteDeletionsApplied: Int
    public let conflictsDetected: Int
    public let conflictsResolved: Int
    public let tombstonesCleanedUp: Int
    public let duration: TimeInterval
    public let startedAt: Date
    public let completedAt: Date

    public init(
        totalProcessed: Int = 0,
        localDeletionsRecorded: Int = 0,
        remoteDeletionsApplied: Int = 0,
        conflictsDetected: Int = 0,
        conflictsResolved: Int = 0,
        tombstonesCleanedUp: Int = 0,
        duration: TimeInterval = 0,
        startedAt: Date = Date(),
        completedAt: Date = Date(),
    ) {
        self.totalProcessed = totalProcessed
        self.localDeletionsRecorded = localDeletionsRecorded
        self.remoteDeletionsApplied = remoteDeletionsApplied
        self.conflictsDetected = conflictsDetected
        self.conflictsResolved = conflictsResolved
        self.tombstonesCleanedUp = tombstonesCleanedUp
        self.duration = duration
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

// MARK: - Tombstone Sync Actor

/// Thread-safe tombstone synchronization manager
public actor TombstoneSync {
    // MARK: - Singleton

    public static let shared = TombstoneSync()

    // MARK: - Properties

    private let supabase: SupabaseClient
    private let coreData: CoreDataStack
    private let logger: Logger
    private let configuration: TombstoneSyncConfiguration

    /// In-memory cache of pending tombstones
    private var pendingTombstones: [UUID: SyncTombstone] = [:]

    /// Track detected conflicts
    private var pendingConflicts: [String: TombstoneConflict] = [:]

    /// Last sync statistics
    private var lastStatistics: TombstoneSyncStatistics?

    /// Last successful sync timestamp
    private var lastSyncedAt: Date?

    // MARK: - Initialization

    public init(
        configuration: TombstoneSyncConfiguration = .default,
        supabase: SupabaseClient? = nil,
        coreData: CoreDataStack? = nil,
    ) {
        self.configuration = configuration
        self.supabase = supabase ?? SupabaseManager.shared.client
        self.coreData = coreData ?? CoreDataStack.shared
        self.logger = Logger(subsystem: "com.flutterflow.foodshare", category: "TombstoneSync")
    }

    // MARK: - Public API - Recording Deletions

    /// Record a local deletion to be synced to the server
    public func recordDeletion(
        entityType: String,
        entityId: String,
        deletedBy: UUID? = nil,
    ) async {
        let tombstone = SyncTombstone(
            entityType: entityType,
            entityId: entityId,
            deletedAt: Date(),
            deletedBy: deletedBy,
            isLocalDeletion: true,
        )

        // Add to pending queue
        pendingTombstones[tombstone.id] = tombstone

        // Persist to Core Data for offline support
        await persistTombstoneLocally(tombstone)

        logger.info("📝 [TOMBSTONE] Recorded deletion: \(entityType)/\(entityId)")
    }

    /// Record multiple deletions at once
    public func recordDeletions(
        entityType: String,
        entityIds: [String],
        deletedBy: UUID? = nil,
    ) async {
        for entityId in entityIds {
            await recordDeletion(
                entityType: entityType,
                entityId: entityId,
                deletedBy: deletedBy,
            )
        }

        logger.info("📝 [TOMBSTONE] Recorded \(entityIds.count) deletions for \(entityType)")
    }

    // MARK: - Public API - Synchronization

    /// Sync tombstones bidirectionally with Supabase
    public func syncTombstones() async throws {
        let startTime = Date()
        logger.info("🔄 [TOMBSTONE] Starting tombstone sync...")

        var stats = TombstoneSyncStatistics(startedAt: startTime)

        // Step 1: Push local deletions to server
        let pushedCount = try await pushLocalDeletions()
        stats = TombstoneSyncStatistics(
            totalProcessed: stats.totalProcessed + pushedCount,
            localDeletionsRecorded: pushedCount,
            remoteDeletionsApplied: stats.remoteDeletionsApplied,
            conflictsDetected: stats.conflictsDetected,
            conflictsResolved: stats.conflictsResolved,
            tombstonesCleanedUp: stats.tombstonesCleanedUp,
            startedAt: startTime,
        )

        // Step 2: Pull remote tombstones from server
        let pulledTombstones = try await pullRemoteTombstones()
        stats = TombstoneSyncStatistics(
            totalProcessed: stats.totalProcessed + pulledTombstones.count,
            localDeletionsRecorded: stats.localDeletionsRecorded,
            remoteDeletionsApplied: pulledTombstones.count,
            conflictsDetected: stats.conflictsDetected,
            conflictsResolved: stats.conflictsResolved,
            tombstonesCleanedUp: stats.tombstonesCleanedUp,
            startedAt: startTime,
        )

        // Step 3: Apply remote deletions with conflict detection
        if configuration.autoApplyRemoteDeletions {
            let (appliedCount, conflictCount, resolvedCount) = try await applyRemoteDeletions(pulledTombstones)
            stats = TombstoneSyncStatistics(
                totalProcessed: stats.totalProcessed,
                localDeletionsRecorded: stats.localDeletionsRecorded,
                remoteDeletionsApplied: appliedCount,
                conflictsDetected: conflictCount,
                conflictsResolved: resolvedCount,
                tombstonesCleanedUp: stats.tombstonesCleanedUp,
                startedAt: startTime,
            )
        }

        // Update metadata
        lastSyncedAt = Date()

        let duration = Date().timeIntervalSince(startTime)
        stats = TombstoneSyncStatistics(
            totalProcessed: stats.totalProcessed,
            localDeletionsRecorded: stats.localDeletionsRecorded,
            remoteDeletionsApplied: stats.remoteDeletionsApplied,
            conflictsDetected: stats.conflictsDetected,
            conflictsResolved: stats.conflictsResolved,
            tombstonesCleanedUp: stats.tombstonesCleanedUp,
            duration: duration,
            startedAt: startTime,
            completedAt: Date(),
        )

        lastStatistics = stats

        logger.info(
            "✅ [TOMBSTONE] Sync completed: pushed \(stats.localDeletionsRecorded), applied \(stats.remoteDeletionsApplied), conflicts \(stats.conflictsDetected)",
        )
    }

    /// Apply remote deletions to local cache
    public func applyRemoteDeletions() async throws {
        let tombstones = try await pullRemoteTombstones()
        _ = try await applyRemoteDeletions(tombstones)
    }

    // MARK: - Public API - Queries

    /// Get all pending deletions that haven't been synced
    public func getPendingDeletions() -> [SyncTombstone] {
        Array(pendingTombstones.values)
    }

    /// Get tombstones for a specific entity type
    public func getTombstones(forEntityType entityType: String) -> [SyncTombstone] {
        pendingTombstones.values.filter { $0.entityType == entityType }
    }

    /// Check if an entity has been deleted
    public func isDeleted(entityType: String, entityId: String) -> Bool {
        pendingTombstones.values.contains { tombstone in
            tombstone.entityType == entityType && tombstone.entityId == entityId
        }
    }

    /// Get pending conflicts
    public func getPendingConflicts() -> [TombstoneConflict] {
        Array(pendingConflicts.values)
    }

    /// Get last sync statistics
    public func getLastStatistics() -> TombstoneSyncStatistics? {
        lastStatistics
    }

    // MARK: - Public API - Cleanup

    /// Cleanup tombstones older than the specified date
    public func cleanupOldTombstones(olderThan date: Date) async throws -> Int {
        logger.info("🧹 [TOMBSTONE] Cleaning up tombstones older than \(date)...")

        let startTime = Date()

        // Clean local cache
        let localCleanedCount = await cleanupLocalTombstones(olderThan: date)

        // Clean server tombstones if needed
        let remoteCleanedCount = try await cleanupRemoteTombstones(olderThan: date)

        let totalCleaned = localCleanedCount + remoteCleanedCount

        logger
            .info(
                "✅ [TOMBSTONE] Cleaned up \(totalCleaned) tombstones (\(localCleanedCount) local, \(remoteCleanedCount) remote)",
            )

        // Update statistics
        if var stats = lastStatistics {
            stats = TombstoneSyncStatistics(
                totalProcessed: stats.totalProcessed,
                localDeletionsRecorded: stats.localDeletionsRecorded,
                remoteDeletionsApplied: stats.remoteDeletionsApplied,
                conflictsDetected: stats.conflictsDetected,
                conflictsResolved: stats.conflictsResolved,
                tombstonesCleanedUp: totalCleaned,
                duration: Date().timeIntervalSince(startTime),
                startedAt: startTime,
                completedAt: Date(),
            )
            lastStatistics = stats
        }

        return totalCleaned
    }

    /// Cleanup tombstones using configured retention period
    public func cleanupOldTombstones() async throws -> Int {
        let cutoffDate = Date().addingTimeInterval(-configuration.retentionPeriod)
        return try await cleanupOldTombstones(olderThan: cutoffDate)
    }

    // MARK: - Private - Push Operations

    /// Push local deletions to Supabase sync_tombstones table
    private func pushLocalDeletions() async throws -> Int {
        guard !pendingTombstones.isEmpty else {
            logger.debug("📤 [TOMBSTONE] No pending deletions to push")
            return 0
        }

        let tombstonesToPush = Array(pendingTombstones.values.filter { $0.syncedAt == nil })
        guard !tombstonesToPush.isEmpty else {
            return 0
        }

        logger.info("📤 [TOMBSTONE] Pushing \(tombstonesToPush.count) local deletions to server...")

        // Prepare payload for Supabase
        struct TombstoneInsertDTO: Encodable {
            let id: String
            let entityType: String
            let entityId: String
            let deletedAt: String
            let deletedBy: String?

            enum CodingKeys: String, CodingKey {
                case id
                case entityType = "entity_type"
                case entityId = "entity_id"
                case deletedAt = "deleted_at"
                case deletedBy = "deleted_by"
            }
        }

        let encoder = ISO8601DateFormatter()
        let dtos = tombstonesToPush.map { tombstone in
            TombstoneInsertDTO(
                id: tombstone.id.uuidString,
                entityType: tombstone.entityType,
                entityId: tombstone.entityId,
                deletedAt: encoder.string(from: tombstone.deletedAt),
                deletedBy: tombstone.deletedBy?.uuidString,
            )
        }

        // Push to Supabase in batches
        var pushedCount = 0
        for batch in dtos.chunked(into: configuration.batchSize) {
            do {
                try await supabase
                    .from("sync_tombstones")
                    .insert(batch)
                    .execute()

                // Mark as synced in local cache
                let batchIds = batch.compactMap { UUID(uuidString: $0.id) }
                for id in batchIds {
                    if var tombstone = pendingTombstones[id] {
                        tombstone.syncedAt = Date()
                        pendingTombstones[id] = tombstone
                        await updateTombstoneSyncStatus(id: id, syncedAt: Date())
                    }
                }

                pushedCount += batch.count
            } catch {
                logger.error("❌ [TOMBSTONE] Failed to push batch: \(error.localizedDescription)")
                throw error
            }
        }

        logger.info("✅ [TOMBSTONE] Pushed \(pushedCount) deletions to server")
        return pushedCount
    }

    // MARK: - Private - Pull Operations

    /// Pull remote tombstones from Supabase
    private func pullRemoteTombstones() async throws -> [SyncTombstone] {
        logger.debug("📥 [TOMBSTONE] Pulling remote tombstones from server...")

        // Fetch tombstones created/updated since last sync
        var query = supabase
            .from("sync_tombstones")
            .select("*")
            .order("deleted_at", ascending: false)
            .limit(configuration.batchSize)

        if let lastSync = lastSyncedAt {
            let formatter = ISO8601DateFormatter()
            query = query.gte("deleted_at", value: formatter.string(from: lastSync))
        }

        let response = try await query.execute()

        // Decode response
        struct TombstoneDTO: Decodable {
            let id: UUID
            let entityType: String
            let entityId: String
            let deletedAt: Date
            let deletedBy: UUID?
            let createdAt: Date?

            enum CodingKeys: String, CodingKey {
                case id
                case entityType = "entity_type"
                case entityId = "entity_id"
                case deletedAt = "deleted_at"
                case deletedBy = "deleted_by"
                case createdAt = "created_at"
            }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let dtos = try decoder.decode([TombstoneDTO].self, from: response.data)

        let tombstones = dtos.map { dto in
            SyncTombstone(
                id: dto.id,
                entityType: dto.entityType,
                entityId: dto.entityId,
                deletedAt: dto.deletedAt,
                syncedAt: Date(),
                deletedBy: dto.deletedBy,
                isLocalDeletion: false,
            )
        }

        logger.info("📥 [TOMBSTONE] Pulled \(tombstones.count) remote tombstones")
        return tombstones
    }

    // MARK: - Private - Apply Deletions

    /// Apply remote deletions to local Core Data cache
    private func applyRemoteDeletions(_ tombstones: [SyncTombstone]) async throws
        -> (applied: Int, conflicts: Int, resolved: Int)
    {
        guard !tombstones.isEmpty else {
            return (0, 0, 0)
        }

        logger.info("🔄 [TOMBSTONE] Applying \(tombstones.count) remote deletions...")

        var appliedCount = 0
        var conflictCount = 0
        var resolvedCount = 0

        let context = await coreData.newBackgroundContext()

        for tombstone in tombstones {
            // Skip if already in our local tombstone cache
            if pendingTombstones.values
                .contains(where: { $0.entityType == tombstone.entityType && $0.entityId == tombstone.entityId })
            {
                continue
            }

            // Check for conflicts with locally modified data
            let hasConflict = await detectConflict(for: tombstone, in: context)

            if hasConflict {
                conflictCount += 1

                // Try to resolve based on strategy
                let resolved = await resolveConflict(for: tombstone, in: context)
                if resolved {
                    resolvedCount += 1
                    appliedCount += 1
                }
            } else {
                // No conflict - apply deletion
                let deleted = await deleteCachedEntity(
                    entityType: tombstone.entityType,
                    entityId: tombstone.entityId,
                    in: context,
                )

                if deleted {
                    appliedCount += 1

                    // Add to local tombstone cache
                    pendingTombstones[tombstone.id] = tombstone
                    await persistTombstoneLocally(tombstone)
                }
            }
        }

        logger.info(
            "✅ [TOMBSTONE] Applied \(appliedCount) deletions, \(conflictCount) conflicts (\(resolvedCount) resolved)",
        )

        return (appliedCount, conflictCount, resolvedCount)
    }

    // MARK: - Private - Conflict Detection & Resolution

    /// Detect if applying a tombstone would conflict with local data
    private func detectConflict(for tombstone: SyncTombstone, in context: NSManagedObjectContext) async -> Bool {
        await context.perform { [weak self] in
            guard let self else { return false }

            // Map entity type to Core Data entity name
            let entityName = self.mapEntityTypeToCoreDataEntity(tombstone.entityType)

            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = self.buildPredicate(for: tombstone.entityId, entityName: entityName)
            fetchRequest.fetchLimit = 1

            let entity: NSManagedObject?
            do {
                entity = try context.fetch(fetchRequest).first
            } catch {
                Task { @TombstoneSync in
                    await self.logger.error("❌ [TOMBSTONE] Failed to fetch entity for conflict detection: \(error.localizedDescription)")
                }
                return false
            }

            guard let entity else {
                return false // Entity doesn't exist locally - no conflict
            }

            // Check if entity was modified after deletion timestamp
            if let locallyModified = entity.value(forKey: "locallyModified") as? Bool,
               locallyModified,
               let updatedAt = entity.value(forKey: "updatedAt") as? Date,
               updatedAt > tombstone.deletedAt
            {

                // Conflict detected: entity was modified locally after remote deletion
                let conflict = TombstoneConflict(
                    entityType: tombstone.entityType,
                    entityId: tombstone.entityId,
                    deletedAt: tombstone.deletedAt,
                    updatedAt: updatedAt,
                    deletedBy: tombstone.deletedBy,
                )

                Task { @TombstoneSync in
                    await self.recordConflict(conflict)
                }

                return true
            }

            return false
        }
    }

    /// Resolve a tombstone conflict based on configured strategy
    private func resolveConflict(for tombstone: SyncTombstone, in context: NSManagedObjectContext) async -> Bool {
        await context.perform { [weak self] in
            guard let self else { return false }

            let entityName = self.mapEntityTypeToCoreDataEntity(tombstone.entityType)

            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = self.buildPredicate(for: tombstone.entityId, entityName: entityName)
            fetchRequest.fetchLimit = 1

            let entity: NSManagedObject?
            do {
                entity = try context.fetch(fetchRequest).first
            } catch {
                Task { @TombstoneSync in
                    await self.logger.error("❌ [TOMBSTONE] Failed to fetch entity for conflict resolution: \(error.localizedDescription)")
                }
                return false
            }

            guard let entity,
                  let updatedAt = entity.value(forKey: "updatedAt") as? Date else
            {
                return false
            }

            var shouldDelete = false

            switch self.configuration.conflictStrategy {
            case .deletionWins:
                shouldDelete = true

            case .updateWins:
                shouldDelete = false

            case .timestampWins:
                // Most recent operation wins
                shouldDelete = tombstone.deletedAt > updatedAt

            case .manual:
                // Don't auto-resolve - leave in pending conflicts
                shouldDelete = false
            }

            if shouldDelete {
                context.delete(entity)
                do {
                    try context.save()
                    Task { @TombstoneSync in
                        await self.logger
                            .info(
                                "✅ [TOMBSTONE] Resolved conflict for \(tombstone.entityType)/\(tombstone.entityId): deletion wins",
                            )
                    }
                    return true
                } catch {
                    Task { @TombstoneSync in
                        await self.logger.error("❌ [TOMBSTONE] Failed to delete entity: \(error.localizedDescription)")
                    }
                    return false
                }
            } else {
                Task { @TombstoneSync in
                    await self.logger
                        .info(
                            "⚠️ [TOMBSTONE] Conflict preserved for manual resolution: \(tombstone.entityType)/\(tombstone.entityId)",
                        )
                }
                return false
            }
        }
    }

    /// Record a conflict for later manual resolution
    private func recordConflict(_ conflict: TombstoneConflict) {
        let key = "\(conflict.entityType)/\(conflict.entityId)"
        pendingConflicts[key] = conflict

        logger.warning(
            "⚠️ [TOMBSTONE] Conflict detected: \(conflict.entityType)/\(conflict.entityId) - deleted \(conflict.deletedAt), updated \(conflict.updatedAt)",
        )
    }

    // MARK: - Private - Core Data Operations

    /// Delete a cached entity from Core Data
    private func deleteCachedEntity(
        entityType: String,
        entityId: String,
        in context: NSManagedObjectContext,
    ) async -> Bool {
        await context.perform { [weak self] in
            guard let self else { return false }

            let entityName = self.mapEntityTypeToCoreDataEntity(entityType)

            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: entityName)
            fetchRequest.predicate = self.buildPredicate(for: entityId, entityName: entityName)

            do {
                let entities = try context.fetch(fetchRequest)
                for entity in entities {
                    context.delete(entity)
                }
                try context.save()

                Task { @TombstoneSync in
                    await self.logger.debug("🗑️ [TOMBSTONE] Deleted cached entity: \(entityType)/\(entityId)")
                }

                return !entities.isEmpty
            } catch {
                Task { @TombstoneSync in
                    await self.logger.error("❌ [TOMBSTONE] Failed to delete entity: \(error.localizedDescription)")
                }
                return false
            }
        }
    }

    /// Persist tombstone to Core Data for offline support
    private func persistTombstoneLocally(_ tombstone: SyncTombstone) async {
        let context = await coreData.newBackgroundContext()

        await context.perform { [weak self] in
            guard let self else { return }

            // Check if tombstone already exists
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SyncTombstone")
            fetchRequest.predicate = NSPredicate(format: "id == %@", tombstone.id as CVarArg)
            fetchRequest.fetchLimit = 1

            let existing = try? context.fetch(fetchRequest).first

            let entity = existing ?? NSEntityDescription.insertNewObject(forEntityName: "SyncTombstone", into: context)

            entity.setValue(tombstone.id, forKey: "id")
            entity.setValue(tombstone.entityType, forKey: "entityType")
            entity.setValue(tombstone.entityId, forKey: "entityId")
            entity.setValue(tombstone.deletedAt, forKey: "deletedAt")
            entity.setValue(tombstone.syncedAt, forKey: "syncedAt")
            entity.setValue(tombstone.deletedBy, forKey: "deletedBy")
            entity.setValue(tombstone.isLocalDeletion, forKey: "isLocalDeletion")

            do {
                try context.save()
            } catch {
                Task { @TombstoneSync in
                    await self.logger.error("❌ [TOMBSTONE] Failed to persist tombstone: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Update tombstone sync status in Core Data
    private func updateTombstoneSyncStatus(id: UUID, syncedAt: Date) async {
        let context = await coreData.newBackgroundContext()

        await context.perform {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SyncTombstone")
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            fetchRequest.fetchLimit = 1

            do {
                if let tombstone = try context.fetch(fetchRequest).first {
                    tombstone.setValue(syncedAt, forKey: "syncedAt")
                    try context.save()
                }
            } catch {
                // Log error but don't throw - sync status update is not critical
                Task { @TombstoneSync in
                    await self.logger.warning("⚠️ [TOMBSTONE] Failed to update tombstone sync status: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Cleanup local tombstones older than specified date
    private func cleanupLocalTombstones(olderThan date: Date) async -> Int {
        let context = await coreData.newBackgroundContext()

        return await context.perform { [weak self] in
            guard let self else { return 0 }

            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "SyncTombstone")
            fetchRequest.predicate = NSPredicate(format: "deletedAt < %@", date as NSDate)

            do {
                let tombstones = try context.fetch(fetchRequest)
                let count = tombstones.count

                for tombstone in tombstones {
                    if let id = tombstone.value(forKey: "id") as? UUID {
                        self.pendingTombstones.removeValue(forKey: id)
                    }
                    context.delete(tombstone)
                }

                try context.save()
                return count
            } catch {
                Task { @TombstoneSync in
                    await self.logger
                        .error("❌ [TOMBSTONE] Failed to cleanup local tombstones: \(error.localizedDescription)")
                }
                return 0
            }
        }
    }

    /// Cleanup remote tombstones older than specified date
    private func cleanupRemoteTombstones(olderThan date: Date) async throws -> Int {
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: date)

        do {
            let response = try await supabase
                .from("sync_tombstones")
                .delete()
                .lt("deleted_at", value: dateString)
                .execute()

            // Supabase doesn't return count for delete operations by default
            // We'll need to count before deleting or use a different approach
            logger.debug("🧹 [TOMBSTONE] Cleaned up remote tombstones older than \(date)")
            return 0 // Return 0 as we can't get exact count without extra query
        } catch {
            logger.error("❌ [TOMBSTONE] Failed to cleanup remote tombstones: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Private - Helpers

    /// Map entity type string to Core Data entity name
    private func mapEntityTypeToCoreDataEntity(_ entityType: String) -> String {
        switch entityType {
        case "posts":
            return "CachedListing"
        case "messages":
            return "CachedMessage"
        case "forum":
            return "CachedForumPost"
        case "profiles":
            return "CachedProfile"
        case "rooms":
            return "CachedRoom"
        default:
            // Fallback: capitalize first letter and add "Cached" prefix
            let capitalized = entityType.prefix(1).uppercased() + entityType.dropFirst()
            return "Cached\(capitalized)"
        }
    }

    /// Build predicate for finding entity by ID
    private func buildPredicate(for entityId: String, entityName: String) -> NSPredicate {
        // Try to parse as Int64 first (most common)
        if let intId = Int64(entityId) {
            return NSPredicate(format: "id == %lld", intId)
        }

        // Try UUID
        if let uuidId = UUID(uuidString: entityId) {
            return NSPredicate(format: "id == %@", uuidId as CVarArg)
        }

        // Fallback to string comparison
        return NSPredicate(format: "id == %@", entityId)
    }
}

// MARK: - Array Extension

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Observable Wrapper for SwiftUI

/// MainActor-bound wrapper for SwiftUI integration
@MainActor
@Observable
public final class TombstoneSyncService {
    public static let shared = TombstoneSyncService()

    private let tombstoneSync = TombstoneSync.shared

    public private(set) var isSyncing = false
    public private(set) var lastStatistics: TombstoneSyncStatistics?
    public private(set) var pendingConflictsCount = 0

    private init() {}

    /// Record a deletion
    public func recordDeletion(entityType: String, entityId: String) async {
        await tombstoneSync.recordDeletion(entityType: entityType, entityId: entityId)
    }

    /// Perform full sync
    public func syncTombstones() async throws {
        isSyncing = true
        defer { isSyncing = false }

        try await tombstoneSync.syncTombstones()

        lastStatistics = await tombstoneSync.getLastStatistics()
        pendingConflictsCount = await tombstoneSync.getPendingConflicts().count
    }

    /// Cleanup old tombstones
    public func cleanupOldTombstones() async throws {
        _ = try await tombstoneSync.cleanupOldTombstones()
        lastStatistics = await tombstoneSync.getLastStatistics()
    }

    /// Get pending conflicts
    public func getPendingConflicts() async -> [TombstoneConflict] {
        await tombstoneSync.getPendingConflicts()
    }
}
