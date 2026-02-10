package com.foodshare.domain.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Review domain model
 *
 * Maps to `reviews` table in Supabase
 * Kotlin fallback for Swift FoodshareCore.Review
 */
@Serializable
data class Review(
    val id: Int,
    @SerialName("reviewer_id") val reviewerId: String,
    @SerialName("reviewee_id") val revieweeId: String,
    @SerialName("post_id") val postId: String? = null,
    val rating: Int, // 1-5
    val comment: String? = null,
    @SerialName("transaction_type") val transactionType: TransactionType = TransactionType.SHARED,
    @SerialName("created_at") val createdAt: String,
    @SerialName("reviewer_name") val reviewerName: String? = null,
    @SerialName("reviewer_avatar") val reviewerAvatar: String? = null
) {
    val ratingDisplay: String
        get() = "\u2605".repeat(rating) + "\u2606".repeat(5 - rating)

    val isPositive: Boolean
        get() = rating >= 4
}

/**
 * Transaction type for reviews
 */
@Serializable
enum class TransactionType {
    @SerialName("shared")
    SHARED,
    @SerialName("received")
    RECEIVED;

    val displayName: String
        get() = when (this) {
            SHARED -> "Shared Food"
            RECEIVED -> "Received Food"
        }

    val verb: String
        get() = when (this) {
            SHARED -> "shared"
            RECEIVED -> "received"
        }

    companion object {
        fun fromString(value: String): TransactionType {
            return entries.find { it.name.equals(value, ignoreCase = true) } ?: SHARED
        }
    }
}

/**
 * Aggregated review statistics
 */
@Serializable
data class ReviewStats(
    @SerialName("total_reviews") val totalReviews: Int = 0,
    @SerialName("average_rating") val averageRating: Double = 0.0,
    @SerialName("rating_distribution") val ratingDistribution: Map<Int, Int> = emptyMap()
) {
    val formattedAverage: String
        get() = String.format("%.1f", averageRating)
}

/**
 * Request to submit a review
 */
@Serializable
data class SubmitReviewRequest(
    @SerialName("reviewee_id") val revieweeId: String,
    @SerialName("post_id") val postId: String? = null,
    val rating: Int,
    val comment: String? = null,
    @SerialName("transaction_type") val transactionType: TransactionType = TransactionType.SHARED
)
