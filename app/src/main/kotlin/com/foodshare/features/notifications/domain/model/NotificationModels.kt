package com.foodshare.features.notifications.domain.model

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import java.time.Instant
import java.time.temporal.ChronoUnit

/**
 * Notification type enum.
 *
 * SYNC: Mirrors Swift NotificationType
 */
enum class NotificationType {
    NEW_MESSAGE,
    ARRANGEMENT_REQUEST,
    ARRANGEMENT_CONFIRMED,
    ARRANGEMENT_CANCELLED,
    NEW_LISTING_NEARBY,
    REVIEW_RECEIVED,
    REVIEW_REMINDER,
    CHALLENGE_COMPLETED,
    FORUM_REPLY,
    SYSTEM;

    val icon: ImageVector
        get() = when (this) {
            NEW_MESSAGE -> Icons.Default.Message
            ARRANGEMENT_REQUEST -> Icons.Default.PanTool
            ARRANGEMENT_CONFIRMED -> Icons.Default.CheckCircle
            ARRANGEMENT_CANCELLED -> Icons.Default.Cancel
            NEW_LISTING_NEARBY -> Icons.Default.Eco
            REVIEW_RECEIVED -> Icons.Default.Star
            REVIEW_REMINDER -> Icons.Default.StarHalf
            CHALLENGE_COMPLETED -> Icons.Default.EmojiEvents
            FORUM_REPLY -> Icons.Default.Forum
            SYSTEM -> Icons.Default.Notifications
        }

    val color: Color
        get() = when (this) {
            NEW_MESSAGE -> Color(0xFF3498DB)        // Brand blue
            ARRANGEMENT_REQUEST -> Color(0xFF9B59B6) // Purple
            ARRANGEMENT_CONFIRMED -> Color(0xFF2ECC71) // Brand green
            ARRANGEMENT_CANCELLED -> Color(0xFFE74C3C) // Error red
            NEW_LISTING_NEARBY -> Color(0xFFE67E22)  // Orange
            REVIEW_RECEIVED -> Color(0xFFF39C12)    // Yellow
            REVIEW_REMINDER -> Color(0xFFF39C12)    // Yellow
            CHALLENGE_COMPLETED -> Color(0xFF2ECC71) // Brand green
            FORUM_REPLY -> Color(0xFF1ABC9C)        // Teal
            SYSTEM -> Color(0xFF95A5A6)             // Gray
        }

    val displayName: String
        get() = when (this) {
            NEW_MESSAGE -> "Message"
            ARRANGEMENT_REQUEST -> "Request"
            ARRANGEMENT_CONFIRMED -> "Confirmed"
            ARRANGEMENT_CANCELLED -> "Cancelled"
            NEW_LISTING_NEARBY -> "Nearby"
            REVIEW_RECEIVED -> "Review"
            REVIEW_REMINDER -> "Reminder"
            CHALLENGE_COMPLETED -> "Challenge"
            FORUM_REPLY -> "Reply"
            SYSTEM -> "System"
        }

    companion object {
        fun fromString(value: String): NotificationType {
            return entries.find {
                it.name.equals(value.replace("-", "_"), ignoreCase = true)
            } ?: SYSTEM
        }
    }
}

/**
 * Actor profile for notification sender info.
 */
data class ActorProfile(
    val id: String,
    val nickname: String? = null,
    val avatarUrl: String? = null
)

/**
 * User notification domain model.
 *
 * SYNC: Mirrors Swift UserNotification
 */
data class UserNotification(
    val id: String,
    val recipientId: String,
    val actorId: String? = null,
    val type: NotificationType,
    val title: String,
    val body: String,
    val postId: Int? = null,
    val roomId: String? = null,
    val reviewId: Int? = null,
    val data: Map<String, String>? = null,
    val isRead: Boolean = false,
    val readAt: Instant? = null,
    val createdAt: Instant,
    val updatedAt: Instant? = null,
    val actorProfile: ActorProfile? = null
) {
    /**
     * Returns a human-readable relative time string.
     */
    val timeAgoDisplay: String
        get() {
            val now = Instant.now()
            val seconds = ChronoUnit.SECONDS.between(createdAt, now)

            return when {
                seconds < 60 -> "Just now"
                seconds < 3600 -> "${seconds / 60}m ago"
                seconds < 86400 -> "${seconds / 3600}h ago"
                seconds < 604800 -> "${seconds / 86400}d ago"
                else -> "${seconds / 604800}w ago"
            }
        }
}

/**
 * Paginated notifications result.
 */
data class PaginatedNotificationsResult(
    val notifications: List<UserNotification>,
    val unreadCount: Int,
    val totalCount: Int,
    val hasMore: Boolean
)
