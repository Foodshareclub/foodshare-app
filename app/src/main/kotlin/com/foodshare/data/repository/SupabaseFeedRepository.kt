package com.foodshare.data.repository

import com.foodshare.core.cache.CacheKeys
import com.foodshare.core.cache.CachedRepository
import com.foodshare.core.cache.CachedResult
import com.foodshare.core.cache.OfflineCache
import com.foodshare.core.cache.withCache
import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.network.RPCConfig
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.core.realtime.RealtimeFilter
import com.foodshare.data.dto.CategoryDto
import com.foodshare.data.dto.FoodListingDto
import com.foodshare.domain.model.Category
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.repository.FeedRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of FeedRepository
 *
 * Uses:
 * - RateLimitedRPCClient for fault-tolerant RPC calls
 * - RealtimeChannelManager for subscription lifecycle
 * - PostGIS for location-based queries
 * - OfflineCache for NETWORK_FIRST caching pattern
 *
 * SYNC: Follows iOS repository caching pattern
 */
@Singleton
class SupabaseFeedRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val rpcClient: RateLimitedRPCClient,
    private val realtimeManager: RealtimeChannelManager,
    override val offlineCache: OfflineCache
) : FeedRepository, CachedRepository {

    override val json = Json { ignoreUnknownKeys = true }

    override suspend fun getNearbyListings(
        latitude: Double,
        longitude: Double,
        radiusKm: Double,
        limit: Int,
        offset: Int,
        postType: String?,
        categoryId: Int?
    ): Result<List<FoodListing>> {
        // Use RPC function for PostGIS distance calculation
        val params = NearbyListingsParams(
            lat = latitude,
            lon = longitude,
            radiusMeters = radiusKm * 1000,
            maxResults = limit,
            offsetCount = offset,
            filterPostType = postType,
            filterCategoryId = categoryId
        )

        // Use rate-limited RPC client with bulk config for feed queries
        val networkResult = rpcClient.call<NearbyListingsParams, List<FoodListingDto>>(
            functionName = "get_nearby_posts",
            params = params,
            config = RPCConfig.bulk
        ).map { dtos ->
            dtos.map { it.toDomain() }
        }.recoverCatching {
            // Fallback: Simple query without location if RPC fails
            val query = supabaseClient.from("posts")
                .select {
                    filter {
                        eq("is_active", true)
                        postType?.let { eq("post_type", it) }
                        categoryId?.let { eq("category_id", it) }
                    }
                    order("created_at", Order.DESCENDING)
                    limit(limit.toLong())
                }

            // Decode to DTO, then convert to domain model
            query.decodeList<FoodListingDto>().map { it.toDomain() }
        }

        // Apply caching for first page of unfiltered results
        return if (offset == 0 && postType == null && categoryId == null) {
            try {
                val cached = networkResult.withCache(
                    cache = offlineCache,
                    key = CacheKeys.FEED_LISTINGS,
                    ttlMs = OfflineCache.DEFAULT_TTL_MS,
                    serialize = { listings ->
                        json.encodeToString(ListSerializer(FoodListing.serializer()), listings)
                    },
                    deserialize = { jsonStr ->
                        json.decodeFromString(ListSerializer(FoodListing.serializer()), jsonStr)
                    }
                )
                Result.success(cached.data)
            } catch (e: Exception) {
                Result.failure(e)
            }
        } else {
            networkResult
        }
    }

    override suspend fun getListingById(id: Int): Result<FoodListing> {
        return runCatching {
            supabaseClient.from("posts")
                .select {
                    filter {
                        eq("id", id)
                    }
                }
                .decodeSingle<FoodListingDto>()
                .toDomain()
        }
    }

    override suspend fun getCategories(): Result<List<Category>> {
        val networkResult = runCatching {
            supabaseClient.from("categories")
                .select {
                    order("sort_order", Order.ASCENDING)
                }
                .decodeList<CategoryDto>()
                .map { it.toDomain() }
        }

        // Categories change infrequently, use longer TTL
        return try {
            val cached = networkResult.withCache(
                cache = offlineCache,
                key = CACHE_KEY_CATEGORIES,
                ttlMs = OfflineCache.LONG_TTL_MS,
                serialize = { categories ->
                    json.encodeToString(ListSerializer(Category.serializer()), categories)
                },
                deserialize = { jsonStr ->
                    json.decodeFromString(ListSerializer(Category.serializer()), jsonStr)
                }
            )
            Result.success(cached.data)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    companion object {
        private const val CACHE_KEY_CATEGORIES = "feed_categories"
    }

    override fun observeNearbyListings(
        latitude: Double,
        longitude: Double,
        radiusKm: Double
    ): Flow<List<FoodListing>> = flow {
        // Initial fetch
        getNearbyListings(latitude, longitude, radiusKm)
            .onSuccess { emit(it) }
            .onFailure { emit(emptyList()) }

        // Subscribe to realtime changes using the manager
        val filter = RealtimeFilter(
            table = "posts",
            filter = "is_active=eq.true"
        )

        realtimeManager.subscribe<FoodListingDto>(filter)
            .collect { change ->
                // Re-fetch on any change to get properly filtered/sorted results
                getNearbyListings(latitude, longitude, radiusKm)
                    .onSuccess { listings -> emit(listings) }
            }
    }

    /**
     * Stop observing listings (call when leaving feed screen).
     */
    suspend fun stopObserving() {
        realtimeManager.unsubscribe(RealtimeFilter(table = "posts"))
    }
}

/**
 * Parameters for the get_nearby_posts RPC function
 */
@Serializable
private data class NearbyListingsParams(
    val lat: Double,
    val lon: Double,
    val radiusMeters: Double = 5000.0,
    val maxResults: Int = 20,
    val offsetCount: Int = 0,
    val filterPostType: String? = null,
    val filterCategoryId: Int? = null
)
