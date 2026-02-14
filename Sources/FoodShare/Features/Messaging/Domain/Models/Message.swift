//
//  Message.swift
//  Foodshare
//
//  Message domain model - Maps to `room_participants` table in Supabase
//  Updated to match actual database schema (December 2025)
//

import Foundation

/// Represents a chat message in a room
/// Maps to `room_participants` table in Supabase
struct Message: Codable, Identifiable, Sendable, Hashable {
    let id: UUID // UUID primary key
    let roomId: UUID? // room_id (FK to rooms)
    let profileId: UUID // profile_id (sender)
    let text: String // text content
    let image: String? // optional image URL
    let timestamp: Date // timestamp

    enum CodingKeys: String, CodingKey {
        case id
        case roomId = "room_id"
        case profileId = "profile_id"
        case text
        case image
        case timestamp
    }

    // MARK: - Computed Properties

    var hasImage: Bool {
        guard let image else { return false }
        return !image.isEmpty
    }

    var imageURL: URL? {
        guard let image, !image.isEmpty else { return nil }
        return URL(string: image)
    }
}

/// Represents a chat room/conversation
/// Maps to `rooms` table in Supabase
struct Room: Codable, Identifiable, Sendable, Hashable {
    let id: UUID // UUID primary key
    let postId: Int // post_id (FK to posts)
    let sharer: UUID // sharer (post owner)
    let requester: UUID // requester (person requesting)
    let lastMessage: String? // last_message preview
    let lastMessageTime: Date? // last_message_time
    let lastMessageSentBy: UUID? // last_message_sent_by
    let lastMessageSeenBy: UUID? // last_message_seen_by
    let postArrangedTo: UUID? // post_arranged_to
    let emailTo: String? // email_to

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

    // MARK: - Computed Properties

    /// Check if current user has unread messages
    func hasUnreadMessages(for userId: UUID) -> Bool {
        guard let lastMessageSentBy, let lastMessageSeenBy else { return false }
        return lastMessageSentBy != userId && lastMessageSeenBy != userId
    }

    /// Get the other participant's ID
    func otherParticipant(currentUserId: UUID) -> UUID {
        currentUserId == sharer ? requester : sharer
    }

    /// Check if post has been arranged
    var isArranged: Bool {
        postArrangedTo != nil
    }
}

/// Room with additional post and profile info for display
struct RoomWithDetails: Identifiable, Sendable {
    let room: Room
    let post: FoodItem?
    let otherUserProfile: UserProfile?

    var id: UUID { room.id }

    var displayName: String {
        otherUserProfile?.nickname ?? "Unknown User"
    }

    var displayAvatar: String? {
        otherUserProfile?.avatarUrl
    }

    var postTitle: String {
        post?.postName ?? "Unknown Post"
    }
}

// MARK: - Legacy Compatibility

/// Legacy conversation type alias for backward compatibility
typealias Conversation = Room

enum ConversationStatus: String, Codable, Sendable {
    case active
    case archived
    case blocked
}

// MARK: - Test Fixtures

#if DEBUG

    extension Message {
        static func fixture(
            id: UUID = UUID(),
            roomId: UUID? = UUID(),
            profileId: UUID = UUID(),
            text: String = "Hi, is this still available?",
            image: String? = nil,
            timestamp: Date = Date(),
        ) -> Message {
            Message(
                id: id,
                roomId: roomId,
                profileId: profileId,
                text: text,
                image: image,
                timestamp: timestamp,
            )
        }

        static let sampleMessages: [Message] = [
            .fixture(text: "Hi, is this still available?"),
            .fixture(text: "Yes! When can you pick it up?"),
            .fixture(text: "I can come by this afternoon around 3pm"),
            .fixture(text: "Perfect, see you then!")
        ]
    }

    extension Room {
        static func fixture(
            id: UUID = UUID(),
            postId: Int = 1,
            sharer: UUID = UUID(),
            requester: UUID = UUID(),
            lastMessage: String? = "See you then!",
            lastMessageTime: Date? = Date(),
            lastMessageSentBy: UUID? = nil,
            lastMessageSeenBy: UUID? = nil,
            postArrangedTo: UUID? = nil,
            emailTo: String? = nil,
        ) -> Room {
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

        static let sampleRooms: [Room] = [
            .fixture(lastMessage: "Thanks for sharing!"),
            .fixture(lastMessage: "When can I pick it up?"),
            .fixture(lastMessage: "See you tomorrow")
        ]
    }

#endif
