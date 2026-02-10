package com.foodshare.core.push

import android.net.Uri

/**
 * Deep link builder for push notifications and navigation.
 */
object DeepLinkBuilder {
    private const val SCHEME = "foodshare"

    /**
     * Build deep link for a listing detail.
     */
    fun listing(listingId: Int): String = "$SCHEME://listing/$listingId"

    /**
     * Build deep link for a chat conversation.
     */
    fun chat(conversationId: String): String = "$SCHEME://chat/$conversationId"

    /**
     * Build deep link for an arrangement.
     */
    fun arrangement(arrangementId: String): String = "$SCHEME://arrangement/$arrangementId"

    /**
     * Build deep link for user profile.
     */
    fun profile(userId: String): String = "$SCHEME://profile/$userId"

    /**
     * Build deep link for user reviews.
     */
    fun reviews(userId: String): String = "$SCHEME://reviews/$userId"

    /**
     * Build deep link to submit a review.
     */
    fun submitReview(
        revieweeId: String,
        postId: String? = null,
        transactionType: String = "shared"
    ): String {
        val base = "$SCHEME://submit-review/$revieweeId"
        val params = buildList {
            postId?.let { add("postId=$it") }
            add("transactionType=$transactionType")
        }.joinToString("&")
        return "$base?$params"
    }

    /**
     * Build deep link for messages list.
     */
    fun messages(): String = "$SCHEME://messages"

    /**
     * Build deep link for search.
     */
    fun search(query: String? = null): String {
        return if (query != null) {
            "$SCHEME://search?q=$query"
        } else {
            "$SCHEME://search"
        }
    }

    /**
     * Build deep link for a specific tab.
     */
    fun tab(tabName: String): String = "$SCHEME://tab/$tabName"

    /**
     * Parse deep link to extract route info.
     */
    fun parse(deepLink: String): DeepLinkInfo? {
        return try {
            val uri = Uri.parse(deepLink)
            if (uri.scheme != SCHEME) return null

            val pathSegments = uri.pathSegments
            if (pathSegments.isEmpty()) return null

            DeepLinkInfo(
                type = pathSegments[0],
                id = pathSegments.getOrNull(1),
                params = uri.queryParameterNames.associateWith { uri.getQueryParameter(it) }
            )
        } catch (e: Exception) {
            null
        }
    }
}

/**
 * Parsed deep link information.
 */
data class DeepLinkInfo(
    val type: String,
    val id: String?,
    val params: Map<String, String?>
)
