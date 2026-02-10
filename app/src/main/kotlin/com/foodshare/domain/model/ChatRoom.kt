package com.foodshare.domain.model

import com.foodshare.swift.generated.RelativeDateFormatter as SwiftRelativeDateFormatter
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Chat room domain model
 *
 * Maps to `chat_rooms` and `room_members` tables in Supabase
 *
 * Architecture (Frameo pattern):
 * - Uses swift-java generated RelativeDateFormatter for iOS/Android consistency
 * - Computed properties mirror Swift ChatRoom for cross-platform parity
 */
@Serializable
data class ChatRoom(
    val id: String,
    @SerialName("room_name") val roomName: String? = null,
    @SerialName("room_type") val roomType: RoomType = RoomType.DIRECT,
    @SerialName("post_id") val postId: Int? = null,
    @SerialName("is_muted") val isMuted: Boolean = false,
    @SerialName("is_pinned") val isPinned: Boolean = false,
    @SerialName("is_archived") val isArchived: Boolean = false,
    @SerialName("unread_count") val unreadCount: Int = 0,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("last_message_id") val lastMessageId: String? = null,
    @SerialName("last_message_content") val lastMessage: String? = null,
    @SerialName("last_message_at") val lastMessageTime: String? = null,
    @SerialName("last_message_sender_id") val lastMessageSenderId: String? = null,
    @SerialName("last_message_sender_name") val lastMessageSenderName: String? = null,
    @SerialName("last_message_read") val lastMessageRead: Boolean? = null,
    val participants: List<ChatParticipant>? = null,
    @SerialName("related_post") val relatedPost: ChatRoomPost? = null
) {
    val displayName: String
        get() = roomName?.takeIf { it.isNotEmpty() }
            ?: otherParticipant?.displayName
            ?: "Conversation"

    val displayAvatarUrl: String?
        get() = otherParticipant?.avatarUrl

    val otherParticipant: ChatParticipant?
        get() = participants?.firstOrNull()

    val hasUnread: Boolean
        get() = unreadCount > 0

    val lastMessagePreview: String
        get() = lastMessage?.let {
            if (it.length > 50) it.take(47) + "..." else it
        } ?: "No messages yet"

    /**
     * Last message time using Swift formatter (matches iOS).
     */
    val lastMessageRelativeTime: String?
        get() = lastMessageTime?.let { SwiftRelativeDateFormatter.format(it) }

    /**
     * Last activity time using Swift formatter.
     */
    val lastActivityRelativeTime: String?
        get() = updatedAt?.let { SwiftRelativeDateFormatter.format(it) }

    /**
     * Room created time using Swift formatter.
     */
    val createdRelativeTime: String?
        get() = createdAt?.let { SwiftRelativeDateFormatter.format(it) }

    /**
     * Formatted time for last message using Swift formatter.
     */
    val lastMessageFormattedTime: String?
        get() = lastMessageTime?.let { SwiftRelativeDateFormatter.formatTime(it) }
}

/**
 * Room type
 */
@Serializable
enum class RoomType {
    @SerialName("direct")
    DIRECT,
    @SerialName("group")
    GROUP,
    @SerialName("post")
    POST;

    val displayName: String
        get() = when (this) {
            DIRECT -> "Direct Message"
            GROUP -> "Group Chat"
            POST -> "Listing Chat"
        }
}

/**
 * Chat participant info
 */
@Serializable
data class ChatParticipant(
    val id: String,
    @SerialName("display_name") val displayName: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("is_online") val isOnline: Boolean? = null
)

/**
 * Minimal post info for chat room context
 */
@Serializable
data class ChatRoomPost(
    val id: Int,
    @SerialName("post_name") val postName: String,
    @SerialName("image_url") val imageUrl: String? = null
)
