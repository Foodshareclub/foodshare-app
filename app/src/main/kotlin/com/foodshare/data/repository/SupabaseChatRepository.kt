package com.foodshare.data.repository

import com.foodshare.core.cache.CacheKeys
import com.foodshare.core.cache.CachedRepository
import com.foodshare.core.cache.OfflineCache
import com.foodshare.core.cache.withCache
import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.network.RPCConfig
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.core.realtime.RealtimeFilter
import com.foodshare.data.dto.BffMessagesResponse
import com.foodshare.data.dto.ChatMessageDto
import com.foodshare.data.dto.GetOrCreateRoomResponse
import com.foodshare.data.dto.RoomMessagesResponse
import com.foodshare.data.dto.SendMessageResponse
import com.foodshare.domain.model.ChatMessage
import com.foodshare.domain.model.ChatRoom
import com.foodshare.domain.model.MessageType
import com.foodshare.domain.model.TypingIndicator
import com.foodshare.domain.repository.ChatRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of ChatRepository
 *
 * Uses:
 * - RateLimitedRPCClient for fault-tolerant RPC calls
 * - RealtimeChannelManager for message subscriptions
 * - OfflineCache for NETWORK_FIRST caching pattern
 *
 * SYNC: Follows iOS repository caching pattern
 */
@Singleton
class SupabaseChatRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val rpcClient: RateLimitedRPCClient,
    private val realtimeManager: RealtimeChannelManager,
    override val offlineCache: OfflineCache
) : ChatRepository, CachedRepository {

    override val json = Json { ignoreUnknownKeys = true }

    private val _unreadCount = MutableStateFlow(0)

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    override suspend fun getRooms(
        searchQuery: String?,
        filterType: String,
        limit: Int,
        offset: Int
    ): Result<List<ChatRoom>> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = GetUserRoomsParams(
            userId = userId,
            searchQuery = searchQuery,
            filterType = filterType,
            limit = limit,
            offset = offset
        )

        val networkResult = rpcClient.call<GetUserRoomsParams, BffMessagesResponse>(
            functionName = "get_bff_messages_data",
            params = params,
            config = RPCConfig.default
        ).map { response ->
            _unreadCount.value = response.totalUnread
            response.rooms.map { it.toDomain() }
        }

        // Cache first page of unfiltered room list
        return if (offset == 0 && searchQuery.isNullOrBlank() && filterType == "all") {
            try {
                val cached = networkResult.withCache(
                    cache = offlineCache,
                    key = CacheKeys.CHAT_ROOMS,
                    ttlMs = OfflineCache.LONG_TTL_MS,
                    serialize = { rooms ->
                        json.encodeToString(ListSerializer(ChatRoom.serializer()), rooms)
                    },
                    deserialize = { jsonStr ->
                        json.decodeFromString(ListSerializer(ChatRoom.serializer()), jsonStr)
                    }
                )
                Result.success(cached.data)
            } catch (e: Exception) {
                Result.failure(e)
            }
        } else {
            networkResult
        }
    }

    override suspend fun getOrCreateRoom(
        postId: Int,
        sharerId: String,
        requesterId: String
    ): Result<ChatRoom> {
        val params = GetOrCreateRoomParams(
            postId = postId.toLong(),
            sharerId = sharerId,
            requesterId = requesterId
        )

        return rpcClient.call<GetOrCreateRoomParams, List<GetOrCreateRoomResponse>>(
            functionName = "get_or_create_room",
            params = params,
            config = RPCConfig.default
        ).map { response ->
            response.firstOrNull()?.toChatRoom()
                ?: throw IllegalStateException("Room creation failed")
        }
    }

    override suspend fun getMessages(
        roomId: String,
        limit: Int,
        cursor: String?
    ): Result<List<ChatMessage>> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = GetMessagesParams(
            roomId = roomId,
            userId = userId,
            limit = limit,
            cursor = cursor
        )

        val networkResult = rpcClient.call<GetMessagesParams, RoomMessagesResponse>(
            functionName = "get_room_messages",
            params = params,
            config = RPCConfig.default
        ).mapCatching { response ->
            if (!response.success) {
                throw IllegalStateException(response.error ?: "Failed to get messages")
            }
            response.messages.map { it.toDomain() }
        }

        // Cache first page of messages per room
        return if (cursor == null) {
            try {
                val cached = networkResult.withCache(
                    cache = offlineCache,
                    key = CacheKeys.chatMessages(roomId),
                    ttlMs = OfflineCache.LONG_TTL_MS,
                    serialize = { messages ->
                        json.encodeToString(ListSerializer(ChatMessage.serializer()), messages)
                    },
                    deserialize = { jsonStr ->
                        json.decodeFromString(ListSerializer(ChatMessage.serializer()), jsonStr)
                    }
                )
                Result.success(cached.data)
            } catch (e: Exception) {
                Result.failure(e)
            }
        } else {
            networkResult
        }
    }

    override suspend fun sendMessage(
        roomId: String,
        content: String,
        messageType: MessageType
    ): Result<ChatMessage> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = SendMessageParams(
            roomId = roomId,
            senderId = userId,
            content = content,
            messageType = messageType.name.lowercase()
        )

        return rpcClient.call<SendMessageParams, SendMessageResponse>(
            functionName = "send_message",
            params = params,
            config = RPCConfig.default
        ).mapCatching { response ->
            if (!response.success || response.message == null) {
                throw IllegalStateException(response.error ?: "Failed to send message")
            }
            response.message.toDomain()
        }
    }

    override suspend fun markAsRead(roomId: String): Result<Unit> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = MarkReadParams(roomId = roomId, userId = userId)

        return rpcClient.call<MarkReadParams, MarkReadResponse>(
            functionName = "mark_messages_read",
            params = params,
            config = RPCConfig.default
        ).map { }
    }

    override fun observeMessages(roomId: String): Flow<ChatMessage> {
        val filter = RealtimeFilter(
            table = "messages",
            filter = "room_id=eq.$roomId"
        )

        return kotlinx.coroutines.flow.flow {
            realtimeManager.subscribe<ChatMessageDto>(filter)
                .collect { change ->
                    change.currentRecord()?.toDomain()?.let { emit(it) }
                }
        }
    }

    override fun observeTyping(roomId: String): Flow<TypingIndicator> {
        // Typing indicators would use Supabase Presence or a separate table
        // For now, return empty flow
        return kotlinx.coroutines.flow.emptyFlow()
    }

    override suspend fun sendTypingIndicator(roomId: String, isTyping: Boolean) {
        // Would broadcast to Supabase Presence channel
    }

    override fun observeUnreadCount(): Flow<Int> = _unreadCount.asStateFlow()

    override suspend fun getUnreadCount(): Result<Int> {
        return runCatching {
            val userId = currentUserId ?: return@runCatching 0
            
            supabaseClient.from("chat_rooms")
                .select {
                    filter {
                        or {
                            eq("user1_id", userId)
                            eq("user2_id", userId)
                        }
                        gt("unread_count", 0)
                    }
                }
                .decodeList<Map<String, Int>>()
                .sumOf { it["unread_count"] ?: 0 }
        }
    }

    override suspend fun setRoomMuted(roomId: String, muted: Boolean): Result<Unit> {
        return runCatching {
            supabaseClient.from("room_members")
                .update({
                    set("is_muted", muted)
                }) {
                    filter {
                        eq("room_id", roomId)
                        currentUserId?.let { eq("profile_id", it) }
                    }
                }
        }
    }

    override suspend fun setRoomPinned(roomId: String, pinned: Boolean): Result<Unit> {
        return runCatching {
            supabaseClient.from("room_members")
                .update({
                    set("is_pinned", pinned)
                }) {
                    filter {
                        eq("room_id", roomId)
                        currentUserId?.let { eq("profile_id", it) }
                    }
                }
        }
    }

    override suspend fun archiveRoom(roomId: String): Result<Unit> {
        return runCatching {
            supabaseClient.from("room_members")
                .update({
                    set("is_archived", true)
                }) {
                    filter {
                        eq("room_id", roomId)
                        currentUserId?.let { eq("profile_id", it) }
                    }
                }
        }
    }

    /**
     * Stop all message subscriptions (call on logout or screen exit)
     */
    suspend fun stopObserving() {
        realtimeManager.unsubscribe(RealtimeFilter(table = "messages"))
    }
}

