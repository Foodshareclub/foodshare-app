package com.foodshare.domain.repository

import com.foodshare.domain.model.Category
import com.foodshare.domain.model.FoodListing
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for feed data operations
 *
 * Matches iOS: FoodItemRepository, FeedRepository
 */
interface FeedRepository {

    /**
     * Fetch nearby food listings
     */
    suspend fun getNearbyListings(
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 5.0,
        limit: Int = 20,
        offset: Int = 0,
        postType: String? = null,
        categoryId: Int? = null
    ): Result<List<FoodListing>>

    /**
     * Fetch listing by ID
     */
    suspend fun getListingById(id: Int): Result<FoodListing>

    /**
     * Fetch all categories
     */
    suspend fun getCategories(): Result<List<Category>>

    /**
     * Observe listings as a Flow
     */
    fun observeNearbyListings(
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 5.0
    ): Flow<List<FoodListing>>
}
