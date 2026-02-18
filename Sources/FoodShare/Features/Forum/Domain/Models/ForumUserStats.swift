//
//  ForumUserStats.swift
//  Foodshare
//
//  User statistics and reputation for forum features
//  Maps to `forum_user_stats` table
//



#if !SKIP
import Foundation
import SwiftUI

// MARK: - Forum User Stats

/// Represents a user's forum statistics from the `forum_user_stats` table
struct ForumUserStats: Codable, Identifiable, Hashable, Sendable {
    let profileId: UUID
    let postsCount: Int
    let commentsCount: Int
    let reactionsReceived: Int
    let helpfulCount: Int
    let reputationScore: Int
    let joinedForumAt: Date?
    let lastPostAt: Date?
    let lastCommentAt: Date?
    let updatedAt: Date?
    let followersCount: Int
    let followingCount: Int
    let trustLevel: Int
    let topicsRead: Int
    let postsRead: Int
    let timeSpentMinutes: Int
    let likesGiven: Int
    let likesReceived: Int
    let repliesReceived: Int
    let flagsAgreed: Int
    let wasWarned: Bool
    let wasSilenced: Bool
    let silencedUntil: Date?
    let trustLevelLocked: Bool

    // MARK: - Identifiable

    var id: UUID { profileId }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case postsCount = "posts_count"
        case commentsCount = "comments_count"
        case reactionsReceived = "reactions_received"
        case helpfulCount = "helpful_count"
        case reputationScore = "reputation_score"
        case joinedForumAt = "joined_forum_at"
        case lastPostAt = "last_post_at"
        case lastCommentAt = "last_comment_at"
        case updatedAt = "updated_at"
        case followersCount = "followers_count"
        case followingCount = "following_count"
        case trustLevel = "trust_level"
        case topicsRead = "topics_read"
        case postsRead = "posts_read"
        case timeSpentMinutes = "time_spent_minutes"
        case likesGiven = "likes_given"
        case likesReceived = "likes_received"
        case repliesReceived = "replies_received"
        case flagsAgreed = "flags_agreed"
        case wasWarned = "was_warned"
        case wasSilenced = "was_silenced"
        case silencedUntil = "silenced_until"
        case trustLevelLocked = "trust_level_locked"
    }

    // MARK: - Custom Decoder (handles nullable database fields)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileId = try container.decode(UUID.self, forKey: .profileId)
        postsCount = try container.decodeIfPresent(Int.self, forKey: .postsCount) ?? 0
        commentsCount = try container.decodeIfPresent(Int.self, forKey: .commentsCount) ?? 0
        reactionsReceived = try container.decodeIfPresent(Int.self, forKey: .reactionsReceived) ?? 0
        helpfulCount = try container.decodeIfPresent(Int.self, forKey: .helpfulCount) ?? 0
        reputationScore = try container.decodeIfPresent(Int.self, forKey: .reputationScore) ?? 0
        joinedForumAt = try container.decodeIfPresent(Date.self, forKey: .joinedForumAt)
        lastPostAt = try container.decodeIfPresent(Date.self, forKey: .lastPostAt)
        lastCommentAt = try container.decodeIfPresent(Date.self, forKey: .lastCommentAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        followersCount = try container.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
        followingCount = try container.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        trustLevel = try container.decodeIfPresent(Int.self, forKey: .trustLevel) ?? 0
        topicsRead = try container.decodeIfPresent(Int.self, forKey: .topicsRead) ?? 0
        postsRead = try container.decodeIfPresent(Int.self, forKey: .postsRead) ?? 0
        timeSpentMinutes = try container.decodeIfPresent(Int.self, forKey: .timeSpentMinutes) ?? 0
        likesGiven = try container.decodeIfPresent(Int.self, forKey: .likesGiven) ?? 0
        likesReceived = try container.decodeIfPresent(Int.self, forKey: .likesReceived) ?? 0
        repliesReceived = try container.decodeIfPresent(Int.self, forKey: .repliesReceived) ?? 0
        flagsAgreed = try container.decodeIfPresent(Int.self, forKey: .flagsAgreed) ?? 0
        wasWarned = try container.decodeIfPresent(Bool.self, forKey: .wasWarned) ?? false
        wasSilenced = try container.decodeIfPresent(Bool.self, forKey: .wasSilenced) ?? false
        silencedUntil = try container.decodeIfPresent(Date.self, forKey: .silencedUntil)
        trustLevelLocked = try container.decodeIfPresent(Bool.self, forKey: .trustLevelLocked) ?? false
    }

    // MARK: - Memberwise Initializer (for fixtures and empty stats)

    init(
        profileId: UUID,
        postsCount: Int,
        commentsCount: Int,
        reactionsReceived: Int,
        helpfulCount: Int,
        reputationScore: Int,
        joinedForumAt: Date?,
        lastPostAt: Date?,
        lastCommentAt: Date?,
        updatedAt: Date?,
        followersCount: Int,
        followingCount: Int,
        trustLevel: Int,
        topicsRead: Int,
        postsRead: Int,
        timeSpentMinutes: Int,
        likesGiven: Int,
        likesReceived: Int,
        repliesReceived: Int,
        flagsAgreed: Int,
        wasWarned: Bool,
        wasSilenced: Bool,
        silencedUntil: Date?,
        trustLevelLocked: Bool
    ) {
        self.profileId = profileId
        self.postsCount = postsCount
        self.commentsCount = commentsCount
        self.reactionsReceived = reactionsReceived
        self.helpfulCount = helpfulCount
        self.reputationScore = reputationScore
        self.joinedForumAt = joinedForumAt
        self.lastPostAt = lastPostAt
        self.lastCommentAt = lastCommentAt
        self.updatedAt = updatedAt
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.trustLevel = trustLevel
        self.topicsRead = topicsRead
        self.postsRead = postsRead
        self.timeSpentMinutes = timeSpentMinutes
        self.likesGiven = likesGiven
        self.likesReceived = likesReceived
        self.repliesReceived = repliesReceived
        self.flagsAgreed = flagsAgreed
        self.wasWarned = wasWarned
        self.wasSilenced = wasSilenced
        self.silencedUntil = silencedUntil
        self.trustLevelLocked = trustLevelLocked
    }

    // MARK: - Computed Properties

    /// Total engagement score combining multiple metrics
    var engagementScore: Int {
        postsCount * 10 +
            commentsCount * 5 +
            likesGiven * 1 +
            likesReceived * 2 +
            reactionsReceived * 2 +
            helpfulCount * 15
    }

    /// Whether the user is currently silenced
    var isSilenced: Bool {
        guard wasSilenced, let silencedUntil else { return false }
        return silencedUntil > Date()
    }

    /// Days since the user joined the forum
    var daysSinceJoin: Int {
        guard let joinedAt = joinedForumAt else { return 0 }
        let days = Calendar.current.dateComponents([.day], from: joinedAt, to: Date()).day ?? 0
        return max(0, days)
    }

    /// Formatted time spent in the forum
    var formattedTimeSpent: String {
        if timeSpentMinutes < 60 {
            "\(timeSpentMinutes)m"
        } else if timeSpentMinutes < 1440 {
            "\(timeSpentMinutes / 60)h"
        } else {
            "\(timeSpentMinutes / 1440)d"
        }
    }

    /// Activity level based on recent engagement
    var activityLevel: ActivityLevel {
        guard let lastActivity = lastPostAt ?? lastCommentAt else {
            return .inactive
        }

        let daysSinceActivity = Calendar.current.dateComponents([.day], from: lastActivity, to: Date()).day ?? Int.max

        switch daysSinceActivity {
        case 0 ... 1: return .veryActive
        case 2 ... 7: return .active
        case 8 ... 30: return .moderate
        default: return .inactive
        }
    }

    // MARK: - Activity Level

    enum ActivityLevel: String, Sendable {
        case veryActive = "Very Active"
        case active = "Active"
        case moderate = "Moderate"
        case inactive = "Inactive"

        var displayName: String {
            rawValue
        }

        @MainActor
        func localizedDisplayName(using t: EnhancedTranslationService) -> String {
            switch self {
            case .veryActive: t.t("forum.activity.very_active")
            case .active: t.t("forum.activity.active")
            case .moderate: t.t("forum.activity.moderate")
            case .inactive: t.t("forum.activity.inactive")
            }
        }

        var color: Color {
            switch self {
            case .veryActive: .green
            case .active: .blue
            case .moderate: .orange
            case .inactive: .gray
            }
        }

        var icon: String {
            switch self {
            case .veryActive: "flame.fill"
            case .active: "bolt.fill"
            case .moderate: "clock.fill"
            case .inactive: "moon.zzz.fill"
            }
        }
    }
}

