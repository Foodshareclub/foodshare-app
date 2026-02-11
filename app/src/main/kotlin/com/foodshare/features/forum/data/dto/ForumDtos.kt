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

// Poll DTOs

/**
 * DTO for forum poll from Supabase.
 */
@Serializable
data class ForumPollDto(
    val id: String,
    @SerialName("forum_id") val forumId: Int,
    val question: String,
    @SerialName("poll_type") val pollType: String,
    @SerialName("ends_at") val endsAt: String? = null,
    @SerialName("is_anonymous") val isAnonymous: Boolean = false,
    @SerialName("show_results_before_vote") val showResultsBeforeVote: Boolean = false,
    @SerialName("total_votes") val totalVotes: Int = 0,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    // Joined data
    @SerialName("forum_poll_options") val options: List<ForumPollOptionDto>? = null,
    @SerialName("user_votes") val userVotes: List<String>? = null
) {
    fun toDomain() = ForumPoll(
        id = id,
        forumId = forumId,
        question = question,
        pollType = parsePollType(pollType),
        endsAt = endsAt,
        isAnonymous = isAnonymous,
        showResultsBeforeVote = showResultsBeforeVote,
        totalVotes = totalVotes,
        createdAt = createdAt,
        updatedAt = updatedAt,
        options = options?.map { it.toDomain() },
        userVotes = userVotes
    )

    private fun parsePollType(type: String): PollType = when (type) {
        "multiple" -> PollType.MULTIPLE
        else -> PollType.SINGLE
    }
}

/**
 * DTO for forum poll option from Supabase.
 */
@Serializable
data class ForumPollOptionDto(
    val id: String,
    @SerialName("poll_id") val pollId: String,
    @SerialName("option_text") val optionText: String,
    @SerialName("votes_count") val votesCount: Int = 0,
    @SerialName("sort_order") val sortOrder: Int = 0,
    @SerialName("created_at") val createdAt: String? = null
) {
    fun toDomain() = ForumPollOption(
        id = id,
        pollId = pollId,
        optionText = optionText,
        votesCount = votesCount,
        sortOrder = sortOrder,
        createdAt = createdAt
    )
}

/**
 * DTO for poll with options from nested query.
 */
@Serializable
data class PollWithOptionsDto(
    @SerialName("forum_polls") val poll: ForumPollDto? = null
)

// Badge DTOs

/**
 * DTO for forum badge from Supabase.
 */
@Serializable
data class ForumBadgeDto(
    val id: Int,
    val name: String = "",
    val slug: String = "",
    val description: String = "",
    @SerialName("icon_name") val iconName: String? = null,
    val color: String? = null,
    @SerialName("badge_type") val badgeType: String = "achievement",
    val criteria: BadgeCriteria? = null,
    val points: Int = 0,
    @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("created_at") val createdAt: String? = null
) {
    fun toDomain() = ForumBadge(
        id = id,
        name = name,
        slug = slug,
        description = description,
        iconName = iconName,
        color = color,
        badgeType = parseBadgeType(badgeType),
        criteria = criteria,
        points = points,
        isActive = isActive,
        createdAt = createdAt
    )

    private fun parseBadgeType(type: String): BadgeType = when (type) {
        "milestone" -> BadgeType.MILESTONE
        "special" -> BadgeType.SPECIAL
        else -> BadgeType.ACHIEVEMENT
    }
}

/**
 * DTO for user badge from Supabase.
 */
@Serializable
data class UserBadgeDto(
    val id: String,
    @SerialName("profile_id") val profileId: String,
    @SerialName("badge_id") val badgeId: Int,
    @SerialName("awarded_at") val awardedAt: String? = null,
    @SerialName("awarded_by") val awardedBy: String? = null,
    @SerialName("is_featured") val isFeatured: Boolean = false
) {
    fun toDomain() = UserBadge(
        id = id,
        profileId = profileId,
        badgeId = badgeId,
        awardedAt = awardedAt,
        awardedBy = awardedBy,
        isFeatured = isFeatured
    )
}

// User Stats DTOs - using domain model directly since it already has @Serializable
// ForumUserStats and ForumTrustLevel are used directly as they are already @Serializable
