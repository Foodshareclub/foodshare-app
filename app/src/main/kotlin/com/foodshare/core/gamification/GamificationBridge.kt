package com.foodshare.core.gamification

import kotlinx.serialization.Serializable
import com.foodshare.swift.generated.GamificationEngine as SwiftEngine
import com.foodshare.swift.generated.ChallengePointsResult as SwiftChallengePointsResult
import com.foodshare.swift.generated.AchievementResult as SwiftAchievementResult
import com.foodshare.swift.generated.LeaderboardRankInfo as SwiftLeaderboardRankInfo

/**
 * Bridge for gamification logic using Swift implementation.
 *
 * Architecture (Frameo pattern - swift-java):
 * - Uses Swift GamificationEngine via swift-java generated classes
 * - Ensures identical gamification across iOS and Android
 * - Kotlin data classes provide API compatibility
 *
 * Swift implementation:
 * - foodshare-core/Sources/FoodshareCore/Gamification/GamificationEngine.swift
 */
object GamificationBridge {

    // ========================================================================
    // Challenge Scoring (delegating to Swift)
    // ========================================================================

    /**
     * Calculate points for completing a challenge.
     * Delegates to Swift GamificationEngine.
     *
     * @param difficulty Challenge difficulty (0=easy, 1=medium, 2=hard, 3=extreme)
     * @param streakDays Current user streak in days
     * @param isEarlyCompletion Whether completed before deadline
     * @param completionRank Rank among completers (1=first, -1=unknown)
     * @return ChallengePointsResult with total points and breakdown
     */
    fun calculateChallengePoints(
        difficulty: Int,
        streakDays: Int = 0,
        isEarlyCompletion: Boolean = false,
        completionRank: Int = -1
    ): ChallengePointsResult {
        val swiftResult: SwiftChallengePointsResult = SwiftEngine.calculateChallengePoints(
            difficulty, streakDays, isEarlyCompletion, completionRank
        )

        return swiftResult.use { result ->
            ChallengePointsResult(
                points = result.points,
                basePoints = result.basePoints,
                difficultyMultiplier = result.difficultyMultiplier,
                streakBonus = result.streakBonus,
                earlyCompletionBonus = result.earlyCompletionBonus,
                rankBonus = result.rankBonus
            )
        }
    }

    /**
     * Calculate points for a ChallengeDifficulty enum.
     */
    fun calculateChallengePoints(
        difficulty: ChallengeDifficulty,
        streakDays: Int = 0,
        isEarlyCompletion: Boolean = false,
        completionRank: Int = -1
    ): ChallengePointsResult {
        return calculateChallengePoints(
            difficulty.ordinal,
            streakDays,
            isEarlyCompletion,
            completionRank
        )
    }

    // ========================================================================
    // Achievement Tracking (delegating to Swift)
    // ========================================================================

    /**
     * Evaluate if an achievement should be unlocked.
     * Delegates to Swift GamificationEngine.
     *
     * @param achievementId Unique achievement identifier
     * @param stats User's current activity statistics
     * @return AchievementEvaluationResult with unlock status and progress
     */
    fun evaluateAchievement(
        achievementId: String,
        stats: UserActivityStats
    ): AchievementEvaluationResult {
        val swiftResult: SwiftAchievementResult = SwiftEngine.evaluateAchievement(
            achievementId,
            stats.totalFoodShared,
            stats.challengesCompleted,
            stats.longestStreak,
            stats.totalPoints
        )

        return swiftResult.use { result ->
            AchievementEvaluationResult(
                shouldUnlock = result.shouldUnlock,
                progress = result.progress,
                threshold = result.threshold,
                pointsValue = result.pointsValue,
                error = result.error
            )
        }
    }

    /**
     * Get all available achievement IDs.
     * Note: These are defined in Swift GamificationEngine.
     */
    fun getAchievementIds(): List<String> = listOf(
        // Food sharing achievements
        "first_share", "sharing_starter", "generous_giver", "food_hero", "sharing_legend",
        // Challenge achievements
        "challenge_beginner", "challenge_enthusiast", "challenge_master", "challenge_champion",
        // Streak achievements
        "streak_starter", "week_warrior", "month_master", "streak_legend",
        // Points achievements
        "point_collector", "point_hoarder", "point_master", "point_legend"
    )

