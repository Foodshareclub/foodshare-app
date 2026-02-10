package com.foodshare.features.challenges.data.dto

import com.foodshare.features.challenges.domain.model.*
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for challenge from Supabase.
 */
@Serializable
data class ChallengeDto(
    val id: Int,
    @SerialName("profile_id") val profileId: String,
    @SerialName("challenge_title") val title: String,
    @SerialName("challenge_description") val description: String,
    @SerialName("challenge_difficulty") val difficulty: String = "easy",
    @SerialName("challenge_action") val action: String? = null,
    @SerialName("challenge_score") val score: Int = 0,
    @SerialName("challenged_people") val participantCount: Int = 0,
    @SerialName("challenge_image") val imageUrl: String? = null,
    @SerialName("challenge_views") val viewsCount: Int = 0,
    @SerialName("challenge_published") val isPublished: Boolean = true,
    @SerialName("challenge_likes_counter") val likesCount: Int = 0,
    @SerialName("challenge_created_at") val createdAt: String,
    @SerialName("challenge_updated_at") val updatedAt: String? = null
) {
    fun toDomain() = Challenge(
        id = id,
        profileId = profileId,
        title = title,
        description = description,
        difficulty = parseDifficulty(difficulty),
        action = action,
        score = score,
        participantCount = participantCount,
        imageUrl = imageUrl,
        viewsCount = viewsCount,
        isPublished = isPublished,
        likesCount = likesCount,
        createdAt = createdAt,
        updatedAt = updatedAt
    )

    private fun parseDifficulty(value: String): ChallengeDifficulty = when (value.lowercase()) {
        "medium" -> ChallengeDifficulty.MEDIUM
        "hard" -> ChallengeDifficulty.HARD
        "extreme" -> ChallengeDifficulty.EXTREME
        else -> ChallengeDifficulty.EASY
    }
}

/**
 * DTO for challenge activity from Supabase.
 */
@Serializable
data class ChallengeActivityDto(
    val id: Int,
    @SerialName("challenge_id") val challengeId: Int,
    @SerialName("created_at") val createdAt: String,
    @SerialName("user_accepted_challenge") val userAcceptedChallenge: String? = null,
    @SerialName("user_rejected_challenge") val userRejectedChallenge: String? = null,
    @SerialName("user_completed_challenge") val userCompletedChallenge: String? = null
) {
    fun toDomain() = ChallengeActivity(
        id = id,
        challengeId = challengeId,
        createdAt = createdAt,
        userAcceptedChallenge = userAcceptedChallenge,
        userRejectedChallenge = userRejectedChallenge,
        userCompletedChallenge = userCompletedChallenge
    )
}

/**
 * DTO for challenge with activity joined.
 */
@Serializable
data class ChallengeWithActivityDto(
    val id: Int,
    @SerialName("profile_id") val profileId: String,
    @SerialName("challenge_title") val title: String,
    @SerialName("challenge_description") val description: String,
    @SerialName("challenge_difficulty") val difficulty: String = "easy",
    @SerialName("challenge_action") val action: String? = null,
    @SerialName("challenge_score") val score: Int = 0,
    @SerialName("challenged_people") val participantCount: Int = 0,
    @SerialName("challenge_image") val imageUrl: String? = null,
    @SerialName("challenge_views") val viewsCount: Int = 0,
    @SerialName("challenge_published") val isPublished: Boolean = true,
    @SerialName("challenge_likes_counter") val likesCount: Int = 0,
    @SerialName("challenge_created_at") val createdAt: String,
    @SerialName("challenge_updated_at") val updatedAt: String? = null,
    @SerialName("challenge_activities") val activities: List<ChallengeActivityDto>? = null
) {
    fun toDomain(userId: String? = null): ChallengeWithStatus {
        val challenge = Challenge(
            id = id,
            profileId = profileId,
            title = title,
            description = description,
            difficulty = parseDifficulty(difficulty),
            action = action,
            score = score,
            participantCount = participantCount,
            imageUrl = imageUrl,
            viewsCount = viewsCount,
            isPublished = isPublished,
            likesCount = likesCount,
            createdAt = createdAt,
            updatedAt = updatedAt
        )

        val activity = activities?.firstOrNull()?.toDomain()

        return ChallengeWithStatus(
            challenge = challenge,
            activity = activity,
            userId = userId
        )
    }

    private fun parseDifficulty(value: String): ChallengeDifficulty = when (value.lowercase()) {
        "medium" -> ChallengeDifficulty.MEDIUM
        "hard" -> ChallengeDifficulty.HARD
        "extreme" -> ChallengeDifficulty.EXTREME
        else -> ChallengeDifficulty.EASY
    }
}

/**
 * DTO for leaderboard entry.
 */
@Serializable
data class LeaderboardEntryDto(
    @SerialName("profile_id") val id: String,
    val nickname: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val rank: Int,
    @SerialName("is_completed") val isCompleted: Boolean = false
) {
    fun toDomain() = ChallengeLeaderboardEntry(
        id = id,
        nickname = nickname,
        avatarUrl = avatarUrl,
        rank = rank,
        isCompleted = isCompleted
    )
}

// RPC Response DTOs

@Serializable
data class UserChallengesWithCountsResponse(
    val challenges: List<ChallengeWithActivityDto> = emptyList(),
    @SerialName("joined_count") val joinedCount: Int = 0,
    @SerialName("completed_count") val completedCount: Int = 0
)

@Serializable
data class ToggleLikeResponse(
    val success: Boolean,
    @SerialName("is_liked") val isLiked: Boolean,
    @SerialName("like_count") val likeCount: Int
)
