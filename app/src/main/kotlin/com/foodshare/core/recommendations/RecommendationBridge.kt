package com.foodshare.core.recommendations

import kotlinx.serialization.Serializable
import java.time.Duration
import java.time.Instant
import com.foodshare.swift.generated.RecommendationEngine as SwiftEngine
import com.foodshare.swift.generated.RankingWeights as SwiftRankingWeights
import com.foodshare.swift.generated.SwiftDecayResult
import com.foodshare.swift.generated.SwiftRelevanceResult
import com.foodshare.swift.generated.AffinityUpdateResult as SwiftAffinityUpdateResult

/**
 * Recommendation engine for personalized feeds using Swift implementation.
 *
 * Architecture (Frameo pattern - swift-java):
 * - Uses Swift RecommendationEngine via swift-java generated classes
 * - Ensures identical ranking algorithms across iOS and Android
 * - Kotlin data classes provide API compatibility
 *
 * Swift implementation:
 * - foodshare-core/Sources/FoodshareCore/Recommendations/RecommendationEngine.swift
 */
object RecommendationBridge {

    // MARK: - Feed Ranking

    /**
     * Rank feed items based on user preferences.
     * Uses Swift RecommendationEngine for relevance calculation.
     *
     * @param items List of content items to rank
     * @param preferences User preferences for personalization
     * @param configPreset Ranking preset: "default", "forYou", "nearby", "popular", "expiringSoon"
     * @return Ranked items result
     */
    fun rankFeedItems(
        items: List<ContentItem>,
        preferences: UserPreferences,
        configPreset: String = "default"
    ): RankingResult {
        val rankedItems = items.mapNotNull { item ->
            val relevance = calculateRelevanceInternal(item, preferences, configPreset)
            if (relevance.shouldFilter) {
                null
            } else {
                RankedItem(
                    id = item.id,
                    score = relevance.score,
                    componentScores = relevance.componentScores,
                    shouldFilter = false,
                    filterReason = null
                )
            }
        }.sortedByDescending { it.score }

        return RankingResult(
            items = rankedItems,
            count = rankedItems.size
        )
    }

    /**
     * Rank items for "For You" personalized feed.
     */
    fun rankForYouFeed(
        items: List<ContentItem>,
        preferences: UserPreferences
    ): List<RankedItem> {
        return rankFeedItems(items, preferences, "forYou").items
    }

    /**
     * Rank items for nearby feed (distance-focused).
     */
    fun rankNearbyFeed(
        items: List<ContentItem>,
        preferences: UserPreferences
    ): List<RankedItem> {
        return rankFeedItems(items, preferences, "nearby").items
    }

    /**
     * Rank items for popular/trending feed.
     */
    fun rankPopularFeed(
        items: List<ContentItem>,
        preferences: UserPreferences
    ): List<RankedItem> {
        return rankFeedItems(items, preferences, "popular").items
    }

    /**
     * Rank expiring items by urgency.
     */
    fun rankExpiringSoon(
        items: List<ContentItem>,
        preferences: UserPreferences
    ): List<RankedItem> {
        return rankFeedItems(items, preferences, "expiringSoon").items
    }

    // MARK: - Content Relevance

    /**
     * Calculate relevance score for a single item.
     * Delegates to Swift RecommendationEngine.
     */
    fun calculateRelevance(
        item: ContentItem,
        preferences: UserPreferences
    ): RelevanceResult {
        return calculateRelevanceInternal(item, preferences, "default")
    }

    /**
     * Internal relevance calculation using Swift.
     */
    private fun calculateRelevanceInternal(
        item: ContentItem,
        preferences: UserPreferences,
        preset: String
    ): RelevanceResult {
        // Calculate age in seconds
        val ageSeconds = try {
            val created = Instant.parse(item.createdAt)
            Duration.between(created, Instant.now()).seconds.toDouble()
        } catch (e: Exception) { 0.0 }

        // Calculate dietary match ratio
        val dietaryMatchRatio = if (preferences.dietaryRequirements.isEmpty()) {
            1.0
        } else {
            val matched = preferences.dietaryRequirements.intersect(item.dietaryTags).size
            matched.toDouble() / preferences.dietaryRequirements.size
        }

        // Get category affinity
        val categoryAffinity = preferences.categoryAffinities[item.categoryId] ?: 0.5

        // Delegate to Swift
        val swiftResult: SwiftRelevanceResult = SwiftEngine.calculateRelevance(
            categoryAffinity,
            item.distanceKm,
            preferences.maxDistanceKm,
            ageSeconds,
            item.viewCount,
            item.favoriteCount,
            item.claimCount,
            item.donorRating,
            item.donorIsVerified,
            preferences.preferVerifiedDonors,
            preferences.minDonorRating,
            dietaryMatchRatio,
            item.categoryId in preferences.excludedCategories,
            preset
        )

        return swiftResult.use { result ->
            val componentScores = mutableMapOf(
                "categoryAffinity" to result.categoryAffinityScore,
                "distance" to result.distanceScore,
                "freshness" to result.freshnessScore,
                "popularity" to result.popularityScore,
                "donorTrust" to result.donorTrustScore,
                "dietary" to result.dietaryScore
            )

            RelevanceResult(
                score = result.score,
                componentScores = componentScores,
                shouldFilter = result.shouldFilter,
                error = result.filterReason.orElse(null)
            )
        }
    }

    // MARK: - Decay Functions

