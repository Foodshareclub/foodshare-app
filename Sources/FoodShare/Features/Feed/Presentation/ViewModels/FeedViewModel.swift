//
//  FeedViewModel.swift
//  Foodshare
//
//  ViewModel for food feed — delegates to extracted services for data loading,
//  translation, preferences, search filtering, and search radius management.
//



#if !SKIP
#if !SKIP
import CoreLocation
#endif
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class FeedViewModel {
    // MARK: - State (what the UI displays)

    var foodItems: [FoodItem] = []
    var categories: [Category] = []
    var communityFridges: [CommunityFridge] = []
    var selectedCategory: Category?
    var isLoading = false
    var isRefreshing = false
    var isLoadingMore = false
    var hasMoreItems = true
    var error: AppError?
    var showError = false // Only for user-initiated action failures
    var loadingFailed = false // For background loading failures - shows inline empty state

    // MARK: - Enhanced State

    var trendingItems: [FoodItem] = []
    var nearbyFridges: [CommunityFridge] = []

    // MARK: - Search State

    var searchQuery = ""
    var isSearching = false

    // MARK: - Personalization State

    var viewedItems: Set<Int> = []

    // MARK: - Analytics State

    var feedStats: FeedStats = .empty

    // MARK: - Pagination

    private var pageSize: Int {
        AppConfiguration.shared.pageSize
    }
    private var currentPage = 0

    /// Track if a prefetch is already in progress to prevent duplicate requests
    private var isPrefetching = false

    /// Prefetch threshold: trigger prefetch when user views item at 80% of list
    private let prefetchThreshold = 0.8

    // MARK: - Cache

    private var lastFetchTime: Date?
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "FeedViewModel")

    // MARK: - Dependencies (injected services)

    private let dataService: any FeedDataServiceProtocol
    private let translationService: any FeedTranslationServiceProtocol
    private let searchRadiusService: FeedSearchRadiusService
    private let preferencesService: any FeedPreferencesServiceProtocol
    private let searchService: any FeedSearchServiceProtocol
    private var userLocation: CLLocationCoordinate2D?

    // MARK: - Search Radius (delegated to searchRadiusService)

    var searchRadiusState: FeedSearchRadiusService.State {
        searchRadiusService.state
    }

    var searchRadius: Double {
        searchRadiusService.state.radius
    }

    var isSearchRadiusReady: Bool {
        searchRadiusService.state.isReady
    }

    // MARK: - View Mode & Sort (delegated to preferencesService)

    var viewMode: FeedViewMode {
        preferencesService.viewMode
    }

    var sortOption: FeedSortOption {
        preferencesService.sortOption
    }

    var savedItems: Set<Int> {
        preferencesService.savedItems
    }

    var preferredCategories: [Int] {
        preferencesService.preferredCategories
    }

    // MARK: - Initialization (dependency injection)

    init(
        dataService: any FeedDataServiceProtocol,
        translationService: any FeedTranslationServiceProtocol,
        searchRadiusService: FeedSearchRadiusService,
        preferencesService: any FeedPreferencesServiceProtocol,
        searchService: any FeedSearchServiceProtocol = FeedSearchService(),
    ) {
        self.dataService = dataService
        self.translationService = translationService
        self.searchRadiusService = searchRadiusService
        self.preferencesService = preferencesService
        self.searchService = searchService
    }

    // MARK: - Actions (what the UI can trigger)

    func loadInitialData(latitude: Double, longitude: Double) async {
        logger.notice("📍 loadInitialData() called with lat=\(latitude), lng=\(longitude)")
        userLocation = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // Load search radius from database first (if authenticated)
        await searchRadiusService.loadFromDatabase()

        // Load data in parallel for faster startup
        async let categoriesTask: () = loadCategories()
        async let itemsTask: () = loadFoodItems()
        async let trendingTask: () = loadTrendingItems()

        _ = await (categoriesTask, itemsTask, trendingTask)

        // Fetch translations for loaded items (non-blocking)
        var itemsToTranslate = foodItems
        await translationService.translateItems(&itemsToTranslate)
        foodItems = itemsToTranslate

        // Calculate feed stats after loading
        updateFeedStats()
        logger.notice("📍 loadInitialData() completed with \(self.foodItems.count) items")
    }

    func loadFoodItems(forceRefresh: Bool = false) async {
        guard let location = userLocation else {
            logger.info("No user location — loading recent items globally")
            await loadRecentItemsFallback()
            return
        }
        guard !isLoading else {
            logger.debug("Already loading, skipping")
            return
        }

        // Check cache validity
        if !forceRefresh, let lastFetch = lastFetchTime, !foodItems.isEmpty {
            if dataService.isCacheValid(lastFetchTime: lastFetch) {
                logger.debug("Using cached data")
                return
            }
        }

        isLoading = true
        error = nil
        currentPage = 0
        defer {
            isLoading = false
            lastFetchTime = Date()
        }

        do {
            logger.info("Fetching nearby items with postType=\(self.selectedPostType ?? "all")...")
            let items = try await dataService.loadItems(
                location: location,
                radiusKm: searchRadius,
                limit: pageSize,
                offset: 0,
                postType: selectedPostType
            )
            logger.info("Received \(items.count) items")

            if items.isEmpty {
                // Progressively expand radius instead of showing all posts globally
                let expandedRadii: [Double] = [50, 200, 800]
                for radius in expandedRadii where radius > searchRadius {
                    let expanded = try await dataService.loadItems(
                        location: location,
                        radiusKm: radius,
                        limit: pageSize,
                        offset: 0,
                        postType: selectedPostType
                    )
                    if !expanded.isEmpty {
                        logger.info("Found \(expanded.count) items at expanded radius \(radius)km")
                        foodItems = expanded
                        hasMoreItems = expanded.count >= pageSize
                        var itemsToTranslate = foodItems
                        await translationService.translateItems(&itemsToTranslate)
                        foodItems = itemsToTranslate
                        updateFeedStats()
                        return
                    }
                }
                logger.info("No listings found even at max expanded radius")
                return
            }

            foodItems = items
            hasMoreItems = items.count >= pageSize

            // Fetch translations for loaded items
            var itemsToTranslate = foodItems
            await translationService.translateItems(&itemsToTranslate)
            foodItems = itemsToTranslate

            updateFeedStats()
        } catch is CancellationError {
            logger.debug("Request cancelled - ignoring")
        } catch let feedError as FeedError {
            logger.error("FeedError: \(feedError.localizedDescription)")
            self.error = .networkError(feedError.localizedDescription)
            loadingFailed = true
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                logger.debug("URL request cancelled - ignoring")
                return
            }
            logger.error("Error: \(error.localizedDescription)")
            self.error = .networkError(error.localizedDescription)
            loadingFailed = true
        }
    }

    /// Load initial data without location (shows recent listings globally)
    func loadInitialDataWithoutLocation() async {
        logger.notice("📍 loadInitialDataWithoutLocation() — loading categories + recent items")
        await searchRadiusService.loadFromDatabase()

        async let categoriesTask: () = loadCategories()
        async let itemsTask: () = loadRecentItemsFallback()
        _ = await (categoriesTask, itemsTask)

        updateFeedStats()
        logger.notice("📍 loadInitialDataWithoutLocation() completed with \(self.foodItems.count) items")
    }

    private func loadRecentItemsFallback() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        currentPage = 0
        defer {
            isLoading = false
            lastFetchTime = Date()
        }

        do {
            logger.info("Fetching recent items without location...")
            let items = try await dataService.loadRecentItems(
                limit: pageSize,
                offset: 0,
                postType: selectedPostType
            )
            logger.info("Received \(items.count) recent items (global fallback)")
            foodItems = items
            hasMoreItems = items.count >= pageSize

            var itemsToTranslate = foodItems
            await translationService.translateItems(&itemsToTranslate)
            foodItems = itemsToTranslate

            updateFeedStats()
        } catch is CancellationError {
            logger.debug("Recent items request cancelled")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            logger.error("Failed to load recent items: \(error.localizedDescription)")
            self.error = .networkError(error.localizedDescription)
            loadingFailed = true
        }
    }

    func loadMoreItems() async {
        guard let location = userLocation else { return }
        guard !isLoadingMore, !isLoading, hasMoreItems else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let nextPage = currentPage + 1
            let offset = nextPage * pageSize
            let newItems = try await dataService.loadItems(
                location: location,
                radiusKm: searchRadius,
                limit: pageSize,
                offset: offset,
                postType: selectedPostType
            )

            foodItems.append(contentsOf: newItems)
            currentPage = nextPage
            hasMoreItems = newItems.count >= pageSize

            // Fetch translations for newly loaded items
            var mutableNewItems = newItems
            await translationService.translateItems(&mutableNewItems)
            // Apply translated items back
            for item in mutableNewItems where item.translationLocale != nil {
                if let index = foodItems.firstIndex(where: { $0.id == item.id }) {
                    foodItems[index] = item
                }
            }

            updateFeedStats()
            logger.debug("Loaded page \(nextPage) with \(newItems.count) items")
        } catch is CancellationError {
            logger.debug("Load more request cancelled - ignoring")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            logger.warning("Failed to load more items: \(error.localizedDescription)")
        }
    }

    /// Check if prefetching should be triggered based on visible item index.
    func onItemAppeared(at index: Int) {
        ImagePrefetchService.shared.prefetchAhead(
            visibleIndex: index,
            allItems: foodItems,
            prefetchCount: 5
        )

        guard hasMoreItems, !isLoadingMore, !isPrefetching else { return }

        let thresholdIndex = Int(Double(foodItems.count) * prefetchThreshold)

        if index >= thresholdIndex {
            isPrefetching = true
            Task {
                await loadMoreItems()
                isPrefetching = false
            }
        }
    }

    func loadTrendingItems() async {
        guard let location = userLocation else { return }

        do {
            let trendingRadius = min(searchRadius * 2, AppConfiguration.shared.maxSearchRadiusKm)
            let items = try await dataService.loadTrending(
                location: location,
                radiusKm: trendingRadius,
                limit: 5
            )
            trendingItems = items
            logger.debug("Loaded \(self.trendingItems.count) trending items from server")
        } catch is CancellationError {
            logger.debug("Trending items request cancelled - ignoring")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            logger.warning("Failed to load trending items: \(error.localizedDescription)")
        }
    }

    func loadCategories() async {
        do {
            categories = try await dataService.loadCategories()
        } catch is CancellationError {
            logger.debug("Categories request cancelled - ignoring")
        } catch {
            if (error as NSError).code == NSURLErrorCancelled { return }
            categories = []
            logger.warning("Failed to load categories: \(error.localizedDescription)")
        }
    }

    func selectCategory(_ category: Category?) {
        selectedCategory = category
        HapticManager.selection()
    }

    /// Filter by post type (ListingCategory from web app)
    private(set) var selectedPostType: String? = "food"

    func filterByPostType(_ postType: String?) async {
        guard postType != selectedPostType else { return }
        selectedPostType = postType
        await loadFoodItems(forceRefresh: true)
    }

    /// Search listings by title, description, or other criteria
    func searchListings(query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchQuery = trimmedQuery

        if trimmedQuery.isEmpty {
            isSearching = false
            return
        }

        isSearching = true
        logger.debug("Searching for: \(trimmedQuery)")
    }

    func updateSearchRadius(_ radius: Double) async {
        let maxRadius = AppConfiguration.shared.maxSearchRadiusKm
        let clampedRadius = min(max(radius, 1.0), maxRadius)

        // Optimistically update via service and reload feed
        async let feedLoadTask: () = loadFoodItems(forceRefresh: true)

        let success = await searchRadiusService.updateRadius(clampedRadius)

        if success {
            logger.info("Search radius synced: \(clampedRadius)km")
        } else {
            logger.warning("Search radius sync failed, using local storage only")
        }

        await feedLoadTask
    }

    func setViewMode(_ mode: FeedViewMode) {
        preferencesService.setViewMode(mode)
    }

    func setSortOption(_ option: FeedSortOption) {
        preferencesService.setSortOption(option)
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let itemsTask: () = loadFoodItems(forceRefresh: true)
        async let trendingTask: () = loadTrendingItems()
        _ = await (itemsTask, trendingTask)

        HapticManager.light()
    }

    func dismissError() {
        error = nil
        showError = false
        loadingFailed = false
    }

    /// Check if item is last for triggering load more
    func isLastItem(_ item: FoodItem) -> Bool {
        item.id == foodItems.last?.id
    }

    // MARK: - Personalization Actions

    func toggleSaveItem(_ itemId: Int) {
        _ = preferencesService.toggleSavedItem(itemId)
    }

    func markItemViewed(_ itemId: Int) {
        viewedItems.insert(itemId)
        if let item = foodItems.first(where: { $0.id == itemId }),
           let categoryId = item.categoryId
        {
            preferencesService.addPreferredCategory(categoryId)
        }
    }

    func isItemSaved(_ itemId: Int) -> Bool {
        savedItems.contains(itemId)
    }

    /// Load search radius from database for authenticated user
    func loadSearchRadiusFromDatabase() async {
        await searchRadiusService.loadFromDatabase()
    }

    // MARK: - Feed Stats

    private func updateFeedStats() {
        let available = foodItems.filter(\.isAvailable).count
        let expiringSoon = foodItems.count(where: { item in
            item.createdAt.timeIntervalSinceNow > -86400
        })
        var categoryBreakdown: [String: Int] = [:]
        for item in foodItems {
            categoryBreakdown[item.postType, default: 0] += 1
        }

        feedStats = FeedStats(
            totalItems: foodItems.count,
            availableItems: available,
            expiringSoonItems: expiringSoon,
            categoryBreakdown: categoryBreakdown,
            lastUpdated: Date(),
        )
    }

    // MARK: - Computed Properties

    var filteredListings: [FoodItem] {
        searchService.applyFilters(
            items: foodItems,
            query: isSearching ? searchQuery : "",
            category: selectedCategory,
            postType: selectedPostType,
            sortOption: sortOption
        )
    }

    var availableListings: [FoodItem] {
        filteredListings.filter(\.isAvailable)
    }

    var hasListings: Bool {
        !filteredListings.isEmpty
    }

    var errorMessage: String {
        error?.errorDescription ?? ""
    }

    /// Localized error message (use in Views with translation service)
    func localizedErrorMessage(using t: EnhancedTranslationService) -> String {
        error?.errorDescription ?? t.t("error.generic")
    }

    /// Group listings by post type
    var listingsByType: [String: [FoodItem]] {
        var result: [String: [FoodItem]] = [:]
        for item in filteredListings {
            result[item.postType, default: []].append(item)
        }
        return result
    }

    /// Food listings only (excludes fridges, foodbanks, etc.)
    var foodListingsOnly: [FoodItem] {
        filteredListings.filter { $0.postType == "food" }
    }

    /// Can load more items
    var canLoadMore: Bool {
        hasMoreItems && !isLoadingMore && !isLoading
    }

    /// Personalized recommendations based on viewing history
    var recommendedItems: [FoodItem] {
        guard !preferredCategories.isEmpty else { return [] }

        return foodItems
            .filter { item in
                guard let categoryId = item.categoryId else { return false }
                return preferredCategories.contains(categoryId) && !viewedItems.contains(item.id)
            }
            .prefix(5)
            .map(\.self)
    }

    /// Items expiring within 24 hours
    var urgentItems: [FoodItem] {
        foodItems.filter { item in
            let ageInSeconds = -item.createdAt.timeIntervalSinceNow
            return ageInSeconds > 172_800 && item.isAvailable
        }
    }

    /// Saved items from the feed
    var savedFoodItems: [FoodItem] {
        foodItems.filter { savedItems.contains($0.id) }
    }

    /// Has trending items to show
    var hasTrendingItems: Bool {
        !trendingItems.isEmpty
    }

    /// Has urgent items to highlight
    var hasUrgentItems: Bool {
        !urgentItems.isEmpty
    }
}

