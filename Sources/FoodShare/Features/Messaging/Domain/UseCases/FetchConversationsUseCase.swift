//
//  FetchConversationsUseCase.swift
//  Foodshare
//
//  Use case for fetching user rooms/conversations
//  Updated to match actual database schema (December 2025)
//


#if !SKIP
import Foundation

/// Use case for fetching user's chat rooms
@MainActor
final class FetchRoomsUseCase {
    private let repository: MessagingRepository

    init(repository: MessagingRepository) {
        self.repository = repository
    }

    /// Fetch all rooms for a user
    func execute(userId: UUID) async throws -> [Room] {
        try await repository.fetchRooms(userId: userId)
    }
}

/// Use case for fetching messages in a room
@MainActor
final class FetchMessagesUseCase {
    private let repository: MessagingRepository

    init(repository: MessagingRepository) {
        self.repository = repository
    }

    /// Fetch messages for a room with pagination
    func execute(roomId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [Message] {
        try await repository.fetchMessages(roomId: roomId, limit: limit, offset: offset)
    }
}

/// Use case for creating or finding a room for a post
@MainActor
final class GetOrCreateRoomUseCase {
    private let repository: MessagingRepository

    init(repository: MessagingRepository) {
        self.repository = repository
    }

    /// Get existing room or create new one for a post
    func execute(postId: Int, sharerId: UUID, requesterId: UUID) async throws -> Room {
        // Don't allow creating room with yourself
        guard sharerId != requesterId else {
            throw MessagingError.cannotMessageSelf
        }

        return try await repository.createRoom(postId: postId, sharerId: sharerId, requesterId: requesterId)
    }
}

// MARK: - Legacy Compatibility

/// Legacy type alias for backward compatibility
typealias FetchConversationsUseCase = FetchRoomsUseCase

#endif
