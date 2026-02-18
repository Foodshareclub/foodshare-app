

#if !SKIP
import Foundation
import OSLog
import SwiftUI

private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ForumViewModel")

// MARK: - Forum ViewModel

@MainActor
@Observable
final class ForumViewModel {
    // MARK: - Properties

    var posts: [ForumPost] = []
    var pinnedPosts: [ForumPost] = []
    var trendingPosts: [ForumPost] = []
    var categories: [ForumCategory] = []
    var popularTags: [ForumTag] = []
    var filters = ForumFilters()

    var isLoading = false
    var isLoadingMore = false
    var isRefreshing = false
    var error: AppError?
    var showError = false // Only for user-initiated action failures (posting, commenting)
    var loadingFailed = false // For background loading failures - shows inline empty state

    // Cache status for offline-first support
    var isFromCache = false
    var lastSyncedAt: Date?

    private var currentOffset = 0
    private var pageSize: Int {
        AppConfiguration.shared.pageSize
    }
    private var hasMorePosts = true

    /// Track if a prefetch is already in progress
    private var isPrefetching = false
    /// Prefetch threshold: trigger at 80% of list
    private let prefetchThreshold = 0.8

    let repository: ForumRepository

    // MARK: - Cache Configuration

    /// Last fetch time for posts cache validity check
    private var lastPostsFetchTime: Date?
    /// Last fetch time for categories cache (changes rarely, 1-hour TTL)
    private var lastCategoriesFetchTime: Date?
    /// Posts cache TTL: 2 minutes
    private let postsCacheTTL: TimeInterval = 120
    /// Categories cache TTL: 1 hour
    private let categoriesCacheTTL: TimeInterval = 3600

    /// Check if posts cache is still valid
    private var isPostsCacheValid: Bool {
        guard let lastFetch = lastPostsFetchTime, !posts.isEmpty else { return false }
        return Date().timeIntervalSince(lastFetch) < postsCacheTTL
    }

    /// Check if categories cache is still valid
    private var isCategoriesCacheValid: Bool {
        guard let lastFetch = lastCategoriesFetchTime, !categories.isEmpty else { return false }
        return Date().timeIntervalSince(lastFetch) < categoriesCacheTTL
    }

    // MARK: - Computed Properties

    var hasPosts: Bool {
        !posts.isEmpty
    }

    var selectedCategory: ForumCategory? {
        guard let categoryId = filters.categoryId else { return nil }
        return categories.first { $0.id == categoryId }
    }

    var activeFiltersCount: Int {
        var count = 0
        if filters.categoryId != nil { count += 1 }
        if filters.postType != nil { count += 1 }
        if filters.showQuestionsOnly { count += 1 }
        if filters.showUnansweredOnly { count += 1 }
        return count
    }

    // MARK: - Initialization

    init(repository: ForumRepository) {
        self.repository = repository
    }

    // MARK: - Actions

    /// Load initial data with parallel loading for better performance
    /// Uses cache validity checks to avoid unnecessary API calls
    func loadInitialData() async {
        // If all caches are valid, skip loading
        if isPostsCacheValid, isCategoriesCacheValid {
            logger.debug("📋 Using cached forum data (posts: \(self.posts.count), categories: \(self.categories.count))")
            return
        }

        // Load main data in parallel for better performance
        async let postsTask: () = loadPosts()
        async let categoriesTask: () = loadCategories()
        async let tagsTask: () = loadPopularTags()

        _ = await (postsTask, categoriesTask, tagsTask)

        // Load trending posts after main data (lower priority)
        await loadTrendingPosts()
    }

    /// Load trending posts (hot posts from last 24-48 hours)
    func loadTrendingPosts() async {
        do {
            var fetchedPosts = try await repository.fetchTrendingPosts(limit: 5)

            // Apply translations to trending posts
            fetchedPosts = await applyTranslationsToNewPosts(fetchedPosts)

            trendingPosts = fetchedPosts
        } catch {
            // Trending is optional, don't show error
        }
    }

