package com.foodshare.features.profile.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.invitation.InvitationService
import com.foodshare.core.invitation.SentInvite
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/**
 * ViewModel for the Invite/Referral screen.
 *
 * Manages referral code generation, invitation sending, and invitation history.
 * Uses [InvitationService] for backend operations and [ValidationBridge] for
 * input validation.
 *
 * SYNC: Mirrors Swift InviteViewModel
 */
@HiltViewModel
class InviteViewModel @Inject constructor(
    private val authRepository: AuthRepository,
    private val invitationService: InvitationService
) : ViewModel() {

    /**
     * UI state for the Invite screen.
     */
    data class UiState(
        val referralCode: String = "",
        val referralLink: String = "",
        val email: String = "",
        val message: String = "",
        val emailError: String? = null,
        val messageError: String? = null,
        val invitesSent: List<SentInvite> = emptyList(),
        val isLoading: Boolean = false,
        val isSending: Boolean = false,
        val error: String? = null,
        val successMessage: String? = null
    ) {
        val canSend: Boolean
            get() = email.isNotBlank() && emailError == null && messageError == null && !isSending

        val shareText: String
            get() = buildString {
                appendLine("Join me on FoodShare - a community for sharing surplus food!")
                if (message.isNotBlank()) {
                    appendLine()
                    appendLine(message)
                }
                appendLine()
                appendLine(referralLink)
            }
    }

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        generateReferralCode()
        loadInvitationHistory()
    }

    /**
     * Generate or retrieve the user's referral code.
     *
     * Uses the first 8 characters of the user's ID as a deterministic referral code,
     * ensuring consistency across sessions.
     */
    private fun generateReferralCode() {
        viewModelScope.launch {
            val currentUser = authRepository.currentUser.first()
            val userId = currentUser?.id
            val code = if (userId != null) {
                userId.take(8).uppercase()
            } else {
                UUID.randomUUID().toString().take(8).uppercase()
            }
            val link = invitationService.generateReferralLink(code)

            _uiState.update {
                it.copy(
                    referralCode = code,
                    referralLink = link
                )
            }
        }
    }

    /**
     * Load the history of previously sent invitations.
     */
    private fun loadInvitationHistory() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            invitationService.getInvitationHistory()
                .onSuccess { history ->
                    _uiState.update {
                        it.copy(
                            invitesSent = history,
                            isLoading = false,
                            error = null
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = error.message ?: "Failed to load invitation history"
                        )
                    }
                }
        }
    }

    /**
     * Update the email field with validation.
     *
     * @param email The email address input
     */
    fun updateEmail(email: String) {
        val emailError = if (email.isBlank()) {
            null
        } else {
            ValidationBridge.validateEmail(email)
        }

        _uiState.update {
            it.copy(
                email = email,
                emailError = emailError,
                successMessage = null
            )
        }
    }

    /**
     * Update the personal message field with validation.
     *
     * @param message The personal message input
     */
    fun updateMessage(message: String) {
        val validationResult = ValidationBridge.validateInvitation(
            email = _uiState.value.email.ifBlank { "placeholder@test.com" },
            message = message
        )

        val messageError = if (message.isBlank()) {
            null
        } else {
            validationResult.errors
                .filter { it.message.contains("message", ignoreCase = true) }
                .firstOrNull()?.message
        }

        _uiState.update {
            it.copy(
                message = message,
                messageError = messageError,
                successMessage = null
            )
        }
    }

    /**
     * Send an invitation to the entered email address.
     *
     * Validates the email and message before sending, then updates
     * the invitation history on success.
     */
    fun sendInvitation() {
        val state = _uiState.value

        // Run full validation
        val validationResult = ValidationBridge.validateInvitation(
            email = state.email,
            message = state.message.takeIf { it.isNotBlank() }
        )

        if (!validationResult.isValid) {
            _uiState.update {
                it.copy(
                    error = validationResult.firstError ?: "Invalid invitation details"
                )
            }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isSending = true, error = null, successMessage = null) }

            invitationService.sendInvitation(
                email = state.email.trim(),
                message = state.message.trim().takeIf { it.isNotBlank() },
                referralCode = state.referralCode
            )
                .onSuccess {
                    _uiState.update {
                        it.copy(
                            email = "",
                            message = "",
                            emailError = null,
                            messageError = null,
                            isSending = false,
                            successMessage = "Invitation sent successfully!"
                        )
                    }
                    // Reload history to include the new invitation
                    loadInvitationHistory()
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isSending = false,
                            error = error.message ?: "Failed to send invitation"
                        )
                    }
                }
        }
    }

    /**
     * Refresh the invitation history.
     */
    fun refresh() {
        loadInvitationHistory()
    }

    /**
     * Clear the current error message.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    /**
     * Clear the success message.
     */
    fun clearSuccessMessage() {
        _uiState.update { it.copy(successMessage = null) }
    }
}
