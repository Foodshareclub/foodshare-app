package com.foodshare.domain.repository

import com.foodshare.domain.model.FilterPreset
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.SearchFilters
import com.foodshare.domain.model.SearchHistoryItem

/**
 * Repository interface for search operations
 *
 * Matches iOS: SearchRepository
 */
interface SearchRepository {

    /**
     * Search for food items with advanced filters
     */
    suspend fun search(
        filters: SearchFilters,
        latitude: Double,
        longitude: Double,
        limit: Int = 20,
        offset: Int = 0
    ): Result<SearchResult>

    /**
     * Get search suggestions for autocomplete
     */
    suspend fun getSuggestions(prefix: String, limit: Int = 5): Result<List<String>>

    /**
     * Save a filter preset
     */
    suspend fun saveFilterPreset(
        name: String,
        filters: SearchFilters,
        isDefault: Boolean = false
    ): Result<FilterPreset>

    /**
     * Get user's saved filter presets
     */
    suspend fun getFilterPresets(): Result<List<FilterPreset>>

    /**
     * Delete a filter preset
     */
    suspend fun deleteFilterPreset(id: String): Result<Unit>

    /**
     * Set a preset as default
     */
    suspend fun setDefaultPreset(id: String): Result<Unit>

    /**
     * Get recent search history
     */
    suspend fun getSearchHistory(limit: Int = 10): Result<List<SearchHistoryItem>>

    /**
     * Clear search history
     */
    suspend fun clearSearchHistory(): Result<Unit>

    /**
     * Record a search query
     */
    suspend fun recordSearch(
        query: String,
        filters: SearchFilters?,
        resultCount: Int
    ): Result<Unit>
}

/**
 * Search result container
 */
data class SearchResult(
    val items: List<FoodListing>,
    val totalCount: Int,
    val hasMore: Boolean
)
