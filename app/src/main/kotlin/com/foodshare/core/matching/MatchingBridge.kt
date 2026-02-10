package com.foodshare.core.matching

import kotlinx.serialization.Serializable
import com.foodshare.swift.generated.MatchingEngine as SwiftEngine
import com.foodshare.swift.generated.SwiftMatchScoreResult
import com.foodshare.swift.generated.SwiftProximityResult
import com.foodshare.swift.generated.SwiftDietaryCompatibilityResult
import com.foodshare.swift.generated.SwiftBoundingBox

/**
 * Bridge for food sharing matching algorithms using Swift implementation.
 *
 * Architecture (Frameo pattern - swift-java):
 * - Uses Swift MatchingEngine via swift-java generated classes
 * - Ensures identical matching behavior across iOS and Android
 * - Kotlin data classes provide API compatibility
 *
 * Swift implementation:
 * - foodshare-core/Sources/FoodshareCore/Matching/MatchingEngine.swift
 */
object MatchingBridge {

    // ========================================================================
    // Data Classes
    // ========================================================================

    @Serializable
    data class MatchCandidate(
        val id: String,
        val latitude: Double,
        val longitude: Double,
        val dietaryPreferences: List<String> = emptyList(),
        val categoryIds: List<Int> = emptyList(),
        val activityLevel: Double = 0.0,
        val rating: Double = 0.0,
        val responseTimeMinutes: Double = 60.0,
        val isVerified: Boolean = false
    )

    @Serializable
    data class MatchingContext(
        val userLatitude: Double,
        val userLongitude: Double,
        val userDietaryPreferences: List<String> = emptyList(),
        val userActivityLevel: Double = 0.0
    )

    data class MatchScoreResult(
        val totalScore: Double,
        val passesThreshold: Boolean,
        val percentageScore: Int,
        val factors: Map<MatchingFactor, Double> = emptyMap(),
        val error: String? = null
    )

    data class BestMatchesResult(
        val matches: List<MatchEntry>,
        val count: Int,
        val error: String? = null
    )

    data class MatchEntry(
        val id: String,
        val score: Double,
        val percentage: Int
    )

    data class DietaryCompatibilityResult(
        val score: Double,
        val meetsRequired: Boolean,
        val isValidMatch: Boolean,
        val matchedCount: Int,
        val violations: List<String> = emptyList()
    )

    data class ProximityResult(
        val distanceKm: Double,
        val score: Double,
        val isWithinRange: Boolean
    )

    data class BoundingBox(
        val minLat: Double,
        val maxLat: Double,
        val minLon: Double,
        val maxLon: Double
    ) {
        fun contains(lat: Double, lon: Double): Boolean =
            lat in minLat..maxLat && lon in minLon..maxLon
    }

    enum class MatchingFactor(val key: String) {
        PROXIMITY("proximity"),
        DIETARY("dietary"),
        CATEGORY("category"),
        ACTIVITY("activity"),
        REPUTATION("reputation"),
        RESPONSE_TIME("responseTime")
    }

    enum class CriteriaPreset(val value: String) {
        DEFAULT("default"),
        FOOD_PICKUP("foodPickup"),
        DIETARY_FOCUSED("dietaryFocused"),
        COMMUNITY("community")
    }

    // ========================================================================
    // Matching Operations (delegating to Swift)
    // ========================================================================