// MARK: - Feed Stats

struct FeedStats: Sendable {
    let totalItems: Int
    let availableItems: Int
    let expiringSoonItems: Int
    let categoryBreakdown: [String: Int]
    let lastUpdated: Date

    static let empty = FeedStats(
        totalItems: 0,
        availableItems: 0,
        expiringSoonItems: 0,
        categoryBreakdown: [:],
        lastUpdated: Date(),
    )

    var formattedLastUpdated: String {
        #if !SKIP
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
        #else
        let interval = Date().timeIntervalSince(lastUpdated)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        return "\(Int(interval / 86400))d ago"
        #endif
    }
}

// MARK: - Preview Support

extension FeedViewModel {
    /// Creates a FeedViewModel for SwiftUI previews
    static var preview: FeedViewModel {
        let deps = DependencyContainer.preview
        return FeedViewModel(
            dataService: deps.feedDataService,
            translationService: deps.feedTranslationService,
            searchRadiusService: FeedSearchRadiusService(
                profileRepository: nil,
                getCurrentUserId: { nil },
                isGuestMode: true
            ),
            preferencesService: deps.feedPreferencesService,
        )
    }
}


#else
// MARK: - Android FeedViewModel (Skip)

import Foundation
import Observation
import SwiftUI

// MARK: - Feed Stats (Android)

