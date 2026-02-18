//
//  ForumAPIService.swift
//  Foodshare
//
//  REST API client for forum operations via api-v1-forum edge function
//


#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - Request Types

private struct CreatePostRequest: Encodable {
    let title: String
    let description: String
    let postType: String
    let categoryId: Int?
}

private struct ForumIdRequest: Encodable {
    let forumId: Int
}

private struct ReactionRequest: Encodable {
    let forumId: Int
    let reactionType: String
}

private struct IncrementStatRequest: Encodable {
    let userId: String
    let stat: String
    let amount: Int
}

private struct UpdatePostRequest: Encodable {
    let title: String?
    let description: String?
}

private struct UpdateCommentRequest: Encodable {
    let content: String
}

// MARK: - Response Types

struct ForumLikeResponse: Codable {
    let isLiked: Bool
    let likeCount: Int
}

struct ForumBookmarkResponse: Codable {
    let isBookmarked: Bool
}

struct ForumReactionResponse: Codable {
    let action: String
    let reactionsCount: [String: Int]?
}

// MARK: - Service

actor ForumAPIService {
    nonisolated static let shared: ForumAPIService = {
        ForumAPIService(
            client: .shared,
            supabase: MainActor.assumeIsolated { AuthenticationService.shared.supabase }
        )
    }()

    private let client: APIClient
    private let supabase: SupabaseClient
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ForumAPI")

    init(client: APIClient = .shared, supabase: SupabaseClient) {
        self.client = client
        self.supabase = supabase
    }

    /// Get the current user's UUID from the Supabase auth session
    private func currentUserId() async throws -> UUID {
        try await supabase.auth.session.user.id
    }

    // MARK: - GET Operations

    func getFeed(categoryId: Int? = nil, postType: String? = nil, sortBy: String = "recent", limit: Int = 20, offset: Int = 0) async throws -> [ForumPost] {
        var params: [String: String] = ["sortBy": sortBy, "limit": "\(limit)", "offset": "\(offset)"]
        if let categoryId = categoryId { params["categoryId"] = "\(categoryId)" }
        if let postType = postType { params["postType"] = postType }

        return try await client.get("api-v1-forum", params: params)
    }

    func getPost(id: Int) async throws -> ForumPost {
        try await client.get("api-v1-forum", params: ["id": "\(id)"])
    }

    func getCategories() async throws -> [ForumCategory] {
        try await client.get("api-v1-forum", params: ["action": "categories"])
    }

    func searchPosts(query: String, limit: Int = 20) async throws -> [ForumPost] {
        try await client.get("api-v1-forum", params: ["action": "search", "q": query, "limit": "\(limit)"])
    }

    func getBookmarks() async throws -> [ForumPost] {
        try await client.get("api-v1-forum", params: ["action": "bookmarks"])
    }

    func getUnread() async throws -> [ForumPost] {
        try await client.get("api-v1-forum", params: ["action": "unread"])
    }

    func getDrafts() async throws -> [ForumPost] {
        try await client.get("api-v1-forum", params: ["action": "drafts"])
    }

    func getComments(forumId: Int, limit: Int = 50, offset: Int = 0) async throws -> [ForumComment] {
        try await client.get("api-v1-forum", params: [
            "action": "comments",
            "id": "\(forumId)",
            "limit": "\(limit)",
            "offset": "\(offset)"
        ])
    }

    // MARK: - POST Operations

    func createPost(title: String, description: String, categoryId: Int?, postType: String = "discussion") async throws -> ForumPost {
        let body = CreatePostRequest(title: title, description: description, postType: postType, categoryId: categoryId)
        return try await client.post("api-v1-forum", body: body, params: ["action": "create"])
    }

    func createComment(forumId: Int, content: String, parentId: Int? = nil) async throws -> ForumComment {
        let userId = try await currentUserId()
        let body = CreateCommentRequest(userId: userId, forumId: forumId, parentId: parentId, comment: content)
        return try await client.post("api-v1-forum", body: body, params: ["action": "comment"])
    }

    func toggleLike(forumId: Int) async throws -> ForumLikeResponse {
        try await client.post("api-v1-forum", body: ForumIdRequest(forumId: forumId), params: ["action": "like"])
    }

    func toggleBookmark(forumId: Int) async throws -> ForumBookmarkResponse {
        try await client.post("api-v1-forum", body: ForumIdRequest(forumId: forumId), params: ["action": "bookmark"])
    }

    func toggleReaction(forumId: Int, reactionType: String) async throws -> ForumReactionResponse {
        try await client.post("api-v1-forum", body: ReactionRequest(forumId: forumId, reactionType: reactionType), params: ["action": "react"])
    }

    func recordView(forumId: Int) async throws {
        let _: EmptyResponse = try await client.post("api-v1-forum", body: ForumIdRequest(forumId: forumId), params: ["action": "view"])
    }

    // MARK: - Poll Operations

    func getPoll(pollId: String) async throws -> ForumPoll {
        try await client.get("api-v1-forum/poll", params: ["id": pollId])
    }

    func votePoll(pollId: UUID, optionIds: [UUID]) async throws -> ForumPoll {
        let profileId = try await currentUserId()
        return try await client.post("api-v1-forum/poll/vote", body: VotePollRequest(pollId: pollId, optionIds: optionIds, profileId: profileId))
    }

    // MARK: - Reputation Operations

    func incrementStat(userId: String, stat: String, amount: Int) async throws {
        let _: EmptyResponse = try await client.post("api-v1-forum/reputation/increment", body: IncrementStatRequest(userId: userId, stat: stat, amount: amount))
    }

    // MARK: - PUT Operations

    func updatePost(id: Int, title: String? = nil, description: String? = nil) async throws -> ForumPost {
        let body = UpdatePostRequest(title: title, description: description)
        return try await client.put("api-v1-forum", body: body, params: ["id": "\(id)"])
    }

    func updateComment(id: Int, content: String) async throws -> ForumComment {
        try await client.put("api-v1-forum", body: UpdateCommentRequest(content: content), params: ["action": "comment", "id": "\(id)"])
    }

    // MARK: - DELETE Operations

    func deletePost(id: Int) async throws {
        let _: EmptyResponse = try await client.delete("api-v1-forum", params: ["id": "\(id)"])
    }

    func deleteComment(id: Int) async throws {
        let _: EmptyResponse = try await client.delete("api-v1-forum", params: ["action": "comment", "id": "\(id)"])
    }
}

#endif
