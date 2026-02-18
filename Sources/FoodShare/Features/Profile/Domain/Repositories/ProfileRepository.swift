
#if !SKIP
import Foundation

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

#endif
