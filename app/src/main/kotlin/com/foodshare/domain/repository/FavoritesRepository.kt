package com.foodshare.domain.repository

import kotlinx.coroutines.flow.Flow

/**
 * Repository for managing user favorites
 *
 * Persists favorites to Supabase `favorites` table
 */
interface FavoritesRepository {

    /**
     * Get all favorite post IDs for current user
     */
    suspend fun getFavorites(): Result<Set<Int>>

    /**
     * Add a post to favorites
     */
    suspend fun addFavorite(postId: Int): Result<Unit>

    /**
     * Remove a post from favorites
     */
    suspend fun removeFavorite(postId: Int): Result<Unit>

    /**
     * Toggle favorite status
     *
     * @return true if now favorited, false if removed
     */
    suspend fun toggleFavorite(postId: Int): Result<Boolean>

    /**
     * Check if post is favorited
     */
    suspend fun isFavorite(postId: Int): Result<Boolean>

    /**
     * Observe favorites as a Flow
     */
    fun observeFavorites(): Flow<Set<Int>>

    /**
     * Batch toggle favorites for efficient offline sync
     *
     * Uses atomic RPC for transactional consistency
     *
     * @param operations List of batch operations to perform
     * @return Result containing individual results for each operation
     */
    suspend fun batchToggleFavorites(
        operations: List<BatchFavoriteOperation>
    ): Result<BatchFavoriteResult>

    /**
     * Get favorite status for multiple posts
     *
     * @param postIds List of post IDs to check
     * @return Map of post ID to favorite status with like count
     */
    suspend fun getFavoritesStatus(postIds: List<Int>): Result<Map<Int, FavoriteStatus>>
}

/**
 * Action for batch favorite operation
 */
enum class FavoriteAction {
    ADD,
    REMOVE,
    TOGGLE
}

/**
 * Single operation in a batch favorites request
 */
data class BatchFavoriteOperation(
    val postId: Int,
    val action: FavoriteAction,
    val correlationId: String = java.util.UUID.randomUUID().toString()
)

/**
 * Result of a single batch operation
 */
data class BatchFavoriteOperationResult(
    val postId: Int,
    val correlationId: String,
    val success: Boolean,
    val isFavorited: Boolean,
    val likeCount: Int,
    val error: String? = null
)

/**
 * Overall result of batch favorites operation
 */
data class BatchFavoriteResult(
    val success: Boolean,
    val results: List<BatchFavoriteOperationResult>,
    val processed: Int,
    val error: String? = null
)

/**
 * Favorite status for a post
 */
data class FavoriteStatus(
    val isFavorited: Boolean,
    val likeCount: Int
)
