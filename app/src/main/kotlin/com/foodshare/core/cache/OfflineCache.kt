package com.foodshare.core.cache

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.first
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Cache policy for offline data.
 */
enum class CachePolicy {
    /** Load from cache first, then refresh from network */
    CACHE_FIRST,
    /** Load from network first, fall back to cache on failure */
    NETWORK_FIRST,
    /** Only load from cache, never network */
    CACHE_ONLY,
    /** Only load from network, never cache */
    NETWORK_ONLY
}

/**
 * Cache entry with TTL support.
 */
data class CacheEntry<T>(
    val data: T,
    val timestamp: Long,
    val ttlMs: Long
) {
    val isExpired: Boolean
        get() = System.currentTimeMillis() > timestamp + ttlMs

    val isStale: Boolean
        get() = isExpired

    val age: Long
        get() = System.currentTimeMillis() - timestamp
}

/**
 * Offline cache interface for storing and retrieving data.
 */
interface OfflineCache {
    /**
     * Save data to cache with TTL.
     *
     * @param key Cache key
     * @param data Data to cache (must be serializable)
     * @param ttlMs Time-to-live in milliseconds (default: 5 minutes)
     */
    suspend fun <T> save(key: String, data: T, ttlMs: Long = DEFAULT_TTL_MS)

    /**
     * Load data from cache.
     *
     * @param key Cache key
     * @param deserialize Function to deserialize the cached JSON
     * @return CacheEntry if found, null otherwise
     */
    suspend fun <T> load(key: String, deserialize: (String) -> T): CacheEntry<T>?

    /**
     * Clear a specific cache entry.
     */
    suspend fun clear(key: String)

    /**
     * Clear all cached data.
     */
    suspend fun clearAll()

    /**
     * Check if cache entry exists and is not expired.
     */
    suspend fun isValid(key: String): Boolean

    companion object {
        const val DEFAULT_TTL_MS = 5 * 60 * 1000L // 5 minutes
        const val SHORT_TTL_MS = 30 * 1000L // 30 seconds
        const val LONG_TTL_MS = 30 * 60 * 1000L // 30 minutes
    }
}

// DataStore extension
private val Context.offlineDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "offline_cache"
)

/**
 * DataStore-based implementation of OfflineCache.
 */
@Singleton
class DataStoreOfflineCache @Inject constructor(
    private val context: Context
) : OfflineCache {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    override suspend fun <T> save(key: String, data: T, ttlMs: Long) {
        val serialized = when (data) {
            is String -> data
            else -> json.encodeToString(data as Any)
        }

        context.offlineDataStore.edit { prefs ->
            prefs[stringPreferencesKey("data_$key")] = serialized
            prefs[longPreferencesKey("timestamp_$key")] = System.currentTimeMillis()
            prefs[longPreferencesKey("ttl_$key")] = ttlMs
        }
    }

    override suspend fun <T> load(key: String, deserialize: (String) -> T): CacheEntry<T>? {
        val prefs = context.offlineDataStore.data.first()

        val dataKey = stringPreferencesKey("data_$key")
        val timestampKey = longPreferencesKey("timestamp_$key")
        val ttlKey = longPreferencesKey("ttl_$key")

        val serialized = prefs[dataKey] ?: return null
        val timestamp = prefs[timestampKey] ?: return null
        val ttl = prefs[ttlKey] ?: OfflineCache.DEFAULT_TTL_MS

        return try {
            CacheEntry(
                data = deserialize(serialized),
                timestamp = timestamp,
                ttlMs = ttl
            )
        } catch (e: Exception) {
            // Invalid cache entry, clear it
            clear(key)
            null
        }
    }

    override suspend fun clear(key: String) {
        context.offlineDataStore.edit { prefs ->
            prefs.remove(stringPreferencesKey("data_$key"))
            prefs.remove(longPreferencesKey("timestamp_$key"))
            prefs.remove(longPreferencesKey("ttl_$key"))
        }
    }

    override suspend fun clearAll() {
        context.offlineDataStore.edit { it.clear() }
    }

    override suspend fun isValid(key: String): Boolean {
        val prefs = context.offlineDataStore.data.first()

        val timestampKey = longPreferencesKey("timestamp_$key")
        val ttlKey = longPreferencesKey("ttl_$key")

        val timestamp = prefs[timestampKey] ?: return false
        val ttl = prefs[ttlKey] ?: OfflineCache.DEFAULT_TTL_MS

        return System.currentTimeMillis() <= timestamp + ttl
    }
}

/**
 * Cache keys for common data types.
 */
object CacheKeys {
    // Feed
    const val FEED_LISTINGS = "feed_listings"
    const val FEED_TRENDING = "feed_trending"

    // User
    const val USER_PROFILE = "user_profile"
    const val USER_FAVORITES = "user_favorites"

    // Messages
    const val CHAT_ROOMS = "chat_rooms"
    fun chatMessages(roomId: String) = "chat_messages_$roomId"

    // Forum
    const val FORUM_POSTS = "forum_posts"
    fun forumPost(postId: Int) = "forum_post_$postId"
    fun forumComments(postId: Int) = "forum_comments_$postId"

    // Search
    const val SEARCH_HISTORY = "search_history"
    const val SEARCH_SUGGESTIONS = "search_suggestions"
}
