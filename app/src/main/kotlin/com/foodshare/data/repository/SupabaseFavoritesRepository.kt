package com.foodshare.data.repository

import com.foodshare.domain.repository.BatchFavoriteOperation
import com.foodshare.domain.repository.BatchFavoriteOperationResult
import com.foodshare.domain.repository.BatchFavoriteResult
import com.foodshare.domain.repository.FavoriteAction
import com.foodshare.domain.repository.FavoriteStatus
import com.foodshare.domain.repository.FavoritesRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.PostgresAction
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of FavoritesRepository
 *
 * Uses the `favorites` table with profile_id and post_id
 */
@Singleton
class SupabaseFavoritesRepository @Inject constructor(
    private val supabaseClient: SupabaseClient
) : FavoritesRepository {

    // Local cache of favorites
    private val _favoritesCache = MutableStateFlow<Set<Int>>(emptySet())

    override suspend fun getFavorites(): Result<Set<Int>> {
        return runCatching {
            val userId = getCurrentUserId()

            val favorites = supabaseClient.from("favorites")
                .select {
                    filter {
                        eq("profile_id", userId)
                    }
                }
                .decodeList<FavoriteEntry>()

            val ids = favorites.map { it.postId }.toSet()
            _favoritesCache.value = ids
            ids
        }
    }

    override suspend fun addFavorite(postId: Int): Result<Unit> {
        return runCatching {
            val userId = getCurrentUserId()

            val entry = FavoriteEntry(
                profileId = userId,
                postId = postId
            )

            supabaseClient.from("favorites")
                .upsert(entry)

            // Update local cache
            _favoritesCache.value = _favoritesCache.value + postId
        }
    }

    override suspend fun removeFavorite(postId: Int): Result<Unit> {
        return runCatching {
            val userId = getCurrentUserId()

            supabaseClient.from("favorites")
                .delete {
                    filter {
                        eq("profile_id", userId)
                        eq("post_id", postId)
                    }
                }

            // Update local cache
            _favoritesCache.value = _favoritesCache.value - postId
        }
    }

    override suspend fun toggleFavorite(postId: Int): Result<Boolean> {
        return runCatching {
            val isFavorite = _favoritesCache.value.contains(postId)

            if (isFavorite) {
                removeFavorite(postId).getOrThrow()
                false
            } else {
                addFavorite(postId).getOrThrow()
                true
            }
        }
    }

    override suspend fun isFavorite(postId: Int): Result<Boolean> {
        // First check cache
        if (_favoritesCache.value.contains(postId)) {
            return Result.success(true)
        }

        // If cache is empty, fetch from server
        return runCatching {
            val userId = getCurrentUserId()

            val count = supabaseClient.from("favorites")
                .select {
                    filter {
                        eq("profile_id", userId)
                        eq("post_id", postId)
                    }
                }
                .decodeList<FavoriteEntry>()

            count.isNotEmpty()
        }
    }

    override fun observeFavorites(): Flow<Set<Int>> = flow {
        // Emit current cache
        emit(_favoritesCache.value)

        // Fetch fresh data
        getFavorites()
            .onSuccess { emit(it) }

        // Subscribe to realtime changes
        try {
            val userId = getCurrentUserId()
            val channel = supabaseClient.channel("favorites-$userId")

            // Note: In supabase-kt 3.x, row-level filtering is set at channel level
            val insertFlow = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
                table = "favorites"
            }

            val deleteFlow = channel.postgresChangeFlow<PostgresAction.Delete>(schema = "public") {
                table = "favorites"
            }

            channel.subscribe()

            // Collect changes and update
            kotlinx.coroutines.flow.merge(insertFlow, deleteFlow).collect {
                getFavorites().onSuccess { favorites ->
                    emit(favorites)
                }
            }
        } catch (e: Exception) {
            // Realtime subscription failed, just use cache
            emit(_favoritesCache.value)
        }
    }

    private fun getCurrentUserId(): String {
        return supabaseClient.auth.currentUserOrNull()?.id
            ?: throw IllegalStateException("User not authenticated")
    }

    override suspend fun batchToggleFavorites(
        operations: List<BatchFavoriteOperation>
    ): Result<BatchFavoriteResult> {
        return runCatching {
            val userId = getCurrentUserId()

            if (operations.isEmpty()) {
                return@runCatching BatchFavoriteResult(
                    success = true,
                    results = emptyList(),
                    processed = 0
                )
            }

            if (operations.size > MAX_BATCH_SIZE) {
                throw IllegalArgumentException("Maximum $MAX_BATCH_SIZE operations per batch")
            }

            // Build JSONB operations array
            val operationsJson = buildJsonArray {
                for (op in operations) {
                    add(buildJsonObject {
                        put("post_id", op.postId)
                        put("action", op.action.name.lowercase())
                        put("correlation_id", op.correlationId)
                    })
                }
            }

            // Call the batch RPC
            val params = mapOf(
                "p_user_id" to userId,
                "p_operations" to operationsJson
            )

            val response = supabaseClient.postgrest.rpc(
                "batch_toggle_favorites",
                params
            ).decodeAs<JsonObject>()

            val success = response["success"]?.jsonPrimitive?.boolean ?: false
            val error = response["error"]?.jsonPrimitive?.content
            val processed = response["processed"]?.jsonPrimitive?.int ?: 0
            val resultsArray = response["results"]?.jsonArray ?: JsonArray(emptyList())

            val results = resultsArray.map { element ->
                val obj = element.jsonObject
                val opPostId = obj["post_id"]?.jsonPrimitive?.int ?: 0
                val opSuccess = obj["success"]?.jsonPrimitive?.boolean ?: false
                val isFavorited = obj["is_favorited"]?.jsonPrimitive?.boolean ?: false
                val likeCount = obj["like_count"]?.jsonPrimitive?.int ?: 0
                val opError = obj["error"]?.jsonPrimitive?.content
                val correlationId = obj["correlation_id"]?.jsonPrimitive?.content ?: ""

                // Update local cache
                if (opSuccess) {
                    _favoritesCache.value = if (isFavorited) {
                        _favoritesCache.value + opPostId
                    } else {
                        _favoritesCache.value - opPostId
                    }
                }

                BatchFavoriteOperationResult(
                    postId = opPostId,
                    correlationId = correlationId,
                    success = opSuccess,
                    isFavorited = isFavorited,
                    likeCount = likeCount,
                    error = opError
                )
            }

            BatchFavoriteResult(
                success = success,
                results = results,
                processed = processed,
                error = error
            )
        }
    }

    override suspend fun getFavoritesStatus(postIds: List<Int>): Result<Map<Int, FavoriteStatus>> {
        return runCatching {
            val userId = getCurrentUserId()

            if (postIds.isEmpty()) {
                return@runCatching emptyMap()
            }

            val params = mapOf(
                "p_user_id" to userId,
                "p_post_ids" to postIds.toTypedArray()
            )

            val response = supabaseClient.postgrest.rpc(
                "get_favorites_status",
                params
            ).decodeAs<JsonObject>()

            val success = response["success"]?.jsonPrimitive?.boolean ?: false

            if (!success) {
                throw IllegalStateException(
                    response["error"]?.jsonPrimitive?.content ?: "Failed to get favorites status"
                )
            }

            val statusesArray = response["statuses"]?.jsonArray ?: JsonArray(emptyList())

            statusesArray.associate { element ->
                val obj = element.jsonObject
                val postId = obj["post_id"]?.jsonPrimitive?.int ?: 0
                val isFavorited = obj["is_favorited"]?.jsonPrimitive?.boolean ?: false
                val likeCount = obj["like_count"]?.jsonPrimitive?.int ?: 0

                postId to FavoriteStatus(
                    isFavorited = isFavorited,
                    likeCount = likeCount
                )
            }
        }
    }

    companion object {
        private const val MAX_BATCH_SIZE = 50
    }
}

/**
 * Database entry for favorites table
 */
@Serializable
private data class FavoriteEntry(
    @SerialName("profile_id") val profileId: String,
    @SerialName("post_id") val postId: Int
)
