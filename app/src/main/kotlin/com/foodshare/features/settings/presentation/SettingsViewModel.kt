package com.foodshare.features.settings.presentation

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

// DataStore extension
private val Context.dataStore by preferencesDataStore(name = "settings")

/**
 * Preference keys
 */
private object PreferenceKeys {
    val NOTIFICATIONS_ENABLED = booleanPreferencesKey("notifications_enabled")
    val LOCATION_ENABLED = booleanPreferencesKey("location_enabled")
    val DARK_MODE = stringPreferencesKey("dark_mode")
    val SEARCH_RADIUS_KM = stringPreferencesKey("search_radius_km")
}

/**
 * ViewModel for Settings screen
 */
@HiltViewModel
class SettingsViewModel @Inject constructor(
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        loadSettings()
    }

    private fun loadSettings() {
        viewModelScope.launch {
            val prefs = context.dataStore.data.first()

            _uiState.update {
                it.copy(
                    notificationsEnabled = prefs[PreferenceKeys.NOTIFICATIONS_ENABLED] ?: true,
                    locationEnabled = prefs[PreferenceKeys.LOCATION_ENABLED] ?: true,
                    darkMode = DarkModeOption.fromString(prefs[PreferenceKeys.DARK_MODE]),
                    searchRadius = SearchRadius.fromString(prefs[PreferenceKeys.SEARCH_RADIUS_KM]),
                    isLoading = false
                )
            }
        }
    }

    fun setNotificationsEnabled(enabled: Boolean) {
        _uiState.update { it.copy(notificationsEnabled = enabled) }
        savePreference(PreferenceKeys.NOTIFICATIONS_ENABLED, enabled)
    }

    fun setLocationEnabled(enabled: Boolean) {
        _uiState.update { it.copy(locationEnabled = enabled) }
        savePreference(PreferenceKeys.LOCATION_ENABLED, enabled)
    }

    fun setDarkMode(mode: DarkModeOption) {
        _uiState.update { it.copy(darkMode = mode) }
        savePreference(PreferenceKeys.DARK_MODE, mode.value)
    }

    fun setSearchRadius(radius: SearchRadius) {
        _uiState.update { it.copy(searchRadius = radius) }
        savePreference(PreferenceKeys.SEARCH_RADIUS_KM, radius.km.toString())
    }

    private fun <T> savePreference(key: androidx.datastore.preferences.core.Preferences.Key<T>, value: T) {
        viewModelScope.launch {
            context.dataStore.edit { prefs ->
                prefs[key] = value
            }
        }
    }
}

/**
 * UI state for Settings screen
 */
data class SettingsUiState(
    val notificationsEnabled: Boolean = true,
    val locationEnabled: Boolean = true,
    val darkMode: DarkModeOption = DarkModeOption.SYSTEM,
    val searchRadius: SearchRadius = SearchRadius.KM_5,
    val isLoading: Boolean = true,
    val appVersion: String = "1.0.0"
)

/**
 * Dark mode options
 */
enum class DarkModeOption(val value: String, val displayName: String) {
    LIGHT("light", "Light"),
    DARK("dark", "Dark"),
    SYSTEM("system", "System Default");

    companion object {
        fun fromString(value: String?): DarkModeOption {
            return entries.find { it.value == value } ?: SYSTEM
        }
    }
}

/**
 * Search radius options
 */
enum class SearchRadius(val km: Int, val displayName: String) {
    KM_1(1, "1 km"),
    KM_2(2, "2 km"),
    KM_5(5, "5 km"),
    KM_10(10, "10 km"),
    KM_20(20, "20 km"),
    KM_50(50, "50 km");

    companion object {
        fun fromString(value: String?): SearchRadius {
            val km = value?.toIntOrNull() ?: 5
            return entries.find { it.km == km } ?: KM_5
        }
    }
}
