package com.foodshare.features.profile.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.features.profile.domain.repository.ProfileActionRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject

/**
 * Data class representing a single arrangement history entry.
 */
@Serializable
data class ArrangementHistoryItem(
    val id: String,
    @SerialName("listing_title") val listingTitle: String,
    @SerialName("counterparty_name") val counterpartyName: String,
    val status: String, // "pending", "accepted", "completed", "cancelled"
    @SerialName("created_at") val createdAt: String,
    @SerialName("completed_at") val completedAt: String? = null
)

/**
 * ViewModel for the Arrangement History screen.
 *
 * Loads and manages the list of past arrangements for the current user.
 * Uses ProfileActionRepository to fetch arrangement history data.
 *
 * SYNC: Mirrors Swift ArrangementHistoryViewModel
 */
@HiltViewModel
class ArrangementHistoryViewModel @Inject constructor(
    private val profileActionRepository: ProfileActionRepository
) : ViewModel() {

    /**
     * UI state for the Arrangement History screen.
     */
    data class UiState(
        val arrangements: List<ArrangementHistoryItem> = emptyList(),
        val isLoading: Boolean = true,
        val error: String? = null
    ) {
        val isEmpty: Boolean
            get() = arrangements.isEmpty() && !isLoading && error == null
    }

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        loadArrangements()
    }

    /**
     * Load arrangement history from the repository.
     *
     * Queries arrangements where the current user is either the requester or the owner,
     * ordered by creation date descending (most recent first).
     */
    fun loadArrangements() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            profileActionRepository.getArrangementHistory()
                .onSuccess { arrangements ->
                    _uiState.update {
                        it.copy(
                            arrangements = arrangements,
                            isLoading = false,
                            error = null
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = error.message ?: "Failed to load arrangements"
                        )
                    }
                }
        }
    }

    /**
     * Refresh the arrangement list by reloading from the server.
     */
    fun refresh() {
        loadArrangements()
    }

    /**
     * Clear the current error state.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
