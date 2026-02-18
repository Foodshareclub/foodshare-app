//
//  MessagingRepository.swift
//  Foodshare
//
//  Messaging repository protocol
//  Updated to match actual database schema (December 2025)
//



#if !SKIP
import Foundation

/// Repository protocol for messaging operations
/// Uses `rooms` and `room_participants` tables in Supabase
@MainActor
protocol MessagingRepository: Sendable {
    // MARK: - Rooms

    /// Fetch all rooms for a user (as sharer or requester)
    func fetchRooms(userId: UUID) async throws -> [Room]

    /// Fetch rooms with server-side filtering and sorting (optimized)
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - searchQuery: Optional text search on last message
    ///   - filterType: Filter type: 'all', 'unread', 'sharing', 'receiving'
    ///   - limit: Maximum rooms to return
    /// - Returns: Filtered rooms result with metadata
    func fetchRoomsFiltered(
        userId: UUID,
        searchQuery: String?,
        filterType: String,
        limit: Int,
    ) async throws -> RoomsFilteredResult

    /// Fetch a single room by ID
    func fetchRoom(id: UUID) async throws -> Room

    /// Create a new room for a post
    func createRoom(postId: Int, sharerId: UUID, requesterId: UUID) async throws -> Room

    /// Find existing room for a post between two users
    func findRoom(postId: Int, sharerId: UUID, requesterId: UUID) async throws -> Room?

    // MARK: - Messages

    /// Fetch messages for a room with cursor-based pagination (preferred for chat)
    func fetchMessages(roomId: UUID, pagination: CursorPaginationParams) async throws -> [Message]

    /// Fetch messages for a room with offset pagination (legacy)
    func fetchMessages(roomId: UUID, limit: Int, offset: Int) async throws -> [Message]

    /// Send a message to a room
    func sendMessage(roomId: UUID, profileId: UUID, text: String, image: String?) async throws -> Message

    /// Mark messages as seen
    func markMessagesSeen(roomId: UUID, userId: UUID) async throws

    // MARK: - Real-time

    /// Subscribe to new messages in a room
    func subscribeToMessages(roomId: UUID, onMessage: @escaping @Sendable (Message) -> Void) async throws

    /// Unsubscribe from message updates
    func unsubscribeFromMessages()

    // MARK: - Room Updates

    /// Subscribe to room updates (last message, seen status)
    func subscribeToRoomUpdates(userId: UUID, onUpdate: @escaping @Sendable (Room) -> Void) async throws

    /// Unsubscribe from room updates
    func unsubscribeFromRoomUpdates()
}

// MARK: - Default Implementations

extension MessagingRepository {
    func findRoom(postId: Int, sharerId: UUID, requesterId: UUID) async throws -> Room? {
        nil // Default implementation returns nil
    }

    func subscribeToRoomUpdates(userId: UUID, onUpdate: @escaping @Sendable (Room) -> Void) async throws {
        // Default no-op implementation
    }

    func unsubscribeFromRoomUpdates() {
        // Default no-op implementation
    }

    func fetchRoomsFiltered(
        userId: UUID,
        searchQuery: String?,
        filterType: String,
        limit: Int,
    ) async throws -> RoomsFilteredResult {
        // Default: fall back to fetchRooms and filter client-side
        let rooms = try await fetchRooms(userId: userId)
        return RoomsFilteredResult(
            rooms: rooms,
            totalCount: rooms.count,
            unreadCount: 0,
            hasMore: false,
        )
    }
}

/// Result from get_user_rooms RPC with server-side filtering
struct RoomsFilteredResult: Sendable {
    let rooms: [Room]
    let totalCount: Int
    let unreadCount: Int
    let hasMore: Bool
}


#endif