// MARK: - Forum Trust Level

/// Represents a trust level from the `forum_trust_levels` table
struct ForumTrustLevel: Codable, Identifiable, Hashable, Sendable {
    let level: Int
    let name: String
    let description: String
    let color: String

    // Requirements
    let minDaysSinceJoin: Int
    let minPostsRead: Int
    let minTopicsRead: Int
    let minPostsCreated: Int
    let minTopicsCreated: Int
    let minLikesGiven: Int
    let minLikesReceived: Int
    let minRepliesReceived: Int
    let minTimeSpentMinutes: Int

    // Permissions
    let canPost: Bool
    let canReply: Bool
    let canLike: Bool
    let canFlag: Bool
    let canEditOwnPosts: Bool
    let canDeleteOwnPosts: Bool
    let canUploadImages: Bool
    let canPostLinks: Bool
    let canMentionUsers: Bool
    let canSendMessages: Bool
    let canCreatePolls: Bool
    let canCreateWiki: Bool

    // Limits
    let maxPostsPerDay: Int
    let maxTopicsPerDay: Int
    let maxLikesPerDay: Int
    let maxFlagsPerDay: Int

    let createdAt: Date?

    // MARK: - Identifiable

    var id: Int { level }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case level, name, description, color
        case minDaysSinceJoin = "min_days_since_join"
        case minPostsRead = "min_posts_read"
        case minTopicsRead = "min_topics_read"
        case minPostsCreated = "min_posts_created"
        case minTopicsCreated = "min_topics_created"
        case minLikesGiven = "min_likes_given"
        case minLikesReceived = "min_likes_received"
        case minRepliesReceived = "min_replies_received"
        case minTimeSpentMinutes = "min_time_spent_minutes"
        case canPost = "can_post"
        case canReply = "can_reply"
        case canLike = "can_like"
        case canFlag = "can_flag"
        case canEditOwnPosts = "can_edit_own_posts"
        case canDeleteOwnPosts = "can_delete_own_posts"
        case canUploadImages = "can_upload_images"
        case canPostLinks = "can_post_links"
        case canMentionUsers = "can_mention_users"
        case canSendMessages = "can_send_messages"
        case canCreatePolls = "can_create_polls"
        case canCreateWiki = "can_create_wiki"
        case maxPostsPerDay = "max_posts_per_day"
        case maxTopicsPerDay = "max_topics_per_day"
        case maxLikesPerDay = "max_likes_per_day"
        case maxFlagsPerDay = "max_flags_per_day"
        case createdAt = "created_at"
    }

    // MARK: - Custom Decoder (handles nullable database fields)

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        level = try container.decode(Int.self, forKey: .level)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        color = try container.decodeIfPresent(String.self, forKey: .color) ?? "#9CA3AF"
        minDaysSinceJoin = try container.decodeIfPresent(Int.self, forKey: .minDaysSinceJoin) ?? 0
        minPostsRead = try container.decodeIfPresent(Int.self, forKey: .minPostsRead) ?? 0
        minTopicsRead = try container.decodeIfPresent(Int.self, forKey: .minTopicsRead) ?? 0
        minPostsCreated = try container.decodeIfPresent(Int.self, forKey: .minPostsCreated) ?? 0
        minTopicsCreated = try container.decodeIfPresent(Int.self, forKey: .minTopicsCreated) ?? 0
        minLikesGiven = try container.decodeIfPresent(Int.self, forKey: .minLikesGiven) ?? 0
        minLikesReceived = try container.decodeIfPresent(Int.self, forKey: .minLikesReceived) ?? 0
        minRepliesReceived = try container.decodeIfPresent(Int.self, forKey: .minRepliesReceived) ?? 0
        minTimeSpentMinutes = try container.decodeIfPresent(Int.self, forKey: .minTimeSpentMinutes) ?? 0
        canPost = try container.decodeIfPresent(Bool.self, forKey: .canPost) ?? true
        canReply = try container.decodeIfPresent(Bool.self, forKey: .canReply) ?? true
        canLike = try container.decodeIfPresent(Bool.self, forKey: .canLike) ?? true
        canFlag = try container.decodeIfPresent(Bool.self, forKey: .canFlag) ?? false
        canEditOwnPosts = try container.decodeIfPresent(Bool.self, forKey: .canEditOwnPosts) ?? true
        canDeleteOwnPosts = try container.decodeIfPresent(Bool.self, forKey: .canDeleteOwnPosts) ?? false
        canUploadImages = try container.decodeIfPresent(Bool.self, forKey: .canUploadImages) ?? false
        canPostLinks = try container.decodeIfPresent(Bool.self, forKey: .canPostLinks) ?? false
        canMentionUsers = try container.decodeIfPresent(Bool.self, forKey: .canMentionUsers) ?? false
        canSendMessages = try container.decodeIfPresent(Bool.self, forKey: .canSendMessages) ?? false
        canCreatePolls = try container.decodeIfPresent(Bool.self, forKey: .canCreatePolls) ?? false
        canCreateWiki = try container.decodeIfPresent(Bool.self, forKey: .canCreateWiki) ?? false
        maxPostsPerDay = try container.decodeIfPresent(Int.self, forKey: .maxPostsPerDay) ?? 10
        maxTopicsPerDay = try container.decodeIfPresent(Int.self, forKey: .maxTopicsPerDay) ?? 3
        maxLikesPerDay = try container.decodeIfPresent(Int.self, forKey: .maxLikesPerDay) ?? 20
        maxFlagsPerDay = try container.decodeIfPresent(Int.self, forKey: .maxFlagsPerDay) ?? 3
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
    }

    // MARK: - Memberwise Initializer (for fixtures and static definitions)

    init(
        level: Int,
        name: String,
        description: String,
        color: String,
        minDaysSinceJoin: Int,
        minPostsRead: Int,
        minTopicsRead: Int,
        minPostsCreated: Int,
        minTopicsCreated: Int,
        minLikesGiven: Int,
        minLikesReceived: Int,
        minRepliesReceived: Int,
        minTimeSpentMinutes: Int,
        canPost: Bool,
        canReply: Bool,
        canLike: Bool,
        canFlag: Bool,
        canEditOwnPosts: Bool,
        canDeleteOwnPosts: Bool,
        canUploadImages: Bool,
        canPostLinks: Bool,
        canMentionUsers: Bool,
        canSendMessages: Bool,
        canCreatePolls: Bool,
        canCreateWiki: Bool,
        maxPostsPerDay: Int,
        maxTopicsPerDay: Int,
        maxLikesPerDay: Int,
        maxFlagsPerDay: Int,
        createdAt: Date?
    ) {
        self.level = level
        self.name = name
        self.description = description
        self.color = color
        self.minDaysSinceJoin = minDaysSinceJoin
        self.minPostsRead = minPostsRead
        self.minTopicsRead = minTopicsRead
        self.minPostsCreated = minPostsCreated
        self.minTopicsCreated = minTopicsCreated
        self.minLikesGiven = minLikesGiven
        self.minLikesReceived = minLikesReceived
        self.minRepliesReceived = minRepliesReceived
        self.minTimeSpentMinutes = minTimeSpentMinutes
        self.canPost = canPost
        self.canReply = canReply
        self.canLike = canLike
        self.canFlag = canFlag
        self.canEditOwnPosts = canEditOwnPosts
        self.canDeleteOwnPosts = canDeleteOwnPosts
        self.canUploadImages = canUploadImages
        self.canPostLinks = canPostLinks
        self.canMentionUsers = canMentionUsers
        self.canSendMessages = canSendMessages
        self.canCreatePolls = canCreatePolls
        self.canCreateWiki = canCreateWiki
        self.maxPostsPerDay = maxPostsPerDay
        self.maxTopicsPerDay = maxTopicsPerDay
        self.maxLikesPerDay = maxLikesPerDay
        self.maxFlagsPerDay = maxFlagsPerDay
        self.createdAt = createdAt
    }

    // MARK: - Computed Properties

    /// SwiftUI Color from the hex color string
    var swiftUIColor: Color {
        Color(hex: color)
    }

    /// Icon for the trust level
    var icon: String {
        switch level {
        case 0: "person.fill"
        case 1: "checkmark.seal.fill"
        case 2: "star.fill"
        case 3: "rosette"
        case 4: "crown.fill"
        default: "person.fill"
        }
    }

    /// Short name for compact display
    var shortName: String {
        switch level {
        case 0: "New"
        case 1: "Basic"
        case 2: "Member"
        case 3: "Regular"
        case 4: "Leader"
        default: "L\(level)"
        }
    }

    /// Localized short name for compact display
    @MainActor
    func localizedShortName(using t: EnhancedTranslationService) -> String {
        switch level {
        case 0: t.t("forum.trust_level.new")
        case 1: t.t("forum.trust_level.basic")
        case 2: t.t("forum.trust_level.member")
        case 3: t.t("forum.trust_level.regular")
        case 4: t.t("forum.trust_level.leader")
        default: "L\(level)"
        }
    }

    /// All permissions as a list
    var enabledPermissions: [String] {
        var permissions: [String] = []
        if canPost { permissions.append("Create posts") }
        if canReply { permissions.append("Reply to posts") }
        if canLike { permissions.append("Like content") }
        if canFlag { permissions.append("Flag content") }
        if canEditOwnPosts { permissions.append("Edit own posts") }
        if canDeleteOwnPosts { permissions.append("Delete own posts") }
        if canUploadImages { permissions.append("Upload images") }
        if canPostLinks { permissions.append("Post links") }
        if canMentionUsers { permissions.append("Mention users") }
        if canSendMessages { permissions.append("Send messages") }
        if canCreatePolls { permissions.append("Create polls") }
        if canCreateWiki { permissions.append("Create wiki") }
        return permissions
    }

    /// All localized permissions as a list
    @MainActor
    func localizedPermissions(using t: EnhancedTranslationService) -> [String] {
        var permissions: [String] = []
        if canPost { permissions.append(t.t("forum.permission.create_posts")) }
        if canReply { permissions.append(t.t("forum.permission.reply_to_posts")) }
        if canLike { permissions.append(t.t("forum.permission.like_content")) }
        if canFlag { permissions.append(t.t("forum.permission.flag_content")) }
        if canEditOwnPosts { permissions.append(t.t("forum.permission.edit_own_posts")) }
        if canDeleteOwnPosts { permissions.append(t.t("forum.permission.delete_own_posts")) }
        if canUploadImages { permissions.append(t.t("forum.permission.upload_images")) }
        if canPostLinks { permissions.append(t.t("forum.permission.post_links")) }
        if canMentionUsers { permissions.append(t.t("forum.permission.mention_users")) }
        if canSendMessages { permissions.append(t.t("forum.permission.send_messages")) }
        if canCreatePolls { permissions.append(t.t("forum.permission.create_polls")) }
        if canCreateWiki { permissions.append(t.t("forum.permission.create_wiki")) }
        return permissions
    }

    // MARK: - Progress Calculation

    /// Calculate progress towards this trust level for a given user stats
    func progressForUser(_ stats: ForumUserStats) -> TrustLevelProgress {
        var requirements: [RequirementProgress] = []

        // Days since join
        requirements.append(RequirementProgress(
            name: "Days Active",
            current: stats.daysSinceJoin,
            required: minDaysSinceJoin,
            icon: "calendar",
        ))

        // Posts read
        requirements.append(RequirementProgress(
            name: "Posts Read",
            current: stats.postsRead,
            required: minPostsRead,
            icon: "eye.fill",
        ))

        // Topics read
        requirements.append(RequirementProgress(
            name: "Topics Read",
            current: stats.topicsRead,
            required: minTopicsRead,
            icon: "doc.text.fill",
        ))

        // Posts created
        requirements.append(RequirementProgress(
            name: "Posts Created",
            current: stats.postsCount,
            required: minPostsCreated,
            icon: "square.and.pencil",
        ))

        // Likes given
        requirements.append(RequirementProgress(
            name: "Likes Given",
            current: stats.likesGiven,
            required: minLikesGiven,
            icon: "hand.thumbsup.fill",
        ))

        // Likes received
        requirements.append(RequirementProgress(
            name: "Likes Received",
            current: stats.likesReceived,
            required: minLikesReceived,
            icon: "heart.fill",
        ))

        // Time spent
        requirements.append(RequirementProgress(
            name: "Time Spent",
            current: stats.timeSpentMinutes,
            required: minTimeSpentMinutes,
            icon: "clock.fill",
        ))

        return TrustLevelProgress(
            trustLevel: self,
            requirements: requirements,
        )
    }

    // MARK: - Static Trust Levels

    /// All trust levels (cached from database)
    static let all: [ForumTrustLevel] = [
        ForumTrustLevel.newUser,
        ForumTrustLevel.basic,
        ForumTrustLevel.member,
        ForumTrustLevel.regular,
        ForumTrustLevel.leader
    ]

    static let newUser = ForumTrustLevel(
        level: 0,
        name: "New User",
        description: "Just joined the community. Limited posting abilities.",
        color: "#9CA3AF",
        minDaysSinceJoin: 0,
        minPostsRead: 0,
        minTopicsRead: 0,
        minPostsCreated: 0,
        minTopicsCreated: 0,
        minLikesGiven: 0,
        minLikesReceived: 0,
        minRepliesReceived: 0,
        minTimeSpentMinutes: 0,
        canPost: true,
        canReply: true,
        canLike: true,
        canFlag: false,
        canEditOwnPosts: true,
        canDeleteOwnPosts: false,
        canUploadImages: false,
        canPostLinks: false,
        canMentionUsers: false,
        canSendMessages: false,
        canCreatePolls: false,
        canCreateWiki: false,
        maxPostsPerDay: 3,
        maxTopicsPerDay: 1,
        maxLikesPerDay: 5,
        maxFlagsPerDay: 0,
        createdAt: nil,
    )

    static let basic = ForumTrustLevel(
        level: 1,
        name: "Basic",
        description: "Has read enough to understand the community norms.",
        color: "#60A5FA",
        minDaysSinceJoin: 1,
        minPostsRead: 10,
        minTopicsRead: 5,
        minPostsCreated: 1,
        minTopicsCreated: 0,
        minLikesGiven: 1,
        minLikesReceived: 0,
        minRepliesReceived: 0,
        minTimeSpentMinutes: 10,
        canPost: true,
        canReply: true,
        canLike: true,
        canFlag: true,
        canEditOwnPosts: true,
        canDeleteOwnPosts: false,
        canUploadImages: true,
        canPostLinks: true,
        canMentionUsers: true,
        canSendMessages: false,
        canCreatePolls: false,
        canCreateWiki: false,
        maxPostsPerDay: 10,
        maxTopicsPerDay: 3,
        maxLikesPerDay: 20,
        maxFlagsPerDay: 3,
        createdAt: nil,
    )

    static let member = ForumTrustLevel(
        level: 2,
        name: "Member",
        description: "Regular participant who contributes positively.",
        color: "#34D399",
        minDaysSinceJoin: 7,
        minPostsRead: 50,
        minTopicsRead: 20,
        minPostsCreated: 5,
        minTopicsCreated: 2,
        minLikesGiven: 10,
        minLikesReceived: 5,
        minRepliesReceived: 0,
        minTimeSpentMinutes: 60,
        canPost: true,
        canReply: true,
        canLike: true,
        canFlag: true,
        canEditOwnPosts: true,
        canDeleteOwnPosts: true,
        canUploadImages: true,
        canPostLinks: true,
        canMentionUsers: true,
        canSendMessages: true,
        canCreatePolls: true,
        canCreateWiki: false,
        maxPostsPerDay: 20,
        maxTopicsPerDay: 5,
        maxLikesPerDay: 50,
        maxFlagsPerDay: 5,
        createdAt: nil,
    )

    static let regular = ForumTrustLevel(
        level: 3,
        name: "Regular",
        description: "Trusted community member with proven track record.",
        color: "#A78BFA",
        minDaysSinceJoin: 30,
        minPostsRead: 200,
        minTopicsRead: 50,
        minPostsCreated: 20,
        minTopicsCreated: 5,
        minLikesGiven: 50,
        minLikesReceived: 20,
        minRepliesReceived: 0,
        minTimeSpentMinutes: 300,
        canPost: true,
        canReply: true,
        canLike: true,
        canFlag: true,
        canEditOwnPosts: true,
        canDeleteOwnPosts: true,
        canUploadImages: true,
        canPostLinks: true,
        canMentionUsers: true,
        canSendMessages: true,
        canCreatePolls: true,
        canCreateWiki: false,
        maxPostsPerDay: 50,
        maxTopicsPerDay: 10,
        maxLikesPerDay: 100,
        maxFlagsPerDay: 10,
        createdAt: nil,
    )

    static let leader = ForumTrustLevel(
        level: 4,
        name: "Leader",
        description: "Community leader who helps moderate and guide discussions.",
        color: "#F59E0B",
        minDaysSinceJoin: 90,
        minPostsRead: 500,
        minTopicsRead: 100,
        minPostsCreated: 50,
        minTopicsCreated: 15,
        minLikesGiven: 100,
        minLikesReceived: 50,
        minRepliesReceived: 0,
        minTimeSpentMinutes: 1000,
        canPost: true,
        canReply: true,
        canLike: true,
        canFlag: true,
        canEditOwnPosts: true,
        canDeleteOwnPosts: true,
        canUploadImages: true,
        canPostLinks: true,
        canMentionUsers: true,
        canSendMessages: true,
        canCreatePolls: true,
        canCreateWiki: false,
        maxPostsPerDay: 100,
        maxTopicsPerDay: 20,
        maxLikesPerDay: 200,
        maxFlagsPerDay: 20,
        createdAt: nil,
    )
}

