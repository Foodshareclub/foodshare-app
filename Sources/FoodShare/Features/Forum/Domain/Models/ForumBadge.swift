//
//  ForumBadge.swift
//  Foodshare
//
//  Forum badge domain models
//  Maps to `forum_badges` and `forum_user_badges` tables
//



#if !SKIP
import Foundation
import SwiftUI

// MARK: - Forum Badge

/// Represents a badge that users can earn in the forum
struct ForumBadge: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let slug: String
    let description: String
    let iconName: String?
    let color: String?
    let badgeType: BadgeType
    let criteria: BadgeCriteria?
    let points: Int
    let isActive: Bool
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, description, points
        case iconName = "icon_name"
        case color
        case badgeType = "badge_type"
        case criteria
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    // MARK: - Custom Decoder (handles nullable database fields)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        slug = try container.decodeIfPresent(String.self, forKey: .slug) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        iconName = try container.decodeIfPresent(String.self, forKey: .iconName)
        color = try container.decodeIfPresent(String.self, forKey: .color)
        badgeType = try container.decodeIfPresent(BadgeType.self, forKey: .badgeType) ?? .achievement
        criteria = try container.decodeIfPresent(BadgeCriteria.self, forKey: .criteria)
        points = try container.decodeIfPresent(Int.self, forKey: .points) ?? 0
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    // MARK: - Memberwise Initializer (for fixtures)

    init(
        id: Int,
        name: String,
        slug: String,
        description: String,
        iconName: String?,
        color: String?,
        badgeType: BadgeType,
        criteria: BadgeCriteria?,
        points: Int,
        isActive: Bool,
        createdAt: Date?
    ) {
        self.id = id
        self.name = name
        self.slug = slug
        self.description = description
        self.iconName = iconName
        self.color = color
        self.badgeType = badgeType
        self.criteria = criteria
        self.points = points
        self.isActive = isActive
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    /// SF Symbol name for the badge icon
    var sfSymbolName: String {
        // Map Lucide/Feather icon names to SF Symbols
        switch iconName {
        case "pencil": "pencil"
        case "edit-3": "square.and.pencil"
        case "book-open": "book.fill"
        case "award": "star.circle.fill"
        case "message-circle": "bubble.left.fill"
        case "messages-square": "bubble.left.and.bubble.right.fill"
        case "users": "person.2.fill"
        case "lightbulb": "lightbulb.fill"
        case "sparkles": "sparkles"
        case "trophy": "trophy.fill"
        case "star": "star.fill"
        case "medal": "medal.fill"
        case "shield-check": "checkmark.shield.fill"
        case "crown": "crown.fill"
        case "heart": "heart.fill"
        case "trending-up": "chart.line.uptrend.xyaxis"
        case "clock": "clock.fill"
        case "badge-check": "checkmark.seal.fill"
        case "shield": "shield.fill"
        case "leaf": "leaf.fill"
        // Additional Lucide/Feather icons from database
        case "chef-hat": "fork.knife"
        case "help-circle": "questionmark.circle.fill"
        case "map-pin": "mappin.circle.fill"
        case "map": "map.fill"
        case "home": "house.fill"
        case "gift": "gift.fill"
        case "camera": "camera.fill"
        case "image": "photo.fill"
        case "share": "square.and.arrow.up.fill"
        case "bookmark": "bookmark.fill"
        case "flag": "flag.fill"
        case "bell": "bell.fill"
        case "settings": "gearshape.fill"
        case "search": "magnifyingglass"
        case "check": "checkmark"
        case "check-circle": "checkmark.circle.fill"
        case "x": "xmark"
        case "x-circle": "xmark.circle.fill"
        case "info": "info.circle.fill"
        case "alert-circle": "exclamationmark.circle.fill"
        case "alert-triangle": "exclamationmark.triangle.fill"
        case "zap": "bolt.fill"
        case "fire": "flame.fill"
        case "coffee": "cup.and.saucer.fill"
        case "utensils": "fork.knife"
        case "package": "shippingbox.fill"
        case "truck": "box.truck.fill"
        case "calendar": "calendar"
        case "user": "person.fill"
        case "user-plus": "person.badge.plus"
        case "user-check": "person.badge.checkmark"
        case "thumbs-up": "hand.thumbsup.fill"
        case "thumbs-down": "hand.thumbsdown.fill"
        case "smile": "face.smiling.fill"
        case "frown": "face.frowning"
        case "sun": "sun.max.fill"
        case "moon": "moon.fill"
        default: "star.fill"
        }
    }

    /// SwiftUI Color from hex string
    var swiftUIColor: Color {
        Color(hex: color ?? "#22c55e")
    }

    /// Whether this badge has specific criteria
    var hasAutoCriteria: Bool {
        guard let criteria else { return false }
        return !criteria.isEmpty
    }

    /// Badge rarity based on points
    var rarity: BadgeRarity {
        switch points {
        case 0 ..< 25: .common
        case 25 ..< 100: .uncommon
        case 100 ..< 250: .rare
        case 250 ..< 500: .epic
        default: .legendary
        }
    }
}

