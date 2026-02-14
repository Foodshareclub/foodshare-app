//
//  SupabaseMessagingRepository.swift
//  Foodshare
//
//  Supabase implementation of messaging repository with Realtime
//  Updated to match actual database schema (December 2025)
//  Uses centralized RealtimeChannelManager for proper lifecycle management
//  Supports offline-first pattern with CoreData caching
//  Migrated to use ChatAPIService (Edge Functions) for CRUD operations
//

#if !SKIP
import CoreData
#endif
import FoodShareArchitecture
import FoodShareRepository
import Foundation
import OSLog
import Realtime
import Supabase

/// Supabase implementation of messaging repository
/// Uses `rooms` and `room_participants` tables with Realtime subscriptions
/// Thread-safe with @MainActor isolation and centralized channel management
/// Supports offline-first pattern with automatic cache synchronization
/// CRUD operations go through ChatAPIService (Edge Functions)
/// Realtime subscriptions remain on direct Supabase WebSocket
@MainActor
final class SupabaseMessagingRepository: BaseSupabaseRepository, MessagingRepository {
    private let channelManager: RealtimeChannelManager
    private let coreDataStack: CoreDataStack
    private let networkMonitor: NetworkMonitor
    private let pushSender: PushNotificationSender
    private let chatAPI: ChatAPIService

    /// Track current subscription identifiers for cleanup
    private var currentMessageRoomId: UUID?
    private var currentRoomUserId: UUID?

    /// Allowed cursor columns for pagination (SQL injection prevention)
    private static let allowedCursorColumns: Set<String> = ["timestamp", "created_at", "id"]

    /// Cache configuration for messaging
    private let cacheConfiguration = CacheConfiguration(
        maxAge: 1800, // 30 minutes - messages are more time-sensitive
        maxItems: 500,
        syncOnLaunch: true,
        backgroundSync: true,
    )

