//
//  SyncManager.swift
//  Foodshare
//
//  Enterprise-grade synchronization manager with conflict resolution.
//  Manages bidirectional sync between Supabase and Core Data cache.
//
//  Features:
//  - Conflict detection and resolution using ConflictResolver
//  - Incremental sync with version tracking
//  - Offline queue for pending changes
//  - Sync statistics and audit logging
//


#if !SKIP
import CoreData
import Foundation
#if !SKIP
import Network
#endif
import Observation
import OSLog
import Supabase
import SwiftUI

// MARK: - Sync State

enum SyncState: Equatable {
    case idle
    case syncing
    case offline
    case error(String)
    case conflictsPending(Int)
}

// MARK: - Sync Configuration

/// Configuration for sync behavior
public struct SyncConfiguration: Sendable {
    /// Default conflict resolution strategy
    public let defaultStrategy: ConflictResolutionStrategy

    /// Maximum items to fetch per sync batch
    public let batchSize: Int

    /// Cache expiration interval
    public let cacheExpirationInterval: TimeInterval

    /// Whether to auto-resolve conflicts or queue for manual resolution
    public let autoResolveConflicts: Bool

    /// Whether to log sync operations for auditing
    public let enableAuditLogging: Bool

    public init(
        defaultStrategy: ConflictResolutionStrategy = .lastWriteWins,
        batchSize: Int = 200,
        cacheExpirationInterval: TimeInterval = 60 * 60 * 24,
        autoResolveConflicts: Bool = true,
        enableAuditLogging: Bool = true,
    ) {
        self.defaultStrategy = defaultStrategy
        self.batchSize = batchSize
        self.cacheExpirationInterval = cacheExpirationInterval
        self.autoResolveConflicts = autoResolveConflicts
        self.enableAuditLogging = enableAuditLogging
    }

    public static let `default` = SyncConfiguration()
}

// MARK: - Sync Manager

@MainActor
@Observable
final class SyncManager {
    static let shared = SyncManager()

    // MARK: - State

    var syncState: SyncState = .idle
    var isOnline = true
    var lastSyncDate: Date?
    var pendingConflictsCount = 0
    var lastSyncStatistics: SyncStatistics?

    // MARK: - Dependencies

