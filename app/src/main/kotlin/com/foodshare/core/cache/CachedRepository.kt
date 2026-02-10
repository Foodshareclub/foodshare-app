package com.foodshare.core.cache

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.json.Json

/**
 * Interface for repositories that support caching.
 *
 * Provides standardized cache operations for NETWORK_FIRST pattern.
 * Implementations should delegate to OfflineCache for storage.
 *
 * SYNC: Mirrors iOS CachedRepository protocol
 */
interface CachedRepository {
    val offlineCache: OfflineCache
    val json: Json
}

/**
 * Result of a cached fetch operation.
 *
 * @param data The fetched data
 * @param source Where the data came from
 * @param isStale Whether the data is potentially outdated
 */
data class CachedResult<T>(
    val data: T,
    val source: DataSource,
    val isStale: Boolean = false
) {
    enum class DataSource {
        NETWORK,
        CACHE,
        CACHE_FALLBACK
    }

    val isFromCache: Boolean get() = source != DataSource.NETWORK
    val isFromNetwork: Boolean get() = source == DataSource.NETWORK
}

/**
 * Extension to add caching to any Result-returning function.
 *
 * Implements NETWORK_FIRST pattern:
 * 1. Try network first
 * 2. On success: cache result and return
 * 3. On failure: return cached data if available
 *
 * @param cache The offline cache to use
 * @param key Cache key for this data
 * @param ttlMs Time-to-live for cached data
 * @param serialize Function to serialize data to JSON string
 * @param deserialize Function to deserialize JSON string to data
 */
suspend fun <T> Result<T>.withCache(
    cache: OfflineCache,
    key: String,
    ttlMs: Long = OfflineCache.DEFAULT_TTL_MS,
    serialize: (T) -> String,
    deserialize: (String) -> T
): CachedResult<T> {
    return fold(
        onSuccess = { data ->
            // Cache successful network result
            try {
                cache.save(key, serialize(data), ttlMs)
            } catch (e: Exception) {
                // Cache failure is non-critical
            }
            CachedResult(data, CachedResult.DataSource.NETWORK)
        },
        onFailure = { networkError ->
            // Try to load from cache
            val cached = try {
                cache.load(key, deserialize)
            } catch (e: Exception) {
                null
            }

            if (cached != null) {
                CachedResult(
                    data = cached.data,
                    source = CachedResult.DataSource.CACHE_FALLBACK,
                    isStale = cached.isStale
                )
            } else {
                // No cache available, propagate original error
                throw networkError
            }
        }
    )
}

/**
 * Extension for Result that returns Result<CachedResult<T>>.
 *
 * Same as withCache but wraps in Result for error handling.
 */
suspend fun <T> Result<T>.withCacheSafe(
    cache: OfflineCache,
    key: String,
    ttlMs: Long = OfflineCache.DEFAULT_TTL_MS,
    serialize: (T) -> String,
    deserialize: (String) -> T
): Result<CachedResult<T>> {
    return runCatching {
        withCache(cache, key, ttlMs, serialize, deserialize)
    }
}

/**
 * CACHE_FIRST pattern: Check cache first, then network if cache miss/stale.
 *
 * @param cache The offline cache to use
 * @param key Cache key for this data
 * @param ttlMs Time-to-live for cached data
 * @param networkFetch Function to fetch fresh data from network
 * @param serialize Function to serialize data to JSON string
 * @param deserialize Function to deserialize JSON string to data
 */
suspend fun <T> fetchWithCacheFirst(
    cache: OfflineCache,
    key: String,
    ttlMs: Long = OfflineCache.DEFAULT_TTL_MS,
    networkFetch: suspend () -> Result<T>,
    serialize: (T) -> String,
    deserialize: (String) -> T
): CachedResult<T> {
    // Check cache first
    val cached = try {
        cache.load(key, deserialize)
    } catch (e: Exception) {
        null
    }

    if (cached != null && !cached.isExpired) {
        return CachedResult(cached.data, CachedResult.DataSource.CACHE)
    }

    // Cache miss or expired, try network
    return networkFetch().withCache(cache, key, ttlMs, serialize, deserialize)
}

/**
 * NETWORK_FIRST pattern as a standalone function.
 *
 * @param cache The offline cache to use
 * @param key Cache key for this data
 * @param ttlMs Time-to-live for cached data
 * @param networkFetch Function to fetch fresh data from network
 * @param serialize Function to serialize data to JSON string
 * @param deserialize Function to deserialize JSON string to data
 */
suspend fun <T> fetchWithNetworkFirst(
    cache: OfflineCache,
    key: String,
    ttlMs: Long = OfflineCache.DEFAULT_TTL_MS,
    networkFetch: suspend () -> Result<T>,
    serialize: (T) -> String,
    deserialize: (String) -> T
): CachedResult<T> {
    return networkFetch().withCache(cache, key, ttlMs, serialize, deserialize)
}

/**
 * Flow that emits cached data first, then fresh network data.
 *
 * Useful for UI that wants immediate display with stale indicator.
 *
 * @param cache The offline cache to use
 * @param key Cache key for this data
 * @param ttlMs Time-to-live for cached data
 * @param networkFetch Function to fetch fresh data from network
 * @param serialize Function to serialize data to JSON string
 * @param deserialize Function to deserialize JSON string to data
 */
fun <T> observeWithCache(
    cache: OfflineCache,
    key: String,
    ttlMs: Long = OfflineCache.DEFAULT_TTL_MS,
    networkFetch: suspend () -> Result<T>,
    serialize: (T) -> String,
    deserialize: (String) -> T
): Flow<CachedResult<T>> = flow {
    // Emit cached data first if available
    val cached = try {
        cache.load(key, deserialize)
    } catch (e: Exception) {
        null
    }

    if (cached != null) {
        emit(CachedResult(cached.data, CachedResult.DataSource.CACHE, cached.isStale))
    }

    // Then fetch fresh data
    try {
        val result = fetchWithNetworkFirst(cache, key, ttlMs, networkFetch, serialize, deserialize)
        emit(result)
    } catch (e: Exception) {
        // Only throw if we had no cached data
        if (cached == null) throw e
    }
}

/**
 * Invalidate cache entry.
 */
suspend fun OfflineCache.invalidate(key: String) {
    clear(key)
}

/**
 * Invalidate multiple cache entries.
 */
suspend fun OfflineCache.invalidateAll(vararg keys: String) {
    keys.forEach { clear(it) }
}
