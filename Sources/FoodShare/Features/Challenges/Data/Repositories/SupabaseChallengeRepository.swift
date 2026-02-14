//
//  SupabaseChallengeRepository.swift
//  Foodshare
//
//  Supabase implementation of ChallengeRepository
//  Connects to `challenges` and `challenge_activities` tables
//
// TODO: Migrate to api-v1-challenges when backend endpoint is created.
// No corresponding Edge Function exists. Direct Supabase access is acceptable.

import FoodShareRepository
import Foundation
import Supabase

/// Supabase implementation of ChallengeRepository
@MainActor
final class SupabaseChallengeRepository: BaseSupabaseRepository, ChallengeRepository {

    init(supabase: Supabase.SupabaseClient) {
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ChallengeRepository")
    }

    // MARK: - Fetch Challenges

    func fetchPublishedChallenges() async throws -> [Challenge] {
        do {
            let response = try await supabase
                .from("challenges")
                .select()
                .eq("challenge_published", value: true)
                .order("challenge_created_at", ascending: false)
                .execute()

            return try decoder.decode([Challenge].self, from: response.data)
        } catch {
            throw mapError(error)
        }
    }

    func fetchUserChallenges(userId: UUID) async throws -> [ChallengeWithStatus] {
        // Fetch activities where user has accepted
        let activitiesResponse = try await supabase
            .from("challenge_activities")
            .select("*, challenges(*)")
            .eq("user_accepted_challenge", value: userId.uuidString)
            .execute()

        let activitiesWithChallenges = try decoder.decode(
            [ChallengeActivityWithChallenge].self,
            from: activitiesResponse.data,
        )

        return activitiesWithChallenges.map { item in
            ChallengeWithStatus(
                challenge: item.challenge,
                activity: item.toActivity(),
                userId: userId,
            )
        }
    }

    func fetchUserChallengesWithCounts(userId: UUID) async throws -> UserChallengesWithCountsResult {
        let params = UserChallengesParams(pUserId: userId)

        do {
            let response = try await supabase
                .rpc("get_user_challenges_with_counts", params: params)
                .execute()

            // Check for empty data (RPC might not exist or return null)
            guard !response.data.isEmpty else {
                logger.warning("RPC returned empty data for user challenges")
                return UserChallengesWithCountsResult(challenges: [], joinedCount: 0, completedCount: 0)
            }

            let dto = try decoder.decode(UserChallengesWithCountsDTO.self, from: response.data)

            let challenges = dto.challenges.map { item in
                ChallengeWithStatus(
                    challenge: item.challenge,
                    activity: item.activity.toChallengeActivity(),
                    userId: userId,
                )
            }

            return UserChallengesWithCountsResult(
                challenges: challenges,
                joinedCount: dto.joinedCount,
                completedCount: dto.completedCount,
            )
        } catch let decodingError as DecodingError {
            logger.error("Failed to decode user challenges: \(decodingError)")
            // Return empty result instead of crashing - graceful degradation
            return UserChallengesWithCountsResult(challenges: [], joinedCount: 0, completedCount: 0)
        } catch {
            throw mapError(error)
        }
    }

    func fetchChallenge(id: Int, userId: UUID) async throws -> ChallengeWithStatus {
        // Fetch challenge
        let challengeResponse = try await supabase
            .from("challenges")
            .select()
            .eq("id", value: id)
            .single()
            .execute()

        let challenge = try decoder.decode(Challenge.self, from: challengeResponse.data)

        // Fetch user's activity for this challenge (if any)
        let activities: [ChallengeActivity] = try await supabase
            .from("challenge_activities")
            .select()
            .eq("challenge_id", value: id)
            .or("user_accepted_challenge.eq.\(userId.uuidString),user_completed_challenge.eq.\(userId.uuidString)")
            .limit(1)
            .execute()
            .value

        let activity = activities.first

        return ChallengeWithStatus(challenge: challenge, activity: activity, userId: userId)
    }

    // MARK: - Participation

    func acceptChallenge(challengeId: Int, userId: UUID) async throws -> ChallengeActivity {
        // Check if activity exists for this challenge
        let existingActivities: [ChallengeActivity] = try await supabase
            .from("challenge_activities")
            .select()
            .eq("challenge_id", value: challengeId)
            .limit(1)
            .execute()
            .value

        if !existingActivities.isEmpty {
            // Activity exists, update it
            let response = try await supabase
                .from("challenge_activities")
                .update(["user_accepted_challenge": userId.uuidString])
                .eq("challenge_id", value: challengeId)
                .select()
                .single()
                .execute()

            return try decoder.decode(ChallengeActivity.self, from: response.data)
        } else {
            // Create new activity
            let params = CreateActivityParams(
                challengeId: challengeId,
                userAcceptedChallenge: userId,
            )

            let response = try await supabase
                .from("challenge_activities")
                .insert(params)
                .select()
                .single()
                .execute()

            // Increment challenged_people count
            try await incrementChallengedPeople(challengeId: challengeId)

            return try decoder.decode(ChallengeActivity.self, from: response.data)
        }
    }

