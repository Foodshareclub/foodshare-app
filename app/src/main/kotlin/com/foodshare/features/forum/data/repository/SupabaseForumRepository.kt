package com.foodshare.features.forum.data.repository

import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.network.RPCConfig
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.core.realtime.RealtimeFilter
import com.foodshare.features.forum.data.dto.*
import com.foodshare.features.forum.domain.model.*
import com.foodshare.features.forum.domain.repository.ForumRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of ForumRepository.
 *
 * SYNC: This mirrors Swift SupabaseForumRepository
 */
@Singleton
class SupabaseForumRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val rpcClient: RateLimitedRPCClient,
    private val realtimeManager: RealtimeChannelManager
) : ForumRepository {

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    // Posts

    override suspend fun getPosts(
        filters: ForumFilters,
        limit: Int,
        cursor: String?
    ): Result<List<ForumPost>> = runCatching {
        supabaseClient.from("forums")
            .select(Columns.raw(POSTS_SELECT)) {
                // Apply filters
                filter {
                    filters.categoryId?.let { eq("category_id", it) }
                    filters.postType?.let { eq("post_type", it.name.lowercase()) }
                    if (filters.showPinnedOnly) eq("is_pinned", true)
                    if (filters.showQuestionsOnly) eq("post_type", "question")
                    if (filters.showUnansweredOnly) eq("comments_counter", 0)
                    cursor?.let { lt("created_at", it) }
                }
                order(filters.sortBy.column, Order.DESCENDING)
                limit(limit.toLong())
            }
            .decodeList<ForumPostDto>()
            .map { it.toDomain() }
    }

    override suspend fun getPost(id: Int): Result<ForumPost> = runCatching {
        supabaseClient.from("forums")
            .select(Columns.raw(POSTS_SELECT)) {
                filter { eq("id", id) }
                limit(1)
            }
            .decodeSingleOrNull<ForumPostDto>()
            ?.toDomain()
            ?: throw NoSuchElementException("Post not found")
    }

    override suspend fun searchPosts(query: String, limit: Int): Result<List<ForumPost>> {
        val params = SearchForumParams(
            searchQuery = query,
            limit = limit
        )

        return rpcClient.call<SearchForumParams, SearchForumResponse>(
            functionName = "search_forum",
            params = params,
            config = RPCConfig.bulk
        ).map { response ->
            response.posts.map { it.toDomain() }
        }
    }

    override suspend fun getTrendingPosts(limit: Int): Result<List<ForumPost>> = runCatching {
        supabaseClient.from("forums")
            .select(Columns.raw(POSTS_SELECT)) {
                order("hot_score", Order.DESCENDING)
                limit(limit.toLong())
            }
            .decodeList<ForumPostDto>()
            .map { it.toDomain() }
    }

    override suspend fun getPinnedPosts(categoryId: Int?): Result<List<ForumPost>> = runCatching {
        supabaseClient.from("forums")
            .select(Columns.raw(POSTS_SELECT)) {
                filter {
                    eq("is_pinned", true)
                    categoryId?.let { eq("category_id", it) }
                }
                order("updated_at", Order.DESCENDING)
            }
            .decodeList<ForumPostDto>()
            .map { it.toDomain() }
    }

    override suspend fun createPost(
        title: String,
        description: String,
        categoryId: Int?,
        postType: ForumPostType,
        imageUrl: String?
    ): Result<ForumPost> = runCatching {
        val userId = currentUserId ?: throw IllegalStateException("Not authenticated")

        supabaseClient.from("forums")
            .insert(mapOf(
                "user_id" to userId,
                "title" to title,
                "description" to description,
                "category_id" to categoryId,
                "post_type" to postType.name.lowercase(),
                "image_url" to imageUrl
            )) {
                select(Columns.raw(POSTS_SELECT))
            }
            .decodeSingle<ForumPostDto>()
            .toDomain()
    }

    override suspend fun updatePost(
        id: Int,
        title: String?,
        description: String?,
        categoryId: Int?,
        imageUrl: String?
    ): Result<ForumPost> = runCatching {
        val updates = mutableMapOf<String, Any?>()
        title?.let { updates["title"] = it }
        description?.let { updates["description"] = it }
        categoryId?.let { updates["category_id"] = it }
        imageUrl?.let { updates["image_url"] = it }
        updates["is_edited"] = true

        supabaseClient.from("forums")
            .update(updates) {
                filter { eq("id", id) }
                select(Columns.raw(POSTS_SELECT))
            }
            .decodeSingle<ForumPostDto>()
            .toDomain()
    }

    override suspend fun deletePost(id: Int): Result<Unit> = runCatching {
        supabaseClient.from("forums")
            .delete {
                filter { eq("id", id) }
            }
    }

    // Categories

    override suspend fun getCategories(): Result<List<ForumCategory>> = runCatching {
        supabaseClient.from("forum_categories")
            .select {
                filter { eq("is_active", true) }
                order("name", Order.ASCENDING)
            }
            .decodeList<ForumCategoryDto>()
            .map { it.toDomain() }
    }

    override suspend fun getPopularTags(limit: Int): Result<List<ForumTag>> = runCatching {
        supabaseClient.from("forum_tags")
            .select {
                order("usage_count", Order.DESCENDING)
                limit(limit.toLong())
            }
            .decodeList<ForumTag>()
    }

    // Comments

    override suspend fun getComments(
        forumId: Int,
        limit: Int,
        cursor: String?
    ): Result<List<ForumComment>> = runCatching {
        supabaseClient.from("forum_comments")
            .select(Columns.raw(COMMENTS_SELECT)) {
                filter {
                    eq("forum_id", forumId)
                    exact("parent_id", null) // Top-level comments only
                }
                cursor?.let { filter { lt("created_at", it) } }
                order("created_at", Order.DESCENDING)
                limit(limit.toLong())
            }
            .decodeList<ForumCommentDto>()
            .map { it.toDomain() }
    }

    override suspend fun getReplies(commentId: Int): Result<List<ForumComment>> = runCatching {
        supabaseClient.from("forum_comments")
            .select(Columns.raw(COMMENTS_SELECT)) {
                filter { eq("parent_id", commentId) }
                order("created_at", Order.ASCENDING)
            }
            .decodeList<ForumCommentDto>()
            .map { it.toDomain() }
    }

    override suspend fun createComment(
        forumId: Int,
        content: String,
        parentId: Int?
    ): Result<ForumComment> = runCatching {
        val userId = currentUserId ?: throw IllegalStateException("Not authenticated")

        // Calculate depth based on parent
        val depth = if (parentId != null) {
            supabaseClient.from("forum_comments")
                .select(Columns.raw("depth")) {
                    filter { eq("id", parentId) }
                    limit(1)
                }
                .decodeSingleOrNull<DepthDto>()?.depth?.plus(1) ?: 1
        } else 0

        supabaseClient.from("forum_comments")
            .insert(mapOf(
                "user_id" to userId,
                "forum_id" to forumId,
                "comment" to content,
                "parent_id" to parentId,
                "depth" to minOf(depth, ForumComment.MAX_DEPTH)
            )) {
                select(Columns.raw(COMMENTS_SELECT))
            }
            .decodeSingle<ForumCommentDto>()
            .toDomain()
    }

    override suspend fun updateComment(id: Int, content: String): Result<ForumComment> = runCatching {
        supabaseClient.from("forum_comments")
            .update(mapOf(
                "comment" to content,
                "is_edited" to true
            )) {
                filter { eq("id", id) }
                select(Columns.raw(COMMENTS_SELECT))
            }
            .decodeSingle<ForumCommentDto>()
            .toDomain()
    }

    override suspend fun deleteComment(id: Int): Result<Unit> = runCatching {
        supabaseClient.from("forum_comments")
            .delete {
                filter { eq("id", id) }
            }
    }

    override suspend fun markAsBestAnswer(commentId: Int, forumId: Int): Result<Unit> = runCatching {
        // Unmark any existing best answer
        supabaseClient.from("forum_comments")
            .update(mapOf("is_best_answer" to false)) {
                filter {
                    eq("forum_id", forumId)
                    eq("is_best_answer", true)
                }
            }

        // Mark the new best answer
        supabaseClient.from("forum_comments")
            .update(mapOf("is_best_answer" to true)) {
                filter { eq("id", commentId) }
            }
    }

    // Reactions

    override suspend fun getReactionTypes(): Result<List<ReactionType>> {
        return Result.success(ReactionType.defaults)
    }

    override suspend fun togglePostReaction(
        postId: Int,
        reactionType: String
    ): Result<ReactionsSummary> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = ToggleReactionParams(
            forumId = postId,
            userId = userId,
            reactionType = reactionType
        )

        return rpcClient.call<ToggleReactionParams, ToggleReactionResponse>(
            functionName = "toggle_forum_reaction",
            params = params,
            config = RPCConfig.normal
        ).map { it.toReactionsSummary() }
    }

    override suspend fun toggleCommentReaction(
        commentId: Int,
        reactionType: String
    ): Result<ReactionsSummary> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = ToggleCommentReactionParams(
            commentId = commentId,
            userId = userId,
            reactionType = reactionType
        )

        return rpcClient.call<ToggleCommentReactionParams, ToggleReactionResponse>(
            functionName = "toggle_comment_reaction",
            params = params,
            config = RPCConfig.normal
        ).map { it.toReactionsSummary() }
    }

    override suspend fun getPostReactions(postId: Int): Result<ReactionsSummary> {
        val userId = currentUserId

        val params = GetReactionsParams(
            forumId = postId,
            userId = userId
        )

        return rpcClient.call<GetReactionsParams, GetReactionsResponse>(
            functionName = "get_post_reactions",
            params = params,
            config = RPCConfig.bulk
        ).map { it.toReactionsSummary() }
    }

    override suspend fun getCommentReactions(commentId: Int): Result<ReactionsSummary> {
        val userId = currentUserId

        val params = GetCommentReactionsParams(
            commentId = commentId,
            userId = userId
        )

        return rpcClient.call<GetCommentReactionsParams, GetReactionsResponse>(
            functionName = "get_comment_reactions",
            params = params,
            config = RPCConfig.bulk
        ).map { it.toReactionsSummary() }
    }

    // Bookmarks

    override suspend fun toggleBookmark(postId: Int): Result<Boolean> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = ToggleBookmarkParams(
            forumId = postId,
            userId = userId
        )

        return rpcClient.call<ToggleBookmarkParams, ToggleBookmarkResponse>(
            functionName = "toggle_forum_bookmark",
            params = params,
            config = RPCConfig.normal
        ).map { it.isBookmarked }
    }

    override suspend fun getBookmarkedPosts(limit: Int, cursor: String?): Result<List<ForumPost>> = runCatching {
        val userId = currentUserId ?: throw IllegalStateException("Not authenticated")

        supabaseClient.from("forum_bookmarks")
            .select(Columns.raw("forums($POSTS_SELECT)")) {
                filter { eq("user_id", userId) }
                cursor?.let { filter { lt("created_at", it) } }
                order("created_at", Order.DESCENDING)
                limit(limit.toLong())
            }
            .decodeList<BookmarkWithPostDto>()
            .mapNotNull { it.forums?.toDomain(isBookmarked = true) }
    }

    // Views

    override suspend fun recordView(postId: Int): Result<Unit> {
        val userId = currentUserId

        val params = RecordViewParams(
            forumId = postId,
            userId = userId
        )

        return rpcClient.call<RecordViewParams, Unit>(
            functionName = "increment_forum_view",
            params = params,
            config = RPCConfig.bulk
        )
    }

    // Notifications

    override suspend fun getNotifications(
        limit: Int,
        cursor: String?,
        unreadOnly: Boolean
    ): Result<List<ForumNotification>> = runCatching {
        val userId = currentUserId ?: throw IllegalStateException("Not authenticated")

        supabaseClient.from("forum_notifications")
            .select(Columns.raw(NOTIFICATIONS_SELECT)) {
                filter {
                    eq("user_id", userId)
                    if (unreadOnly) eq("is_read", false)
                }
                cursor?.let { filter { lt("created_at", it) } }
                order("created_at", Order.DESCENDING)
                limit(limit.toLong())
            }
            .decodeList<ForumNotificationDto>()
            .map { it.toDomain() }
    }

    override suspend fun getUnreadNotificationCount(): Result<Int> = runCatching {
        val userId = currentUserId ?: throw IllegalStateException("Not authenticated")

        // Use RPC for count queries as the API differs
        val params = GetUnreadCountParams(userId = userId)
        rpcClient.call<GetUnreadCountParams, UnreadCountResponse>(
            functionName = "get_forum_unread_count",
            params = params,
            config = RPCConfig.bulk
        ).getOrNull()?.count ?: 0
    }

    override suspend fun markNotificationAsRead(id: Int): Result<Unit> = runCatching {
        supabaseClient.from("forum_notifications")
            .update(mapOf("is_read" to true)) {
                filter { eq("id", id) }
            }
    }

    override suspend fun markAllNotificationsAsRead(): Result<Unit> = runCatching {
        val userId = currentUserId ?: throw IllegalStateException("Not authenticated")

        supabaseClient.from("forum_notifications")
            .update(mapOf("is_read" to true)) {
                filter {
                    eq("user_id", userId)
                    eq("is_read", false)
                }
            }
    }

    // Realtime

    override fun observePosts(categoryId: Int?): Flow<ForumPost> = channelFlow {
        val filter = RealtimeFilter(
            table = "forums",
            filter = categoryId?.let { "category_id=eq.$it" }
        )

        realtimeManager.subscribe<ForumPostDto>(filter)
            .collect { change ->
                change.currentRecord()?.toDomain()?.let { send(it) }
            }
    }

    override fun observeComments(forumId: Int): Flow<ForumComment> = channelFlow {
        val filter = RealtimeFilter(
            table = "forum_comments",
            filter = "forum_id=eq.$forumId"
        )

        realtimeManager.subscribe<ForumCommentDto>(filter)
            .collect { change ->
                change.currentRecord()?.toDomain()?.let { send(it) }
            }
    }

    companion object {
        private const val POSTS_SELECT = """
            *,
            profiles:user_id(id, nickname, avatar_url, is_verified),
            forum_categories:category_id(id, name, slug, description, color, icon)
        """

        private const val COMMENTS_SELECT = """
            *,
            profiles:user_id(id, nickname, avatar_url, is_verified)
        """

        private const val NOTIFICATIONS_SELECT = """
            *,
            actor:actor_id(id, nickname, avatar_url)
        """
    }
}

