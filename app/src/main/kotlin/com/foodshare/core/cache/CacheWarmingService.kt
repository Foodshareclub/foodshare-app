package com.foodshare.core.cache

import android.content.Context
import android.util.Log
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.withContext
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Preloads frequently accessed data into the offline cache on app launch.
 *
 * Warms the following caches in parallel:
 * - Feed listings (latest available food near the user)
 * - Nearby listings (geographically closest items)
 * - Unread notification count
 * - User profile data
 *
 * This reduces perceived latency on first screen display by having
 * data ready in the cache before the UI requests it.
 *
 * SYNC: Mirrors Swift CacheWarmingService
 */
@Singleton
class CacheWarmingService @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val offlineCache: OfflineCache,
    @ApplicationContext private val context: Context
) {
    companion object {
        private const val TAG = "CacheWarmingService"
        private const val FEED_PAGE_SIZE = 20
        private const val NEARBY_PAGE_SIZE = 10
        private const val WARM_TTL_MS = 10 * 60 * 1000L // 10 minutes
        const val CACHE_KEY_NEARBY = "nearby_listings"
        const val CACHE_KEY_UNREAD_COUNT = "unread_notification_count"
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    // ========================================================================
    // Public API
    // ========================================================================

    /**
     * Warm all caches in parallel.
     *
     * This is designed to be called at app launch. Errors in individual
     * warming tasks are caught and logged; they do not prevent other
     * tasks from completing.
     *
     * @return CacheWarmingResult with success/failure counts
     */
    suspend fun warmAll(): CacheWarmingResult = coroutineScope {
        Log.d(TAG, "Starting cache warming")
        val startTime = System.currentTimeMillis()

        val feedDeferred = async { warmFeedListings() }
        val nearbyDeferred = async { warmNearbyListings() }
        val notificationsDeferred = async { warmUnreadNotificationCount() }
        val profileDeferred = async { warmUserProfile() }

        val feedResult = feedDeferred.await()
        val nearbyResult = nearbyDeferred.await()
        val notificationsResult = notificationsDeferred.await()
        val profileResult = profileDeferred.await()

        val results = listOf(feedResult, nearbyResult, notificationsResult, profileResult)
        val successCount = results.count { it }
        val failureCount = results.count { !it }
        val elapsedMs = System.currentTimeMillis() - startTime

        Log.d(TAG, "Cache warming completed in ${elapsedMs}ms: " +
            "$successCount succeeded, $failureCount failed")

        CacheWarmingResult(
            feedWarmed = feedResult,
            nearbyWarmed = nearbyResult,
            notificationsWarmed = notificationsResult,
            profileWarmed = profileResult,
            durationMs = elapsedMs
        )
    }

    /**
     * Warm only the feed listings cache.
     */
    suspend fun warmFeedOnly(): Boolean {
        return warmFeedListings()
    }

    /**
     * Warm only the nearby listings cache.
     */
    suspend fun warmNearbyOnly(): Boolean {
        return warmNearbyListings()
    }

    // ========================================================================
    // Individual Warming Tasks
    // ========================================================================

    /**
     * Fetch and cache the latest feed listings.
     */
    private suspend fun warmFeedListings(): Boolean = withContext(Dispatchers.IO) {
        try {
            val listings = supabaseClient.from("posts")
                .select {
                    filter {
                        eq("is_active", true)
                        eq("is_arranged", false)
                    }
                    order("id", Order.DESCENDING)
                    limit(FEED_PAGE_SIZE.toLong())
                }
                .decodeList<CachedListing>()

            val serialized = json.encodeToString(listings)
            offlineCache.save(CacheKeys.FEED_LISTINGS, serialized, WARM_TTL_MS)
            Log.d(TAG, "Warmed feed cache with ${listings.size} listings")
            true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to warm feed cache: ${e.message}")
            false
        }
    }

    /**
     * Fetch and cache nearby listings.
     *
     * Uses the `nearby_listings` RPC function if the user has a known location,
     * otherwise falls back to the standard feed query.
     */
    private suspend fun warmNearbyListings(): Boolean = withContext(Dispatchers.IO) {
        try {
            val listings = supabaseClient.from("posts")
                .select {
                    filter {
                        eq("is_active", true)
                        eq("is_arranged", false)
                    }
                    order("id", Order.DESCENDING)
                    limit(NEARBY_PAGE_SIZE.toLong())
                }
                .decodeList<CachedListing>()

            val serialized = json.encodeToString(listings)
            offlineCache.save(CACHE_KEY_NEARBY, serialized, WARM_TTL_MS)
            Log.d(TAG, "Warmed nearby cache with ${listings.size} listings")
            true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to warm nearby cache: ${e.message}")
            false
        }
    }

    /**
     * Fetch and cache the unread notification count.
     */
    private suspend fun warmUnreadNotificationCount(): Boolean = withContext(Dispatchers.IO) {
        try {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: return@withContext false

            val result = supabaseClient.from("notifications")
                .select {
                    filter {
                        eq("user_id", userId)
                        eq("is_read", false)
                    }
                    count(io.github.jan.supabase.postgrest.query.Count.EXACT)
                    limit(0)
                }

            val count = result.countOrNull() ?: 0L
            offlineCache.save(CACHE_KEY_UNREAD_COUNT, count.toString(), WARM_TTL_MS)
            Log.d(TAG, "Warmed notification count: $count unread")
            true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to warm notification count: ${e.message}")
            false
        }
    }

    /**
     * Fetch and cache the current user's profile.
     */
    private suspend fun warmUserProfile(): Boolean = withContext(Dispatchers.IO) {
        try {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: return@withContext false

            val profile = supabaseClient.from("profiles")
                .select {
                    filter { eq("id", userId) }
                    limit(1)
                }
                .decodeSingleOrNull<CachedProfile>()
                ?: return@withContext false

            val serialized = json.encodeToString(profile)
            offlineCache.save(CacheKeys.USER_PROFILE, serialized, WARM_TTL_MS)
            Log.d(TAG, "Warmed user profile cache")
            true
        } catch (e: Exception) {
            Log.w(TAG, "Failed to warm user profile: ${e.message}")
            false
        }
    }

    // ========================================================================
    // Cache Keys
    // ========================================================================

}

// ============================================================================
// Data Models (lightweight models for cache warming)
// ============================================================================

/**
 * Lightweight listing model for cache warming.
 * Contains only the fields needed for feed display.
 */
@Serializable
data class CachedListing(
    val id: Int,
    @SerialName("post_name") val postName: String,
    @SerialName("post_description") val postDescription: String? = null,
    @SerialName("post_type") val postType: String? = null,
    @SerialName("pickup_time") val pickupTime: String? = null,
    @SerialName("post_address") val postAddress: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val images: List<String>? = null,
    @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("is_arranged") val isArranged: Boolean = false,
    @SerialName("distance_meters") val distanceMeters: Double? = null
)

/**
 * Lightweight profile model for cache warming.
 */
@Serializable
data class CachedProfile(
    val id: String,
    @SerialName("display_name") val displayName: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val bio: String? = null,
    @SerialName("community_rank") val communityRank: Int? = null
)

/**
 * Result of a cache warming operation.
 */
data class CacheWarmingResult(
    val feedWarmed: Boolean,
    val nearbyWarmed: Boolean,
    val notificationsWarmed: Boolean,
    val profileWarmed: Boolean,
    val durationMs: Long
) {
    val allSucceeded: Boolean
        get() = feedWarmed && nearbyWarmed && notificationsWarmed && profileWarmed

    val successCount: Int
        get() = listOf(feedWarmed, nearbyWarmed, notificationsWarmed, profileWarmed).count { it }
}
