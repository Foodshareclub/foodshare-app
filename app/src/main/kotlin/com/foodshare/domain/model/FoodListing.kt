package com.foodshare.domain.model

import com.foodshare.swift.generated.DistanceFormatter as SwiftDistanceFormatter
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Food listing domain model
 *
 * Maps to `posts` table in Supabase
 *
 * Architecture (Frameo pattern):
 * - Uses swift-java generated DistanceFormatter for iOS/Android consistency
 * - Computed properties mirror Swift FoodListing for cross-platform parity
 */
@Serializable
data class FoodListing(
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
    @SerialName("post_views") val postViews: Int = 0,
    @SerialName("post_like_counter") val postLikeCounter: Int? = null,
    @SerialName("has_pantry") val hasPantry: Boolean? = null,
    @SerialName("food_status") val foodStatus: String? = null,
    val network: String? = null,
    val website: String? = null,
    val donation: String? = null,
    @SerialName("donation_rules") val donationRules: String? = null,
    @SerialName("category_id") val categoryId: Int? = null,
    @SerialName("distance_meters") val distanceMeters: Double? = null
) {
    // Computed properties
    val isAvailable: Boolean get() = isActive && !isArranged

    val distanceKm: Double? get() = distanceMeters?.let { it / 1000.0 }

    /** Format distance using Swift DistanceFormatter for iOS/Android consistency */
    val distanceDisplay: String?
        get() = distanceMeters?.let { meters ->
            SwiftDistanceFormatter.format(meters)
        }

    /** Format distance with "away" suffix using Swift formatter */
    val distanceDisplayWithSuffix: String?
        get() = distanceMeters?.let { meters ->
            SwiftDistanceFormatter.formatWithSuffix(meters)
        }

    val title: String get() = postName

    val description: String? get() = postDescription

    val displayImageUrl: String? get() = images?.firstOrNull()

    val status: ListingStatus
        get() = when {
            !isActive -> ListingStatus.INACTIVE
            isArranged -> ListingStatus.ARRANGED
            else -> ListingStatus.AVAILABLE
        }
}

/**
 * Listing status enum
 */
enum class ListingStatus {
    AVAILABLE,
    ARRANGED,
    INACTIVE;

    val displayName: String
        get() = when (this) {
            AVAILABLE -> "Available"
            ARRANGED -> "Arranged"
            INACTIVE -> "Inactive"
        }

    val isClaimable: Boolean get() = this == AVAILABLE

    val colorHex: String
        get() = when (this) {
            AVAILABLE -> "#2ECC71"
            ARRANGED -> "#F39C12"
            INACTIVE -> "#95A5A6"
        }
}

/**
 * Post types in the system
 */
enum class PostType(val displayName: String, val iconName: String) {
    FOOD("Food", "leaf.fill"),
    THING("Non-Food Item", "shippingbox.fill"),
    BORROW("Borrow", "arrow.triangle.2.circlepath"),
    WANTED("Wanted", "magnifyingglass"),
    FRIDGE("Community Fridge", "refrigerator.fill"),
    FOODBANK("Food Bank", "building.2.fill"),
    BUSINESS("Business", "storefront.fill"),
    VOLUNTEER("Volunteer", "person.2.fill"),
    CHALLENGE("Challenge", "trophy.fill"),
    ZEROWASTE("Zero Waste", "arrow.3.trianglepath"),
    VEGAN("Vegan", "carrot.fill"),
    COMMUNITY("Community Event", "person.3.fill");

    companion object {
        fun fromString(value: String): PostType? {
            return entries.find { it.name.equals(value, ignoreCase = true) }
        }
    }
}
