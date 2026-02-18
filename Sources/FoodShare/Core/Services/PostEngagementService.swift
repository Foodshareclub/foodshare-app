//
//  PostEngagementService.swift
//  Foodshare
//
//  Handles post engagement: likes, bookmarks, and batch status checks.
//  Routes all operations through EngagementAPIService (Edge Function).
//


#if !SKIP
import Foundation
import OSLog

// MARK: - Engagement Status

/// Engagement status for a single post
struct PostEngagementStatus: Sendable {
    let isLiked: Bool
    let isBookmarked: Bool
    let likeCount: Int
}

// MARK: - Post Engagement Service

/// Actor-based service for managing post engagement (likes, bookmarks)
/// Routes all operations through the api-v1-engagement Edge Function
actor PostEngagementService {
    // MARK: - Singleton

    nonisolated static let shared = PostEngagementService()

    // MARK: - Properties

    private let engagementAPI: EngagementAPIService
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "PostEngagement")

    /// In-memory cache for engagement status (cleared on sign-out)
    private var engagementCache: [Int: PostEngagementStatus] = [:]

    /// Cache expiration time (5 minutes)
    private let cacheExpiration: TimeInterval = 300
    private var cacheTimestamps: [Int: Date] = [:]

    // MARK: - Initialization

    init(engagementAPI: EngagementAPIService = .shared) {
        self.engagementAPI = engagementAPI
        logger.info("[ENGAGEMENT] PostEngagementService initialized")
    }

    // MARK: - Like Operations

    /// Toggle like on a post via Edge Function
    /// Returns new like state and count
    @MainActor
    func toggleLike(postId: Int) async throws -> (isLiked: Bool, likeCount: Int) {
        logger.info("[ENGAGEMENT] Toggling like for post: \(postId)")

        do {
            let result = try await engagementAPI.toggleLike(postId: postId)

            // Update cache
            await updateCache(postId: postId, isLiked: result.isLiked, likeCount: result.likeCount)

            logger.info("[ENGAGEMENT] \(result.isLiked ? "Liked" : "Unliked") post: \(postId)")
            return (result.isLiked, result.likeCount)
        } catch let error as EdgeFunctionError {
            logger.error("[ENGAGEMENT] Toggle like failed: \(error.localizedDescription)")
            switch error {
            case .authenticationRequired:
                throw EngagementError.notAuthenticated
            case .notFound:
                throw EngagementError.networkError("Post not found")
            default:
                throw EngagementError.networkError(error.localizedDescription)
            }
        }
    }

    /// Check if user has liked a post
    /// Uses cache-first strategy with API fallback
    @MainActor
    func checkLiked(postId: Int) async throws -> (isLiked: Bool, likeCount: Int) {
        // Cache-first strategy (5-minute TTL)
        if let cached = await getCachedStatus(postId: postId) {
            return (cached.isLiked, cached.likeCount)
        }

        // Cache miss - fetch from server
        let statuses = try await getBatchEngagementStatus(postIds: [postId])
        if let status = statuses[postId] {
            return (status.isLiked, status.likeCount)
        }
        return (false, 0)
    }

    // MARK: - Bookmark Operations

    /// Toggle bookmark on a post via Edge Function
    /// Returns new bookmark state
    @MainActor
    func toggleBookmark(postId: Int) async throws -> Bool {
        logger.info("[ENGAGEMENT] Toggling bookmark for post: \(postId)")

        do {
            let result = try await engagementAPI.toggleBookmark(postId: postId)
            logger.info("[ENGAGEMENT] \(result.isBookmarked ? "Bookmarked" : "Unbookmarked") post: \(postId)")
            return result.isBookmarked
        } catch let error as EdgeFunctionError {
            logger.error("[ENGAGEMENT] Toggle bookmark failed: \(error.localizedDescription)")
            switch error {
            case .authenticationRequired:
                throw EngagementError.notAuthenticated
            case .notFound:
                throw EngagementError.networkError("Post not found")
            default:
                throw EngagementError.networkError(error.localizedDescription)
            }
        }
    }

    /// Check if user has bookmarked a post
    @MainActor
    func checkBookmarked(postId: Int) async throws -> Bool {
        if let cached = await getCachedStatus(postId: postId) {
            return cached.isBookmarked
        }
        let statuses = try await getBatchEngagementStatus(postIds: [postId])
        return statuses[postId]?.isBookmarked ?? false
    }

    /// Get user's bookmarked post IDs
    @MainActor
    func getUserBookmarks(limit: Int = 50) async throws -> [Int] {
        logger.debug("[ENGAGEMENT] Fetching user bookmarks")

        do {
            let result = try await engagementAPI.getUserBookmarks(limit: limit)
            return result.postIds
        } catch let error as EdgeFunctionError {
            if case .authenticationRequired = error {
                throw EngagementError.notAuthenticated
            }
            throw EngagementError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Batch Operations

    /// Get engagement status for multiple posts via Edge Function
    @MainActor
    func getBatchEngagementStatus(postIds: [Int]) async throws -> [Int: PostEngagementStatus] {
        guard !postIds.isEmpty else { return [:] }
        guard postIds.count <= 100 else {
            throw EngagementError.tooManyPosts
        }

        do {
            let statusMap = try await engagementAPI.getBatchStatus(postIds: postIds)

            // Build result dictionary and update cache
            var result: [Int: PostEngagementStatus] = [:]
            for (postId, dto) in statusMap {
                let status = PostEngagementStatus(
                    isLiked: dto.isLiked,
                    isBookmarked: dto.isBookmarked,
                    likeCount: dto.likeCount
                )
                result[postId] = status
                await updateCache(postId: postId, isLiked: dto.isLiked, likeCount: dto.likeCount, isBookmarked: dto.isBookmarked)
            }

            return result
        } catch let error as EdgeFunctionError {
            throw EngagementError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Cache Management

    /// Update engagement cache
    private func updateCache(postId: Int, isLiked: Bool, likeCount: Int, isBookmarked: Bool = false) {
        engagementCache[postId] = PostEngagementStatus(
            isLiked: isLiked,
            isBookmarked: isBookmarked,
            likeCount: likeCount
        )
        cacheTimestamps[postId] = Date()
    }

    /// Get cached engagement status if valid
    func getCachedStatus(postId: Int) -> PostEngagementStatus? {
        guard let status = engagementCache[postId],
              let timestamp = cacheTimestamps[postId],
              Date().timeIntervalSince(timestamp) < cacheExpiration
        else {
            return nil
        }
        return status
    }

    /// Clear all cached engagement data (call on sign-out)
    func clearCache() {
        engagementCache.removeAll()
        cacheTimestamps.removeAll()
        logger.info("[ENGAGEMENT] Cache cleared")
    }
}

// MARK: - Engagement Errors

/// Errors that can occur during post engagement operations.
enum EngagementError: LocalizedError, Sendable {
    case notAuthenticated
    case tooManyPosts
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Please sign in to like posts"
        case .tooManyPosts:
            "Too many posts requested (max 100)"
        case let .networkError(message):
            "Network error: \(message)"
        }
    }
}

#endif