    init(
        supabase: Supabase.SupabaseClient,
        channelManager: RealtimeChannelManager = .shared,
        coreDataStack: CoreDataStack = .shared,
        networkMonitor: NetworkMonitor = .shared,
        pushSender: PushNotificationSender = .shared,
        chatAPI: ChatAPIService = .shared,
    ) {
        self.channelManager = channelManager
        self.coreDataStack = coreDataStack
        self.networkMonitor = networkMonitor
        self.pushSender = pushSender
        self.chatAPI = chatAPI
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "MessagingRepository")
    }

    // MARK: - Cache Policy Selection

    /// Determines the appropriate cache policy based on network state
    private var currentCachePolicy: CachePolicy {
        if networkMonitor.isOffline {
            .cacheOnly
        } else if networkMonitor.isConstrained {
            .cacheFirst
        } else {
            .cacheFallback
        }
    }

    /// Validates cursor column to prevent SQL injection
    private func validateCursorColumn(_ column: String) throws {
        guard Self.allowedCursorColumns.contains(column) else {
            throw AppError.validationError("Invalid cursor column: \(column)")
        }
    }

    // MARK: - DTO Mapping Helpers

    /// Map ChatRoomDTO from Edge Function to Room domain object
    private func mapRoomDTO(_ dto: ChatRoomDTO) -> Room {
        Room(
            id: dto.id,
            postId: dto.postId ?? 0,
            sharer: dto.otherParticipant?.id ?? UUID(),
            requester: UUID(),
            lastMessage: dto.lastMessage,
            lastMessageTime: dto.lastMessageTime,
            lastMessageSentBy: nil,
            lastMessageSeenBy: nil,
            postArrangedTo: dto.isArranged == true ? UUID() : nil,
            emailTo: nil,
        )
    }

    /// Map ChatRoomDetailDTO from Edge Function to Room domain object
    private func mapRoomDetailDTO(_ dto: ChatRoomDetailDTO) -> Room {
        Room(
            id: dto.id,
            postId: dto.postId ?? 0,
            sharer: dto.otherParticipant?.id ?? UUID(),
            requester: UUID(),
            lastMessage: dto.lastMessage,
            lastMessageTime: dto.lastMessageTime,
            lastMessageSentBy: nil,
            lastMessageSeenBy: nil,
            postArrangedTo: dto.isArranged == true ? UUID() : nil,
            emailTo: nil,
        )
    }

    /// Map ChatMessageDTO from Edge Function to Message domain object
    private func mapMessageDTO(_ dto: ChatMessageDTO) -> Message {
        Message(
            id: dto.id,
            roomId: dto.roomId,
            profileId: dto.senderId ?? UUID(),
            text: dto.text ?? "",
            image: dto.image,
            timestamp: dto.timestamp ?? Date(),
        )
    }

    // MARK: - Rooms

    /// Fetch rooms with offline-first support and request deduplication
    func fetchRooms(userId: UUID) async throws -> [Room] {
        // Deduplicate concurrent room fetches for the same user
        do {
            return try await RequestDeduplicator.shared.deduplicate(key: "rooms-\(userId.uuidString)") {
                let result = try await self.fetchRoomsOfflineFirst(userId: userId)
                return result.items
            }
        } catch let error as DeduplicationError where error.isDeduplicated {
            // Request already in flight - wait briefly and fetch directly
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            let result = try await fetchRoomsOfflineFirst(userId: userId)
            return result.items
        }
    }

    /// Offline-first fetch for rooms with cache policy awareness
    /// Uses ChatAPIService (Edge Function) for remote fetch
    func fetchRoomsOfflineFirst(userId: UUID) async throws -> OfflineDataResult<Room> {
        let dataSource = OfflineFirstDataSource<Room, Room>(
            configuration: cacheConfiguration,
            fetchLocal: { [coreDataStack] in
                try await coreDataStack.fetchCachedRooms(for: userId)
            },
            fetchRemote: { [chatAPI, weak self] in
                do {
                    let dtos = try await chatAPI.getRooms(mode: "food")
                    guard let self else { return [] }
                    return dtos.map { self.mapRoomDTO($0) }
                } catch {
                    // Fallback to direct Supabase query if Edge Function fails
                    guard let self else { throw error }
                    self.logger.warning("Edge Function getRooms failed, falling back to direct query: \(error.localizedDescription)")
                    let response = try await self.supabase
                        .from("rooms")
                        .select()
                        .or("sharer.eq.\(userId.uuidString),requester.eq.\(userId.uuidString)")
                        .order("last_message_time", ascending: false)
                        .execute()
                    return try self.decoder.decode([Room].self, from: response.data)
                }
            },
            saveToCache: { [coreDataStack] rooms in
                try await coreDataStack.cacheRooms(rooms, for: userId)
            },
        )

        return try await dataSource.fetch(policy: currentCachePolicy)
    }

    /// Fetch a single room by ID via Edge Function
    func fetchRoom(id: UUID) async throws -> Room {
        do {
            let response = try await chatAPI.getRoom(roomId: id.uuidString, mode: "food")
            return mapRoomDetailDTO(response.room)
        } catch {
            // Fallback to direct Supabase query
            logger.warning("Edge Function getRoom failed, falling back to direct query: \(error.localizedDescription)")
            return try await fetchOne(from: "rooms", id: id.hashValue)
        }
    }

    /// Create a room via Edge Function with client-side blocking check
    func createRoom(postId: Int, sharerId: UUID, requesterId: UUID) async throws -> Room {
        // Client-side blocking check (defense-in-depth)
        let currentUserId = requesterId
        let otherUserId = sharerId

        // Check if users have blocked each other
        let isBlocked = try await isUserBlocked(userId: currentUserId, targetUserId: otherUserId)
        if isBlocked {
            throw AppError.validationError("Cannot create room with blocked user")
        }

        do {
            let request = CreateFoodRoomRequest(
                postId: postId,
                sharerId: sharerId.uuidString,
                initialMessage: nil,
            )
            let response = try await chatAPI.createFoodRoom(request)

            // Fetch the created/found room to get full details
            let roomDetail = try await chatAPI.getFoodRoom(roomId: response.roomId.uuidString)
            return mapRoomDetailDTO(roomDetail.room)
        } catch {
            // Fallback to direct RPC
            logger.warning("Edge Function createFoodRoom failed, falling back to RPC: \(error.localizedDescription)")
            let params = GetOrCreateRoomParams(
                pPostId: postId,
                pSharerId: sharerId,
                pRequesterId: requesterId,
            )
            let dto: RoomDTO = try await executeRPC("get_or_create_room", params: params)
            return dto.toRoom()
        }
    }

    func findRoom(postId: Int, sharerId: UUID, requesterId: UUID) async throws -> Room? {
        let rooms: [Room] = try await supabase
            .from("rooms")
            .select()
            .eq("post_id", value: postId)
            .eq("sharer", value: sharerId.uuidString)
            .eq("requester", value: requesterId.uuidString)
            .limit(1)
            .execute()
            .value

        return rooms.first
    }

    /// Fetch rooms with filtering via Edge Function, fallback to direct query
    func fetchRoomsFiltered(
        userId: UUID,
        searchQuery: String?,
        filterType: String,
        limit: Int,
    ) async throws -> RoomsFilteredResult {
        do {
            let dtos = try await chatAPI.getRooms(mode: "food", limit: limit)
            let rooms = dtos.map { mapRoomDTO($0) }

            // Client-side filtering since the Edge Function returns all rooms
            let filteredRooms: [Room]
            switch filterType {
            case "unread":
                filteredRooms = rooms.filter { room in
                    room.hasUnreadMessages(for: userId)
                }
            case "sharing":
                filteredRooms = rooms.filter { $0.sharer == userId }
            case "receiving":
                filteredRooms = rooms.filter { $0.requester == userId }
            default:
                filteredRooms = rooms
            }

            // Apply search query if provided
            let searchedRooms: [Room]
            if let searchQuery, !searchQuery.isEmpty {
                searchedRooms = filteredRooms.filter { room in
                    room.lastMessage?.localizedCaseInsensitiveContains(searchQuery) == true
                }
            } else {
                searchedRooms = filteredRooms
            }

            let limitedRooms = Array(searchedRooms.prefix(limit))
            let unreadCount = rooms.filter { $0.hasUnreadMessages(for: userId) }.count

            logger.info("Fetched \(limitedRooms.count) rooms via API (filter: \(filterType), unread: \(unreadCount))")

            return RoomsFilteredResult(
                rooms: limitedRooms,
                totalCount: searchedRooms.count,
                unreadCount: unreadCount,
                hasMore: searchedRooms.count > limit,
            )
        } catch {
            logger.warning("Edge Function getRooms failed, falling back to direct query: \(error.localizedDescription)")
            return try await fetchRoomsFilteredDirect(userId: userId, filterType: filterType, limit: limit)
        }
    }

    /// Direct query fallback for filtered rooms when Edge Function is unavailable
    private func fetchRoomsFilteredDirect(
        userId: UUID,
        filterType: String,
        limit: Int,
    ) async throws -> RoomsFilteredResult {
        var query = supabase
            .from("rooms")
            .select()
            .or("sharer.eq.\(userId.uuidString),requester.eq.\(userId.uuidString)")

        if filterType == "unread" {
            query = query
                .neq("last_message_sent_by", value: userId.uuidString)
                .neq("last_message_seen_by", value: userId.uuidString)
        }

        let response = try await query
            .order("last_message_time", ascending: false)
            .limit(limit)
            .execute()

        let rooms = try decoder.decode([Room].self, from: response.data)

        let unreadQuery = try await supabase
            .from("rooms")
            .select("id", head: true, count: .exact)
            .or("sharer.eq.\(userId.uuidString),requester.eq.\(userId.uuidString)")
            .neq("last_message_sent_by", value: userId.uuidString)
            .neq("last_message_seen_by", value: userId.uuidString)
            .execute()

        let unreadCount = unreadQuery.count ?? 0

        logger.info("Rooms fallback returned \(rooms.count) rooms (unread: \(unreadCount))")

        return RoomsFilteredResult(
            rooms: rooms,
            totalCount: rooms.count,
            unreadCount: unreadCount,
            hasMore: rooms.count >= limit,
        )
    }

    // MARK: - Messages

    /// Fetch messages with cursor-based pagination (kept as direct query for pagination support)
    func fetchMessages(roomId: UUID, pagination: CursorPaginationParams) async throws -> [Message] {
        // Validate cursor column to prevent SQL injection
        try validateCursorColumn(pagination.cursorColumn)

        var query = supabase
            .from("room_participants")
            .select()
            .eq("room_id", value: roomId.uuidString)

        // Apply cursor-based pagination (ideal for chat history)
        if let cursor = pagination.cursor {
            let comparison = pagination.direction == .backward ? "lt" : "gt"
            query = query.filter(pagination.cursorColumn, operator: comparison, value: cursor)
        }

        // For chat, backward direction = older messages, forward = newer
        // We typically want oldest-first display, so we order accordingly
        let ascending = pagination.direction == .forward

        let response = try await query
            .order(pagination.cursorColumn, ascending: ascending)
            .limit(pagination.limit)
            .execute()

        return try decoder.decode([Message].self, from: response.data)
    }

    func fetchMessages(roomId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [Message] {
        let result = try await fetchMessagesOfflineFirst(roomId: roomId, limit: limit, offset: offset)
        return result.items
    }

    /// Offline-first fetch for messages with cache policy awareness
    /// Uses Edge Function for remote fetch, direct Supabase as fallback
    func fetchMessagesOfflineFirst(
        roomId: UUID,
        limit: Int = 50,
        offset: Int = 0,
    ) async throws -> OfflineDataResult<Message> {
        let dataSource = OfflineFirstDataSource<Message, Message>(
            configuration: cacheConfiguration,
            fetchLocal: { [coreDataStack] in
                try await coreDataStack.fetchCachedMessages(for: roomId, limit: limit, offset: offset)
            },
            fetchRemote: { [chatAPI, weak self] in
                do {
                    let response = try await chatAPI.getFoodRoom(roomId: roomId.uuidString, limit: limit)
                    guard let self else { return [] }
                    return response.messages.map { self.mapMessageDTO($0) }
                } catch {
                    // Fallback to direct Supabase query if Edge Function fails
                    guard let self else { throw error }
                    self.logger.warning("Edge Function getFoodRoom messages failed, falling back to direct query: \(error.localizedDescription)")
                    let response = try await self.supabase
                        .from("room_participants")
                        .select()
                        .eq("room_id", value: roomId.uuidString)
                        .order("timestamp", ascending: true)
                        .range(from: offset, to: offset + limit - 1)
                        .execute()
                    return try self.decoder.decode([Message].self, from: response.data)
                }
            },
            saveToCache: { [coreDataStack] messages in
                try await coreDataStack.cacheMessages(messages, for: roomId)
            },
        )

        return try await dataSource.fetch(policy: currentCachePolicy)
    }

    /// Send a message via Edge Function with client-side blocking check
    func sendMessage(roomId: UUID, profileId: UUID, text: String, image: String? = nil) async throws -> Message {
        // Client-side blocking check (defense-in-depth)
        let room = try await fetchRoom(id: roomId)
        let otherUserId = room.sharer == profileId ? room.requester : room.sharer

        let isBlocked = try await isUserBlocked(userId: profileId, targetUserId: otherUserId)
        if isBlocked {
            throw AppError.validationError("Cannot send message to blocked user")
        }

        do {
            let request = SendFoodMessageRequest(
                roomId: roomId.uuidString,
                text: text,
                image: image,
            )
            let dto = try await chatAPI.sendFoodMessage(request)
            let message = mapMessageDTO(dto)

            // Send push notification to recipient (non-blocking)
            Task {
                await sendMessagePushNotification(
                    roomId: roomId,
                    senderId: profileId,
                    messageText: text,
                )
            }

            return message
        } catch {
            // Fallback to direct Supabase insert
            logger.warning("Edge Function sendFoodMessage failed, falling back to direct insert: \(error.localizedDescription)")

            let params = SendMessageParams(roomId: roomId, profileId: profileId, text: text, image: image ?? "")

            let response = try await supabase
                .from("room_participants")
                .insert(params)
                .select()
                .single()
                .execute()

            let message = try decoder.decode(Message.self, from: response.data)
            try await updateRoomLastMessage(roomId: roomId, message: text, sentBy: profileId)

            // Send push notification to recipient (non-blocking)
            Task {
                await sendMessagePushNotification(
                    roomId: roomId,
                    senderId: profileId,
                    messageText: text,
                )
            }

            return message
        }
    }

    /// Send push notification for new message
    private func sendMessagePushNotification(
        roomId: UUID,
        senderId: UUID,
        messageText: String,
    ) async {
        do {
            // Fetch room to get recipient
            let room = try await fetchRoom(id: roomId)

            // Determine recipient (the one who isn't the sender)
            let recipientId = room.sharer == senderId ? room.requester : room.sharer

            // Truncate message preview
            let preview = messageText.count > 50
                ? String(messageText.prefix(47)) + "..."
                : messageText

            try await pushSender.sendNotification(
                to: [recipientId],
                title: "New Message",
                body: preview,
                type: .newMessage,
                data: ["roomId": roomId.uuidString],
            )
        } catch {
            // Log but don't fail message send
            logger.warning("Failed to send push notification: \(error.localizedDescription)")
        }
    }

    /// Mark messages as seen - kept as direct Supabase update (simple operation)
    func markMessagesSeen(roomId: UUID, userId: UUID) async throws {
        try await supabase
            .from("rooms")
            .update(["last_message_seen_by": userId.uuidString])
            .eq("id", value: roomId.uuidString)
            .execute()
    }

    // MARK: - Real-time (Unchanged - uses Supabase Realtime WebSocket)

    func subscribeToMessages(roomId: UUID, onMessage: @escaping @Sendable (Message) -> Void) async throws {
        let table = "room_participants"
        let filter = "room_id=eq.\(roomId.uuidString)"
        let channelName = "room_participants:\(roomId.uuidString)"

        // Clean up previous subscription if different room
        if let previousRoomId = currentMessageRoomId, previousRoomId != roomId {
            await unsubscribeFromMessagesAsync()
        }

        // Check if already subscribed
        if await channelManager.existingChannel(table: table, filter: filter) != nil {
            logger.debug("Already subscribed to messages for room: \(roomId.uuidString)")
            return
        }

        let channel = supabase.realtimeV2.channel(channelName)

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: table,
            filter: filter,
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            logger.error("Failed to subscribe to messages channel: \(error.localizedDescription)")
        }

        // Register with centralized manager
        await channelManager.register(channel: channel, table: table, filter: filter)
        currentMessageRoomId = roomId

        logger.info("Subscribed to messages for room: \(roomId.uuidString)")

        Task { [decoder, weak self] in
            for await insertion in insertions {
                do {
                    let message = try insertion.decodeRecord(as: Message.self, decoder: decoder)
                    await MainActor.run { onMessage(message) }
                } catch {
                    self?.logger.error("Failed to decode message: \(error.localizedDescription)")
                }
            }
        }
    }

    func unsubscribeFromMessages() {
        Task { await unsubscribeFromMessagesAsync() }
    }

    private func unsubscribeFromMessagesAsync() async {
        if let roomId = currentMessageRoomId {
            let filter = "room_id=eq.\(roomId.uuidString)"
            await channelManager.unregister(table: "room_participants", filter: filter)
            currentMessageRoomId = nil
            logger.info("Unsubscribed from messages for room: \(roomId.uuidString)")
        }
    }

    func subscribeToRoomUpdates(userId: UUID, onUpdate: @escaping @Sendable (Room) -> Void) async throws {
        let table = "rooms"
        let filter: String? = nil // Rooms filter by userId in callback
        let channelName = "rooms:\(userId.uuidString)"

        // Clean up previous subscription if different user
        if let previousUserId = currentRoomUserId, previousUserId != userId {
            await unsubscribeFromRoomUpdatesAsync()
        }

        // Check if already subscribed
        if await channelManager.existingChannel(table: table, filter: "user:\(userId.uuidString)") != nil {
            logger.debug("Already subscribed to room updates for user: \(userId.uuidString)")
            return
        }

        let channel = supabase.realtimeV2.channel(channelName)

        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: table,
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            logger.error("Failed to subscribe to room updates channel: \(error.localizedDescription)")
        }

        // Register with a user-specific filter identifier
        await channelManager.register(channel: channel, table: table, filter: "user:\(userId.uuidString)")
        currentRoomUserId = userId

        logger.info("Subscribed to room updates for user: \(userId.uuidString)")

        Task { [decoder, weak self] in
            for await update in updates {
                do {
                    let room = try update.decodeRecord(as: Room.self, decoder: decoder)
                    if room.sharer == userId || room.requester == userId {
                        await MainActor.run { onUpdate(room) }
                    }
                } catch {
                    self?.logger.error("Failed to decode room: \(error.localizedDescription)")
                }
            }
        }
    }

    func unsubscribeFromRoomUpdates() {
        Task { await unsubscribeFromRoomUpdatesAsync() }
    }

    private func unsubscribeFromRoomUpdatesAsync() async {
        if let userId = currentRoomUserId {
            await channelManager.unregister(table: "rooms", filter: "user:\(userId.uuidString)")
            currentRoomUserId = nil
            logger.info("Unsubscribed from room updates for user: \(userId.uuidString)")
        }
    }

    /// Cleanup all messaging subscriptions
    func cleanup() async {
        await unsubscribeFromMessagesAsync()
        await unsubscribeFromRoomUpdatesAsync()
    }

    // MARK: - Blocking Helper

    /// Check if user has blocked target user (queries blocked_users directly)
    private func isUserBlocked(userId: UUID, targetUserId: UUID) async throws -> Bool {
        // Query blocked_users table directly for performance
        let result: [BlockedUserCheck] = try await supabase
            .from("blocked_users")
            .select("id")
            .or("user_id.eq.\(userId.uuidString),user_id.eq.\(targetUserId.uuidString)")
            .or("blocked_user_id.eq.\(userId.uuidString),blocked_user_id.eq.\(targetUserId.uuidString)")
            .limit(1)
            .execute()
            .value

        return !result.isEmpty
    }
}

