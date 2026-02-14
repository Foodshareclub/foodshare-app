//
//  ActivityItem.swift
//  Foodshare
//
//  Domain model for Activity Feed items
//

import Foundation
import SwiftUI
import FoodShareDesignSystem

/// Represents a single activity item in the feed
struct ActivityItem: Identifiable, Sendable {
    let id: UUID
    let type: ActivityType
    let title: String
    let subtitle: String
    let imageURL: URL?
    let timestamp: Date
    let actorName: String?
    let actorAvatarURL: URL?
    let linkedPostId: Int?
    let linkedForumId: Int?
    let linkedProfileId: UUID?

    var timeAgo: String {
        timestamp.timeAgoDisplay()
    }
}

/// Types of activity
enum ActivityType: String, Codable, Sendable {
    case newListing
    case listingArranged
    case forumPost
    case forumComment
    case reviewReceived
    case challengeCompleted
    case userJoined
    case communityMilestone

    var icon: String {
        switch self {
        case .newListing: "leaf.fill"
        case .listingArranged: "checkmark.circle.fill"
        case .forumPost: "bubble.left.fill"
        case .forumComment: "text.bubble.fill"
        case .reviewReceived: "star.fill"
        case .challengeCompleted: "trophy.fill"
        case .userJoined: "person.badge.plus"
        case .communityMilestone: "flag.fill"
        }
    }

    var color: Color {
        switch self {
        case .newListing: .DesignSystem.brandGreen
        case .listingArranged: .DesignSystem.success
        case .forumPost: .DesignSystem.brandBlue
        case .forumComment: .DesignSystem.blueLight
        case .reviewReceived: .DesignSystem.accentYellow
        case .challengeCompleted: .DesignSystem.accentOrange
        case .userJoined: .DesignSystem.accentPurple
        case .communityMilestone: .DesignSystem.accentPink
        }
    }

    var label: String {
        switch self {
        case .newListing: "New Listing"
        case .listingArranged: "Food Shared"
        case .forumPost: "Forum Post"
        case .forumComment: "Comment"
        case .reviewReceived: "Review"
        case .challengeCompleted: "Challenge"
        case .userJoined: "New Member"
        case .communityMilestone: "Milestone"
        }
    }

    @MainActor
    func localizedLabel(using t: EnhancedTranslationService) -> String {
        switch self {
        case .newListing: t.t("activity.type.new_listing")
        case .listingArranged: t.t("activity.type.food_shared")
        case .forumPost: t.t("activity.type.forum_post")
        case .forumComment: t.t("activity.type.comment")
        case .reviewReceived: t.t("activity.type.review")
        case .challengeCompleted: t.t("activity.type.challenge")
        case .userJoined: t.t("activity.type.new_member")
        case .communityMilestone: t.t("activity.type.milestone")
        }
    }
}

// MARK: - Date Extension

extension Date {
    func timeAgoDisplay() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)

        if let weeks = components.weekOfYear, weeks >= 1 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }
        if let days = components.day, days >= 1 {
            return days == 1 ? "Yesterday" : "\(days) days ago"
        }
        if let hours = components.hour, hours >= 1 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        if let minutes = components.minute, minutes >= 1 {
            return minutes == 1 ? "1 min ago" : "\(minutes) mins ago"
        }
        return "Just now"
    }
}

// MARK: - Test Fixtures

#if DEBUG

    extension ActivityItem {
        static func fixture(
            id: UUID = UUID(),
            type: ActivityType = .newListing,
            title: String = "Fresh Vegetables Available",
            subtitle: String = "Organic tomatoes and lettuce",
            imageURL: URL? = nil,
            timestamp: Date = Date(),
            actorName: String? = "FoodSaver",
            actorAvatarURL: URL? = nil,
            linkedPostId: Int? = 1,
            linkedForumId: Int? = nil,
            linkedProfileId: UUID? = nil,
        ) -> ActivityItem {
            ActivityItem(
                id: id,
                type: type,
                title: title,
                subtitle: subtitle,
                imageURL: imageURL,
                timestamp: timestamp,
                actorName: actorName,
                actorAvatarURL: actorAvatarURL,
                linkedPostId: linkedPostId,
                linkedForumId: linkedForumId,
                linkedProfileId: linkedProfileId,
            )
        }

        static let sampleActivities: [ActivityItem] = [
            .fixture(
                type: .newListing,
                title: "Fresh Bread Available",
                subtitle: "Sourdough loaves from local bakery",
                timestamp: Date().addingTimeInterval(-300),
            ),
            .fixture(
                type: .listingArranged,
                title: "Food Shared Successfully!",
                subtitle: "10 kg of produce saved from waste",
                timestamp: Date().addingTimeInterval(-3600),
                actorName: "GreenHelper",
            ),
            .fixture(
                type: .forumPost,
                title: "Tips for reducing food waste",
                subtitle: "Check out these 5 easy tips...",
                timestamp: Date().addingTimeInterval(-7200),
                actorName: "EcoWarrior",
            ),
            .fixture(
                type: .challengeCompleted,
                title: "Zero Waste Week Complete",
                subtitle: "15 users completed the challenge!",
                timestamp: Date().addingTimeInterval(-86400),
            ),
            .fixture(
                type: .reviewReceived,
                title: "New 5-star review",
                subtitle: "\"Amazing experience, highly recommend!\"",
                timestamp: Date().addingTimeInterval(-90000),
                actorName: "HappyUser",
            ),
            .fixture(
                type: .userJoined,
                title: "Welcome our newest member",
                subtitle: "Foodshare community grows!",
                timestamp: Date().addingTimeInterval(-172_800),
                actorName: "NewFoodSaver",
            )
        ]
    }

#endif
