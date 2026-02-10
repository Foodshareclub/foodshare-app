package com.foodshare.domain.repository

import com.foodshare.domain.model.Review
import com.foodshare.domain.model.ReviewStats
import com.foodshare.domain.model.TransactionType

/**
 * Repository interface for review operations
 *
 * Matches iOS: ReviewRepository
 */
interface ReviewRepository {

    /**
     * Get reviews for a user with pagination
     */
    suspend fun getUserReviews(
        userId: String,
        limit: Int = 20,
        cursor: String? = null
    ): Result<List<Review>>

    /**
     * Get review statistics for a user
     */
    suspend fun getUserReviewStats(userId: String): Result<ReviewStats>

    /**
     * Submit a review for a completed transaction (legacy - by post ID)
     */
    suspend fun submitReview(
        revieweeId: String,
        postId: String?,
        rating: Int,
        comment: String?,
        transactionType: TransactionType = TransactionType.SHARED
    ): Result<Review>

    /**
     * Submit a review for a transaction (uses atomic RPC)
     *
     * This is the preferred method that:
     * - Atomically inserts the review
     * - Updates the reviewee's average rating
     * - Creates a notification for the reviewee
     * - Prevents duplicate reviews
     *
     * @param transactionId The completed transaction ID
     * @param rating Rating from 1-5
     * @param comment Optional review comment
     * @param transactionType Whether user shared or received
     * @return Result containing the submitted review with updated stats
     */
    suspend fun submitReviewForTransaction(
        transactionId: String,
        rating: Int,
        comment: String?,
        transactionType: TransactionType = TransactionType.SHARED
    ): Result<ReviewSubmissionResult>

    /**
     * Check if user can review a specific post transaction
     */
    suspend fun canReviewPost(
        postId: String,
        otherUserId: String
    ): Result<Boolean>

    /**
     * Get pending reviews (transactions user hasn't reviewed yet)
     */
    suspend fun getPendingReviews(): Result<List<PendingReview>>
}

/**
 * A transaction that can be reviewed
 */
data class PendingReview(
    val transactionId: String,
    val postId: Int,
    val postName: String,
    val otherUserId: String,
    val otherUserName: String,
    val otherUserAvatar: String?,
    val transactionType: TransactionType,
    val completedAt: String
)

/**
 * Result from submitting a review via atomic RPC
 */
data class ReviewSubmissionResult(
    val review: Review,
    val revieweeStats: RevieweeStats
)

/**
 * Updated stats for the reviewed user
 */
data class RevieweeStats(
    val userId: String,
    val newAvgRating: Double,
    val newReviewCount: Int
)
