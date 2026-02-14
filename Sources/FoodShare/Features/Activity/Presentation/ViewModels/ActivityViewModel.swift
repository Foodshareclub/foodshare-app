//
//  ActivityViewModel.swift
//  Foodshare
//
//  ViewModel for Activity Feed with real-time updates
//

import Foundation
import Observation
import OSLog
import Supabase

@MainActor
@Observable
final class ActivityViewModel {
    // MARK: - State

    var activities: [ActivityItem] = []
    var isLoading = false
    var isLoadingMore = false
    var error: AppError?
    var showError = false
    var hasMorePages = true

    // MARK: - Private

    private let repository: ActivityRepository
    private let client: SupabaseClient
    private let channelManager: RealtimeChannelManager
    private var currentPage = 0
    private var pageSize: Int {
        AppConfiguration.shared.pageSize
    }
    private let decoder: JSONDecoder
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ActivityViewModel")

    /// Channel identifiers for cleanup
    private let postsChannelId = "activity-posts"
    private let forumChannelId = "activity-forum"

    // MARK: - Caching & Prefetching

    /// Last fetch time for cache validity
    private var lastFetchTime: Date?
    /// Cache TTL: 2 minutes
    private let cacheTTL: TimeInterval = 120
    /// Track if prefetch is in progress
    private var isPrefetching = false
    /// Prefetch at 80% of list
    private let prefetchThreshold = 0.8

    /// Check if cache is valid
    private var isCacheValid: Bool {
        guard let lastFetch = lastFetchTime, !activities.isEmpty else { return false }
        return Date().timeIntervalSince(lastFetch) < cacheTTL
    }

    // MARK: - Initialization

    init(
        repository: ActivityRepository,
        client: SupabaseClient,
        channelManager: RealtimeChannelManager = .shared,
    ) {
        self.repository = repository
        self.client = client
        self.channelManager = channelManager
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    deinit {
        // Use Task to call async cleanup from deinit
        // The channel manager handles the actual unsubscribe
        let client = self.client
        let postsId = postsChannelId
        let forumId = forumChannelId
        let manager = channelManager

        Task {
            await manager.unregister(table: "posts", filter: postsId)
            await manager.unregister(table: "forum", filter: forumId)
        }
    }

    // MARK: - Computed Properties

    var hasActivities: Bool {
        !activities.isEmpty
    }

    // MARK: - Actions

    /// Load activities with cache support
    /// - Parameter forceRefresh: If true, bypasses cache and fetches fresh data
    func loadActivities(forceRefresh: Bool = false) async {
        guard !isLoading else { return }

        // Check cache validity unless force refresh
        if !forceRefresh, isCacheValid {
            logger.debug("Using cached activities (age: \(Date().timeIntervalSince(self.lastFetchTime ?? Date()))s)")
            return
        }

        isLoading = true
        error = nil
        showError = false
        currentPage = 0

        defer {
            isLoading = false
            lastFetchTime = Date()
        }

        do {
            activities = try await repository.fetchActivities(offset: 0, limit: pageSize)
            hasMorePages = activities.count >= pageSize
            // Cache the activities for offline access
            try? await repository.cacheActivities(activities)
            logger.debug("Loaded \(self.activities.count) activities")
        } catch {
            // Try to load from cache on failure
            let cached = await repository.fetchCachedActivities()
            if !cached.isEmpty {
                activities = cached
                logger.info("Loaded \(cached.count) activities from cache")
            } else {
                self.error = .networkError(error.localizedDescription)
                showError = true
                logger.error("Failed to load activities: \(error.localizedDescription)")
            }
        }
    }

    func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }

        isLoadingMore = true
        currentPage += 1

        do {
            let newActivities = try await repository.fetchActivities(
                offset: currentPage * pageSize,
                limit: pageSize,
            )
            activities.append(contentsOf: newActivities)
            hasMorePages = newActivities.count >= pageSize
            logger.debug("Loaded \(newActivities.count) more activities")
        } catch {
            // Silently fail on load more
            hasMorePages = false
            logger.warning("Failed to load more activities: \(error.localizedDescription)")
        }

