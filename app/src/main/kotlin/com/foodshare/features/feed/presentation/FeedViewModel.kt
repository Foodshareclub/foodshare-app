package com.foodshare.features.feed.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.cache.CacheKeys
import com.foodshare.core.cache.OfflineCache
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.core.optimistic.EntityType
import com.foodshare.core.optimistic.ErrorCategory
import com.foodshare.core.optimistic.OptimisticUpdate
import com.foodshare.core.optimistic.OptimisticUpdateBridge
import com.foodshare.core.optimistic.UpdateOperation
import com.foodshare.core.recommendations.ContentItem
import com.foodshare.core.recommendations.RecommendationBridge
import com.foodshare.core.recommendations.UserPreferences
import com.foodshare.domain.model.Category
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.PostType
import com.foodshare.domain.repository.FavoritesRepository
import com.foodshare.domain.repository.FeedRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.time.Instant
import java.time.format.DateTimeFormatter
import javax.inject.Inject

/**
 * ViewModel for the Feed screen
 *
 * Manages listing data, filtering, and pagination.
 * Supports offline caching for improved UX.
 *
 * SYNC: Mirrors Swift FeedViewModel
 */
@HiltViewModel
class FeedViewModel @Inject constructor(
    private val feedRepository: FeedRepository,
    private val favoritesRepository: FavoritesRepository,
    private val offlineCache: OfflineCache
) : ViewModel() {

    private val json = Json { ignoreUnknownKeys = true }

    private val _uiState = MutableStateFlow(FeedUiState())
    val uiState: StateFlow<FeedUiState> = _uiState.asStateFlow()

    // Default location (can be updated with actual user location)
    private var currentLatitude = 37.7749 // San Francisco
    private var currentLongitude = -122.4194

    // User preferences for Swift-based recommendation ranking
    private var userPreferences = UserPreferences(
        maxDistanceKm = 10.0,
        preferVerifiedDonors = false
    )

    init {
        loadCategories()
        loadListings()
        loadFavorites()
    }

    /**
     * Update user preferences for personalized feed ranking.
     * Preferences are used by Swift RecommendationBridge.
     */
    fun updatePreferences(
        preferredCategories: Set<String> = userPreferences.preferredCategories,
        dietaryRequirements: Set<String> = userPreferences.dietaryRequirements,
        maxDistanceKm: Double? = userPreferences.maxDistanceKm,
        preferVerifiedDonors: Boolean = userPreferences.preferVerifiedDonors
    ) {
        userPreferences = userPreferences.copy(
            preferredCategories = preferredCategories,
            dietaryRequirements = dietaryRequirements,
            maxDistanceKm = maxDistanceKm,
            preferVerifiedDonors = preferVerifiedDonors
        )
        // Re-rank current listings with new preferences
        viewModelScope.launch {
            val rankedListings = rankListings(_uiState.value.listings)
            _uiState.update { it.copy(listings = rankedListings) }
        }
    }

    private fun loadFavorites() {
        viewModelScope.launch {
            favoritesRepository.getFavorites()
                .onSuccess { favorites ->
                    _uiState.update { it.copy(favoriteIds = favorites) }
                }
        }
    }

    fun refresh() {
        _uiState.update { it.copy(isRefreshing = true, offset = 0) }
        loadListings(isRefresh = true)
    }

    fun loadMore() {
        val state = _uiState.value
        if (state.isLoading || !state.hasMore) return

        _uiState.update { it.copy(isLoadingMore = true) }
        loadListings(isLoadMore = true)
    }

    fun selectCategory(postType: PostType?) {
        _uiState.update {
            it.copy(
                selectedPostType = postType,
                offset = 0,
                listings = emptyList()
            )
        }
        loadListings()
    }

    fun updateLocation(latitude: Double, longitude: Double) {
        currentLatitude = latitude
        currentLongitude = longitude
        refresh()
    }

    /**
     * Toggle favorite status with Swift-backed optimistic updates.
     * Uses OptimisticUpdateBridge for:
     * - Consistent rollback logic across platforms
     * - Smart retry with exponential backoff
     * - Proper error categorization
     */
    fun toggleFavorite(listingId: Int) {
        val isFavorited = _uiState.value.favoriteIds.contains(listingId)
        val operation = if (isFavorited) UpdateOperation.UNFAVORITE else UpdateOperation.FAVORITE

        // Create optimistic update via Swift bridge
        val optimisticUpdate = OptimisticUpdateBridge.createUpdate(
            id = listingId.toString(),
            entityType = EntityType.FAVORITE,
            operation = operation,
            originalValue = isFavorited.toString(),
            optimisticValue = (!isFavorited).toString()
        )

        // Apply optimistic update to UI immediately
        _uiState.update { state ->
            val newFavorites = if (isFavorited) {
                state.favoriteIds - listingId
            } else {
                state.favoriteIds + listingId
            }
            state.copy(favoriteIds = newFavorites)
        }

        // Persist to Supabase
        viewModelScope.launch {
            favoritesRepository.toggleFavorite(listingId)
                .onSuccess {
                    // Confirm the optimistic update
                    optimisticUpdate?.let { OptimisticUpdateBridge.confirmUpdate(it) }
                }
                .onFailure { error ->
                    // Use Swift bridge for rollback decision
                    if (optimisticUpdate != null) {
                        val recommendation = OptimisticUpdateBridge.handleError(
                            update = optimisticUpdate,
                            errorCode = "TOGGLE_FAILED",
                            errorMessage = ErrorBridge.mapFavoritesError(error),
                            category = categorizeError(error)
                        )

                        if (recommendation.shouldRollback) {
                            // Rollback via Swift bridge
                            OptimisticUpdateBridge.rollback(optimisticUpdate)
                            // Revert UI state
                            _uiState.update { state ->
                                val revertedFavorites = if (isFavorited) {
                                    state.favoriteIds + listingId
                                } else {
                                    state.favoriteIds - listingId
                                }
                                state.copy(favoriteIds = revertedFavorites)
                            }
                        } else if (recommendation.shouldRetry && recommendation.delayMs != null) {
                            // Schedule retry with suggested delay
                            delay(recommendation.delayMs)
                            toggleFavorite(listingId)
                        }
                    }
                }
        }
    }

    /**
     * Categorize error for OptimisticUpdateBridge.
     */
    private fun categorizeError(error: Throwable): ErrorCategory {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("network") || message.contains("timeout") -> ErrorCategory.NETWORK
            message.contains("unauthorized") || message.contains("401") -> ErrorCategory.AUTHORIZATION
            message.contains("conflict") || message.contains("409") -> ErrorCategory.CONFLICT
            message.contains("validation") || message.contains("400") -> ErrorCategory.VALIDATION
            message.contains("server") || message.contains("500") -> ErrorCategory.SERVER_ERROR
            else -> ErrorCategory.UNKNOWN
        }
    }

    private fun loadListings(isRefresh: Boolean = false, isLoadMore: Boolean = false) {
        viewModelScope.launch {
            val state = _uiState.value
            val offset = if (isRefresh) 0 else state.offset

            if (!isLoadMore) {
                _uiState.update { it.copy(isLoading = true) }
            }

            feedRepository.getNearbyListings(
                latitude = currentLatitude,
                longitude = currentLongitude,
                radiusKm = 10.0,
                limit = PAGE_SIZE,
                offset = offset,
                postType = state.selectedPostType?.name?.lowercase()
            ).onSuccess { newListings ->
                // Cache first page of listings for offline access
                if (offset == 0 && state.selectedPostType == null) {
                    cacheListings(newListings)
                }

                // Apply Swift-based personalized ranking
                val rankedListings = rankListings(newListings)

                _uiState.update { currentState ->
                    val allListings = if (isRefresh || offset == 0) {
                        rankedListings
                    } else {
                        // For pagination, append new ranked listings
                        currentState.listings + rankedListings
                    }

                    currentState.copy(
                        listings = allListings,
                        isLoading = false,
                        isRefreshing = false,
                        isLoadingMore = false,
                        isOffline = false,
                        error = null,
                        offset = offset + newListings.size,
                        hasMore = newListings.size >= PAGE_SIZE
                    )
                }
            }.onFailure { error ->
                // Try to load from cache on failure
                if (offset == 0) {
                    loadFromCache()
                }

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        isRefreshing = false,
                        isLoadingMore = false,
                        error = ErrorBridge.mapFeedError(error)
                    )
                }
            }
        }
    }

    private suspend fun cacheListings(listings: List<FoodListing>) {
        try {
            offlineCache.save(
                key = CacheKeys.FEED_LISTINGS,
                data = json.encodeToString(
                    kotlinx.serialization.builtins.ListSerializer(FoodListing.serializer()),
                    listings
                ),
                ttlMs = OfflineCache.DEFAULT_TTL_MS
            )
        } catch (e: Exception) {
            // Cache failure is non-critical
        }
    }

    private suspend fun loadFromCache() {
        try {
            val cached = offlineCache.load(
                key = CacheKeys.FEED_LISTINGS,
                deserialize = { jsonStr ->
                    json.decodeFromString(
                        kotlinx.serialization.builtins.ListSerializer(FoodListing.serializer()),
                        jsonStr
                    )
                }
            )

            if (cached != null && !cached.isExpired) {
                _uiState.update {
                    it.copy(
                        listings = cached.data,
                        isOffline = true
                    )
                }
            }
        } catch (e: Exception) {
            // Cache load failure is non-critical
        }
    }

    private fun loadCategories() {
        viewModelScope.launch {
            feedRepository.getCategories()
                .onSuccess { categories ->
                    _uiState.update { it.copy(categories = categories) }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    // =========================================================================
    // Swift RecommendationBridge Integration
    // =========================================================================

    /**
     * Rank listings using Swift RecommendationBridge.
     * Applies personalized scoring based on user preferences.
     */
    private suspend fun rankListings(listings: List<FoodListing>): List<FoodListing> {
        if (listings.isEmpty()) return listings

        return withContext(Dispatchers.Default) {
            try {
                // Convert FoodListings to ContentItems for Swift ranking
                val contentItems = listings.map { it.toContentItem() }

                // Get ranking from Swift via RecommendationBridge
                val rankingResult = RecommendationBridge.rankFeedItems(
                    items = contentItems,
                    preferences = userPreferences,
                    configPreset = when (_uiState.value.selectedPostType) {
                        PostType.FOOD -> "nearby"
                        PostType.WANTED -> "forYou"
                        else -> "default"
                    }
                )

                // If ranking failed, return original order
                if (rankingResult.error != null || rankingResult.items.isEmpty()) {
                    return@withContext listings
                }

                // Create a map of id -> score for sorting
                val scoreMap = rankingResult.items
                    .filter { !it.shouldFilter }
                    .associate { it.id to it.score }

                // Sort listings by score (highest first), keeping unscored at end
                listings.sortedByDescending { listing ->
                    scoreMap[listing.id.toString()] ?: 0.0
                }
            } catch (e: Exception) {
                // On any error, return original order
                listings
            }
        }
    }

    /**
     * Convert FoodListing to ContentItem for Swift ranking.
     */
    private fun FoodListing.toContentItem(): ContentItem {
        return ContentItem(
            id = this.id.toString(),
            title = this.title,
            categoryId = this.categoryId?.toString() ?: "unknown",
            categoryName = "", // FoodListing doesn't have category name yet
            dietaryTags = emptySet(), // FoodListing doesn't have dietary tags yet
            distanceKm = this.distanceKm,
            donorRating = null, // FoodListing doesn't have donor rating yet
            donorIsVerified = false, // FoodListing doesn't have verification yet
            pickupStartHour = null, // Not in FoodListing model
            pickupEndHour = null,
            createdAt = Instant.now().toString(), // FoodListing doesn't have createdAt
            expiresAt = null, // FoodListing doesn't have expiresAt
            viewCount = this.postViews,
            favoriteCount = this.postLikeCounter ?: 0,
            claimCount = 0
        )
    }

    /**
     * Record category view for affinity tracking.
     * Called when user views a listing to improve future recommendations.
     */
    fun recordCategoryView(categoryId: String) {
        viewModelScope.launch {
            val currentAffinity = userPreferences.categoryAffinities[categoryId] ?: 0.0
            val newAffinities = userPreferences.categoryAffinities + (categoryId to (currentAffinity + 0.1))
            userPreferences = userPreferences.copy(categoryAffinities = newAffinities)
        }
    }

    companion object {
        private const val PAGE_SIZE = 20
    }
}

/**
 * UI state for the Feed screen
 */
data class FeedUiState(
    val listings: List<FoodListing> = emptyList(),
    val categories: List<Category> = emptyList(),
    val selectedPostType: PostType? = null,
    val isLoading: Boolean = false,
    val isRefreshing: Boolean = false,
    val isLoadingMore: Boolean = false,
    val isOffline: Boolean = false,
    val error: String? = null,
    val offset: Int = 0,
    val hasMore: Boolean = true,
    val favoriteIds: Set<Int> = emptySet()
) {
    val isEmpty: Boolean get() = listings.isEmpty() && !isLoading
    val showEmptyState: Boolean get() = isEmpty && error == null
    val offlineIndicator: String? get() = if (isOffline) "Showing cached listings" else null
}
