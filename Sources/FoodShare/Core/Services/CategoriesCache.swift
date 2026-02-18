//
//  CategoriesCache.swift
//  Foodshare
//
//  Global actor-based cache for categories. Categories rarely change and are
//  used across multiple features (Feed, Forum, Search, Map). This centralizes
//  category caching to eliminate duplicate API calls.
//


#if !SKIP
import Foundation
import OSLog
import Supabase

/// Global actor-based cache for food categories.
///
/// Categories are fetched once and cached for 1 hour. All features share
/// the same cache, eliminating duplicate API calls when navigating between
/// Feed, Forum, Search, and Map screens.
///
/// Usage:
/// ```swift
/// let categories = await CategoriesCache.shared.getCategories()
/// ```
actor CategoriesCache {
    // MARK: - Singleton

    static let shared = CategoriesCache()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "CategoriesCache")

    /// Cached categories
    private var categories: [Category] = []

    /// When the cache was last populated
    private var lastFetchTime: Date?

    /// Cache TTL: 1 hour (categories rarely change)
    private let cacheTTL: TimeInterval = 3600

    /// In-flight fetch task to prevent duplicate requests
    private var fetchTask: Task<[Category], Error>?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Get categories from cache or fetch if stale/empty.
    ///
    /// This method is safe to call from multiple concurrent tasks.
    /// Only one fetch will occur even if called simultaneously.
    ///
    /// - Parameter forceRefresh: If true, bypasses cache and fetches fresh data
    /// - Returns: Array of categories
    func getCategories(forceRefresh: Bool = false) async throws -> [Category] {
        // Return cached if valid and not forcing refresh
        if !forceRefresh, isCacheValid {
            logger.debug("📦 Categories from cache (\(self.categories.count) items)")
            return categories
        }

        // If already fetching, wait for that task
        if let existingTask = fetchTask {
            logger.debug("⏳ Waiting for in-flight categories fetch")
            return try await existingTask.value
        }

        // Start new fetch
        let task = Task<[Category], Error> { [weak self] in
            guard let self else { throw CancellationError() }
            return try await self.fetchCategoriesFromAPI()
        }

        fetchTask = task

        do {
            let result = try await task.value
            fetchTask = nil
            return result
        } catch {
            fetchTask = nil
            throw error
        }
    }

    /// Get a specific category by ID.
    ///
    /// - Parameter id: Category ID to look up
    /// - Returns: Category if found, nil otherwise
    func getCategory(id: Int) async throws -> Category? {
        let allCategories = try await getCategories()
        return allCategories.first { $0.id == id }
    }

    /// Invalidate the cache, forcing next access to fetch fresh data.
    func invalidate() {
        categories = []
        lastFetchTime = nil
        logger.debug("🗑️ Categories cache invalidated")
    }

    /// Preload categories in background (called during cache warming).
    func preload() async {
        do {
            _ = try await getCategories()
        } catch {
            logger.warning("Failed to preload categories: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Implementation

    /// Check if cache is still valid
    private var isCacheValid: Bool {
        guard let lastFetch = lastFetchTime, !categories.isEmpty else {
            return false
        }
        return Date().timeIntervalSince(lastFetch) < cacheTTL
    }

    /// Fetch categories from the Supabase API
    private func fetchCategoriesFromAPI() async throws -> [Category] {
        logger.info("🌐 Fetching categories from API")
        let startTime = CFAbsoluteTimeGetCurrent()

        // Get client from MainActor-isolated SupabaseManager
        let client = await MainActor.run { SupabaseManager.shared.client }

        let response = try await client
            .from("categories")
            .select("*")
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()

        let fetchedCategories = try JSONDecoder().decode([Category].self, from: response.data)

        // Update cache
        categories = fetchedCategories
        lastFetchTime = Date()

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("✅ Fetched \(fetchedCategories.count) categories in \(String(format: "%.2f", elapsed))s")

        return fetchedCategories
    }
}

// MARK: - Category Extensions

extension CategoriesCache {
    /// Get categories filtered by a predicate.
    func getCategories(where predicate: @Sendable (Category) -> Bool) async throws -> [Category] {
        let allCategories = try await getCategories()
        return allCategories.filter(predicate)
    }

    /// Get category names as a dictionary for quick lookup.
    func getCategoryNames() async throws -> [Int: String] {
        let allCategories = try await getCategories()
        return Dictionary(uniqueKeysWithValues: allCategories.map { ($0.id, $0.name) })
    }
}

#endif
