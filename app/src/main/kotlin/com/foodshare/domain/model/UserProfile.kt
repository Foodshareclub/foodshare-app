package com.foodshare.domain.model

import com.foodshare.core.validation.ValidationBridge
import com.foodshare.swift.generated.Coordinate as SwiftCoordinate
import com.foodshare.swift.generated.DistanceFormatter as SwiftDistanceFormatter
import com.foodshare.swift.generated.RelativeDateFormatter as SwiftRelativeDateFormatter
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import org.swift.swiftkit.core.SwiftArena

/**
 * User profile domain model
 *
 * Maps to `profiles` table in Supabase.
 *
 * Architecture (Frameo pattern):
 * - Uses swift-java generated formatters for iOS/Android consistency
 * - Computed properties mirror Swift UserProfile for cross-platform parity
 */
@Serializable
data class UserProfile(
    val id: String,
    val email: String? = null,
    val nickname: String? = null,
    val bio: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val location: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    @SerialName("items_shared") val itemsShared: Int? = null,
    @SerialName("items_received") val itemsReceived: Int? = null,
    @SerialName("rating_average") val ratingAverage: Double? = null,
    @SerialName("rating_count") val ratingCount: Int? = null,
    @SerialName("created_at") val createdAt: String? = null
) {
    val displayName: String
        get() = nickname ?: email?.substringBefore("@") ?: "User"

    val hasLocation: Boolean
        get() = latitude != null && longitude != null

    /**
     * Validate coordinates using Swift validation (matches iOS).
     */
    val hasValidLocation: Boolean
        get() = latitude != null && longitude != null &&
                ValidationBridge.isValidCoordinate(latitude, longitude)

    val formattedRating: String?
        get() = ratingAverage?.let { String.format("%.1f", it) }

    /**
     * Member since relative time using Swift formatter (matches iOS).
     */
    val memberSinceRelative: String?
        get() = createdAt?.let { SwiftRelativeDateFormatter.format(it) }

    /**
     * Member since short format using Swift formatter.
     */
    val memberSinceFormatted: String?
        get() = createdAt?.let { SwiftRelativeDateFormatter.formatTime(it) }

    /**
     * Calculate distance from this user to a location using Swift.
     */
    fun distanceFromUser(targetLat: Double, targetLon: Double): String? {
        val lat = latitude ?: return null
        val lon = longitude ?: return null
        if (!ValidationBridge.isValidCoordinate(targetLat, targetLon)) return null

        val arena = SwiftArena.ofAuto()
        val userCoord = SwiftCoordinate.init(lat, lon, arena)
        val targetCoord = SwiftCoordinate.init(targetLat, targetLon, arena)
        val distanceMeters = userCoord.distanceMeters(targetCoord)
        return SwiftDistanceFormatter.formatWithSuffix(distanceMeters)
    }

    /**
     * Rating with count formatted for display.
     */
    val ratingWithCount: String
        get() = ratingAverage?.let { avg ->
            val count = ratingCount ?: 0
            String.format("%.1f (%d)", avg, count)
        } ?: "No reviews"

    /**
     * Stats summary for display.
     */
    val statsSummary: String
        get() {
            val shared = itemsShared ?: 0
            val received = itemsReceived ?: 0
            return "$shared shared, $received received"
        }
}

/**
 * Request to update user profile
 */
@Serializable
data class UpdateProfileRequest(
    val nickname: String? = null,
    val bio: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val location: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null
)
