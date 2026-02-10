package com.foodshare.features.activity.data.dto

import com.foodshare.features.activity.domain.model.ActivityItem
import com.foodshare.features.activity.domain.model.ActivityType
import com.foodshare.features.activity.domain.model.PostActivityItem
import com.foodshare.features.activity.domain.model.PostActivityStats
import com.foodshare.features.activity.domain.model.PostActivityType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/**
 * DTO for mixed activity feed from RPC.
 */
@Serializable
data class MixedActivityDto(
    val id: String,
    @SerialName("activity_type") val activityType: String,
    val title: String,
    val subtitle: String,
    @SerialName("image_url") val imageUrl: String? = null,
    val timestamp: String,
    @SerialName("actor_name") val actorName: String? = null,
    @SerialName("actor_avatar_url") val actorAvatarUrl: String? = null,
    @SerialName("linked_post_id") val linkedPostId: Int? = null,
    @SerialName("linked_forum_id") val linkedForumId: Int? = null,
    @SerialName("linked_profile_id") val linkedProfileId: String? = null
) {
    fun toDomain(): ActivityItem {
        return ActivityItem(
            id = id,
            type = ActivityType.fromString(activityType),
            title = title,
            subtitle = subtitle,
            imageUrl = imageUrl,
            timestamp = parseTimestamp(timestamp),
            actorName = actorName,
            actorAvatarUrl = actorAvatarUrl,
            linkedPostId = linkedPostId,
            linkedForumId = linkedForumId,
            linkedProfileId = linkedProfileId
        )
    }

    private fun parseTimestamp(value: String): Instant {
        return try {
            Instant.parse(value)
        } catch (e: Exception) {
            Instant.now()
        }
    }
}

/**
 * DTO for post activity log entries.
 */
@Serializable
data class PostActivityLogDto(
    val id: String,
    @SerialName("post_id") val postId: Int,
    @SerialName("activity_type") val activityType: String,
    @SerialName("actor_id") val actorId: String? = null,
    @SerialName("actor_name") val actorName: String? = null,
    @SerialName("actor_avatar_url") val actorAvatarUrl: String? = null,
    @SerialName("previous_state") val previousState: String? = null,
    @SerialName("new_state") val newState: String? = null,
    val changes: String? = null,
    val metadata: String? = null,
    val notes: String? = null,
    @SerialName("created_at") val createdAt: String
) {
    fun toDomain(): PostActivityItem {
        return PostActivityItem(
            id = id,
            postId = postId,
            type = PostActivityType.fromString(activityType),
            actorId = actorId,
            actorName = actorName,
            actorAvatarUrl = actorAvatarUrl,
            previousState = previousState,
            newState = newState,
            changes = changes,
            metadata = metadata,
            notes = notes,
            timestamp = parseTimestamp(createdAt)
        )
    }

    private fun parseTimestamp(value: String): Instant {
        return try {
            Instant.parse(value)
        } catch (e: Exception) {
            Instant.now()
        }
    }
}

/**
 * DTO for post activity stats from RPC.
 */
@Serializable
data class PostActivityStatsDto(
    val views: Int = 0,
    val likes: Int = 0,
    val shares: Int = 0,
    val contacts: Int = 0,
    val bookmarks: Int = 0
) {
    fun toDomain(): PostActivityStats {
        return PostActivityStats(
            views = views,
            likes = likes,
            shares = shares,
            contacts = contacts,
            bookmarks = bookmarks
        )
    }
}

/**
 * RPC params for get_mixed_activity_feed.
 */
@Serializable
data class GetActivityFeedParams(
    @SerialName("p_limit") val limit: Int = 20,
    @SerialName("p_offset") val offset: Int = 0
)

/**
 * RPC params for get_post_activities.
 */
@Serializable
data class GetPostActivitiesParams(
    @SerialName("p_post_id") val postId: Int,
    @SerialName("p_limit") val limit: Int = 50
)

/**
 * RPC params for get_post_activity_stats.
 */
@Serializable
data class GetPostActivityStatsParams(
    @SerialName("p_post_id") val postId: Int
)
