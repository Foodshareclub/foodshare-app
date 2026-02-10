package com.foodshare.domain.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Search filters for food item discovery
 *
 * Kotlin fallback for Swift FoodshareCore.SearchFilters
 */
@Serializable
data class SearchFilters(
    val query: String = "",
    @SerialName("radius_km") val radiusKm: Double = 10.0,
    val categories: List<String> = emptyList(),
    @SerialName("post_types") val postTypes: List<String> = emptyList(),
    @SerialName("dietary_preferences") val dietaryPreferences: List<DietaryPreference> = emptyList(),
    @SerialName("freshness_hours") val freshnessHours: Int? = null,
    @SerialName("sort_by") val sortBy: SortOption = SortOption.RELEVANCE
) {
    val hasActiveFilters: Boolean
        get() = categories.isNotEmpty() ||
                postTypes.isNotEmpty() ||
                dietaryPreferences.isNotEmpty() ||
                freshnessHours != null ||
                sortBy != SortOption.RELEVANCE ||
                radiusKm != 10.0

    val activeFilterCount: Int
        get() {
            var count = 0
            if (categories.isNotEmpty()) count += categories.size
            if (postTypes.isNotEmpty()) count += postTypes.size
            if (dietaryPreferences.isNotEmpty()) count += dietaryPreferences.size
            if (freshnessHours != null) count += 1
            if (sortBy != SortOption.RELEVANCE) count += 1
            if (radiusKm != 10.0) count += 1
            return count
        }

    fun reset() = copy(
        query = "",
        radiusKm = 10.0,
        categories = emptyList(),
        postTypes = emptyList(),
        dietaryPreferences = emptyList(),
        freshnessHours = null,
        sortBy = SortOption.RELEVANCE
    )

    companion object {
        val Default = SearchFilters()
    }
}

/**
 * Dietary preferences for filtering
 */
@Serializable
enum class DietaryPreference {
    @SerialName("vegan")
    VEGAN,
    @SerialName("vegetarian")
    VEGETARIAN,
    @SerialName("gluten_free")
    GLUTEN_FREE,
    @SerialName("dairy_free")
    DAIRY_FREE,
    @SerialName("nut_free")
    NUT_FREE,
    @SerialName("halal")
    HALAL,
    @SerialName("kosher")
    KOSHER,
    @SerialName("organic")
    ORGANIC;

    val displayName: String
        get() = when (this) {
            VEGAN -> "Vegan"
            VEGETARIAN -> "Vegetarian"
            GLUTEN_FREE -> "Gluten-Free"
            DAIRY_FREE -> "Dairy-Free"
            NUT_FREE -> "Nut-Free"
            HALAL -> "Halal"
            KOSHER -> "Kosher"
            ORGANIC -> "Organic"
        }
}

/**
 * Sort options for search results
 */
@Serializable
enum class SortOption {
    @SerialName("relevance")
    RELEVANCE,
    @SerialName("distance")
    DISTANCE,
    @SerialName("newest")
    NEWEST,
    @SerialName("rating")
    RATING;

    val displayName: String
        get() = when (this) {
            RELEVANCE -> "Most Relevant"
            DISTANCE -> "Nearest First"
            NEWEST -> "Most Recent"
            RATING -> "Highest Rated"
        }
}

/**
 * Saved filter preset
 */
@Serializable
data class FilterPreset(
    val id: String,
    val name: String,
    val filters: SearchFilters,
    @SerialName("is_default") val isDefault: Boolean = false,
    @SerialName("created_at") val createdAt: String? = null
)

/**
 * Search history item
 */
@Serializable
data class SearchHistoryItem(
    val id: String,
    val query: String,
    @SerialName("result_count") val resultCount: Int = 0,
    @SerialName("created_at") val createdAt: String
)

/**
 * Generic search results container
 */
@Serializable
data class SearchResults<T>(
    val items: List<T>,
    @SerialName("total_count") val totalCount: Int,
    @SerialName("has_more") val hasMore: Boolean
)
