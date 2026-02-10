package com.foodshare.features.messaging.data

import android.util.Log
import com.foodshare.core.realtime.RealtimeChange
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.core.realtime.RealtimeFilter
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Message DTO for realtime updates.
 */
@Serializable
data class MessageDto(
    val id: String,
    @SerialName("conversation_id") val conversationId: String,
    @SerialName("sender_id") val senderId: String,
    val content: String,
    @SerialName("created_at") val createdAt: String,
    @SerialName("read_at") val readAt: String? = null,
    @SerialName("message_type") val messageType: String = "text"
)

/**
 * Domain message model.
 */
data class Message(
    val id: String,
    val conversationId: String,
    val senderId: String,
    val content: String,
    val createdAt: String,
    val readAt: String?,
    val messageType: String,
    val isFromMe: Boolean = false
)

/**
 * Observes realtime chat message updates.
 *
 * Use cases:
 * - New messages in active conversation
 * - Message read receipts
 * - Typing indicators (if implemented)
 */
@Singleton
class ChatRealtimeObserver @Inject constructor(
    private val realtimeManager: RealtimeChannelManager
) {
    companion object {
        private const val TAG = "ChatRealtimeObserver"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _newMessages = MutableSharedFlow<Message>(replay = 0)
    val newMessages: SharedFlow<Message> = _newMessages.asSharedFlow()

    private val _messageUpdates = MutableSharedFlow<Message>(replay = 0)
    val messageUpdates: SharedFlow<Message> = _messageUpdates.asSharedFlow()

    private val _activeConversationId = MutableStateFlow<String?>(null)
    val activeConversationId: StateFlow<String?> = _activeConversationId.asStateFlow()

    private var currentUserId: String? = null

    /**
     * Start observing messages for a specific conversation.
     *
     * @param conversationId The conversation to observe
     * @param userId Current user ID (to mark messages as "from me")
     */
    suspend fun startObserving(conversationId: String, userId: String) {
        // Stop previous observation if any
        stopObserving()

        Log.d(TAG, "Starting chat observation for conversation: $conversationId")
        _activeConversationId.value = conversationId
        currentUserId = userId

        val filter = RealtimeFilter(
            table = "messages",
            filter = "conversation_id=eq.$conversationId"
        )

        scope.launch {
            try {
                realtimeManager.subscribe<MessageDto>(filter)
                    .collect { change ->
                        handleChange(change)
                    }
            } catch (e: Exception) {
                Log.e(TAG, "Chat observation error", e)
                _activeConversationId.value = null
            }
        }
    }

    /**
     * Start observing all messages for a user (for notifications).
     *
     * @param userId User ID to observe messages for
     */
    suspend fun startObservingAllMessages(userId: String) {
        Log.d(TAG, "Starting observation for all messages to user: $userId")
        currentUserId = userId

        // Subscribe to messages where user is recipient
        val filter = RealtimeFilter(
            table = "messages",
            // Note: This filter may need adjustment based on your schema
            // You might need a different column like "recipient_id"
        )

        scope.launch {
            try {
                realtimeManager.subscribe<MessageDto>(filter)
                    .collect { change ->
                        // Only emit if message is not from current user
                        if (change is RealtimeChange.Insert) {
                            val dto = change.record
                            if (dto.senderId != userId) {
                                handleChange(change)
                            }
                        }
                    }
            } catch (e: Exception) {
                Log.e(TAG, "All messages observation error", e)
            }
        }
    }

    /**
     * Stop observing messages.
     */
    suspend fun stopObserving() {
        _activeConversationId.value?.let { conversationId ->
            Log.d(TAG, "Stopping chat observation for: $conversationId")
            realtimeManager.unsubscribe(
                RealtimeFilter(
                    table = "messages",
                    filter = "conversation_id=eq.$conversationId"
                )
            )
        }
        _activeConversationId.value = null
    }

    /**
     * Handle a realtime change event.
     */
    private suspend fun handleChange(change: RealtimeChange<MessageDto>) {
        when (change) {
            is RealtimeChange.Insert -> {
                val message = change.record.toDomain()
                Log.d(TAG, "New message: ${message.id}")
                _newMessages.emit(message)
            }

            is RealtimeChange.Update -> {
                val message = change.record.toDomain()
                Log.d(TAG, "Updated message: ${message.id}")
                _messageUpdates.emit(message)
            }

            is RealtimeChange.Delete -> {
                // Messages typically aren't hard deleted
                Log.d(TAG, "Message deleted")
            }
        }
    }

    /**
     * Convert DTO to domain model.
     */
    private fun MessageDto.toDomain(): Message {
        return Message(
            id = id,
            conversationId = conversationId,
            senderId = senderId,
            content = content,
            createdAt = createdAt,
            readAt = readAt,
            messageType = messageType,
            isFromMe = senderId == currentUserId
        )
    }

    /**
     * Observe new messages as a Flow.
     */
    fun observeNewMessages(): Flow<Message> = newMessages

    /**
     * Observe message updates as a Flow (read receipts, etc).
     */
    fun observeMessageUpdates(): Flow<Message> = messageUpdates

    /**
     * Check if currently observing a conversation.
     */
    fun isObserving(conversationId: String): Boolean {
        return _activeConversationId.value == conversationId
    }

    /**
     * Cleanup resources.
     */
    fun destroy() {
        scope.cancel()
    }
}

/**
 * Typing indicator state.
 */
data class TypingState(
    val conversationId: String,
    val userId: String,
    val isTyping: Boolean,
    val timestamp: Long
)
