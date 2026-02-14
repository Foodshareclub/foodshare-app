//
//  UserNotification.swift
//  Foodshare
//
//  User notification model for in-app notification center
//

import Foundation

// MARK: - Notification Type

enum NotificationType: String, Codable, Sendable, CaseIterable {
    case newMessage = "new_message"
    case arrangementRequest = "arrangement_request"
    case arrangementConfirmed = "arrangement_confirmed"
    case arrangementCancelled = "arrangement_cancelled"
    case newListingNearby = "new_listing_nearby"
    case reviewReceived = "review_received"
    case reviewReminder = "review_reminder"
    case challengeCompleted = "challenge_completed"
    case forumReply = "forum_reply"
    case system

    var icon: String {
        switch self {
        case .newMessage: "message.fill"
        case .arrangementRequest: "hand.raised.fill"
        case .arrangementConfirmed: "checkmark.circle.fill"
        case .arrangementCancelled: "xmark.circle.fill"
        case .newListingNearby: "leaf.fill"
        case .reviewReceived: "star.fill"
        case .reviewReminder: "star.leadinghalf.filled"
        case .challengeCompleted: "trophy.fill"
        case .forumReply: "bubble.left.and.bubble.right.fill"
        case .system: "bell.fill"
        }
    }

    var color: String {
        switch self {
        case .newMessage: "brandBlue"
        case .arrangementRequest: "purple"
        case .arrangementConfirmed: "brandGreen"
        case .arrangementCancelled: "error"
        case .newListingNearby: "orange"
        case .reviewReceived: "yellow"
        case .reviewReminder: "yellow"
        case .challengeCompleted: "brandGreen"
        case .forumReply: "teal"
        case .system: "textSecondary"
        }
    }
}

// MARK: - User Notification Model

struct UserNotification: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let recipientId: UUID
    let actorId: UUID?
    let type: NotificationType
    let title: String
    let body: String?
    let postId: Int?
    let roomId: UUID?
    let reviewId: UUID?
    let data: [String: String]?
    var isRead: Bool
    let readAt: Date?
    let createdAt: Date
    let updatedAt: Date?

    // Actor profile (populated via join)
    let actorProfile: ActorProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case actorId = "actor_id"
        case type
        case title
        case body
        case postId = "post_id"
        case roomId = "room_id"
        case reviewId = "review_id"
        case data
        case isRead = "is_read"
        case readAt = "read_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case actorProfile = "actor_profile"
    }

    // MARK: - Custom Decoder (handles nullable database fields)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        recipientId = try container.decode(UUID.self, forKey: .recipientId)
        actorId = try container.decodeIfPresent(UUID.self, forKey: .actorId)
        type = try container.decodeIfPresent(NotificationType.self, forKey: .type) ?? .system
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body)
        postId = try container.decodeIfPresent(Int.self, forKey: .postId)
        roomId = try container.decodeIfPresent(UUID.self, forKey: .roomId)
        reviewId = try container.decodeIfPresent(UUID.self, forKey: .reviewId)
        data = try container.decodeIfPresent([String: String].self, forKey: .data)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
        readAt = try container.decodeIfPresent(Date.self, forKey: .readAt)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        actorProfile = try container.decodeIfPresent(ActorProfile.self, forKey: .actorProfile)
    }

    // MARK: - Memberwise Initializer (for fixtures)

    init(
        id: UUID,
        recipientId: UUID,
        actorId: UUID?,
        type: NotificationType,
        title: String,
        body: String?,
        postId: Int?,
        roomId: UUID?,
        reviewId: UUID?,
        data: [String: String]?,
        isRead: Bool,
        readAt: Date?,
        createdAt: Date,
        updatedAt: Date?,
        actorProfile: ActorProfile?
    ) {
        self.id = id
        self.recipientId = recipientId
        self.actorId = actorId
        self.type = type
        self.title = title
        self.body = body
        self.postId = postId
        self.roomId = roomId
        self.reviewId = reviewId
        self.data = data
        self.isRead = isRead
        self.readAt = readAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.actorProfile = actorProfile
    }

    // MARK: - Computed Properties

    var displayBody: String {
        body ?? ""
    }

    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    var hasDeepLink: Bool {
        postId != nil || roomId != nil || reviewId != nil
    }
}

// MARK: - Actor Profile (Nested)

struct ActorProfile: Codable, Sendable, Equatable {
    let id: UUID
    let nickname: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
    }

    var displayName: String {
        nickname ?? "Foodshare User"
    }
}

// MARK: - Sample Data

extension UserNotification {
    static func fixture(
        id: UUID = UUID(),
        type: NotificationType = .newMessage,
        title: String = "New message",
        body: String? = "Hey! Is this still available?",
        isRead: Bool = false,
    ) -> UserNotification {
        UserNotification(
            id: id,
            recipientId: UUID(),
            actorId: UUID(),
            type: type,
            title: title,
            body: body,
            postId: nil,
            roomId: nil,
            reviewId: nil,
            data: nil,
            isRead: isRead,
            readAt: nil,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: nil,
            actorProfile: ActorProfile(
                id: UUID(),
                nickname: "John D.",
                avatarUrl: nil,
            ),
        )
    }

    static var sampleNotifications: [UserNotification] {
        [
            .fixture(type: .newMessage, title: "New message from Sarah", body: "Is the pasta still available?"),
            .fixture(
                type: .arrangementConfirmed,
                title: "Pickup confirmed!",
                body: "Your request for \"Fresh Vegetables\" has been confirmed",
                isRead: true,
            ),
            .fixture(
                type: .newListingNearby,
                title: "New food nearby!",
                body: "\"Homemade Bread\" is available 0.3 miles away",
            ),
            .fixture(type: .reviewReceived, title: "You received a review!", body: "⭐️⭐️⭐️⭐️⭐️ Great experience!"),
            .fixture(
                type: .challengeCompleted,
                title: "Challenge Complete!",
                body: "You've completed the \"First Share\" challenge",
            ),
            .fixture(
                type: .forumReply,
                title: "Reply to your post",
                body: "Someone replied to \"Best practices for...\"",
            )
        ]
    }
}
