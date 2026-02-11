package com.foodshare.features.notifications.presentation.components

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.domain.repository.AuthRepository
import com.foodshare.features.notifications.domain.repository.NotificationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.temporal.ChronoUnit
import javax.inject.Inject

// ============================================================================
// Data Models
// ============================================================================

/**
 * A single notification item for the dropdown display.
 */
data class NotificationItem(
    val id: String,
    val title: String,
    val message: String,
    val type: String,  // "listing", "message", "forum", "challenge", "system"
    val isRead: Boolean = false,
    val createdAt: String,
    val targetId: String? = null  // ID for navigation
) {
    /**
     * Returns a human-readable relative time string.
     */
    val timeAgo: String
        get() {
            return try {
                val instant = Instant.parse(createdAt)
                val now = Instant.now()
                val seconds = ChronoUnit.SECONDS.between(instant, now)

                when {
                    seconds < 60 -> "Just now"
                    seconds < 3600 -> "${seconds / 60}m ago"
                    seconds < 86400 -> "${seconds / 3600}h ago"
                    seconds < 604800 -> "${seconds / 86400}d ago"
                    else -> "${seconds / 604800}w ago"
                }
            } catch (_: Exception) {
                ""
            }
        }
}

// ============================================================================
// ViewModel
// ============================================================================

/**
 * ViewModel for the Notification Dropdown component.
 *
 * Manages a compact list of recent notifications (last 5) with
 * unread tracking, mark-as-read functionality, and real-time updates.
 *
 * SYNC: Mirrors Swift NotificationDropdownViewModel
 */
@HiltViewModel
class NotificationDropdownViewModel @Inject constructor(
    private val notificationRepository: NotificationRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    // ========================================================================
    // UI State
    // ========================================================================

    data class UiState(
        val notifications: List<NotificationItem> = emptyList(),
        val unreadCount: Int = 0,
        val isLoading: Boolean = true,
        val error: String? = null
    )

    // ========================================================================
    // State
    // ========================================================================

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private var currentUserId: String? = null

    // ========================================================================
    // Initialization
    // ========================================================================

    init {
        loadCurrentUser()
        loadRecentNotifications()
        subscribeToRealTimeUpdates()
    }

    private fun loadCurrentUser() {
        viewModelScope.launch {
            authRepository.getCurrentUser()
                .onSuccess { user ->
                    currentUserId = user?.id
                }
        }
    }

    // ========================================================================
    // Public API
    // ========================================================================

    /**
     * Load the last 5 notifications for the dropdown.
     */
    fun loadRecentNotifications() {
        val userId = currentUserId ?: return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            notificationRepository.getPaginatedNotifications(
                userId = userId,
                limit = 5,
                offset = 0
            )
                .onSuccess { result ->
                    val items = result.notifications.map { notification ->
                        NotificationItem(
                            id = notification.id,
                            title = notification.title,
                            message = notification.body,
                            type = mapNotificationType(notification.type.name),
                            isRead = notification.isRead,
                            createdAt = notification.createdAt.toString(),
                            targetId = notification.postId?.toString()
                                ?: notification.roomId
                                ?: notification.actorId
                        )
                    }

                    _uiState.update { state ->
                        state.copy(
                            notifications = items,
                            unreadCount = result.unreadCount,
                            isLoading = false
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = error.message ?: "Failed to load notifications"
                        )
                    }
                }
        }
    }

    /**
     * Mark a single notification as read.
     */
    fun markAsRead(notification: NotificationItem) {
        if (notification.isRead) return

        // Optimistic update
        _uiState.update { state ->
            val updated = state.notifications.map {
                if (it.id == notification.id) it.copy(isRead = true) else it
            }
            state.copy(
                notifications = updated,
                unreadCount = maxOf(0, state.unreadCount - 1)
            )
        }

        viewModelScope.launch {
            notificationRepository.markAsRead(notification.id)
                .onFailure {
                    // Revert on failure
                    _uiState.update { state ->
                        val reverted = state.notifications.map {
                            if (it.id == notification.id) it.copy(isRead = false) else it
                        }
                        state.copy(
                            notifications = reverted,
                            unreadCount = state.unreadCount + 1
                        )
                    }
                }
        }
    }

    /**
     * Mark all notifications as read.
     */
    fun markAllAsRead() {
        val userId = currentUserId ?: return
        val previousState = _uiState.value

        // Optimistic update
        _uiState.update { state ->
            state.copy(
                notifications = state.notifications.map { it.copy(isRead = true) },
                unreadCount = 0
            )
        }

        viewModelScope.launch {
            notificationRepository.markAllAsRead(userId)
                .onFailure {
                    // Revert on failure
                    _uiState.update { previousState }
                }
        }
    }

    /**
     * Clear the error state.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    // ========================================================================
    // Private Helpers
    // ========================================================================

    /**
     * Subscribe to real-time notification updates.
     */
    private fun subscribeToRealTimeUpdates() {
        val userId = currentUserId ?: return

        viewModelScope.launch {
            notificationRepository.observeNotifications(userId).collect { newNotification ->
                val item = NotificationItem(
                    id = newNotification.id,
                    title = newNotification.title,
                    message = newNotification.body,
                    type = mapNotificationType(newNotification.type.name),
                    isRead = newNotification.isRead,
                    createdAt = newNotification.createdAt.toString(),
                    targetId = newNotification.postId?.toString()
                        ?: newNotification.roomId
                        ?: newNotification.actorId
                )

                _uiState.update { state ->
                    val updatedList = (listOf(item) + state.notifications).take(5)
                    state.copy(
                        notifications = updatedList,
                        unreadCount = if (!item.isRead) state.unreadCount + 1 else state.unreadCount
                    )
                }
            }
        }
    }

    /**
     * Map internal notification type names to simplified category strings.
     */
    private fun mapNotificationType(typeName: String): String = when {
        typeName.contains("MESSAGE", ignoreCase = true) -> "message"
        typeName.contains("LISTING", ignoreCase = true) ||
            typeName.contains("ARRANGEMENT", ignoreCase = true) -> "listing"
        typeName.contains("FORUM", ignoreCase = true) -> "forum"
        typeName.contains("CHALLENGE", ignoreCase = true) -> "challenge"
        else -> "system"
    }
}
