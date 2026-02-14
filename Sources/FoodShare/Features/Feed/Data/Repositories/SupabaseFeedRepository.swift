//
//  SupabaseFeedRepository.swift
//  Foodshare
//
//  Supabase implementation of FeedRepository with offline-first support
//  Maps to `posts` table in Supabase with CoreData caching
//

#if !SKIP
import CoreData
#endif
import FoodShareRepository
import Foundation
import OSLog
import Supabase

// MARK: - Repository Implementation

/// Supabase implementation of feed repository with offline-first support
/// Queries the `posts` table with PostGIS geography support
/// Thread-safe with @MainActor isolation for UI state updates
/// Uses CoreData caching for offline functionality
@MainActor
final class SupabaseFeedRepository: BaseSupabaseRepository, FeedRepository {
    private let coreDataStack: CoreDataStack
    private let networkMonitor: NetworkMonitor
    private let productsAPI: ProductsAPIService

    /// Allowed cursor columns for pagination (SQL injection prevention)
    private static let allowedCursorColumns: Set<String> = ["created_at", "updated_at", "id", "post_views"]

    /// Cache configuration for listings
    private let cacheConfiguration = CacheConfiguration.default

    init(
        supabase: Supabase.SupabaseClient,
        productsAPI: ProductsAPIService = .shared,
        coreDataStack: CoreDataStack = .shared,
        networkMonitor: NetworkMonitor = .shared,
    ) {
        self.productsAPI = productsAPI
        self.coreDataStack = coreDataStack
        self.networkMonitor = networkMonitor
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "FeedRepository")
    }

    // MARK: - Cache Policy Selection

    /// Determines the appropriate cache policy based on network state
    private var currentCachePolicy: CachePolicy {
        if networkMonitor.isOffline {
            .cacheOnly
        } else if networkMonitor.isConstrained {
            // Low data mode: prefer cache
            .cacheFirst
        } else {
            // Normal connectivity: remote first with cache fallback
            .cacheFallback
        }
    }

    /// Validates cursor column to prevent SQL injection
    private func validateCursorColumn(_ column: String) throws {
        guard Self.allowedCursorColumns.contains(column) else {
            throw AppError.validationError("Invalid cursor column: \(column)")
        }
    }

    // MARK: - Fetch Listings (Cursor-Based)

    @inline(__always)
    func fetchListings(
        near location: Location,
        radius: Double,
        pagination: CursorPaginationParams,
        excludeBlockedUsers: Bool = true,
    ) async throws -> [FoodItem] {
        logger
            .info(
                "📍 Fetching listings near \(location.latitude), \(location.longitude)",
            )

        let dtos = try await productsAPI.getNearbyProducts(
            lat: location.latitude,
            lng: location.longitude,
            radiusKm: radius,
            limit: pagination.limit,
            cursor: pagination.cursor,
        )

        let items = dtos.map { $0.toFoodItem() }
        logger.info("✅ Loaded \(items.count) location-filtered items")
        return items
    }

    @inline(__always)
    func fetchListings(
        categoryId: Int,
        near location: Location,
        radius: Double,
        pagination: CursorPaginationParams,
        excludeBlockedUsers: Bool = true,
    ) async throws -> [FoodItem] {
        do {
            let dtos = try await productsAPI.getNearbyProducts(
                lat: location.latitude,
                lng: location.longitude,
                radiusKm: radius,
                categoryId: categoryId,
                limit: pagination.limit,
                cursor: pagination.cursor,
            )
            return dtos.map { $0.toFoodItem() }
        } catch {
            // Fallback to direct query if API fails
            return try await fetchListingsDirect(categoryId: categoryId, pagination: pagination)
        }
    }

    // MARK: - Fetch Listings (Offset-Based Legacy)

    @inline(__always)
    func fetchListings(
        near location: Location,
        radius: Double,
        limit: Int,
        offset: Int,
        excludeBlockedUsers: Bool = true,
    ) async throws -> [FoodItem] {
        let dtos = try await productsAPI.getNearbyProducts(
            lat: location.latitude,
            lng: location.longitude,
            radiusKm: radius,
            limit: limit,
        )
        return dtos.map { $0.toFoodItem() }
    }

    @inline(__always)
    func fetchListings(
        categoryId: Int,
        near location: Location,
        radius: Double,
        limit: Int,
        offset: Int,
        excludeBlockedUsers: Bool = true,
    ) async throws -> [FoodItem] {
        do {
            let dtos = try await productsAPI.getNearbyProducts(
                lat: location.latitude,
                lng: location.longitude,
                radiusKm: radius,
                categoryId: categoryId,
                limit: limit,
            )
            return dtos.map { $0.toFoodItem() }
        } catch {
            // Fallback to direct query if API fails
            return try await fetchListingsDirect(categoryId: categoryId, limit: limit, offset: offset)
        }
    }

    /// Direct query fallback with cursor-based pagination
    private func fetchListingsDirect(
        categoryId: Int? = nil,
        pagination: CursorPaginationParams,
    ) async throws -> [FoodItem] {
        // Validate cursor column to prevent SQL injection
        try validateCursorColumn(pagination.cursorColumn)

        // Use posts_with_location view to get extracted latitude/longitude coordinates
        var query = supabase
            .from("posts_with_location")
            .select("""
                id,
                profile_id,
                post_name,
                post_description,
                post_type,
                pickup_time,
                available_hours,
                post_address,
                latitude,
                longitude,
                images,
                is_active,
                is_arranged,
                post_arranged_to,
                post_arranged_at,
                post_views,
                post_like_counter,
                has_pantry,
                condition,
                network,
                website,
                donation,
                donation_rules,
                category_id,
                created_at,
                updated_at
            """)
            .eq("is_active", value: true)
            .eq("is_arranged", value: false)

        // Apply category filter if provided
        if let categoryId {
            query = query.eq("category_id", value: categoryId)
        }

        // Apply cursor-based pagination
        if let cursor = pagination.cursor {
            let comparison = pagination.direction == .backward ? "lt" : "gt"
            query = query.filter(pagination.cursorColumn, operator: comparison, value: cursor)
        }

        let ascending = pagination.direction == .forward

        let response = try await query
            .order(pagination.cursorColumn, ascending: ascending)
            .limit(pagination.limit)
            .execute()

        return try decoder.decode([FoodItem].self, from: response.data)
    }

    /// Direct query fallback when RPC functions aren't available (offset-based)
    private func fetchListingsDirect(
        categoryId: Int? = nil,
        limit: Int,
        offset: Int,
    ) async throws -> [FoodItem] {
        // Build query with filters first, then apply ordering and pagination
        // Use posts_with_location view to get extracted latitude/longitude coordinates
        var query = supabase
            .from("posts_with_location")
            .select("""
                id,
                profile_id,
                post_name,
                post_description,
                post_type,
                pickup_time,
                available_hours,
                post_address,
                latitude,
                longitude,
                images,
                is_active,
                is_arranged,
                post_arranged_to,
                post_arranged_at,
                post_views,
                post_like_counter,
                has_pantry,
                condition,
                network,
                website,
                donation,
                donation_rules,
                category_id,
                created_at,
                updated_at
            """)
            .eq("is_active", value: true)
            .eq("is_arranged", value: false)

        // Apply category filter if provided
        if let categoryId {
            query = query.eq("category_id", value: categoryId)
        }

        // Apply ordering and pagination
        let response = try await query
            .order("created_at", ascending: false)
            .limit(limit)
            .range(from: offset, to: offset + limit - 1)
            .execute()

        return try decoder.decode([FoodItem].self, from: response.data)
    }

    // MARK: - Fetch Categories

    func fetchCategories() async throws -> [Category] {
        // Use global CategoriesCache for app-wide category caching
        // This eliminates duplicate fetches across Feed, Forum, Search, and Map
        try await CategoriesCache.shared.getCategories()
    }

    // MARK: - Fetch Single Listing

    func fetchListing(id: Int) async throws -> FoodItem {
        do {
            let dto = try await productsAPI.getProduct(id: id)
            return dto.toFoodItem()
        } catch {
            // Fallback to direct Supabase query
            return try await fetchOne(from: "posts_with_location", id: id)
        }
    }

    // MARK: - Increment View Count

    func incrementViewCount(listingId: Int) async throws {
        await PostViewService.shared.recordView(postId: listingId)
    }

    // MARK: - Fetch Community Fridges

    func fetchCommunityFridges(
        near location: Location,
        radius: Double,
        limit: Int,
    ) async throws -> [CommunityFridge] {
        let dtos = try await productsAPI.getNearbyProducts(
            lat: location.latitude,
            lng: location.longitude,
            radiusKm: radius,
            postType: "fridge",
            limit: limit,
        )
        return dtos.map { $0.toFoodItem() }.map { CommunityFridge(from: $0) }
    }

    // MARK: - Offline-First Operations

    /// Fetch listings using offline-first pattern
    /// Uses OfflineFirstDataSource to intelligently select data source
    func fetchListingsOfflineFirst(
        near location: Location,
        radius: Double,
        pagination: CursorPaginationParams,
    ) async throws -> OfflineDataResult<FoodItem> {
        let dataSource = OfflineFirstDataSource<FoodItem, FoodItem>(
            configuration: cacheConfiguration,
            fetchLocal: { [weak self] in
                guard let self else { return [] }
                return await fetchCachedListings()
            },
            fetchRemote: { [weak self] in
                guard let self else { return [] }
                return try await fetchListings(
                    near: location,
                    radius: radius,
                    pagination: pagination,
                )
            },
            saveToCache: { [weak self] items in
                guard let self else { return }
                await cacheListings(items)
            },
        )

        let result = try await dataSource.fetch(policy: currentCachePolicy)

        // Log cache usage for debugging
        switch result {
        case .fresh:
            logger.debug("📡 [Feed] Fetched fresh data from remote")
        case let .cached(_, lastSyncedAt):
            let syncInfo = lastSyncedAt.map { "last synced: \($0)" } ?? "unknown sync time"
            logger.debug("📦 [Feed] Using cached data (\(syncInfo))")
        case .empty:
            logger.debug("⚠️ [Feed] No data available (cache empty, offline)")
        }

        return result
    }

    // MARK: - Core Data Cache Operations

    /// Fetch listings from local Core Data cache
    private func fetchCachedListings() async -> [FoodItem] {
        let context = coreDataStack.viewContext
        let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]

        // Only return non-arranged, active items
        fetchRequest.predicate = NSPredicate(format: "isArranged == NO")

        do {
            let cachedItems = try context.fetch(fetchRequest)
            return cachedItems.map { convertToFoodItem($0) }
        } catch {
            logger.error("❌ [Feed] Failed to fetch cached listings: \(error.localizedDescription)")
            return []
        }
    }

    /// Save listings to Core Data cache
    /// Note: Uses nonisolated method to work with NSManagedObjectContext safely
    private func cacheListings(_ items: [FoodItem]) async {
        let context = coreDataStack.newBackgroundContext()
        let itemCount = items.count
        let logger = Logger(subsystem: Constants.bundleIdentifier, category: "Feed")

        // Track errors to log after perform block
        var cacheErrors: [(Int, String)] = []
        var saveError: String?
        var saveSuccess = false

        // Perform all CoreData operations within the context's perform block
        await context.perform {
            for item in items {
                // Upsert: check if exists first
                let fetchRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
                fetchRequest.predicate = NSPredicate(format: "id == %lld", item.id)

                do {
                    let existing = try context.fetch(fetchRequest).first
                    let cached = existing ?? CachedListing(context: context)

                    // Inline update to avoid actor isolation issues
                    cached.id = Int64(item.id)
                    cached.name = item.postName
                    cached.descriptionText = item.postDescription
                    cached.address = item.postAddress
                    cached.latitude = item.latitude ?? 0
                    cached.longitude = item.longitude ?? 0
                    cached.imagesData = (try? JSONEncoder().encode(item.images ?? [])) ?? Data()
                    cached.category = item.categoryId.map { String($0) }
                    cached.profileId = item.profileId
                    cached.isArranged = item.isArranged
                    cached.createdAt = item.createdAt
                    cached.updatedAt = item.updatedAt
                    cached.cachedAt = Date()
                } catch {
                    cacheErrors.append((item.id, error.localizedDescription))
                }
            }

            // Update sync metadata inline
            let metadataRequest = NSFetchRequest<SyncMetadata>(entityName: "SyncMetadata")
            metadataRequest.predicate = NSPredicate(format: "entityType == %@", "listings")

            do {
                let existing = try context.fetch(metadataRequest).first
                let metadata = existing ?? SyncMetadata(context: context)
                metadata.entityType = "listings"
                metadata.lastSyncedAt = Date()
            } catch {
                // Non-critical, ignore
            }

            do {
                try context.save()
                saveSuccess = true
            } catch {
                saveError = error.localizedDescription
            }
        }

        // Log results after perform block completes
        for (itemId, errorMsg) in cacheErrors {
            logger.warning("[Feed] Failed to cache listing \(itemId): \(errorMsg)")
        }

        if saveSuccess {
            logger.debug("[Feed] Cached \(itemCount) listings")
        } else if let error = saveError {
            logger.error("[Feed] Failed to save cache: \(error)")
        }
    }

    /// Convert CachedListing to FoodItem
    private func convertToFoodItem(_ cached: CachedListing) -> FoodItem {
        FoodItem(
            id: Int(cached.id),
            profileId: cached.profileId,
            postName: cached.name,
            postDescription: cached.descriptionText,
            postType: "food", // Default - could store in cache
            pickupTime: nil,
            availableHours: nil,
            postAddress: cached.address,
            postStrippedAddress: nil, // Not stored in cache
            latitude: cached.latitude != 0 ? cached.latitude : nil,
            longitude: cached.longitude != 0 ? cached.longitude : nil,
            images: cached.images.isEmpty ? nil : cached.images,
            isActive: true,
            isArranged: cached.isArranged,
            postArrangedTo: nil,
            postArrangedAt: nil,
            postViews: 0,
            postLikeCounter: nil,
            hasPantry: nil,
            foodStatus: nil,
            network: nil,
            website: nil,
            donation: nil,
            donationRules: nil,
            categoryId: cached.category.flatMap { Int($0) },
            createdAt: cached.createdAt,
            updatedAt: cached.updatedAt,
            distanceMeters: nil,
        )
    }

    // MARK: - Cache Management

    /// Clear expired cache entries
    func clearExpiredCache() async {
        let context = coreDataStack.newBackgroundContext()
        let expirationDate = Date().addingTimeInterval(-cacheConfiguration.maxAge)

        await context.perform {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "CachedListing")
            fetchRequest.predicate = NSPredicate(format: "cachedAt < %@", expirationDate as NSDate)

            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)

            do {
                let result = try context.execute(deleteRequest) as? NSBatchDeleteResult
                let deletedCount = result?.result as? Int ?? 0
                Task { @MainActor in
                    self.logger.debug("🧹 [Feed] Cleared \(deletedCount) expired cache entries")
                }
            } catch {
                Task { @MainActor in
                    self.logger.error("❌ [Feed] Failed to clear expired cache: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Get cache statistics
    func getCacheStats() async -> (count: Int, lastSyncedAt: Date?) {
        let context = coreDataStack.viewContext

        let countRequest = NSFetchRequest<CachedListing>(entityName: "CachedListing")
        let syncRequest = NSFetchRequest<SyncMetadata>(entityName: "SyncMetadata")
        syncRequest.predicate = NSPredicate(format: "entityType == %@", "listings")

        do {
            let count = try context.count(for: countRequest)
            let syncMetadata = try context.fetch(syncRequest).first
            return (count, syncMetadata?.lastSyncedAt)
        } catch {
            return (0, nil)
        }
    }

    // MARK: - Fetch Initial Data

    func fetchInitialData(
        location: Location,
        radius: Double,
        feedLimit: Int,
        trendingLimit: Int,
        postType: String?,
        categoryId: Int?,
    ) async throws -> FeedInitialData {
        do {
            // Fetch categories and feed data concurrently
            async let categoriesTask = CategoriesCache.shared.getCategories()
            async let feedTask = productsAPI.getFeed(
                lat: location.latitude,
                lng: location.longitude,
                radiusKm: radius,
                limit: feedLimit,
            )

            let (categories, feedResponse) = try await (categoriesTask, feedTask)

            // Map ProductDTOs to FoodItem domain models
            let feedItems = feedResponse.listings.map { $0.toFoodItem() }

            // Trending items: use the same feed items sorted by views (API doesn't have a separate trending endpoint)
            let trendingItems = Array(
                feedItems
                    .sorted { $0.postViews > $1.postViews }
                    .prefix(trendingLimit)
            )

            // Map counts from FeedCountsDTO
            let counts = feedResponse.counts
            let stats = FeedStats(
                totalItems: counts?.total ?? feedItems.count,
                availableItems: counts?.total ?? feedItems.count,
                expiringSoonItems: counts?.urgent ?? 0,
                categoryBreakdown: [
                    "food": counts?.food ?? 0,
                    "fridge": counts?.fridge ?? 0,
                ],
                lastUpdated: Date(),
            )

            logger
                .info(
                    "Fetched initial data: \(categories.count) categories, \(feedItems.count) items, \(trendingItems.count) trending",
                )

            return FeedInitialData(
                categories: categories,
                feedItems: feedItems,
                trendingItems: trendingItems,
                stats: stats,
            )
        } catch {
            throw mapError(error)
        }
    }
}