    // ========================================================================
    // Streak Management (delegating to Swift)
    // ========================================================================

    private const val SECONDS_PER_DAY = 86400L

    /**
     * Get streak status from last activity timestamp.
     * Delegates to Swift GamificationEngine.
     *
     * @param lastActivityTimestamp Unix timestamp of last activity (seconds)
     * @return StreakStatus enum value
     */
    fun getStreakStatus(lastActivityTimestamp: Long): StreakStatus {
        val statusInt = SwiftEngine.getStreakStatus(lastActivityTimestamp)
        return StreakStatus.fromInt(statusInt)
    }

    /**
     * Check if streak is active from last activity.
     * Delegates to Swift GamificationEngine.
     */
    fun isStreakActive(lastActivityTimestamp: Long): Boolean {
        return SwiftEngine.isStreakActive(lastActivityTimestamp)
    }

    /**
     * Calculate streak days from last activity.
     * Returns estimated streak based on last activity time.
     * For accurate multi-day streak, use activity dates API.
     */
    fun calculateStreak(lastActivityTimestamp: Long): Int {
        if (lastActivityTimestamp <= 0) return 0

        val now = System.currentTimeMillis() / 1000
        val daysSinceActivity = (now - lastActivityTimestamp) / SECONDS_PER_DAY

        // If activity was within grace period, return at least 1
        return if (daysSinceActivity <= 1) 1 else 0
    }

    // ========================================================================
    // Leaderboard (delegating to Swift)
    // ========================================================================

    /**
     * Get leaderboard rank information.
     * Delegates to Swift GamificationEngine.
     *
     * @param rank User's rank (1 = first place)
     * @param totalParticipants Total number of participants
     * @return LeaderboardRankInfo with formatted rank and percentile
     */
    fun getLeaderboardRank(rank: Int, totalParticipants: Int): LeaderboardRankInfo {
        val swiftResult: SwiftLeaderboardRankInfo = SwiftEngine.getLeaderboardRank(rank, totalParticipants)

        return swiftResult.use { result ->
            LeaderboardRankInfo(
                rank = result.rank,
                percentile = result.percentile,
                formattedRank = result.formattedRank,
                medal = result.medal
            )
        }
    }

    /**
     * Format rank as ordinal string (1st, 2nd, 3rd, etc.)
     * Delegates to Swift GamificationEngine.
     */
    fun formatRank(rank: Int): String {
        return SwiftEngine.formatRank(rank)
    }

    // ========================================================================
    // Validation (Kotlin-only, not in Swift)
    // ========================================================================

    /**
     * Validate challenge progress update.
     *
     * @param currentProgress Current progress value
     * @param newProgress New progress value to validate
     * @param targetProgress Target/goal value
     * @return ValidationResult indicating if update is valid
     */
    fun validateChallengeProgress(
        currentProgress: Int,
        newProgress: Int,
        targetProgress: Int
    ): ChallengeValidationResult {
        val errors = mutableListOf<String>()

        if (newProgress < 0) errors.add("Progress cannot be negative")
        if (newProgress < currentProgress) errors.add("Progress cannot decrease")
        if (newProgress > targetProgress) errors.add("Progress cannot exceed target")
        if (targetProgress <= 0) errors.add("Target must be positive")

        return ChallengeValidationResult(errors.isEmpty(), errors)
    }

    // ========================================================================
    // Milestone & Badge (delegating to Swift)
    // ========================================================================

    /**
     * Calculate milestone bonus for completed challenges count.
     * Delegates to Swift GamificationEngine.
     */
    fun calculateMilestoneBonus(completedCount: Int): Int {
        return SwiftEngine.calculateMilestoneBonus(completedCount)
    }

