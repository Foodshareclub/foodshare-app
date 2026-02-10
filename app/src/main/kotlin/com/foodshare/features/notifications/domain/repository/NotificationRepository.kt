package com.foodshare.features.notifications.domain.repository

import com.foodshare.features.notifications.domain.model.PaginatedNotificationsResult
import com.foodshare.features.notifications.domain.model.UserNotification
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for notification data operations.
 *
 * SYNC: Mirrors Swift NotificationRepository
 */
interface NotificationRepository {

    /**
     * Fetch notifications with pagination.
     */
    suspend fun getNotifications(
        userId: String,
        limit: Int = 20,
        offset: Int = 0
    ): Result<List<UserNotification>>

    /**
     * Fetch paginated notifications with metadata.
     */
    suspend fun getPaginatedNotifications(
        userId: String,
        limit: Int = 20,
        offset: Int = 0
    ): Result<PaginatedNotificationsResult>

    /**
     * Get unread notification count.
     */
    suspend fun getUnreadCount(userId: String): Result<Int>

    /**
     * Mark a notification as read.
     */
    suspend fun markAsRead(notificationId: String): Result<Unit>

    /**
     * Mark all notifications as read.
     */
    suspend fun markAllAsRead(userId: String): Result<Unit>

    /**
     * Delete a notification.
     */
    suspend fun deleteNotification(notificationId: String): Result<Unit>

    /**
     * Observe new notifications in real-time.
     */
    fun observeNotifications(userId: String): Flow<UserNotification>
}
