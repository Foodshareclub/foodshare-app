package com.foodshare.core.rating

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlin.math.ln
import kotlin.math.roundToInt

/**
 * Bridge for rating display and calculation logic.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for rating algorithms
 * - Consistent formatting logic across iOS and Android
 * - No manual JNI required for these stateless calculations
 *
 * Note: Rating algorithms are simple mathematical operations that don't
 * benefit from Swift interop. Local Kotlin implementations provide
 * identical results with better performance.
 */
object RatingBridge {

    // ========================================================================
    // Formatting
    // ========================================================================

    /**
     * Format rating as stars (e.g., "★★★★☆").
     *
     * @param rating Rating value (0.0 to 5.0)
     * @param maxStars Maximum number of stars (default 5)
     * @return Unicode star string
     */
    fun formatAsStars(rating: Double, maxStars: Int = 5): String {
        val fullStars = rating.toInt().coerceIn(0, maxStars)
        val hasHalfStar = (rating - fullStars) >= 0.5
        val emptyStars = maxStars - fullStars - (if (hasHalfStar) 1 else 0)
        return "★".repeat(fullStars) + (if (hasHalfStar) "½" else "") + "☆".repeat(emptyStars)
    }

    /**
     * Format rating with count (e.g., "4.5 (123 reviews)").
     *
     * @param rating Rating value
     * @param count Number of reviews
     * @return Formatted string
     */
    fun formatWithCount(rating: Double, count: Int): String {
        return "${String.format("%.1f", rating)} ($count ${if (count == 1) "review" else "reviews"})"
    }

    /**
     * Get descriptive text for rating (e.g., "Excellent", "Good").
     *
     * @param rating Rating value
     * @return Description string
     */
    fun getDescription(rating: Double): String {
        return when {
            rating >= 4.5 -> "Excellent"
            rating >= 3.5 -> "Good"
            rating >= 2.5 -> "Average"
            rating >= 1.5 -> "Below Average"
            rating > 0 -> "Poor"
            else -> "Not Rated"
        }
    }

    /**
     * Get suggested color for rating.
     *
     * @param rating Rating value
     * @return RatingColor enum value
     */
    fun getSuggestedColor(rating: Double): RatingColor {
        return when {
            rating >= 4.5 -> RatingColor.EXCELLENT
            rating >= 3.5 -> RatingColor.GOOD
            rating >= 2.5 -> RatingColor.AVERAGE
            rating >= 1.5 -> RatingColor.POOR
            rating > 0 -> RatingColor.TERRIBLE
            else -> RatingColor.NEUTRAL
        }
    }

    /**
     * Format rating for accessibility (screen readers).
     *
     * @param rating Rating value
     * @param count Number of reviews
     * @return Screen reader friendly string
     */
    fun formatForAccessibility(rating: Double, count: Int): String {
        return "Rated ${String.format("%.1f", rating)} out of 5, based on $count ${if (count == 1) "review" else "reviews"}"
    }

    // ========================================================================
    // Calculations
    // ========================================================================

    /**
     * Calculate weighted average from ratings list.
     *
     * @param ratings List of rating values (1-5)
     * @return Weighted average
     */
    fun calculateAverage(ratings: List<Int>): Double {
        if (ratings.isEmpty()) return 0.0
        return ratings.average()
    }

    /**
     * Calculate full rating statistics.
     *
     * @param ratings List of rating values
     * @return RatingStats with average, distribution, trend, etc.
     */
    fun getStats(ratings: List<Int>): RatingStats {
        if (ratings.isEmpty()) {
            return RatingStats.empty()
        }

        val average = ratings.average()
        val count = ratings.size

        val distribution = (1..5).associate { star ->
            star.toString() to (ratings.count { it == star }.toDouble() / ratings.size * 100)
        }

        val confidence = calculateConfidence(count)

        return RatingStats(
            average = average,
            count = count,
            distribution = distribution,
            trend = calculateTrend(ratings),
            confidence = confidence,
            formattedAverage = String.format("%.1f", average),
            formattedStars = formatAsStars(average, 5),
            description = getDescription(average),
            accessibilityLabel = "Rated ${String.format("%.1f", average)} out of 5"
        )
    }