struct FeedStats {
    let totalItems: Int
    let availableItems: Int
    let expiringSoonItems: Int
    let categoryBreakdown: [String: Int]
    let lastUpdated: Date

    static let empty: FeedStats = FeedStats(
        totalItems: 0,
        availableItems: 0,
        expiringSoonItems: 0,
        categoryBreakdown: [:],
        lastUpdated: Date()
    )
}

// MARK: - Feed API Response DTOs

private struct FeedEnvelopeResponse: Decodable {
    let success: Bool
    let data: FeedDataResponse?
}

private struct FeedDataResponse: Decodable {
    let listings: [FoodItem]?
    let counts: FeedCountsResponse?
}

private struct FeedCountsResponse: Decodable {
    let total: Int?
    let food: Int?
    let fridge: Int?
    let urgent: Int?
}

private struct CategoriesEnvelopeResponse: Decodable {
    let success: Bool
    let data: [Category]?
}

// MARK: - FeedViewModel

@MainActor
@Observable
final class FeedViewModel {
    // MARK: - State

    var items: [FoodItem] = []
    var categories: [Category] = []
    var selectedCategory: Category?
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true
    var errorMessage: String?

    private let log = AppLog(category: "FeedViewModel")
    private let baseURL: String
    private let apiKey: String
    private var currentOffset = 0
    private let pageSize = 20

