//
//  ForumSubscription.swift
//  Foodshare
//
//  Forum subscription and notification domain models
//  Maps to `forum_subscriptions` and `forum_notifications` tables
//

import Foundation
import SwiftUI
import FoodShareDesignSystem

// MARK: - Forum Subscription

/// Represents a user's subscription to a forum post or category
struct ForumSubscription: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let profileId: UUID
    let forumId: Int?
    let categoryId: Int?
    let notifyOnReply: Bool
    let notifyOnMention: Bool
    let notifyOnReaction: Bool
    let emailNotifications: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case forumId = "forum_id"
        case categoryId = "category_id"
        case notifyOnReply = "notify_on_reply"
        case notifyOnMention = "notify_on_mention"
        case notifyOnReaction = "notify_on_reaction"
        case emailNotifications = "email_notifications"
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    /// Whether this is a post subscription (vs category)
    var isPostSubscription: Bool {
        forumId != nil
    }

    /// Whether this is a category subscription
    var isCategorySubscription: Bool {
        categoryId != nil && forumId == nil
    }

    /// Active notification types
    var activeNotificationTypes: [NotificationPreference] {
        var types: [NotificationPreference] = []
        if notifyOnReply { types.append(.reply) }
        if notifyOnMention { types.append(.mention) }
        if notifyOnReaction { types.append(.reaction) }
        return types
    }
}

// MARK: - Notification Preference

/// Types of notifications a user can enable
enum NotificationPreference: String, CaseIterable, Sendable {
    case reply
    case mention
    case reaction

    var displayName: String {
        switch self {
        case .reply: "Replies"
        case .mention: "Mentions"
        case .reaction: "Reactions"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .reply: t.t("forum.subscription.reply")
        case .mention: t.t("forum.subscription.mention")
        case .reaction: t.t("forum.subscription.reaction")
        }
    }

    var description: String {
        switch self {
        case .reply: "Get notified when someone replies"
        case .mention: "Get notified when you're mentioned"
        case .reaction: "Get notified when someone reacts"
        }
    }

    @MainActor
    func localizedDescription(using t: EnhancedTranslationService) -> String {
        switch self {
        case .reply: t.t("forum.subscription.reply_desc")
        case .mention: t.t("forum.subscription.mention_desc")
        case .reaction: t.t("forum.subscription.reaction_desc")
        }
    }

    var icon: String {
        switch self {
        case .reply: "arrowshape.turn.up.left.fill"
        case .mention: "at"
        case .reaction: "face.smiling.fill"
        }
    }
}

// MARK: - Forum Notification

/// Represents a notification for forum activity
struct ForumNotification: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let recipientId: UUID
    let actorId: UUID?
    let type: ForumNotificationType
    let forumId: Int?
    let commentId: Int?
    let data: NotificationData?
    let isRead: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case actorId = "actor_id"
        case type
        case forumId = "forum_id"
        case commentId = "comment_id"
        case data
        case isRead = "is_read"
        case createdAt = "created_at"
    }

    // MARK: - Computed Properties

    /// Time since notification was created
    var timeAgo: String {
        guard let createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }

    /// Whether the notification is recent (within last hour)
    var isRecent: Bool {
        guard let createdAt else { return false }
        return Date().timeIntervalSince(createdAt) < 3600
    }
}

// MARK: - Forum Notification Type

enum ForumNotificationType: String, Codable, Sendable, CaseIterable {
    case reply
    case mention
    case reaction
    case newPost = "new_post"
    case postLiked = "post_liked"
    case commentLiked = "comment_liked"
    case badgeEarned = "badge_earned"
    case levelUp = "level_up"
    case pollEnded = "poll_ended"
    case postPinned = "post_pinned"
    case postSolved = "post_solved"

    var displayName: String {
        switch self {
        case .reply: "Reply"
        case .mention: "Mention"
        case .reaction: "Reaction"
        case .newPost: "New Post"
        case .postLiked: "Like"
        case .commentLiked: "Like"
        case .badgeEarned: "Badge Earned"
        case .levelUp: "Level Up"
        case .pollEnded: "Poll Ended"
        case .postPinned: "Post Pinned"
        case .postSolved: "Question Answered"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .reply: t.t("forum.notification_type.reply")
        case .mention: t.t("forum.notification_type.mention")
        case .reaction: t.t("forum.notification_type.reaction")
        case .newPost: t.t("forum.notification_type.new_post")
        case .postLiked: t.t("forum.notification_type.post_liked")
        case .commentLiked: t.t("forum.notification_type.comment_liked")
        case .badgeEarned: t.t("forum.notification_type.badge_earned")
        case .levelUp: t.t("forum.notification_type.level_up")
        case .pollEnded: t.t("forum.notification_type.poll_ended")
        case .postPinned: t.t("forum.notification_type.post_pinned")
        case .postSolved: t.t("forum.notification_type.post_solved")
        }
    }

