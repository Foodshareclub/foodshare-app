package com.foodshare.core.search

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import com.foodshare.swift.generated.SearchEngine as SwiftEngine
import com.foodshare.swift.generated.ParsedQuery as SwiftParsedQuery
import com.foodshare.swift.generated.SpellingCorrection as SwiftSpellingCorrection
import com.foodshare.swift.generated.RelevanceScore as SwiftRelevanceScore
import com.foodshare.swift.generated.FuzzyMatchResult as SwiftFuzzyMatchResult

/**
 * Bridge for search engine algorithms using Swift implementation.
 *
 * Architecture (Frameo pattern - swift-java):
 * - Uses Swift SearchEngine via swift-java generated classes
 * - Ensures identical search behavior across iOS and Android
 * - Kotlin data classes provide API compatibility
 *
 * Swift implementation:
 * - foodshare-core/Sources/FoodshareCore/Search/SearchEngine.swift
 */
object SearchEngineBridge {

    // ========================================================================
    // Query Parsing (delegating to Swift)
    // ========================================================================

    /**
     * Parse a natural language query into structured components.
     * Delegates to Swift SearchEngine.
     */
    fun parseQuery(rawQuery: String): ParsedQuery {
        val swiftResult: SwiftParsedQuery = SwiftEngine.parseQuery(rawQuery)

        return swiftResult.use { result ->
            ParsedQuery(
                originalQuery = result.originalQuery,
                normalizedQuery = result.normalizedQuery,
                tokens = result.tokens.split(",").filter { it.isNotEmpty() },
                searchTerms = result.searchTerms.split(",").filter { it.isNotEmpty() },
                categories = result.categories.split(",").filter { it.isNotEmpty() },
                dietaryFilters = result.dietaryFilters.split(",").filter { it.isNotEmpty() },
                locationIntent = if (result.locationIntent >= 0) LocationIntent.fromInt(result.locationIntent) else null,
                timeIntent = if (result.timeIntent >= 0) TimeIntent.fromInt(result.timeIntent) else null
            )
        }
    }

    // ========================================================================
    // Spelling Correction (delegating to Swift)
    // ========================================================================

    /**
     * Correct spelling errors in query.
     * Delegates to Swift SearchEngine.
     */
    fun correctSpelling(query: String): SpellingCorrection {
        val swiftResult: SwiftSpellingCorrection = SwiftEngine.correctSpelling(query)

        return swiftResult.use { result ->
            SpellingCorrection(
                originalQuery = result.originalQuery,
                correctedQuery = result.correctedQuery,
                corrections = emptyList(), // Simplified - corrections count available
                hasCorrections = result.hasCorrections
            )
        }
    }

    // ========================================================================
    // Synonym Expansion (delegating to Swift)
    // ========================================================================

    /**
     * Expand query with synonyms for better recall.
     * Delegates to Swift SearchEngine.
     */
    fun expandSynonyms(tokens: List<String>): List<String> {
        val result = SwiftEngine.expandSynonyms(tokens.joinToString(","))
        return result.split(",").filter { it.isNotEmpty() }
    }

    // ========================================================================
    // Relevance Scoring (delegating to Swift)
    // ========================================================================

    /**
     * Rank search results based on relevance.
     * Delegates to Swift SearchEngine for scoring.
     */
    suspend fun rankResults(
        query: ParsedQuery,
        results: List<SearchableItem>,
        userContext: SearchUserContext?
    ): List<RankedResult> = withContext(Dispatchers.Default) {
        results.map { item ->
            val score = calculateRelevanceScore(query, item, userContext)
            RankedResult(
                item = item,
                score = score.total,
                scoreBreakdown = score,
                matchedTerms = findMatchedTerms(query, item)
            )
        }.sortedByDescending { it.score }
    }

