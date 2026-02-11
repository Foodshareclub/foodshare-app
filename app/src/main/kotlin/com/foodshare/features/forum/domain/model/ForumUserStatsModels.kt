package com.foodshare.features.forum.domain.model

import com.foodshare.core.engagement.EngagementBridge
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * Forum user statistics and reputation models.
 *
 * SYNC: This mirrors Swift ForumUserStats (ForumUserStats.swift)
 * Maps to `forum_user_stats` table.
 */
@Serializable
data class ForumUserStats(
    @SerialName("profile_id") val profileId: String,
    @SerialName("posts_count") val postsCount: Int = 0,
    @SerialName("comments_count") val commentsCount: Int = 0,
    @SerialName("reactions_received") val reactionsReceived: Int = 0,
    @SerialName("helpful_count") val helpfulCount: Int = 0,
    @SerialName("reputation_score") val reputationScore: Int = 0,
    @SerialName("joined_forum_at") val joinedForumAt: String? = null,
    @SerialName("last_post_at") val lastPostAt: String? = null,
    @SerialName("last_comment_at") val lastCommentAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("followers_count") val followersCount: Int = 0,
    @SerialName("following_count") val followingCount: Int = 0,
    @SerialName("trust_level") val trustLevel: Int = 0,
    @SerialName("topics_read") val topicsRead: Int = 0,
    @SerialName("posts_read") val postsRead: Int = 0,
    @SerialName("time_spent_minutes") val timeSpentMinutes: Int = 0,
    @SerialName("likes_given") val likesGiven: Int = 0,
    @SerialName("likes_received") val likesReceived: Int = 0,
    @SerialName("replies_received") val repliesReceived: Int = 0,
    @SerialName("flags_agreed") val flagsAgreed: Int = 0,
    @SerialName("was_warned") val wasWarned: Boolean = false,
    @SerialName("was_silenced") val wasSilenced: Boolean = false,
    @SerialName("silenced_until") val silencedUntil: String? = null,
    @SerialName("trust_level_locked") val trustLevelLocked: Boolean = false
) {
    // ========================================================================
    // Computed Properties (matching iOS ForumUserStats)
    // ========================================================================

    /**
     * Total engagement score using EngagementBridge for cross-platform consistency.
     *
     * Formula: posts*10 + comments*5 + likesGiven*1 + likesReceived*2 + reactions*2 + helpful*15
     */
    val engagementScore: Int
        get() = EngagementBridge.calculateEngagementScore(
            posts = postsCount,
            comments = commentsCount,
            likesGiven = likesGiven,
            likesReceived = likesReceived,
            reactions = reactionsReceived,
            helpful = helpfulCount
        )

    /**
     * Activity level based on recency of engagement using EngagementBridge.
     *
     * Returns: "Very Active", "Active", "Moderate", or "Inactive"
     */
    val activityLevel: String
        get() {
            val daysSincePost = lastPostAt?.let { daysSinceDate(it) }
            val daysSinceComment = lastCommentAt?.let { daysSinceDate(it) }
            return EngagementBridge.calculateActivityLevel(daysSincePost, daysSinceComment)
        }

    /**
     * Parsed ActivityLevel enum for the current activity state.
     */
    val activityLevelEnum: ActivityLevel
        get() = when (activityLevel) {
            "Very Active" -> ActivityLevel.VERY_ACTIVE
            "Active" -> ActivityLevel.ACTIVE
            "Moderate" -> ActivityLevel.MODERATE
            else -> ActivityLevel.INACTIVE
        }

    /**
     * Whether the user is currently silenced.
     */
    val isSilenced: Boolean
        get() {
            if (!wasSilenced) return false
            val until = silencedUntil ?: return false
            return try {
                val silenceEnd = Instant.parse(until)
                silenceEnd.isAfter(Instant.now())
            } catch (_: Exception) {
                false
            }
        }

    /**
     * Days since the user joined the forum.
     * Parses joinedForumAt as ISO date and computes days until now.
     */
    val daysSinceJoin: Int
        get() {
            val joined = joinedForumAt ?: return 0
            return try {
                val joinDate = Instant.parse(joined)
                    .atZone(ZoneId.systemDefault())
                    .toLocalDate()
                ChronoUnit.DAYS.between(joinDate, LocalDate.now()).toInt().coerceAtLeast(0)
            } catch (_: Exception) {
                0
            }
        }

    /**
     * Formatted time spent in the forum (matches iOS formattedTimeSpent).
     */
    val formattedTimeSpent: String
        get() = when {
            timeSpentMinutes < 60 -> "${timeSpentMinutes}m"
            timeSpentMinutes < 1440 -> "${timeSpentMinutes / 60}h"
            else -> "${timeSpentMinutes / 1440}d"
        }

    companion object {
        /** Empty stats for use as fallback in production code. */
        val empty = ForumUserStats(profileId = "")

        /** Empty stats with specific profile ID for use as fallback. */
        fun empty(profileId: String) = ForumUserStats(profileId = profileId)
    }
}