// MARK: - Trust Level Progress

/// Progress towards a trust level
struct TrustLevelProgress: Sendable {
    let trustLevel: ForumTrustLevel
    let requirements: [RequirementProgress]

    /// Overall progress percentage (0.0 to 1.0)
    var overallProgress: Double {
        guard !requirements.isEmpty else { return 1.0 }
        let totalProgress = requirements.reduce(0.0) { $0 + $1.progress }
        return totalProgress / Double(requirements.count)
    }

    /// Whether all requirements are met
    var isComplete: Bool {
        requirements.allSatisfy(\.isMet)
    }

    /// Incomplete requirements
    var incompleteRequirements: [RequirementProgress] {
        requirements.filter { !$0.isMet }
    }
}

/// Progress for a single requirement
struct RequirementProgress: Identifiable, Sendable {
    let name: String
    let current: Int
    let required: Int
    let icon: String

    var id: String { name }

    /// Progress percentage (0.0 to 1.0, capped at 1.0)
    var progress: Double {
        guard required > 0 else { return 1.0 }
        return min(1.0, Double(current) / Double(required))
    }

    /// Whether this requirement is met
    var isMet: Bool {
        current >= required
    }

    /// Display string
    var displayText: String {
        "\(current)/\(required)"
    }
}

// MARK: - Reputation History

