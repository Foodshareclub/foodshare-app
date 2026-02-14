import FoodShareRepository
import Foundation
import OSLog
import Supabase

// MARK: - Supabase Forum Engagement Repository

/// Handles forum likes, bookmarks, reactions, and views
@MainActor
final class SupabaseForumEngagementRepository: BaseSupabaseRepository, @unchecked Sendable {
    private let apiService: ForumAPIService
    
    init(supabase: Supabase.SupabaseClient, apiService: ForumAPIService = .shared) {
        self.apiService = apiService
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ForumEngagementRepository")
    }

    // MARK: - Reactions (Legacy Like)

    func togglePostLike(forumId: Int, profileId: UUID) async throws -> Bool {
        let response = try await apiService.toggleLike(forumId: forumId)
        return response.isLiked
    }

    func toggleCommentLike(commentId: Int, profileId: UUID) async throws -> Bool {
        // Single RPC call - uses unified likes table with comment_id
        let response = try await supabase
            .rpc("toggle_comment_like", params: ["p_comment_id": commentId])
            .execute()

        let result = try JSONDecoder().decode(ToggleCommentLikeResponse.self, from: response.data)

        guard result.success else {
            if let error = result.error {
                throw AppError.networkError(error.message)
            }
            throw AppError.networkError("Failed to toggle comment like")
        }

        return result.isLiked ?? false
    }

    func hasLikedPost(forumId: Int, profileId: UUID) async throws -> Bool {
        let existing: [LikeRecord] = try await supabase
            .from("likes")
            .select()
            .eq("forum_id", value: forumId)
            .eq("profile_id", value: profileId)
            .execute()
            .value

        return !existing.isEmpty
    }

    // MARK: - Emoji Reactions

    func fetchReactionTypes() async throws -> [ReactionType] {
        try await fetchMany(
            from: "reaction_types",
            orderBy: "sort_order",
            ascending: true,
            limit: nil,
        )
    }

    func fetchPostReactions(forumId: Int, profileId: UUID) async throws -> ReactionsSummary {
        struct PostReactionsParams: Encodable, Sendable {
            let pForumId: Int
            let pProfileId: UUID

            enum CodingKeys: String, CodingKey {
                case pForumId = "p_forum_id"
                case pProfileId = "p_profile_id"
            }
        }

        let dto: PostReactionsDTO = try await executeRPC(
            "get_post_reactions",
            params: PostReactionsParams(pForumId: forumId, pProfileId: profileId),
        )

        return ReactionsSummary.from(
            reactionsCount: dto.reactionsCount,
            userReactionTypeIds: dto.userReactionTypeIds,
        )
    }

    func fetchCommentReactions(commentId: Int, profileId: UUID) async throws -> ReactionsSummary {
        // Fetch comment to get reactions_count JSONB
        let comment: CommentReactionsDTO = try await supabase
            .from("comments")
            .select("reactions_count")
            .eq("id", value: commentId)
            .single()
            .execute()
            .value

        // Fetch user's reactions for this comment
        let userReactions: [CommentReactionDTO] = try await supabase
            .from("forum_comment_reactions")
            .select("reaction_type_id")
            .eq("comment_id", value: commentId)
            .eq("profile_id", value: profileId)
            .execute()
            .value

        let userReactionTypeIds = userReactions.map(\.reaction_type_id)
        return ReactionsSummary.from(
            reactionsCount: comment.reactions_count ?? [:],
            userReactionTypeIds: userReactionTypeIds,
        )
    }

    func togglePostReaction(forumId: Int, reactionTypeId: Int, profileId: UUID) async throws -> ReactionsSummary {
        guard let reactionType = ReactionType.all.first(where: { $0.id == reactionTypeId }) else {
            throw ValidationError.custom("Invalid reaction type ID: \(reactionTypeId)")
        }

        let result = try await apiService.toggleReaction(forumId: forumId, reactionType: reactionType.name)
        
        var userReactionTypeIds = [Int]()
        if result.action == "added" {
            userReactionTypeIds.append(reactionTypeId)
        }

        return ReactionsSummary.from(
            reactionsCount: result.reactionsCount ?? [:],
            userReactionTypeIds: userReactionTypeIds
        )
    }