    /**
     * Calculate relevance score for a single item.
     * Delegates to Swift SearchEngine.
     */
    private fun calculateRelevanceScore(
        query: ParsedQuery,
        item: SearchableItem,
        userContext: SearchUserContext?
    ): RelevanceScore {
        val distance = if (userContext?.location != null && item.latitude != null && item.longitude != null) {
            calculateDistance(
                userContext.location.first, userContext.location.second,
                item.latitude, item.longitude
            )
        } else null

        val swiftResult: SwiftRelevanceScore = SwiftEngine.calculateRelevance(
            query.searchTerms.joinToString(","),
            query.categories.joinToString(","),
            query.dietaryFilters.joinToString(","),
            item.title,
            item.description,
            item.category,
            item.dietaryTags.joinToString(","),
            item.createdAt,
            distance ?: 0.0,
            distance != null,
            item.viewCount,
            userContext?.preferredCategories?.joinToString(",") ?: "",
            userContext?.trustedUsers?.contains(item.authorId) == true
        )

        return swiftResult.use { result ->
            RelevanceScore(
                textMatch = result.textMatch,
                categoryMatch = result.categoryMatch,
                dietaryMatch = result.dietaryMatch,
                recencyBoost = result.recencyBoost,
                distanceBoost = result.distanceBoost,
                personalBoost = result.personalBoost,
                popularityBoost = result.popularityBoost
            )
        }
    }

    // ========================================================================
    // Fuzzy Matching (delegating to Swift)
    // ========================================================================

    /**
     * Perform fuzzy matching with configurable threshold.
     * Delegates to Swift SearchEngine.
     */
    fun fuzzyMatch(query: String, candidate: String, threshold: Double = 0.7): FuzzyMatchResult {
        val swiftResult: SwiftFuzzyMatchResult = SwiftEngine.fuzzyMatch(query, candidate, threshold)

        return swiftResult.use { result ->
            FuzzyMatchResult(
                isMatch = result.isMatch,
                similarity = result.similarity,
                editDistance = result.editDistance
            )
        }
    }

    /**
     * Calculate Levenshtein edit distance.
     * Delegates to Swift SearchEngine.
     */
    fun editDistance(s1: String, s2: String): Int {
        return SwiftEngine.editDistance(s1, s2)
    }

    // ========================================================================
    // Suggestions (Kotlin-only, not in Swift)
    // ========================================================================

    /**
     * Get autocomplete suggestions for partial query.
     */
    fun getSuggestions(
        partialQuery: String,
        recentSearches: List<String>,
        popularSearches: List<String>
    ): List<SearchSuggestion> {
        val suggestions = mutableListOf<SearchSuggestion>()
        val lowercasedQuery = partialQuery.lowercase()

        // Recent searches
        recentSearches.filter { it.lowercase().startsWith(lowercasedQuery) }
            .forEach { suggestions.add(SearchSuggestion(it, SuggestionType.RECENT, 100)) }

        // Popular searches
        popularSearches.filter { it.lowercase().startsWith(lowercasedQuery) }
            .forEach { suggestions.add(SearchSuggestion(it, SuggestionType.POPULAR, 80)) }

        // Category suggestions
        val categories = listOf("vegetables", "fruits", "bakery", "dairy", "prepared meals", "beverages")
        categories.filter { it.lowercase().startsWith(lowercasedQuery) }
            .forEach { suggestions.add(SearchSuggestion(it, SuggestionType.CATEGORY, 60)) }

        // Dedupe and sort
        return suggestions
            .distinctBy { it.text.lowercase() }
            .sortedByDescending { it.score }
            .take(8)
    }

    // ========================================================================
    // Facets (Kotlin-only, not in Swift)
    // ========================================================================

    /**
     * Aggregate facets from search results.
     */
    fun aggregateFacets(results: List<SearchableItem>): SearchFacets {
        val categoryCounts = results.groupingBy { it.category }.eachCount()
        val dietaryCounts = results.flatMap { it.dietaryTags }
            .groupingBy { it }
            .eachCount()

        return SearchFacets(
            categories = categoryCounts.map { FacetValue(it.key, it.value) }
                .sortedByDescending { it.count },
            dietary = dietaryCounts.map { FacetValue(it.key, it.value) }
                .sortedByDescending { it.count },
            distanceRanges = listOf(
                FacetValue("< 1km", 0),
                FacetValue("1-5km", 0),
                FacetValue("5-10km", 0),
                FacetValue("> 10km", 0)
            )
        )
    }

