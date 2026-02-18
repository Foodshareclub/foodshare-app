//
//  FeedDataService.swift
//  FoodShare
//
//  Service layer for feed data operations including loading, caching, and trending.
//  Extracted from FeedViewModel to improve separation of concerns.
//



#if !SKIP
#if !SKIP
import CoreLocation
#endif
import Foundation
import OSLog

// MARK: - Feed Data Service Protocol

/// Protocol for feed data operations, enabling testability
@MainActor
protocol FeedDataServiceProtocol {
    /// Fetches food items near a location
    /// - Parameters:
    ///   - location: The center location for the search
    ///   - radiusKm: Search radius in kilometers
    ///   - limit: Maximum number of items to return
    ///   - offset: Pagination offset
    ///   - postType: Optional filter by post type
    /// - Returns: Array of food items
    func loadItems(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
        offset: Int,
        postType: String?
    ) async throws -> [FoodItem]

    /// Fetches trending items based on engagement
    /// - Parameters:
    ///   - location: The center location for the search
    ///   - radiusKm: Search radius in kilometers
    ///   - limit: Maximum number of items to return
    /// - Returns: Array of trending food items
    func loadTrending(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int
    ) async throws -> [FoodItem]

    /// Fetches all available categories
    /// - Returns: Array of categories
    func loadCategories() async throws -> [Category]

    /// Checks if cached data is still valid
    /// - Parameter lastFetchTime: The time of the last fetch
    /// - Returns: True if cache is still valid
    func isCacheValid(lastFetchTime: Date?) -> Bool

    /// Clears any cached data
    func clearCache()
}

// MARK: - Feed Data Service

/// Default implementation of FeedDataServiceProtocol
@MainActor
final class FeedDataService: FeedDataServiceProtocol {
    // MARK: - Dependencies

    private let fetchNearbyItemsUseCase: FetchNearbyItemsUseCase
    private let fetchCategoriesUseCase: FetchCategoriesUseCase
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "FeedDataService")

    // MARK: - Cache

    private struct CacheEntry {
        let items: [FoodItem]
        let timestamp: Date
    }

    private var itemCache: [String: CacheEntry] = [:]
    private var categoriesCache: [Category]?
    private var trendingCache: CacheEntry?

    private var cacheValidityDuration: TimeInterval {
        AppConfiguration.shared.feedCacheTTL
    }

    // MARK: - Initialization

    init(
        fetchNearbyItemsUseCase: FetchNearbyItemsUseCase,
        fetchCategoriesUseCase: FetchCategoriesUseCase
    ) {
        self.fetchNearbyItemsUseCase = fetchNearbyItemsUseCase
        self.fetchCategoriesUseCase = fetchCategoriesUseCase
    }

    // MARK: - FeedDataServiceProtocol

    func loadItems(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
        offset: Int,
        postType: String?
    ) async throws -> [FoodItem] {
        let cacheKey = makeCacheKey(location: location, radiusKm: radiusKm, offset: offset, postType: postType)

        if let cached = getCachedItems(key: cacheKey) {
            return cached
        }

        let items = try await fetchNearbyItemsUseCase.execute(
            location: location,
            radiusKm: radiusKm,
            limit: limit,
            offset: offset,
            postType: postType
        )

        updateCache(key: cacheKey, items: items)

        return items
    }

    func loadTrending(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int
    ) async throws -> [FoodItem] {
        if let cached = getCachedTrending() {
            return cached
        }

        let items = try await fetchNearbyItemsUseCase.fetchTrending(
            location: location,
            radiusKm: radiusKm,
            limit: limit
        )

        updateTrendingCache(items: items)

        return items
    }

    func loadCategories() async throws -> [Category] {
        if let cached = getCachedCategories() {
            return cached
        }

        let categories = try await fetchCategoriesUseCase.execute()
        updateCategoriesCache(categories: categories)

        return categories
    }

    func isCacheValid(lastFetchTime: Date?) -> Bool {
        guard let lastFetch = lastFetchTime else { return false }
        let elapsed = Date().timeIntervalSince(lastFetch)
        return elapsed < cacheValidityDuration
    }

    func clearCache() {
        itemCache.removeAll()
        categoriesCache = nil
        trendingCache = nil
        logger.debug("Cache cleared")
    }

    // MARK: - Cache Helpers

    private func makeCacheKey(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        offset: Int,
        postType: String?
    ) -> String {
        let lat = String(format: "%.2f", location.latitude)
        let lng = String(format: "%.2f", location.longitude)
        return "\(lat)_\(lng)_\(radiusKm)_\(offset)_\(postType ?? "all")"
    }

    private func getCachedItems(key: String) -> [FoodItem]? {
        guard let entry = itemCache[key] else { return nil }
        guard isCacheValid(lastFetchTime: entry.timestamp) else {
            itemCache.removeValue(forKey: key)
            return nil
        }
        return entry.items
    }

    private func getCachedTrending() -> [FoodItem]? {
        guard let entry = trendingCache else { return nil }
        guard isCacheValid(lastFetchTime: entry.timestamp) else {
            trendingCache = nil
            return nil
        }
        return entry.items
    }

    private func getCachedCategories() -> [Category]? {
        categoriesCache
    }

    private func updateCache(key: String, items: [FoodItem]) {
        itemCache[key] = CacheEntry(items: items, timestamp: Date())
    }

    private func updateTrendingCache(items: [FoodItem]) {
        trendingCache = CacheEntry(items: items, timestamp: Date())
    }

    private func updateCategoriesCache(categories: [Category]) {
        categoriesCache = categories
    }
}

// MARK: - Feed Data Service Error

enum FeedDataError: Error, LocalizedError {
    case noLocation
    case networkError(String)
    case cacheError

    var errorDescription: String? {
        switch self {
        case .noLocation:
            return "Location not available"
        case .networkError(let message):
            return message
        case .cacheError:
            return "Failed to access cache"
        }
    }
}


#endif
