package com.foodshare.features.notifications.data.repository

import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.network.RPCConfig
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.core.realtime.RealtimeFilter
import com.foodshare.features.notifications.data.dto.*
import com.foodshare.features.notifications.domain.model.PaginatedNotificationsResult
import com.foodshare.features.notifications.domain.model.UserNotification
import com.foodshare.features.notifications.domain.repository.NotificationRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of NotificationRepository.
 *
 * SYNC: Mirrors Swift SupabaseNotificationRepository
 */
@Singleton
class SupabaseNotificationRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val rpcClient: RateLimitedRPCClient,
    private val realtimeManager: RealtimeChannelManager
) : NotificationRepository {

    override suspend fun getNotifications(
        userId: String,
        limit: Int,
        offset: Int
    ): Result<List<UserNotification>> = runCatching {
        supabaseClient.from("user_notifications")
            .select(Columns.raw(NOTIFICATIONS_SELECT)) {
                filter { eq("recipient_id", userId) }
                order("created_at", Order.DESCENDING)
                range(offset.toLong(), (offset + limit - 1).toLong())
            }
            .decodeList<UserNotificationDto>()
            .map { it.toDomain() }
    }

    override suspend fun getPaginatedNotifications(
        userId: String,
        limit: Int,
        offset: Int
    ): Result<PaginatedNotificationsResult> {
        val params = GetPaginatedNotificationsParams(
            userId = userId,
            limit = limit,
            offset = offset
        )

        return rpcClient.call<GetPaginatedNotificationsParams, PaginatedNotificationsDto>(
            functionName = "get_paginated_notifications",
            params = params,
            config = RPCConfig.normal
        ).map { it.toDomain() }
    }

    override suspend fun getUnreadCount(userId: String): Result<Int> = runCatching {
        supabaseClient.from("user_notifications")
            .select {
                filter {
                    eq("recipient_id", userId)
                    eq("is_read", false)
                }
            }
            .decodeList<Any>()
            .size
    }

    override suspend fun markAsRead(notificationId: String): Result<Unit> = runCatching {
        supabaseClient.from("user_notifications")
            .update(mapOf(
                "is_read" to true,
                "read_at" to Instant.now().toString()
            )) {
                filter { eq("id", notificationId) }
            }
    }

    override suspend fun markAllAsRead(userId: String): Result<Unit> = runCatching {
        supabaseClient.from("user_notifications")
            .update(mapOf(
                "is_read" to true,
                "read_at" to Instant.now().toString()
            )) {
                filter {
                    eq("recipient_id", userId)
                    eq("is_read", false)
                }
            }
    }

    override suspend fun deleteNotification(notificationId: String): Result<Unit> = runCatching {
        supabaseClient.from("user_notifications")
            .delete {
                filter { eq("id", notificationId) }
            }
    }

    override fun observeNotifications(userId: String): Flow<UserNotification> {
        val filter = RealtimeFilter(
            table = "user_notifications",
            filter = "recipient_id=eq.$userId"
        )

        return channelFlow {
            realtimeManager.subscribe<NotificationInsertDto>(filter)
                .collect { change ->
                    change.currentRecord()?.toNotification()?.let { send(it) }
                }
        }
    }

    companion object {
        private const val NOTIFICATIONS_SELECT = """
            *,
            actor_profile:profiles!actor_id(id, nickname, avatar_url)
        """
    }
}

/**
 * DTO for realtime notification insert.
 */
@Serializable
private data class NotificationInsertDto(
    val id: String,
    @SerialName("recipient_id") val recipientId: String,
    @SerialName("actor_id") val actorId: String? = null,
    val type: String,
    val title: String,
    val body: String,
    @SerialName("post_id") val postId: Int? = null,
    @SerialName("room_id") val roomId: String? = null,
    @SerialName("review_id") val reviewId: Int? = null,
    @SerialName("is_read") val isRead: Boolean = false,
    @SerialName("created_at") val createdAt: String
) {
    fun toNotification(): UserNotification {
        return UserNotification(
            id = id,
            recipientId = recipientId,
            actorId = actorId,
            type = com.foodshare.features.notifications.domain.model.NotificationType.fromString(type),
            title = title,
            body = body,
            postId = postId,
            roomId = roomId,
            reviewId = reviewId,
            isRead = isRead,
            createdAt = try { Instant.parse(createdAt) } catch (e: Exception) { Instant.now() }
        )
    }
}
