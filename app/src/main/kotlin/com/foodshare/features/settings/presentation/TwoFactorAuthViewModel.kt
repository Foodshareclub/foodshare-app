package com.foodshare.features.settings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.features.settings.domain.repository.SettingsRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for Two-Factor Authentication screen
 */
@HiltViewModel
class TwoFactorAuthViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(TwoFactorAuthUiState())
    val uiState: StateFlow<TwoFactorAuthUiState> = _uiState.asStateFlow()

    init {
        loadMFAStatus()
    }

    private fun loadMFAStatus() {
        viewModelScope.launch {
            settingsRepository.getTwoFactorStatus()
                .onSuccess { status ->
                    _uiState.update {
                        it.copy(
                            isEnabled = status.isEnabled,
                            enrolledFactors = status.enrolledFactors,
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

    fun enrollMFA() {
        viewModelScope.launch {
            _uiState.update { it.copy(isEnrolling = true) }

            settingsRepository.enableTwoFactor("Authenticator App")
                .onSuccess { setupData ->
                    _uiState.update {
                        it.copy(
                            isEnrolling = false,
                            qrCode = setupData.qrCode,
                            secret = setupData.secret,
                            factorId = setupData.factorId,
                            showVerificationDialog = true
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update {
                        it.copy(
                            isEnrolling = false,
                            error = e.message
                        )
                    }
                }
        }
    }

    fun verifyMFA(code: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isVerifying = true) }

            val factorId = _uiState.value.factorId ?: return@launch

            settingsRepository.verifyTwoFactor(factorId, code)
                .onSuccess {
                    _uiState.update {
                        it.copy(
                            isVerifying = false,
                            isEnabled = true,
                            enrolledFactors = it.enrolledFactors + 1,
                            showVerificationDialog = false,
                            qrCode = null,
                            secret = null,
                            factorId = null
                        )
                    }
                }
                .onFailure {
                    _uiState.update {
                        it.copy(
                            isVerifying = false,
                            error = "Invalid verification code"
                        )
                    }
                }
        }
    }

    fun unenrollMFA() {
        viewModelScope.launch {
            _uiState.update { it.copy(isUnenrolling = true) }

            settingsRepository.disableTwoFactor()
                .onSuccess {
                    _uiState.update {
                        it.copy(
                            isUnenrolling = false,
                            isEnabled = false,
                            enrolledFactors = 0
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update {
                        it.copy(
                            isUnenrolling = false,
                            error = e.message
                        )
                    }
                }
        }
    }

    fun dismissError() {
        _uiState.update { it.copy(error = null) }
    }
}

/**
 * UI state for Two-Factor Authentication screen
 */
data class TwoFactorAuthUiState(
    val isEnabled: Boolean = false,
    val enrolledFactors: Int = 0,
    val qrCode: String? = null,
    val secret: String? = null,
    val factorId: String? = null,
    val showVerificationDialog: Boolean = false,
    val isLoading: Boolean = true,
    val isEnrolling: Boolean = false,
    val isVerifying: Boolean = false,
    val isUnenrolling: Boolean = false,
    val error: String? = null
)
