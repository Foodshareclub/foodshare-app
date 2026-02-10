package com.foodshare.features.challenges.domain.repository

import com.foodshare.features.challenges.domain.model.*

/**
 * Repository interface for challenge operations.
 *
 * SYNC: This mirrors Swift ChallengeRepository protocol
 */
interface ChallengeRepository {
    /**
     * Fetch all published challenges.
     */
    suspend fun getPublishedChallenges(): Result<List<Challenge>>

    /**
     * Fetch challenges for a specific user with their status.
     */
    suspend fun getUserChallenges(userId: String): Result<List<ChallengeWithStatus>>

    /**
     * Fetch user challenges with joined/completed counts.
     */
    suspend fun getUserChallengesWithCounts(userId: String): Result<UserChallengesWithCountsResult>

    /**
     * Fetch a specific challenge with user's status.
     */
    suspend fun getChallenge(id: Int, userId: String): Result<ChallengeWithStatus>

    /**
     * Accept a challenge (mark as joined).
     */
    suspend fun acceptChallenge(challengeId: Int, userId: String): Result<ChallengeActivity>

    /**
     * Mark a challenge as completed.
     */
    suspend fun completeChallenge(challengeId: Int, userId: String): Result<ChallengeActivity>

    /**
     * Reject/skip a challenge.
     */
    suspend fun rejectChallenge(challengeId: Int, userId: String): Result<ChallengeActivity>

    /**
     * Fetch leaderboard for a challenge.
     */
    suspend fun getLeaderboard(challengeId: Int, limit: Int = 10): Result<List<ChallengeLeaderboardEntry>>

    /**
     * Toggle like on a challenge.
     * @return Pair of (isLiked, newLikeCount)
     */
    suspend fun toggleLike(challengeId: Int, userId: String): Result<Pair<Boolean, Int>>

    /**
     * Check if user has liked a challenge.
     */
    suspend fun hasLiked(challengeId: Int, userId: String): Result<Boolean>
}