/// Represents a reputation change event
struct ReputationHistoryItem: Codable, Identifiable, Sendable {
    let id: UUID
    let profileId: UUID
    let changeAmount: Int
    let reason: ReputationReason
    let sourceType: String?
    let sourceId: Int?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case changeAmount = "change_amount"
        case reason
        case sourceType = "source_type"
        case sourceId = "source_id"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        profileId = try container.decode(UUID.self, forKey: .profileId)
        changeAmount = try container.decodeIfPresent(Int.self, forKey: .changeAmount) ?? 0
        reason = try container.decodeIfPresent(ReputationReason.self, forKey: .reason) ?? .bonus
        sourceType = try container.decodeIfPresent(String.self, forKey: .sourceType)
        sourceId = try container.decodeIfPresent(Int.self, forKey: .sourceId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    init(id: UUID, profileId: UUID, changeAmount: Int, reason: ReputationReason, sourceType: String?, sourceId: Int?, createdAt: Date) {
        self.id = id
        self.profileId = profileId
        self.changeAmount = changeAmount
        self.reason = reason
        self.sourceType = sourceType
        self.sourceId = sourceId
        self.createdAt = createdAt
    }
}

/// Reasons for reputation changes
enum ReputationReason: String, Codable, Sendable {
    case postCreated = "post_created"
    case commentCreated = "comment_created"
    case reactionReceived = "reaction_received"
    case markedHelpful = "marked_helpful"
    case bestAnswer = "best_answer"
    case postLiked = "post_liked"
    case flagAccepted = "flag_accepted"
    case modAction = "mod_action"
    case bonus

