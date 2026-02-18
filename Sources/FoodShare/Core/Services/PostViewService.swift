//
//  PostViewService.swift
//  Foodshare
//
//  Tracks post views with session-based deduplication.
//  Routes view recording through EngagementAPIService batch operations.
//


#if !SKIP
import Foundation
import OSLog
import SwiftUI

// MARK: - Post View Service

/// Actor-based service for tracking post views with deduplication
/// Prevents spam views with a cooldown period per post
actor PostViewService {
    // MARK: - Singleton

    nonisolated static let shared = PostViewService()

    // MARK: - Properties

    private let engagementAPI: EngagementAPIService
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "PostViewService")

    /// Cooldown period between views of the same post (30 seconds)
    private let viewCooldown: TimeInterval = 30

    /// Track last view time per post to prevent spam
    private var lastViewTimes: [Int: Date] = [:]

    /// Posts currently being tracked (prevent duplicate requests)
    private var pendingViews: Set<Int> = []

    // MARK: - Initialization

    init(engagementAPI: EngagementAPIService = .shared) {
        self.engagementAPI = engagementAPI
        logger.info("[VIEWS] PostViewService initialized")
    }

    // MARK: - View Tracking

    /// Record a view for a post
    /// Deduplicates views within cooldown period, server handles counter increment and activity logging
    /// - Parameter postId: The post ID to record a view for
    /// - Returns: True if view was recorded, false if deduplicated
    @discardableResult
    @MainActor
    func recordView(postId: Int) async -> Bool {
        // Check cooldown
        let cooldown = await viewCooldown
        if let lastView = await getLastViewTime(postId: postId) {
            let elapsed = Date().timeIntervalSince(lastView)
            if elapsed < cooldown {
                return false
            }
        }

        // Check if already pending
        guard await !isPending(postId: postId) else {
            return false
        }

        // Mark as pending
        await setPending(postId: postId, pending: true)
        defer {
            Task { await self.setPending(postId: postId, pending: false) }
        }

        do {
            // Use batch operations to record the view — server handles
            // counter increment, activity logging, and deduplication
            _ = try await engagementAPI.batchOperations([.markRead(postId: postId)])

            // Update last view time
            await setLastViewTime(postId: postId, time: Date())

            logger.info("[VIEWS] View recorded for post: \(postId)")
            return true
        } catch {
            logger.warning("[VIEWS] Failed to record view: \(error.localizedDescription)")
            return false
        }
    }

    /// Record views for multiple posts (batch operation)
    @MainActor
    func recordViews(postIds: [Int]) async {
        // Filter out posts within cooldown
        let now = Date()
        let eligibleIds = await filterEligiblePosts(postIds, now: now)
        guard !eligibleIds.isEmpty else { return }

        let ops = eligibleIds.map { BatchOperation.markRead(postId: $0) }
        do {
            _ = try await engagementAPI.batchOperations(ops)
            for postId in eligibleIds {
                await setLastViewTime(postId: postId, time: now)
            }
        } catch {
            logger.warning("[VIEWS] Failed to record batch views: \(error.localizedDescription)")
        }
    }

    /// Record a view for a forum post
    /// Forum views go through the forum Edge Function action=view
    @discardableResult
    @MainActor
    func recordForumView(forumId: Int) async -> Bool {
        // Check cooldown
        let cooldown = await viewCooldown
        if let lastView = await getLastViewTime(postId: forumId) {
            let elapsed = Date().timeIntervalSince(lastView)
            if elapsed < cooldown {
                return false
            }
        }

        guard await !isPending(postId: forumId) else {
            return false
        }

        await setPending(postId: forumId, pending: true)
        defer {
            Task { await self.setPending(postId: forumId, pending: false) }
        }

        do {
            // Forum views go through the forum API endpoint
            let client = APIClient.shared
            struct ForumViewBody: Encodable { let forumId: Int }
            try await client.postVoid(
                "api-v1-forum",
                body: ForumViewBody(forumId: forumId),
                params: ["action": "view"]
            )

            await setLastViewTime(postId: forumId, time: Date())
            logger.info("[VIEWS] View recorded for forum: \(forumId)")
            return true
        } catch {
            logger.warning("[VIEWS] Failed to record forum view: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - State Management

    private func filterEligiblePosts(_ postIds: [Int], now: Date) -> [Int] {
        postIds.filter { postId in
            guard let lastView = lastViewTimes[postId] else { return true }
            return now.timeIntervalSince(lastView) >= viewCooldown
        }
    }

    private func getLastViewTime(postId: Int) -> Date? {
        lastViewTimes[postId]
    }

    private func setLastViewTime(postId: Int, time: Date) {
        lastViewTimes[postId] = time
    }

    private func isPending(postId: Int) -> Bool {
        pendingViews.contains(postId)
    }

    private func setPending(postId: Int, pending: Bool) {
        if pending {
            pendingViews.insert(postId)
        } else {
            pendingViews.remove(postId)
        }
    }

    // MARK: - Cache Management

    /// Clear view tracking state (call on app termination or sign-out)
    func clearState() {
        lastViewTimes.removeAll()
        pendingViews.removeAll()
        logger.info("[VIEWS] View tracking state cleared")
    }
}

// MARK: - SwiftUI Integration

/// View modifier to track post views when appearing
struct PostViewTracker: ViewModifier {
    let postId: Int

    func body(content: Content) -> some View {
        content
            .task {
                await PostViewService.shared.recordView(postId: postId)
            }
    }
}

extension View {
    /// Track a view when this view appears
    func trackView(postId: Int) -> some View {
        modifier(PostViewTracker(postId: postId))
    }
}

// MARK: - Forum View Service

/// Forum-specific view tracking service
actor ForumViewService {
    static let shared = ForumViewService()

    private init() {}

    /// Record a view for a forum post
    @discardableResult
    @MainActor
    func recordView(forumId: Int) async -> Bool {
        await PostViewService.shared.recordForumView(forumId: forumId)
    }
}

#endif
