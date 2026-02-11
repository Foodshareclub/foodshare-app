package com.foodshare.features.insights.presentation

import androidx.compose.runtime.Immutable
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.features.insights.domain.model.UserInsights
import com.foodshare.features.insights.domain.repository.InsightsRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@Immutable
data class InsightsUiState(
    val insights: UserInsights? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)

@HiltViewModel
class InsightsViewModel @Inject constructor(
    private val insightsRepository: InsightsRepository,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(InsightsUiState())
    val uiState: StateFlow<InsightsUiState> = _uiState.asStateFlow()

    init {
        loadInsights()
    }

    fun loadInsights() {
        viewModelScope.launch {
            val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return@launch

            _uiState.update { it.copy(isLoading = true, error = null) }

            insightsRepository.getUserInsights(userId)
                .onSuccess { insights ->
                    _uiState.update { it.copy(insights = insights, isLoading = false) }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(isLoading = false, error = e.message) }
                }
        }
    }
}
