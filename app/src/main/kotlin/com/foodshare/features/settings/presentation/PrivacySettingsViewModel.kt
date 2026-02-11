package com.foodshare.features.settings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject

/**
 * ViewModel for Privacy Settings screen
 */
@HiltViewModel
class PrivacySettingsViewModel @Inject constructor(
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(PrivacyUiState())
    val uiState: StateFlow<PrivacyUiState> = _uiState.asStateFlow()

    init {
        loadPrivacySettings()
    }

    private fun loadPrivacySettings() {
        viewModelScope.launch {
            try {
                val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return@launch

                val profile = supabaseClient.from("profiles")
                    .select {
                        filter {
                            eq("id", userId)
                        }
                    }
                    .decodeSingle<ProfilePrivacyResponse>()

                val settings = profile.privacy_settings ?: PrivacySettings()

                _uiState.update {
                    it.copy(
                        profileVisible = settings.profileVisible,
                        showLocation = settings.showLocation,
                        allowMessages = settings.allowMessages,
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
            try {
                val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return@launch

                val privacySettings = buildJsonObject {
                    put("profileVisible", _uiState.value.profileVisible)
                    put("showLocation", _uiState.value.showLocation)
                    put("allowMessages", _uiState.value.allowMessages)
                }

                supabaseClient.from("profiles")
                    .update({
                        set("privacy_settings", privacySettings)
                    }) {
                        filter {
                            eq("id", userId)
                        }
                    }
            } catch (e: Exception) {
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

/**
 * Profile response with privacy settings
 */
@Serializable
data class ProfilePrivacyResponse(
    val id: String,
    val privacy_settings: PrivacySettings? = null
)
