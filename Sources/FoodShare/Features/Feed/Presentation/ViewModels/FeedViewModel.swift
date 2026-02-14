//
//  FeedViewModel.swift
//  Foodshare
//
//  ViewModel for food feed — delegates to extracted services for data loading,
//  translation, preferences, search filtering, and search radius management.
//

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
            logger.warning("No user location available")
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
        let categoryBreakdown = Dictionary(grouping: foodItems) { $0.postType }
            .mapValues(\.count)

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
        Dictionary(grouping: filteredListings) { $0.postType }
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
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
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
