package com.foodshare.features.listing.presentation

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.domain.repository.ListingRepository
import com.foodshare.domain.repository.TimelineEvent
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class TimelineUiState(
    val events: List<TimelineEvent> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class PostActivityTimelineViewModel @Inject constructor(
    private val listingRepository: ListingRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val listingId: Int = checkNotNull(savedStateHandle.get<String>("listingId")?.toIntOrNull())

    private val _uiState = MutableStateFlow(TimelineUiState())
    val uiState: StateFlow<TimelineUiState> = _uiState.asStateFlow()

    init {
        loadTimelineEvents()
    }

    fun loadTimelineEvents() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            listingRepository.getListingTimeline(listingId)
                .onSuccess { events ->
                    _uiState.update { it.copy(events = events, isLoading = false) }
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
}
