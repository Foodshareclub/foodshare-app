package com.foodshare.features.activity.domain.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import java.time.Instant
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * Activity type enum for classifying activities.
 *
 * SYNC: Mirrors Swift ActivityType
 */
enum class ActivityType {
    NEW_LISTING,
    LISTING_ARRANGED,
    FORUM_POST,
    FORUM_COMMENT,
    REVIEW_RECEIVED,
    CHALLENGE_COMPLETED,
    USER_JOINED,
    COMMUNITY_MILESTONE;

    val icon: ImageVector
        get() = when (this) {
            NEW_LISTING -> Icons.Default.Add
            LISTING_ARRANGED -> Icons.Default.Handshake
            FORUM_POST -> Icons.Default.Forum
            FORUM_COMMENT -> Icons.Default.Comment
            REVIEW_RECEIVED -> Icons.Default.Star
            CHALLENGE_COMPLETED -> Icons.Default.EmojiEvents
            USER_JOINED -> Icons.Default.PersonAdd
            COMMUNITY_MILESTONE -> Icons.Default.Celebration
        }

    val color: Color
        get() = when (this) {
            NEW_LISTING -> Color(0xFF2ECC71)       // Green
            LISTING_ARRANGED -> Color(0xFF3498DB)  // Blue
            FORUM_POST -> Color(0xFF9B59B6)        // Purple
            FORUM_COMMENT -> Color(0xFF1ABC9C)     // Teal
            REVIEW_RECEIVED -> Color(0xFFF39C12)   // Yellow
            CHALLENGE_COMPLETED -> Color(0xFFFFD700) // Gold
            USER_JOINED -> Color(0xFFE91E63)       // Pink
            COMMUNITY_MILESTONE -> Color(0xFFE67E22) // Orange
        }

    val label: String
        get() = when (this) {
            NEW_LISTING -> "New Listing"
            LISTING_ARRANGED -> "Arranged"
            FORUM_POST -> "Forum Post"
            FORUM_COMMENT -> "Comment"
            REVIEW_RECEIVED -> "Review"
            CHALLENGE_COMPLETED -> "Challenge"
            USER_JOINED -> "New Member"
            COMMUNITY_MILESTONE -> "Milestone"
        }

    companion object {
        fun fromString(value: String): ActivityType {
            return entries.find {
                it.name.equals(value.replace("-", "_"), ignoreCase = true)
            } ?: NEW_LISTING
        }
    }
}

/**
 * Activity item domain model.
 *
 * SYNC: Mirrors Swift ActivityItem
 */
data class ActivityItem(
    val id: String,
    val type: ActivityType,
    val title: String,
    val subtitle: String,
    val imageUrl: String? = null,
    val timestamp: Instant,
    val actorName: String? = null,
    val actorAvatarUrl: String? = null,
    val linkedPostId: Int? = null,
    val linkedForumId: Int? = null,
    val linkedProfileId: String? = null
) {
    /**
     * Returns a human-readable relative time string.
     */
    val timeAgoDisplay: String
        get() {
            val now = Instant.now()
            val seconds = ChronoUnit.SECONDS.between(timestamp, now)

            return when {
                seconds < 60 -> "Just now"
                seconds < 3600 -> "${seconds / 60}m ago"
                seconds < 86400 -> "${seconds / 3600}h ago"
                seconds < 604800 -> "${seconds / 86400}d ago"
                seconds < 2592000 -> "${seconds / 604800}w ago"
                else -> "${seconds / 2592000}mo ago"
            }
        }
}

/**
 * Post activity type for detailed post timeline.
 *
 * SYNC: Mirrors Swift PostActivityType
 */
enum class PostActivityType {
    // Lifecycle
    CREATED, UPDATED, DELETED, RESTORED, ACTIVATED, DEACTIVATED, EXPIRED,

    // User Actions
    VIEWED, CONTACTED, ARRANGED, COLLECTED, LIKED, SHARED, BOOKMARKED,

    // Moderation
    REPORTED, FLAGGED, APPROVED, REJECTED, HIDDEN,

    // Admin
    ADMIN_EDITED, ADMIN_NOTE_ADDED, ADMIN_STATUS_CHANGED,

