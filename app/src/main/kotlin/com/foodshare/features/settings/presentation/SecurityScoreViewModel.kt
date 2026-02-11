package com.foodshare.features.settings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.security.SecurityCheckItem
import com.foodshare.core.security.SecurityLevel
import com.foodshare.core.security.SecurityScoreService
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.user.UserInfo
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import javax.inject.Inject

/**
 * ViewModel for Security Score screen
 */
@HiltViewModel
class SecurityScoreViewModel @Inject constructor(
    private val securityScoreService: SecurityScoreService,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(SecurityScoreUiState())
    val uiState: StateFlow<SecurityScoreUiState> = _uiState.asStateFlow()

    init {
        loadSecurityScore()
    }

    private fun loadSecurityScore() {
        viewModelScope.launch {
            try {
                val user = supabaseClient.auth.currentUserOrNull()
                if (user == null) {
                    _uiState.update { it.copy(isLoading = false) }
                    return@launch
                }

                // Check email verification
                val emailVerified = user.emailConfirmedAt != null

                // Check MFA status
                val hasMFA = checkMFAStatus(user)

                // Check password strength (placeholder - would need custom implementation)
                val hasStrongPassword = true // Assume true for now

                // Check profile completeness
                val profileComplete = checkProfileComplete(user.id)

                // Calculate score
                val (score, items) = securityScoreService.calculateScore(
                    emailVerified = emailVerified,
                    hasMFA = hasMFA,
                    hasStrongPassword = hasStrongPassword,
                    profileComplete = profileComplete
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

    private fun checkMFAStatus(user: UserInfo): Boolean {
        // Check if user has MFA factors enrolled
        return user.factors?.isNotEmpty() == true
    }

    private suspend fun checkProfileComplete(userId: String): Boolean {
        return try {
            val profile = supabaseClient.from("profiles")
                .select {
                    filter {
                        eq("id", userId)
                    }
                }
                .decodeSingle<ProfileCompletenessCheck>()

            !profile.nickname.isNullOrBlank() && !profile.bio.isNullOrBlank()
        } catch (e: Exception) {
            false
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

/**
 * Profile completeness check model
 */
@Serializable
data class ProfileCompletenessCheck(
    val id: String,
    val nickname: String? = null,
    val bio: String? = null
)