    func completeChallenge(challengeId: Int, userId: UUID) async throws -> ChallengeActivity {
        let response = try await supabase
            .from("challenge_activities")
            .update(["user_completed_challenge": userId.uuidString])
            .eq("challenge_id", value: challengeId)
            .eq("user_accepted_challenge", value: userId.uuidString)
            .select()
            .single()
            .execute()

        return try decoder.decode(ChallengeActivity.self, from: response.data)
    }

    func rejectChallenge(challengeId: Int, userId: UUID) async throws -> ChallengeActivity {
        // Check if activity exists
        let existingActivities: [ChallengeActivity] = try await supabase
            .from("challenge_activities")
            .select()
            .eq("challenge_id", value: challengeId)
            .limit(1)
            .execute()
            .value

        if !existingActivities.isEmpty {
            // Update existing
            let response = try await supabase
                .from("challenge_activities")
                .update(["user_rejected_challenge": userId.uuidString])
                .eq("challenge_id", value: challengeId)
                .select()
                .single()
                .execute()

            return try decoder.decode(ChallengeActivity.self, from: response.data)
        } else {
            // Create new with rejection
            let params = CreateActivityParams(
                challengeId: challengeId,
                userRejectedChallenge: userId,
            )

            let response = try await supabase
                .from("challenge_activities")
                .insert(params)
                .select()
                .single()
                .execute()

            return try decoder.decode(ChallengeActivity.self, from: response.data)
        }
    }

    // MARK: - Leaderboard

    func fetchLeaderboard(challengeId: Int, limit: Int = 10) async throws -> [ChallengeLeaderboardEntry] {
        // Use server-side RPC with ROW_NUMBER() for accurate ranking
        let params = LeaderboardParams(
            pChallengeId: challengeId,
            pLimit: limit,
        )

        let response = try await supabase
            .rpc("get_challenge_leaderboard", params: params)
            .execute()

        return try decoder.decode([ChallengeLeaderboardEntry].self, from: response.data)
    }

    // MARK: - Private Helpers

    private func incrementChallengedPeople(challengeId: Int) async throws {
        let response = try await supabase
            .from("challenges")
            .select("challenged_people")
            .eq("id", value: challengeId)
            .single()
            .execute()

        let current = try decoder.decode(ChallengedPeopleResponse.self, from: response.data)

        try await supabase
            .from("challenges")
            .update(["challenged_people": current.challengedPeople + 1])
            .eq("id", value: challengeId)
            .execute()
    }

    // MARK: - Likes
    // Note: This repository method is called by ChallengeEngagementService
    // for consistency with PostEngagementService pattern

    /// Toggle like on a challenge
    /// - Parameters:
    ///   - challengeId: The challenge ID to like/unlike
    ///   - profileId: The user's profile ID
    /// - Returns: Tuple of (isLiked, likeCount) after the toggle operation
    /// - Note: Uses single RPC call for optimal performance (Enterprise Unified Engagement)
    func toggleChallengeLike(challengeId: Int, profileId: UUID) async throws -> (isLiked: Bool, likeCount: Int) {
        // Single RPC call - uses unified likes table
        let response = try await supabase
            .rpc("toggle_challenge_like", params: ["p_challenge_id": challengeId])
            .execute()

        let result = try JSONDecoder().decode(ToggleChallengeLikeResponse.self, from: response.data)

        guard result.success else {
            if let error = result.error {
                throw ChallengeEngagementError.networkError(error.message)
            }
            throw ChallengeEngagementError.networkError("Failed to toggle challenge like")
        }

        return (result.isLiked ?? false, result.likeCount ?? 0)
    }

    func hasLikedChallenge(challengeId: Int, profileId: UUID) async throws -> Bool {
        let existing: [ChallengeLikeRecord] = try await supabase
            .from("likes")
            .select("id")
            .eq("challenge_id", value: challengeId)
            .eq("profile_id", value: profileId.uuidString)
            .execute()
            .value

        return !existing.isEmpty
    }
}

// MARK: - Helper Structs

private struct ChallengedPeopleResponse: Decodable {
    let challengedPeople: Int
    // CodingKeys removed - BaseSupabaseRepository uses .convertFromSnakeCase
}

private struct ChallengeLikeRecord: Decodable {
    let id: Int
}

private struct ChallengeLikeInsertDTO: Encodable {
    let challengeId: Int
    let profileId: String

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case profileId = "profile_id"
    }
}

