package com.foodshare.domain.repository

import android.net.Uri
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.PostType

/**
 * Repository interface for creating and managing listings
 */
interface ListingRepository {

    /**
     * Create a new listing
     *
     * @param title Listing title
     * @param description Optional description
     * @param postType Type of post (FOOD, THING, etc.)
     * @param pickupTime When item can be picked up
     * @param address Pickup location address
     * @param latitude Optional latitude coordinate
     * @param longitude Optional longitude coordinate
     * @param imageUris List of local image URIs to upload
     * @return Result containing the created listing
     */
    suspend fun createListing(
        title: String,
        description: String?,
        postType: PostType,
        pickupTime: String?,
        address: String?,
        latitude: Double?,
        longitude: Double?,
        imageUris: List<Uri>
    ): Result<FoodListing>

    /**
     * Update an existing listing
     */
    suspend fun updateListing(
        listingId: Int,
        title: String? = null,
        description: String? = null,
        pickupTime: String? = null,
        address: String? = null,
        isActive: Boolean? = null
    ): Result<FoodListing>

    /**
     * Delete a listing
     */
    suspend fun deleteListing(listingId: Int): Result<Unit>

    /**
     * Mark listing as arranged (uses atomic RPC)
     *
     * @param listingId The listing ID
     * @param arrangedToUserId The user receiving the item
     * @param roomId Optional chat room ID to update
     * @return Result containing the arrangement details
     */
    suspend fun markAsArranged(
        listingId: Int,
        arrangedToUserId: String,
        roomId: String? = null
    ): Result<ArrangementResult>

    /**
     * Complete a transaction after food exchange (uses atomic RPC)
     *
     * Updates transaction status, user counts, and sends review prompts
     *
     * @param transactionId The transaction ID to complete
     * @param roomId Optional chat room ID to update
     * @return Result containing the completion details
     */
    suspend fun completeTransaction(
        transactionId: String,
        roomId: String? = null
    ): Result<TransactionCompletionResult>

    /**
     * Get transaction details
     */
    suspend fun getTransactionDetails(transactionId: String): Result<TransactionDetails>

    /**
     * Get listings created by the current user
     */
    suspend fun getMyListings(): Result<List<FoodListing>>

    /**
     * Create a new listing with auto-matching (uses atomic RPC)
     *
     * Creates the listing and finds matching food requests within radius.
     * Sends notifications to matched users automatically.
     *
     * @param title Listing title
     * @param description Optional description
     * @param postType Type of post
     * @param pickupTime When item can be picked up
     * @param address Pickup location address
     * @param latitude Latitude coordinate (required for matching)
     * @param longitude Longitude coordinate (required for matching)
     * @param imageUris List of local image URIs to upload
     * @param matchRadiusKm Radius for matching in kilometers (default 5km)
     * @return Result containing the created listing with match info
     */
    suspend fun createListingWithAutoMatch(
        title: String,
        description: String?,
        postType: PostType,
        pickupTime: String?,
        address: String?,
        latitude: Double,
        longitude: Double,
        imageUris: List<Uri>,
        matchRadiusKm: Double = 5.0
    ): Result<ListingCreationResult>

    /**
     * Get activity timeline events for a listing
     *
     * @param listingId The listing ID
     * @return Result containing the list of timeline events
     */
    suspend fun getListingTimeline(listingId: Int): Result<List<TimelineEvent>>
}

/**
 * Result from marking a listing as arranged
 */
data class ArrangementResult(
    val success: Boolean,
    val postId: Int,
    val transactionId: String?,
    val notificationSent: Boolean,
    val arrangedAt: String?,
    val error: String? = null
)

/**
 * Result from completing a transaction
 */
data class TransactionCompletionResult(
    val success: Boolean,
    val transactionId: String,
    val postId: Int,
    val giverId: String,
    val receiverId: String,
    val completedAt: String,
    val completedBy: String,
    val notificationsSent: Int,
    val error: String? = null
)

/**
 * Transaction details
 */
data class TransactionDetails(
    val transactionId: String,
    val postId: Int,
    val postName: String,
    val giverId: String,
    val receiverId: String,
    val status: String,
    val createdAt: String,
    val completedAt: String?,
    val canComplete: Boolean,
    val canReview: Boolean
)

/**
 * Result from creating a listing with auto-match
 */
data class ListingCreationResult(
    val listing: FoodListing,
    val matchInfo: MatchInfo
)

/**
 * Information about matches found when creating a listing
 */
data class MatchInfo(
    val matchCount: Int,
    val notificationsSent: Int,
    val radiusKm: Double
)

/**
 * Timeline event for listing activity
 */
data class TimelineEvent(
    val id: String,
    val type: TimelineEventType,
    val description: String,
    val timestamp: String,
    val count: Int? = null
)

/**
 * Timeline event types
 */
enum class TimelineEventType {
    CREATED,
    VIEWED,
    MESSAGED,
    ARRANGED,
    COMPLETED
}