    /**
     * Get badge tier for total points.
     * Delegates to Swift GamificationEngine.
     *
     * @param totalPoints User's total points
     * @return BadgeTier enum value
     */
    fun getBadgeTier(totalPoints: Int): BadgeTier {
        val tierInt = SwiftEngine.getBadgeTier(totalPoints)
        return BadgeTier.fromInt(tierInt)
    }
}

// ========================================================================
// Data Classes
// ========================================================================

/**
 * Result of challenge points calculation.
 */
@Serializable
data class ChallengePointsResult(
    val points: Int,
    val basePoints: Int,
    val difficultyMultiplier: Double,
    val streakBonus: Double,
    val earlyCompletionBonus: Double,
    val rankBonus: Int
)

/**
 * Result of achievement evaluation.
 */
@Serializable
data class AchievementEvaluationResult(
    val shouldUnlock: Boolean,
    val progress: Int,
    val threshold: Int,
    val pointsValue: Int,
    val error: String? = null
)

/**
 * User activity statistics for achievement evaluation.
 */
data class UserActivityStats(
    val totalFoodShared: Int = 0,
    val challengesCompleted: Int = 0,
    val longestStreak: Int = 0,
    val totalPoints: Int = 0,
    val reviewsReceived: Int = 0,
    val messagesExchanged: Int = 0,
    val uniqueUsersHelped: Int = 0
)

/**
 * Leaderboard rank information.
 */
@Serializable
data class LeaderboardRankInfo(
    val rank: Int,
    val percentile: Double,
    val formattedRank: String,
    val medal: String
)

/**
 * Result of challenge progress validation.
 */
@Serializable
data class ChallengeValidationResult(
    val isValid: Boolean,
    val errors: List<String>
) {
    val firstError: String? get() = errors.firstOrNull()
}

// ========================================================================
// Enums
// ========================================================================

/**
 * Challenge difficulty levels.
 * SYNC: Mirrors Swift ChallengeDifficulty
 */
enum class ChallengeDifficulty {
    EASY,
    MEDIUM,
    HARD,
    EXTREME;

    val displayName: String
        get() = when (this) {
            EASY -> "Easy"
            MEDIUM -> "Medium"
            HARD -> "Hard"
            EXTREME -> "Extreme"
        }

    val pointMultiplier: Double
        get() = when (this) {
            EASY -> 1.0
            MEDIUM -> 1.5
            HARD -> 2.5
            EXTREME -> 4.0
        }

    val basePoints: Int
        get() = when (this) {
            EASY -> 50
            MEDIUM -> 100
            HARD -> 200
            EXTREME -> 400
        }
}

/**
 * User streak status.
 * SYNC: Mirrors Swift StreakStatus
 */
enum class StreakStatus {
    NO_STREAK,
    ACTIVE_TODAY,
    AT_RISK,
    BROKEN;

    val displayName: String
        get() = when (this) {
            NO_STREAK -> "No streak yet"
            ACTIVE_TODAY -> "Streak active"
            AT_RISK -> "Streak at risk"
            BROKEN -> "Streak broken"
        }

    val isActive: Boolean
        get() = this == ACTIVE_TODAY || this == AT_RISK

    companion object {
        fun fromInt(value: Int): StreakStatus = when (value) {
            0 -> NO_STREAK
            1 -> ACTIVE_TODAY
            2 -> AT_RISK
            3 -> BROKEN
            else -> NO_STREAK
        }
    }
}

/**
 * Badge tier levels.
 * SYNC: Mirrors Swift BadgeTier
 */
enum class BadgeTier {
    BRONZE,
    SILVER,
    GOLD,
    PLATINUM,
    DIAMOND;

    val displayName: String
        get() = name.lowercase().replaceFirstChar { it.uppercase() }

    val pointsThreshold: Int
        get() = when (this) {
            BRONZE -> 100
            SILVER -> 500
            GOLD -> 2000
            PLATINUM -> 10000
            DIAMOND -> 50000
        }

    companion object {
        fun fromInt(value: Int): BadgeTier = when (value) {
            0 -> BRONZE
            1 -> SILVER
            2 -> GOLD
            3 -> PLATINUM
            4 -> DIAMOND
            else -> BRONZE
        }
    }
}
