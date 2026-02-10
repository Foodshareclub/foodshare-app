@file:Suppress("unused")

package com.foodshare.domain.model

/**
 * Type aliases for cross-platform Swift integration.
 *
 * TRANSITION STRATEGY:
 * Currently these alias to Kotlin domain models for compatibility.
 * When Swift bindings are generated and verified, change these to:
 *
 * ```kotlin
 * typealias SwiftFoodListing = com.foodshare.swift.FoodListing
 * typealias SwiftUserProfile = com.foodshare.swift.UserProfile
 * typealias SwiftCategory = com.foodshare.swift.Category
 * typealias SwiftCoordinate = com.foodshare.swift.Coordinate
 * ```
 *
 * This allows gradual migration without breaking existing code.
 */

// ============================================================================
// Swift Type Aliases (currently pointing to Kotlin fallbacks)
// ============================================================================

/**
 * Food listing from Swift FoodshareCore.
 * Currently aliases to Kotlin FoodListing.
 */
typealias SwiftFoodListing = FoodListing

/**
 * User profile from Swift FoodshareCore.
 * Currently aliases to Kotlin UserProfile.
 */
typealias SwiftUserProfile = UserProfile

/**
 * Category from Swift FoodshareCore.
 * Currently aliases to Kotlin Category.
 */
typealias SwiftCategory = Category

/**
 * Listing status from Swift FoodshareCore.
 * Currently aliases to Kotlin ListingStatus.
 */
typealias SwiftListingStatus = ListingStatus

/**
 * Post type from Swift FoodshareCore.
 * Currently aliases to Kotlin PostType.
 */
typealias SwiftPostType = PostType

// ============================================================================
// Coordinate (Platform-agnostic location type from Swift)
// ============================================================================

/**
 * Platform-agnostic coordinate type.
 *
 * This replaces direct usage of Pair<Double, Double> for locations.
 * Mirrors Swift FoodshareCore.Coordinate.
 */
data class Coordinate(
    val latitude: Double,
    val longitude: Double
) {
    /**
     * Calculate distance to another coordinate in kilometers.
     * Uses Haversine formula.
     */
    fun distanceTo(other: Coordinate): Double {
        return com.foodshare.core.utilities.DistanceCalculator.distanceKm(
            fromLat = latitude,
            fromLon = longitude,
            toLat = other.latitude,
            toLon = other.longitude
        )
    }

    /**
     * Calculate distance to another coordinate in meters.
     */
    fun distanceMetersTo(other: Coordinate): Double {
        return distanceTo(other) * 1000.0
    }

    /**
     * Convert to Pair for compatibility with existing code.
     */
    fun toPair(): Pair<Double, Double> = latitude to longitude

    companion object {
        /**
         * Create from Pair for migration compatibility.
         */
        fun fromPair(pair: Pair<Double, Double>): Coordinate {
            return Coordinate(pair.first, pair.second)
        }

        /**
         * Create from nullable lat/lon, returns null if either is null.
         */
        fun fromNullable(latitude: Double?, longitude: Double?): Coordinate? {
            return if (latitude != null && longitude != null) {
                Coordinate(latitude, longitude)
            } else {
                null
            }
        }
    }
}

/**
 * Swift Coordinate alias.
 * Currently aliases to Kotlin Coordinate.
 */
typealias SwiftCoordinate = Coordinate
