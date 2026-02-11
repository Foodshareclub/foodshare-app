package com.foodshare.data.repository

import android.content.Context
import android.net.Uri
import com.foodshare.data.dto.FoodListingDto
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.PostType
import com.foodshare.domain.repository.ArrangementResult
import com.foodshare.domain.repository.ListingCreationResult
import com.foodshare.domain.repository.ListingRepository
import com.foodshare.domain.repository.MatchInfo
import com.foodshare.domain.repository.TransactionCompletionResult
import com.foodshare.domain.repository.TransactionDetails
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.rpc
import io.github.jan.supabase.storage.storage
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.double
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of ListingRepository
 *
 * Handles:
 * - Image upload to Supabase Storage (posts bucket)
 * - Post creation in the posts table
 * - Post management operations
 */
@Singleton
class SupabaseListingRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    @ApplicationContext private val context: Context
) : ListingRepository {

    private val storageBucket = "posts"

    override suspend fun createListing(
        title: String,
        description: String?,
        postType: PostType,
        pickupTime: String?,
        address: String?,
        latitude: Double?,
        longitude: Double?,
        imageUris: List<Uri>
    ): Result<FoodListing> {
        return runCatching {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            // 1. Upload images to Storage
            val imageUrls = uploadImages(userId, imageUris)

            // 2. Create the post
            val createRequest = CreatePostRequest(
                profileId = userId,
                postName = title,
                postDescription = description,
                postType = postType.name.lowercase(),
                pickupTime = pickupTime,
                postAddress = address,
                latitude = latitude,
                longitude = longitude,
                images = imageUrls.ifEmpty { null }
            )

            supabaseClient.from("posts")
                .insert(createRequest) {
                    select()
                }
                .decodeSingle<FoodListingDto>()
                .toDomain()
        }
    }

    override suspend fun updateListing(
        listingId: Int,
        title: String?,
        description: String?,
        pickupTime: String?,
        address: String?,
        isActive: Boolean?
    ): Result<FoodListing> {
        return runCatching {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            val updateRequest = UpdatePostRequest(
                postName = title,
                postDescription = description,
                pickupTime = pickupTime,
                postAddress = address,
                isActive = isActive
            )

            supabaseClient.from("posts")
                .update(updateRequest) {
                    select()
                    filter {
                        eq("id", listingId)
                        eq("profile_id", userId)
                    }
                }
                .decodeSingle<FoodListingDto>()
                .toDomain()
        }
    }

    override suspend fun deleteListing(listingId: Int): Result<Unit> {
        return runCatching {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            // Soft delete by setting is_active to false
            supabaseClient.from("posts")
                .update(mapOf("is_active" to false)) {
                    filter {
                        eq("id", listingId)
                        eq("profile_id", userId)
                    }
                }
        }
    }

    private val json = Json { ignoreUnknownKeys = true }

    override suspend fun markAsArranged(
        listingId: Int,
        arrangedToUserId: String,
        roomId: String?
    ): Result<ArrangementResult> {
        return runCatching {
            // Use atomic RPC function
            val params = buildMap {
                put("p_post_id", listingId)
                put("p_receiver_id", arrangedToUserId)
                roomId?.let { put("p_room_id", it) }
            }

            val response = supabaseClient.postgrest.rpc(
                "mark_listing_arranged",
                params
            ).decodeAs<JsonObject>()

            val success = response["success"]?.jsonPrimitive?.boolean ?: false

            ArrangementResult(
                success = success,
                postId = response["post_id"]?.jsonPrimitive?.int ?: listingId,
                transactionId = response["transaction_id"]?.jsonPrimitive?.content,
                notificationSent = response["notification_sent"]?.jsonPrimitive?.boolean ?: false,
                arrangedAt = response["arranged_at"]?.jsonPrimitive?.content,
                error = if (!success) response["error"]?.jsonPrimitive?.content else null
            )
        }
    }

    override suspend fun completeTransaction(
        transactionId: String,
        roomId: String?
    ): Result<TransactionCompletionResult> {
        return runCatching {
            // Use atomic RPC function
            val params = buildMap {
                put("p_transaction_id", transactionId)
                roomId?.let { put("p_room_id", it) }
            }

            val response = supabaseClient.postgrest.rpc(
                "complete_transaction_with_notifications",
                params
            ).decodeAs<JsonObject>()

            val success = response["success"]?.jsonPrimitive?.boolean ?: false

            if (!success) {
                throw IllegalStateException(
                    response["error"]?.jsonPrimitive?.content ?: "Failed to complete transaction"
                )
            }

            TransactionCompletionResult(
                success = true,
                transactionId = response["transaction_id"]?.jsonPrimitive?.content ?: transactionId,
                postId = response["post_id"]?.jsonPrimitive?.int ?: 0,
                giverId = response["giver_id"]?.jsonPrimitive?.content ?: "",
                receiverId = response["receiver_id"]?.jsonPrimitive?.content ?: "",
                completedAt = response["completed_at"]?.jsonPrimitive?.content ?: "",
                completedBy = response["completed_by"]?.jsonPrimitive?.content ?: "",
                notificationsSent = response["notifications_sent"]?.jsonPrimitive?.int ?: 0
            )
        }
    }

    override suspend fun getTransactionDetails(transactionId: String): Result<TransactionDetails> {
        return runCatching {
            val params = mapOf("p_transaction_id" to transactionId)

            val response = supabaseClient.postgrest.rpc(
                "get_transaction_details",
                params
            ).decodeAs<JsonObject>()

            val success = response["success"]?.jsonPrimitive?.boolean ?: false

            if (!success) {
                throw IllegalStateException(
                    response["error"]?.jsonPrimitive?.content ?: "Transaction not found"
                )
            }

            val transaction = response["transaction"] as? JsonObject
                ?: throw IllegalStateException("Invalid transaction data")

            TransactionDetails(
                transactionId = transaction["transaction_id"]?.jsonPrimitive?.content ?: transactionId,
                postId = transaction["post_id"]?.jsonPrimitive?.int ?: 0,
                postName = transaction["post_name"]?.jsonPrimitive?.content ?: "",
                giverId = transaction["giver_id"]?.jsonPrimitive?.content ?: "",
                receiverId = transaction["receiver_id"]?.jsonPrimitive?.content ?: "",
                status = transaction["status"]?.jsonPrimitive?.content ?: "",
                createdAt = transaction["created_at"]?.jsonPrimitive?.content ?: "",
                completedAt = transaction["completed_at"]?.jsonPrimitive?.content,
                canComplete = transaction["can_complete"]?.jsonPrimitive?.boolean ?: false,
                canReview = transaction["can_review"]?.jsonPrimitive?.boolean ?: false
            )
        }
    }

    override suspend fun getMyListings(): Result<List<FoodListing>> {
        return runCatching {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            supabaseClient.from("posts")
                .select {
                    filter {
                        eq("profile_id", userId)
                    }
                    order("created_at", Order.DESCENDING)
                }
                .decodeList<FoodListingDto>()
                .map { it.toDomain() }
        }
    }

    override suspend fun createListingWithAutoMatch(
        title: String,
        description: String?,
        postType: PostType,
        pickupTime: String?,
        address: String?,
        latitude: Double,
        longitude: Double,
        imageUris: List<Uri>,
        matchRadiusKm: Double
    ): Result<ListingCreationResult> {
        return runCatching {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            // 1. Upload images first
            val imageUrls = uploadImages(userId, imageUris)

            // 2. Call the atomic RPC
            val params = mapOf(
                "p_profile_id" to userId,
                "p_post_name" to title,
                "p_post_description" to description,
                "p_post_type" to postType.name.lowercase(),
                "p_pickup_time" to pickupTime,
                "p_post_address" to address,
                "p_latitude" to latitude,
                "p_longitude" to longitude,
                "p_images" to imageUrls.ifEmpty { null },
                "p_match_radius_km" to matchRadiusKm
            )

            val response = supabaseClient.postgrest.rpc(
                "create_listing_with_auto_match",
                params
            ).decodeAs<JsonObject>()

            val success = response["success"]?.jsonPrimitive?.boolean ?: false

            if (!success) {
                throw IllegalStateException(
                    response["error"]?.jsonPrimitive?.content ?: "Failed to create listing"
                )
            }

            // Parse the post from response
            val postJson = response["post"]?.jsonObject
                ?: throw IllegalStateException("No post in response")

            val listing = FoodListing(
                id = postJson["id"]?.jsonPrimitive?.int ?: 0,
                profileId = postJson["profile_id"]?.jsonPrimitive?.content ?: userId,
                postName = postJson["post_name"]?.jsonPrimitive?.content ?: title,
                postDescription = postJson["post_description"]?.jsonPrimitive?.content,
                postType = postType.name.lowercase(),
                postAddress = postJson["post_address"]?.jsonPrimitive?.content,
                latitude = postJson["latitude"]?.jsonPrimitive?.doubleOrNull,
                longitude = postJson["longitude"]?.jsonPrimitive?.doubleOrNull,
                images = imageUrls,
                isActive = postJson["is_active"]?.jsonPrimitive?.boolean ?: true,
                isArranged = false,
                distanceMeters = null
            )

            // Parse match info
            val matchesJson = response["matches"]?.jsonObject
            val matchInfo = MatchInfo(
                matchCount = matchesJson?.get("count")?.jsonPrimitive?.int ?: 0,
                notificationsSent = matchesJson?.get("notifications_sent")?.jsonPrimitive?.int ?: 0,
                radiusKm = matchesJson?.get("radius_km")?.jsonPrimitive?.double ?: matchRadiusKm
            )

            ListingCreationResult(
                listing = listing,
                matchInfo = matchInfo
            )
        }
    }

    /**
     * Upload images to Supabase Storage
     *
     * @param userId User ID for folder organization
     * @param imageUris Local URIs of images to upload
     * @return List of public URLs for uploaded images
     */
    private suspend fun uploadImages(userId: String, imageUris: List<Uri>): List<String> {
        if (imageUris.isEmpty()) return emptyList()

        val bucket = supabaseClient.storage.from(storageBucket)
        val uploadedUrls = mutableListOf<String>()

        for (uri in imageUris) {
            try {
                // Read image bytes from content URI
                val bytes = context.contentResolver.openInputStream(uri)?.use {
                    it.readBytes()
                } ?: continue

                // Generate unique filename
                val uuid = UUID.randomUUID().toString()
                val extension = getExtensionFromUri(uri) ?: "jpg"
                val path = "$userId/$uuid.$extension"

                // Upload to Storage
                bucket.upload(path, bytes) {
                    upsert = false
                }

                // Get public URL
                val publicUrl = bucket.publicUrl(path)
                uploadedUrls.add(publicUrl)

            } catch (e: Exception) {
                // Log but continue with other images
                e.printStackTrace()
            }
        }

        return uploadedUrls
    }

    /**
     * Get file extension from content URI
     */
    private fun getExtensionFromUri(uri: Uri): String? {
        val mimeType = context.contentResolver.getType(uri) ?: return null
        return when {
            mimeType.contains("jpeg") || mimeType.contains("jpg") -> "jpg"
            mimeType.contains("png") -> "png"
            mimeType.contains("webp") -> "webp"
            mimeType.contains("heic") -> "heic"
            else -> "jpg"
        }
    }

    override suspend fun getListingTimeline(listingId: Int): Result<List<com.foodshare.domain.repository.TimelineEvent>> = runCatching {
        supabaseClient.postgrest["listing_activity_timeline"]
            .select {
                filter { eq("listing_id", listingId) }
                order("timestamp", Order.DESCENDING)
            }
            .decodeList<TimelineEventDto>()
            .map { it.toDomain() }
    }
}

