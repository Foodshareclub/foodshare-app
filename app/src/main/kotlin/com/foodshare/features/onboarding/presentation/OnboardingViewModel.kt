package com.foodshare.features.onboarding.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.features.onboarding.data.OnboardingPreferences
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI State for Onboarding screen.
 */
data class OnboardingUiState(
    val hasConfirmedAge: Boolean = false,
    val hasAcceptedTerms: Boolean = false,
    val showFullDisclaimer: Boolean = false,
    val showTermsSheet: Boolean = false,
    val showPrivacySheet: Boolean = false,
    val isCompleting: Boolean = false
) {
    val canProceed: Boolean get() = hasConfirmedAge && hasAcceptedTerms
}

/**
 * ViewModel for Onboarding feature.
 *
 * SYNC: Mirrors Swift OnboardingView state management
 */
@HiltViewModel
class OnboardingViewModel @Inject constructor(
    private val onboardingPreferences: OnboardingPreferences
) : ViewModel() {

    private val _uiState = MutableStateFlow(OnboardingUiState())
    val uiState: StateFlow<OnboardingUiState> = _uiState.asStateFlow()

    fun toggleAgeConfirmation() {
        _uiState.update { it.copy(hasConfirmedAge = !it.hasConfirmedAge) }
    }

    fun toggleTermsAcceptance() {
        _uiState.update { it.copy(hasAcceptedTerms = !it.hasAcceptedTerms) }
    }

    fun showFullDisclaimer() {
        _uiState.update { it.copy(showFullDisclaimer = true) }
    }

    fun hideFullDisclaimer() {
        _uiState.update { it.copy(showFullDisclaimer = false) }
    }

    fun showTermsSheet() {
        _uiState.update { it.copy(showTermsSheet = true) }
    }

    fun hideTermsSheet() {
        _uiState.update { it.copy(showTermsSheet = false) }
    }

    fun showPrivacySheet() {
        _uiState.update { it.copy(showPrivacySheet = true) }
    }

    fun hidePrivacySheet() {
        _uiState.update { it.copy(showPrivacySheet = false) }
    }

    fun completeOnboarding(onComplete: () -> Unit) {
        if (!_uiState.value.canProceed) return

        viewModelScope.launch {
            _uiState.update { it.copy(isCompleting = true) }
            onboardingPreferences.completeOnboarding()
            onComplete()
        }
    }
}
