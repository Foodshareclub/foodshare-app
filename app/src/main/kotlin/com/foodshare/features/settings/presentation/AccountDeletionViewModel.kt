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
 * ViewModel for Account Deletion screen
 *
 * Manages the account deletion flow including password verification,
 * confirmation, and the RPC call to request account deletion.
 */
@HiltViewModel
class AccountDeletionViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    data class UiState(
        val password: String = "",
        val isConfirmed: Boolean = false,
        val isDeleting: Boolean = false,
        val error: String? = null,
        val isDeleted: Boolean = false
    )

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    fun updatePassword(password: String) {
        _uiState.update { it.copy(password = password, error = null) }
    }

    fun toggleConfirmation(confirmed: Boolean) {
        _uiState.update { it.copy(isConfirmed = confirmed) }
    }

    fun deleteAccount(onDeleted: () -> Unit) {
        val state = _uiState.value

        if (state.password.isBlank()) {
            _uiState.update { it.copy(error = "Password is required to confirm deletion") }
            return
        }

        if (!state.isConfirmed) {
            _uiState.update { it.copy(error = "Please confirm that you understand this action is permanent") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isDeleting = true, error = null) }

            settingsRepository.requestAccountDeletion(
                reason = "user_requested",
                password = state.password
            )
                .onSuccess {
                    _uiState.update {
                        it.copy(
                            isDeleting = false,
                            isDeleted = true
                        )
                    }
                    onDeleted()
                }
                .onFailure { e ->
                    _uiState.update {
                        it.copy(
                            isDeleting = false,
                            error = when {
                                e.message?.contains("Invalid login", ignoreCase = true) == true ->
                                    "Incorrect password. Please try again."
                                e.message?.contains("invalid_grant", ignoreCase = true) == true ->
                                    "Incorrect password. Please try again."
                                else -> "Failed to delete account: ${e.message}"
                            }
                        )
                    }
                }
        }
    }

    fun dismissError() {
        _uiState.update { it.copy(error = null) }
    }
}
