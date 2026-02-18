//
//  ForumEngagementService.swift
//  Foodshare
//
//  Handles forum post engagement: likes, bookmarks
//  Uses unified `likes` table via RPC calls for optimal performance
//


#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - Forum Engagement Status

/// Engagement status for a single forum post
struct ForumEngagementStatus: Sendable {
    let isLiked: Bool
    let isBookmarked: Bool
    let likeCount: Int
}

// MARK: - RPC Response Types

/// Response from toggle_forum_like RPC
private struct ToggleForumLikeResponse: Decodable {
    let success: Bool
    let isLiked: Bool?
    let likeCount: Int?
    let error: RPCError?

    enum CodingKeys: String, CodingKey {
        case success
        case isLiked = "is_liked"
        case likeCount = "like_count"
        case error
    }

    struct RPCError: Decodable {
        let code: String
        let message: String
    }
}

/// Response from toggle_forum_bookmark RPC
private struct ToggleForumBookmarkResponse: Decodable {
    let success: Bool
    let isBookmarked: Bool?
    let error: RPCError?

    enum CodingKeys: String, CodingKey {
        case success
        case isBookmarked = "is_bookmarked"
        case error
    }

    struct RPCError: Decodable {
        let code: String
        let message: String
    }
}

// MARK: - Forum Engagement Service