// RPC parameter classes
@Serializable
private data class GetUserRoomsParams(
    @SerialName("p_user_id") val userId: String,
    @SerialName("p_limit") val limit: Int = 20,
    @SerialName("p_offset") val offset: Int = 0,
    @SerialName("p_cursor") val cursor: String? = null,
    @SerialName("p_include_archived") val includeArchived: Boolean = false,
    // Extended params for get_user_rooms
    @SerialName("p_search_query") val searchQuery: String? = null,
    @SerialName("p_filter_type") val filterType: String = "all"
)

@Serializable
private data class GetOrCreateRoomParams(
    @SerialName("p_post_id") val postId: Long,
    @SerialName("p_sharer_id") val sharerId: String,
    @SerialName("p_requester_id") val requesterId: String
)

@Serializable
private data class GetMessagesParams(
    @SerialName("p_room_id") val roomId: String,
    @SerialName("p_user_id") val userId: String,
    @SerialName("p_limit") val limit: Int = 50,
    @SerialName("p_cursor") val cursor: String? = null
)

@Serializable
private data class SendMessageParams(
    @SerialName("p_room_id") val roomId: String,
    @SerialName("p_sender_id") val senderId: String,
    @SerialName("p_content") val content: String,
    @SerialName("p_message_type") val messageType: String = "text"
)

@Serializable
private data class MarkReadParams(
    @SerialName("p_room_id") val roomId: String,
    @SerialName("p_user_id") val userId: String
)

@Serializable
private data class MarkReadResponse(
    val success: Boolean,
    @SerialName("room_id") val roomId: String? = null
)
