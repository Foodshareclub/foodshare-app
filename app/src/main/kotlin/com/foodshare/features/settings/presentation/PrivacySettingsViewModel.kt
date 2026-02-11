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
import kotlinx.serialization.Serializable
import javax.inject.Inject

/**
 * ViewModel for Privacy Settings screen
 */
@HiltViewModel
class PrivacySettingsViewModel @Inject constructor(
    private val settingsRepository: SettingsRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(PrivacyUiState())
    val uiState: StateFlow<PrivacyUiState> = _uiState.asStateFlow()

    init {
        loadPrivacySettings()
    }

    private fun loadPrivacySettings() {
        viewModelScope.launch {
            settingsRepository.getPrivacySettings()
                .onSuccess { settings ->
                    _uiState.update {
                        it.copy(
                            profileVisible = settings.profileVisible,
                            showLocation = settings.showLocation,
                            allowMessages = settings.allowMessages,
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

    fun toggleProfileVisible(visible: Boolean) {
        _uiState.update { it.copy(profileVisible = visible) }
        savePrivacySettings()
    }

    fun toggleShowLocation(show: Boolean) {
        _uiState.update { it.copy(showLocation = show) }
        savePrivacySettings()
    }

    fun toggleAllowMessages(allow: Boolean) {
        _uiState.update { it.copy(allowMessages = allow) }
        savePrivacySettings()
    }

    private fun savePrivacySettings() {
        viewModelScope.launch {
            val state = _uiState.value
            val settings = PrivacySettings(
                profileVisible = state.profileVisible,
                showLocation = state.showLocation,
                allowMessages = state.allowMessages
            )

            settingsRepository.updatePrivacySettings(settings)
                .onFailure { e ->
                    _uiState.update {
                        it.copy(error = e.message)
                    }
                }
        }
    }
}

/**
 * UI state for Privacy Settings
 */
data class PrivacyUiState(
    val profileVisible: Boolean = true,
    val showLocation: Boolean = true,
    val allowMessages: Boolean = true,
    val isLoading: Boolean = true,
    val error: String? = null
)

/**
 * Privacy settings data model
 */
@Serializable
data class PrivacySettings(
    val profileVisible: Boolean = true,
    val showLocation: Boolean = true,
    val allowMessages: Boolean = true
)
