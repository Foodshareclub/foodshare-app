package com.foodshare.features.profile.data.repository

import com.foodshare.domain.repository.AuthRepository
import com.foodshare.features.profile.domain.repository.ProfileActionRepository
import com.foodshare.features.profile.presentation.ArrangementHistoryItem
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.first
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of ProfileActionRepository.
 *
 * Handles profile-related data operations including arrangement history,
 * newsletter preferences, and email preferences.
 */
@Singleton
class SupabaseProfileActionRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val authRepository: AuthRepository
) : ProfileActionRepository {

    override suspend fun getArrangementHistory(): Result<List<ArrangementHistoryItem>> {
        return runCatching {
            val currentUser = authRepository.currentUser.first()
                ?: throw IllegalStateException("User not authenticated")

            val userId = currentUser.id

            val arrangements = supabaseClient.from("arrangements")
                .select {
                    filter {
                        or {
                            eq("requester_id", userId)
                            eq("owner_id", userId)
                        }
                    }
                    order("created_at", Order.DESCENDING)
                }
                .decodeList<ArrangementHistoryDto>()

            arrangements.map { dto ->
                val isRequester = dto.requesterId == userId
                ArrangementHistoryItem(
                    id = dto.id,
                    listingTitle = dto.listingTitle ?: "Unknown Listing",
                    counterpartyName = if (isRequester) {
                        dto.ownerName ?: "Unknown User"
                    } else {
                        dto.requesterName ?: "Unknown User"
                    },
                    status = dto.status,
                    createdAt = dto.createdAt ?: "",
                    completedAt = dto.completedAt
                )
            }
        }
    }

    override suspend fun syncNewsletterPreferences(
        isSubscribed: Boolean,
        frequency: String,
        topics: List<String>
    ): Result<Unit> {
        return runCatching {
            val currentUser = authRepository.currentUser.first()
                ?: throw IllegalStateException("User not authenticated")

            val updateData = buildJsonObject {
                put("user_id", currentUser.id)
                put("newsletter_subscribed", isSubscribed)
                put("newsletter_frequency", frequency)
                putJsonArray("newsletter_topics") {
                    topics.forEach { topic ->
                        add(kotlinx.serialization.json.JsonPrimitive(topic))
                    }
                }
            }

            supabaseClient.from("newsletter_preferences")
                .upsert(updateData)
        }
    }

    override suspend fun syncEmailPreferences(
        marketingEnabled: Boolean,
        productUpdatesEnabled: Boolean,
        communityNotificationsEnabled: Boolean,
        foodAlertsEnabled: Boolean,
        weeklyDigestEnabled: Boolean
    ): Result<Unit> {
        return runCatching {
            val currentUser = authRepository.currentUser.first()
                ?: throw IllegalStateException("User not authenticated")

            val updateData = buildJsonObject {
                put("user_id", currentUser.id)
                put("marketing_enabled", marketingEnabled)
                put("product_updates_enabled", productUpdatesEnabled)
                put("community_notifications_enabled", communityNotificationsEnabled)
                put("food_alerts_enabled", foodAlertsEnabled)
                put("weekly_digest_enabled", weeklyDigestEnabled)
            }

            supabaseClient.from("email_preferences")
                .upsert(updateData)
        }
    }
}

/**
 * Internal DTO for decoding arrangement rows from Supabase.
 */
@Serializable
private data class ArrangementHistoryDto(
    val id: String,
    @SerialName("requester_id") val requesterId: String,
    @SerialName("owner_id") val ownerId: String,
    val status: String,
    @SerialName("created_at") val createdAt: String? = null,
    @SerialName("completed_at") val completedAt: String? = null,
    @SerialName("listing_title") val listingTitle: String? = null,
    @SerialName("requester_name") val requesterName: String? = null,
    @SerialName("owner_name") val ownerName: String? = null
)
