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
 * ViewModel for MFA Enrollment Screen
 *
 * Handles TOTP MFA enrollment and verification
 */
@HiltViewModel
class MFAEnrollmentViewModel @Inject constructor(
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(MFAEnrollmentUiState())
    val uiState: StateFlow<MFAEnrollmentUiState> = _uiState.asStateFlow()

    fun enrollMFA() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            try {
                val factor = supabaseClient.auth.mfa.enroll(
                    factorType = io.github.jan.supabase.auth.mfa.FactorType.TOTP
                )

                _uiState.update {
                    it.copy(
                        isLoading = false,
                        factorId = factor.id,
                        qrCodeUri = factor.data.qrCode,
                        secret = factor.data.secret
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = "Failed to enroll MFA: ${e.message}"
                    )
                }
            }
        }
    }

    fun updateVerificationCode(code: String) {
        _uiState.update { it.copy(verificationCode = code, error = null) }
    }

    fun verifyMFA() {
        val state = _uiState.value
        if (state.factorId == null || state.verificationCode.length != 6) return

        viewModelScope.launch {
            _uiState.update { it.copy(isVerifying = true, error = null) }

            try {
                supabaseClient.auth.mfa.createChallengeAndVerify(
                    factorId = state.factorId,
                    code = state.verificationCode
                )

                _uiState.update {
                    it.copy(
                        isVerifying = false,
                        isEnrollmentComplete = true
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isVerifying = false,
                        error = "Invalid verification code. Please try again."
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
 * UI state for MFA Enrollment
 */
data class MFAEnrollmentUiState(
    val isLoading: Boolean = false,
    val isVerifying: Boolean = false,
    val factorId: String? = null,
    val qrCodeUri: String? = null,
    val secret: String? = null,
    val verificationCode: String = "",
    val error: String? = null,
    val isEnrollmentComplete: Boolean = false
)
