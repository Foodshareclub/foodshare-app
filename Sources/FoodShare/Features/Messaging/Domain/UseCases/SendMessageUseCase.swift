//
//  SendMessageUseCase.swift
//  Foodshare
//
//  Use case for sending messages
//  Updated to match actual database schema (December 2025)
//

import Foundation

/// Use case for sending messages in a room
@MainActor
final class SendMessageUseCase {
    private let repository: MessagingRepository

    init(repository: MessagingRepository) {
        self.repository = repository
    }

    /// Send a text message to a room
    func execute(roomId: UUID, profileId: UUID, text: String, image: String? = nil) async throws -> Message {
        // Validate text content
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedText.isEmpty || image != nil else {
            throw MessagingError.emptyMessage
        }

        guard trimmedText.count <= 2000 else {
            throw MessagingError.messageTooLong
        }

        return try await repository.sendMessage(
            roomId: roomId,
            profileId: profileId,
            text: trimmedText,
            image: image,
        )
    }
}

/// Use case for marking messages as seen
@MainActor
final class MarkMessagesSeenUseCase {
    private let repository: MessagingRepository

    init(repository: MessagingRepository) {
        self.repository = repository
    }

    /// Mark all messages in a room as seen by user
    func execute(roomId: UUID, userId: UUID) async throws {
        try await repository.markMessagesSeen(roomId: roomId, userId: userId)
    }
}

// MARK: - Messaging Errors

/// Errors that can occur during messaging operations.
///
/// Thread-safe for Swift 6 concurrency.
enum MessagingError: LocalizedError, Sendable {
    /// Message content is empty
    case emptyMessage
    /// Message exceeds maximum length
    case messageTooLong
    /// Chat room doesn't exist
    case roomNotFound
    /// User attempted to message themselves
    case cannotMessageSelf
    /// User lacks permission for this action
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            "Message cannot be empty"
        case .messageTooLong:
            "Message is too long (max 2000 characters)"
        case .roomNotFound:
            "Chat room not found"
        case .cannotMessageSelf:
            "You cannot message yourself"
        case .unauthorized:
            "You are not authorized to send messages in this room"
        }
    }
}
