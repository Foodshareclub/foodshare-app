package com.foodshare.features.activity.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.features.activity.domain.model.ActivityItem
import com.foodshare.features.activity.domain.repository.ActivityRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI State for Activity screen.
 */
data class ActivityUiState(
    val activities: List<ActivityItem> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val error: String? = null,
    val hasMorePages: Boolean = true,
    val currentPage: Int = 0
) {
    val isEmpty: Boolean get() = activities.isEmpty() && !isLoading
}

/**
 * ViewModel for Activity feature.
 *
 * SYNC: Mirrors Swift ActivityViewModel
 */
@HiltViewModel
class ActivityViewModel @Inject constructor(
    private val repository: ActivityRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ActivityUiState())
    val uiState: StateFlow<ActivityUiState> = _uiState.asStateFlow()

    private val pageSize = 20
    private val maxPages = 10

    init {
        loadActivities()
        subscribeToRealTimeUpdates()
    }

    fun loadActivities() {
        if (_uiState.value.isLoading) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null, currentPage = 0) }

            repository.getActivities(offset = 0, limit = pageSize)
                .onSuccess { activities ->
                    _uiState.update { state ->
                        state.copy(
                            activities = activities,
                            isLoading = false,
                            hasMorePages = activities.size >= pageSize,
                            currentPage = 1
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(isLoading = false, error = ErrorBridge.mapActivityError(error))
                    }
                }
        }
    }

    fun loadMore() {
        val currentState = _uiState.value
        if (currentState.isLoadingMore || !currentState.hasMorePages) return
        if (currentState.currentPage >= maxPages) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingMore = true) }

            val offset = currentState.activities.size

            repository.getActivities(offset = offset, limit = pageSize)
                .onSuccess { newActivities ->
                    _uiState.update { state ->
                        state.copy(
                            activities = state.activities + newActivities,
                            isLoadingMore = false,
                            hasMorePages = newActivities.size >= pageSize,
                            currentPage = state.currentPage + 1
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(isLoadingMore = false, error = ErrorBridge.mapActivityError(error))
                    }
                }
        }
    }

    fun refresh() {
        _uiState.update { it.copy(currentPage = 0, hasMorePages = true) }
        loadActivities()
    }

    private fun subscribeToRealTimeUpdates() {
        viewModelScope.launch {
            repository.observeActivities().collect { newActivity ->
                _uiState.update { state ->
                    // Insert at the top of the feed
                    state.copy(
                        activities = listOf(newActivity) + state.activities
                    )
                }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