    var displayName: String {
        switch self {
        case .postCreated: "Created a post"
        case .commentCreated: "Added a comment"
        case .reactionReceived: "Received a reaction"
        case .markedHelpful: "Marked as helpful"
        case .bestAnswer: "Best answer"
        case .postLiked: "Post was liked"
        case .flagAccepted: "Flag accepted"
        case .modAction: "Moderator action"
        case .bonus: "Bonus"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .postCreated: t.t("forum.reputation.post_created")
        case .commentCreated: t.t("forum.reputation.comment_added")
        case .reactionReceived: t.t("forum.reputation.reaction_received")
        case .markedHelpful: t.t("forum.reputation.marked_helpful")
        case .bestAnswer: t.t("forum.reputation.best_answer")
        case .postLiked: t.t("forum.reputation.post_liked")
        case .flagAccepted: t.t("forum.reputation.flag_accepted")
        case .modAction: t.t("forum.reputation.moderator_action")
        case .bonus: t.t("forum.reputation.bonus")
        }
    }

    var icon: String {
        switch self {
        case .postCreated: "square.and.pencil"
        case .commentCreated: "text.bubble.fill"
        case .reactionReceived: "face.smiling.fill"
        case .markedHelpful: "hand.thumbsup.fill"
        case .bestAnswer: "checkmark.seal.fill"
        case .postLiked: "heart.fill"
        case .flagAccepted: "flag.fill"
        case .modAction: "shield.fill"
        case .bonus: "gift.fill"
        }
    }