// MARK: - Badge Type

enum BadgeType: String, Codable, Sendable, CaseIterable {
    case milestone
    case achievement
    case special

    var displayName: String {
        switch self {
        case .milestone: "Milestone"
        case .achievement: "Achievement"
        case .special: "Special"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .milestone: t.t("badges.type.milestone")
        case .achievement: t.t("badges.type.achievement")
        case .special: t.t("badges.type.special")
        }
    }

    var icon: String {
        switch self {
        case .milestone: "flag.fill"
        case .achievement: "trophy.fill"
        case .special: "sparkles"
        }
    }

    var sortOrder: Int {
        switch self {
        case .special: 0
        case .achievement: 1
        case .milestone: 2
        }
    }
}

// MARK: - Badge Criteria

/// Criteria for automatic badge awarding
struct BadgeCriteria: Codable, Hashable, Sendable {
    let postsCount: Int?
    let commentsCount: Int?
    let helpfulCount: Int?
    let followersCount: Int?
    let reputationScore: Int?

    enum CodingKeys: String, CodingKey {
        case postsCount = "posts_count"
        case commentsCount = "comments_count"
        case helpfulCount = "helpful_count"
        case followersCount = "followers_count"
        case reputationScore = "reputation_score"
    }

    var isEmpty: Bool {
        postsCount == nil &&
            commentsCount == nil &&
            helpfulCount == nil &&
            followersCount == nil &&
            reputationScore == nil
    }

    /// Check if user stats meet this criteria
    func isMet(by stats: ForumUserStats) -> Bool {
        if let required = postsCount, stats.postsCount < required { return false }
        if let required = commentsCount, stats.commentsCount < required { return false }
        if let required = helpfulCount, stats.helpfulCount < required { return false }
        if let required = followersCount, stats.followersCount < required { return false }
        if let required = reputationScore, stats.reputationScore < required { return false }
        return true
    }

    /// Progress towards meeting this criteria (0.0 to 1.0)
    func progress(for stats: ForumUserStats) -> Double {
        var progressValues: [Double] = []

        if let required = postsCount, required > 0 {
            progressValues.append(min(1.0, Double(stats.postsCount) / Double(required)))
        }
        if let required = commentsCount, required > 0 {
            progressValues.append(min(1.0, Double(stats.commentsCount) / Double(required)))
        }
        if let required = helpfulCount, required > 0 {
            progressValues.append(min(1.0, Double(stats.helpfulCount) / Double(required)))
        }
        if let required = followersCount, required > 0 {
            progressValues.append(min(1.0, Double(stats.followersCount) / Double(required)))
        }
        if let required = reputationScore, required > 0 {
            progressValues.append(min(1.0, Double(stats.reputationScore) / Double(required)))
        }

        guard !progressValues.isEmpty else { return 0.0 }
        return progressValues.reduce(0, +) / Double(progressValues.count)
    }

