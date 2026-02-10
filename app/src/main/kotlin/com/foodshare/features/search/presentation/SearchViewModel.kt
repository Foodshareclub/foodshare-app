package com.foodshare.features.search.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.cache.CacheKeys
import com.foodshare.core.cache.OfflineCache
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.core.matching.MatchingBridge
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.domain.model.DietaryPreference
import com.foodshare.domain.model.FilterPreset
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.SearchFilters
import com.foodshare.domain.model.SearchHistoryItem
import com.foodshare.domain.model.SortOption
import com.foodshare.domain.repository.SearchRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.withContext
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import javax.inject.Inject

/**
 * ViewModel for the Search screen
 *
 * Handles advanced search with filters, presets, and history.
 * Supports offline caching for improved UX.
 *
 * SYNC: Mirrors Swift SearchViewModel
 */
@HiltViewModel
class SearchViewModel @Inject constructor(
    private val searchRepository: SearchRepository,
    private val offlineCache: OfflineCache
) : ViewModel() {

    private val json = Json { ignoreUnknownKeys = true }

    private val _uiState = MutableStateFlow(SearchUiState())
    val uiState: StateFlow<SearchUiState> = _uiState.asStateFlow()

    // Default location (should be updated with actual user location)
    private var currentLatitude = 37.7749 // San Francisco
    private var currentLongitude = -122.4194

    private var searchJob: Job? = null

    init {
        loadPresets()
        loadHistory()
    }

    fun updateQuery(query: String) {
        // Validate query using Swift
        val validationResult = ValidationBridge.validateSearchQuery(query)
        val queryError = if (validationResult.isValid) null else validationResult.firstError

        _uiState.update { it.copy(
            filters = it.filters.copy(query = query),
            error = queryError
        ) }

        // Only search if query is valid
        if (!validationResult.isValid) return

        // Debounced search
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(300) // Debounce
            if (query.isNotBlank()) {
                search()
            }
        }
    }

    fun search() {
        val filters = _uiState.value.filters
        if (filters.query.isBlank() && !filters.hasActiveFilters) {
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            searchRepository.search(
                filters = filters,
                latitude = currentLatitude,
                longitude = currentLongitude
            ).onSuccess { result ->
                // Apply Swift-based matching scores for personalized ranking
                val scoredResults = scoreResults(result.items)

                _uiState.update {
                    it.copy(
                        results = scoredResults,
                        totalCount = result.totalCount,
                        hasMore = result.hasMore,
                        isLoading = false
                    )
                }

                // Record search
                if (filters.query.isNotBlank()) {
                    searchRepository.recordSearch(
                        query = filters.query,
                        filters = filters,
                        resultCount = result.totalCount
                    )
                }
            }.onFailure { error ->
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = ErrorBridge.mapSearchError(error)
                    )
                }
            }
        }
    }

    fun loadMore() {
        val state = _uiState.value
        if (state.isLoadingMore || !state.hasMore) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingMore = true) }

            searchRepository.search(
                filters = state.filters,
                latitude = currentLatitude,
                longitude = currentLongitude,
                offset = state.results.size
            ).onSuccess { result ->
                // Apply Swift-based matching scores for personalized ranking
                val scoredResults = scoreResults(result.items)

                _uiState.update {
                    it.copy(
                        results = it.results + scoredResults,
                        hasMore = result.hasMore,
                        isLoadingMore = false
                    )
                }
            }.onFailure {
                _uiState.update { it.copy(isLoadingMore = false) }
            }
        }
    }

    fun updateFilters(filters: SearchFilters) {
        _uiState.update { it.copy(filters = filters) }
    }

    fun setRadius(radiusKm: Double) {
        // Clamp radius to valid range using Swift
        val clampedRadius = ValidationBridge.clampSearchRadius(radiusKm)
        _uiState.update { it.copy(filters = it.filters.copy(radiusKm = clampedRadius)) }
    }

    fun toggleCategory(category: String) {
        _uiState.update { state ->
            val current = state.filters.categories
            val updated = if (current.contains(category)) {
                current - category
            } else {
                current + category
            }
            state.copy(filters = state.filters.copy(categories = updated))
        }
    }

    fun toggleDietaryPreference(preference: DietaryPreference) {
        _uiState.update { state ->
            val current = state.filters.dietaryPreferences
            val updated = if (current.contains(preference)) {
                current - preference
            } else {
                current + preference
            }
            state.copy(filters = state.filters.copy(dietaryPreferences = updated))
        }
    }

    fun setSortOption(sortBy: SortOption) {
        _uiState.update { it.copy(filters = it.filters.copy(sortBy = sortBy)) }
    }

    fun setFreshnessHours(hours: Int?) {
        _uiState.update { it.copy(filters = it.filters.copy(freshnessHours = hours)) }
    }

    fun clearFilters() {
        _uiState.update { it.copy(filters = SearchFilters.Default) }
    }

    fun showFilterSheet(show: Boolean) {
        _uiState.update { it.copy(showFilterSheet = show) }
    }

    // Filter presets
    private fun loadPresets() {
        viewModelScope.launch {
            searchRepository.getFilterPresets()
                .onSuccess { presets ->
                    _uiState.update { it.copy(presets = presets) }

                    // Apply default preset if exists
                    presets.find { it.isDefault }?.let { defaultPreset ->
                        _uiState.update { it.copy(filters = defaultPreset.filters) }
                    }
                }
        }
    }

    fun savePreset(name: String) {
        viewModelScope.launch {
            searchRepository.saveFilterPreset(
                name = name,
                filters = _uiState.value.filters
            ).onSuccess {
                loadPresets()
            }
        }
    }

    fun applyPreset(preset: FilterPreset) {
        _uiState.update { it.copy(filters = preset.filters) }
        search()
    }

    fun deletePreset(id: String) {
        viewModelScope.launch {
            searchRepository.deleteFilterPreset(id)
                .onSuccess { loadPresets() }
        }
    }

    // Search history
    private fun loadHistory() {
        viewModelScope.launch {
            searchRepository.getSearchHistory()
                .onSuccess { history ->
                    _uiState.update { it.copy(history = history) }
                    // Cache history for offline access
                    cacheHistory(history)
                }
                .onFailure {
                    // Try to load from cache
                    loadHistoryFromCache()
                }
        }
    }

    private suspend fun cacheHistory(history: List<SearchHistoryItem>) {
        try {
            offlineCache.save(
                key = CacheKeys.SEARCH_HISTORY,
                data = json.encodeToString(
                    kotlinx.serialization.builtins.ListSerializer(SearchHistoryItem.serializer()),
                    history
                ),
                ttlMs = OfflineCache.LONG_TTL_MS
            )
        } catch (e: Exception) {
            // Cache failure is non-critical
        }
    }

    private suspend fun loadHistoryFromCache() {
        try {
            val cached = offlineCache.load(
                key = CacheKeys.SEARCH_HISTORY,
                deserialize = { jsonStr ->
                    json.decodeFromString(
                        kotlinx.serialization.builtins.ListSerializer(SearchHistoryItem.serializer()),
                        jsonStr
                    )
                }
            )

            if (cached != null && !cached.isExpired) {
                _uiState.update { it.copy(history = cached.data) }
            }
        } catch (e: Exception) {
            // Cache load failure is non-critical
        }
    }

    fun applyHistoryItem(item: SearchHistoryItem) {
        _uiState.update { it.copy(filters = it.filters.copy(query = item.query)) }
        search()
    }

    fun clearHistory() {
        viewModelScope.launch {
            searchRepository.clearSearchHistory()
                .onSuccess {
                    _uiState.update { it.copy(history = emptyList()) }
                }
        }
    }

    /**
     * Update user's current location for proximity search.
     *
     * Uses Swift-backed ValidationBridge to validate coordinates.
     */
    fun updateLocation(latitude: Double, longitude: Double) {
        // Validate coordinates using Swift validation
        if (!ValidationBridge.isValidCoordinate(latitude, longitude)) {
            return // Silently ignore invalid coordinates
        }
        currentLatitude = latitude
        currentLongitude = longitude
    }

    // =========================================================================
    // Swift MatchingBridge Integration
    // =========================================================================

    /**
     * Score and sort search results using Swift MatchingBridge.
     * Applies relevance scoring based on user preferences and location.
     */
    private suspend fun scoreResults(results: List<FoodListing>): List<FoodListing> {
        if (results.isEmpty()) return results

        return withContext(Dispatchers.Default) {
            try {
                val filters = _uiState.value.filters

                // Convert listings to MatchCandidates
                val candidates = results.map { it.toMatchCandidate() }

                // Create match context from search filters
                val context = MatchingBridge.MatchingContext(
                    userLatitude = currentLatitude,
                    userLongitude = currentLongitude,
                    userDietaryPreferences = filters.dietaryPreferences.map { it.name.lowercase() }
                )

                // Get match scores from Swift via MatchingBridge
                val matchResults = MatchingBridge.findBestMatches(
                    candidates = candidates,
                    context = context,
                    maxResults = results.size
                )

                if (matchResults.matches.isEmpty()) {
                    return@withContext results
                }

                // Create a map of id -> score for sorting
                val scoreMap = matchResults.matches.associate { it.id to it.score }

                // Sort results by match score (highest first)
                results.sortedByDescending { listing ->
                    scoreMap[listing.id.toString()] ?: 0.0
                }
            } catch (e: Exception) {
                // On error, return original order
                results
            }
        }
    }

    /**
     * Convert FoodListing to MatchCandidate for Swift matching.
     */
    private fun FoodListing.toMatchCandidate(): MatchingBridge.MatchCandidate {
        return MatchingBridge.MatchCandidate(
            id = this.id.toString(),
            latitude = this.latitude ?: 0.0,
            longitude = this.longitude ?: 0.0,
            dietaryPreferences = emptyList(), // FoodListing doesn't have dietary tags yet
            rating = 0.0, // FoodListing doesn't have donor rating yet
            isVerified = false // FoodListing doesn't have donor verification yet
        )
    }

    /**
     * Get a quick match score for a single listing.
     * Useful for showing relevance indicators in the UI.
     */
    fun getQuickMatchScore(listing: FoodListing): Double {
        return try {
            val candidate = listing.toMatchCandidate()
            val context = MatchingBridge.MatchingContext(
                userLatitude = currentLatitude,
                userLongitude = currentLongitude
            )
            MatchingBridge.quickMatchScore(candidate, context)
        } catch (e: Exception) {
            0.0
        }
    }
}

/**
 * UI State for Search screen
 */
data class SearchUiState(
    val filters: SearchFilters = SearchFilters.Default,
    val results: List<FoodListing> = emptyList(),
    val totalCount: Int = 0,
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = false,
    val error: String? = null,
    val showFilterSheet: Boolean = false,
    val presets: List<FilterPreset> = emptyList(),
    val history: List<SearchHistoryItem> = emptyList()
)