    /**
     * Calculate match score between user context and a candidate.
     * Delegates to Swift MatchingEngine.
     */
    fun calculateMatchScore(
        candidate: MatchCandidate,
        context: MatchingContext,
        preset: CriteriaPreset = CriteriaPreset.DEFAULT
    ): MatchScoreResult {
        // Calculate individual factor scores using Swift
        val proximity = scoreLocationProximity(
            context.userLatitude, context.userLongitude,
            candidate.latitude, candidate.longitude, 25.0
        )

        val dietary = evaluateDietaryCompatibility(
            candidate.dietaryPreferences,
            context.userDietaryPreferences, emptyList(), emptyList()
        )

        val reputationScore = SwiftEngine.calculateReputationScore(candidate.rating, candidate.isVerified)
        val responseTimeScore = SwiftEngine.calculateResponseTimeScore(candidate.responseTimeMinutes)

        // Calculate final score using Swift
        val swiftResult: SwiftMatchScoreResult = SwiftEngine.calculateMatchScore(
            proximity.score,
            dietary.score,
            0.5, // category score (neutral)
            0.5, // activity score (neutral)
            reputationScore,
            responseTimeScore,
            preset.value
        )

        return swiftResult.use { result ->
            val factors = mapOf(
                MatchingFactor.PROXIMITY to result.proximityScore,
                MatchingFactor.DIETARY to result.dietaryScore,
                MatchingFactor.CATEGORY to result.categoryScore,
                MatchingFactor.ACTIVITY to result.activityScore,
                MatchingFactor.REPUTATION to result.reputationScore,
                MatchingFactor.RESPONSE_TIME to result.responseTimeScore
            )

            MatchScoreResult(
                totalScore = result.totalScore,
                passesThreshold = result.passesThreshold,
                percentageScore = result.percentageScore,
                factors = factors
            )
        }
    }

    /**
     * Find best matches from a list of candidates.
     */
    fun findBestMatches(
        candidates: List<MatchCandidate>,
        context: MatchingContext,
        preset: CriteriaPreset = CriteriaPreset.DEFAULT,
        maxResults: Int = 20
    ): BestMatchesResult {
        val scored = candidates.map { candidate ->
            val result = calculateMatchScore(candidate, context, preset)
            MatchEntry(candidate.id, result.totalScore, result.percentageScore)
        }
            .filter { it.score >= 0.3 }
            .sortedByDescending { it.score }
            .take(maxResults)

        return BestMatchesResult(scored, scored.size)
    }

    /**
     * Evaluate dietary compatibility.
     * Delegates to Swift MatchingEngine.
     */
    fun evaluateDietaryCompatibility(
        listingDietary: List<String>,
        required: List<String> = emptyList(),
        preferred: List<String> = emptyList(),
        excluded: List<String> = emptyList()
    ): DietaryCompatibilityResult {
        val swiftResult: SwiftDietaryCompatibilityResult = SwiftEngine.evaluateDietaryCompatibility(
            listingDietary.joinToString(","),
            required.joinToString(","),
            preferred.joinToString(","),
            excluded.joinToString(",")
        )

        return swiftResult.use { result ->
            DietaryCompatibilityResult(
                score = result.score,
                meetsRequired = result.meetsRequired,
                isValidMatch = result.isValidMatch,
                matchedCount = result.matchedCount,
                violations = if (result.hasViolations) listOf("Dietary violation") else emptyList()
            )
        }
    }

    /**
     * Calculate location proximity score.
     * Delegates to Swift MatchingEngine.
     */
    fun scoreLocationProximity(
        userLat: Double,
        userLon: Double,
        targetLat: Double,
        targetLon: Double,
        maxDistanceKm: Double = 25.0
    ): ProximityResult {
        val swiftResult: SwiftProximityResult = SwiftEngine.scoreLocationProximity(
            userLat, userLon, targetLat, targetLon, maxDistanceKm
        )

        return swiftResult.use { result ->
            ProximityResult(
                distanceKm = result.distanceKm,
                score = result.score,
                isWithinRange = result.isWithinRange
            )
        }
    }

    /**
     * Calculate bounding box for spatial database queries.
     * Delegates to Swift MatchingEngine.
     */
    fun calculateBoundingBox(
        centerLat: Double,
        centerLon: Double,
        radiusKm: Double
    ): BoundingBox {
        val swiftResult: SwiftBoundingBox = SwiftEngine.calculateBoundingBox(centerLat, centerLon, radiusKm)

        return swiftResult.use { result ->
            BoundingBox(
                minLat = result.minLat,
                maxLat = result.maxLat,
                minLon = result.minLon,
                maxLon = result.maxLon
            )
        }
    }

    /**
     * Quick match score for filtering (no detailed breakdown).
     */
    fun quickMatchScore(
        candidate: MatchCandidate,
        context: MatchingContext
    ): Double {
        return calculateMatchScore(candidate, context).totalScore
    }

    /**
     * Calculate Haversine distance between two points.
     * Delegates to Swift MatchingEngine.
     */
    fun haversineDistance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ): Double {
        return SwiftEngine.haversineDistance(lat1, lon1, lat2, lon2)
    }
}
