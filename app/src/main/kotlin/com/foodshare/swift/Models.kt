package com.foodshare.swift

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.Date
import java.util.UUID

/**
 * Kotlin representations of FoodshareCore Swift models.
 * These mirror the Swift types for seamless data exchange.
 */

// MARK: - Listing Status

@Serializable
enum class ListingStatus(val displayName: String, val hexColor: String) {
    @SerialName("available")
    AVAILABLE("Available", "#2ECC71"),
    
    @SerialName("arranged")
    ARRANGED("Arranged", "#F39C12"),
    
    @SerialName("inactive")
    INACTIVE("Inactive", "#95A5A6");
    
    val isClaimable: Boolean get() = this == AVAILABLE
}

// MARK: - Post Type

@Serializable
enum class PostType(val displayName: String, val iconName: String) {
    @SerialName("food")
    FOOD("Food", "leaf"),
    
    @SerialName("thing")
    THING("Non-Food Item", "inventory_2"),
    
    @SerialName("borrow")
    BORROW("Borrow", "swap_horiz"),
    
    @SerialName("wanted")
    WANTED("Wanted", "search"),
    
    @SerialName("fridge")
    FRIDGE("Community Fridge", "kitchen"),
    
    @SerialName("foodbank")
    FOODBANK("Food Bank", "store"),
    
    @SerialName("business")
    BUSINESS("Business", "storefront"),
    
    @SerialName("volunteer")
    VOLUNTEER("Volunteer", "group"),
    
    @SerialName("challenge")
    CHALLENGE("Challenge", "emoji_events"),
    
    @SerialName("zerowaste")
    ZEROWASTE("Zero Waste", "recycling"),
    
    @SerialName("vegan")
    VEGAN("Vegan", "eco"),
    
    @SerialName("community")
    COMMUNITY("Community Event", "groups")
}

// MARK: - Fridge Food Status

@Serializable
enum class FridgeFoodStatus(val displayName: String, val hexColor: String) {
    @SerialName("nearly empty")
    NEARLY_EMPTY("Nearly Empty", "#E74C3C"),
    
    @SerialName("room for more")
    ROOM_FOR_MORE("Room for More", "#F39C12"),
    
    @SerialName("pretty full")
    PRETTY_FULL("Pretty Full", "#2ECC71"),
    
    @SerialName("overflowing")
    OVERFLOWING("Overflowing", "#3498DB")
}

// MARK: - Food Listing

/**
 * Represents a food listing in the system.
 * Maps to `posts` table in Supabase.
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
    @SerialName("created_at") val createdAt: String,
    @SerialName("updated_at") val updatedAt: String,
    @SerialName("distance_meters") val distanceMeters: Double? = null
) {
    // Computed properties
    val title: String get() = postName
    val description: String? get() = postDescription
    val displayImageUrl: String? get() = images?.firstOrNull()
    val isAvailable: Boolean get() = isActive && !isArranged
    
    val distanceKm: Double? get() = distanceMeters?.let { it / 1000.0 }
    
    val distanceDisplay: String? get() = distanceMeters?.let { meters ->
        if (meters < 1000) "${meters.toInt()}m"
        else String.format("%.1fkm", meters / 1000.0)
    }
    
    val status: ListingStatus get() = when {
        !isActive -> ListingStatus.INACTIVE
        isArranged -> ListingStatus.ARRANGED
        else -> ListingStatus.AVAILABLE
    }
}

// MARK: - Category

@Serializable
data class Category(
    val id: Int,
    val name: String,
    val description: String? = null,
    @SerialName("icon_url") val iconUrl: String? = null,
    val color: String = "#4CAF50",
    @SerialName("sort_order") val sortOrder: Int = 0,
    @SerialName("is_active") val isActive: Boolean = true,
    @SerialName("created_at") val createdAt: String
)

// MARK: - User Profile

@Serializable
data class UserProfile(
    val id: String,
    val nickname: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val bio: String? = null,
    @SerialName("about_me") val aboutMe: String? = null,
    @SerialName("rating_average") val ratingAverage: Double = 0.0,
    @SerialName("items_shared") val itemsShared: Int = 0,
    @SerialName("items_received") val itemsReceived: Int = 0,
    @SerialName("rating_count") val ratingCount: Int = 0,
    @SerialName("created_time") val createdTime: String,
    @SerialName("search_radius_km") val searchRadiusKm: Int? = null
) {
    val effectiveSearchRadius: Double get() = (searchRadiusKm ?: 5).toDouble()
}

// MARK: - Review

@Serializable
data class Review(
    val id: Int,
    @SerialName("profile_id") val profileId: String,
    @SerialName("post_id") val postId: Int? = null,
    @SerialName("forum_id") val forumId: Int? = null,
    @SerialName("challenge_id") val challengeId: Int? = null,
    @SerialName("reviewed_rating") val reviewedRating: Int,
    val feedback: String,
    val notes: String = "",
    @SerialName("created_at") val createdAt: String,
    @SerialName("profiles") val reviewer: ReviewerProfile? = null
) {
    val rating: Int get() = reviewedRating
}

@Serializable
data class ReviewerProfile(
    val id: String,
    val nickname: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    @SerialName("is_verified") val isVerified: Boolean = false
) {
    val displayName: String get() = nickname ?: "Anonymous"
}