private struct ChallengeLikeCountResponse: Decodable {
    let challengeLikesCounter: Int
    // CodingKeys removed - BaseSupabaseRepository uses .convertFromSnakeCase
}

// MARK: - RPC Response Types

/// Response from toggle_challenge_like RPC
private struct ToggleChallengeLikeResponse: Decodable {
    let success: Bool
    let isLiked: Bool?
    let likeCount: Int?
    let error: RPCError?

    enum CodingKeys: String, CodingKey {
        case success
        case isLiked = "is_liked"
        case likeCount = "like_count"
        case error
    }

    struct RPCError: Decodable {
        let code: String
        let message: String
    }
}

private struct CreateActivityParams: Encodable {
    let challengeId: Int
    var userAcceptedChallenge: UUID?
    var userRejectedChallenge: UUID?
    var userCompletedChallenge: UUID?

    enum CodingKeys: String, CodingKey {
        case challengeId = "challenge_id"
        case userAcceptedChallenge = "user_accepted_challenge"
        case userRejectedChallenge = "user_rejected_challenge"
        case userCompletedChallenge = "user_completed_challenge"
    }
}

// MARK: - Response Structs for Joins

private struct ChallengeActivityWithChallenge: Decodable {
    let id: Int
    let challengeId: Int
    let createdAt: Date?
    let userAcceptedChallenge: UUID?
    let userRejectedChallenge: UUID?
    let userCompletedChallenge: UUID?
    let challenge: Challenge

    /// Only keep the key that differs from snake_case conversion
    /// (challengeId, createdAt, etc. are handled by .convertFromSnakeCase)
    enum CodingKeys: String, CodingKey {
        case id, challengeId, createdAt, userAcceptedChallenge
        case userRejectedChallenge, userCompletedChallenge
        case challenge = "challenges" // Different name, not snake_case
    }

    func toActivity() -> ChallengeActivity {
        ChallengeActivity(
            id: id,
            challengeId: challengeId,
            createdAt: createdAt ?? Date(),
            userAcceptedChallenge: userAcceptedChallenge,
            userRejectedChallenge: userRejectedChallenge,
            userCompletedChallenge: userCompletedChallenge,
        )
    }
}

private struct LeaderboardRawEntry: Decodable {
    let userCompletedChallenge: UUID?
    let profile: ProfileInfo?

    /// Only keep the key that differs from snake_case conversion
    enum CodingKeys: String, CodingKey {
        case userCompletedChallenge
        case profile = "profiles" // Different name, not snake_case
    }
}

private struct ProfileInfo: Decodable {
    let nickname: String?
    let avatarUrl: String?
    // CodingKeys removed - BaseSupabaseRepository uses .convertFromSnakeCase
}

/// Parameters for the get_challenge_leaderboard RPC
private struct LeaderboardParams: Encodable {
    let pChallengeId: Int
    let pLimit: Int

    enum CodingKeys: String, CodingKey {
        case pChallengeId = "p_challenge_id"
        case pLimit = "p_limit"
    }
}

/// Parameters for the get_user_challenges_with_counts RPC
private struct UserChallengesParams: Encodable {
    let pUserId: UUID

    enum CodingKeys: String, CodingKey {
        case pUserId = "p_user_id"
    }
}

/// DTO for decoding the get_user_challenges_with_counts RPC response
/// Note: Uses auto-synthesis with keyDecodingStrategy = .convertFromSnakeCase
private struct UserChallengesWithCountsDTO: Decodable {
    let challenges: [ChallengeWithStatusDTO]
    let joinedCount: Int
    let completedCount: Int
    // CodingKeys removed - BaseSupabaseRepository uses .convertFromSnakeCase
}

private struct ChallengeWithStatusDTO: Decodable {
    let challenge: Challenge
    let activity: ChallengeActivityDTO
    let hasAccepted: Bool
    let hasCompleted: Bool
    // CodingKeys removed - BaseSupabaseRepository uses .convertFromSnakeCase
}

private struct ChallengeActivityDTO: Decodable {
    let id: Int
    let challengeId: Int
    let profileId: UUID?
    let progress: Int?
    let acceptedAt: Date?
    let completedAt: Date?
    let rejectedAt: Date?
    let createdAt: Date?
    // CodingKeys removed - BaseSupabaseRepository uses .convertFromSnakeCase

    func toChallengeActivity() -> ChallengeActivity {
        ChallengeActivity(
            id: id,
            challengeId: challengeId,
            createdAt: createdAt ?? Date(),
            userAcceptedChallenge: acceptedAt != nil ? profileId : nil,
            userRejectedChallenge: rejectedAt != nil ? profileId : nil,
            userCompletedChallenge: completedAt != nil ? profileId : nil,
        )
    }
}
