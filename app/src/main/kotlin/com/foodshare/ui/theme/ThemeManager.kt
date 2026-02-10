package com.foodshare.ui.theme

import android.content.Context
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch

// DataStore extension for theme preferences
private val Context.themeDataStore: DataStore<Preferences> by preferencesDataStore(name = "theme_preferences")

/**
 * Theme Manager - Observable theme state with persistence
 *
 * Matches iOS ThemeManager pattern with StateFlow instead of @Observable
 */
object ThemeManager {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    // Preference keys
    private val THEME_ID_KEY = stringPreferencesKey("theme_id")
    private val COLOR_SCHEME_KEY = stringPreferencesKey("color_scheme")

    // State flows
    private val _currentTheme = MutableStateFlow<FoodShareTheme>(FoodShareTheme.Brand)
    val currentTheme: StateFlow<FoodShareTheme> = _currentTheme.asStateFlow()

    private val _colorSchemePreference = MutableStateFlow(ColorSchemePreference.SYSTEM)
    val colorSchemePreference: StateFlow<ColorSchemePreference> = _colorSchemePreference.asStateFlow()

    private var dataStore: DataStore<Preferences>? = null

    /** All available themes */
    val availableThemes: List<FoodShareTheme> = FoodShareTheme.allThemes

    /**
     * Initialize with context (call from Application class)
     */
    fun initialize(context: Context) {
        dataStore = context.themeDataStore
        loadSavedPreferences()
    }

    private fun loadSavedPreferences() {
        scope.launch {
            dataStore?.data?.first()?.let { preferences ->
                // Load theme
                preferences[THEME_ID_KEY]?.let { themeIdString ->
                    _currentTheme.value = FoodShareTheme.fromIdString(themeIdString)
                }

                // Load color scheme preference
                preferences[COLOR_SCHEME_KEY]?.let { schemeString ->
                    _colorSchemePreference.value = when (schemeString) {
                        "LIGHT" -> ColorSchemePreference.LIGHT
                        "DARK" -> ColorSchemePreference.DARK
                        else -> ColorSchemePreference.SYSTEM
                    }
                }
            }
        }
    }

    /**
     * Set current theme
     */
    fun setTheme(theme: FoodShareTheme) {
        _currentTheme.value = theme
        persistTheme(theme)
    }

    /**
     * Set color scheme preference
     */
    fun setColorSchemePreference(preference: ColorSchemePreference) {
        _colorSchemePreference.value = preference
        persistColorScheme(preference)
    }

    private fun persistTheme(theme: FoodShareTheme) {
        scope.launch {
            dataStore?.edit { preferences ->
                preferences[THEME_ID_KEY] = theme.id.name
            }
        }
    }

    private fun persistColorScheme(preference: ColorSchemePreference) {
        scope.launch {
            dataStore?.edit { preferences ->
                preferences[COLOR_SCHEME_KEY] = preference.name
            }
        }
    }

    /**
     * Get current palette based on theme and dark mode
     */
    @Composable
    fun currentPalette(): ThemePalette {
        val theme by currentTheme.collectAsState()
        val schemePreference by colorSchemePreference.collectAsState()

        val isDark = when (schemePreference) {
            ColorSchemePreference.LIGHT -> false
            ColorSchemePreference.DARK -> true
            ColorSchemePreference.SYSTEM -> isSystemInDarkTheme()
        }

        return theme.palette(isDark)
    }

    /**
     * Check if dark mode is active
     */
    @Composable
    fun isDarkMode(): Boolean {
        val schemePreference by colorSchemePreference.collectAsState()
        return when (schemePreference) {
            ColorSchemePreference.LIGHT -> false
            ColorSchemePreference.DARK -> true
            ColorSchemePreference.SYSTEM -> isSystemInDarkTheme()
        }
    }
}

/**
 * Composable helper to get current theme palette
 */
@Composable
fun currentThemePalette(): ThemePalette = ThemeManager.currentPalette()

/**
 * Composable helper to check dark mode
 */
@Composable
fun isAppDarkTheme(): Boolean = ThemeManager.isDarkMode()