    /**
     * Compute decay score for content age.
     * Delegates to Swift RecommendationEngine.
     *
     * @param ageSeconds Age of content in seconds
     * @param strategy Decay strategy: "exponential", "linear", "inverse", "step", "foodFreshness"
     * @param parameter Strategy parameter (halfLife for exponential, maxAge for linear, etc.)
     * @return Decay result with score
     */
    fun computeDecayScore(
        ageSeconds: Double,
        strategy: String = "exponential",
        parameter: Double = 86400.0
    ): DecayResult {
        val swiftResult: SwiftDecayResult = SwiftEngine.computeDecayScore(ageSeconds, strategy, parameter)
        return swiftResult.use { result ->
            DecayResult(
                score = result.score,
                ageSeconds = result.ageSeconds,
                ageDescription = result.ageDescription,
                strategy = result.strategy
            )
        }
    }

    /**
     * Calculate freshness score for a listing.
     * Delegates to Swift RecommendationEngine.
     */
    fun calculateFreshness(ageSeconds: Double, expiresInSeconds: Double? = null): Double {
        return SwiftEngine.calculateFreshness(ageSeconds, expiresInSeconds)
    }

    // MARK: - Category Affinities

    /**
     * Update category affinity based on user action.
     * Delegates to Swift RecommendationEngine.
     *
     * @param affinity Current affinity state
     * @param eventType Event type: "view", "favorite", "claim", "engagement", "like", "dislike", "neutral"
     * @param eventValue Optional value (e.g., engagement seconds)
     * @return Updated affinity
     */
    fun updateAffinity(
        affinity: CategoryAffinity,
        eventType: String,
        eventValue: Double = 0.0
    ): CategoryAffinity {
        val swiftResult: SwiftAffinityUpdateResult = SwiftEngine.updateAffinity(
            affinity.viewCount,
            affinity.favoriteCount,
            affinity.claimCount,
            affinity.engagementSeconds,
            affinity.explicitPreference,
            eventType,
            eventValue
        )
        return swiftResult.use { result ->
            CategoryAffinity(
                categoryId = affinity.categoryId,
                viewCount = result.viewCount,
                favoriteCount = result.favoriteCount,
                claimCount = result.claimCount,
                engagementSeconds = result.engagementSeconds,
                lastInteractionAt = result.lastInteractionAt,
                explicitPreference = result.explicitPreference
            )
        }
    }

    /**
     * Record a view for a category.
     */
    fun recordCategoryView(affinity: CategoryAffinity): CategoryAffinity {
        return updateAffinity(affinity, "view")
    }

    /**
     * Record a favorite for a category.
     */
    fun recordCategoryFavorite(affinity: CategoryAffinity): CategoryAffinity {
        return updateAffinity(affinity, "favorite")
    }

    /**
     * Record a claim for a category.
     */
    fun recordCategoryClaim(affinity: CategoryAffinity): CategoryAffinity {
        return updateAffinity(affinity, "claim")
    }

    /**
     * Record engagement time for a category.
     */
    fun recordCategoryEngagement(affinity: CategoryAffinity, seconds: Double): CategoryAffinity {
        return updateAffinity(affinity, "engagement", seconds)
    }

    /**
     * Set explicit category preference.
     */
    fun setCategoryPreference(affinity: CategoryAffinity, preference: Int): CategoryAffinity {
        val eventType = when {
            preference > 0 -> "like"
            preference < 0 -> "dislike"
            else -> "neutral"
        }
        return updateAffinity(affinity, eventType)
    }
}

// MARK: - Data Models

@Serializable
data class ContentItem(
    val id: String,
    val title: String,
    val categoryId: String,
    val categoryName: String? = null,
    val dietaryTags: Set<String> = emptySet(),
    val distanceKm: Double? = null,
    val donorRating: Double? = null,
    val donorIsVerified: Boolean = false,
    val pickupStartHour: Int? = null,
    val pickupEndHour: Int? = null,
    val createdAt: String, // ISO8601
    val expiresAt: String? = null, // ISO8601
    val viewCount: Int = 0,
    val favoriteCount: Int = 0,
    val claimCount: Int = 0
)

@Serializable
data class UserPreferences(
    val preferredCategories: Set<String> = emptySet(),
    val excludedCategories: Set<String> = emptySet(),
    val dietaryRequirements: Set<String> = emptySet(),
    val maxDistanceKm: Double? = null,
    val preferredPickupHours: Set<Int> = emptySet(),
    val preferVerifiedDonors: Boolean = false,
    val minDonorRating: Double? = null,
    val categoryAffinities: Map<String, Double> = emptyMap(),
    val customFilters: Map<String, String> = emptyMap()
)

@Serializable
data class RankedItem(
    val id: String,
    val score: Double,
    val componentScores: Map<String, Double> = emptyMap(),
    val shouldFilter: Boolean = false,
    val filterReason: String? = null
)

@Serializable
data class RankingResult(
    val items: List<RankedItem>,
    val count: Int,
    val error: String? = null
)

@Serializable
data class RelevanceResult(
    val score: Double,
    val componentScores: Map<String, Double> = emptyMap(),
    val shouldFilter: Boolean = false,
    val error: String? = null
)

@Serializable
data class DecayResult(
    val score: Double,
    val ageSeconds: Double,
    val ageDescription: String,
    val strategy: String
)

@Serializable
data class CategoryAffinity(
    val categoryId: String,
    val viewCount: Int = 0,
    val favoriteCount: Int = 0,
    val claimCount: Int = 0,
    val engagementSeconds: Double = 0.0,
    val lastInteractionAt: String? = null, // ISO8601
    val explicitPreference: Int = 0
)
