import FoodShareRepository
import Foundation
import OSLog
import Supabase

// MARK: - Supabase Forum Reputation Repository

/// Handles forum badges, stats, trust levels, subscriptions, notifications, and reputation
@MainActor
final class SupabaseForumReputationRepository: BaseSupabaseRepository, @unchecked Sendable {
    init(supabase: Supabase.SupabaseClient) {
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ForumReputationRepository")
    }

    // MARK: - Reputation & Trust Levels

    func fetchUserStats(profileId: UUID) async throws -> ForumUserStats {
        try await supabase
            .from("forum_user_stats")
            .select()
            .eq("profile_id", value: profileId)
            .single()
            .execute()
            .value
    }

    func fetchOrCreateUserStats(profileId: UUID) async throws -> ForumUserStats {
        do {
            // Try to fetch existing stats
            let existing: [ForumUserStats] = try await supabase
                .from("forum_user_stats")
                .select()
                .eq("profile_id", value: profileId)
                .execute()
                .value

            if let stats = existing.first {
                return stats
            }

            // Create new stats entry
            return try await supabase
                .from("forum_user_stats")
                .insert(UserStatsInsertDTO(profile_id: profileId.uuidString))
                .select()
                .single()
                .execute()
                .value
        } catch {
            // Return empty stats with correct profileId as fallback
            logger.warning("Failed to fetch/create user stats: \(error.localizedDescription)")
            return ForumUserStats.empty(for: profileId)
        }
    }

    func fetchTrustLevels() async throws -> [ForumTrustLevel] {
        try await supabase
            .from("forum_trust_levels")
            .select()
            .order("level", ascending: true)
            .execute()
            .value
    }

    func fetchTrustLevel(level: Int) async throws -> ForumTrustLevel {
        try await supabase
            .from("forum_trust_levels")
            .select()
            .eq("level", value: level)
            .single()
            .execute()
            .value
    }

