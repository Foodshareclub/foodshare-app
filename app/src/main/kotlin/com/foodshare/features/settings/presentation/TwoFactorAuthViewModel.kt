package com.foodshare.features.settings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.mfa.MfaLevel
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
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(TwoFactorAuthUiState())
    val uiState: StateFlow<TwoFactorAuthUiState> = _uiState.asStateFlow()

    init {
        loadMFAStatus()
    }

    private fun loadMFAStatus() {
        viewModelScope.launch {
            try {
                val user = supabaseClient.auth.currentUserOrNull()
                if (user == null) {
                    _uiState.update { it.copy(isLoading = false) }
                    return@launch
                }

                val hasMFA = user.factors?.isNotEmpty() == true
                val enrolledFactors = user.factors?.size ?: 0

                _uiState.update {
                    it.copy(
                        isEnabled = hasMFA,
                        enrolledFactors = enrolledFactors,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
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

            try {
                // Enroll TOTP MFA
                val enrollResult = supabaseClient.auth.mfa.enroll(
                    factorType = io.github.jan.supabase.auth.mfa.FactorType.TOTP,
                    friendlyName = "Authenticator App"
                )

                _uiState.update {
                    it.copy(
                        isEnrolling = false,
                        qrCode = enrollResult.data.qrCode,
                        secret = enrollResult.data.secret,
                        factorId = enrollResult.id,
                        showVerificationDialog = true
                    )
                }
            } catch (e: Exception) {
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

            try {
                val factorId = _uiState.value.factorId ?: return@launch

                // Verify the TOTP code
                supabaseClient.auth.mfa.createChallengeAndVerify(
                    factorId = factorId,
                    code = code
                )

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
            } catch (e: Exception) {
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

            try {
                // Get all factors and unenroll them
                val user = supabaseClient.auth.currentUserOrNull()
                user?.factors?.forEach { factor ->
                    supabaseClient.auth.mfa.unenroll(factor.id)
                }

                _uiState.update {
                    it.copy(
                        isUnenrolling = false,
                        isEnabled = false,
                        enrolledFactors = 0
                    )
                }
            } catch (e: Exception) {
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
