package com.foodshare.domain.repository

import com.foodshare.domain.model.ChatMessage
import com.foodshare.domain.model.ChatRoom
import com.foodshare.domain.model.MessageType
import com.foodshare.domain.model.TypingIndicator
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for chat/messaging operations
 *
 * Matches iOS: MessagingRepository
 */
interface ChatRepository {

    /**
     * Get user's chat rooms with last message preview
     */
    suspend fun getRooms(
        searchQuery: String? = null,
        filterType: String = "all", // all, unread, sharing, receiving
        limit: Int = 50,
        offset: Int = 0
    ): Result<List<ChatRoom>>

    /**
     * Get or create a chat room for a post
     */
    suspend fun getOrCreateRoom(
        postId: Int,
        sharerId: String,
        requesterId: String
    ): Result<ChatRoom>

    /**
     * Get messages for a room with pagination
     */
    suspend fun getMessages(
        roomId: String,
        limit: Int = 50,
        cursor: String? = null
    ): Result<List<ChatMessage>>

    /**
     * Send a message to a room
     */
    suspend fun sendMessage(
        roomId: String,
        content: String,
        messageType: MessageType = MessageType.TEXT
    ): Result<ChatMessage>

    /**
     * Mark all messages in a room as read
     */
    suspend fun markAsRead(roomId: String): Result<Unit>

    /**
     * Observe new messages in a room (real-time)
     */
    fun observeMessages(roomId: String): Flow<ChatMessage>

    /**
     * Observe typing indicators in a room
     */
    fun observeTyping(roomId: String): Flow<TypingIndicator>

    /**
     * Send typing indicator
     */
    suspend fun sendTypingIndicator(roomId: String, isTyping: Boolean)

    /**
     * Observe total unread count across all rooms
     */
    fun observeUnreadCount(): Flow<Int>

    /**
     * Mute/unmute a room
     */
    suspend fun setRoomMuted(roomId: String, muted: Boolean): Result<Unit>

    /**
     * Pin/unpin a room
     */
    suspend fun setRoomPinned(roomId: String, pinned: Boolean): Result<Unit>

    /**
     * Archive a room
     */
    suspend fun archiveRoom(roomId: String): Result<Unit>
}
