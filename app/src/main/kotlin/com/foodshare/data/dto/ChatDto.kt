package com.foodshare.data.dto

import com.foodshare.domain.model.ChatMessage
import com.foodshare.domain.model.ChatParticipant
import com.foodshare.domain.model.ChatRoom
import com.foodshare.domain.model.ChatRoomPost
import com.foodshare.domain.model.MessageType
import com.foodshare.domain.model.RoomType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for chat messages from Supabase
 */
@Serializable
data class ChatMessageDto(
    val id: String,
    @SerialName("room_id") val roomId: String,
    @SerialName("sender_id") val senderId: String,
    val content: String,
    @SerialName("message_type") val messageType: String = "text",
    @SerialName("created_at") val createdAt: String,
    @SerialName("read_at") val readAt: String? = null,
    @SerialName("sender_name") val senderName: String? = null,
    @SerialName("sender_avatar") val senderAvatar: String? = null,
    @SerialName("is_from_me") val isFromMe: Boolean = false
) {
    fun toDomain(): ChatMessage {
        return ChatMessage(
            id = id,
            roomId = roomId,
            senderId = senderId,
            content = content,
            messageType = parseMessageType(messageType),
            createdAt = createdAt,
            readAt = readAt,
            senderName = senderName,
            senderAvatar = senderAvatar,
            isFromMe = isFromMe
        )
    }

    private fun parseMessageType(type: String): MessageType {
        return when (type.lowercase()) {
            "text" -> MessageType.TEXT
            "image" -> MessageType.IMAGE
            "location" -> MessageType.LOCATION
            "system_arrangement" -> MessageType.SYSTEM_ARRANGEMENT
            "system_info" -> MessageType.SYSTEM_INFO
            else -> MessageType.TEXT
        }
    }
}

/**
 * DTO for chat rooms from Supabase BFF
 */
@Serializable
data class ChatRoomDto(
    @SerialName("room_id") val id: String,
    @SerialName("room_name") val roomName: String? = null,
    @SerialName("room_type") val roomType: String = "direct",
    @SerialName("post_id") val postId: Int? = null,
    @SerialName("is_muted") val isMuted: Boolean = false,
    @SerialName("is_pinned") val isPinned: Boolean = false,
    @SerialName("is_archived") val isArchived: Boolean = false,
    @SerialName("unread_count") val unreadCount: Int = 0,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("last_message_id") val lastMessageId: String? = null,
    @SerialName("last_message_content") val lastMessage: String? = null,
    @SerialName("last_message_at") val lastMessageTime: String? = null,
    @SerialName("last_message_sender_id") val lastMessageSenderId: String? = null,
    @SerialName("last_message_sender_name") val lastMessageSenderName: String? = null,
    @SerialName("last_message_read") val lastMessageRead: Boolean? = null,
    val participants: List<ChatParticipantDto>? = null
) {
    fun toDomain(): ChatRoom {
        return ChatRoom(
            id = id,
            roomName = roomName,
            roomType = parseRoomType(roomType),
            postId = postId,
            isMuted = isMuted,
            isPinned = isPinned,
            isArchived = isArchived,
            unreadCount = unreadCount,
            updatedAt = updatedAt,
            lastMessageId = lastMessageId,
            lastMessage = lastMessage,
            lastMessageTime = lastMessageTime,
            lastMessageSenderId = lastMessageSenderId,
            lastMessageSenderName = lastMessageSenderName,
            lastMessageRead = lastMessageRead,
            participants = participants?.map { it.toDomain() }
        )
    }

    private fun parseRoomType(type: String): RoomType {
        return when (type.lowercase()) {
            "direct" -> RoomType.DIRECT
            "group" -> RoomType.GROUP
            "post" -> RoomType.POST
            else -> RoomType.DIRECT
        }
    }
}

/**
 * DTO for chat participants
 */
@Serializable
data class ChatParticipantDto(
    val id: String,
    @SerialName("display_name") val displayName: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("is_online") val isOnline: Boolean? = null
) {
    fun toDomain(): ChatParticipant {
        return ChatParticipant(
            id = id,
            displayName = displayName,
            avatarUrl = avatarUrl,
            isOnline = isOnline
        )
    }
}

/**
 * Response from get_bff_messages_data
 */
@Serializable
data class BffMessagesResponse(
    val rooms: List<ChatRoomDto> = emptyList(),
    @SerialName("total_unread") val totalUnread: Int = 0
)

/**
 * Response from get_room_messages
 */
@Serializable
data class RoomMessagesResponse(
    val success: Boolean,
    val messages: List<ChatMessageDto> = emptyList(),
    @SerialName("has_more") val hasMore: Boolean = false,
    val error: String? = null
)

/**
 * Response from send_message
 */
@Serializable
data class SendMessageResponse(
    val success: Boolean,
    val message: ChatMessageDto? = null,
    val error: String? = null
)

/**
 * Response from get_or_create_room (legacy format)
 */
@Serializable
data class GetOrCreateRoomResponse(
    val id: String,
    @SerialName("post_id") val postId: Long,
    val sharer: String,
    val requester: String,
    @SerialName("last_message") val lastMessage: String? = null,
    @SerialName("last_message_time") val lastMessageTime: String? = null
) {
    fun toChatRoom(): ChatRoom {
        return ChatRoom(
            id = id,
            postId = postId.toInt(),
            lastMessage = lastMessage,
            lastMessageTime = lastMessageTime
        )
    }
}