// ========================================================================
// Helper: compute days since an ISO date string
// ========================================================================

private fun daysSinceDate(isoDate: String): Int? {
    return try {
        val date = Instant.parse(isoDate)
            .atZone(ZoneId.systemDefault())
            .toLocalDate()
        ChronoUnit.DAYS.between(date, LocalDate.now()).toInt().coerceAtLeast(0)
    } catch (_: Exception) {
        null
    }
}

// ========================================================================
// Forum Trust Level
// ========================================================================

/**
 * Represents a trust level from the `forum_trust_levels` table.
 *
 * SYNC: This mirrors Swift ForumTrustLevel (ForumUserStats.swift)
 */
@Serializable
data class ForumTrustLevel(
    val level: Int,
    val name: String = "",
    val description: String = "",
    val color: String = "#9CA3AF",
    // Requirements
    @SerialName("min_days_since_join") val minDaysSinceJoin: Int = 0,
    @SerialName("min_posts_read") val minPostsRead: Int = 0,
    @SerialName("min_topics_read") val minTopicsRead: Int = 0,
    @SerialName("min_posts_created") val minPostsCreated: Int = 0,
    @SerialName("min_topics_created") val minTopicsCreated: Int = 0,
    @SerialName("min_likes_given") val minLikesGiven: Int = 0,
    @SerialName("min_likes_received") val minLikesReceived: Int = 0,
    @SerialName("min_replies_received") val minRepliesReceived: Int = 0,
    @SerialName("min_time_spent_minutes") val minTimeSpentMinutes: Int = 0,
    // Permissions (12 booleans)
    @SerialName("can_post") val canPost: Boolean = true,
    @SerialName("can_reply") val canReply: Boolean = true,
    @SerialName("can_like") val canLike: Boolean = true,
    @SerialName("can_flag") val canFlag: Boolean = false,
    @SerialName("can_edit_own_posts") val canEditOwnPosts: Boolean = true,
    @SerialName("can_delete_own_posts") val canDeleteOwnPosts: Boolean = false,
    @SerialName("can_upload_images") val canUploadImages: Boolean = false,
    @SerialName("can_post_links") val canPostLinks: Boolean = false,
    @SerialName("can_mention_users") val canMentionUsers: Boolean = false,
    @SerialName("can_send_messages") val canSendMessages: Boolean = false,
    @SerialName("can_create_polls") val canCreatePolls: Boolean = false,
    @SerialName("can_create_wiki") val canCreateWiki: Boolean = false,
    // Limits
    @SerialName("max_posts_per_day") val maxPostsPerDay: Int = 10,
    @SerialName("max_topics_per_day") val maxTopicsPerDay: Int = 3,
    @SerialName("max_likes_per_day") val maxLikesPerDay: Int = 20,
    @SerialName("max_flags_per_day") val maxFlagsPerDay: Int = 3,
    @SerialName("created_at") val createdAt: String? = null
) {
    // ========================================================================
    // Computed Properties (matching iOS ForumTrustLevel)
    // ========================================================================

    /** Icon name for the trust level (Material icon). */
    val icon: String
        get() = when (level) {
            0 -> "person"
            1 -> "verified"
            2 -> "star"
            3 -> "workspace_premium"
            4 -> "emoji_events"
            else -> "person"
        }

    /** Short name for compact display. */
    val shortName: String
        get() = when (level) {
            0 -> "New"
            1 -> "Basic"
            2 -> "Member"
            3 -> "Regular"
            4 -> "Leader"
            else -> "L$level"
        }

    /** All enabled permissions as a list of strings. */
    val enabledPermissions: List<String>
        get() = buildList {
            if (canPost) add("Create posts")
            if (canReply) add("Reply to posts")
            if (canLike) add("Like content")
            if (canFlag) add("Flag content")
            if (canEditOwnPosts) add("Edit own posts")
            if (canDeleteOwnPosts) add("Delete own posts")
            if (canUploadImages) add("Upload images")
            if (canPostLinks) add("Post links")
            if (canMentionUsers) add("Mention users")
            if (canSendMessages) add("Send messages")
            if (canCreatePolls) add("Create polls")
            if (canCreateWiki) add("Create wiki")
        }

    // ========================================================================
    // Progress Calculation (matching iOS progressForUser)
    // ========================================================================

    /**
     * Calculate progress towards this trust level for a given user stats.
     */
    fun progressForUser(stats: ForumUserStats): TrustLevelProgress {
        val requirements = listOf(
            RequirementProgress(
                name = "Days Active",
                current = stats.daysSinceJoin,
                required = minDaysSinceJoin,
                icon = "calendar_today"
            ),
            RequirementProgress(
                name = "Posts Read",
                current = stats.postsRead,
                required = minPostsRead,
                icon = "visibility"
            ),
            RequirementProgress(
                name = "Topics Read",
                current = stats.topicsRead,
                required = minTopicsRead,
                icon = "description"
            ),
            RequirementProgress(
                name = "Posts Created",
                current = stats.postsCount,
                required = minPostsCreated,
                icon = "edit"
            ),
            RequirementProgress(
                name = "Likes Given",
                current = stats.likesGiven,
                required = minLikesGiven,
                icon = "thumb_up"
            ),
            RequirementProgress(
                name = "Likes Received",
                current = stats.likesReceived,
                required = minLikesReceived,
                icon = "favorite"
            ),
            RequirementProgress(
                name = "Time Spent",
                current = stats.timeSpentMinutes,
                required = minTimeSpentMinutes,
                icon = "schedule"
            )
        )

        return TrustLevelProgress(
            trustLevel = this,
            requirements = requirements
        )
    }

    companion object {
        val newUser = ForumTrustLevel(
            level = 0,
            name = "New User",
            description = "Just joined the community. Limited posting abilities.",
            color = "#9CA3AF",
            minDaysSinceJoin = 0,
            minPostsRead = 0,
            minTopicsRead = 0,
            minPostsCreated = 0,
            minTopicsCreated = 0,
            minLikesGiven = 0,
            minLikesReceived = 0,
            minRepliesReceived = 0,
            minTimeSpentMinutes = 0,
            canPost = true,
            canReply = true,
            canLike = true,
            canFlag = false,
            canEditOwnPosts = true,
            canDeleteOwnPosts = false,
            canUploadImages = false,
            canPostLinks = false,
            canMentionUsers = false,
            canSendMessages = false,
            canCreatePolls = false,
            canCreateWiki = false,
            maxPostsPerDay = 3,
            maxTopicsPerDay = 1,
            maxLikesPerDay = 5,
            maxFlagsPerDay = 0
        )

        val basic = ForumTrustLevel(
            level = 1,
            name = "Basic",
            description = "Has read enough to understand the community norms.",
            color = "#60A5FA",
            minDaysSinceJoin = 1,
            minPostsRead = 10,
            minTopicsRead = 5,
            minPostsCreated = 1,
            minTopicsCreated = 0,
            minLikesGiven = 1,
            minLikesReceived = 0,
            minRepliesReceived = 0,
            minTimeSpentMinutes = 10,
            canPost = true,
            canReply = true,
            canLike = true,
            canFlag = true,
            canEditOwnPosts = true,
            canDeleteOwnPosts = false,
            canUploadImages = true,
            canPostLinks = true,
            canMentionUsers = true,
            canSendMessages = false,
            canCreatePolls = false,
            canCreateWiki = false,
            maxPostsPerDay = 10,
            maxTopicsPerDay = 3,
            maxLikesPerDay = 20,
            maxFlagsPerDay = 3
        )

        val member = ForumTrustLevel(
            level = 2,
            name = "Member",
            description = "Regular participant who contributes positively.",
            color = "#34D399",
            minDaysSinceJoin = 7,
            minPostsRead = 50,
            minTopicsRead = 20,
            minPostsCreated = 5,
            minTopicsCreated = 2,
            minLikesGiven = 10,
            minLikesReceived = 5,
            minRepliesReceived = 0,
            minTimeSpentMinutes = 60,
            canPost = true,
            canReply = true,
            canLike = true,
            canFlag = true,
            canEditOwnPosts = true,
            canDeleteOwnPosts = true,
            canUploadImages = true,
            canPostLinks = true,
            canMentionUsers = true,
            canSendMessages = true,
            canCreatePolls = true,
            canCreateWiki = false,
            maxPostsPerDay = 20,
            maxTopicsPerDay = 5,
            maxLikesPerDay = 50,
            maxFlagsPerDay = 5
        )

        val regular = ForumTrustLevel(
            level = 3,
            name = "Regular",
            description = "Trusted community member with proven track record.",
            color = "#A78BFA",
            minDaysSinceJoin = 30,
            minPostsRead = 200,
            minTopicsRead = 50,
            minPostsCreated = 20,
            minTopicsCreated = 5,
            minLikesGiven = 50,
            minLikesReceived = 20,
            minRepliesReceived = 0,
            minTimeSpentMinutes = 300,
            canPost = true,
            canReply = true,
            canLike = true,
            canFlag = true,
            canEditOwnPosts = true,
            canDeleteOwnPosts = true,
            canUploadImages = true,
            canPostLinks = true,
            canMentionUsers = true,
            canSendMessages = true,
            canCreatePolls = true,
            canCreateWiki = false,
            maxPostsPerDay = 50,
            maxTopicsPerDay = 10,
            maxLikesPerDay = 100,
            maxFlagsPerDay = 10
        )

        val leader = ForumTrustLevel(
            level = 4,
            name = "Leader",
            description = "Community leader who helps moderate and guide discussions.",
            color = "#F59E0B",
            minDaysSinceJoin = 90,
            minPostsRead = 500,
            minTopicsRead = 100,
            minPostsCreated = 50,
            minTopicsCreated = 15,
            minLikesGiven = 100,
            minLikesReceived = 50,
            minRepliesReceived = 0,
            minTimeSpentMinutes = 1000,
            canPost = true,
            canReply = true,
            canLike = true,
            canFlag = true,
            canEditOwnPosts = true,
            canDeleteOwnPosts = true,
            canUploadImages = true,
            canPostLinks = true,
            canMentionUsers = true,
            canSendMessages = true,
            canCreatePolls = true,
            canCreateWiki = false,
            maxPostsPerDay = 100,
            maxTopicsPerDay = 20,
            maxLikesPerDay = 200,
            maxFlagsPerDay = 20
        )

        /** All static trust levels (matching iOS ForumTrustLevel.all). */
        val all: List<ForumTrustLevel> = listOf(newUser, basic, member, regular, leader)
    }
}