    /// Description of what's required
    var requirementDescription: String? {
        var parts: [String] = []
        if let count = postsCount { parts.append("\(count) posts") }
        if let count = commentsCount { parts.append("\(count) comments") }
        if let count = helpfulCount { parts.append("\(count) helpful reactions") }
        if let count = followersCount { parts.append("\(count) followers") }
        if let score = reputationScore { parts.append("\(score) reputation") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

// MARK: - Badge Rarity

enum BadgeRarity: String, Sendable, CaseIterable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var displayName: String {
        rawValue.capitalized
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .common: t.t("badges.rarity.common")
        case .uncommon: t.t("badges.rarity.uncommon")
        case .rare: t.t("badges.rarity.rare")
        case .epic: t.t("badges.rarity.epic")
        case .legendary: t.t("badges.rarity.legendary")
        }
    }

    var color: Color {
        switch self {
        case .common: .gray
        case .uncommon: .green
        case .rare: .blue
        case .epic: .purple
        case .legendary: .orange
        }
    }

    var glowIntensity: Double {
        switch self {
        case .common: 0.0
        case .uncommon: 0.1
        case .rare: 0.2
        case .epic: 0.3
        case .legendary: 0.4
        }
    }
}

// MARK: - User Badge

/// Represents a badge awarded to a user
struct UserBadge: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let profileId: UUID
    let badgeId: Int
    let awardedAt: Date?
    let awardedBy: UUID?
    let isFeatured: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case badgeId = "badge_id"
        case awardedAt = "awarded_at"
        case awardedBy = "awarded_by"
        case isFeatured = "is_featured"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        profileId = try container.decode(UUID.self, forKey: .profileId)
        badgeId = try container.decode(Int.self, forKey: .badgeId)
        awardedAt = try container.decodeIfPresent(Date.self, forKey: .awardedAt)
        awardedBy = try container.decodeIfPresent(UUID.self, forKey: .awardedBy)
        isFeatured = try container.decodeIfPresent(Bool.self, forKey: .isFeatured) ?? false
    }

    init(id: UUID, profileId: UUID, badgeId: Int, awardedAt: Date?, awardedBy: UUID?, isFeatured: Bool) {
        self.id = id
        self.profileId = profileId
        self.badgeId = badgeId
        self.awardedAt = awardedAt
        self.awardedBy = awardedBy
        self.isFeatured = isFeatured
    }
}

// MARK: - User Badge with Details

/// User badge joined with badge details
struct UserBadgeWithDetails: Identifiable, Hashable, Sendable {
    let userBadge: UserBadge
    let badge: ForumBadge

    var id: UUID { userBadge.id }

    init(userBadge: UserBadge, badge: ForumBadge) {
        self.userBadge = userBadge
        self.badge = badge
    }
}

// MARK: - Badge Collection

/// A collection of badges grouped by type
struct BadgeCollection: Sendable {
    let allBadges: [ForumBadge]
    let earnedBadges: [UserBadgeWithDetails]
    let featuredBadges: [UserBadgeWithDetails]

    /// Badges grouped by type
    var badgesByType: [BadgeType: [ForumBadge]] {
        var result: [BadgeType: [ForumBadge]] = [:]
        for badge in allBadges {
            result[badge.badgeType, default: []].append(badge)
        }
        return result
    }

    /// Earned badge IDs for quick lookup
    var earnedBadgeIds: Set<Int> {
        Set(earnedBadges.map(\.badge.id))
    }

    /// Check if user has earned a specific badge
    func hasEarned(_ badge: ForumBadge) -> Bool {
        earnedBadgeIds.contains(badge.id)
    }

