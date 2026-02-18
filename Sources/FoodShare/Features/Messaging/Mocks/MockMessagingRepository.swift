//
//  MockMessagingRepository.swift
//  Foodshare
//
//  Mock implementation of MessagingRepository for testing
//


#if !SKIP
import Foundation

#if DEBUG
/// Mock implementation of MessagingRepository for unit tests
@MainActor
final class MockMessagingRepository: MessagingRepository {
    // MARK: - Test Configuration

    var shouldFail = false
    var delay: TimeInterval = 0

    // MARK: - Mock Data

    var mockRooms: [Room] = Room.sampleRooms
    var mockMessages: [UUID: [Message]] = [:]

    // MARK: - Call Tracking

    private(set) var fetchRoomsCallCount = 0
    private(set) var fetchRoomCallCount = 0
    private(set) var createRoomCallCount = 0
    private(set) var fetchMessagesCallCount = 0
    private(set) var sendMessageCallCount = 0
    private(set) var markMessagesSeenCallCount = 0

    // MARK: - Callbacks

    var onMessageReceived: (@Sendable (Message) -> Void)?
    var onRoomUpdated: (@Sendable (Room) -> Void)?

    // MARK: - MessagingRepository Implementation

    func fetchRooms(userId: UUID) async throws -> [Room] {
        fetchRoomsCallCount += 1

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        return mockRooms.filter { $0.sharer == userId || $0.requester == userId }
    }

    func fetchRoom(id: UUID) async throws -> Room {
        fetchRoomCallCount += 1

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        guard let room = mockRooms.first(where: { $0.id == id }) else {
            throw AppError.notFound(resource: "Room")
        }

        return room
    }

    func createRoom(postId: Int, sharerId: UUID, requesterId: UUID) async throws -> Room {
        createRoomCallCount += 1

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        let room = Room(
            id: UUID(),
            postId: postId,
            sharer: sharerId,
            requester: requesterId,
            lastMessage: nil,
            lastMessageTime: nil,
            lastMessageSentBy: nil,
            lastMessageSeenBy: nil,
            postArrangedTo: nil,
            emailTo: nil
        )

        mockRooms.append(room)
        return room
    }

    func findRoom(postId: Int, sharerId: UUID, requesterId: UUID) async throws -> Room? {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        return mockRooms.first { room in
            room.postId == postId &&
            room.sharer == sharerId &&
            room.requester == requesterId
        }
    }

    func fetchMessages(roomId: UUID, pagination: CursorPaginationParams) async throws -> [Message] {
        fetchMessagesCallCount += 1

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        let messages = mockMessages[roomId] ?? Message.sampleMessages
        return Array(messages.prefix(pagination.limit))
    }

    func fetchMessages(roomId: UUID, limit: Int, offset: Int) async throws -> [Message] {
        fetchMessagesCallCount += 1

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        let messages = mockMessages[roomId] ?? Message.sampleMessages
        let endIndex = min(offset + limit, messages.count)
        guard offset < messages.count else { return [] }
        return Array(messages[offset..<endIndex])
    }

    func sendMessage(roomId: UUID, profileId: UUID, text: String, image: String?) async throws -> Message {
        sendMessageCallCount += 1

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        let message = Message(
            id: UUID(),
            roomId: roomId,
            profileId: profileId,
            text: text,
            image: image,
            timestamp: Date()
        )

        if mockMessages[roomId] == nil {
            mockMessages[roomId] = []
        }
        mockMessages[roomId]?.append(message)

        return message
    }

    func markMessagesSeen(roomId: UUID, userId: UUID) async throws {
        markMessagesSeenCallCount += 1

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        // Update mock room's lastMessageSeenBy
        if let index = mockRooms.firstIndex(where: { $0.id == roomId }) {
            let oldRoom = mockRooms[index]
            mockRooms[index] = Room(
                id: oldRoom.id,
                postId: oldRoom.postId,
                sharer: oldRoom.sharer,
                requester: oldRoom.requester,
                lastMessage: oldRoom.lastMessage,
                lastMessageTime: oldRoom.lastMessageTime,
                lastMessageSentBy: oldRoom.lastMessageSentBy,
                lastMessageSeenBy: userId,
                postArrangedTo: oldRoom.postArrangedTo,
                emailTo: oldRoom.emailTo
            )
        }
    }

    func subscribeToMessages(roomId: UUID, onMessage: @escaping @Sendable (Message) -> Void) async throws {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        onMessageReceived = onMessage
    }

    func unsubscribeFromMessages() {
        onMessageReceived = nil
    }

    func subscribeToRoomUpdates(userId: UUID, onUpdate: @escaping @Sendable (Room) -> Void) async throws {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        onRoomUpdated = onUpdate
    }

    func unsubscribeFromRoomUpdates() {
        onRoomUpdated = nil
    }

    // MARK: - Test Helpers

    func reset() {
        shouldFail = false
        delay = 0
        mockRooms = Room.sampleRooms
        mockMessages = [:]
        fetchRoomsCallCount = 0
        fetchRoomCallCount = 0
        createRoomCallCount = 0
        fetchMessagesCallCount = 0
        sendMessageCallCount = 0
        markMessagesSeenCallCount = 0
        onMessageReceived = nil
        onRoomUpdated = nil
    }

    /// Simulate receiving a new message (for testing real-time updates)
    func simulateNewMessage(_ message: Message) {
        onMessageReceived?(message)
    }

    /// Simulate room update (for testing real-time updates)
    func simulateRoomUpdate(_ room: Room) {
        onRoomUpdated?(room)
    }
}
#endif

#endif