    // Default location (Sacramento, CA — fallback)
    private var lat: Double = 38.5816
    private var lng: Double = -121.4944
    private var radiusKm: Double = 25.0

    // MARK: - Initialization

    init() {
        self.baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        self.apiKey = AppEnvironment.supabasePublishableKey ?? ""
    }

    // MARK: - Public API

    func loadFeed() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        currentOffset = 0

        do {
            let feedItems = try await fetchFeedFromAPI(limit: pageSize, offset: 0)
            items = feedItems
            hasMore = feedItems.count >= pageSize
            log.info("Loaded \(feedItems.count) feed items")
        } catch {
            errorMessage = "Failed to load feed: \(error.localizedDescription)"
            log.error("Feed load failed: \(error.localizedDescription)")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true

        let nextOffset = currentOffset + pageSize
        do {
            let newItems = try await fetchFeedFromAPI(limit: pageSize, offset: nextOffset)
            items.append(contentsOf: newItems)
            currentOffset = nextOffset
            hasMore = newItems.count >= pageSize
        } catch {
            log.error("Load more failed: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    func refresh() async {
        currentOffset = 0
        hasMore = true
        await loadFeed()
    }

    func selectCategory(_ category: Category?) {
        selectedCategory = category
        Task { await refresh() }
    }

    func loadCategories() async {
        // Use static categories as fallback
        if categories.isEmpty {
            categories = Self.defaultCategories
        }
    }

    // MARK: - API Calls

    private func fetchFeedFromAPI(limit: Int, offset: Int) async throws -> [FoodItem] {
        var urlString = "\(baseURL)/functions/v1/api-v1-products?mode=feed&lat=\(lat)&lng=\(lng)&limit=\(limit)&radiusKm=\(radiusKm)"
        if let cat = selectedCategory {
            urlString = urlString + "&categoryId=\(cat.id)"
        }

        guard let url = URL(string: urlString) else {
            throw AppError.configurationError("Invalid feed URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        // Add auth token if available
        if AuthenticationService.shared.isAuthenticated {
            if let token = AuthenticationService.shared.accessToken {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AppError.networkError("Feed request failed")
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601

        let envelope = try decoder.decode(FeedEnvelopeResponse.self, from: data)
        return envelope.data?.listings ?? []
    }

    // MARK: - Default Categories

    private static let defaultCategories: [Category] = [
        Category(id: 1, name: "Produce", description: "Fresh fruits and vegetables", iconUrl: nil, color: "#2ECC71", sortOrder: 0, isActive: true, createdAt: Date()),
        Category(id: 2, name: "Dairy", description: "Milk, cheese, yogurt", iconUrl: nil, color: "#3498DB", sortOrder: 1, isActive: true, createdAt: Date()),
        Category(id: 3, name: "Baked Goods", description: "Bread, pastries", iconUrl: nil, color: "#E67E22", sortOrder: 2, isActive: true, createdAt: Date()),
        Category(id: 4, name: "Meat & Fish", description: "Meat and seafood", iconUrl: nil, color: "#E74C3C", sortOrder: 3, isActive: true, createdAt: Date()),
        Category(id: 5, name: "Pantry", description: "Canned and dry goods", iconUrl: nil, color: "#9B59B6", sortOrder: 4, isActive: true, createdAt: Date()),
        Category(id: 6, name: "Prepared Food", description: "Ready-to-eat meals", iconUrl: nil, color: "#F39C12", sortOrder: 5, isActive: true, createdAt: Date()),
        Category(id: 7, name: "Beverages", description: "Drinks", iconUrl: nil, color: "#1ABC9C", sortOrder: 6, isActive: true, createdAt: Date()),
        Category(id: 8, name: "Other", description: "Other items", iconUrl: nil, color: "#95A5A6", sortOrder: 7, isActive: true, createdAt: Date())
    ]

    // MARK: - Preview

    static var preview: FeedViewModel {
        return FeedViewModel()
    }
}

#endif
