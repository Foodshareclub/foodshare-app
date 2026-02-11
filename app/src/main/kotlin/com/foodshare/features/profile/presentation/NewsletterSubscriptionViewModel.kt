package com.foodshare.features.profile.presentation

import android.content.Context
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import javax.inject.Inject

// DataStore for newsletter preferences
private val Context.newsletterDataStore by preferencesDataStore(name = "newsletter_settings")

/**
 * Preference keys for newsletter settings.
 */
private object NewsletterKeys {
    val SUBSCRIBED = booleanPreferencesKey("newsletter_subscribed")
    val FREQUENCY = stringPreferencesKey("newsletter_frequency")
    val TOPICS = stringSetPreferencesKey("newsletter_topics")
}

/**
 * Available newsletter topics.
 */
enum class NewsletterTopic(val key: String, val displayName: String, val description: String) {
    COMMUNITY_UPDATES(
        key = "community_updates",
        displayName = "Community Updates",
        description = "News about your local food sharing community"
    ),
    FOOD_TIPS(
        key = "food_tips",
        displayName = "Food Tips",
        description = "Recipes, storage tips, and reducing food waste"
    ),
    SUSTAINABILITY(
        key = "sustainability",
        displayName = "Sustainability",
        description = "Environmental impact and sustainability insights"
    ),
    EVENTS(
        key = "events",
        displayName = "Events",
        description = "Upcoming community events and meetups"
    )
}

/**
 * Available newsletter frequency options.
 */
enum class NewsletterFrequency(val key: String, val displayName: String) {
    WEEKLY("weekly", "Weekly"),
    MONTHLY("monthly", "Monthly")
}

/**
 * ViewModel for the Newsletter Subscription screen.
 *
 * Manages newsletter opt-in/opt-out, frequency selection, and topic preferences.
 * Persists settings locally via DataStore and syncs to the Supabase
 * "newsletter_preferences" table.
 *
 * SYNC: Mirrors Swift NewsletterSubscriptionViewModel
 */
@HiltViewModel
class NewsletterSubscriptionViewModel @Inject constructor(
    @ApplicationContext private val context: Context,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    /**
     * UI state for the Newsletter Subscription screen.
     */
    data class UiState(
        val isSubscribed: Boolean = false,
        val frequency: NewsletterFrequency = NewsletterFrequency.WEEKLY,
        val selectedTopics: Set<NewsletterTopic> = emptySet(),
        val isLoading: Boolean = true,
        val isSaving: Boolean = false,
        val error: String? = null,
        val successMessage: String? = null
    ) {
        val hasChanges: Boolean
            get() = true // Simplified; in production compare with initial state
    }

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    init {
        loadPreferences()
    }

    /**
     * Load saved newsletter preferences from DataStore.
     */
    private fun loadPreferences() {
        viewModelScope.launch {
            try {
                val prefs = context.newsletterDataStore.data.first()

                val isSubscribed = prefs[NewsletterKeys.SUBSCRIBED] ?: false
                val frequencyKey = prefs[NewsletterKeys.FREQUENCY] ?: NewsletterFrequency.WEEKLY.key
                val topicKeys = prefs[NewsletterKeys.TOPICS] ?: emptySet()

                val frequency = NewsletterFrequency.entries.find { it.key == frequencyKey }
                    ?: NewsletterFrequency.WEEKLY

                val topics = topicKeys.mapNotNull { key ->
                    NewsletterTopic.entries.find { it.key == key }
                }.toSet()

                _uiState.update {
                    it.copy(
                        isSubscribed = isSubscribed,
                        frequency = frequency,
                        selectedTopics = topics,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = "Failed to load preferences"
                    )
                }
            }
        }
    }

    /**
     * Toggle the newsletter subscription on or off.
     *
     * @param subscribed Whether the user wants to subscribe
     */
    fun toggleSubscription(subscribed: Boolean) {
        _uiState.update {
            it.copy(
                isSubscribed = subscribed,
                successMessage = null
            )
        }
    }

    /**
     * Set the newsletter delivery frequency.
     *
     * @param frequency The desired frequency (weekly or monthly)
     */
    fun setFrequency(frequency: NewsletterFrequency) {
        _uiState.update {
            it.copy(
                frequency = frequency,
                successMessage = null
            )
        }
    }

    /**
     * Toggle a specific topic of interest on or off.
     *
     * @param topic The topic to toggle
     */
    fun toggleTopic(topic: NewsletterTopic) {
        _uiState.update { state ->
            val updatedTopics = if (topic in state.selectedTopics) {
                state.selectedTopics - topic
            } else {
                state.selectedTopics + topic
            }
            state.copy(
                selectedTopics = updatedTopics,
                successMessage = null
            )
        }
    }

    /**
     * Save the current preferences to DataStore and sync to the backend.
     */
    fun savePreferences() {
        val state = _uiState.value

        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, error = null, successMessage = null) }

            try {
                // Save locally to DataStore
                context.newsletterDataStore.edit { prefs ->
                    prefs[NewsletterKeys.SUBSCRIBED] = state.isSubscribed
                    prefs[NewsletterKeys.FREQUENCY] = state.frequency.key
                    prefs[NewsletterKeys.TOPICS] = state.selectedTopics.map { it.key }.toSet()
                }

                // Sync to backend
                syncToBackend(state)

                _uiState.update {
                    it.copy(
                        isSaving = false,
                        successMessage = "Preferences saved successfully!"
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isSaving = false,
                        error = e.message ?: "Failed to save preferences"
                    )
                }
            }
        }
    }

    /**
     * Sync newsletter preferences to the Supabase backend.
     */
    private suspend fun syncToBackend(state: UiState) {
        val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return

        val updateData = buildJsonObject {
            put("user_id", userId)
            put("newsletter_subscribed", state.isSubscribed)
            put("newsletter_frequency", state.frequency.key)
            putJsonArray("newsletter_topics") {
                state.selectedTopics.forEach { topic ->
                    add(kotlinx.serialization.json.JsonPrimitive(topic.key))
                }
            }
        }

        supabaseClient.from("newsletter_preferences")
            .upsert(updateData)
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