// ========================================================================
// Trust Level Progress
// ========================================================================

/**
 * Progress towards a trust level.
 *
 * SYNC: This mirrors Swift TrustLevelProgress
 */
data class TrustLevelProgress(
    val trustLevel: ForumTrustLevel,
    val requirements: List<RequirementProgress>
) {
    /** Overall progress percentage (0.0 to 1.0). */
    val overallProgress: Double
        get() {
            if (requirements.isEmpty()) return 1.0
            val totalProgress = requirements.sumOf { it.progress }
            return totalProgress / requirements.size
        }

    /** Whether all requirements are met. */
    val isComplete: Boolean
        get() = requirements.all { it.isMet }

    /** Incomplete requirements. */
    val incompleteRequirements: List<RequirementProgress>
        get() = requirements.filter { !it.isMet }
}

/**
 * Progress for a single requirement.
 *
 * SYNC: This mirrors Swift RequirementProgress
 */
data class RequirementProgress(
    val name: String,
    val current: Int,
    val required: Int,
    val icon: String
) {
    /** Progress percentage (0.0 to 1.0, capped at 1.0). */
    val progress: Double
        get() = if (required > 0) minOf(1.0, current.toDouble() / required.toDouble()) else 1.0

    /** Whether this requirement is met. */
    val isMet: Boolean
        get() = current >= required

    /** Display string (e.g. "15/50"). */
    val displayText: String
        get() = "$current/$required"
}

// ========================================================================
// Activity Level
// ========================================================================

/**
 * User activity level based on recent engagement.
 *
 * SYNC: This mirrors Swift ForumUserStats.ActivityLevel
 */
enum class ActivityLevel(val displayName: String, val colorHex: Long) {
    VERY_ACTIVE("Very Active", 0xFF4CAF50),
    ACTIVE("Active", 0xFF2196F3),
    MODERATE("Moderate", 0xFFFF9800),
    INACTIVE("Inactive", 0xFF9E9E9E);

    /** Material icon name. */
    val icon: String
        get() = when (this) {
            VERY_ACTIVE -> "local_fire_department"
            ACTIVE -> "bolt"
            MODERATE -> "schedule"
            INACTIVE -> "bedtime"
        }
}