    /// Get user badge for a specific badge ID
    func userBadge(for badgeId: Int) -> UserBadgeWithDetails? {
        earnedBadges.first { $0.badge.id == badgeId }
    }

    /// Total points from earned badges
    var totalPoints: Int {
        earnedBadges.reduce(0) { $0 + $1.badge.points }
    }

    /// Badges user can earn next (not earned, has criteria, criteria not yet met)
    func nextBadges(for stats: ForumUserStats) -> [ForumBadge] {
        allBadges
            .filter { !earnedBadgeIds.contains($0.id) && $0.hasAutoCriteria }
            .sorted { ($0.criteria?.progress(for: stats) ?? 0) > ($1.criteria?.progress(for: stats) ?? 0) }
    }

    static let empty = BadgeCollection(allBadges: [], earnedBadges: [], featuredBadges: [])
}

// MARK: - Fixtures

#if DEBUG
    extension ForumBadge {
        static let fixture = ForumBadge(
            id: 1,
            name: "First Post",
            slug: "first-post",
            description: "Published your first forum post",
            iconName: "pencil",
            color: "#22c55e",
            badgeType: .milestone,
            criteria: BadgeCriteria(
                postsCount: 1,
                commentsCount: nil,
                helpfulCount: nil,
                followersCount: nil,
                reputationScore: nil,
            ),
            points: 10,
            isActive: true,
            createdAt: Date(),
        )

        static let fixtures: [ForumBadge] = [
            ForumBadge(
                id: 1,
                name: "First Post",
                slug: "first-post",
                description: "Published your first forum post",
                iconName: "pencil",
                color: "#22c55e",
                badgeType: .milestone,
                criteria: BadgeCriteria(
                    postsCount: 1,
                    commentsCount: nil,
                    helpfulCount: nil,
                    followersCount: nil,
                    reputationScore: nil,
                ),
                points: 10,
                isActive: true,
                createdAt: Date(),
            ),
            ForumBadge(
                id: 2,
                name: "Contributor",
                slug: "contributor",
                description: "Published 10 forum posts",
                iconName: "edit-3",
                color: "#3b82f6",
                badgeType: .milestone,
                criteria: BadgeCriteria(
                    postsCount: 10,
                    commentsCount: nil,
                    helpfulCount: nil,
                    followersCount: nil,
                    reputationScore: nil,
                ),
                points: 25,
                isActive: true,
                createdAt: Date(),
            ),
            ForumBadge(
                id: 17,
                name: "Early Adopter",
                slug: "early-adopter",
                description: "Joined the forum community early",
                iconName: "clock",
                color: "#6366f1",
                badgeType: .achievement,
                criteria: nil,
                points: 50,
                isActive: true,
                createdAt: Date(),
            ),
            ForumBadge(
                id: 18,
                name: "Verified",
                slug: "verified",
                description: "Verified community member",
                iconName: "badge-check",
                color: "#0ea5e9",
                badgeType: .special,
                criteria: nil,
                points: 0,
                isActive: true,
                createdAt: Date(),
            ),
        ]
    }

    extension UserBadge {
        static func fixture(badgeId: Int = 1) -> UserBadge {
            UserBadge(
                id: UUID(),
                profileId: UUID(),
                badgeId: badgeId,
                awardedAt: Date(),
                awardedBy: nil,
                isFeatured: false,
            )
        }
    }

    extension BadgeCollection {
        static let fixture = BadgeCollection(
            allBadges: ForumBadge.fixtures,
            earnedBadges: [
                UserBadgeWithDetails(
                    userBadge: UserBadge.fixture(badgeId: 1),
                    badge: ForumBadge.fixtures[0],
                ),
                UserBadgeWithDetails(
                    userBadge: UserBadge.fixture(badgeId: 17),
                    badge: ForumBadge.fixtures[2],
                ),
            ],
            featuredBadges: [],
        )
    }
#endif


#endif
