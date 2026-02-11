package com.foodshare.data.repository

import com.foodshare.data.dto.UserProfileDto
import com.foodshare.domain.model.ProfileStats
import com.foodshare.domain.model.UserProfile
import com.foodshare.domain.repository.ProfileRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.storage.storage
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of ProfileRepository
 *
 * Handles profile operations using supabase-kt
 */
@Singleton
class SupabaseProfileRepository @Inject constructor(
    private val supabaseClient: SupabaseClient
) : ProfileRepository {

    override val currentProfile: Flow<UserProfile?>
        get() = supabaseClient.auth.sessionStatus.map { status ->
            when (status) {
                is SessionStatus.Authenticated -> {
                    try {
                        fetchUserProfile(status.session.user?.id ?: return@map null)
                    } catch (e: Exception) {
                        null
                    }
                }
                else -> null
            }
        }

    override suspend fun getProfile(userId: String): Result<UserProfile> {
        return runCatching {
            fetchUserProfile(userId)
        }
    }

    override suspend fun updateProfile(
        nickname: String?,
        bio: String?,
        location: String?,
        avatarUrl: String?
    ): Result<UserProfile> {
        return runCatching {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            val updateData = buildJsonObject {
                nickname?.let { put("nickname", it) }
                bio?.let { put("bio", it) }
                location?.let { put("location", it) }
                avatarUrl?.let { put("avatar_url", it) }
            }

            supabaseClient.from("profiles")
                .update(updateData) {
                    filter { eq("id", userId) }
                }

            fetchUserProfile(userId)
        }
    }

    override suspend fun uploadAvatar(
        userId: String,
        imageBytes: ByteArray,
        mimeType: String
    ): Result<String> {
        return runCatching {
            val currentUserId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            if (currentUserId != userId) {
                throw IllegalArgumentException("Cannot upload avatar for another user")
            }

            // Generate unique filename
            val timestamp = System.currentTimeMillis()
            val extension = when (mimeType) {
                "image/jpeg", "image/jpg" -> "jpg"
                "image/png" -> "png"
                "image/webp" -> "webp"
                else -> "jpg"
            }
            val fileName = "$userId-$timestamp.$extension"
            val filePath = "avatars/$fileName"

            // Upload to storage
            supabaseClient.storage
                .from("avatars")
                .upload(filePath, imageBytes) {
                    contentType = io.ktor.http.ContentType.parse(mimeType)
                    upsert = true
                }

            // Get public URL
            val publicUrl = supabaseClient.storage
                .from("avatars")
                .publicUrl(filePath)

            publicUrl
        }
    }

    override suspend fun deleteAvatar(userId: String): Result<Unit> {
        return runCatching {
            val currentUserId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            if (currentUserId != userId) {
                throw IllegalArgumentException("Cannot delete avatar for another user")
            }

            // Get current avatar URL to extract path
            val profile = fetchUserProfile(userId)
            val avatarUrl = profile.avatarUrl ?: return@runCatching

            // Extract file path from URL
            val path = avatarUrl.substringAfter("avatars/")

            // Delete from storage
            supabaseClient.storage
                .from("avatars")
                .delete(listOf("avatars/$path"))

            // Update profile to remove avatar URL
            updateProfile(null, null, null, null)
        }
    }

    override suspend fun getStats(userId: String): Result<ProfileStats> {
        return runCatching {
            val profile = fetchUserProfile(userId)

            // For now, create stats from profile data
            // In future, this could query aggregated stats from separate table
            ProfileStats(
                itemsShared = profile.itemsShared ?: 0,
                itemsReceived = profile.itemsReceived ?: 0,
                ratingAverage = profile.ratingAverage,
                ratingCount = profile.ratingCount ?: 0,
                totalConversations = 0, // TODO: Query from chat_rooms
                challengesCompleted = 0, // TODO: Query from user_challenges
                forumPosts = 0, // TODO: Query from forum_posts
                foodSavedKg = 0.0 // TODO: Calculate from listings
            )
        }
    }

    private suspend fun fetchUserProfile(userId: String): UserProfile {
        return supabaseClient.from("profiles")
            .select {
                filter { eq("id", userId) }
            }
            .decodeSingle<UserProfileDto>()
            .toDomain()
    }
}
