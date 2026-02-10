package com.foodshare.features.listing.presentation

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.core.utilities.DistanceCalculator
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.ListingStatus
import com.foodshare.domain.model.PostType
import com.foodshare.domain.repository.FeedRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for the Listing Detail screen
 *
 * Manages:
 * - Listing data loading
 * - Favorite toggling
 * - Share/contact actions
 * - View count tracking
 */
@HiltViewModel
class ListingDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val feedRepository: FeedRepository
) : ViewModel() {

    private val listingId: Int = checkNotNull(savedStateHandle["id"])

    private val _uiState = MutableStateFlow(ListingDetailUiState())
    val uiState: StateFlow<ListingDetailUiState> = _uiState.asStateFlow()

    init {
        loadListing()
    }

    fun loadListing() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            feedRepository.getListingById(listingId)
                .onSuccess { listing ->
                    _uiState.update {
                        it.copy(
                            listing = listing,
                            isLoading = false,
                            error = null
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapListingError(error)
                        )
                    }
                }
        }
    }

    fun toggleFavorite() {
        _uiState.update { it.copy(isFavorite = !it.isFavorite) }
        // TODO: Persist to Supabase favorites table
    }

    fun setCurrentImageIndex(index: Int) {
        _uiState.update { it.copy(currentImageIndex = index) }
    }

    fun retry() {
        loadListing()
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}

/**
 * UI state for listing detail screen
 */
data class ListingDetailUiState(
    val listing: FoodListing? = null,
    val isLoading: Boolean = true,
    val error: String? = null,
    val isFavorite: Boolean = false,
    val currentImageIndex: Int = 0
) {
    // Derived properties
    val title: String get() = listing?.title ?: ""
    val description: String? get() = listing?.description
    val address: String? get() = listing?.postAddress
    val pickupTime: String? get() = listing?.pickupTime

    val postType: PostType?
        get() = listing?.postType?.let { PostType.fromString(it) }

    val status: ListingStatus
        get() = listing?.status ?: ListingStatus.AVAILABLE

    val isClaimable: Boolean
        get() = status.isClaimable

    val images: List<String>
        get() = listing?.images ?: emptyList()

    val hasMultipleImages: Boolean
        get() = images.size > 1

    val imageCount: Int
        get() = images.size

    val distanceDisplay: String?
        get() = listing?.distanceMeters?.let { meters ->
            DistanceCalculator.formatMeters(meters)
        }

    val viewCount: Int
        get() = listing?.postViews ?: 0

    val likeCount: Int
        get() = listing?.postLikeCounter ?: 0

    val showEmptyState: Boolean
        get() = listing == null && !isLoading && error == null

    val canRetry: Boolean
        get() = error != null
}
