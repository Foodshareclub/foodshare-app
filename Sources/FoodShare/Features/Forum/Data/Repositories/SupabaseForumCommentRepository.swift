
#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - Supabase Forum Comment Repository

/// Handles forum comments CRUD, replies, and threading
@MainActor
final class SupabaseForumCommentRepository: BaseSupabaseRepository, @unchecked Sendable {
    private let apiService: ForumAPIService
    
    init(supabase: Supabase.SupabaseClient, apiService: ForumAPIService = .shared) {
        self.apiService = apiService
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ForumCommentRepository")
    }

    // MARK: - Comments

    func fetchComments(forumId: Int, pagination: CursorPaginationParams) async throws -> [ForumComment] {
        // API doesn't support cursor pagination yet, use limit/offset
        try await apiService.getComments(forumId: forumId, limit: pagination.limit, offset: 0)
    }

    func fetchComments(forumId: Int, limit: Int, offset: Int) async throws -> [ForumComment] {
        try await apiService.getComments(forumId: forumId, limit: limit, offset: offset)
    }

    func createComment(_ request: CreateCommentRequest) async throws -> ForumComment {
        try await apiService.createComment(
            forumId: request.forumId,
            content: request.comment,
            parentId: request.parentId
        )
    }

    func deleteComment(id: Int) async throws {
        try await apiService.deleteComment(id: id)
    }

    func updateComment(id: Int, content: String) async throws -> ForumComment {
        try await apiService.updateComment(id: id, content: content)
    }

    func fetchReplies(commentId: Int, limit: Int, offset: Int) async throws -> [ForumComment] {
        // Replies are comments with parent_id set - API doesn't have dedicated endpoint yet
        // Keep direct query for now
        try await supabase
            .from("comments")
            .select("""
                *,
                author:profiles!comments_user_id_fkey(id, nickname, avatar_url, is_verified)
            """)
            .eq("parent_id", value: commentId)
            .order("comment_created_at", ascending: true)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }
}

#endif
