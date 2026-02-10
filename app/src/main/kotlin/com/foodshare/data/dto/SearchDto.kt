package com.foodshare.data.dto

import com.foodshare.domain.model.DietaryPreference
import com.foodshare.domain.model.FilterPreset
import com.foodshare.domain.model.SearchFilters
import com.foodshare.domain.model.SearchHistoryItem
import com.foodshare.domain.model.SortOption
import com.foodshare.domain.repository.SearchResult
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Request params for search_food_items_advanced RPC
 */
@Serializable
data class AdvancedSearchParams(
    @SerialName("p_search_query") val searchQuery: String,
    @SerialName("p_latitude") val latitude: Double?,
    @SerialName("p_longitude") val longitude: Double?,
    @SerialName("p_radius_km") val radiusKm: Int = 50,
    @SerialName("p_limit") val limit: Int = 20,
    @SerialName("p_offset") val offset: Int = 0,
    @SerialName("p_categories") val categories: List<String>? = null,
    @SerialName("p_post_types") val postTypes: List<String>? = null,
    @SerialName("p_dietary_preferences") val dietaryPreferences: List<String>? = null,
    @SerialName("p_freshness_hours") val freshnessHours: Int? = null,
    @SerialName("p_sort_by") val sortBy: String = "relevance"
)

/**
 * Response from search_food_items_advanced
 */
@Serializable
data class AdvancedSearchResponse(
    val success: Boolean = true,
    val items: List<FoodListingDto> = emptyList(),
    @SerialName("total_count") val totalCount: Int = 0
) {
    fun toSearchResult(): SearchResult {
        return SearchResult(
            items = items.map { it.toDomain() },
            totalCount = totalCount,
            hasMore = items.size < totalCount
        )
    }
}

/**
 * DTO for filter presets
 */
@Serializable
data class FilterPresetDto(
    val id: String,
    val name: String,
    val filters: SearchFiltersDto,
    @SerialName("is_default") val isDefault: Boolean = false,
    @SerialName("created_at") val createdAt: String? = null
) {
    fun toDomain(): FilterPreset {
        return FilterPreset(
            id = id,
            name = name,
            filters = filters.toDomain(),
            isDefault = isDefault,
            createdAt = createdAt
        )
    }
}

/**
 * DTO for search filters (stored as JSONB)
 */
@Serializable
data class SearchFiltersDto(
    val query: String = "",
    @SerialName("radius_km") val radiusKm: Double = 10.0,
    val categories: List<String> = emptyList(),
    @SerialName("post_types") val postTypes: List<String> = emptyList(),
    @SerialName("dietary_preferences") val dietaryPreferences: List<String> = emptyList(),
    @SerialName("freshness_hours") val freshnessHours: Int? = null,
    @SerialName("sort_by") val sortBy: String = "relevance"
) {
    fun toDomain(): SearchFilters {
        return SearchFilters(
            query = query,
            radiusKm = radiusKm,
            categories = categories,
            postTypes = postTypes,
            dietaryPreferences = dietaryPreferences.mapNotNull { parseDietaryPreference(it) },
            freshnessHours = freshnessHours,
            sortBy = parseSortOption(sortBy)
        )
    }

    private fun parseDietaryPreference(value: String): DietaryPreference? {
        return DietaryPreference.entries.find { it.name.equals(value, ignoreCase = true) }
    }

    private fun parseSortOption(value: String): SortOption {
        return SortOption.entries.find { it.name.equals(value, ignoreCase = true) }
            ?: SortOption.RELEVANCE
    }

    companion object {
        fun fromDomain(filters: SearchFilters): SearchFiltersDto {
            return SearchFiltersDto(
                query = filters.query,
                radiusKm = filters.radiusKm,
                categories = filters.categories,
                postTypes = filters.postTypes,
                dietaryPreferences = filters.dietaryPreferences.map { it.name.lowercase() },
                freshnessHours = filters.freshnessHours,
                sortBy = filters.sortBy.name.lowercase()
            )
        }
    }
}

/**
 * Response from get_filter_presets
 */
@Serializable
data class FilterPresetsResponse(
    val presets: List<FilterPresetDto> = emptyList()
)

/**
 * Response from save_filter_preset
 */
@Serializable
data class SavePresetResponse(
    val success: Boolean,
    @SerialName("preset_id") val presetId: String? = null
)

/**
 * DTO for search history items
 */
@Serializable
data class SearchHistoryItemDto(
    val id: String,
    val query: String,
    @SerialName("result_count") val resultCount: Int = 0,
    @SerialName("created_at") val createdAt: String
) {
    fun toDomain(): SearchHistoryItem {
        return SearchHistoryItem(
            id = id,
            query = query,
            resultCount = resultCount,
            createdAt = createdAt
        )
    }
}

/**
 * Response from get_search_history
 */
@Serializable
data class SearchHistoryResponse(
    val history: List<SearchHistoryItemDto> = emptyList()
)

/**
 * Params for record_search RPC
 */
@Serializable
data class RecordSearchParams(
    @SerialName("p_user_id") val userId: String,
    @SerialName("p_query") val query: String,
    @SerialName("p_filters") val filters: SearchFiltersDto? = null,
    @SerialName("p_result_count") val resultCount: Int = 0
)
