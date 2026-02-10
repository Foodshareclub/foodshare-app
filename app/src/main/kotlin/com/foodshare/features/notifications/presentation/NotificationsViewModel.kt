package com.foodshare.features.notifications.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.features.notifications.domain.model.UserNotification
import com.foodshare.features.notifications.domain.repository.NotificationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI State for Notifications screen.
 *
 * SYNC: Mirrors Swift NotificationsViewModel state
 */
data class NotificationsUiState(
    val notifications: List<UserNotification> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val error: String? = null,
    val hasMorePages: Boolean = true,
    val unreadCount: Int = 0,
    val totalCount: Int = 0,
    val currentOffset: Int = 0
) {
    val isEmpty: Boolean get() = notifications.isEmpty() && !isLoading
    val hasNotifications: Boolean get() = notifications.isNotEmpty()
}

/**
 * ViewModel for Notifications feature.
 *
 * SYNC: Mirrors Swift NotificationsViewModel
 */
@HiltViewModel
class NotificationsViewModel @Inject constructor(
    private val repository: NotificationRepository,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(NotificationsUiState())
    val uiState: StateFlow<NotificationsUiState> = _uiState.asStateFlow()

    private val pageSize = 20

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    init {
        loadNotifications()
        subscribeToRealTimeUpdates()
    }

    fun loadNotifications() {
        val userId = currentUserId ?: return
        if (_uiState.value.isLoading) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null, currentOffset = 0) }

            repository.getPaginatedNotifications(userId, limit = pageSize, offset = 0)
                .onSuccess { result ->
                    _uiState.update { state ->
                        state.copy(
                            notifications = result.notifications,
                            isLoading = false,
                            hasMorePages = result.hasMore,
                            unreadCount = result.unreadCount,
                            totalCount = result.totalCount,
                            currentOffset = result.notifications.size
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(isLoading = false, error = ErrorBridge.mapNotificationError(error))
                    }
                }
        }
    }

    fun loadMore() {
        val userId = currentUserId ?: return
        val currentState = _uiState.value
        if (currentState.isLoadingMore || !currentState.hasMorePages) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingMore = true) }

            repository.getPaginatedNotifications(
                userId,
                limit = pageSize,
                offset = currentState.currentOffset
            )
                .onSuccess { result ->
                    _uiState.update { state ->
                        state.copy(
                            notifications = state.notifications + result.notifications,
                            isLoadingMore = false,
                            hasMorePages = result.hasMore,
                            unreadCount = result.unreadCount,
                            currentOffset = state.currentOffset + result.notifications.size
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(isLoadingMore = false, error = ErrorBridge.mapNotificationError(error))
                    }
                }
        }
    }

    fun refresh() {
        _uiState.update { it.copy(currentOffset = 0, hasMorePages = true) }
        loadNotifications()
    }

    fun markAsRead(notification: UserNotification) {
        if (notification.isRead) return

        // Optimistic update
        _uiState.update { state ->
            val updatedNotifications = state.notifications.map {
                if (it.id == notification.id) it.copy(isRead = true) else it
            }
            state.copy(
                notifications = updatedNotifications,
                unreadCount = maxOf(0, state.unreadCount - 1)
            )
        }

        viewModelScope.launch {
            repository.markAsRead(notification.id)
                .onFailure {
                    // Revert on failure
                    _uiState.update { state ->
                        val revertedNotifications = state.notifications.map {
                            if (it.id == notification.id) it.copy(isRead = false) else it
                        }
                        state.copy(
                            notifications = revertedNotifications,
                            unreadCount = state.unreadCount + 1
                        )
                    }
                }
        }
    }

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
            repository.markAllAsRead(userId)
                .onFailure {
                    // Revert on failure
                    _uiState.update { previousState }
                }
        }
    }

    fun deleteNotification(notification: UserNotification) {
        val previousNotifications = _uiState.value.notifications
        val wasUnread = !notification.isRead

        // Optimistic removal
        _uiState.update { state ->
            state.copy(
                notifications = state.notifications.filter { it.id != notification.id },
                unreadCount = if (wasUnread) maxOf(0, state.unreadCount - 1) else state.unreadCount
            )
        }

        viewModelScope.launch {
            repository.deleteNotification(notification.id)
                .onFailure {
                    // Revert on failure
                    _uiState.update { state ->
                        state.copy(
                            notifications = previousNotifications,
                            unreadCount = if (wasUnread) state.unreadCount + 1 else state.unreadCount
                        )
                    }
                }
        }
    }

    private fun subscribeToRealTimeUpdates() {
        val userId = currentUserId ?: return

        viewModelScope.launch {
            repository.observeNotifications(userId).collect { newNotification ->
                _uiState.update { state ->
                    state.copy(
                        notifications = listOf(newNotification) + state.notifications,
                        unreadCount = if (!newNotification.isRead) state.unreadCount + 1 else state.unreadCount
                    )
                }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
