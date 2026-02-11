package com.foodshare.core.push

import android.util.Log
import com.foodshare.core.network.EdgeFunctionClient
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Edge Function client for sending push notifications to other users.
 *
 * This service invokes the `send-push-notification` Edge Function to deliver
 * push notifications to specific users. It handles notification construction,
 * deep link generation, and batch sending.
 *
 * Common use cases:
 * - Notify a listing owner when someone requests their food
 * - Notify a user when they receive a new message
 * - Notify participants about arrangement updates
 * - Send challenge completion notifications
 *
 * SYNC: Uses `send-push-notification` Edge Function format
 */
@Singleton
class PushNotificationSender @Inject constructor(
    private val edgeFunctionClient: EdgeFunctionClient,
    private val supabaseClient: SupabaseClient
) {
    companion object {
        private const val TAG = "PushNotificationSender"
        private const val FUNCTION_NAME = "send-push-notification"

        // Notification type constants
        const val TYPE_MESSAGE = "message"
        const val TYPE_ARRANGEMENT = "arrangement"
        const val TYPE_LISTING = "listing"
        const val TYPE_REVIEW = "review"
        const val TYPE_CHALLENGE = "challenge"
        const val TYPE_SYSTEM = "system"
        const val TYPE_FORUM = "forum"
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    // ========================================================================
    // Single Notification
    // ========================================================================

    /**
     * Send a push notification to a specific user.
     *
     * @param recipientUserId The target user's ID
     * @param title Notification title
     * @param body Notification body text
     * @param type Notification type (used for categorization and channel routing)
     * @param deepLink Optional deep link URL for navigation on tap
     * @param data Optional additional data payload
     * @return Result indicating success or failure
     */
    suspend fun send(
        recipientUserId: String,
        title: String,
        body: String,
        type: String = TYPE_SYSTEM,
        deepLink: String? = null,
        data: Map<String, String> = emptyMap()
    ): Result<PushSendResult> {
        return runCatching {
            val senderId = supabaseClient.auth.currentUserOrNull()?.id

            val requestBody = buildJsonObject {
                put("user_id", recipientUserId)
                put("title", title)
                put("body", body)
                put("type", type)
                deepLink?.let { put("deep_link", it) }
                senderId?.let { put("sender_id", it) }
                if (data.isNotEmpty()) {
                    put("data", json.encodeToJsonElement(data))
                }
            }

            val result = edgeFunctionClient.invoke<PushSendResult>(
                functionName = FUNCTION_NAME
            ).getOrThrow()

            Log.d(TAG, "Push notification sent to user $recipientUserId: $title")
            result
        }
    }

    // ========================================================================
    // Typed Notification Helpers
    // ========================================================================

    /**
     * Send a new message notification.
     *
     * @param recipientUserId The recipient user's ID
     * @param senderName The sender's display name
     * @param messagePreview A preview of the message text (truncated)
     * @param conversationId The conversation/room ID for deep linking
     */
    suspend fun sendMessageNotification(
        recipientUserId: String,
        senderName: String,
        messagePreview: String,
        conversationId: String
    ): Result<PushSendResult> {
        return send(
            recipientUserId = recipientUserId,
            title = senderName,
            body = messagePreview.take(200),
            type = TYPE_MESSAGE,
            deepLink = "foodshare://conversation/$conversationId",
            data = mapOf("conversation_id" to conversationId)
        )
    }

    /**
     * Send an arrangement update notification.
     *
     * @param recipientUserId The recipient user's ID
     * @param listingTitle The title of the listing
     * @param status The new arrangement status
     * @param arrangementId The arrangement ID for deep linking
     */
    suspend fun sendArrangementNotification(
        recipientUserId: String,
        listingTitle: String,
        status: String,
        arrangementId: String
    ): Result<PushSendResult> {
        val body = when (status) {
            "requested" -> "Someone wants to pick up \"$listingTitle\""
            "confirmed" -> "Your request for \"$listingTitle\" has been confirmed"
            "completed" -> "Arrangement for \"$listingTitle\" is complete"
            "cancelled" -> "Arrangement for \"$listingTitle\" was cancelled"
            else -> "Update on \"$listingTitle\""
        }

        return send(
            recipientUserId = recipientUserId,
            title = "Arrangement Update",
            body = body,
            type = TYPE_ARRANGEMENT,
            deepLink = "foodshare://arrangement/$arrangementId",
            data = mapOf(
                "arrangement_id" to arrangementId,
                "status" to status
            )
        )
    }

    /**
     * Send a new listing notification (for users watching a category or area).
     *
     * @param recipientUserId The recipient user's ID
     * @param listingTitle The title of the new listing
     * @param listingId The listing ID for deep linking
     * @param distance Optional distance string (e.g., "0.5 km away")
     */
    suspend fun sendNewListingNotification(
        recipientUserId: String,
        listingTitle: String,
        listingId: Int,
        distance: String? = null
    ): Result<PushSendResult> {
        val body = if (distance != null) {
            "\"$listingTitle\" - $distance"
        } else {
            "\"$listingTitle\" is now available near you"
        }

        return send(
            recipientUserId = recipientUserId,
            title = "New Food Available",
            body = body,
            type = TYPE_LISTING,
            deepLink = "foodshare://listing/$listingId",
            data = mapOf("listing_id" to listingId.toString())
        )
    }

    /**
     * Send a review notification.
     *
     * @param recipientUserId The recipient user's ID
     * @param reviewerName The reviewer's display name
     * @param rating The rating given (1-5)
     */
    suspend fun sendReviewNotification(
        recipientUserId: String,
        reviewerName: String,
        rating: Int
    ): Result<PushSendResult> {
        val stars = "\u2B50".repeat(rating.coerceIn(1, 5))
        return send(
            recipientUserId = recipientUserId,
            title = "New Review",
            body = "$reviewerName left you a $stars review",
            type = TYPE_REVIEW,
            deepLink = "foodshare://reviews/$recipientUserId"
        )
    }

    /**
     * Send a challenge notification.
     *
     * @param recipientUserId The recipient user's ID
     * @param challengeTitle The challenge title
     * @param challengeId The challenge ID for deep linking
     * @param message Custom notification message
     */
    suspend fun sendChallengeNotification(
        recipientUserId: String,
        challengeTitle: String,
        challengeId: Int,
        message: String
    ): Result<PushSendResult> {
        return send(
            recipientUserId = recipientUserId,
            title = "Challenge: $challengeTitle",
            body = message,
            type = TYPE_CHALLENGE,
            deepLink = "foodshare://challenges/$challengeId",
            data = mapOf("challenge_id" to challengeId.toString())
        )
    }

    // ========================================================================
    // Batch Sending
    // ========================================================================

    /**
     * Send the same notification to multiple users.
     *
     * Sends notifications sequentially. Failures for individual recipients
     * do not prevent delivery to remaining recipients.
     *
     * @param recipientUserIds List of target user IDs
     * @param title Notification title
     * @param body Notification body text
     * @param type Notification type
     * @param deepLink Optional deep link URL
     * @param data Optional additional data payload
     * @return Map of user ID to send result
     */
    suspend fun sendToMultiple(
        recipientUserIds: List<String>,
        title: String,
        body: String,
        type: String = TYPE_SYSTEM,
        deepLink: String? = null,
        data: Map<String, String> = emptyMap()
    ): Map<String, Result<PushSendResult>> {
        val results = mutableMapOf<String, Result<PushSendResult>>()

        for (userId in recipientUserIds) {
            val result = send(
                recipientUserId = userId,
                title = title,
                body = body,
                type = type,
                deepLink = deepLink,
                data = data
            )
            results[userId] = result
        }

        val successCount = results.values.count { it.isSuccess }
        Log.d(TAG, "Batch notification sent: $successCount/${recipientUserIds.size} succeeded")

        return results
    }
}

// ============================================================================
// Data Models
// ============================================================================

/**
 * Result returned by the send-push-notification Edge Function.
 */
@Serializable
data class PushSendResult(
    val success: Boolean = true,
    val message: String? = null,
    @SerialName("notification_id") val notificationId: String? = null
)
