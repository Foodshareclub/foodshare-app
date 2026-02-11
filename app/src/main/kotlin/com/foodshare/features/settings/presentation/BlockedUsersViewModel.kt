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
 * ViewModel for Blocked Users screen
 */
@HiltViewModel
class BlockedUsersViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(BlockedUsersUiState())
    val uiState: StateFlow<BlockedUsersUiState> = _uiState.asStateFlow()

    init {
        loadBlockedUsers()
    }

    private fun loadBlockedUsers() {
        viewModelScope.launch {
            settingsRepository.getBlockedUsers()
                .onSuccess { blockedUsers ->
                    _uiState.update {
                        it.copy(
                            blockedUsers = blockedUsers,
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

    fun unblockUser(userId: String) {
        viewModelScope.launch {
            settingsRepository.unblockUser(userId)
                .onSuccess {
                    // Remove from local state
                    _uiState.update {
                        it.copy(
                            blockedUsers = it.blockedUsers.filter { user -> user.id != userId }
                        )
                    }
                }
                .onFailure { e ->
                    _uiState.update {
                        it.copy(error = e.message)
                    }
                }
        }
    }
}

/**
 * UI state for Blocked Users screen
 */
data class BlockedUsersUiState(
    val blockedUsers: List<BlockedUser> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)

/**
 * Blocked user model
 */
data class BlockedUser(
    val id: String,
    val nickname: String,
    val avatarUrl: String?,
    val blockedAt: String
)
