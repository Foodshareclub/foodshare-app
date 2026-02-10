package com.foodshare.features.challenges.data.repository

import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.network.RPCConfig
import com.foodshare.features.challenges.data.dto.*
import com.foodshare.features.challenges.domain.model.*
import com.foodshare.features.challenges.domain.repository.ChallengeRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of ChallengeRepository.
 *
 * SYNC: This mirrors Swift SupabaseChallengeRepository
 */
@Singleton
class SupabaseChallengeRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val rpcClient: RateLimitedRPCClient
) : ChallengeRepository {

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    override suspend fun getPublishedChallenges(): Result<List<Challenge>> = runCatching {
        supabaseClient.from("challenges")
            .select {
                filter { eq("challenge_published", true) }
                order("challenge_created_at", Order.DESCENDING)
            }
            .decodeList<ChallengeDto>()
            .map { it.toDomain() }
    }

    override suspend fun getUserChallenges(userId: String): Result<List<ChallengeWithStatus>> = runCatching {
        supabaseClient.from("challenges")
            .select(Columns.raw(CHALLENGE_WITH_ACTIVITY_SELECT)) {
                filter { eq("challenge_published", true) }
                order("challenge_created_at", Order.DESCENDING)
            }
            .decodeList<ChallengeWithActivityDto>()
            .map { it.toDomain(userId) }
    }

    override suspend fun getUserChallengesWithCounts(userId: String): Result<UserChallengesWithCountsResult> {
        val params = GetUserChallengesParams(userId = userId)

        return rpcClient.call<GetUserChallengesParams, UserChallengesWithCountsResponse>(
            functionName = "get_user_challenges_with_counts",
            params = params,
            config = RPCConfig.normal
        ).map { response ->
            UserChallengesWithCountsResult(
                challenges = response.challenges.map { it.toDomain(userId) },
                joinedCount = response.joinedCount,
                completedCount = response.completedCount
            )
        }
    }

    override suspend fun getChallenge(id: Int, userId: String): Result<ChallengeWithStatus> = runCatching {
        supabaseClient.from("challenges")
            .select(Columns.raw(CHALLENGE_WITH_ACTIVITY_SELECT)) {
                filter { eq("id", id) }
                limit(1)
            }
            .decodeSingleOrNull<ChallengeWithActivityDto>()
            ?.toDomain(userId)
            ?: throw NoSuchElementException("Challenge not found")
    }

    override suspend fun acceptChallenge(challengeId: Int, userId: String): Result<ChallengeActivity> = runCatching {
        // Check if activity exists
        val existing = supabaseClient.from("challenge_activities")
            .select {
                filter {
                    eq("challenge_id", challengeId)
                    or {
                        eq("user_accepted_challenge", userId)
                        eq("user_rejected_challenge", userId)
                        eq("user_completed_challenge", userId)
                    }
                }
                limit(1)
            }
            .decodeSingleOrNull<ChallengeActivityDto>()

        if (existing != null) {
            // Update existing
            supabaseClient.from("challenge_activities")
                .update(mapOf(
                    "user_accepted_challenge" to userId,
                    "user_rejected_challenge" to null,
                    "user_completed_challenge" to null
                )) {
                    filter { eq("id", existing.id) }
                    select()
                }
                .decodeSingle<ChallengeActivityDto>()
                .toDomain()
        } else {
            // Create new
            supabaseClient.from("challenge_activities")
                .insert(mapOf(
                    "challenge_id" to challengeId,
                    "user_accepted_challenge" to userId
                )) {
                    select()
                }
                .decodeSingle<ChallengeActivityDto>()
                .toDomain()
        }
    }

    override suspend fun completeChallenge(challengeId: Int, userId: String): Result<ChallengeActivity> = runCatching {
        // Find user's activity for this challenge
        val existing = supabaseClient.from("challenge_activities")
            .select {
                filter {
                    eq("challenge_id", challengeId)
                    eq("user_accepted_challenge", userId)
                }
                limit(1)
            }
            .decodeSingleOrNull<ChallengeActivityDto>()
            ?: throw IllegalStateException("Must accept challenge before completing")

        supabaseClient.from("challenge_activities")
            .update(mapOf(
                "user_completed_challenge" to userId
            )) {
                filter { eq("id", existing.id) }
                select()
            }
            .decodeSingle<ChallengeActivityDto>()
            .toDomain()
    }

    override suspend fun rejectChallenge(challengeId: Int, userId: String): Result<ChallengeActivity> = runCatching {
        // Check if activity exists
        val existing = supabaseClient.from("challenge_activities")
            .select {
                filter {
                    eq("challenge_id", challengeId)
                    or {
                        eq("user_accepted_challenge", userId)
                        eq("user_rejected_challenge", userId)
                        eq("user_completed_challenge", userId)
                    }
                }
                limit(1)
            }
            .decodeSingleOrNull<ChallengeActivityDto>()

        if (existing != null) {
            // Update existing
            supabaseClient.from("challenge_activities")
                .update(mapOf(
                    "user_rejected_challenge" to userId,
                    "user_accepted_challenge" to null,
                    "user_completed_challenge" to null
                )) {
                    filter { eq("id", existing.id) }
                    select()
                }
                .decodeSingle<ChallengeActivityDto>()
                .toDomain()
        } else {
            // Create new
            supabaseClient.from("challenge_activities")
                .insert(mapOf(
                    "challenge_id" to challengeId,
                    "user_rejected_challenge" to userId
                )) {
                    select()
                }
                .decodeSingle<ChallengeActivityDto>()
                .toDomain()
        }
    }

    override suspend fun getLeaderboard(challengeId: Int, limit: Int): Result<List<ChallengeLeaderboardEntry>> {
        val params = GetLeaderboardParams(
            challengeId = challengeId,
            limit = limit
        )

        return rpcClient.call<GetLeaderboardParams, List<LeaderboardEntryDto>>(
            functionName = "get_challenge_leaderboard",
            params = params,
            config = RPCConfig.bulk
        ).map { entries ->
            entries.map { it.toDomain() }
        }
    }

    override suspend fun toggleLike(challengeId: Int, userId: String): Result<Pair<Boolean, Int>> {
        val params = ToggleLikeParams(
            challengeId = challengeId,
            profileId = userId
        )

        return rpcClient.call<ToggleLikeParams, ToggleLikeResponse>(
            functionName = "toggle_challenge_like",
            params = params,
            config = RPCConfig.normal
        ).map { response ->
            Pair(response.isLiked, response.likeCount)
        }
    }

    override suspend fun hasLiked(challengeId: Int, userId: String): Result<Boolean> = runCatching {
        val count = supabaseClient.from("challenge_likes")
            .select {
                filter {
                    eq("challenge_id", challengeId)
                    eq("profile_id", userId)
                }
                limit(1)
            }
            .decodeList<Any>()
            .size

        count > 0
    }

    companion object {
        private const val CHALLENGE_WITH_ACTIVITY_SELECT = """
            *,
            challenge_activities(*)
        """
    }
}

// RPC Parameter classes

@Serializable
private data class GetUserChallengesParams(
    @SerialName("p_user_id") val userId: String
)

@Serializable
private data class GetLeaderboardParams(
    @SerialName("p_challenge_id") val challengeId: Int,
    @SerialName("p_limit") val limit: Int = 10
)

@Serializable
private data class ToggleLikeParams(
    @SerialName("p_challenge_id") val challengeId: Int,
    @SerialName("p_profile_id") val profileId: String
)
