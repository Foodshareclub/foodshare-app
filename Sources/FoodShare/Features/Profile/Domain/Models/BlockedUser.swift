//
//  BlockedUser.swift
//  Foodshare
//
//  Model for blocked users
//

import Foundation

/// Represents a blocked user
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

/// DTO for blocked user from backend
public struct BlockedUserDTO: Codable, Sendable {
    public let id: String
    public let blockedUserId: String
    public let blockedAt: String
    public let reason: String?

    /// Joined profile data
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
