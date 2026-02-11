package com.foodshare.core.push

import android.content.Context
import android.os.Build
import android.util.Log
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.functions.functions
import io.ktor.utils.io.InternalAPI
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

// DataStore for push token preferences
private val Context.pushDataStore: DataStore<Preferences> by preferencesDataStore(name = "push_settings")

/**
 * Manages push token registration and notification settings.
 *
 * Note: Firebase has been removed. This class now provides a stub implementation
 * for push token management. Integrate with your preferred push provider
 * (e.g., Supabase Realtime, OneSignal, or native Android push) as needed.
 *
 * SYNC: Uses `send-push-notification` Edge Function format
 */
@Singleton
class PushTokenManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val supabaseClient: SupabaseClient
) {
    companion object {
        private const val TAG = "PushTokenManager"
        private val KEY_PUSH_TOKEN = stringPreferencesKey("push_token")
        private val KEY_REGISTERED_USER_ID = stringPreferencesKey("registered_user_id")
    }

    private val dataStore = context.pushDataStore

    /**
     * Get the current push token.
     *
     * TODO(push): Integrate push notification provider (FCM, OneSignal, or Pushy)
     * - For FCM: Use FirebaseMessaging.getInstance().token
     * - For OneSignal: Use OneSignal.getDeviceState()?.userId
     * For now, returns null as no push provider is configured.
     */
    suspend fun getToken(): String? {
        Log.d(TAG, "Push token retrieval not implemented - no push provider configured")
        return null
    }

    /**
     * Get the locally stored push token.
     */
    suspend fun getStoredToken(): String? {
        return dataStore.data.map { preferences ->
            preferences[KEY_PUSH_TOKEN]
        }.first()
    }

    /**
     * Register a push token with the backend.
     * 
     * Call this when you obtain a token from your push provider.
     */
    suspend fun registerToken(token: String): Result<Unit> {
        return runCatching {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            // Check if already registered for this user
            val storedToken = getStoredToken()
            val storedUserId = dataStore.data.map { it[KEY_REGISTERED_USER_ID] }.first()

            if (storedToken == token && storedUserId == userId) {
                Log.d(TAG, "Token already registered for user")
                return@runCatching
            }

            // Register with backend
            val deviceInfo = buildJsonObject {
                put("token", token)
                put("platform", "android")
                put("device_type", Build.MODEL)
                put("os_version", "Android ${Build.VERSION.RELEASE}")
                put("app_version", getAppVersion())
            }

            supabaseClient.from("push_tokens")
                .upsert(buildJsonObject {
                    put("user_id", userId)
                    put("token", token)
                    put("platform", "android")
                    put("device_info", deviceInfo)
                    put("is_active", true)
                }) {
                    onConflict = "user_id,platform"
                }

            // Store locally
            dataStore.edit { preferences ->
                preferences[KEY_PUSH_TOKEN] = token
                preferences[KEY_REGISTERED_USER_ID] = userId
            }

            Log.d(TAG, "Push token registered successfully")
        }
    }

    /**
     * Unregister push token (call on logout).
     */
    suspend fun unregisterToken(): Result<Unit> {
        return runCatching {
            val token = getStoredToken() ?: return@runCatching

            // Mark as inactive in backend
            try {
                supabaseClient.from("push_tokens")
                    .update(mapOf("is_active" to false)) {
                        filter {
                            eq("token", token)
                        }
                    }
            } catch (e: Exception) {
                Log.w(TAG, "Failed to unregister token on backend", e)
            }

            // Clear local storage
            dataStore.edit { preferences ->
                preferences.remove(KEY_PUSH_TOKEN)
                preferences.remove(KEY_REGISTERED_USER_ID)
            }

            Log.d(TAG, "Push token unregistered")
        }
    }

    /**
     * Delete the push token entirely (for account deletion).
     */
    suspend fun deleteToken(): Result<Unit> {
        return runCatching {
            // Delete from backend
            val token = getStoredToken()
            if (token != null) {
                try {
                    supabaseClient.from("push_tokens")
                        .delete {
                            filter {
                                eq("token", token)
                            }
                        }
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to delete token from backend", e)
                }
            }

            // Clear local storage
            dataStore.edit { it.clear() }

            Log.d(TAG, "Push token deleted")
        }
    }

    /**
     * Send a test notification to this device.
     */
    @OptIn(InternalAPI::class)
    suspend fun sendTestNotification(): Result<Unit> {
        return runCatching {
            val token = getStoredToken()
                ?: throw IllegalStateException("No push token registered")

            // Call Edge Function to send test notification
            supabaseClient.functions.invoke("send-push-notification") {
                body = buildJsonObject {
                    put("token", token)
                    put("title", "Test Notification")
                    put("body", "Push notifications are working!")
                    put("type", "system")
                }
            }
        }
    }

    /**
     * Check if push notifications are enabled and registered.
     */
    suspend fun isRegistered(): Boolean {
        val token = getStoredToken()
        val userId = dataStore.data.map { it[KEY_REGISTERED_USER_ID] }.first()
        val currentUserId = supabaseClient.auth.currentUserOrNull()?.id

        return token != null && userId == currentUserId
    }

    /**
     * Get app version for device info.
     */
    private fun getAppVersion(): String {
        return try {
            val packageInfo = context.packageManager.getPackageInfo(context.packageName, 0)
            packageInfo.versionName ?: "unknown"
        } catch (e: Exception) {
            "unknown"
        }
    }
}

/**
 * Push notification settings stored locally.
 */
@Serializable
data class PushSettings(
    val messagesEnabled: Boolean = true,
    val newFoodEnabled: Boolean = true,
    val arrangementsEnabled: Boolean = true,
    val favoritesEnabled: Boolean = true,
    val systemEnabled: Boolean = true,
    val soundEnabled: Boolean = true,
    val vibrationEnabled: Boolean = true
)
