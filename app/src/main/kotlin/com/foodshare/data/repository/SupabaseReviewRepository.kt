package com.foodshare.data.repository

import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.network.RPCConfig
import com.foodshare.data.dto.CanReviewParams
import com.foodshare.data.dto.CanReviewResponse
import com.foodshare.data.dto.ReviewDto
import com.foodshare.data.dto.ReviewStatsDto
import com.foodshare.data.dto.SubmitReviewParams
import com.foodshare.data.dto.SubmitReviewResponse
import com.foodshare.domain.model.Review
import com.foodshare.domain.model.ReviewStats
import com.foodshare.domain.model.TransactionType
import com.foodshare.domain.repository.PendingReview
import com.foodshare.domain.repository.RevieweeStats
import com.foodshare.domain.repository.ReviewRepository
import com.foodshare.domain.repository.ReviewSubmissionResult
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.double
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of ReviewRepository
 */
@Singleton
class SupabaseReviewRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val rpcClient: RateLimitedRPCClient
) : ReviewRepository {

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    override suspend fun getUserReviews(
        userId: String,
        limit: Int,
        cursor: String?
    ): Result<List<Review>> {
        return runCatching {
            val query = supabaseClient.from("reviews")
                .select {
                    filter {
                        eq("reviewee_id", userId)
                    }
                    order("created_at", Order.DESCENDING)
                    limit(limit.toLong())
                }

            query.decodeList<ReviewDto>().map { it.toDomain() }
        }
    }

    override suspend fun getUserReviewStats(userId: String): Result<ReviewStats> {
        return runCatching {
            // Calculate stats from reviews
            val reviews = supabaseClient.from("reviews")
                .select {
                    filter {
                        eq("reviewee_id", userId)
                    }
                }
                .decodeList<ReviewDto>()

            if (reviews.isEmpty()) {
                ReviewStats()
            } else {
                val totalReviews = reviews.size
                val averageRating = reviews.map { it.rating }.average()
                val distribution = reviews.groupBy { it.rating }
                    .mapValues { (_, reviews) -> reviews.size }

                ReviewStats(
                    totalReviews = totalReviews,
                    averageRating = averageRating,
                    ratingDistribution = distribution
                )
            }
        }
    }

    override suspend fun submitReview(
        revieweeId: String,
        postId: String?,
        rating: Int,
        comment: String?,
        transactionType: TransactionType
    ): Result<Review> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = SubmitReviewParams(
            reviewerId = userId,
            revieweeId = revieweeId,
            postId = postId,
            rating = rating,
            comment = comment,
            transactionType = transactionType.name.lowercase()
        )

        return rpcClient.call<SubmitReviewParams, SubmitReviewResponse>(
            functionName = "submit_review",
            params = params,
            config = RPCConfig.default
        ).mapCatching { response ->
            if (!response.success || response.review == null) {
                throw IllegalStateException(response.error ?: "Failed to submit review")
            }
            response.review.toDomain()
        }
    }

    override suspend fun canReviewPost(
        postId: String,
        otherUserId: String
    ): Result<Boolean> {
        val userId = currentUserId ?: return Result.failure(IllegalStateException("Not authenticated"))

        val params = CanReviewParams(
            userId = userId,
            postId = postId,
            otherUserId = otherUserId
        )

        return rpcClient.call<CanReviewParams, CanReviewResponse>(
            functionName = "can_review_post",
            params = params,
            config = RPCConfig.default
        ).map { response ->
            response.canReview
        }
    }

    override suspend fun submitReviewForTransaction(
        transactionId: String,
        rating: Int,
        comment: String?,
        transactionType: TransactionType
    ): Result<ReviewSubmissionResult> {
        return runCatching {
            val params = mapOf(
                "p_transaction_id" to transactionId,
                "p_rating" to rating,
                "p_comment" to comment,
                "p_transaction_type" to transactionType.name.lowercase()
            )

            val response = supabaseClient.postgrest.rpc(
                "submit_review_with_notifications",
                params
            ).decodeAs<JsonObject>()

            val success = response["success"]?.jsonPrimitive?.boolean ?: false

            if (!success) {
                throw IllegalStateException(
                    response["error"]?.jsonPrimitive?.content ?: "Failed to submit review"
                )
            }

            // Parse review
            val reviewJson = response["review"]?.jsonObject
                ?: throw IllegalStateException("No review in response")

            val review = Review(
                id = reviewJson["id"]?.jsonPrimitive?.int ?: 0,
                reviewerId = reviewJson["reviewer_id"]?.jsonPrimitive?.content ?: "",
                revieweeId = reviewJson["reviewee_id"]?.jsonPrimitive?.content ?: "",
                rating = reviewJson["rating"]?.jsonPrimitive?.int ?: rating,
                comment = reviewJson["comment"]?.jsonPrimitive?.content,
                transactionType = transactionType,
                createdAt = reviewJson["created_at"]?.jsonPrimitive?.content ?: "",
                reviewerName = null,
                reviewerAvatar = null
            )

            // Parse reviewee stats
            val statsJson = response["reviewee_stats"]?.jsonObject
            val revieweeStats = RevieweeStats(
                userId = statsJson?.get("user_id")?.jsonPrimitive?.content ?: "",
                newAvgRating = statsJson?.get("new_avg_rating")?.jsonPrimitive?.double ?: 0.0,
                newReviewCount = statsJson?.get("new_review_count")?.jsonPrimitive?.int ?: 0
            )

            ReviewSubmissionResult(
                review = review,
                revieweeStats = revieweeStats
            )
        }
    }

    override suspend fun getPendingReviews(): Result<List<PendingReview>> {
        return runCatching {
            val response = supabaseClient.postgrest.rpc(
                "get_pending_reviews",
                emptyMap<String, Any>()
            ).decodeAs<JsonObject>()

            val success = response["success"]?.jsonPrimitive?.boolean ?: false

            if (!success) {
                throw IllegalStateException(
                    response["error"]?.jsonPrimitive?.content ?: "Failed to get pending reviews"
                )
            }

            val pendingArray = response["pending_reviews"]?.jsonArray ?: return@runCatching emptyList()

            pendingArray.map { element ->
                val obj = element.jsonObject
                val otherUserObj = obj["other_user"]?.jsonObject

                PendingReview(
                    transactionId = obj["transaction_id"]?.jsonPrimitive?.content ?: "",
                    postId = obj["post_id"]?.jsonPrimitive?.int ?: 0,
                    postName = obj["post_name"]?.jsonPrimitive?.content ?: "",
                    otherUserId = otherUserObj?.get("id")?.jsonPrimitive?.content ?: "",
                    otherUserName = otherUserObj?.get("display_name")?.jsonPrimitive?.content ?: "",
                    otherUserAvatar = otherUserObj?.get("avatar_url")?.jsonPrimitive?.content,
                    transactionType = TransactionType.fromString(
                        obj["transaction_type"]?.jsonPrimitive?.content ?: "shared"
                    ),
                    completedAt = obj["completed_at"]?.jsonPrimitive?.content ?: ""
                )
            }
        }
    }
}
