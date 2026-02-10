package com.foodshare.data.repository

import com.foodshare.core.cache.CacheKeys
import com.foodshare.core.cache.CachedRepository
import com.foodshare.core.cache.OfflineCache
import com.foodshare.core.cache.withCache
import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.network.RPCConfig
import com.foodshare.data.dto.AdvancedSearchParams
import com.foodshare.data.dto.AdvancedSearchResponse
import com.foodshare.data.dto.FilterPresetsResponse
import com.foodshare.data.dto.RecordSearchParams
import com.foodshare.data.dto.SavePresetResponse
import com.foodshare.data.dto.SearchFiltersDto
import com.foodshare.data.dto.SearchHistoryResponse
import com.foodshare.domain.model.FilterPreset
import com.foodshare.domain.model.SearchFilters
import com.foodshare.domain.model.SearchHistoryItem
import com.foodshare.domain.repository.SearchRepository
import com.foodshare.domain.repository.SearchResult
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of SearchRepository
 *
 * Uses:
 * - RateLimitedRPCClient for fault-tolerant RPC calls
 * - OfflineCache for NETWORK_FIRST caching pattern
 *
 * SYNC: Follows iOS repository caching pattern
 */
@Singleton
class SupabaseSearchRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val rpcClient: RateLimitedRPCClient,
    override val offlineCache: OfflineCache
) : SearchRepository, CachedRepository {

    override val json = Json { ignoreUnknownKeys = true }

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    override suspend fun search(
        filters: SearchFilters,
        latitude: Double,
        longitude: Double,
        limit: Int,
        offset: Int
    ): Result<SearchResult> {
        val params = AdvancedSearchParams(
            searchQuery = filters.query,
            latitude = latitude,
            longitude = longitude,
            radiusKm = filters.radiusKm.toInt(),
            limit = limit,
            offset = offset,
            categories = filters.categories.takeIf { it.isNotEmpty() },
            postTypes = filters.postTypes.takeIf { it.isNotEmpty() },
            dietaryPreferences = filters.dietaryPreferences
                .map { it.name.lowercase() }
                .takeIf { it.isNotEmpty() },
            freshnessHours = filters.freshnessHours,
            sortBy = filters.sortBy.name.lowercase()
        )

        return rpcClient.call<AdvancedSearchParams, AdvancedSearchResponse>(
            functionName = "search_food_items_advanced",
            params = params,
            config = RPCConfig.bulk
        ).map { response ->
            response.toSearchResult()
        }
    }

    override suspend fun getSuggestions(prefix: String, limit: Int): Result<List<String>> {
        val params = SuggestionParams(prefix = prefix, limit = limit)

        return rpcClient.call<SuggestionParams, List<SuggestionResponse>>(
            functionName = "search_suggestions",
            params = params,
            config = RPCConfig.default
        ).map { suggestions ->
            suggestions.map { it.suggestion }
        }
    }

    override suspend fun saveFilterPreset(
        name: String,
        filters: SearchFilters,
        isDefault: Boolean
    ): Result<FilterPreset> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = SavePresetParams(
            userId = userId,
            name = name,
            filters = SearchFiltersDto.fromDomain(filters),
            isDefault = isDefault
        )

        return rpcClient.call<SavePresetParams, SavePresetResponse>(
            functionName = "save_filter_preset",
            params = params,
            config = RPCConfig.default
        ).map { response ->
            FilterPreset(
                id = response.presetId ?: "",
                name = name,
                filters = filters,
                isDefault = isDefault
            )
        }
    }

    override suspend fun getFilterPresets(): Result<List<FilterPreset>> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = UserIdParams(userId = userId)

        val networkResult = rpcClient.call<UserIdParams, FilterPresetsResponse>(
            functionName = "get_filter_presets",
            params = params,
            config = RPCConfig.default
        ).map { response ->
            response.presets.map { it.toDomain() }
        }

        // Cache filter presets for offline access
        return try {
            val cached = networkResult.withCache(
                cache = offlineCache,
                key = CACHE_KEY_FILTER_PRESETS,
                ttlMs = OfflineCache.LONG_TTL_MS,
                serialize = { presets ->
                    json.encodeToString(ListSerializer(FilterPreset.serializer()), presets)
                },
                deserialize = { jsonStr ->
                    json.decodeFromString(ListSerializer(FilterPreset.serializer()), jsonStr)
                }
            )
            Result.success(cached.data)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun deleteFilterPreset(id: String): Result<Unit> {
        return runCatching {
            supabaseClient.from("saved_filters")
                .delete {
                    filter {
                        eq("id", id)
                        currentUserId?.let { eq("user_id", it) }
                    }
                }
        }
    }

    override suspend fun setDefaultPreset(id: String): Result<Unit> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        return runCatching {
            // First unset all defaults
            supabaseClient.from("saved_filters")
                .update({
                    set("is_default", false)
                }) {
                    filter {
                        eq("user_id", userId)
                        eq("is_default", true)
                    }
                }

            // Then set the new default
            supabaseClient.from("saved_filters")
                .update({
                    set("is_default", true)
                }) {
                    filter {
                        eq("id", id)
                        eq("user_id", userId)
                    }
                }
        }
    }

    override suspend fun getSearchHistory(limit: Int): Result<List<SearchHistoryItem>> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = GetHistoryParams(userId = userId, limit = limit)

        val networkResult = rpcClient.call<GetHistoryParams, SearchHistoryResponse>(
            functionName = "get_search_history",
            params = params,
            config = RPCConfig.default
        ).map { response ->
            response.history.map { it.toDomain() }
        }

        // Cache search history for offline access
        return try {
            val cached = networkResult.withCache(
                cache = offlineCache,
                key = CacheKeys.SEARCH_HISTORY,
                ttlMs = OfflineCache.LONG_TTL_MS,
                serialize = { history ->
                    json.encodeToString(ListSerializer(SearchHistoryItem.serializer()), history)
                },
                deserialize = { jsonStr ->
                    json.decodeFromString(ListSerializer(SearchHistoryItem.serializer()), jsonStr)
                }
            )
            Result.success(cached.data)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    companion object {
        private const val CACHE_KEY_FILTER_PRESETS = "search_filter_presets"
    }

    override suspend fun clearSearchHistory(): Result<Unit> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = UserIdParams(userId = userId)

        return rpcClient.call<UserIdParams, Unit>(
            functionName = "clear_search_history",
            params = params,
            config = RPCConfig.default
        )
    }

    override suspend fun recordSearch(
        query: String,
        filters: SearchFilters?,
        resultCount: Int
    ): Result<Unit> {
        val userId = currentUserId ?: return Result.success(Unit) // Silent fail if not authenticated

        val params = RecordSearchParams(
            userId = userId,
            query = query,
            filters = filters?.let { SearchFiltersDto.fromDomain(it) },
            resultCount = resultCount
        )

        return rpcClient.call<RecordSearchParams, Unit>(
            functionName = "record_search",
            params = params,
            config = RPCConfig.default
        )
    }
}

// RPC parameter classes
@Serializable
private data class SuggestionParams(
    @SerialName("p_prefix") val prefix: String,
    @SerialName("p_limit") val limit: Int = 5
)

@Serializable
private data class SuggestionResponse(
    val suggestion: String,
    val count: Long = 0
)

@Serializable
private data class SavePresetParams(
    @SerialName("p_user_id") val userId: String,
    @SerialName("p_name") val name: String,
    @SerialName("p_filters") val filters: SearchFiltersDto,
    @SerialName("p_is_default") val isDefault: Boolean = false
)

@Serializable
private data class UserIdParams(
    @SerialName("p_user_id") val userId: String
)

@Serializable
private data class GetHistoryParams(
    @SerialName("p_user_id") val userId: String,
    @SerialName("p_limit") val limit: Int = 10
)
