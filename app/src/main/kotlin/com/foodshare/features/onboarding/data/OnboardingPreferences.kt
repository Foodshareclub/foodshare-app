package com.foodshare.features.onboarding.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.onboardingDataStore: DataStore<Preferences> by preferencesDataStore(name = "onboarding_prefs")

/**
 * Manages onboarding state persistence.
 *
 * SYNC: Mirrors Swift OnboardingManager / @AppStorage pattern
 */
@Singleton
class OnboardingPreferences @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val dataStore = context.onboardingDataStore

    private companion object {
        val KEY_HAS_COMPLETED_ONBOARDING = booleanPreferencesKey("has_completed_onboarding")
        val KEY_ONBOARDING_COMPLETED_AT = longPreferencesKey("onboarding_completed_at")
        val KEY_ONBOARDING_VERSION = intPreferencesKey("onboarding_version")
        
        // Increment this to force re-onboarding when terms change
        const val REQUIRED_ONBOARDING_VERSION = 1
    }

    /**
     * Flow of whether onboarding has been completed.
     */
    val hasCompletedOnboarding: Flow<Boolean> = dataStore.data.map { prefs ->
        val savedVersion = prefs[KEY_ONBOARDING_VERSION] ?: 0
        if (savedVersion < REQUIRED_ONBOARDING_VERSION) {
            false
        } else {
            prefs[KEY_HAS_COMPLETED_ONBOARDING] ?: false
        }
    }

    /**
     * Mark onboarding as completed.
     */
    suspend fun completeOnboarding() {
        dataStore.edit { prefs ->
            prefs[KEY_HAS_COMPLETED_ONBOARDING] = true
            prefs[KEY_ONBOARDING_COMPLETED_AT] = System.currentTimeMillis()
            prefs[KEY_ONBOARDING_VERSION] = REQUIRED_ONBOARDING_VERSION
        }
    }

    /**
     * Reset onboarding state (for testing or re-acceptance).
     */
    suspend fun resetOnboarding() {
        dataStore.edit { prefs ->
            prefs[KEY_HAS_COMPLETED_ONBOARDING] = false
            prefs.remove(KEY_ONBOARDING_COMPLETED_AT)
        }
    }
}
