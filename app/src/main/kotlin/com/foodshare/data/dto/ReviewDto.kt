package com.foodshare.data.dto

import com.foodshare.domain.model.Review
import com.foodshare.domain.model.ReviewStats
import com.foodshare.domain.model.TransactionType
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * DTO for reviews from Supabase
 */
@Serializable
data class ReviewDto(
    val id: Int,
    @SerialName("reviewer_id") val reviewerId: String,
    @SerialName("reviewee_id") val revieweeId: String,
    @SerialName("post_id") val postId: String? = null,
    val rating: Int,
    val comment: String? = null,
    @SerialName("transaction_type") val transactionType: String = "shared",
    @SerialName("created_at") val createdAt: String,
    @SerialName("reviewer_name") val reviewerName: String? = null,
    @SerialName("reviewer_avatar") val reviewerAvatar: String? = null
) {
    fun toDomain(): Review {
        return Review(
            id = id,
            reviewerId = reviewerId,
            revieweeId = revieweeId,
            postId = postId,
            rating = rating,
            comment = comment,
            transactionType = parseTransactionType(transactionType),
            createdAt = createdAt,
            reviewerName = reviewerName,
            reviewerAvatar = reviewerAvatar
        )
    }

    private fun parseTransactionType(type: String): TransactionType {
        return when (type.lowercase()) {
            "shared" -> TransactionType.SHARED
            "received" -> TransactionType.RECEIVED
            else -> TransactionType.SHARED
        }
    }
}

/**
 * Response from submit_review
 */
@Serializable
data class SubmitReviewResponse(
    val success: Boolean,
    val review: ReviewDto? = null,
    val error: String? = null
)

/**
 * Response from can_review_post
 */
@Serializable
data class CanReviewResponse(
    @SerialName("can_review") val canReview: Boolean,
    @SerialName("already_reviewed") val alreadyReviewed: Boolean = false
)

/**
 * Request params for submit_review RPC
 */
@Serializable
data class SubmitReviewParams(
    @SerialName("p_reviewer_id") val reviewerId: String,
    @SerialName("p_reviewee_id") val revieweeId: String,
    @SerialName("p_post_id") val postId: String?,
    @SerialName("p_rating") val rating: Int,
    @SerialName("p_comment") val comment: String?,
    @SerialName("p_transaction_type") val transactionType: String = "shared"
)

/**
 * Request params for can_review_post RPC
 */
@Serializable
data class CanReviewParams(
    @SerialName("p_user_id") val userId: String,
    @SerialName("p_post_id") val postId: String,
    @SerialName("p_other_user_id") val otherUserId: String
)

/**
 * DTO for review stats
 */
@Serializable
data class ReviewStatsDto(
    @SerialName("total_reviews") val totalReviews: Int = 0,
    @SerialName("average_rating") val averageRating: Double = 0.0,
    @SerialName("rating_distribution") val ratingDistribution: Map<String, Int> = emptyMap()
) {
    fun toDomain(): ReviewStats {
        // Convert string keys to int keys
        val distribution = ratingDistribution.mapKeys { (key, _) -> key.toIntOrNull() ?: 0 }
        return ReviewStats(
            totalReviews = totalReviews,
            averageRating = averageRating,
            ratingDistribution = distribution.filterKeys { it > 0 }
        )
    }
}