    func toggleCommentReaction(commentId: Int, reactionTypeId: Int, profileId: UUID) async throws -> ReactionsSummary {
        struct ToggleCommentReactionParams: Encodable, Sendable {
            let p_comment_id: Int
            let p_reaction_type_id: Int
        }

        let result: ToggleCommentReactionResult = try await executeRPC(
            "toggle_comment_reaction",
            params: ToggleCommentReactionParams(
                p_comment_id: commentId,
                p_reaction_type_id: reactionTypeId,
            ),
        )

        var userReactionTypeIds = [Int]()
        if result.wasAdded {
            userReactionTypeIds.append(reactionTypeId)
        }

        return ReactionsSummary.from(
            reactionsCount: result.reactionCounts ?? [:],
            userReactionTypeIds: userReactionTypeIds,
        )
    }

    func fetchPostReactors(forumId: Int, reactionTypeId: Int, limit: Int) async throws -> [UUID] {
        let reactions: [ReactorDTO] = try await supabase
            .from("forum_reactions")
            .select("profile_id")
            .eq("forum_id", value: forumId)
            .eq("reaction_type_id", value: reactionTypeId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return reactions.map(\.profile_id)
    }

    // MARK: - Bookmarks

    func toggleBookmark(forumId: Int, profileId: UUID) async throws -> Bool {
        let result = try await apiService.toggleBookmark(forumId: forumId)
        return result.isBookmarked
    }

    func fetchBookmarkedPosts(profileId: UUID, pagination: CursorPaginationParams) async throws -> [ForumPost] {
        try await apiService.getBookmarks()
    }

    func fetchBookmarkedPosts(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumPost] {
        try await apiService.getBookmarks()
    }

    func recordView(forumId: Int, profileId: UUID) async throws {
        try await apiService.recordView(forumId: forumId)
    }
}

// MARK: - Helper Types

private struct LikeRecord: Codable {
    let id: Int
}

private struct LikeInsertDTO: Encodable {
    let forum_id: Int
    let profile_id: String
}

// MARK: - RPC Response DTOs

/// Response from toggle_comment_like RPC
private struct ToggleCommentLikeResponse: Decodable {
    let success: Bool
    let isLiked: Bool?
    let likeCount: Int?
    let commentAuthorId: UUID?
    let error: RPCError?

    enum CodingKeys: String, CodingKey {
        case success
        case isLiked = "is_liked"
        case likeCount = "like_count"
        case commentAuthorId = "comment_author_id"
        case error
    }

    struct RPCError: Decodable {
        let code: String
        let message: String
    }
}

/// Result from toggle_forum_bookmark RPC
private struct ToggleBookmarkResult: Codable {
    let bookmarked: Bool
    let message: String
}

/// Result from toggle_forum_reaction RPC
private struct ToggleReactionRPCResult: Codable {
    let action: String
    let reaction: String
    let reactionsCount: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case action
        case reaction
        case reactionsCount = "reactions_count"
    }

    /// Whether the reaction was added (vs removed)
    var wasAdded: Bool {
        action == "added"
    }
}

/// Result from toggle_comment_reaction RPC
private struct ToggleCommentReactionResult: Codable {
    let action: String
    let reactionCounts: [String: Int]?

    enum CodingKeys: String, CodingKey {
        case action
        case reactionCounts = "reaction_counts"
    }

    var wasAdded: Bool {
        action == "added"
    }
}

// MARK: - Reaction DTOs

private struct CommentReactionsDTO: Codable {
    let reactions_count: [String: Int]?
}

private struct CommentReactionDTO: Codable {
    let reaction_type_id: Int
}

private struct ReactorDTO: Codable {
    let profile_id: UUID
}

/// Parameters for the get_post_reactions RPC
private struct PostReactionsParams: Encodable {
    let pForumId: Int
    let pProfileId: UUID

    enum CodingKeys: String, CodingKey {
        case pForumId = "p_forum_id"
        case pProfileId = "p_profile_id"
    }
}

/// DTO for decoding the get_post_reactions RPC response
private struct PostReactionsDTO: Decodable {
    let reactionsCount: [String: Int]
    let userReactionTypeIds: [Int]

    enum CodingKeys: String, CodingKey {
        case reactionsCount = "reactions_count"
        case userReactionTypeIds = "user_reaction_type_ids"
    }
}