    /// Load forum posts with cache support
    func loadPosts(forceRefresh: Bool = false) async {
        guard !isLoading else { return }

        // Check cache validity unless force refresh
        if !forceRefresh, isPostsCacheValid {
            logger.debug("📋 Using cached posts (age: \(Date().timeIntervalSince(self.lastPostsFetchTime ?? Date()))s)")
            return
        }

        logger.info("📋 Loading forum posts...")
        isLoading = true
        error = nil
        showError = false
        loadingFailed = false
        currentOffset = 0
        hasMorePosts = true
        isFromCache = false

        defer {
            isLoading = false
            lastPostsFetchTime = Date()
        }

        do {
            // Load pinned posts first
            logger.debug("Fetching pinned posts...")
            pinnedPosts = try await repository.fetchPinnedPosts(categoryId: filters.categoryId)
            logger.debug("Fetched \(self.pinnedPosts.count) pinned posts")

            // Load regular posts
            logger.debug("Fetching regular posts...")
            posts = try await repository.fetchPosts(
                categoryId: filters.categoryId,
                postType: filters.postType,
                sortBy: filters.sortBy,
                limit: pageSize,
                offset: 0,
            )
            logger.info("✅ Loaded \(self.posts.count) forum posts successfully")

            hasMorePosts = posts.count >= pageSize
            lastSyncedAt = Date()

            // Fetch and apply translations for non-English locales
            await applyTranslations()
        } catch let appError as AppError {
            logger.error("❌ Forum load failed with AppError: \(appError.localizedDescription)")
            error = appError
            loadingFailed = true // Show inline empty state, not blocking dialog
        } catch {
            logger.error("❌ Forum load failed with error: \(error.localizedDescription)")
            self.error = .networkError(error.localizedDescription)
            loadingFailed = true // Show inline empty state, not blocking dialog
        }
    }