    var icon: String {
        switch self {
        case .reply: "arrowshape.turn.up.left.fill"
        case .mention: "at"
        case .reaction: "face.smiling.fill"
        case .newPost: "doc.text.fill"
        case .postLiked, .commentLiked: "heart.fill"
        case .badgeEarned: "medal.fill"
        case .levelUp: "arrow.up.circle.fill"
        case .pollEnded: "chart.bar.fill"
        case .postPinned: "pin.fill"
        case .postSolved: "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .reply: .blue
        case .mention: .purple
        case .reaction: .orange
        case .newPost: .DesignSystem.brandGreen
        case .postLiked, .commentLiked: .red
        case .badgeEarned: .yellow
        case .levelUp: .DesignSystem.brandGreen
        case .pollEnded: .indigo
        case .postPinned: .mint
        case .postSolved: .green
        }
    }

    /// Whether this is a celebratory notification (badges, level up)
    var isCelebratory: Bool {
        self == .badgeEarned || self == .levelUp
    }

    /// Priority for sorting (higher = more important)
    var priority: Int {
        switch self {
        case .mention: 10
        case .reply: 9
        case .badgeEarned, .levelUp: 8
        case .postSolved: 7
        case .reaction, .postLiked, .commentLiked: 5
        case .newPost: 4
        case .pollEnded, .postPinned: 3
        }
    }
}

// MARK: - Notification Data

/// Additional data attached to notifications (stored as JSONB)
struct NotificationData: Codable, Hashable, Sendable {
    let postTitle: String?
    let commentPreview: String?
    let actorName: String?
    let actorAvatarUrl: String?
    let badgeName: String?
    let badgeIcon: String?
    let reactionEmoji: String?
    let newLevel: Int?
    let pollQuestion: String?

    enum CodingKeys: String, CodingKey {
        case postTitle = "post_title"
        case commentPreview = "comment_preview"
        case actorName = "actor_name"
        case actorAvatarUrl = "actor_avatar_url"
        case badgeName = "badge_name"
        case badgeIcon = "badge_icon"
        case reactionEmoji = "reaction_emoji"
        case newLevel = "new_level"
        case pollQuestion = "poll_question"
    }

    init(
        postTitle: String? = nil,
        commentPreview: String? = nil,
        actorName: String? = nil,
        actorAvatarUrl: String? = nil,
        badgeName: String? = nil,
        badgeIcon: String? = nil,
        reactionEmoji: String? = nil,
        newLevel: Int? = nil,
        pollQuestion: String? = nil,
    ) {
        self.postTitle = postTitle
        self.commentPreview = commentPreview
        self.actorName = actorName
        self.actorAvatarUrl = actorAvatarUrl
        self.badgeName = badgeName
        self.badgeIcon = badgeIcon
        self.reactionEmoji = reactionEmoji
        self.newLevel = newLevel
        self.pollQuestion = pollQuestion
    }
}

// MARK: - Notification Display Helper

/// Extension to generate display messages from notification data
extension ForumNotification {
    /// Formatted message for display
    var displayMessage: String {
        let actorName = data?.actorName ?? "Someone"
        let postTitle = data?.postTitle ?? "a post"

        switch type {
        case .reply:
            return "\(actorName) replied to \"\(postTitle)\""
        case .mention:
            return "\(actorName) mentioned you in \"\(postTitle)\""
        case .reaction:
            let emoji = data?.reactionEmoji ?? "❤️"
            return "\(actorName) reacted \(emoji) to your post"
        case .newPost:
            return "\(actorName) posted \"\(postTitle)\""
        case .postLiked:
            return "\(actorName) liked your post \"\(postTitle)\""
        case .commentLiked:
            return "\(actorName) liked your comment"
        case .badgeEarned:
            let badge = data?.badgeName ?? "a badge"
            return "You earned the \"\(badge)\" badge!"
        case .levelUp:
            let level = data?.newLevel ?? 1
            return "Congratulations! You reached Trust Level \(level)!"
        case .pollEnded:
            return "Poll results are in for \"\(postTitle)\""
        case .postPinned:
            return "Your post \"\(postTitle)\" was pinned!"
        case .postSolved:
            return "Your question \"\(postTitle)\" was marked as solved!"
        }
    }

    /// Actor's avatar URL if available
    var actorAvatarUrl: URL? {
        guard let urlString = data?.actorAvatarUrl else { return nil }
        return URL(string: urlString)
    }
}

// MARK: - Subscription Preferences

/// User's subscription preferences for the settings sheet
struct SubscriptionPreferences: Sendable {
    var notifyOnReply = true
    var notifyOnMention = true
    var notifyOnReaction = false
    var emailNotifications = false

    init() {}

    init(from subscription: ForumSubscription) {
        notifyOnReply = subscription.notifyOnReply
        notifyOnMention = subscription.notifyOnMention
        notifyOnReaction = subscription.notifyOnReaction
        emailNotifications = subscription.emailNotifications
    }
}