    private let coreData = CoreDataStack.shared
    private let supabase = SupabaseManager.shared.client
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "SyncManager")
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.flutterflow.foodshare.network")

    // MARK: - Conflict Resolution

    private let listingResolver: ConflictResolver<SyncableListing>
    private let forumPostResolver: ConflictResolver<SyncableForumPost>
    private let conflictQueue = ConflictQueue.shared

    // MARK: - Configuration

    private let configuration: SyncConfiguration
    private var cacheExpirationInterval: TimeInterval { configuration.cacheExpirationInterval }
    private var maxCachedListings: Int { configuration.batchSize }

    // MARK: - Initialization

    private init(configuration: SyncConfiguration = .default) {
        self.configuration = configuration

        // Initialize conflict resolvers with configured strategy
        self.listingResolver = ConflictResolver<SyncableListing>(
            strategy: configuration.defaultStrategy,
            logger: Logger(subsystem: "com.flutterflow.foodshare", category: "ListingConflictResolver"),
        )
        self.forumPostResolver = ConflictResolver<SyncableForumPost>(
            strategy: configuration.defaultStrategy,
            logger: Logger(subsystem: "com.flutterflow.foodshare", category: "ForumPostConflictResolver"),
        )

        startNetworkMonitoring()

        // Trigger CoreData store loading early and wait for it to be ready
        Task {
            // Access the container to trigger lazy loading
            _ = coreData.persistentContainer
            await coreData.waitForStoreReady()
            logger.info("🔄 [SyncManager] CoreData store ready")

            // Check for any pending conflicts from previous session
            await updatePendingConflictsCount()
        }
    }

    /// Update the pending conflicts count from all resolvers
    private func updatePendingConflictsCount() async {
        let listingConflicts = await listingResolver.getPendingConflicts().count
        let forumConflicts = await forumPostResolver.getPendingConflicts().count
        let queueCount = await conflictQueue.totalPendingCount()

        pendingConflictsCount = listingConflicts + forumConflicts + queueCount

        if pendingConflictsCount > 0 {
            syncState = .conflictsPending(pendingConflictsCount)
            logger.warning("⚠️ [SYNC] \(self.pendingConflictsCount) pending conflicts require attention")
        }
    }

    // MARK: - Network Monitoring

    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = self?.isOnline == false
                self?.isOnline = path.status == .satisfied

                if wasOffline, path.status == .satisfied {
                    self?.logger.info("📶 [SYNC] Network restored - triggering sync")
                    await self?.syncPendingChanges()
                } else if path.status != .satisfied {
                    self?.logger.warning("📵 [SYNC] Network unavailable - switching to offline mode")
                    self?.syncState = .offline
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }

    // MARK: - Full Sync

    /// Perform a full sync of all cacheable data
    /// Pushes local changes first, then pulls remote changes with conflict resolution
    func performFullSync() async {
        guard isOnline else {
            logger.warning("📵 [SYNC] Offline - skipping full sync")
            syncState = .offline
            return
        }

        logger.info("🔄 [SYNC] Starting full bidirectional sync...")
        syncState = .syncing

        do {
            // Step 1: Push local changes first (client-first strategy)
            try await pushLocalChanges()

            // Step 2: Pull remote changes with conflict resolution
            try await syncListings()

            // Step 3: Sync forum posts
            try await syncForumPosts()

            // Step 4: Check for any remaining conflicts
            await updatePendingConflictsCount()

            // Update sync metadata
            lastSyncDate = Date()

            if pendingConflictsCount > 0 {
                syncState = .conflictsPending(pendingConflictsCount)
                logger.warning("⚠️ [SYNC] Full sync completed with \(self.pendingConflictsCount) pending conflicts")
            } else {
                syncState = .idle
                logger.info("✅ [SYNC] Full sync completed successfully")
            }
        } catch {
            logger.error("❌ [SYNC] Full sync failed: \(error.localizedDescription)")
            syncState = .error(error.localizedDescription)
        }
    }

    // MARK: - Listing Sync

    /// Sync listings from Supabase to Core Data with conflict resolution
    func syncListings() async throws {
        let startTime = Date()
        logger.debug("🔄 [SYNC] Syncing listings with conflict resolution...")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Fetch recent listings from Supabase
        let response = try await supabase
            .from("posts")
            .select("*")
            .eq("is_active", value: true)
            .order("created_at", ascending: false)
            .limit(maxCachedListings)
            .execute()

        struct ListingDTO: Decodable {
            let id: Int
            let postName: String
            let postDescription: String?
            let postAddress: String?
            let latitude: Double?
            let longitude: Double?
            let images: [String]?
            let category: String?
            let profileId: UUID
            let isArranged: Bool
            let createdAt: Date
            let updatedAt: Date?
            let version: Int?

            enum CodingKeys: String, CodingKey {
                case id
                case postName = "post_name"
                case postDescription = "post_description"
                case postAddress = "post_address"
                case latitude
                case longitude
                case images
                case category = "post_type"
                case profileId = "profile_id"
                case isArranged = "is_arranged"
                case createdAt = "created_at"
                case updatedAt = "updated_at"
                case version
            }
        }

        let remoteDTOs = try decoder.decode([ListingDTO].self, from: response.data)
        logger.debug("📦 [SYNC] Fetched \(remoteDTOs.count) listings from server")

        // Local helper to update cached listing from DTO
        func updateCachedListingFromDTO(_ cached: CachedListing, _ dto: ListingDTO) {
            cached.name = dto.postName
            cached.descriptionText = dto.postDescription
            cached.address = dto.postAddress
            cached.latitude = dto.latitude ?? 0
            cached.longitude = dto.longitude ?? 0
            cached.images = dto.images ?? []
            cached.category = dto.category
            cached.isArranged = dto.isArranged
            cached.updatedAt = dto.updatedAt ?? dto.createdAt
            cached.cachedAt = Date()
            cached.syncVersion = Int64(dto.version ?? 0)
        }

        // Collected data for conflict processing (Sendable)
        struct PendingConflict: Sendable {
            let listingId: Int64
            let local: SyncableListing
            let remote: SyncableListing
        }

        struct SimpleUpdate: Sendable {
            let listingId: Int64
            let remote: SyncableListing
        }

        // Thread-safe statistics using actor
        actor SyncStats {
            var created = 0
            var updated = 0
            var conflictsDetected = 0
            var conflictsResolved = 0
            var errors = 0

            func incrementCreated() { created += 1 }
            func incrementUpdated() { updated += 1 }
            func incrementConflicts() { conflictsDetected += 1 }
            func incrementResolved() { conflictsResolved += 1 }
            func incrementErrors() { errors += 1 }

            func getAll() -> (created: Int, updated: Int, conflictsDetected: Int, conflictsResolved: Int, errors: Int) {
                (created, updated, conflictsDetected, conflictsResolved, errors)
            }
        }

        let stats = SyncStats()
        let context = coreData.newBackgroundContext()

        // Phase 1: Collect conflict data and process non-conflicting updates
        var pendingConflicts: [PendingConflict] = []
        var simpleUpdates: [SimpleUpdate] = []

        await context.perform { [self] in
            for dto in remoteDTOs {
                do {
                    let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
                    fetchRequest.predicate = NSPredicate(format: "id == %lld", Int64(dto.id))
                    fetchRequest.fetchLimit = 1

                    let existingListings = try context.fetch(fetchRequest)

                    if let existing = existingListings.first {
                        if existing.locallyModified {
                            // Collect for conflict resolution
                            let localSyncable = SyncableListing.from(existing)
                            let remoteSyncable = SyncableListing(
                                id: Int64(dto.id),
                                name: dto.postName,
                                descriptionText: dto.postDescription,
                                address: dto.postAddress,
                                latitude: dto.latitude ?? 0,
                                longitude: dto.longitude ?? 0,
                                images: dto.images ?? [],
                                category: dto.category,
                                profileId: dto.profileId,
                                isArranged: dto.isArranged,
                                createdAt: dto.createdAt,
                                updatedAt: dto.updatedAt ?? dto.createdAt,
                                version: dto.version ?? 0,
                            )
                            pendingConflicts.append(PendingConflict(
                                listingId: Int64(dto.id),
                                local: localSyncable,
                                remote: remoteSyncable,
                            ))
                        } else {
                            // No conflict - collect for simple update
                            let remoteSyncable = SyncableListing(
                                id: Int64(dto.id),
                                name: dto.postName,
                                descriptionText: dto.postDescription,
                                address: dto.postAddress,
                                latitude: dto.latitude ?? 0,
                                longitude: dto.longitude ?? 0,
                                images: dto.images ?? [],
                                category: dto.category,
                                profileId: dto.profileId,
                                isArranged: dto.isArranged,
                                createdAt: dto.createdAt,
                                updatedAt: dto.updatedAt ?? dto.createdAt,
                                version: dto.version ?? 0,
                            )
                            simpleUpdates.append(SimpleUpdate(listingId: Int64(dto.id), remote: remoteSyncable))
                        }
                    } else {
                        // New listing - create it directly
                        let cached = CachedListing(context: context)
                        cached.id = Int64(dto.id)
                        cached.name = dto.postName
                        cached.descriptionText = dto.postDescription
                        cached.address = dto.postAddress
                        cached.latitude = dto.latitude ?? 0
                        cached.longitude = dto.longitude ?? 0
                        cached.images = dto.images ?? []
                        cached.category = dto.category
                        cached.profileId = dto.profileId
                        cached.isArranged = dto.isArranged
                        cached.createdAt = dto.createdAt
                        cached.updatedAt = dto.updatedAt ?? dto.createdAt
                        cached.cachedAt = Date()
                        cached.syncVersion = Int64(dto.version ?? 0)
                        cached.locallyModified = false
                        cached.pendingSync = false

                        Task { await stats.incrementCreated() }
                    }
                } catch {
                    Task { [self] in
                        await stats.incrementErrors()
                        logger.error("❌ [SYNC] Error processing listing \(dto.id): \(error.localizedDescription)")
                    }
                }
            }

            // Save new listings
            do {
                try context.save()
            } catch {
                Task { @MainActor [self] in
                    logger.error("❌ [SYNC] Failed to save new listings: \(error.localizedDescription)")
                }
            }
        }

        // Helper to apply SyncableListing data to CachedListing (nonisolated for use in context.perform)
        @Sendable
        nonisolated func applyResolutionToCached(_ resolved: SyncableListing, _ cached: CachedListing) {
            cached.name = resolved.name
            cached.descriptionText = resolved.descriptionText
            cached.address = resolved.address
            cached.latitude = resolved.latitude
            cached.longitude = resolved.longitude
            cached.images = resolved.images
            cached.category = resolved.category
            cached.isArranged = resolved.isArranged
            cached.updatedAt = resolved.updatedAt
            cached.cachedAt = Date()
            cached.syncVersion = Int64(resolved.version)
        }

        // Phase 2: Process simple updates (no conflicts)
        for update in simpleUpdates {
            let remote = update.remote
            await context.perform { [self] in
                let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
                fetchRequest.predicate = NSPredicate(format: "id == %lld", update.listingId)
                fetchRequest.fetchLimit = 1

                do {
                    if let cached = try context.fetch(fetchRequest).first {
                        applyResolutionToCached(remote, cached)
                        cached.locallyModified = false
                    } else {
                        Task { @MainActor [self] in
                            logger.warning("⚠️ [SYNC] Cached listing \(update.listingId) not found for simple update")
                        }
                    }
                } catch {
                    Task { @MainActor [self] in
                        logger.error("❌ [SYNC] Failed to fetch cached listing \(update.listingId): \(error.localizedDescription)")
                    }
                }
            }
            await stats.incrementUpdated()
        }

        // Phase 3: Process conflicts
        for conflict in pendingConflicts {
            if let detectedConflict = await listingResolver.detectConflict(
                local: conflict.local,
                remote: conflict.remote,
            ) {
                await stats.incrementConflicts()

                if configuration.autoResolveConflicts {
                    let result = await listingResolver.resolveConflict(detectedConflict)
                    await stats.incrementResolved()

                    // Apply resolution
                    let resolved = result.resolved
                    await context.perform { [self] in
                        let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
                        fetchRequest.predicate = NSPredicate(format: "id == %lld", conflict.listingId)
                        fetchRequest.fetchLimit = 1

                        do {
                            if let cached = try context.fetch(fetchRequest).first {
                                applyResolutionToCached(resolved, cached)
                                cached.locallyModified = false
                                cached.pendingSync = false
                            } else {
                                Task { @MainActor [self] in
                                    logger.warning("⚠️ [SYNC] Cached listing \(conflict.listingId) not found for conflict resolution")
                                }
                            }
                        } catch {
                            Task { @MainActor [self] in
                                logger.error("❌ [SYNC] Failed to fetch cached listing \(conflict.listingId) for conflict resolution: \(error.localizedDescription)")
                            }
                        }
                    }
                } else {
                    await conflictQueue.recordConflict(
                        entityType: SyncableListing.entityType,
                        entityId: String(conflict.listingId),
                    )
                }
            } else {
                // No actual conflict - apply remote data
                let remote = conflict.remote
                await context.perform { [self] in
                    let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
                    fetchRequest.predicate = NSPredicate(format: "id == %lld", conflict.listingId)
                    fetchRequest.fetchLimit = 1

                    do {
                        if let cached = try context.fetch(fetchRequest).first {
                            applyResolutionToCached(remote, cached)
                            cached.locallyModified = false
                        } else {
                            Task { @MainActor [self] in
                                logger.warning("⚠️ [SYNC] Cached listing \(conflict.listingId) not found for non-conflict update")
                            }
                        }
                    } catch {
                        Task { @MainActor [self] in
                            logger.error("❌ [SYNC] Failed to fetch cached listing \(conflict.listingId) for non-conflict update: \(error.localizedDescription)")
                        }
                    }
                }
            }
            await stats.incrementUpdated()
        }

        // Final save
        await context.perform { [self] in
            do {
                try context.save()
            } catch {
                Task { @MainActor [self] in
                    logger.error("❌ [SYNC] Failed to save final sync changes: \(error.localizedDescription)")
                }
            }
        }

        // Get final statistics
        let finalStats = await stats.getAll()

        // Update sync metadata
        await updateSyncMetadata(entityType: "listings")

        // Record statistics
        let duration = Date().timeIntervalSince(startTime)
        lastSyncStatistics = SyncStatistics(
            entityType: "listings",
            totalProcessed: remoteDTOs.count,
            created: finalStats.created,
            updated: finalStats.updated,
            conflictsDetected: finalStats.conflictsDetected,
            conflictsResolved: finalStats.conflictsResolved,
            errors: finalStats.errors,
            duration: duration,
            startedAt: startTime,
            completedAt: Date(),
        )

        logger
            .info(
                "✅ [SYNC] Listings sync completed: \(finalStats.created) created, \(finalStats.updated) updated, \(finalStats.conflictsDetected) conflicts (\(finalStats.conflictsResolved) resolved)",
            )
    }

    /// Apply resolved listing data to cached entity
    private func applyListingResolution(_ resolved: SyncableListing, to cached: CachedListing) {
        cached.name = resolved.name
        cached.descriptionText = resolved.descriptionText
        cached.address = resolved.address
        cached.latitude = resolved.latitude
        cached.longitude = resolved.longitude
        cached.images = resolved.images
        cached.category = resolved.category
        cached.isArranged = resolved.isArranged
        cached.updatedAt = resolved.updatedAt
        cached.cachedAt = Date()
        cached.syncVersion = Int64(resolved.version)
    }

    // MARK: - Local Modification Tracking

    /// Mark a listing as locally modified (call when user edits offline)
    func markListingModified(id: Int64) async {
        let context = coreData.newBackgroundContext()

        await context.perform { [self] in
            let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
            fetchRequest.predicate = NSPredicate(format: "id == %lld", id)
            fetchRequest.fetchLimit = 1

            do {
                if let cached = try context.fetch(fetchRequest).first {
                    cached.locallyModified = true
                    cached.pendingSync = true
                    cached.updatedAt = Date()

                    do {
                        try context.save()
                        Task { @MainActor [self] in
                            logger.debug("📝 [SYNC] Listing \(id) marked as locally modified")
                        }
                    } catch {
                        Task { @MainActor [self] in
                            logger.error("❌ [SYNC] Failed to save locally modified listing \(id): \(error.localizedDescription)")
                        }
                    }
                } else {
                    Task { @MainActor [self] in
                        logger.warning("⚠️ [SYNC] Listing \(id) not found to mark as modified")
                    }
                }
            } catch {
                Task { @MainActor [self] in
                    logger.error("❌ [SYNC] Failed to fetch listing \(id) to mark as modified: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Get all locally modified listings that need to be pushed to server
    func getLocallyModifiedListings() async -> [SyncableListing] {
        let context = coreData.newBackgroundContext()

        return await context.perform { [self] in
            let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
            fetchRequest.predicate = NSPredicate(format: "locallyModified == YES")

            do {
                let cached = try context.fetch(fetchRequest)
                return cached.map { SyncableListing.from($0) }
            } catch {
                Task { @MainActor [self] in
                    logger.error("❌ [SYNC] Failed to fetch locally modified listings: \(error.localizedDescription)")
                }
                return []
            }
        }
    }

    /// Push local changes to server
    func pushLocalChanges() async throws {
        guard isOnline else {
            logger.warning("📵 [SYNC] Offline - cannot push changes")
            return
        }

        let locallyModified = await getLocallyModifiedListings()
        guard !locallyModified.isEmpty else {
            logger.debug("✅ [SYNC] No local changes to push")
            return
        }

        logger.info("🔄 [SYNC] Pushing \(locallyModified.count) local changes to server")

        // Encodable payload for listing updates
        struct ListingUpdatePayload: Encodable {
            let postName: String
            let postDescription: String?
            let postAddress: String?
            let latitude: Double
            let longitude: Double
            let images: [String]
            let postType: String?
            let isArranged: Bool
            let updatedAt: String

            enum CodingKeys: String, CodingKey {
                case postName = "post_name"
                case postDescription = "post_description"
                case postAddress = "post_address"
                case latitude
                case longitude
                case images
                case postType = "post_type"
                case isArranged = "is_arranged"
                case updatedAt = "updated_at"
            }
        }

        for listing in locallyModified {
            do {
                // Push to server
                let payload = ListingUpdatePayload(
                    postName: listing.name,
                    postDescription: listing.descriptionText,
                    postAddress: listing.address,
                    latitude: listing.latitude,
                    longitude: listing.longitude,
                    images: listing.images,
                    postType: listing.category,
                    isArranged: listing.isArranged,
                    updatedAt: ISO8601DateFormatter().string(from: Date()),
                )

                try await supabase
                    .from("posts")
                    .update(payload)
                    .eq("id", value: Int(listing.id))
                    .execute()

                // Mark as synced
                let context = coreData.newBackgroundContext()
                await context.perform { [self] in
                    let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
                    fetchRequest.predicate = NSPredicate(format: "id == %lld", listing.id)
                    fetchRequest.fetchLimit = 1

                    do {
                        if let cached = try context.fetch(fetchRequest).first {
                            cached.locallyModified = false
                            cached.pendingSync = false

                            do {
                                try context.save()
                            } catch {
                                Task { @MainActor [self] in
                                    logger.error("❌ [SYNC] Failed to save synced listing \(listing.id): \(error.localizedDescription)")
                                }
                            }
                        } else {
                            Task { @MainActor [self] in
                                logger.warning("⚠️ [SYNC] Listing \(listing.id) not found after push to mark as synced")
                            }
                        }
                    } catch {
                        Task { @MainActor [self] in
                            logger.error("❌ [SYNC] Failed to fetch listing \(listing.id) after push: \(error.localizedDescription)")
                        }
                    }
                }

                logger.debug("✅ [SYNC] Pushed listing \(listing.id) to server")
            } catch {
                logger.error("❌ [SYNC] Failed to push listing \(listing.id): \(error.localizedDescription)")
                throw error
            }
        }
    }

    // MARK: - Conflict Management

    /// Get all pending conflicts for manual resolution
    func getPendingListingConflicts() async -> [ConflictInfo<SyncableListing>] {
        await listingResolver.getPendingConflicts()
    }

    /// Get all pending forum post conflicts
    func getPendingForumPostConflicts() async -> [ConflictInfo<SyncableForumPost>] {
        await forumPostResolver.getPendingConflicts()
    }

    /// Manually resolve a listing conflict
    func resolveListingConflict(
        entityId: String,
        choice: ConflictWinner,
        customResolution: SyncableListing? = nil,
    ) async -> Bool {
        guard let result = await listingResolver.manuallyResolve(
            entityId: entityId,
            choice: choice,
            customResolution: customResolution,
        ) else {
            return false
        }

        // Capture resolution data for use in context.perform
        let resolved = result.resolved

        // Apply resolution to Core Data
        let context = coreData.newBackgroundContext()
        await context.perform { [self] in
            let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
            fetchRequest.predicate = NSPredicate(format: "id == %lld", Int64(entityId) ?? 0)
            fetchRequest.fetchLimit = 1

            do {
                if let cached = try context.fetch(fetchRequest).first {
                    // Apply resolution inline to avoid actor isolation issues
                    cached.name = resolved.name
                    cached.descriptionText = resolved.descriptionText
                    cached.address = resolved.address
                    cached.latitude = resolved.latitude
                    cached.longitude = resolved.longitude
                    cached.images = resolved.images
                    cached.category = resolved.category
                    cached.isArranged = resolved.isArranged
                    cached.updatedAt = resolved.updatedAt
                    cached.cachedAt = Date()
                    cached.syncVersion = Int64(resolved.version)
                    cached.locallyModified = false
                    cached.pendingSync = false

                    do {
                        try context.save()
                    } catch {
                        Task { @MainActor [self] in
                            logger.error("❌ [SYNC] Failed to save manually resolved conflict for listing \(entityId): \(error.localizedDescription)")
                        }
                    }
                } else {
                    Task { @MainActor [self] in
                        logger.warning("⚠️ [SYNC] Listing \(entityId) not found for manual conflict resolution")
                    }
                }
            } catch {
                Task { @MainActor [self] in
                    logger.error("❌ [SYNC] Failed to fetch listing \(entityId) for manual conflict resolution: \(error.localizedDescription)")
                }
            }
        }

        // Update conflict queue
        await conflictQueue.markResolved(entityType: SyncableListing.entityType, entityId: entityId)
        await updatePendingConflictsCount()

        logger.info("✅ [SYNC] Manually resolved conflict for listing \(entityId): \(choice.rawValue)")
        return true
    }

    /// Clear all pending conflicts (use with caution)
    func clearAllPendingConflicts() async {
        await listingResolver.clearPendingConflicts()
        await forumPostResolver.clearPendingConflicts()
        pendingConflictsCount = 0
        syncState = .idle
        logger.warning("⚠️ [SYNC] All pending conflicts cleared")
    }

    // MARK: - Cached Data Access

    /// Get cached listings (for offline use)
    func getCachedListings() async -> [CachedListing] {
        let context = coreData.viewContext
        let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            logger.error("❌ [SYNC] Failed to fetch cached listings: \(error.localizedDescription)")
            return []
        }
    }

    /// Get cached listing by ID
    func getCachedListing(id: Int64) async -> CachedListing? {
        let context = coreData.viewContext
        let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
        fetchRequest.predicate = NSPredicate(format: "id == %lld", id)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            logger.error("❌ [SYNC] Failed to fetch cached listing: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Forum Sync

    /// Sync forum posts from Supabase to Core Data
    func syncForumPosts() async throws {
        logger.debug("🔄 [SYNC] Syncing forum posts...")

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Fetch recent forum posts
        let response = try await supabase
            .from("forum")
            .select("""
                *,
                profiles:profile_id (id, nickname, avatar_url, is_verified)
            """)
            .eq("forum_published", value: true)
            .order("forum_post_created_at", ascending: false)
            .limit(100)
            .execute()

        struct ForumPostDTO: Decodable {
            let id: Int
            let profileId: UUID
            let forumPostName: String?
            let forumPostDescription: String?
            let forumPostImage: String?
            let forumCommentsCounter: Int?
            let forumLikesCounter: Int
            let categoryId: Int?
            let viewsCount: Int
            let isPinned: Bool
            let postType: String
            let forumPostCreatedAt: Date
            let profiles: AuthorDTO?

            enum CodingKeys: String, CodingKey {
                case id
                case profileId = "profile_id"
                case forumPostName = "forum_post_name"
                case forumPostDescription = "forum_post_description"
                case forumPostImage = "forum_post_image"
                case forumCommentsCounter = "forum_comments_counter"
                case forumLikesCounter = "forum_likes_counter"
                case categoryId = "category_id"
                case viewsCount = "views_count"
                case isPinned = "is_pinned"
                case postType = "post_type"
                case forumPostCreatedAt = "forum_post_created_at"
                case profiles
            }
        }

        struct AuthorDTO: Decodable {
            let id: UUID
            let nickname: String?
            let avatarUrl: String?
            let isVerified: Bool?

            enum CodingKeys: String, CodingKey {
                case id
                case nickname
                case avatarUrl = "avatar_url"
                case isVerified = "is_verified"
            }
        }

        let posts = try decoder.decode([ForumPostDTO].self, from: response.data)
        logger.debug("📦 [SYNC] Fetched \(posts.count) forum posts from server")

        // Save to Core Data
        let context = coreData.newBackgroundContext()
        let encoder = JSONEncoder()

        await context.perform { [self] in
            // Clear old forum posts first
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedForumPost")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                try context.execute(deleteRequest)
            } catch {
                Task { @MainActor [self] in
                    logger.error("❌ [SYNC] Failed to delete old forum posts: \(error.localizedDescription)")
                }
            }

            // Insert new posts
            for dto in posts {
                let cached = CachedForumPost(context: context)
                cached.id = Int64(dto.id)
                cached.profileId = dto.profileId
                cached.title = dto.forumPostName
                cached.descriptionText = dto.forumPostDescription
                cached.imageUrl = dto.forumPostImage
                cached.categoryId = Int64(dto.categoryId ?? 0)
                cached.postType = dto.postType
                cached.commentsCount = Int64(dto.forumCommentsCounter ?? 0)
                cached.likesCount = Int64(dto.forumLikesCounter)
                cached.viewsCount = Int64(dto.viewsCount)
                cached.isPinned = dto.isPinned
                cached.createdAt = dto.forumPostCreatedAt
                cached.cachedAt = Date()

                // Encode author data
                if let author = dto.profiles {
                    let authorModel = ForumAuthor(
                        id: author.id,
                        nickname: author.nickname ?? "Anonymous",
                        avatarUrl: author.avatarUrl,
                        isVerified: author.isVerified,
                    )
                    cached.authorData = try? encoder.encode(authorModel)
                }
            }

            do {
                try context.save()
                Task { @MainActor in
                    self.logger.debug("✅ [SYNC] Cached \(posts.count) forum posts")
                }
            } catch {
                Task { @MainActor in
                    self.logger.error("❌ [SYNC] Failed to save forum posts: \(error.localizedDescription)")
                }
            }
        }

        // Update sync metadata
        await updateSyncMetadata(entityType: "forum_posts")
    }

    /// Get cached forum posts (for offline use)
    func getCachedForumPosts() async -> [CachedForumPost] {
        let context = coreData.viewContext
        let fetchRequest = NSFetchRequest<CachedForumPost>(entityName: "CachedForumPost")
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "isPinned", ascending: false),
            NSSortDescriptor(key: "createdAt", ascending: false)
        ]

        do {
            return try context.fetch(fetchRequest)
        } catch {
            logger.error("❌ [SYNC] Failed to fetch cached forum posts: \(error.localizedDescription)")
            return []
        }
    }

    /// Get cached forum post by ID
    func getCachedForumPost(id: Int64) async -> CachedForumPost? {
        let context = coreData.viewContext
        let fetchRequest = NSFetchRequest<CachedForumPost>(entityName: "CachedForumPost")
        fetchRequest.predicate = NSPredicate(format: "id == %lld", id)
        fetchRequest.fetchLimit = 1

        do {
            return try context.fetch(fetchRequest).first
        } catch {
            logger.error("❌ [SYNC] Failed to fetch cached forum post: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Pending Changes (Offline Queue)

    /// Queue a message to be sent when online
    func queueOfflineMessage(roomId: UUID, senderId: UUID, content: String) async {
        let context = coreData.newBackgroundContext()

        await context.perform {
            let message = CachedMessage(context: context)
            message.id = UUID()
            message.roomId = roomId
            message.senderId = senderId
            message.content = content
            message.createdAt = Date()
            message.cachedAt = Date()
            message.isSent = false

            do {
                try context.save()
                Task { @MainActor in
                    self.logger.info("📤 [SYNC] Message queued for offline send")
                }
            } catch {
                Task { @MainActor in
                    self.logger.error("❌ [SYNC] Failed to queue message: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Sync pending changes (messages, listings, etc.) when back online
    func syncPendingChanges() async {
        guard isOnline else { return }

        logger.info("🔄 [SYNC] Syncing pending changes...")

        // Push locally modified listings
        do {
            try await pushLocalChanges()
        } catch {
            logger.error("❌ [SYNC] Failed to push local listing changes: \(error.localizedDescription)")
        }

        // Send pending messages
        await syncPendingMessages()

        // Pull any remote updates
        do {
            try await syncListings()
            try await syncForumPosts()
        } catch {
            logger.error("❌ [SYNC] Failed to pull remote changes: \(error.localizedDescription)")
        }

        // Update conflict status
        await updatePendingConflictsCount()
    }

    private func syncPendingMessages() async {
        let context = coreData.newBackgroundContext()

        // Extract Sendable message data from Core Data context
        let pendingMessageData: [(id: UUID, roomId: UUID, senderId: UUID, content: String, createdAt: Date)] =
            await context.perform {
                let fetchRequest = NSFetchRequest<CachedMessage>(entityName: "CachedMessage")
                fetchRequest.predicate = NSPredicate(format: "isSent == NO")

                do {
                    let pendingMessages = try context.fetch(fetchRequest)
                    return pendingMessages.map { (
                        id: $0.id,
                        roomId: $0.roomId,
                        senderId: $0.senderId,
                        content: $0.content,
                        createdAt: $0.createdAt,
                    ) }
                } catch {
                    Task { @MainActor in
                        self.logger.error("❌ [SYNC] Failed to fetch pending messages: \(error.localizedDescription)")
                    }
                    return []
                }
            }

        // Process each message outside the Core Data context
        for messageData in pendingMessageData {
            do {
                // Send to Supabase
                try await supabase
                    .from("messages")
                    .insert([
                        "id": messageData.id.uuidString,
                        "room_id": messageData.roomId.uuidString,
                        "profile_id": messageData.senderId.uuidString,
                        "content": messageData.content,
                        "created_at": ISO8601DateFormatter().string(from: messageData.createdAt)
                    ])
                    .execute()

                // Mark as sent in Core Data
                await context.perform { [self] in
                    let fetchRequest = NSFetchRequest<CachedMessage>(entityName: "CachedMessage")
                    fetchRequest.predicate = NSPredicate(format: "id == %@", messageData.id as CVarArg)

                    do {
                        if let message = try context.fetch(fetchRequest).first {
                            message.isSent = true

                            do {
                                try context.save()
                            } catch {
                                Task { @MainActor [self] in
                                    logger.error("❌ [SYNC] Failed to save sent message status: \(error.localizedDescription)")
                                }
                            }
                        } else {
                            Task { @MainActor [self] in
                                logger.warning("⚠️ [SYNC] Message \(messageData.id) not found to mark as sent")
                            }
                        }
                    } catch {
                        Task { @MainActor [self] in
                            logger.error("❌ [SYNC] Failed to fetch message \(messageData.id) to mark as sent: \(error.localizedDescription)")
                        }
                    }
                }

                logger.info("✅ [SYNC] Pending message sent")
            } catch {
                logger.error("❌ [SYNC] Failed to send pending message: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Sync Metadata

    private func updateSyncMetadata(entityType: String) async {
        let context = coreData.newBackgroundContext()

        await context.perform {
            let fetchRequest = NSFetchRequest<SyncMetadata>(entityName: "SyncMetadata")
            fetchRequest.predicate = NSPredicate(format: "entityType == %@", entityType)

            do {
                let existing = try context.fetch(fetchRequest).first

                if let metadata = existing {
                    metadata.lastSyncedAt = Date()
                } else {
                    let metadata = SyncMetadata(context: context)
                    metadata.entityType = entityType
                    metadata.lastSyncedAt = Date()
                }

                try context.save()
            } catch {
                Task { @MainActor in
                    self.logger.error("❌ [SYNC] Failed to update sync metadata: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Check if cache is stale
    func isCacheStale(entityType: String) async -> Bool {
        let context = coreData.viewContext
        let fetchRequest = NSFetchRequest<SyncMetadata>(entityName: "SyncMetadata")
        fetchRequest.predicate = NSPredicate(format: "entityType == %@", entityType)

        do {
            guard let metadata = try context.fetch(fetchRequest).first else {
                return true // No metadata = never synced
            }

            let age = Date().timeIntervalSince(metadata.lastSyncedAt)
            return age > cacheExpirationInterval
        } catch {
            return true
        }
    }

    // MARK: - Cache Cleanup

    /// Remove expired cache entries
    func cleanupExpiredCache() async {
        let context = coreData.newBackgroundContext()
        let expirationDate = Date().addingTimeInterval(-cacheExpirationInterval)

        await context.perform { [self] in
            for entityName in ["CachedListing", "CachedProfile", "CachedMessage", "CachedForumPost", "CachedRoom"] {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                fetchRequest.predicate = NSPredicate(format: "cachedAt < %@", expirationDate as NSDate)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

                do {
                    try context.execute(deleteRequest)
                } catch {
                    Task { @MainActor [self] in
                        logger.error("❌ [SYNC] Failed to cleanup \(entityName): \(error.localizedDescription)")
                    }
                }
            }

            do {
                try context.save()
            } catch {
                Task { @MainActor [self] in
                    logger.error("❌ [SYNC] Failed to save cache cleanup changes: \(error.localizedDescription)")
                }
            }
        }

        logger.info("🧹 [SYNC] Expired cache cleaned up")
    }
}

// MARK: - Offline Status View Modifier

struct OfflineIndicator: ViewModifier {
    let syncManager: SyncManager

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if !syncManager.isOnline {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 12))
                    Text("Offline Mode")
                        .font(.DesignSystem.captionSmall)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Color.DesignSystem.warning)
                .clipShape(Capsule())
                .padding(.top, Spacing.xs)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: syncManager.isOnline)
            }
        }
    }
}

extension View {
    func offlineIndicator(_ syncManager: SyncManager = SyncManager.shared) -> some View {
        modifier(OfflineIndicator(syncManager: syncManager))
    }
}

#endif
