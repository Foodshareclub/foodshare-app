//
//  ForumAPIService.swift
//  Foodshare
//
//  REST API client for forum operations via api-v1-forum edge function
//

import Foundation
import OSLog
import Supabase

actor ForumAPIService {
    nonisolated static let shared = ForumAPIService()
    
    private let client: APIClient
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ForumAPI")
    
    init(client: APIClient = .shared) {
        self.client = client
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
        var body: [String: Any] = ["title": title, "description": description, "postType": postType]
        if let categoryId = categoryId { body["categoryId"] = categoryId }
        return try await client.post("api-v1-forum", body: body, params: ["action": "create"])
    }
    
    func createComment(forumId: Int, content: String, parentId: Int? = nil) async throws -> ForumComment {
        var body: [String: Any] = ["forumId": forumId, "content": content]
        if let parentId = parentId { body["parentId"] = parentId }
        return try await client.post("api-v1-forum", body: body, params: ["action": "comment"])
    }
    
    func toggleLike(forumId: Int) async throws -> LikeResponse {
        try await client.post("api-v1-forum", body: ["forumId": forumId], params: ["action": "like"])
    }
    
    func toggleBookmark(forumId: Int) async throws -> BookmarkResponse {
        try await client.post("api-v1-forum", body: ["forumId": forumId], params: ["action": "bookmark"])
    }
    
    func toggleReaction(forumId: Int, reactionType: String) async throws -> ReactionResponse {
        try await client.post("api-v1-forum", body: ["forumId": forumId, "reactionType": reactionType], params: ["action": "react"])
    }
    
    func recordView(forumId: Int) async throws {
        let _: EmptyResponse = try await client.post("api-v1-forum", body: ["forumId": forumId], params: ["action": "view"])
    }
    
    // MARK: - Poll Operations
    
    func getPoll(pollId: String) async throws -> ForumPoll {
        try await client.get("api-v1-forum/poll", params: ["id": pollId])
    }
    
    func votePoll(pollId: String, optionIds: [String]) async throws -> ForumPoll {
        try await client.post("api-v1-forum/poll/vote", body: ["pollId": pollId, "optionIds": optionIds])
    }
    
    // MARK: - Reputation Operations
    
    func incrementStat(userId: String, stat: String, amount: Int) async throws {
        let _: EmptyResponse = try await client.post("api-v1-forum/reputation/increment", body: [
            "userId": userId,
            "stat": stat,
            "amount": amount
        ])
    }
    
    // MARK: - PUT Operations
    
    func updatePost(id: Int, title: String? = nil, description: String? = nil) async throws -> ForumPost {
        var body: [String: Any] = [:]
        if let title = title { body["title"] = title }
        if let description = description { body["description"] = description }
        return try await client.put("api-v1-forum", body: body, params: ["id": "\(id)"])
    }
    
    func updateComment(id: Int, content: String) async throws -> ForumComment {
        try await client.put("api-v1-forum", body: ["content": content], params: ["action": "comment", "id": "\(id)"])
    }
    
    // MARK: - DELETE Operations
    
    func deletePost(id: Int) async throws {
        let _: EmptyResponse = try await client.delete("api-v1-forum", params: ["id": "\(id)"])
    }
    
    func deleteComment(id: Int) async throws {
        let _: EmptyResponse = try await client.delete("api-v1-forum", params: ["action": "comment", "id": "\(id)"])
    }
}

// MARK: - Response Types

struct ForumPost: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let profileId: String
    let categoryId: Int?
    let postType: String
    let likeCount: Int
    let commentCount: Int
    let viewCount: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, categoryId, postType, likeCount, commentCount, viewCount, createdAt, updatedAt
        case profileId = "profile_id"
    }
}

struct ForumCategory: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let icon: String?
}

struct ForumComment: Codable, Identifiable {
    let id: Int
    let forumId: Int
    let profileId: String
    let content: String
    let parentId: Int?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, content, createdAt
        case forumId = "forum_id"
        case profileId = "profile_id"
        case parentId = "parent_id"
    }
}

struct LikeResponse: Codable {
    let isLiked: Bool
    let likeCount: Int
}

struct BookmarkResponse: Codable {
    let isBookmarked: Bool
}

struct ReactionResponse: Codable {
    let action: String
    let reactionsCount: [String: Int]?
}

struct ForumPoll: Codable {
    let id: String
    let question: String
    let options: [PollOption]
    let totalVotes: Int
    
    struct PollOption: Codable {
        let id: String
        let text: String
        let votes: Int
    }
}

// Remove ForumAPIError - use APIError from APIClient instead
