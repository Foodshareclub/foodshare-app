package com.foodshare.features.forum.data.dto

import com.foodshare.features.forum.domain.model.*
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for forum post from Supabase.
 */
@Serializable
data class ForumPostDto(
    val id: Int,
    @SerialName("user_id") val userId: String,
    val title: String,
    val description: String,
    @SerialName("category_id") val categoryId: Int? = null,
    @SerialName("post_type") val postType: String = "discussion",
    @SerialName("image_url") val imageUrl: String? = null,
    @SerialName("likes_counter") val likesCount: Int = 0,
    @SerialName("comments_counter") val commentsCount: Int = 0,
    @SerialName("views_counter") val viewsCount: Int = 0,
    @SerialName("is_pinned") val isPinned: Boolean = false,
    @SerialName("is_locked") val isLocked: Boolean = false,
    @SerialName("is_edited") val isEdited: Boolean = false,
    @SerialName("is_featured") val isFeatured: Boolean = false,
    @SerialName("hot_score") val hotScore: Double = 0.0,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String? = null,
    // Joined data
    val profiles: ForumAuthorDto? = null,
    @SerialName("forum_categories") val category: ForumCategoryDto? = null
) {
    fun toDomain(
        isBookmarked: Boolean = false,
        userReaction: String? = null
    ) = ForumPost(
        id = id,
        userId = userId,
        title = title,
        description = description,
        categoryId = categoryId,
        postType = parsePostType(postType),
        imageUrl = imageUrl,
        likesCount = likesCount,
        commentsCount = commentsCount,
        viewsCount = viewsCount,
        isPinned = isPinned,
        isLocked = isLocked,
        isEdited = isEdited,
        isFeatured = isFeatured,
        hotScore = hotScore,
        createdAt = createdAt,
        updatedAt = updatedAt,
        author = profiles?.toDomain(),
        category = category?.toDomain(),
        isBookmarked = isBookmarked,
        userReaction = userReaction
    )

    private fun parsePostType(type: String): ForumPostType = when (type) {
        "question" -> ForumPostType.QUESTION
        "announcement" -> ForumPostType.ANNOUNCEMENT
        "guide" -> ForumPostType.GUIDE
        else -> ForumPostType.DISCUSSION
    }
}

/**
 * DTO for forum author/profile.
 */
@Serializable
data class ForumAuthorDto(
    val id: String,
    val nickname: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("is_verified") val isVerified: Boolean = false
) {
    fun toDomain() = ForumAuthor(
        id = id,
        nickname = nickname,
        avatarUrl = avatarUrl,
        isVerified = isVerified
    )
}

/**
 * DTO for forum category.
 */
@Serializable
data class ForumCategoryDto(
    val id: Int,
    val name: String,
    val slug: String,
    val description: String? = null,
    val color: String? = null,
    val icon: String? = null,
    @SerialName("posts_count") val postsCount: Int = 0,
    @SerialName("is_active") val isActive: Boolean = true
) {
    fun toDomain() = ForumCategory(
        id = id,
        name = name,
        slug = slug,
        description = description,
        color = color,
        icon = icon,
        postsCount = postsCount,
        isActive = isActive
    )
}

/**
 * DTO for forum comment.
 */
@Serializable
data class ForumCommentDto(
    val id: Int,
    @SerialName("user_id") val userId: String,
    @SerialName("forum_id") val forumId: Int,
    @SerialName("parent_id") val parentId: Int? = null,
    val comment: String,
    val depth: Int = 0,
    @SerialName("likes_counter") val likesCount: Int = 0,
    @SerialName("replies_counter") val repliesCount: Int = 0,
    @SerialName("is_best_answer") val isBestAnswer: Boolean = false,
    @SerialName("is_edited") val isEdited: Boolean = false,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String? = null,
    val profiles: ForumAuthorDto? = null
) {
    fun toDomain(userReaction: String? = null) = ForumComment(
        id = id,
        userId = userId,
        forumId = forumId,
        parentId = parentId,
        comment = comment,
        depth = depth,
        likesCount = likesCount,
        repliesCount = repliesCount,
        isBestAnswer = isBestAnswer,
        isEdited = isEdited,
        createdAt = createdAt,
        updatedAt = updatedAt,
        author = profiles?.toDomain(),
        userReaction = userReaction
    )
}

