package com.foodshare.core.transformation

import com.foodshare.domain.model.ChatMessage
import com.foodshare.domain.model.FoodListing
import com.foodshare.domain.model.Review
import com.foodshare.domain.model.UserProfile
import kotlinx.serialization.json.Json

/**
 * Bridge for JSON-to-domain model transformations.
 *
 * Architecture (Frameo pattern):
 * - Domain models have computed properties that call swift-java generated classes
 * - DistanceFormatter, RelativeDateFormatter provide iOS/Android consistency
 * - This bridge deserializes JSON; computed properties are evaluated on access
 *
 * Benefits:
 * - 100% identical transformation logic across platforms via swift-java
 * - Computed properties call Swift via generated bindings
 * - No manual JNI code required
 */
object TransformationBridge {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
        encodeDefaults = true
    }

    /**
     * Transform a FoodListing DTO to domain model.
     *
     * Computed properties (evaluated on access via swift-java):
     * - distanceDisplay: formatted distance string ("500m", "1.2km")
     * - distanceKm: distance in kilometers
     * - isAvailable: availability status
     * - displayImageUrl: primary image URL
     * - status: listing status enum
     *
     * @param listingJson Raw JSON from Supabase
     * @return FoodListing with computed properties available on access
     */
    fun transformListing(listingJson: String): FoodListing {
        return try {
            json.decodeFromString<FoodListing>(listingJson)
        } catch (e: Exception) {
            throw TransformationException("Failed to decode listing: ${e.message}", e)
        }
    }

    /**
     * Transform a UserProfile DTO to domain model.
     *
     * Computed properties (evaluated on access via swift-java):
     * - memberSinceRelative: relative time via RelativeDateFormatter
     * - memberSinceFormatted: formatted time via RelativeDateFormatter
     * - distanceFromUser: distance calculation via Coordinate + DistanceFormatter
     *
     * @param profileJson Raw JSON from Supabase
     * @return UserProfile with computed properties available on access
     */
    fun transformProfile(profileJson: String): UserProfile {
        return try {
            json.decodeFromString<UserProfile>(profileJson)
        } catch (e: Exception) {
            throw TransformationException("Failed to decode profile: ${e.message}", e)
        }
    }

    /**
     * Transform a ChatMessage DTO to domain model.
     *
     * Computed properties (evaluated on access via swift-java):
     * - relativeTime: relative time via RelativeDateFormatter
     * - formattedTime: formatted time via RelativeDateFormatter
     * - isRead: read status based on readAt
     *
     * @param messageJson Raw JSON from Supabase
     * @return ChatMessage with computed properties available on access
     */
    fun transformChatMessage(messageJson: String): ChatMessage {
        return try {
            json.decodeFromString<ChatMessage>(messageJson)
        } catch (e: Exception) {
            throw TransformationException("Failed to decode message: ${e.message}", e)
        }
    }

    /**
     * Transform a Review DTO to domain model.
     *
     * @param reviewJson Raw JSON from Supabase
     * @return Review domain model
     */
    fun transformReview(reviewJson: String): Review {
        return try {
            json.decodeFromString<Review>(reviewJson)
        } catch (e: Exception) {
            throw TransformationException("Failed to decode review: ${e.message}", e)
        }
    }

    /**
     * Batch transform multiple FoodListings.
     *
     * @param listingsJson JSON array of listings
     * @return List of FoodListings
     */
    fun transformListingBatch(listingsJson: String): List<FoodListing> {
        return try {
            json.decodeFromString<List<FoodListing>>(listingsJson)
        } catch (e: Exception) {
            throw TransformationException("Failed to decode listings batch: ${e.message}", e)
        }
    }

    /**
     * Batch transform multiple UserProfiles.
     *
     * @param profilesJson JSON array of profiles
     * @return List of UserProfiles
     */
    fun transformProfileBatch(profilesJson: String): List<UserProfile> {
        return try {
            json.decodeFromString<List<UserProfile>>(profilesJson)
        } catch (e: Exception) {
            throw TransformationException("Failed to decode profiles batch: ${e.message}", e)
        }
    }
}

/**
 * Exception thrown when DTO transformation fails.
 */
class TransformationException(
    message: String,
    cause: Throwable? = null
) : Exception(message, cause)
