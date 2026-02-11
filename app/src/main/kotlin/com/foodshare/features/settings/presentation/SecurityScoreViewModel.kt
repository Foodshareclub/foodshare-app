package com.foodshare.features.settings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.security.SecurityCheckItem
import com.foodshare.core.security.SecurityLevel
import com.foodshare.core.security.SecurityScoreService
import com.foodshare.features.settings.domain.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for Security Score screen
 */
@HiltViewModel
class SecurityScoreViewModel @Inject constructor(
    private val securityScoreService: SecurityScoreService,
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(SecurityScoreUiState())
    val uiState: StateFlow<SecurityScoreUiState> = _uiState.asStateFlow()

    init {
        loadSecurityScore()
    }

    private fun loadSecurityScore() {
        viewModelScope.launch {
            settingsRepository.getSecurityScore()
                .onSuccess { scoreData ->
                    // Calculate score
                    val (score, items) = securityScoreService.calculateScore(
                        emailVerified = scoreData.emailVerified,
                        hasMFA = scoreData.hasMFA,
                        hasStrongPassword = scoreData.hasStrongPassword,
                        profileComplete = scoreData.profileComplete
                    )

                    val level = securityScoreService.getSecurityLevel(score)

                    _uiState.update {
                        it.copy(
                            score = score,
                            level = level,
                            items = items,
                            isLoading = false
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = e.message
                        )
                    }
                }
        }
    }
}

/**
 * UI state for Security Score screen
 */
data class SecurityScoreUiState(
    val score: Int = 0,
    val level: SecurityLevel = SecurityLevel.POOR,
    val items: List<SecurityCheckItem> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)