/**
 * Request body for creating a new post
 */
@Serializable
private data class CreatePostRequest(
    @SerialName("profile_id") val profileId: String,
    @SerialName("post_name") val postName: String,
    @SerialName("post_description") val postDescription: String? = null,
    @SerialName("post_type") val postType: String,
    @SerialName("pickup_time") val pickupTime: String? = null,
    @SerialName("post_address") val postAddress: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val images: List<String>? = null
)

/**
 * Request body for updating a post
 */
@Serializable
private data class UpdatePostRequest(
    @SerialName("post_name") val postName: String? = null,
    @SerialName("post_description") val postDescription: String? = null,
    @SerialName("pickup_time") val pickupTime: String? = null,
    @SerialName("post_address") val postAddress: String? = null,
    @SerialName("is_active") val isActive: Boolean? = null
)

/**
 * DTO for timeline events
 */
@Serializable
private data class TimelineEventDto(
    val id: String,
    @SerialName("listing_id") val listingId: Int,
    @SerialName("event_type") val eventType: String,
    val description: String,
    val timestamp: String,
    val count: Int? = null
) {
    fun toDomain() = com.foodshare.domain.repository.TimelineEvent(
        id = id,
        type = when (eventType.lowercase()) {
            "created" -> com.foodshare.domain.repository.TimelineEventType.CREATED
            "viewed" -> com.foodshare.domain.repository.TimelineEventType.VIEWED
            "messaged" -> com.foodshare.domain.repository.TimelineEventType.MESSAGED
            "arranged" -> com.foodshare.domain.repository.TimelineEventType.ARRANGED
            "completed" -> com.foodshare.domain.repository.TimelineEventType.COMPLETED
            else -> com.foodshare.domain.repository.TimelineEventType.CREATED
        },
        description = description,
        timestamp = timestamp,
        count = count
    )
}
