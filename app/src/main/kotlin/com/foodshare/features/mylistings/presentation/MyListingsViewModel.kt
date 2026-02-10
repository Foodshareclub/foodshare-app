package com.foodshare.features.mylistings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.ListingStatus
import com.foodshare.domain.repository.ListingRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for My Listings screen
 *
 * Manages user's own listings with filtering and actions
 */
@HiltViewModel
class MyListingsViewModel @Inject constructor(
    private val listingRepository: ListingRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(MyListingsUiState())
    val uiState: StateFlow<MyListingsUiState> = _uiState.asStateFlow()

    init {
        loadListings()
    }

    fun loadListings() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            listingRepository.getMyListings()
                .onSuccess { listings ->
                    _uiState.update {
                        it.copy(
                            allListings = listings,
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

    fun refresh() {
        _uiState.update { it.copy(isRefreshing = true) }
        viewModelScope.launch {
            listingRepository.getMyListings()
                .onSuccess { listings ->
                    _uiState.update {
                        it.copy(
                            allListings = listings,
                            isRefreshing = false,
                            error = null
                        )
                    }
                }
                .onFailure {
                    _uiState.update { it.copy(isRefreshing = false) }
                }
        }
    }

    fun setFilter(filter: ListingFilter) {
        _uiState.update { it.copy(filter = filter) }
    }

    fun deleteListing(listingId: Int) {
        viewModelScope.launch {
            listingRepository.deleteListing(listingId)
                .onSuccess {
                    // Remove from local list
                    _uiState.update { state ->
                        state.copy(
                            allListings = state.allListings.filter { it.id != listingId }
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = ErrorBridge.mapListingError(error)) }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}

/**
 * Filter options for listings
 */
enum class ListingFilter(val displayName: String) {
    ALL("All"),
    ACTIVE("Active"),
    ARRANGED("Arranged"),
    INACTIVE("Inactive")
}

/**
 * UI state for My Listings screen
 */
data class MyListingsUiState(
    val allListings: List<FoodListing> = emptyList(),
    val filter: ListingFilter = ListingFilter.ALL,
    val isLoading: Boolean = true,
    val isRefreshing: Boolean = false,
    val error: String? = null
) {
    /**
     * Filtered listings based on current filter
     */
    val listings: List<FoodListing>
        get() = when (filter) {
            ListingFilter.ALL -> allListings
            ListingFilter.ACTIVE -> allListings.filter { it.status == ListingStatus.AVAILABLE }
            ListingFilter.ARRANGED -> allListings.filter { it.status == ListingStatus.ARRANGED }
            ListingFilter.INACTIVE -> allListings.filter { it.status == ListingStatus.INACTIVE }
        }

    val isEmpty: Boolean
        get() = listings.isEmpty() && !isLoading

    val showEmptyState: Boolean
        get() = isEmpty && error == null

    /**
     * Count for each filter
     */
    val activeCount: Int get() = allListings.count { it.status == ListingStatus.AVAILABLE }
    val arrangedCount: Int get() = allListings.count { it.status == ListingStatus.ARRANGED }
    val inactiveCount: Int get() = allListings.count { it.status == ListingStatus.INACTIVE }
    val totalCount: Int get() = allListings.size
}