    // ========================================================================
    // Private Helpers
    // ========================================================================

    private fun calculateDistance(lat1: Double, lng1: Double, lat2: Double, lng2: Double): Double {
        val R = 6371.0 // Earth radius in km
        val dLat = Math.toRadians(lat2 - lat1)
        val dLng = Math.toRadians(lng2 - lng1)
        val a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) *
                Math.sin(dLng / 2) * Math.sin(dLng / 2)
        val c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
        return R * c
    }

    private fun findMatchedTerms(query: ParsedQuery, item: SearchableItem): List<String> {
        val result = SwiftEngine.findMatchedTerms(
            query.searchTerms.joinToString(","),
            "${item.title} ${item.description}"
        )
        return result.split(",").filter { it.isNotEmpty() }
    }
}

// ========================================================================
// Data Classes
// ========================================================================

@Serializable
data class ParsedQuery(
    val originalQuery: String,
    val normalizedQuery: String,
    val tokens: List<String>,
    val searchTerms: List<String>,
    val categories: List<String>,
    val dietaryFilters: List<String>,
    val locationIntent: LocationIntent?,
    val timeIntent: TimeIntent?
)

@Serializable
enum class LocationIntent {
    NEARBY,
    WALKING_DISTANCE,
    DELIVERY,
    SPECIFIC_AREA;

    companion object {
        fun fromInt(value: Int): LocationIntent = when (value) {
            0 -> NEARBY
            1 -> WALKING_DISTANCE
            2 -> DELIVERY
            3 -> SPECIFIC_AREA
            else -> NEARBY
        }
    }
}

@Serializable
enum class TimeIntent {
    NOW,
    TODAY,
    TOMORROW,
    WEEKEND;

    companion object {
        fun fromInt(value: Int): TimeIntent = when (value) {
            0 -> NOW
            1 -> TODAY
            2 -> TOMORROW
            3 -> WEEKEND
            else -> NOW
        }
    }
}

@Serializable
data class SpellingCorrection(
    val originalQuery: String,
    val correctedQuery: String,
    val corrections: List<Pair<String, String>>,
    val hasCorrections: Boolean
)

@Serializable
data class SearchableItem(
    val id: String,
    val title: String,
    val description: String,
    val category: String,
    val dietaryTags: List<String>,
    val authorId: String,
    val createdAt: Long,
    val latitude: Double?,
    val longitude: Double?,
    val viewCount: Int
)

@Serializable
data class SearchUserContext(
    val userId: String,
    val location: Pair<Double, Double>?,
    val preferredCategories: List<String>,
    val trustedUsers: List<String>,
    val recentSearches: List<String>
)

@Serializable
data class RankedResult(
    val item: SearchableItem,
    val score: Double,
    val scoreBreakdown: RelevanceScore,
    val matchedTerms: List<String>
)

@Serializable
data class RelevanceScore(
    val textMatch: Double,
    val categoryMatch: Double,
    val dietaryMatch: Double,
    val recencyBoost: Double,
    val distanceBoost: Double,
    val personalBoost: Double,
    val popularityBoost: Double
) {
    val total: Double
        get() = textMatch + categoryMatch + dietaryMatch +
                recencyBoost + distanceBoost + personalBoost + popularityBoost
}

data class FuzzyMatchResult(
    val isMatch: Boolean,
    val similarity: Double,
    val editDistance: Int
)

@Serializable
data class SearchSuggestion(
    val text: String,
    val type: SuggestionType,
    val score: Int
)

@Serializable
enum class SuggestionType {
    RECENT,
    POPULAR,
    CATEGORY,
    DIETARY
}

@Serializable
data class SearchFacets(
    val categories: List<FacetValue>,
    val dietary: List<FacetValue>,
    val distanceRanges: List<FacetValue>
)

@Serializable
data class FacetValue(
    val name: String,
    val count: Int
)