    // Auto
    AUTO_EXPIRED, AUTO_DEACTIVATED,

    // Property Updates
    LOCATION_UPDATED, IMAGES_UPDATED;

    val icon: ImageVector
        get() = when (this) {
            CREATED -> Icons.Default.Add
            UPDATED -> Icons.Default.Edit
            DELETED -> Icons.Default.Delete
            RESTORED -> Icons.Default.Restore
            ACTIVATED -> Icons.Default.CheckCircle
            DEACTIVATED -> Icons.Default.Cancel
            EXPIRED -> Icons.Default.Schedule
            VIEWED -> Icons.Default.Visibility
            CONTACTED -> Icons.Default.Message
            ARRANGED -> Icons.Default.Handshake
            COLLECTED -> Icons.Default.CheckCircle
            LIKED -> Icons.Default.Favorite
            SHARED -> Icons.Default.Share
            BOOKMARKED -> Icons.Default.Bookmark
            REPORTED -> Icons.Default.Flag
            FLAGGED -> Icons.Default.Warning
            APPROVED -> Icons.Default.Verified
            REJECTED -> Icons.Default.Block
            HIDDEN -> Icons.Default.VisibilityOff
            ADMIN_EDITED -> Icons.Default.AdminPanelSettings
            ADMIN_NOTE_ADDED -> Icons.Default.Note
            ADMIN_STATUS_CHANGED -> Icons.Default.Settings
            AUTO_EXPIRED -> Icons.Default.TimerOff
            AUTO_DEACTIVATED -> Icons.Default.PowerOff
            LOCATION_UPDATED -> Icons.Default.LocationOn
            IMAGES_UPDATED -> Icons.Default.Photo
        }

    val color: Color
        get() = when (this) {
            CREATED, ACTIVATED, APPROVED, COLLECTED -> Color(0xFF2ECC71)
            UPDATED, IMAGES_UPDATED, LOCATION_UPDATED -> Color(0xFF3498DB)
            DELETED, DEACTIVATED, REJECTED, HIDDEN -> Color(0xFFE74C3C)
            RESTORED -> Color(0xFF1ABC9C)
            EXPIRED, AUTO_EXPIRED, AUTO_DEACTIVATED -> Color(0xFF95A5A6)
            VIEWED -> Color(0xFF9B59B6)
            CONTACTED, ARRANGED -> Color(0xFF2ECC71)
            LIKED -> Color(0xFFE91E63)
            SHARED -> Color(0xFF3498DB)
            BOOKMARKED -> Color(0xFFF39C12)
            REPORTED, FLAGGED -> Color(0xFFE74C3C)
            ADMIN_EDITED, ADMIN_NOTE_ADDED, ADMIN_STATUS_CHANGED -> Color(0xFF607D8B)
        }

    val label: String
        get() = name.lowercase().replace("_", " ").replaceFirstChar { it.uppercase() }

    companion object {
        fun fromString(value: String): PostActivityType {
            return entries.find {
                it.name.equals(value.replace("-", "_"), ignoreCase = true)
            } ?: VIEWED
        }
    }
}

/**
 * Post activity item for detailed timeline.
 */
data class PostActivityItem(
    val id: String,
    val postId: Int,
    val type: PostActivityType,
    val actorId: String? = null,
    val actorName: String? = null,
    val actorAvatarUrl: String? = null,
    val previousState: String? = null,
    val newState: String? = null,
    val changes: String? = null,
    val metadata: String? = null,
    val notes: String? = null,
    val timestamp: Instant
) {
    val timeAgoDisplay: String
        get() {
            val now = Instant.now()
            val seconds = ChronoUnit.SECONDS.between(timestamp, now)

            return when {
                seconds < 60 -> "Just now"
                seconds < 3600 -> "${seconds / 60}m ago"
                seconds < 86400 -> "${seconds / 3600}h ago"
                else -> "${seconds / 86400}d ago"
            }
        }
}

/**
 * Activity stats for a post.
 */
data class PostActivityStats(
    val views: Int = 0,
    val likes: Int = 0,
    val shares: Int = 0,
    val contacts: Int = 0,
    val bookmarks: Int = 0
)