    func fetchReputationHistory(profileId: UUID, limit: Int) async throws -> [ReputationHistoryItem] {
        try await supabase
            .from("forum_reputation_history")
            .select()
            .eq("profile_id", value: profileId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
    }

    func incrementUserStat(profileId: UUID, stat: UserStatType, by amount: Int) async throws {
        // Use RPC to atomically increment the stat
        try await supabase.rpc(
            "increment_user_stat",
            params: IncrementStatParams(
                p_profile_id: profileId.uuidString,
                p_stat_column: stat.rawValue,
                p_amount: amount,
            ),
        ).execute()
    }

    func canPerformAction(profileId: UUID, action: TrustLevelAction) async throws -> Bool {
        // Fetch user stats to get trust level
        let stats = try await fetchOrCreateUserStats(profileId: profileId)
        let trustLevel = try await fetchTrustLevel(level: stats.trustLevel)

        // Check if action is allowed based on trust level
        switch action {
        case .createPost:
            return trustLevel.canPost
        case .createReply:
            return trustLevel.canReply
        case .uploadImage:
            return trustLevel.canUploadImages
        case .postLink:
            return trustLevel.canPostLinks
        case .mentionUser:
            return trustLevel.canMentionUsers
        case .sendMessage:
            return trustLevel.canSendMessages
        case .createPoll:
            return trustLevel.canCreatePolls
        case .deleteOwnPost:
            return trustLevel.canDeleteOwnPosts
        case .flag:
            return trustLevel.canFlag
        }
    }

    // MARK: - Badges

    func fetchBadges() async throws -> [ForumBadge] {
        try await supabase
            .from("forum_badges")
            .select()
            .eq("is_active", value: true)
            .order("badge_type", ascending: true)
            .order("points", ascending: false)
            .execute()
            .value
    }

    func fetchUserBadges(profileId: UUID) async throws -> [UserBadgeWithDetails] {
        // Fetch user badges with badge details joined
        let userBadges: [UserBadgeResponse] = try await supabase
            .from("forum_user_badges")
            .select("*, forum_badges(*)")
            .eq("profile_id", value: profileId)
            .order("awarded_at", ascending: false)
            .execute()
            .value

        return userBadges.compactMap { response in
            guard let badge = response.forum_badges else { return nil }
            return UserBadgeWithDetails(
                userBadge: UserBadge(
                    id: response.id,
                    profileId: response.profile_id,
                    badgeId: response.badge_id,
                    awardedAt: response.awarded_at,
                    awardedBy: response.awarded_by,
                    isFeatured: response.is_featured ?? false,
                ),
                badge: badge,
            )
        }
    }

    func fetchBadgeCollection(profileId: UUID) async throws -> BadgeCollection {
        do {
            // Single RPC call replaces 2 separate queries
            let params = BadgeCollectionParams(pProfileId: profileId)

            let response = try await supabase
                .rpc("get_badge_collection", params: params)
                .execute()

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let dto = try decoder.decode(BadgeCollectionDTO.self, from: response.data)

            let allBadges = dto.allBadges
            let earnedBadges = dto.earnedBadges.map { item in
                UserBadgeWithDetails(
                    userBadge: UserBadge(
                        id: item.userBadge.id,
                        profileId: item.userBadge.profileId,
                        badgeId: item.userBadge.badgeId,
                        awardedAt: item.userBadge.awardedAt,
                        awardedBy: item.userBadge.awardedBy,
                        isFeatured: item.userBadge.isFeatured,
                    ),
                    badge: item.badge,
                )
            }

            let featuredBadges = earnedBadges.filter(\.userBadge.isFeatured)

            return BadgeCollection(
                allBadges: allBadges,
                earnedBadges: earnedBadges,
                featuredBadges: featuredBadges,
            )
        } catch {
            // Return empty collection as fallback
            logger.warning("Failed to fetch badge collection: \(error.localizedDescription)")
            return BadgeCollection(allBadges: [], earnedBadges: [], featuredBadges: [])
        }
    }

    func hasEarnedBadge(profileId: UUID, badgeId: Int) async throws -> Bool {
        let existing: [UserBadge] = try await supabase
            .from("forum_user_badges")
            .select("id")
            .eq("profile_id", value: profileId)
            .eq("badge_id", value: badgeId)
            .limit(1)
            .execute()
            .value

        return !existing.isEmpty
    }

    func awardBadge(badgeId: Int, to profileId: UUID, by awarderId: UUID?) async throws -> UserBadge {
        // Check if already earned
        let alreadyEarned = try await hasEarnedBadge(profileId: profileId, badgeId: badgeId)
        if alreadyEarned {
            throw BadgeError.alreadyEarned
        }

        let insertDTO = UserBadgeInsertDTO(
            profile_id: profileId.uuidString,
            badge_id: badgeId,
            awarded_by: awarderId?.uuidString,
        )

        return try await supabase
            .from("forum_user_badges")
            .insert(insertDTO)
            .select()
            .single()
            .execute()
            .value
    }

    func toggleFeaturedBadge(userBadgeId: UUID, profileId: UUID) async throws -> Bool {
        // Fetch current state
        let existing: UserBadge = try await supabase
            .from("forum_user_badges")
            .select()
            .eq("id", value: userBadgeId)
            .eq("profile_id", value: profileId)
            .single()
            .execute()
            .value

        let newFeaturedState = !existing.isFeatured

        // Update
        try await supabase
            .from("forum_user_badges")
            .update(["is_featured": newFeaturedState])
            .eq("id", value: userBadgeId)
            .execute()

        return newFeaturedState
    }

    func fetchNextBadges(profileId: UUID, limit: Int) async throws -> [(badge: ForumBadge, progress: Double)] {
        // Fetch user stats and all badges
        async let statsTask = fetchOrCreateUserStats(profileId: profileId)
        async let badgesTask = fetchBadges()
        async let earnedTask = fetchUserBadges(profileId: profileId)

        let (stats, allBadges, earnedBadges) = try await (statsTask, badgesTask, earnedTask)

        let earnedIds = Set(earnedBadges.map(\.badge.id))

        // Filter to badges not yet earned with criteria
        let unearnedWithProgress: [(badge: ForumBadge, progress: Double)] = allBadges
            .filter { !earnedIds.contains($0.id) && $0.hasAutoCriteria }
            .map { badge in
                let progress = badge.criteria?.progress(for: stats) ?? 0.0
                return (badge: badge, progress: progress)
            }
            .sorted { $0.progress > $1.progress }
            .prefix(limit)
            .map(\.self)

        return Array(unearnedWithProgress)
    }

    // MARK: - Subscriptions

    func fetchPostSubscription(forumId: Int, profileId: UUID) async throws -> ForumSubscription? {
        let response: [ForumSubscription] = try await supabase
            .from("forum_subscriptions")
            .select()
            .eq("profile_id", value: profileId.uuidString)
            .eq("forum_id", value: forumId)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    func fetchCategorySubscription(categoryId: Int, profileId: UUID) async throws -> ForumSubscription? {
        let response: [ForumSubscription] = try await supabase
            .from("forum_subscriptions")
            .select()
            .eq("profile_id", value: profileId.uuidString)
            .eq("category_id", value: categoryId)
            .is("forum_id", value: nil)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    func fetchSubscriptions(profileId: UUID) async throws -> [ForumSubscription] {
        try await supabase
            .from("forum_subscriptions")
            .select()
            .eq("profile_id", value: profileId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    func subscribeToPost(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription {
        // Check if already subscribed
        if let forumId = request.forumId {
            if let existing = try await fetchPostSubscription(forumId: forumId, profileId: request.profileId) {
                return existing
            }
        }

        return try await supabase
            .from("forum_subscriptions")
            .insert(request)
            .select()
            .single()
            .execute()
            .value
    }

    func subscribeToCategory(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription {
        // Check if already subscribed
        if let categoryId = request.categoryId {
            if let existing = try await fetchCategorySubscription(
                categoryId: categoryId,
                profileId: request.profileId,
            ) {
                return existing
            }
        }

        return try await supabase
            .from("forum_subscriptions")
            .insert(request)
            .select()
            .single()
            .execute()
            .value
    }

    func unsubscribeFromPost(forumId: Int, profileId: UUID) async throws {
        try await supabase
            .from("forum_subscriptions")
            .delete()
            .eq("profile_id", value: profileId.uuidString)
            .eq("forum_id", value: forumId)
            .execute()
    }

    func unsubscribeFromCategory(categoryId: Int, profileId: UUID) async throws {
        try await supabase
            .from("forum_subscriptions")
            .delete()
            .eq("profile_id", value: profileId.uuidString)
            .eq("category_id", value: categoryId)
            .is("forum_id", value: nil)
            .execute()
    }

    func updateSubscription(id: UUID, preferences: SubscriptionPreferences) async throws -> ForumSubscription {
        let updateDTO = SubscriptionUpdateDTO(
            notify_on_reply: preferences.notifyOnReply,
            notify_on_mention: preferences.notifyOnMention,
            notify_on_reaction: preferences.notifyOnReaction,
            email_notifications: preferences.emailNotifications,
        )

        return try await supabase
            .from("forum_subscriptions")
            .update(updateDTO)
            .eq("id", value: id.uuidString)
            .select()
            .single()
            .execute()
            .value
    }

    // MARK: - Notifications

    func fetchNotifications(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumNotification] {
        try await supabase
            .from("forum_notifications")
            .select()
            .eq("recipient_id", value: profileId.uuidString)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }

    func fetchUnreadNotificationCount(profileId: UUID) async throws -> Int {
        let response: [NotificationCountResponse] = try await supabase
            .from("forum_notifications")
            .select("id", head: false, count: .exact)
            .eq("recipient_id", value: profileId.uuidString)
            .eq("is_read", value: false)
            .execute()
            .value

        return response.count
    }

    func markNotificationAsRead(id: UUID) async throws {
        try await supabase
            .from("forum_notifications")
            .update(["is_read": true])
            .eq("id", value: id.uuidString)
            .execute()
    }

    func markAllNotificationsAsRead(profileId: UUID) async throws {
        try await supabase
            .from("forum_notifications")
            .update(["is_read": true])
            .eq("recipient_id", value: profileId.uuidString)
            .eq("is_read", value: false)
            .execute()
    }

    func deleteNotification(id: UUID) async throws {
        try await supabase
            .from("forum_notifications")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func deleteReadNotifications(profileId: UUID) async throws {
        try await supabase
            .from("forum_notifications")
            .delete()
            .eq("recipient_id", value: profileId.uuidString)
            .eq("is_read", value: true)
            .execute()
    }
}

// MARK: - Reputation DTOs

private struct UserStatsInsertDTO: Encodable {
    let profile_id: String
}

private struct IncrementStatParams: Encodable {
    let p_profile_id: String
    let p_stat_column: String
    let p_amount: Int
}

// MARK: - Badge DTOs

private struct UserBadgeResponse: Codable {
    let id: UUID
    let profile_id: UUID
    let badge_id: Int
    let awarded_at: Date?
    let awarded_by: UUID?
    let is_featured: Bool?
    let forum_badges: ForumBadge?
}

private struct UserBadgeInsertDTO: Encodable {
    let profile_id: String
    let badge_id: Int
    let awarded_by: String?
}

/// Parameters for the get_badge_collection RPC
private struct BadgeCollectionParams: Encodable {
    let pProfileId: UUID

    enum CodingKeys: String, CodingKey {
        case pProfileId = "p_profile_id"
    }
}

/// DTO for decoding the get_badge_collection RPC response
private struct BadgeCollectionDTO: Decodable {
    let allBadges: [ForumBadge]
    let earnedBadges: [EarnedBadgeDTO]

    enum CodingKeys: String, CodingKey {
        case allBadges = "all_badges"
        case earnedBadges = "earned_badges"
    }
}

private struct EarnedBadgeDTO: Decodable {
    let userBadge: UserBadgeDTO
    let badge: ForumBadge

    enum CodingKeys: String, CodingKey {
        case userBadge = "user_badge"
        case badge
    }
}

private struct UserBadgeDTO: Decodable {
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
}

// MARK: - Badge Errors

/// Errors that can occur during badge operations.
///
/// Thread-safe for Swift 6 concurrency.
enum BadgeError: LocalizedError, Sendable {
    /// User already has this badge
    case alreadyEarned
    /// Badge does not exist
    case badgeNotFound
    /// User doesn't own this badge
    case notOwned

    var errorDescription: String? {
        switch self {
        case .alreadyEarned:
            "You have already earned this badge"
        case .badgeNotFound:
            "Badge not found"
        case .notOwned:
            "You do not own this badge"
        }
    }
}

// MARK: - Subscription DTOs

private struct SubscriptionUpdateDTO: Encodable {
    let notify_on_reply: Bool
    let notify_on_mention: Bool
    let notify_on_reaction: Bool
    let email_notifications: Bool
}

private struct NotificationCountResponse: Codable {
    let id: UUID
}
