package com.foodshare.features.forum.domain.model

import com.foodshare.core.utilities.DateTimeFormatter
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Forum post types.
 *
 * SYNC: This mirrors Swift FoodshareCore.ForumPostType
 */
@Serializable
enum class ForumPostType {
    @SerialName("discussion") DISCUSSION,
    @SerialName("question") QUESTION,
    @SerialName("announcement") ANNOUNCEMENT,
    @SerialName("guide") GUIDE;

    val displayName: String
        get() = when (this) {
            DISCUSSION -> "Discussion"
            QUESTION -> "Question"
            ANNOUNCEMENT -> "Announcement"
            GUIDE -> "Guide"
        }
}

/**
 * Forum post author - lightweight profile reference.
 *
 * SYNC: This mirrors Swift FoodshareCore.ForumAuthor
 */
@Serializable
data class ForumAuthor(
    val id: String,
    val nickname: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("is_verified") val isVerified: Boolean = false
) {
    val displayName: String
        get() = nickname ?: "Anonymous"
}

/**
 * Forum category.
 *
 * SYNC: This mirrors Swift FoodshareCore.ForumCategory
 */
@Serializable
data class ForumCategory(
    val id: Int,
    val name: String,
    val slug: String,
    val description: String? = null,
    val color: String? = null,
    val icon: String? = null,
    @SerialName("posts_count") val postsCount: Int = 0,
    @SerialName("is_active") val isActive: Boolean = true
) {
    companion object {
        val defaults = listOf(
            ForumCategory(1, "General", "general", "General discussion", "#4CAF50", "message-circle"),
            ForumCategory(2, "Tips & Tricks", "tips", "Share tips", "#2196F3", "lightbulb"),
            ForumCategory(3, "Questions", "questions", "Ask questions", "#FF9800", "help-circle"),
            ForumCategory(4, "Announcements", "announcements", "Official updates", "#9C27B0", "megaphone")
        )
    }
}

/**
 * Forum tag for content categorization.
 */
@Serializable
data class ForumTag(
    val id: Int,
    val name: String,
    val slug: String,
    @SerialName("usage_count") val usageCount: Int = 0
)

/**
 * Forum post.
 *
 * SYNC: This mirrors Swift FoodshareCore.ForumPost
 */
@Serializable
data class ForumPost(
    val id: Int,
    @SerialName("user_id") val userId: String,
    val title: String,
    val description: String,
    @SerialName("category_id") val categoryId: Int? = null,
    @SerialName("post_type") val postType: ForumPostType = ForumPostType.DISCUSSION,
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
    val author: ForumAuthor? = null,
    val category: ForumCategory? = null,
    val tags: List<ForumTag> = emptyList(),
    // User-specific state
    @SerialName("is_bookmarked") val isBookmarked: Boolean = false,
    @SerialName("user_reaction") val userReaction: String? = null
) {
    val displayTitle: String
        get() = title.take(100)

    val previewDescription: String
        get() = description.take(200).let {
            if (description.length > 200) "$it..." else it
        }

    /** Format createdAt as relative time. */
    val relativeTime: String
        get() = DateTimeFormatter.formatRelativeDate(createdAt)
}

/**
 * Forum comment with threading support.
 */
@Serializable
data class ForumComment(
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
    // Joined data
    val author: ForumAuthor? = null,
    // User-specific state
    @SerialName("user_reaction") val userReaction: String? = null
) {
    val isReply: Boolean
        get() = parentId != null

    /** Format createdAt as relative time. */
    val relativeTime: String
        get() = DateTimeFormatter.formatRelativeDate(createdAt)

    companion object {
        const val MAX_DEPTH = 2
    }
}

/**
 * Reaction types for forum posts and comments.
 */
@Serializable
data class ReactionType(
    val id: String,
    val emoji: String,
    val name: String
) {
    companion object {
        val defaults = listOf(
            ReactionType("like", "👍", "Like"),
            ReactionType("love", "❤️", "Love"),
            ReactionType("celebrate", "🎉", "Celebrate"),
            ReactionType("helpful", "💡", "Helpful"),
            ReactionType("insightful", "🤔", "Insightful"),
            ReactionType("funny", "😄", "Funny")
        )
    }
}

/**
 * Aggregated reactions summary.
 */
@Serializable
data class ReactionsSummary(
    val reactions: Map<String, Int> = emptyMap(),
    @SerialName("user_reactions") val userReactions: List<String> = emptyList(),
    @SerialName("total_count") val totalCount: Int = 0
) {
    fun hasUserReacted(reactionType: String): Boolean =
        userReactions.contains(reactionType)
}

/**
 * Forum filters for querying posts.
 */
data class ForumFilters(
    val categoryId: Int? = null,
    val postType: ForumPostType? = null,
    val sortBy: ForumSortOption = ForumSortOption.NEWEST,
    val searchQuery: String = "",
    val showPinnedOnly: Boolean = false,
    val showQuestionsOnly: Boolean = false,
    val showUnansweredOnly: Boolean = false
)

/**
 * Sort options for forum posts.
 */
enum class ForumSortOption(val column: String, val ascending: Boolean = false) {
    NEWEST("created_at", false),
    OLDEST("created_at", true),
    MOST_LIKED("likes_counter", false),
    MOST_COMMENTED("comments_counter", false),
    TRENDING("hot_score", false);

    val displayName: String
        get() = when (this) {
            NEWEST -> "Newest"
            OLDEST -> "Oldest"
            MOST_LIKED -> "Most Liked"
            MOST_COMMENTED -> "Most Discussed"
            TRENDING -> "Trending"
        }
}

/**
 * Forum notification types.
 */
@Serializable
enum class ForumNotificationType {
    @SerialName("reply") REPLY,
    @SerialName("mention") MENTION,
    @SerialName("reaction") REACTION,
    @SerialName("new_post") NEW_POST,
    @SerialName("liked") LIKED,
    @SerialName("badge_earned") BADGE_EARNED,
    @SerialName("level_up") LEVEL_UP,
    @SerialName("poll_ended") POLL_ENDED,
    @SerialName("pinned") PINNED,
    @SerialName("solved") SOLVED
}

/**
 * Forum notification.
 */
@Serializable
data class ForumNotification(
    val id: Int,
    @SerialName("user_id") val userId: String,
    val type: ForumNotificationType,
    @SerialName("forum_id") val forumId: Int? = null,
    @SerialName("comment_id") val commentId: Int? = null,
    @SerialName("actor_id") val actorId: String? = null,
    val message: String,
    @SerialName("is_read") val isRead: Boolean = false,
    @SerialName("created_at") val createdAt: String,
    // Joined data
    @SerialName("actor") val actor: ForumAuthor? = null
)