// MARK: - Create Subscription Request

struct CreateSubscriptionRequest: Encodable, Sendable {
    let profileId: UUID
    let forumId: Int?
    let categoryId: Int?
    let notifyOnReply: Bool
    let notifyOnMention: Bool
    let notifyOnReaction: Bool
    let emailNotifications: Bool

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case forumId = "forum_id"
        case categoryId = "category_id"
        case notifyOnReply = "notify_on_reply"
        case notifyOnMention = "notify_on_mention"
        case notifyOnReaction = "notify_on_reaction"
        case emailNotifications = "email_notifications"
    }

    static func forPost(
        _ forumId: Int,
        profileId: UUID,
        preferences: SubscriptionPreferences = .init(),
    ) -> CreateSubscriptionRequest {
        CreateSubscriptionRequest(
            profileId: profileId,
            forumId: forumId,
            categoryId: nil,
            notifyOnReply: preferences.notifyOnReply,
            notifyOnMention: preferences.notifyOnMention,
            notifyOnReaction: preferences.notifyOnReaction,
            emailNotifications: preferences.emailNotifications,
        )
    }

    static func forCategory(
        _ categoryId: Int,
        profileId: UUID,
        preferences: SubscriptionPreferences = .init(),
    ) -> CreateSubscriptionRequest {
        CreateSubscriptionRequest(
            profileId: profileId,
            forumId: nil,
            categoryId: categoryId,
            notifyOnReply: preferences.notifyOnReply,
            notifyOnMention: preferences.notifyOnMention,
            notifyOnReaction: preferences.notifyOnReaction,
            emailNotifications: preferences.emailNotifications,
        )
    }
}

// MARK: - Fixtures

#if DEBUG
    extension ForumSubscription {
        static func fixture(
            forumId: Int? = 1,
            categoryId: Int? = nil,
        ) -> ForumSubscription {
            ForumSubscription(
                id: UUID(),
                profileId: UUID(),
                forumId: forumId,
                categoryId: categoryId,
                notifyOnReply: true,
                notifyOnMention: true,
                notifyOnReaction: false,
                emailNotifications: false,
                createdAt: Date(),
            )
        }
    }

    extension ForumNotification {
        static func fixture(
            type: ForumNotificationType = .reply,
            isRead: Bool = false,
        ) -> ForumNotification {
            ForumNotification(
                id: UUID(),
                recipientId: UUID(),
                actorId: UUID(),
                type: type,
                forumId: 1,
                commentId: nil,
                data: NotificationData(
                    postTitle: "Best food sharing tips",
                    commentPreview: "Great post! I learned so much.",
                    actorName: "FoodLover42",
                    actorAvatarUrl: nil,
                    badgeName: nil,
                    badgeIcon: nil,
                    reactionEmoji: nil,
                    newLevel: nil,
                    pollQuestion: nil,
                ),
                isRead: isRead,
                createdAt: Date().addingTimeInterval(-3600),
            )
        }

        static let fixtures: [ForumNotification] = [
            ForumNotification(
                id: UUID(),
                recipientId: UUID(),
                actorId: UUID(),
                type: .reply,
                forumId: 1,
                commentId: 10,
                data: NotificationData(
                    postTitle: "Best food sharing tips",
                    actorName: "FoodLover42",
                ),
                isRead: false,
                createdAt: Date().addingTimeInterval(-300),
            ),
            ForumNotification(
                id: UUID(),
                recipientId: UUID(),
                actorId: UUID(),
                type: .mention,
                forumId: 2,
                commentId: 15,
                data: NotificationData(
                    postTitle: "Weekly recipe thread",
                    commentPreview: "@user check this out!",
                    actorName: "ChefMike",
                ),
                isRead: false,
                createdAt: Date().addingTimeInterval(-1800),
            ),
            ForumNotification(
                id: UUID(),
                recipientId: UUID(),
                actorId: nil,
                type: .badgeEarned,
                forumId: nil,
                commentId: nil,
                data: NotificationData(
                    badgeName: "First Post",
                    badgeIcon: "pencil",
                ),
                isRead: false,
                createdAt: Date().addingTimeInterval(-3600),
            ),
            ForumNotification(
                id: UUID(),
                recipientId: UUID(),
                actorId: UUID(),
                type: .postLiked,
                forumId: 3,
                commentId: nil,
                data: NotificationData(
                    postTitle: "My favorite local markets",
                    actorName: "MarketExplorer",
                ),
                isRead: true,
                createdAt: Date().addingTimeInterval(-7200),
            ),
            ForumNotification(
                id: UUID(),
                recipientId: UUID(),
                actorId: nil,
                type: .levelUp,
                forumId: nil,
                commentId: nil,
                data: NotificationData(
                    newLevel: 2,
                ),
                isRead: true,
                createdAt: Date().addingTimeInterval(-86400),
            )
        ]
    }
#endif
