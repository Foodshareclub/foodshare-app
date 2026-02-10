package com.foodshare.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Data Transfer Object for food listings.
 *
 * Used for Supabase-kt serialization (maps to `posts` table).
 * Converts to/from Swift FoodListing via generated bindings.
 */
@Serializable
data class FoodListingDto(
    val id: Int,
    @SerialName("profile_id") val profileId: String,
    @SerialName("post_name") val postName: String,
    @SerialName("post_description") val postDescription: String? = null,
    @SerialName("post_type") val postType: String,
    @SerialName("pickup_time") val pickupTime: String? = null,
    @SerialName("available_hours") val availableHours: String? = null,
    @SerialName("post_address") val postAddress: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    val images: List<String>? = null,
    @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("is_arranged") val isArranged: Boolean = false,
    @SerialName("post_arranged_to") val postArrangedTo: String? = null,
    @SerialName("post_arranged_at") val postArrangedAt: String? = null,
    @SerialName("post_views") val postViews: Int = 0,
    @SerialName("post_like_counter") val postLikeCounter: Int? = null,
    @SerialName("has_pantry") val hasPantry: Boolean? = null,
    @SerialName("food_status") val foodStatus: String? = null,
    val network: String? = null,
    val website: String? = null,
    val donation: String? = null,
    @SerialName("donation_rules") val donationRules: String? = null,
    @SerialName("category_id") val categoryId: Int? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("distance_meters") val distanceMeters: Double? = null
) {
    /**
     * Convert DTO to domain model.
     *
     * When Swift bindings are available, this converts to Swift FoodListing.
     * Falls back to Kotlin domain model if Swift runtime not available.
     */
    fun toDomain(): com.foodshare.domain.model.FoodListing {
        return com.foodshare.domain.model.FoodListing(
            id = id,
            profileId = profileId,
            postName = postName,
            postDescription = postDescription,
            postType = postType,
            pickupTime = pickupTime,
            availableHours = availableHours,
            postAddress = postAddress,
            latitude = latitude,
            longitude = longitude,
            images = images,
            isActive = isActive,
            isArranged = isArranged,
            postArrangedTo = postArrangedTo,
            postViews = postViews,
            postLikeCounter = postLikeCounter,
            hasPantry = hasPantry,
            foodStatus = foodStatus,
            network = network,
            website = website,
            donation = donation,
            donationRules = donationRules,
            categoryId = categoryId,
            distanceMeters = distanceMeters
        )
    }

    companion object {
        /**
         * Create DTO from domain model.
         */
        fun fromDomain(listing: com.foodshare.domain.model.FoodListing): FoodListingDto {
            return FoodListingDto(
                id = listing.id,
                profileId = listing.profileId,
                postName = listing.postName,
                postDescription = listing.postDescription,
                postType = listing.postType,
                pickupTime = listing.pickupTime,
                availableHours = listing.availableHours,
                postAddress = listing.postAddress,
                latitude = listing.latitude,
                longitude = listing.longitude,
                images = listing.images,
                isActive = listing.isActive,
                isArranged = listing.isArranged,
                postArrangedTo = listing.postArrangedTo,
                postViews = listing.postViews,
                postLikeCounter = listing.postLikeCounter,
                hasPantry = listing.hasPantry,
                foodStatus = listing.foodStatus,
                network = listing.network,
                website = listing.website,
                donation = listing.donation,
                donationRules = listing.donationRules,
                categoryId = listing.categoryId,
                distanceMeters = listing.distanceMeters
            )
        }
    }
}