/**
 * DTO for forum notification.
 */
@Serializable
data class ForumNotificationDto(
    val id: Int,
    @SerialName("user_id") val userId: String,
    val type: String,
    @SerialName("forum_id") val forumId: Int? = null,
    @SerialName("comment_id") val commentId: Int? = null,
    @SerialName("actor_id") val actorId: String? = null,
    val message: String,
    @SerialName("is_read") val isRead: Boolean = false,
    @SerialName("created_at") val createdAt: String,
    val actor: ForumAuthorDto? = null
) {
    fun toDomain() = ForumNotification(
        id = id,
        userId = userId,
        type = parseNotificationType(type),
        forumId = forumId,
        commentId = commentId,
        actorId = actorId,
        message = message,
        isRead = isRead,
        createdAt = createdAt,
        actor = actor?.toDomain()
    )

    private fun parseNotificationType(type: String): ForumNotificationType = when (type) {
        "reply" -> ForumNotificationType.REPLY
        "mention" -> ForumNotificationType.MENTION
        "reaction" -> ForumNotificationType.REACTION
        "new_post" -> ForumNotificationType.NEW_POST
        "liked" -> ForumNotificationType.LIKED
        "badge_earned" -> ForumNotificationType.BADGE_EARNED
        "level_up" -> ForumNotificationType.LEVEL_UP
        "poll_ended" -> ForumNotificationType.POLL_ENDED
        "pinned" -> ForumNotificationType.PINNED
        "solved" -> ForumNotificationType.SOLVED
        else -> ForumNotificationType.NEW_POST
    }
}

// Request DTOs

@Serializable
data class CreateForumPostRequest(
    val title: String,
    val description: String,
    @SerialName("category_id") val categoryId: Int?,
    @SerialName("post_type") val postType: String = "discussion",
    @SerialName("image_url") val imageUrl: String? = null
)

@Serializable
data class UpdateForumPostRequest(
    val title: String? = null,
    val description: String? = null,
    @SerialName("category_id") val categoryId: Int? = null,
    @SerialName("image_url") val imageUrl: String? = null
)

@Serializable
data class CreateCommentRequest(
    @SerialName("forum_id") val forumId: Int,
    val comment: String,
    @SerialName("parent_id") val parentId: Int? = null,
    val depth: Int = 0
)

// RPC Response DTOs

@Serializable
data class ToggleReactionResponse(
    val success: Boolean,
    val action: String, // "added" or "removed"
    val reactions: Map<String, Int> = emptyMap(),
    @SerialName("user_reactions") val userReactions: List<String> = emptyList(),
    @SerialName("total_count") val totalCount: Int = 0
) {
    fun toReactionsSummary() = ReactionsSummary(
        reactions = reactions,
        userReactions = userReactions,
        totalCount = totalCount
    )
}

@Serializable
data class ToggleBookmarkResponse(
    val success: Boolean,
    @SerialName("is_bookmarked") val isBookmarked: Boolean
)

@Serializable
data class SearchForumResponse(
    val posts: List<ForumPostDto> = emptyList(),
    @SerialName("total_count") val totalCount: Int = 0
)

@Serializable
data class GetReactionsResponse(
    val reactions: Map<String, Int> = emptyMap(),
    @SerialName("user_reactions") val userReactions: List<String> = emptyList(),
    @SerialName("total_count") val totalCount: Int = 0
) {
    fun toReactionsSummary() = ReactionsSummary(
        reactions = reactions,
        userReactions = userReactions,
        totalCount = totalCount
    )
}
