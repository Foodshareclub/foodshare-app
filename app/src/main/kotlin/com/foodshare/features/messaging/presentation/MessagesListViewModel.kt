package com.foodshare.features.messaging.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.cache.CacheKeys
import com.foodshare.core.cache.MessageQueue
import com.foodshare.core.cache.OfflineCache
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.domain.model.ChatRoom
import com.foodshare.domain.repository.ChatRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * ViewModel for the Messages List screen
 *
 * Displays user's chat rooms with unread counts.
 * Supports offline caching and pending message tracking.
 *
 * SYNC: Mirrors Swift MessagesListViewModel
 */
@HiltViewModel
class MessagesListViewModel @Inject constructor(
    private val chatRepository: ChatRepository,
    private val offlineCache: OfflineCache,
    private val messageQueue: MessageQueue
) : ViewModel() {

    private val json = Json { ignoreUnknownKeys = true }

    private val _uiState = MutableStateFlow(MessagesListUiState())
    val uiState: StateFlow<MessagesListUiState> = _uiState.asStateFlow()

    init {
        loadRooms()
        observeUnreadCount()
        observePendingMessageCount()
    }

    private fun observeUnreadCount() {
        viewModelScope.launch {
            chatRepository.observeUnreadCount().collect { count ->
                _uiState.update { it.copy(totalUnread = count) }
            }
        }
    }

    private fun observePendingMessageCount() {
        viewModelScope.launch {
            messageQueue.observePendingCount().collect { count ->
                _uiState.update { it.copy(pendingMessageCount = count) }
            }
        }
    }

    fun loadRooms() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            chatRepository.getRooms(
                filterType = _uiState.value.filterType
            ).onSuccess { rooms ->
                // Cache rooms for offline access
                cacheRooms(rooms)

                _uiState.update {
                    it.copy(
                        rooms = rooms,
                        isLoading = false,
                        isRefreshing = false,
                        isOffline = false
                    )
                }
            }.onFailure { error ->
                // Try to load from cache on failure
                loadFromCache()

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        error = ErrorBridge.mapMessageError(error)
                    )
                }
            }
        }
    }

    private suspend fun cacheRooms(rooms: List<ChatRoom>) {
        try {
            offlineCache.save(
                key = CacheKeys.CHAT_ROOMS,
                data = json.encodeToString(kotlinx.serialization.builtins.ListSerializer(ChatRoom.serializer()), rooms),
                ttlMs = OfflineCache.LONG_TTL_MS
            )
        } catch (e: Exception) {
            // Cache failure is non-critical
        }
    }

    private suspend fun loadFromCache() {
        try {
            val cached = offlineCache.load(
                key = CacheKeys.CHAT_ROOMS,
                deserialize = { jsonStr ->
                    json.decodeFromString(
                        kotlinx.serialization.builtins.ListSerializer(ChatRoom.serializer()),
                        jsonStr
                    )
                }
            )

            if (cached != null && !cached.isExpired) {
                _uiState.update {
                    it.copy(
                        rooms = cached.data,
                        isOffline = true
                    )
                }
            }
        } catch (e: Exception) {
            // Cache load failure is non-critical
        }
    }

    fun refresh() {
        _uiState.update { it.copy(isRefreshing = true) }
        loadRooms()
    }

    fun setFilter(filterType: String) {
        _uiState.update { it.copy(filterType = filterType, rooms = emptyList()) }
        loadRooms()
    }

    fun search(query: String) {
        _uiState.update { it.copy(searchQuery = query) }
        viewModelScope.launch {
            chatRepository.getRooms(
                searchQuery = query.takeIf { it.isNotBlank() },
                filterType = _uiState.value.filterType
            ).onSuccess { rooms ->
                _uiState.update { it.copy(rooms = rooms) }
            }
        }
    }

    fun muteRoom(roomId: String) {
        viewModelScope.launch {
            chatRepository.setRoomMuted(roomId, true)
                .onSuccess { loadRooms() }
        }
    }

    fun pinRoom(roomId: String) {
        viewModelScope.launch {
            chatRepository.setRoomPinned(roomId, true)
                .onSuccess { loadRooms() }
        }
    }

    fun archiveRoom(roomId: String) {
        viewModelScope.launch {
            chatRepository.archiveRoom(roomId)
                .onSuccess { loadRooms() }
        }
    }
}

/**
 * UI State for Messages List
 */
data class MessagesListUiState(
    val rooms: List<ChatRoom> = emptyList(),
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val isOffline: Boolean = false,
    val error: String? = null,
    val filterType: String = "all", // all, unread, sharing, receiving
    val searchQuery: String = "",
    val totalUnread: Int = 0,
    val pendingMessageCount: Int = 0
) {
    val hasPendingMessages: Boolean
        get() = pendingMessageCount > 0

    val offlineIndicator: String?
        get() = if (isOffline) "Showing cached messages" else null
}