    var isPositive: Bool {
        switch self {
        case .modAction: false
        default: true
        }
    }
}

// MARK: - Static Defaults

extension ForumUserStats {
    /// Empty stats for use as fallback in production code
    static let empty = ForumUserStats(
        profileId: UUID(),
        postsCount: 0,
        commentsCount: 0,
        reactionsReceived: 0,
        helpfulCount: 0,
        reputationScore: 0,
        joinedForumAt: nil,
        lastPostAt: nil,
        lastCommentAt: nil,
        updatedAt: nil,
        followersCount: 0,
        followingCount: 0,
        trustLevel: 0,
        topicsRead: 0,
        postsRead: 0,
        timeSpentMinutes: 0,
        likesGiven: 0,
        likesReceived: 0,
        repliesReceived: 0,
        flagsAgreed: 0,
        wasWarned: false,
        wasSilenced: false,
        silencedUntil: nil,
        trustLevelLocked: false
    )

    /// Empty stats with specific profile ID for use as fallback
    static func empty(for profileId: UUID) -> ForumUserStats {
        ForumUserStats(
            profileId: profileId,
            postsCount: 0,
            commentsCount: 0,
            reactionsReceived: 0,
            helpfulCount: 0,
            reputationScore: 0,
            joinedForumAt: nil,
            lastPostAt: nil,
            lastCommentAt: nil,
            updatedAt: nil,
            followersCount: 0,
            followingCount: 0,
            trustLevel: 0,
            topicsRead: 0,
            postsRead: 0,
            timeSpentMinutes: 0,
            likesGiven: 0,
            likesReceived: 0,
            repliesReceived: 0,
            flagsAgreed: 0,
            wasWarned: false,
            wasSilenced: false,
            silencedUntil: nil,
            trustLevelLocked: false
        )
    }
}

// MARK: - Fixtures

#if DEBUG
    extension ForumUserStats {
        static func fixture(
            profileId: UUID = UUID(),
            reputationScore: Int = 150,
            trustLevel: Int = 1,
            postsCount: Int = 12,
            commentsCount: Int = 45,
        ) -> ForumUserStats {
            ForumUserStats(
                profileId: profileId,
                postsCount: postsCount,
                commentsCount: commentsCount,
                reactionsReceived: 28,
                helpfulCount: 5,
                reputationScore: reputationScore,
                joinedForumAt: Date().addingTimeInterval(-30 * 24 * 60 * 60),
                lastPostAt: Date().addingTimeInterval(-1 * 24 * 60 * 60),
                lastCommentAt: Date().addingTimeInterval(-2 * 60 * 60),
                updatedAt: Date(),
                followersCount: 15,
                followingCount: 23,
                trustLevel: trustLevel,
                topicsRead: 120,
                postsRead: 450,
                timeSpentMinutes: 180,
                likesGiven: 89,
                likesReceived: 156,
                repliesReceived: 34,
                flagsAgreed: 2,
                wasWarned: false,
                wasSilenced: false,
                silencedUntil: nil,
                trustLevelLocked: false,
            )
        }
    }

