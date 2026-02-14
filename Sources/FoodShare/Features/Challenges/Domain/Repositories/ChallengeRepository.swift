//
//  ChallengeRepository.swift
//  Foodshare
//
//  Repository protocol for challenge operations
//

import Foundation

// MARK: - User Challenges with Counts Result

struct UserChallengesWithCountsResult: Sendable {
    let challenges: [ChallengeWithStatus]
    let joinedCount: Int
    let completedCount: Int

    static let empty = UserChallengesWithCountsResult(
        challenges: [],
        joinedCount: 0,
        completedCount: 0,
    )
}

protocol ChallengeRepository: Sendable {
    // MARK: - Fetch Challenges

    /// Fetch all published challenges
    func fetchPublishedChallenges() async throws -> [Challenge]

    /// Fetch challenges user has accepted
    func fetchUserChallenges(userId: UUID) async throws -> [ChallengeWithStatus]

    /// Fetch challenges user has accepted with pre-computed counts
    func fetchUserChallengesWithCounts(userId: UUID) async throws -> UserChallengesWithCountsResult

    /// Fetch a single challenge with user status
    func fetchChallenge(id: Int, userId: UUID) async throws -> ChallengeWithStatus

    // MARK: - Participation

    /// Accept a challenge
    func acceptChallenge(challengeId: Int, userId: UUID) async throws -> ChallengeActivity

    /// Complete a challenge
    func completeChallenge(challengeId: Int, userId: UUID) async throws -> ChallengeActivity

    /// Reject a challenge
    func rejectChallenge(challengeId: Int, userId: UUID) async throws -> ChallengeActivity

    // MARK: - Leaderboard

    /// Fetch challenge leaderboard (users who completed)
    func fetchLeaderboard(challengeId: Int, limit: Int) async throws -> [ChallengeLeaderboardEntry]

    // MARK: - Likes

    /// Toggle like on a challenge, returns new like state and count
    func toggleChallengeLike(challengeId: Int, profileId: UUID) async throws -> (isLiked: Bool, likeCount: Int)

    /// Check if user has liked a challenge
    func hasLikedChallenge(challengeId: Int, profileId: UUID) async throws -> Bool
}

// MARK: - Leaderboard Entry

struct ChallengeLeaderboardEntry: Codable, Identifiable, Sendable {
    let id: UUID
    let nickname: String
    let avatarUrl: String?
    let rank: Int
    let isCompleted: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case avatarUrl = "avatar_url"
        case rank
        case isCompleted = "is_completed"
    }
}

#if DEBUG

    extension ChallengeLeaderboardEntry {
        static func fixture(
            id: UUID = UUID(),
            nickname: String = "FoodHero",
            avatarUrl: String? = nil,
            rank: Int = 1,
            isCompleted: Bool = true,
        ) -> ChallengeLeaderboardEntry {
            ChallengeLeaderboardEntry(
                id: id,
                nickname: nickname,
                avatarUrl: avatarUrl,
                rank: rank,
                isCompleted: isCompleted,
            )
        }
    }

#endif
