package com.foodshare.core.cache

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Pending message for offline queue.
 */
@Serializable
data class PendingMessage(
    val id: String = UUID.randomUUID().toString(),
    val roomId: String,
    val content: String,
    val timestamp: Long = System.currentTimeMillis(),
    val retryCount: Int = 0,
    val status: MessageStatus = MessageStatus.PENDING
) {
    val maxRetries: Int get() = 3
    val canRetry: Boolean get() = retryCount < maxRetries
}

/**
 * Status of a queued message.
 */
@Serializable
enum class MessageStatus {
    PENDING,
    SENDING,
    SENT,
    FAILED
}

/**
 * Message queue for offline-first messaging.
 *
 * Queues messages when offline and flushes them when back online.
 */
interface MessageQueue {
    /**
     * Add a message to the queue.
     *
     * @param roomId Chat room ID
     * @param content Message content
     * @return ID of the queued message
     */
    suspend fun enqueue(roomId: String, content: String): String

    /**
     * Get all pending messages.
     */
    suspend fun getPendingMessages(): List<PendingMessage>

    /**
     * Get pending messages for a specific room.
     */
    suspend fun getPendingMessages(roomId: String): List<PendingMessage>

    /**
     * Mark a message as sending.
     */
    suspend fun markSending(messageId: String)

    /**
     * Mark a message as sent and remove from queue.
     */
    suspend fun markSent(messageId: String)

    /**
     * Mark a message as failed.
     */
    suspend fun markFailed(messageId: String)

    /**
     * Retry a failed message.
     */
    suspend fun retry(messageId: String)

    /**
     * Clear all pending messages.
     */
    suspend fun clearAll()

    /**
     * Observe pending message count.
     */
    fun observePendingCount(): Flow<Int>

    /**
     * Observe pending messages for a room.
     */
    fun observePendingMessages(roomId: String): Flow<List<PendingMessage>>
}

// DataStore extension
private val Context.messageQueueDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "message_queue"
)

private val QUEUE_KEY = stringPreferencesKey("pending_messages")

/**
 * DataStore-based implementation of MessageQueue.
 */
@Singleton
class DataStoreMessageQueue @Inject constructor(
    private val context: Context
) : MessageQueue {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    override suspend fun enqueue(roomId: String, content: String): String {
        val message = PendingMessage(
            roomId = roomId,
            content = content
        )

        val current = loadMessages()
        saveMessages(current + message)

        return message.id
    }

    override suspend fun getPendingMessages(): List<PendingMessage> {
        return loadMessages().filter { it.status == MessageStatus.PENDING }
    }

    override suspend fun getPendingMessages(roomId: String): List<PendingMessage> {
        return getPendingMessages().filter { it.roomId == roomId }
    }

    override suspend fun markSending(messageId: String) {
        updateMessage(messageId) { it.copy(status = MessageStatus.SENDING) }
    }

    override suspend fun markSent(messageId: String) {
        val current = loadMessages()
        saveMessages(current.filter { it.id != messageId })
    }

    override suspend fun markFailed(messageId: String) {
        updateMessage(messageId) {
            it.copy(
                status = MessageStatus.FAILED,
                retryCount = it.retryCount + 1
            )
        }
    }

    override suspend fun retry(messageId: String) {
        updateMessage(messageId) { it.copy(status = MessageStatus.PENDING) }
    }

    override suspend fun clearAll() {
        context.messageQueueDataStore.edit { prefs ->
            prefs.remove(QUEUE_KEY)
        }
    }

    override fun observePendingCount(): Flow<Int> {
        return context.messageQueueDataStore.data.map { prefs ->
            val queueJson = prefs[QUEUE_KEY] ?: "[]"
            try {
                json.decodeFromString<List<PendingMessage>>(queueJson)
                    .count { it.status == MessageStatus.PENDING }
            } catch (e: Exception) {
                0
            }
        }
    }

    override fun observePendingMessages(roomId: String): Flow<List<PendingMessage>> {
        return context.messageQueueDataStore.data.map { prefs ->
            val queueJson = prefs[QUEUE_KEY] ?: "[]"
            try {
                json.decodeFromString<List<PendingMessage>>(queueJson)
                    .filter { it.roomId == roomId && it.status == MessageStatus.PENDING }
            } catch (e: Exception) {
                emptyList()
            }
        }
    }

    private suspend fun loadMessages(): List<PendingMessage> {
        val prefs = context.messageQueueDataStore.data.first()
        val queueJson = prefs[QUEUE_KEY] ?: return emptyList()

        return try {
            json.decodeFromString<List<PendingMessage>>(queueJson)
        } catch (e: Exception) {
            emptyList()
        }
    }

    private suspend fun saveMessages(messages: List<PendingMessage>) {
        context.messageQueueDataStore.edit { prefs ->
            prefs[QUEUE_KEY] = json.encodeToString(messages)
        }
    }

    private suspend fun updateMessage(
        messageId: String,
        transform: (PendingMessage) -> PendingMessage
    ) {
        val current = loadMessages()
        val updated = current.map {
            if (it.id == messageId) transform(it) else it
        }
        saveMessages(updated)
    }
}

/**
 * Message queue flusher - sends pending messages when back online.
 */
interface MessageQueueFlusher {
    /**
     * Flush all pending messages.
     *
     * @param sendMessage Function to send a single message
     * @return Number of messages successfully sent
     */
    suspend fun flush(
        sendMessage: suspend (roomId: String, content: String) -> Result<Unit>
    ): Int
}

/**
 * Default implementation of MessageQueueFlusher.
 */
@Singleton
class DefaultMessageQueueFlusher @Inject constructor(
    private val messageQueue: MessageQueue
) : MessageQueueFlusher {

    override suspend fun flush(
        sendMessage: suspend (roomId: String, content: String) -> Result<Unit>
    ): Int {
        val pending = messageQueue.getPendingMessages()
        var sentCount = 0

        for (message in pending.sortedBy { it.timestamp }) {
            if (!message.canRetry) {
                // Skip messages that have exceeded retry limit
                continue
            }

            messageQueue.markSending(message.id)

            val result = sendMessage(message.roomId, message.content)

            result.onSuccess {
                messageQueue.markSent(message.id)
                sentCount++
            }.onFailure {
                messageQueue.markFailed(message.id)
            }
        }

        return sentCount
    }
}
