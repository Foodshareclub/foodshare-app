package com.foodshare.data.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Data Transfer Object for user profiles.
 *
 * Used for Supabase-kt serialization (maps to `profiles` table).
 * Converts to/from Swift UserProfile via generated bindings.
 */
@Serializable
data class UserProfileDto(
    val id: String,
    val email: String? = null,
    val nickname: String? = null,
    val bio: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val location: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("updated_at") val updatedAt: String? = null,
    @SerialName("items_shared") val itemsShared: Int? = null,
    @SerialName("items_received") val itemsReceived: Int? = null,
    @SerialName("rating_average") val ratingAverage: Double? = null,
    @SerialName("rating_count") val ratingCount: Int? = null
) {
    /**
     * Convert DTO to domain model.
     */
    fun toDomain(): com.foodshare.domain.model.UserProfile {
        return com.foodshare.domain.model.UserProfile(
            id = id,
            email = email,
            nickname = nickname,
            bio = bio,
            avatarUrl = avatarUrl,
            location = location,
            latitude = latitude,
            longitude = longitude,
            itemsShared = itemsShared,
            itemsReceived = itemsReceived,
            ratingAverage = ratingAverage,
            ratingCount = ratingCount
        )
    }

    companion object {
        /**
         * Create DTO from domain model.
         */
        fun fromDomain(profile: com.foodshare.domain.model.UserProfile): UserProfileDto {
            return UserProfileDto(
                id = profile.id,
                email = profile.email,
                nickname = profile.nickname,
                bio = profile.bio,
                avatarUrl = profile.avatarUrl,
                location = profile.location,
                latitude = profile.latitude,
                longitude = profile.longitude,
                itemsShared = profile.itemsShared,
                itemsReceived = profile.itemsReceived,
                ratingAverage = profile.ratingAverage,
                ratingCount = profile.ratingCount
            )
        }
    }
}

/**
 * DTO for profile update requests.
 */
@Serializable
data class UpdateProfileRequestDto(
    val nickname: String? = null,
    val bio: String? = null,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val location: String? = null,
    val latitude: Double? = null,
    val longitude: Double? = null
) {
    companion object {
        fun fromDomain(request: com.foodshare.domain.model.UpdateProfileRequest): UpdateProfileRequestDto {
            return UpdateProfileRequestDto(
                nickname = request.nickname,
                bio = request.bio,
                avatarUrl = request.avatarUrl,
                location = request.location,
                latitude = request.latitude,
                longitude = request.longitude
            )
        }
    }
}
