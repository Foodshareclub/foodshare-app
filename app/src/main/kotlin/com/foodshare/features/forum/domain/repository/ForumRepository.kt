package com.foodshare.features.forum.domain.repository

import com.foodshare.features.forum.domain.model.*
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for forum operations.
 *
 * SYNC: This mirrors Swift ForumRepository protocol
 */
interface ForumRepository {
    // Posts
    suspend fun getPosts(
        filters: ForumFilters = ForumFilters(),
        limit: Int = 20,
        cursor: String? = null
    ): Result<List<ForumPost>>

    suspend fun getPost(id: Int): Result<ForumPost>

    suspend fun searchPosts(query: String, limit: Int = 20): Result<List<ForumPost>>

    suspend fun getTrendingPosts(limit: Int = 10): Result<List<ForumPost>>

    suspend fun getPinnedPosts(categoryId: Int? = null): Result<List<ForumPost>>

    suspend fun createPost(
        title: String,
        description: String,
        categoryId: Int?,
        postType: ForumPostType,
        imageUrl: String? = null
    ): Result<ForumPost>

    suspend fun updatePost(
        id: Int,
        title: String? = null,
        description: String? = null,
        categoryId: Int? = null,
        imageUrl: String? = null
    ): Result<ForumPost>

    suspend fun deletePost(id: Int): Result<Unit>

    // Categories
    suspend fun getCategories(): Result<List<ForumCategory>>

    suspend fun getPopularTags(limit: Int = 20): Result<List<ForumTag>>

    // Comments
    suspend fun getComments(
        forumId: Int,
        limit: Int = 20,
        cursor: String? = null
    ): Result<List<ForumComment>>

    suspend fun getReplies(commentId: Int): Result<List<ForumComment>>

    suspend fun createComment(
        forumId: Int,
        content: String,
        parentId: Int? = null
    ): Result<ForumComment>

    suspend fun updateComment(id: Int, content: String): Result<ForumComment>

    suspend fun deleteComment(id: Int): Result<Unit>

    suspend fun markAsBestAnswer(commentId: Int, forumId: Int): Result<Unit>

    // Reactions
    suspend fun getReactionTypes(): Result<List<ReactionType>>

    suspend fun togglePostReaction(postId: Int, reactionType: String): Result<ReactionsSummary>

    suspend fun toggleCommentReaction(commentId: Int, reactionType: String): Result<ReactionsSummary>

    suspend fun getPostReactions(postId: Int): Result<ReactionsSummary>

    suspend fun getCommentReactions(commentId: Int): Result<ReactionsSummary>

    // Bookmarks
    suspend fun toggleBookmark(postId: Int): Result<Boolean>

    suspend fun getBookmarkedPosts(limit: Int = 20, cursor: String? = null): Result<List<ForumPost>>

    // Views
    suspend fun recordView(postId: Int): Result<Unit>

    // Notifications
    suspend fun getNotifications(
        limit: Int = 20,
        cursor: String? = null,
        unreadOnly: Boolean = false
    ): Result<List<ForumNotification>>

    suspend fun getUnreadNotificationCount(): Result<Int>

    suspend fun markNotificationAsRead(id: Int): Result<Unit>

    suspend fun markAllNotificationsAsRead(): Result<Unit>

    // Realtime
    fun observePosts(categoryId: Int? = null): Flow<ForumPost>

    fun observeComments(forumId: Int): Flow<ForumComment>
}