        isLoadingMore = false
    }

    /// Check if prefetching should be triggered based on visible activity index.
    /// Call this when an activity becomes visible in the list.
    ///
    /// - Parameter index: The index of the activity that became visible
    func onActivityAppeared(at index: Int) {
        guard hasMorePages, !isLoadingMore, !isPrefetching else { return }

        // Calculate if we've reached the prefetch threshold (80% of current activities)
        let thresholdIndex = Int(Double(activities.count) * prefetchThreshold)

        if index >= thresholdIndex {
            isPrefetching = true
            Task {
                await loadMore()
                isPrefetching = false
            }
        }
    }

    func refresh() async {
        await loadActivities(forceRefresh: true)
    }

    func dismissError() {
        error = nil
        showError = false
    }

    // MARK: - Real-time Subscriptions

    func subscribeToRealTimeUpdates() async {
        await subscribeToNewPosts()
        await subscribeToForumPosts()
    }

    private func subscribeToNewPosts() async {
        let channel = client.realtimeV2.channel(postsChannelId)

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "posts",
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            await AppLogger.shared.error("Failed to subscribe to posts channel", error: error)
        }

        // Register with centralized manager for lifecycle tracking
        await channelManager.register(channel: channel, table: "posts", filter: postsChannelId)

        Task { [weak self, decoder] in
            for await insertion in insertions {
                guard let self else { return }

                do {
                    struct NewPost: Decodable {
                        let id: Int
                        let postName: String
                        let postDescription: String?
                        let images: [String]?
                        let createdAt: Date
                        let isArranged: Bool

                        enum CodingKeys: String, CodingKey {
                            case id
                            case postName = "post_name"
                            case postDescription = "post_description"
                            case images
                            case createdAt = "created_at"
                            case isArranged = "is_arranged"
                        }
                    }

                    let post = try insertion.decodeRecord(as: NewPost.self, decoder: decoder)

                    let imageURL: URL? = {
                        guard let firstImage = post.images?.first else { return nil }
                        return URL(string: firstImage)
                    }()

                    let activity = ActivityItem(
                        id: UUID(),
                        type: post.isArranged ? .listingArranged : .newListing,
                        title: post.postName,
                        subtitle: post.postDescription ?? "",
                        imageURL: imageURL,
                        timestamp: post.createdAt,
                        actorName: nil,
                        actorAvatarURL: nil,
                        linkedPostId: post.id,
                        linkedForumId: nil,
                        linkedProfileId: nil,
                    )

                    await MainActor.run {
                        self.activities.insert(activity, at: 0)
                        HapticManager.light()
                    }
                } catch {
                    await AppLogger.shared.error("Failed to decode real-time post", error: error)
                }
            }
        }
    }

    private func subscribeToForumPosts() async {
        let channel = client.realtimeV2.channel(forumChannelId)

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "forum",
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            await AppLogger.shared.error("Failed to subscribe to forum channel", error: error)
        }

        // Register with centralized manager for lifecycle tracking
        await channelManager.register(channel: channel, table: "forum", filter: forumChannelId)

        Task { [weak self, decoder] in
            for await insertion in insertions {
                guard let self else { return }

                do {
                    struct NewForumPost: Decodable {
                        let id: Int
                        let forumPostName: String
                        let forumPostDescription: String?
                        let forumPostCreatedAt: Date

                        enum CodingKeys: String, CodingKey {
                            case id
                            case forumPostName = "forum_post_name"
                            case forumPostDescription = "forum_post_description"
                            case forumPostCreatedAt = "forum_post_created_at"
                        }
                    }

                    let post = try insertion.decodeRecord(as: NewForumPost.self, decoder: decoder)

                    let activity = ActivityItem(
                        id: UUID(),
                        type: .forumPost,
                        title: post.forumPostName,
                        subtitle: post.forumPostDescription ?? "",
                        imageURL: nil,
                        timestamp: post.forumPostCreatedAt,
                        actorName: nil,
                        actorAvatarURL: nil,
                        linkedPostId: nil,
                        linkedForumId: post.id,
                        linkedProfileId: nil,
                    )

                    await MainActor.run {
                        self.activities.insert(activity, at: 0)
                        HapticManager.light()
                    }
                } catch {
                    await AppLogger.shared.error("Failed to decode real-time forum post", error: error)
                }
            }
        }
    }

    func unsubscribeFromRealTimeUpdates() async {
        // Unregister from centralized manager
        await channelManager.unregister(table: "posts", filter: postsChannelId)
        await channelManager.unregister(table: "forum", filter: forumChannelId)
    }
}
