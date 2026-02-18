//
//  EngagementAPIService.swift
//  Foodshare
//
//  API service for post engagement operations via api-v1-engagement Edge Function.
//  Handles likes, bookmarks, favorites, shares, and batch operations.
//


#if !SKIP
import Foundation

// MARK: - Response DTOs

/// Status for a single post's engagement
struct EngagementStatusDTO: Decodable, Sendable {
    let postId: Int
    let isLiked: Bool
    let isBookmarked: Bool
    let likeCount: Int
}

/// Response from toggling a like
struct ToggleLikeDTO: Decodable, Sendable {
    let postId: Int
    let isLiked: Bool
    let likeCount: Int
}

/// Response from toggling a bookmark
struct ToggleBookmarkDTO: Decodable, Sendable {
    let postId: Int
    let isBookmarked: Bool
}

/// Response from toggling a favorite
struct ToggleFavoriteDTO: Decodable, Sendable {
    let postId: Int
    let isFavorited: Bool
    let likeCount: Int
    let action: String // "added", "removed", "unchanged"
}

/// Response from getUserBookmarks
struct BookmarksDTO: Decodable, Sendable {
    let postIds: [Int]
    let count: Int
}

/// A single batch operation to send
struct BatchOperation: Encodable, Sendable {
    let correlationId: String
    let type: String
    let entityId: String

    init(type: String, entityId: String) {
        self.correlationId = UUID().uuidString
        self.type = type
        self.entityId = entityId
    }

    static func toggleLike(postId: Int) -> BatchOperation {
        BatchOperation(type: "toggle_like", entityId: "\(postId)")
    }

    static func toggleBookmark(postId: Int) -> BatchOperation {
        BatchOperation(type: "toggle_bookmark", entityId: "\(postId)")
    }

    static func toggleFavorite(postId: Int) -> BatchOperation {
        BatchOperation(type: "toggle_favorite", entityId: "\(postId)")
    }

    static func markRead(postId: Int) -> BatchOperation {
        BatchOperation(type: "mark_read", entityId: "\(postId)")
    }
}

/// Result of a batch operation
struct BatchResultDTO: Decodable, Sendable {
    let totalOperations: Int
    let successful: Int
    let failed: Int
    let results: [BatchOperationResult]

    struct BatchOperationResult: Decodable, Sendable {
        let correlationId: String
        let success: Bool
        let error: String?
    }
}

// MARK: - Request Bodies

private struct PostIdBody: Encodable {
    let postId: Int
}

private struct ShareBody: Encodable {
    let postId: Int
    let method: String
}

private struct FavoriteBody: Encodable {
    let postId: Int
    let mode: String?
}

private struct BatchRequestBody: Encodable {
    let operations: [BatchOperation]
}

// MARK: - Engagement API Service

actor EngagementAPIService {
    nonisolated static let shared = EngagementAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    /// Get engagement status for a single post
    func getStatus(postId: Int) async throws -> EngagementStatusDTO {
        try await client.get("api-v1-engagement", params: ["postId": "\(postId)"])
    }

    /// Get engagement status for multiple posts
    func getBatchStatus(postIds: [Int]) async throws -> [Int: EngagementStatusDTO] {
        let idsString = postIds.map { "\($0)" }.joined(separator: ",")
        let statuses: [EngagementStatusDTO] = try await client.get(
            "api-v1-engagement",
            params: ["postIds": idsString]
        )
        var map: [Int: EngagementStatusDTO] = [:]
        for status in statuses {
            map[status.postId] = status
        }
        return map
    }

    /// Toggle like on a post
    func toggleLike(postId: Int) async throws -> ToggleLikeDTO {
        try await client.post(
            "api-v1-engagement",
            body: PostIdBody(postId: postId),
            params: ["action": "like"]
        )
    }

    /// Toggle bookmark on a post
    func toggleBookmark(postId: Int) async throws -> ToggleBookmarkDTO {
        try await client.post(
            "api-v1-engagement",
            body: PostIdBody(postId: postId),
            params: ["action": "bookmark"]
        )
    }

    /// Toggle favorite on a post
    func toggleFavorite(postId: Int, mode: String? = nil) async throws -> ToggleFavoriteDTO {
        try await client.post(
            "api-v1-engagement",
            body: FavoriteBody(postId: postId, mode: mode),
            params: ["action": "favorite"]
        )
    }

    /// Get user's bookmarked post IDs
    func getUserBookmarks(limit: Int = 50) async throws -> BookmarksDTO {
        try await client.get(
            "api-v1-engagement",
            params: ["action": "bookmarks", "limit": "\(limit)"]
        )
    }

    /// Record a share action
    func recordShare(postId: Int, method: String) async throws {
        try await client.postVoid(
            "api-v1-engagement",
            body: ShareBody(postId: postId, method: method),
            params: ["action": "share"]
        )
    }

    /// Execute batch operations
    func batchOperations(_ ops: [BatchOperation]) async throws -> BatchResultDTO {
        try await client.post(
            "api-v1-engagement/batch",
            body: BatchRequestBody(operations: ops)
        )
    }
}

#endif
