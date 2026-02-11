package com.foodshare.features.auth.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for MFA Verification Screen
 *
 * Handles MFA code verification during sign-in
 */
@HiltViewModel
class MFAVerificationViewModel @Inject constructor(
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(MFAVerificationUiState())
    val uiState: StateFlow<MFAVerificationUiState> = _uiState.asStateFlow()

    fun updateCode(code: String) {
        if (code.length <= 6 && code.all { it.isDigit() }) {
            _uiState.update { it.copy(code = code, error = null) }
        }
    }

    fun verifyCode() {
        val state = _uiState.value
        if (state.code.length != 6) return

        viewModelScope.launch {
            _uiState.update { it.copy(isVerifying = true, error = null) }

            try {
                // Get the first TOTP factor (assuming single MFA factor setup)
                val factors = supabaseClient.auth.mfa.retrieveFactorsForCurrentUser()
                val totpFactor = factors.firstOrNull { it.factorType == "totp" }

                if (totpFactor != null) {
                    supabaseClient.auth.mfa.createChallengeAndVerify(
                        factorId = totpFactor.id,
                        code = state.code
                    )

                    _uiState.update {
                        it.copy(
                            isVerifying = false,
                            isVerified = true
                        )
                    }
                } else {
                    _uiState.update {
                        it.copy(
                            isVerifying = false,
                            error = "No MFA factor found"
                        )
                    }
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isVerifying = false,
                        error = "Invalid code. Please try again."
                    )
                }
            }
        }
    }

    fun verifyRecoveryCode(recoveryCode: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isVerifying = true, error = null) }

            try {
                // Recovery code verification (implementation depends on Supabase API)
                // This is a placeholder - actual implementation may vary
                _uiState.update {
                    it.copy(
                        isVerifying = false,
                        error = "Recovery code verification not yet implemented"
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isVerifying = false,
                        error = "Invalid recovery code"
                    )
                }
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}

/**
 * UI state for MFA Verification
 */
data class MFAVerificationUiState(
    val code: String = "",
    val isVerifying: Boolean = false,
    val error: String? = null,
    val isVerified: Boolean = false
)