    /// Load more posts (pagination)
    func loadMorePosts() async {
        guard !isLoadingMore, hasMorePosts else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let newOffset = currentOffset + pageSize
            var newPosts = try await repository.fetchPosts(
                categoryId: filters.categoryId,
                postType: filters.postType,
                sortBy: filters.sortBy,
                limit: pageSize,
                offset: newOffset,
            )

            // Fetch translations for new posts
            newPosts = await applyTranslationsToNewPosts(newPosts)

            posts.append(contentsOf: newPosts)
            currentOffset = newOffset
            hasMorePosts = newPosts.count >= pageSize
        } catch {
            // Silently fail for pagination
        }
    }

    /// Check if prefetching should be triggered based on visible post index.
    /// Call this when a post becomes visible in the list.
    ///
    /// - Parameter index: The index of the post that became visible
    func onPostAppeared(at index: Int) {
        guard hasMorePosts, !isLoadingMore, !isPrefetching else { return }

        // Calculate if we've reached the prefetch threshold (80% of current posts)
        let thresholdIndex = Int(Double(posts.count) * prefetchThreshold)

        if index >= thresholdIndex {
            isPrefetching = true
            Task {
                await loadMorePosts()
                isPrefetching = false
            }
        }
    }

    /// Refresh posts (force refresh, ignoring cache)
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        await loadPosts(forceRefresh: true)
    }

    /// Load categories with 1-hour cache TTL
    func loadCategories() async {
        // Check cache validity - categories rarely change
        if isCategoriesCacheValid {
            logger
                .debug(
                    "📋 Using cached categories (age: \(Date().timeIntervalSince(self.lastCategoriesFetchTime ?? Date()))s)",
                )
            return
        }

        do {
            categories = try await repository.fetchCategories()
            lastCategoriesFetchTime = Date()
        } catch {
            // Categories are optional, don't show error
        }
    }

    /// Load popular tags
    func loadPopularTags() async {
        do {
            popularTags = try await repository.fetchPopularTags(limit: 10)
        } catch {
            // Tags are optional, don't show error
        }
    }

    /// Search posts
    func searchPosts(query: String) async {
        guard !query.isEmpty else {
            await loadPosts()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            var searchResults = try await repository.searchPosts(query: query, limit: 50)

            // Apply translations to search results
            searchResults = await applyTranslationsToNewPosts(searchResults)

            posts = searchResults
            pinnedPosts = []
            hasMorePosts = false
        } catch {
            // Keep existing posts on search failure
        }
    }

    /// Apply filters and reload
    func applyFilters(_ newFilters: ForumFilters) async {
        filters = newFilters
        await loadPosts()
    }

    /// Select category
    func selectCategory(_ category: ForumCategory?) async {
        filters.categoryId = category?.id
        await loadPosts()
    }

    /// Change sort option
    func changeSortOption(_ option: ForumSortOption) async {
        filters.sortBy = option
        await loadPosts()
    }

    /// Reset all filters
    func resetFilters() async {
        filters.reset()
        await loadPosts()
    }

    /// Toggle like on a post
    func toggleLike(for post: ForumPost, profileId: UUID) async {
        do {
            let isLiked = try await repository.togglePostLike(forumId: post.id, profileId: profileId)

            // Update local state
            if let index = posts.firstIndex(where: { $0.id == post.id }) {
                var updatedPost = posts[index]
                // Note: In a real app, you'd update the likes count properly
                posts[index] = updatedPost
            }
        } catch {
            // Handle error silently or show toast
        }
    }

    /// Toggle bookmark on a post
    func toggleBookmark(for post: ForumPost, profileId: UUID) async {
        do {
            _ = try await repository.toggleBookmark(forumId: post.id, profileId: profileId)
        } catch {
            // Handle error silently or show toast
        }
    }

    // MARK: - Emoji Reactions

    /// Available reaction types (cached)
    var reactionTypes: [ReactionType] = ReactionType.all

    /// Reactions cache for posts (keyed by post ID)
    var postReactions: [Int: ReactionsSummary] = [:]

    /// Load reaction types from server (or use cached)
    func loadReactionTypes() async {
        do {
            reactionTypes = try await repository.fetchReactionTypes()
        } catch {
            // Fall back to static list
            reactionTypes = ReactionType.all
        }
    }

    /// Fetch reactions for a post
    func fetchPostReactions(forumId: Int, profileId: UUID) async -> ReactionsSummary {
        do {
            let summary = try await repository.fetchPostReactions(forumId: forumId, profileId: profileId)
            postReactions[forumId] = summary
            return summary
        } catch {
            return ReactionsSummary()
        }
    }

    /// Toggle a reaction on a post
    func togglePostReaction(forumId: Int, reactionType: ReactionType, profileId: UUID) async -> ReactionsSummary {
        do {
            let summary = try await repository.togglePostReaction(
                forumId: forumId,
                reactionTypeId: reactionType.id,
                profileId: profileId,
            )
            postReactions[forumId] = summary

            // Update the post's likes counter in the local state for UI feedback
            if let index = posts.firstIndex(where: { $0.id == forumId }) {
                // The likes count is now reflected in the reactions summary
                // The UI should use ReactionsSummary.totalCount instead
            }

            return summary
        } catch {
            return postReactions[forumId] ?? ReactionsSummary()
        }
    }

    /// Get cached reactions for a post
    func getPostReactions(forumId: Int) -> ReactionsSummary {
        postReactions[forumId] ?? ReactionsSummary()
    }

    /// Dismiss error
    func dismissError() {
        showError = false
        loadingFailed = false
        error = nil
    }

    // MARK: - Translation Support

    /// Fetch translations from localization service and apply to loaded posts
    private func applyTranslations() async {
        let translationService = EnhancedTranslationService.shared

        // Skip if English locale
        guard translationService.currentLocale != "en" else { return }

        // Get all post IDs
        let allPostIds = (pinnedPosts + posts + trendingPosts).map { Int64($0.id) }
        guard !allPostIds.isEmpty else { return }

        logger.debug("🌐 Fetching translations for \(allPostIds.count) forum posts...")

        // Fetch translations via localization edge function
        let translations = await translationService.fetchForumPostTranslations(
            postIds: allPostIds,
            fields: ["title", "content"],
        )

        guard !translations.isEmpty else {
            logger.debug("No translations found for forum posts")
            return
        }

        // Apply translations to posts
        let locale = translationService.currentLocale

        posts = posts.map { post in
            var mutablePost = post
            if let trans = translations[String(post.id)] {
                mutablePost.titleTranslated = trans["title"].flatMap(\.self)
                mutablePost.descriptionTranslated = trans["content"].flatMap(\.self)
                mutablePost.translationLocale = locale
            }
            return mutablePost
        }

        pinnedPosts = pinnedPosts.map { post in
            var mutablePost = post
            if let trans = translations[String(post.id)] {
                mutablePost.titleTranslated = trans["title"].flatMap(\.self)
                mutablePost.descriptionTranslated = trans["content"].flatMap(\.self)
                mutablePost.translationLocale = locale
            }
            return mutablePost
        }

        trendingPosts = trendingPosts.map { post in
            var mutablePost = post
            if let trans = translations[String(post.id)] {
                mutablePost.titleTranslated = trans["title"].flatMap(\.self)
                mutablePost.descriptionTranslated = trans["content"].flatMap(\.self)
                mutablePost.translationLocale = locale
            }
            return mutablePost
        }

        logger.info("✅ Applied translations to \(translations.count) forum posts")
    }

    /// Fetch and apply translations to a batch of new posts (for pagination)
    private func applyTranslationsToNewPosts(_ newPosts: [ForumPost]) async -> [ForumPost] {
        let translationService = EnhancedTranslationService.shared

        // Skip if English locale
        guard translationService.currentLocale != "en" else { return newPosts }

        let postIds = newPosts.map { Int64($0.id) }
        guard !postIds.isEmpty else { return newPosts }

        let translations = await translationService.fetchForumPostTranslations(
            postIds: postIds,
            fields: ["title", "content"],
        )

        guard !translations.isEmpty else { return newPosts }

        let locale = translationService.currentLocale

        return newPosts.map { post in
            var mutablePost = post
            if let trans = translations[String(post.id)] {
                mutablePost.titleTranslated = trans["title"].flatMap(\.self)
                mutablePost.descriptionTranslated = trans["content"].flatMap(\.self)
                mutablePost.translationLocale = locale
            }
            return mutablePost
        }
    }
}


#endif