    /**
     * Calculate confidence score (0.0 to 1.0) based on sample size.
     * Uses logarithmic scaling: more ratings = higher confidence.
     *
     * @param count Number of ratings
     * @return Confidence score
     */
    fun calculateConfidence(count: Int): Double {
        if (count <= 0) return 0.0
        // Logarithmic scaling: 10 ratings ≈ 0.5, 100 ratings ≈ 0.9
        return minOf(1.0, ln(count.toDouble() + 1) / ln(101.0))
    }

    /**
     * Round rating for display at specified precision.
     *
     * @param rating Raw rating value
     * @param precision Rounding precision (whole, half, tenth)
     * @return Rounded value
     */
    fun roundForDisplay(rating: Double, precision: RatingPrecision = RatingPrecision.HALF): Double {
        return when (precision) {
            RatingPrecision.WHOLE -> rating.roundToInt().toDouble()
            RatingPrecision.HALF -> (rating * 2).roundToInt() / 2.0
            RatingPrecision.TENTH -> (rating * 10).roundToInt() / 10.0
        }
    }

    /**
     * Calculate trend from ratings (simplified - would need timestamps for real trend).
     */
    private fun calculateTrend(ratings: List<Int>): RatingTrend {
        if (ratings.size < 5) return RatingTrend.INSUFFICIENT
        // Simple heuristic: compare recent vs older ratings
        val recentAvg = ratings.takeLast(ratings.size / 2).average()
        val olderAvg = ratings.take(ratings.size / 2).average()
        return when {
            recentAvg - olderAvg > 0.3 -> RatingTrend.IMPROVING
            olderAvg - recentAvg > 0.3 -> RatingTrend.DECLINING
            else -> RatingTrend.STABLE
        }
    }

}

// ========================================================================
// Data Classes
// ========================================================================

@Serializable
data class RatingStats(
    val average: Double,
    val count: Int,
    val distribution: Map<String, Double> = emptyMap(),
    val trend: RatingTrend = RatingTrend.STABLE,
    val confidence: Double = 0.0,
    val formattedAverage: String = "",
    val formattedStars: String = "",
    val description: String = "",
    val accessibilityLabel: String = ""
) {
    companion object {
        fun empty() = RatingStats(
            average = 0.0,
            count = 0,
            distribution = (1..5).associate { it.toString() to 0.0 },
            trend = RatingTrend.INSUFFICIENT,
            confidence = 0.0,
            formattedAverage = "0.0",
            formattedStars = "☆☆☆☆☆",
            description = "Not Rated",
            accessibilityLabel = "No ratings yet"
        )
    }
}

@Serializable
enum class RatingTrend(val value: String) {
    @SerialName("improving") IMPROVING("improving"),
    @SerialName("declining") DECLINING("declining"),
    @SerialName("stable") STABLE("stable"),
    @SerialName("insufficient") INSUFFICIENT("insufficient");

    val displayName: String
        get() = when (this) {
            IMPROVING -> "Improving"
            DECLINING -> "Declining"
            STABLE -> "Stable"
            INSUFFICIENT -> "Not enough data"
        }

    val symbol: String
        get() = when (this) {
            IMPROVING -> "↑"
            DECLINING -> "↓"
            STABLE -> "↔"
            INSUFFICIENT -> "-"
        }
}

enum class RatingPrecision(val value: String) {
    WHOLE("whole"),
    HALF("half"),
    TENTH("tenth")
}

enum class RatingColor {
    EXCELLENT,  // Green - 4.5+
    GOOD,       // Light green - 3.5-4.5
    AVERAGE,    // Yellow - 2.5-3.5
    POOR,       // Orange - 1.5-2.5
    TERRIBLE,   // Red - below 1.5
    NEUTRAL;    // Gray - no rating

    companion object {
        fun fromName(name: String): RatingColor {
            return when (name.lowercase()) {
                "excellent" -> EXCELLENT
                "good" -> GOOD
                "average" -> AVERAGE
                "poor" -> POOR
                "terrible" -> TERRIBLE
                else -> NEUTRAL
            }
        }
    }
}
