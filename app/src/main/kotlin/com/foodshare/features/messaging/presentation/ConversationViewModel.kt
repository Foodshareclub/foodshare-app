package com.foodshare.features.messaging.presentation

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.core.optimistic.EntityType
import com.foodshare.core.optimistic.ErrorCategory
import com.foodshare.core.optimistic.OptimisticUpdateBridge
import com.foodshare.core.optimistic.UpdateOperation
import com.foodshare.core.realtime.ChannelState
import com.foodshare.core.realtime.RealtimeSubscriptionBridge
import com.foodshare.core.validation.ValidationBridge
import java.time.Instant
import java.util.UUID
import com.foodshare.domain.model.ChatMessage
import com.foodshare.domain.model.ChatRoom
import com.foodshare.domain.model.MessageType
import com.foodshare.domain.repository.ChatRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for the Conversation screen
 *
 * Handles real-time messaging within a chat room.
 * Uses Swift RealtimeSubscriptionBridge for:
 * - Message deduplication
 * - Channel lifecycle management
 * - Reconnection with exponential backoff
 *
 * SYNC: Mirrors Swift ConversationViewModel
 */
@HiltViewModel
class ConversationViewModel @Inject constructor(
    private val chatRepository: ChatRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val roomId: String = checkNotNull(savedStateHandle["roomId"])
    private val channelId: String = "messages:$roomId"

    private val _uiState = MutableStateFlow(ConversationUiState())
    val uiState: StateFlow<ConversationUiState> = _uiState.asStateFlow()

    private var reconnectionJob: Job? = null

    init {
        registerRealtimeChannel()
        loadMessages()
        observeNewMessages()
        markAsRead()
    }

    // =========================================================================
    // Swift RealtimeSubscriptionBridge Integration
    // =========================================================================

    /**
     * Register realtime channel for this conversation.
     * Uses Swift bridge for consistent channel management across platforms.
     */
    private fun registerRealtimeChannel() {
        RealtimeSubscriptionBridge.registerChannel(
            channelId = channelId,
            topic = "realtime:chat_messages",
            table = "chat_messages",
            filter = "room_id=eq.$roomId"
        )
        RealtimeSubscriptionBridge.markConnecting(channelId)
        updateConnectionState()
    }

    /**
     * Handle channel connection established.
     */
    private fun onChannelConnected() {
        RealtimeSubscriptionBridge.markConnected(channelId)
        reconnectionJob?.cancel()
        updateConnectionState()
    }

    /**
     * Handle channel disconnection with auto-reconnect.
     */
    private fun onChannelDisconnected() {
        RealtimeSubscriptionBridge.markDisconnected(channelId)
        updateConnectionState()
        scheduleReconnection()
    }

    /**
     * Schedule reconnection with exponential backoff via Swift.
     */
    private fun scheduleReconnection() {
        if (!RealtimeSubscriptionBridge.shouldRetryReconnection(channelId)) {
            _uiState.update { it.copy(
                connectionState = ConnectionState.FAILED,
                error = "Unable to connect to chat. Please check your connection."
            ) }
            return
        }

        reconnectionJob?.cancel()
        reconnectionJob = viewModelScope.launch {
            val delayMs = RealtimeSubscriptionBridge.getReconnectionDelay(channelId)
            _uiState.update { it.copy(connectionState = ConnectionState.RECONNECTING) }

            delay(delayMs)

            RealtimeSubscriptionBridge.markConnecting(channelId)
            updateConnectionState()
            // Realtime subscription will handle actual reconnection
            // The observeMessages() flow will automatically reconnect
        }
    }

    /**
     * Update UI state with current channel connection state.
     */
    private fun updateConnectionState() {
        val channelState = RealtimeSubscriptionBridge.getChannelState(channelId)
        val connectionState = when (channelState) {
            ChannelState.CONNECTED -> ConnectionState.CONNECTED
            ChannelState.CONNECTING -> ConnectionState.CONNECTING
            ChannelState.RECONNECTING, ChannelState.BACKING_OFF -> ConnectionState.RECONNECTING
            ChannelState.FAILED -> ConnectionState.FAILED
            else -> ConnectionState.DISCONNECTED
        }
        _uiState.update { it.copy(connectionState = connectionState) }
    }

    private fun observeNewMessages() {
        viewModelScope.launch {
            chatRepository.observeMessages(roomId).collect { message ->
                // Mark channel as connected when we receive messages
                if (RealtimeSubscriptionBridge.getChannelState(channelId) != ChannelState.CONNECTED) {
                    onChannelConnected()
                }

                // Use Swift bridge for message deduplication
                val messageFingerprint = RealtimeSubscriptionBridge.generateMessageFingerprint(
                    table = "chat_messages",
                    eventType = "INSERT",
                    recordId = message.id.toString(),
                    timestamp = message.createdAt
                ) ?: message.id.toString()

                // Only process if not a duplicate
                if (RealtimeSubscriptionBridge.shouldProcessMessage(channelId, messageFingerprint)) {
                    _uiState.update { state ->
                        state.copy(
                            messages = listOf(message) + state.messages
                        )
                    }
                    // Mark as read when new message arrives
                    markAsRead()
                }
            }
        }
    }

    /**
     * Manually trigger reconnection attempt.
     */
    fun retryConnection() {
        RealtimeSubscriptionBridge.resetChannel(channelId)
        registerRealtimeChannel()
        loadMessages()
    }

    override fun onCleared() {
        super.onCleared()
        reconnectionJob?.cancel()
        RealtimeSubscriptionBridge.closeChannel(channelId)
        RealtimeSubscriptionBridge.removeChannel(channelId)
    }

    fun loadMessages() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            chatRepository.getMessages(roomId = roomId)
                .onSuccess { messages ->
                    _uiState.update {
                        it.copy(
                            messages = messages,
                            isLoading = false
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapMessageError(error)
                        )
                    }
                }
        }
    }

    fun loadMoreMessages() {
        val state = _uiState.value
        if (state.isLoadingMore || !state.hasMore) return

        val lastMessage = state.messages.lastOrNull() ?: return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingMore = true) }

            chatRepository.getMessages(
                roomId = roomId,
                cursor = lastMessage.createdAt
            ).onSuccess { olderMessages ->
                _uiState.update {
                    it.copy(
                        messages = it.messages + olderMessages,
                        isLoadingMore = false,
                        hasMore = olderMessages.isNotEmpty()
                    )
                }
            }.onFailure {
                _uiState.update { it.copy(isLoadingMore = false) }
            }
        }
    }

    /**
     * Send message with Swift-backed optimistic updates.
     * Uses OptimisticUpdateBridge for:
     * - Instant message display before server confirmation
     * - Smart rollback on failure
     * - Retry with exponential backoff for transient errors
     */
    fun sendMessage(content: String) {
        if (content.isBlank()) return

        // Validate message content using Swift
        val validationResult = ValidationBridge.validateMessage(content)
        if (!validationResult.isValid) {
            _uiState.update { it.copy(error = validationResult.firstError) }
            return
        }

        // Sanitize message content using Swift
        val sanitizedContent = ValidationBridge.sanitizeMessage(content)
        if (sanitizedContent.isBlank()) return

        // Generate optimistic message ID
        val optimisticId = UUID.randomUUID().toString()
        val optimisticMessage = ChatMessage(
            id = optimisticId,
            roomId = roomId,
            senderId = null, // Will be filled by server
            content = sanitizedContent,
            messageType = MessageType.TEXT,
            createdAt = Instant.now().toString(),
            isOptimistic = true,
            isFromMe = true
        )

        // Create optimistic update via Swift bridge
        val optimisticUpdate = OptimisticUpdateBridge.createUpdate(
            id = optimisticId,
            entityType = EntityType.MESSAGE,
            operation = UpdateOperation.CREATE,
            originalValue = null,
            optimisticValue = sanitizedContent
        )

        // Apply optimistic update to UI immediately
        _uiState.update {
            it.copy(
                messages = listOf(optimisticMessage) + it.messages,
                isSending = true,
                messageInput = ""
            )
        }

        viewModelScope.launch {
            chatRepository.sendMessage(
                roomId = roomId,
                content = sanitizedContent,
                messageType = MessageType.TEXT
            ).onSuccess { serverMessage ->
                // Confirm optimistic update and replace with server message
                optimisticUpdate?.let { OptimisticUpdateBridge.confirmUpdate(it) }

                _uiState.update { state ->
                    // Replace optimistic message with server-confirmed message
                    val updatedMessages = state.messages.map { msg ->
                        if (msg.id == optimisticMessage.id) serverMessage else msg
                    }
                    state.copy(
                        messages = updatedMessages,
                        isSending = false
                    )
                }
            }.onFailure { error ->
                // Use Swift bridge for rollback decision
                if (optimisticUpdate != null) {
                    val recommendation = OptimisticUpdateBridge.handleError(
                        update = optimisticUpdate,
                        errorCode = "SEND_FAILED",
                        errorMessage = error.message ?: "Failed to send message",
                        category = categorizeError(error)
                    )

                    if (recommendation.shouldRollback) {
                        // Rollback via Swift bridge
                        OptimisticUpdateBridge.rollback(optimisticUpdate)
                        // Remove optimistic message from UI
                        _uiState.update { state ->
                            state.copy(
                                messages = state.messages.filter { it.id != optimisticMessage.id },
                                isSending = false,
                                error = error.message ?: "Failed to send message",
                                messageInput = sanitizedContent // Restore input for retry
                            )
                        }
                    } else if (recommendation.shouldRetry && recommendation.delayMs != null) {
                        // Mark message as retrying
                        _uiState.update { state ->
                            val updatedMessages = state.messages.map { msg ->
                                if (msg.id == optimisticMessage.id) {
                                    msg.copy(isRetrying = true)
                                } else msg
                            }
                            state.copy(messages = updatedMessages, isSending = false)
                        }
                        // Retry after delay
                        delay(recommendation.delayMs)
                        retrySendMessage(optimisticMessage, optimisticUpdate, sanitizedContent)
                    }
                } else {
                    _uiState.update {
                        it.copy(
                            isSending = false,
                            error = error.message ?: "Failed to send message"
                        )
                    }
                }
            }
        }
    }

    /**
     * Retry sending a failed message.
     */
    private fun retrySendMessage(
        optimisticMessage: ChatMessage,
        update: com.foodshare.core.optimistic.OptimisticUpdate,
        content: String
    ) {
        viewModelScope.launch {
            val incrementedUpdate = OptimisticUpdateBridge.incrementRetry(update)

            chatRepository.sendMessage(
                roomId = roomId,
                content = content,
                messageType = MessageType.TEXT
            ).onSuccess { serverMessage ->
                OptimisticUpdateBridge.confirmUpdate(incrementedUpdate)
                _uiState.update { state ->
                    val updatedMessages = state.messages.map { msg ->
                        if (msg.id == optimisticMessage.id) serverMessage else msg
                    }
                    state.copy(messages = updatedMessages)
                }
            }.onFailure { error ->
                val recommendation = OptimisticUpdateBridge.handleError(
                    update = incrementedUpdate,
                    errorCode = "RETRY_FAILED",
                    errorMessage = error.message ?: "Retry failed",
                    category = categorizeError(error)
                )

                if (recommendation.shouldRollback) {
                    OptimisticUpdateBridge.rollback(incrementedUpdate)
                    _uiState.update { state ->
                        state.copy(
                            messages = state.messages.filter { it.id != optimisticMessage.id },
                            error = "Message failed to send after retries",
                            messageInput = content
                        )
                    }
                }
            }
        }
    }

    /**
     * Categorize error for OptimisticUpdateBridge.
     */
    private fun categorizeError(error: Throwable): ErrorCategory {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("network") || message.contains("timeout") -> ErrorCategory.NETWORK
            message.contains("unauthorized") || message.contains("401") -> ErrorCategory.AUTHORIZATION
            message.contains("conflict") || message.contains("409") -> ErrorCategory.CONFLICT
            message.contains("validation") || message.contains("400") -> ErrorCategory.VALIDATION
            message.contains("server") || message.contains("500") -> ErrorCategory.SERVER_ERROR
            else -> ErrorCategory.UNKNOWN
        }
    }

    fun updateMessageInput(input: String) {
        _uiState.update { it.copy(messageInput = input) }
    }

    private fun markAsRead() {
        viewModelScope.launch {
            chatRepository.markAsRead(roomId)
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}

/**
 * UI State for Conversation
 */
data class ConversationUiState(
    val room: ChatRoom? = null,
    val messages: List<ChatMessage> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val isSending: Boolean = false,
    val error: String? = null,
    val messageInput: String = "",
    val hasMore: Boolean = true,
    val connectionState: ConnectionState = ConnectionState.CONNECTING
) {
    val isConnected: Boolean get() = connectionState == ConnectionState.CONNECTED
    val showConnectionBanner: Boolean get() = connectionState != ConnectionState.CONNECTED
    val connectionMessage: String? get() = when (connectionState) {
        ConnectionState.CONNECTING -> "Connecting..."
        ConnectionState.RECONNECTING -> "Reconnecting..."
        ConnectionState.DISCONNECTED -> "Disconnected"
        ConnectionState.FAILED -> "Connection failed"
        ConnectionState.CONNECTED -> null
    }
}

/**
 * Connection state for realtime messaging.
 * Mirrors Swift ChannelState for UI display.
 */
enum class ConnectionState {
    CONNECTING,
    CONNECTED,
    RECONNECTING,
    DISCONNECTED,
    FAILED
}