// RPC Parameter classes

@Serializable
private data class SearchForumParams(
    @SerialName("p_search_query") val searchQuery: String,
    @SerialName("p_limit") val limit: Int = 20
)

@Serializable
private data class ToggleReactionParams(
    @SerialName("p_forum_id") val forumId: Int,
    @SerialName("p_user_id") val userId: String,
    @SerialName("p_reaction_type") val reactionType: String
)

@Serializable
private data class ToggleCommentReactionParams(
    @SerialName("p_comment_id") val commentId: Int,
    @SerialName("p_user_id") val userId: String,
    @SerialName("p_reaction_type") val reactionType: String
)

@Serializable
private data class GetReactionsParams(
    @SerialName("p_forum_id") val forumId: Int,
    @SerialName("p_user_id") val userId: String? = null
)

@Serializable
private data class GetCommentReactionsParams(
    @SerialName("p_comment_id") val commentId: Int,
    @SerialName("p_user_id") val userId: String? = null
)

@Serializable
private data class ToggleBookmarkParams(
    @SerialName("p_forum_id") val forumId: Int,
    @SerialName("p_user_id") val userId: String
)

@Serializable
private data class RecordViewParams(
    @SerialName("p_forum_id") val forumId: Int,
    @SerialName("p_user_id") val userId: String? = null
)

@Serializable
private data class GetUnreadCountParams(
    @SerialName("p_user_id") val userId: String
)

@Serializable
private data class UnreadCountResponse(
    val count: Int = 0
)

@Serializable
private data class DepthDto(val depth: Int = 0)

@Serializable
private data class BookmarkWithPostDto(
    val forums: ForumPostDto? = null
)
