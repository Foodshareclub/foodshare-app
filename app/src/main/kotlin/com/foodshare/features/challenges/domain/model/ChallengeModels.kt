package com.foodshare.features.challenges.domain.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Challenge difficulty levels.
 *
 * SYNC: This mirrors Swift ChallengeDifficulty
 */
@Serializable
enum class ChallengeDifficulty {
    @SerialName("easy") EASY,
    @SerialName("medium") MEDIUM,
    @SerialName("hard") HARD,
    @SerialName("extreme") EXTREME;

    val displayName: String
        get() = when (this) {
            EASY -> "Easy"
            MEDIUM -> "Medium"
            HARD -> "Hard"
            EXTREME -> "Extreme"
        }

    val color: Long
        get() = when (this) {
            EASY -> 0xFF4CAF50 // Green
            MEDIUM -> 0xFFFF9800 // Orange
            HARD -> 0xFFF44336 // Red
            EXTREME -> 0xFF9C27B0 // Purple
        }
}

/**
 * User's status with a challenge.
 */
enum class ChallengeUserStatus {
    NOT_JOINED,
    ACCEPTED,
    COMPLETED,
    REJECTED;

    val displayName: String
        get() = when (this) {
            NOT_JOINED -> "Join"
            ACCEPTED -> "In Progress"
            COMPLETED -> "Done"
            REJECTED -> "Declined"
        }
}

/**
 * Challenge domain model.
 *
 * SYNC: This mirrors Swift Challenge
 */
@Serializable
data class Challenge(
    val id: Int,
    @SerialName("profile_id") val profileId: String,
    @SerialName("challenge_title") val title: String,
    @SerialName("challenge_description") val description: String,
    @SerialName("challenge_difficulty") val difficulty: ChallengeDifficulty = ChallengeDifficulty.EASY,
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
    val displayTitle: String
        get() = title.take(50)

    val displayDescription: String
        get() = description.take(150).let {
            if (description.length > 150) "$it..." else it
        }

    val formattedScore: String
        get() = when {
            score >= 1000 -> "${score / 1000}K"
            else -> score.toString()
        }

    val formattedParticipants: String
        get() = when {
            participantCount >= 1000 -> "${participantCount / 1000}K"
            else -> participantCount.toString()
        }
}

/**
 * Challenge activity tracking user participation.
 *
 * SYNC: This mirrors Swift ChallengeActivity
 */
@Serializable
data class ChallengeActivity(
    val id: Int,
    @SerialName("challenge_id") val challengeId: Int,
    @SerialName("created_at") val createdAt: String,
    @SerialName("user_accepted_challenge") val userAcceptedChallenge: String? = null,
    @SerialName("user_rejected_challenge") val userRejectedChallenge: String? = null,
    @SerialName("user_completed_challenge") val userCompletedChallenge: String? = null
) {
    fun isAccepted(userId: String): Boolean = userAcceptedChallenge == userId
    fun isCompleted(userId: String): Boolean = userCompletedChallenge == userId
    fun isRejected(userId: String): Boolean = userRejectedChallenge == userId
}

/**
 * Challenge with user status.
 */
data class ChallengeWithStatus(
    val challenge: Challenge,
    val activity: ChallengeActivity? = null,
    val userId: String? = null
) {
    val status: ChallengeUserStatus
        get() {
            val uid = userId ?: return ChallengeUserStatus.NOT_JOINED
            val act = activity ?: return ChallengeUserStatus.NOT_JOINED
            return when {
                act.isCompleted(uid) -> ChallengeUserStatus.COMPLETED
                act.isRejected(uid) -> ChallengeUserStatus.REJECTED
                act.isAccepted(uid) -> ChallengeUserStatus.ACCEPTED
                else -> ChallengeUserStatus.NOT_JOINED
            }
        }
}

/**
 * Result from fetching user challenges with counts.
 */
data class UserChallengesWithCountsResult(
    val challenges: List<ChallengeWithStatus>,
    val joinedCount: Int,
    val completedCount: Int
)

/**
 * Leaderboard entry for a challenge.
 *
 * SYNC: This mirrors Swift ChallengeLeaderboardEntry
 */
@Serializable
data class ChallengeLeaderboardEntry(
    val id: String,
    val nickname: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val rank: Int,
    @SerialName("is_completed") val isCompleted: Boolean = false
)

/**
 * Filter options for challenges list.
 */
enum class ChallengeFilter {
    ALL,
    JOINED,
    COMPLETED;

    val displayName: String
        get() = when (this) {
            ALL -> "All"
            JOINED -> "Joined"
            COMPLETED -> "Completed"
        }
}

/**
 * View mode for challenges screen.
 */
enum class ChallengeViewMode {
    DECK,
    LIST,
    LEADERBOARD
}
