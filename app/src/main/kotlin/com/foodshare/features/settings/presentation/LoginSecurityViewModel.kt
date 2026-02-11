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
 * Active session data model
 */
data class ActiveSession(
    val id: String,
    val deviceName: String,
    val lastActiveAt: String,
    val isCurrent: Boolean
)

/**
 * ViewModel for Login & Security screen
 *
 * Manages password changes, MFA status, biometric preferences,
 * and active session listing/revocation.
 */
@HiltViewModel
class LoginSecurityViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    data class UiState(
        val isMfaEnabled: Boolean = false,
        val isBiometricEnabled: Boolean = false,
        val sessions: List<ActiveSession> = emptyList(),
        val isLoading: Boolean = true,
        val isChangingPassword: Boolean = false,
        val currentPassword: String = "",
        val newPassword: String = "",
        val confirmPassword: String = "",
        val passwordError: String? = null,
        val error: String? = null,
        val successMessage: String? = null
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        loadSecurityData()
    }

    private fun loadSecurityData() {
        viewModelScope.launch {
            // Load MFA status
            settingsRepository.getTwoFactorStatus()
                .onSuccess { status ->
                    _uiState.update { it.copy(isMfaEnabled = status.isEnabled) }
                }

            // Load active sessions
            settingsRepository.getActiveSessions()
                .onSuccess { sessions ->
                    _uiState.update {
                        it.copy(
                            sessions = sessions,
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

    fun updateCurrentPassword(password: String) {
        _uiState.update { it.copy(currentPassword = password, passwordError = null) }
    }

    fun updateNewPassword(password: String) {
        _uiState.update { it.copy(newPassword = password, passwordError = null) }
    }

    fun updateConfirmPassword(password: String) {
        _uiState.update { it.copy(confirmPassword = password, passwordError = null) }
    }

    fun changePassword() {
        val state = _uiState.value

        // Validate inputs
        if (state.currentPassword.isBlank()) {
            _uiState.update { it.copy(passwordError = "Current password is required") }
            return
        }
        if (state.newPassword.length < 8) {
            _uiState.update { it.copy(passwordError = "New password must be at least 8 characters") }
            return
        }
        if (state.newPassword != state.confirmPassword) {
            _uiState.update { it.copy(passwordError = "Passwords do not match") }
            return
        }
        if (state.currentPassword == state.newPassword) {
            _uiState.update { it.copy(passwordError = "New password must be different from current password") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isChangingPassword = true, passwordError = null) }

            settingsRepository.changePassword(state.currentPassword, state.newPassword)
                .onSuccess {
                    _uiState.update {
                        it.copy(
                            isChangingPassword = false,
                            currentPassword = "",
                            newPassword = "",
                            confirmPassword = "",
                            successMessage = "Password changed successfully"
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update {
                        it.copy(
                            isChangingPassword = false,
                            passwordError = "Failed to change password: ${e.message}"
                        )
                    }
                }
        }
    }

    fun toggleBiometric(enabled: Boolean) {
        _uiState.update { it.copy(isBiometricEnabled = enabled) }
    }

    fun revokeSession(sessionId: String) {
        viewModelScope.launch {
            settingsRepository.revokeSession(sessionId)
                .onSuccess {
                    // Remove the session from the local list
                    _uiState.update { state ->
                        state.copy(
                            sessions = state.sessions.filter { it.id != sessionId }
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update { it.copy(error = e.message) }
                }
        }
    }

    fun dismissSuccess() {
        _uiState.update { it.copy(successMessage = null) }
    }

    fun dismissError() {
        _uiState.update { it.copy(error = null) }
    }
}