    extension ForumTrustLevel {
        /// Default trust levels for testing
        static let allLevels: [ForumTrustLevel] = [
            fixture(level: 0, name: "New", color: "#95A5A6"),
            fixture(level: 1, name: "Basic", color: "#3498DB"),
            fixture(level: 2, name: "Member", color: "#27AE60"),
            fixture(level: 3, name: "Regular", color: "#9B59B6"),
            fixture(level: 4, name: "Leader", color: "#F1C40F")
        ]

        static func fixture(
            level: Int = 1,
            name: String = "Basic",
            description: String = "Basic community member",
            color: String = "#3498DB",
        ) -> ForumTrustLevel {
            ForumTrustLevel(
                level: level,
                name: name,
                description: description,
                color: color,
                minDaysSinceJoin: level * 5,
                minPostsRead: level * 20,
                minTopicsRead: level * 10,
                minPostsCreated: level * 2,
                minTopicsCreated: level,
                minLikesGiven: level * 5,
                minLikesReceived: level * 3,
                minRepliesReceived: level * 2,
                minTimeSpentMinutes: level * 30,
                canPost: level >= 0,
                canReply: level >= 0,
                canLike: level >= 0,
                canFlag: level >= 1,
                canEditOwnPosts: level >= 0,
                canDeleteOwnPosts: level >= 1,
                canUploadImages: level >= 1,
                canPostLinks: level >= 1,
                canMentionUsers: level >= 1,
                canSendMessages: level >= 1,
                canCreatePolls: level >= 2,
                canCreateWiki: level >= 3,
                maxPostsPerDay: 10 + (level * 10),
                maxTopicsPerDay: 3 + (level * 2),
                maxLikesPerDay: 20 + (level * 20),
                maxFlagsPerDay: 3 + level,
                createdAt: Date(),
            )
        }
    }
#endif


#endif