/// Actor-based service for managing forum post engagement (likes, bookmarks)
/// Uses unified `likes` table via RPC calls for optimal performance
actor ForumEngagementService {
    // MARK: - Singleton

    nonisolated static let shared: ForumEngagementService = {
        ForumEngagementService(supabase: MainActor.assumeIsolated { AuthenticationService.shared.supabase })
    }()

    // MARK: - Properties

    private let supabase: SupabaseClient
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ForumEngagement")

    /// In-memory cache for engagement status (cleared on sign-out)
    private var engagementCache: [Int: ForumEngagementStatus] = [:]

    /// Cache expiration time (5 minutes)
    private let cacheExpiration: TimeInterval = 300
    private var cacheTimestamps: [Int: Date] = [:]

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        logger.info("📊 [FORUM-ENGAGEMENT] ForumEngagementService initialized")
    }

    // MARK: - Like Operations (Single RPC Call)

    /// Toggle like on a forum post using single RPC call
    /// Uses unified `likes` table with forum_id
    /// Returns new like state and count
    @MainActor
    func toggleLike(forumId: Int) async throws -> (isLiked: Bool, likeCount: Int) {
        logger.info("❤️ [FORUM-ENGAGEMENT] Toggling like for forum post: \(forumId)")

        // Single RPC call replaces multiple database calls
        let response = try await supabase
            .rpc("toggle_forum_like", params: ["p_forum_id": forumId])
            .execute()

        let result = try JSONDecoder().decode(ToggleForumLikeResponse.self, from: response.data)

        guard result.success else {
            if let error = result.error {
                logger.error("❌ [FORUM-ENGAGEMENT] Toggle like failed: \(error.message)")
                switch error.code {
                case "AUTH_REQUIRED":
                    throw ForumEngagementError.notAuthenticated
                case "FORUM_NOT_FOUND":
                    throw ForumEngagementError.networkError("Forum post not found")
                default:
                    throw ForumEngagementError.networkError(error.message)
                }
            }
            throw ForumEngagementError.networkError("Unknown error")
        }

        let isLiked = result.isLiked ?? false
        let likeCount = result.likeCount ?? 0

        // Update cache
        await updateCache(forumId: forumId, isLiked: isLiked, likeCount: likeCount)

        logger.info("\(isLiked ? "❤️" : "💔") [FORUM-ENGAGEMENT] \(isLiked ? "Liked" : "Unliked") forum post: \(forumId)")

        return (isLiked, likeCount)
    }

    /// Check if user has liked a forum post
    /// Uses cache-first strategy
    @MainActor
    func checkLiked(forumId: Int) async throws -> (isLiked: Bool, likeCount: Int) {
        logger.debug("🔍 [FORUM-ENGAGEMENT] Checking like status for forum post: \(forumId)")

        // Cache-first strategy
        if let cached = await getCachedStatus(forumId: forumId) {
            logger.debug("✅ [FORUM-ENGAGEMENT] Cache hit for forum: \(forumId)")
            return (cached.isLiked, cached.likeCount)
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            logger.debug("🔍 [FORUM-ENGAGEMENT] User not authenticated, returning defaults")
            return (false, 0)
        }

        // Check likes in unified table
        let existingLikes: [LikeRecord] = try await supabase
            .from("likes")
            .select("id")
            .eq("forum_id", value: forumId)
            .eq("profile_id", value: userId)
            .eq("post_id", value: 0)
            .eq("challenge_id", value: 0)
            .eq("comment_id", value: 0)
            .execute()
            .value

        let isLiked = !existingLikes.isEmpty
        let likeCount = try await fetchLikeCount(forumId: forumId)

        // Update cache
        await updateCache(forumId: forumId, isLiked: isLiked, likeCount: likeCount)

        return (isLiked, likeCount)
    }

    // MARK: - Bookmark Operations (Single RPC Call)

    /// Toggle bookmark on a forum post using single RPC call
    /// Returns new bookmark state
    @MainActor
    func toggleBookmark(forumId: Int) async throws -> Bool {
        logger.info("🔖 [FORUM-ENGAGEMENT] Toggling bookmark for forum post: \(forumId)")

        let supabase = supabase

        // Single RPC call
        let response = try await supabase
            .rpc("toggle_forum_bookmark", params: ["p_forum_id": forumId])
            .execute()

        let result = try JSONDecoder().decode(ToggleForumBookmarkResponse.self, from: response.data)

        guard result.success else {
            if let error = result.error {
                logger.error("❌ [FORUM-ENGAGEMENT] Toggle bookmark failed: \(error.message)")
                switch error.code {
                case "AUTH_REQUIRED":
                    throw ForumEngagementError.notAuthenticated
                case "FORUM_NOT_FOUND":
                    throw ForumEngagementError.networkError("Forum post not found")
                default:
                    throw ForumEngagementError.networkError(error.message)
                }
            }
            throw ForumEngagementError.networkError("Unknown error")
        }

        let isBookmarked = result.isBookmarked ?? false

        // Update cache with bookmark state
        if let cached = await getCachedStatus(forumId: forumId) {
            await updateCache(
                forumId: forumId,
                isLiked: cached.isLiked,
                likeCount: cached.likeCount,
                isBookmarked: isBookmarked,
            )
        }

        logger
            .info(
                "\(isBookmarked ? "🔖" : "📖") [FORUM-ENGAGEMENT] \(isBookmarked ? "Bookmarked" : "Unbookmarked") forum post: \(forumId)",
            )

        return isBookmarked
    }

    /// Check if user has bookmarked a forum post
    @MainActor
    func checkBookmarked(forumId: Int) async throws -> Bool {
        logger.debug("🔍 [FORUM-ENGAGEMENT] Checking bookmark status for forum post: \(forumId)")

        guard let userId = try? await supabase.auth.session.user.id else {
            logger.debug("🔍 [FORUM-ENGAGEMENT] User not authenticated, returning false")
            return false
        }

        let existingBookmarks: [BookmarkRecord] = try await supabase
            .from("bookmarks")
            .select("id")
            .eq("forum_id", value: forumId)
            .eq("profile_id", value: userId)
            .eq("post_id", value: 0)
            .execute()
            .value

        return !existingBookmarks.isEmpty
    }

    // MARK: - Helper Methods

    private func fetchLikeCount(forumId: Int) async throws -> Int {
        // Count likes in unified table
        let response = try await supabase
            .from("likes")
            .select("*", head: true, count: .exact)
            .eq("forum_id", value: forumId)
            .eq("post_id", value: 0)
            .eq("challenge_id", value: 0)
            .eq("comment_id", value: 0)
            .execute()

        return response.count ?? 0
    }

    // MARK: - Cache Management

    /// Update engagement cache
    private func updateCache(forumId: Int, isLiked: Bool, likeCount: Int, isBookmarked: Bool = false) {
        engagementCache[forumId] = ForumEngagementStatus(
            isLiked: isLiked,
            isBookmarked: isBookmarked,
            likeCount: likeCount,
        )
        cacheTimestamps[forumId] = Date()
    }

    /// Get cached engagement status if valid
    func getCachedStatus(forumId: Int) -> ForumEngagementStatus? {
        guard let status = engagementCache[forumId],
              let timestamp = cacheTimestamps[forumId],
              Date().timeIntervalSince(timestamp) < cacheExpiration else
        {
            return nil
        }
        return status
    }

    /// Clear all cached engagement data (call on sign-out)
    func clearCache() {
        engagementCache.removeAll()
        cacheTimestamps.removeAll()
        logger.info("🧹 [FORUM-ENGAGEMENT] Cache cleared")
    }
}

// MARK: - Private DTOs

private struct LikeRecord: Codable {
    let id: Int
}

private struct BookmarkRecord: Codable {
    let id: Int
}

// MARK: - Forum Engagement Errors

enum ForumEngagementError: LocalizedError, Sendable {
    case notAuthenticated
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Please sign in to interact with forum posts"
        case let .networkError(message):
            "Network error: \(message)"
        }
    }
}

#endif
