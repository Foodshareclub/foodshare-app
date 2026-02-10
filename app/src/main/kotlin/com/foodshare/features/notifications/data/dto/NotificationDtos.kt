package com.foodshare.features.notifications.data.dto

import com.foodshare.features.notifications.domain.model.ActorProfile
import com.foodshare.features.notifications.domain.model.NotificationType
import com.foodshare.features.notifications.domain.model.PaginatedNotificationsResult
import com.foodshare.features.notifications.domain.model.UserNotification
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant

/**
 * DTO for actor profile from Supabase join.
 */
@Serializable
data class ActorProfileDto(
    val id: String,
    val nickname: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null
) {
    fun toDomain(): ActorProfile {
        return ActorProfile(
            id = id,
            nickname = nickname,
            avatarUrl = avatarUrl
        )
    }
}

/**
 * DTO for user notification from Supabase.
 */
@Serializable
data class UserNotificationDto(
    val id: String,
    @SerialName("recipient_id") val recipientId: String,
    @SerialName("actor_id") val actorId: String? = null,
    val type: String,
    val title: String,
    val body: String,
    @SerialName("post_id") val postId: Int? = null,
    @SerialName("room_id") val roomId: String? = null,
    @SerialName("review_id") val reviewId: Int? = null,
    val data: Map<String, String>? = null,
    @SerialName("is_read") val isRead: Boolean = false,
    @SerialName("read_at") val readAt: String? = null,
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("actor_profile") val actorProfile: ActorProfileDto? = null
) {
    fun toDomain(): UserNotification {
        return UserNotification(
            id = id,
            recipientId = recipientId,
            actorId = actorId,
            type = NotificationType.fromString(type),
            title = title,
            body = body,
            postId = postId,
            roomId = roomId,
            reviewId = reviewId,
            data = data,
            isRead = isRead,
            readAt = readAt?.let { parseTimestamp(it) },
            createdAt = parseTimestamp(createdAt),
            updatedAt = updatedAt?.let { parseTimestamp(it) },
            actorProfile = actorProfile?.toDomain()
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
 * DTO for paginated notifications RPC response.
 */
@Serializable
data class PaginatedNotificationsDto(
    val notifications: List<UserNotificationDto>,
    @SerialName("unread_count") val unreadCount: Int,
    @SerialName("total_count") val totalCount: Int,
    @SerialName("has_more") val hasMore: Boolean
) {
    fun toDomain(): PaginatedNotificationsResult {
        return PaginatedNotificationsResult(
            notifications = notifications.map { it.toDomain() },
            unreadCount = unreadCount,
            totalCount = totalCount,
            hasMore = hasMore
        )
    }
}

/**
 * RPC params for get_paginated_notifications.
 */
@Serializable
data class GetPaginatedNotificationsParams(
    @SerialName("p_user_id") val userId: String,
    @SerialName("p_limit") val limit: Int = 20,
    @SerialName("p_offset") val offset: Int = 0
)

/**
 * RPC params for mark_all_notifications_read.
 */
@Serializable
data class MarkAllReadParams(
    @SerialName("p_user_id") val userId: String
)
