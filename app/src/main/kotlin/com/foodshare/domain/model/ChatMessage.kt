package com.foodshare.domain.model

import com.foodshare.swift.generated.RelativeDateFormatter as SwiftRelativeDateFormatter
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Chat message domain model
 *
 * Maps to `messages` table in Supabase
 *
 * Architecture (Frameo pattern):
 * - Uses swift-java generated RelativeDateFormatter for iOS/Android consistency
 * - Computed properties mirror Swift ChatMessage for cross-platform parity
 */
@Serializable
data class ChatMessage(
    val id: String,
    @SerialName("room_id") val roomId: String,
    @SerialName("sender_id") val senderId: String? = null,
    val content: String,
    @SerialName("message_type") val messageType: MessageType = MessageType.TEXT,
    @SerialName("created_at") val createdAt: String,
    @SerialName("read_at") val readAt: String? = null,
    @SerialName("sender_name") val senderName: String? = null,
    @SerialName("sender_avatar") val senderAvatar: String? = null,
    @SerialName("is_from_me") val isFromMe: Boolean = false,
    // Optimistic update support
    @kotlinx.serialization.Transient val isOptimistic: Boolean = false,
    @kotlinx.serialization.Transient val isRetrying: Boolean = false,
    @kotlinx.serialization.Transient val sendFailed: Boolean = false
) {
    val isRead: Boolean get() = readAt != null
    val isSystem: Boolean get() = messageType.isSystem
    val isPending: Boolean get() = isOptimistic && !sendFailed

    /** Format createdAt as relative time using Swift RelativeDateFormatter */
    val relativeTime: String
        get() = SwiftRelativeDateFormatter.format(createdAt)

    /** Format createdAt as time only (e.g., "2:30 PM") using Swift formatter */
    val formattedTime: String
        get() = SwiftRelativeDateFormatter.formatTime(createdAt)
}

/**
 * Types of messages
 */
@Serializable
enum class MessageType {
    @SerialName("text")
    TEXT,
    @SerialName("image")
    IMAGE,
    @SerialName("location")
    LOCATION,
    @SerialName("system_arrangement")
    SYSTEM_ARRANGEMENT,
    @SerialName("system_info")
    SYSTEM_INFO;

    val isSystem: Boolean
        get() = this == SYSTEM_ARRANGEMENT || this == SYSTEM_INFO
}

/**
 * Typing indicator for real-time updates
 */
@Serializable
data class TypingIndicator(
    @SerialName("room_id") val roomId: String,
    @SerialName("user_id") val userId: String,
    @SerialName("user_name") val userName: String? = null,
    @SerialName("is_typing") val isTyping: Boolean,
    @SerialName("updated_at") val updatedAt: String
)