// MARK: - Blocking Check DTO
private struct BlockedUserCheck: Decodable {
    let id: UUID
}

extension SupabaseMessagingRepository {
    /// Update room last message via RPC (kept as direct - needs server-side NOW())
    private func updateRoomLastMessage(roomId: UUID, message: String, sentBy: UUID) async throws {
        // Use RPC to ensure server-side timestamp (NOW())
        let params = UpdateRoomMessageParams(
            pRoomId: roomId,
            pMessage: message,
            pSentBy: sentBy,
        )

        try await self.executeRPC("update_room_last_message", params: params)
    }
}

// MARK: - Parameter Structs

/// Parameters for the get_or_create_room RPC (fallback)
private struct GetOrCreateRoomParams: Encodable, Sendable {
    let pPostId: Int
    let pSharerId: UUID
    let pRequesterId: UUID

    enum CodingKeys: String, CodingKey {
        case pPostId = "p_post_id"
        case pSharerId = "p_sharer_id"
        case pRequesterId = "p_requester_id"
    }
}

/// DTO for decoding the get_or_create_room RPC response (fallback)
private struct RoomDTO: Decodable {
    let id: UUID
    let postId: Int
    let sharer: UUID
    let requester: UUID
    let lastMessage: String?
    let lastMessageTime: Date?
    let lastMessageSentBy: UUID?
    let lastMessageSeenBy: UUID?
    let postArrangedTo: UUID?
    let emailTo: String?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case sharer
        case requester
        case lastMessage = "last_message"
        case lastMessageTime = "last_message_time"
        case lastMessageSentBy = "last_message_sent_by"
        case lastMessageSeenBy = "last_message_seen_by"
        case postArrangedTo = "post_arranged_to"
        case emailTo = "email_to"
    }

    func toRoom() -> Room {
        Room(
            id: id,
            postId: postId,
            sharer: sharer,
            requester: requester,
            lastMessage: lastMessage,
            lastMessageTime: lastMessageTime,
            lastMessageSentBy: lastMessageSentBy,
            lastMessageSeenBy: lastMessageSeenBy,
            postArrangedTo: postArrangedTo,
            emailTo: emailTo,
        )
    }
}

/// Parameters for direct message insert (fallback)
private struct SendMessageParams: Encodable, Sendable {
    let roomId: UUID
    let profileId: UUID
    let text: String
    let image: String

    enum CodingKeys: String, CodingKey {
        case roomId = "room_id"
        case profileId = "profile_id"
        case text
        case image
    }
}

/// Parameters for the update_room_last_message RPC
private struct UpdateRoomMessageParams: Encodable, Sendable {
    let pRoomId: UUID
    let pMessage: String
    let pSentBy: UUID

    enum CodingKeys: String, CodingKey {
        case pRoomId = "p_room_id"
        case pMessage = "p_message"
        case pSentBy = "p_sent_by"
    }
}
