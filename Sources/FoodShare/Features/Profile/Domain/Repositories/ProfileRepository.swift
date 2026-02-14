import Foundation

/// Temporary stub for BlockedUser until model is properly added to target
public struct BlockedUser: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public let blockedUserId: UUID
    public let blockedUserName: String
    public let blockedUserAvatar: String?
    public let blockedAt: Date
    public let reason: String?

    public init(
        id: UUID,
        blockedUserId: UUID,
        blockedUserName: String,
        blockedUserAvatar: String?,
        blockedAt: Date,
        reason: String?,
    ) {
        self.id = id
        self.blockedUserId = blockedUserId
        self.blockedUserName = blockedUserName
        self.blockedUserAvatar = blockedUserAvatar
        self.blockedAt = blockedAt
        self.reason = reason
    }
}

public struct BlockedUserDTO: Codable, Sendable {
    public let id: String
    public let blockedUserId: String
    public let blockedAt: String
    public let reason: String?
    public let profile: BlockedUserProfileDTO?

    enum CodingKeys: String, CodingKey {
        case id
        case blockedUserId = "blocked_user_id"
        case blockedAt = "blocked_at"
        case reason
        case profile = "blocked_profile"
    }

    public func toDomain() -> BlockedUser {
        BlockedUser(
            id: UUID(uuidString: id) ?? UUID(),
            blockedUserId: UUID(uuidString: blockedUserId) ?? UUID(),
            blockedUserName: profile?.nickname ?? "Unknown User",
            blockedUserAvatar: profile?.avatarUrl,
            blockedAt: ISO8601DateFormatter().date(from: blockedAt) ?? Date(),
            reason: reason,
        )
    }
}

public struct BlockedUserProfileDTO: Codable, Sendable {
    public let nickname: String
    public let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case nickname
        case avatarUrl = "avatar_url"
    }
}

protocol ProfileRepository: Sendable {
    func fetchProfile(userId: UUID) async throws -> UserProfile
    func updateProfile(userId: UUID, request: UpdateProfileRequest) async throws -> UserProfile
    func updateSearchRadius(userId: UUID, radiusKm: Int) async throws

    /// Fetch server-calculated analytics (completion, rank, impact)
    /// Single source of truth - replaces client-side calculations
    func fetchProfileAnalytics(userId: UUID) async throws -> ProfileAnalytics

    // MARK: - Address Methods

    /// Fetch user's address from user_addresses table
    func fetchAddress(profileId: UUID) async throws -> Address?

    /// Upsert (insert or update) user's address
    func upsertAddress(profileId: UUID, address: EditableAddress) async throws -> Address

    /// Delete user's address
    func deleteAddress(profileId: UUID) async throws

    // MARK: - Blocking

    /// Block a user and optionally provide a reason
    func blockUser(userId: UUID, blockedUserId: UUID, reason: String?) async throws

    /// Unblock a previously blocked user
    func unblockUser(userId: UUID, blockedUserId: UUID) async throws

    /// Get list of blocked users
    func getBlockedUsers(userId: UUID) async throws -> [BlockedUser]

    /// Check if a specific user is blocked
    func isUserBlocked(userId: UUID, targetUserId: UUID) async throws -> Bool
}
