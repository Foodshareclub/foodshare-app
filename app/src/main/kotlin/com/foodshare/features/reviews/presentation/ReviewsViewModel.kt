package com.foodshare.features.reviews.presentation

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.core.moderation.ModerationBridge
import com.foodshare.core.moderation.ModerationContentType
import com.foodshare.core.moderation.ModerationSeverity
import com.foodshare.core.optimistic.EntityType
import com.foodshare.core.optimistic.ErrorCategory
import com.foodshare.core.optimistic.OptimisticUpdateBridge
import com.foodshare.core.optimistic.UpdateOperation
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.domain.model.Review
import com.foodshare.domain.model.ReviewStats
import com.foodshare.domain.model.TransactionType
import com.foodshare.domain.repository.ReviewRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

/**
 * ViewModel for viewing user reviews
 */
@HiltViewModel
class UserReviewsViewModel @Inject constructor(
    private val reviewRepository: ReviewRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val userId: String = checkNotNull(savedStateHandle["userId"])

    private val _uiState = MutableStateFlow(UserReviewsUiState())
    val uiState: StateFlow<UserReviewsUiState> = _uiState.asStateFlow()

    init {
        loadReviews()
        loadStats()
    }

    fun loadReviews() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            reviewRepository.getUserReviews(userId)
                .onSuccess { reviews ->
                    _uiState.update {
                        it.copy(
                            reviews = reviews,
                            isLoading = false
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapReviewError(error)
                        )
                    }
                }
        }
    }

    private fun loadStats() {
        viewModelScope.launch {
            reviewRepository.getUserReviewStats(userId)
                .onSuccess { stats ->
                    _uiState.update { it.copy(stats = stats) }
                }
        }
    }

    fun loadMore() {
        val state = _uiState.value
        if (state.isLoadingMore || !state.hasMore) return

        val lastReview = state.reviews.lastOrNull() ?: return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingMore = true) }

            reviewRepository.getUserReviews(
                userId = userId,
                cursor = lastReview.createdAt
            ).onSuccess { moreReviews ->
                _uiState.update {
                    it.copy(
                        reviews = it.reviews + moreReviews,
                        isLoadingMore = false,
                        hasMore = moreReviews.isNotEmpty()
                    )
                }
            }.onFailure {
                _uiState.update { it.copy(isLoadingMore = false) }
            }
        }
    }
}

/**
 * UI State for User Reviews
 */
data class UserReviewsUiState(
    val reviews: List<Review> = emptyList(),
    val stats: ReviewStats? = null,
    val isLoading: Boolean = false,
    val isLoadingMore: Boolean = false,
    val hasMore: Boolean = true,
    val error: String? = null
)

/**
 * ViewModel for submitting a review
 */
@HiltViewModel
class SubmitReviewViewModel @Inject constructor(
    private val reviewRepository: ReviewRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val postId: String? = savedStateHandle["postId"]
    private val revieweeId: String = checkNotNull(savedStateHandle["revieweeId"])
    private val transactionType: TransactionType = savedStateHandle.get<String>("transactionType")
        ?.let { TransactionType.valueOf(it.uppercase()) }
        ?: TransactionType.SHARED

    private val _uiState = MutableStateFlow(SubmitReviewUiState())
    val uiState: StateFlow<SubmitReviewUiState> = _uiState.asStateFlow()

    init {
        checkCanReview()
    }

    private fun checkCanReview() {
        if (postId == null) return

        viewModelScope.launch {
            reviewRepository.canReviewPost(postId, revieweeId)
                .onSuccess { canReview ->
                    if (!canReview) {
                        _uiState.update {
                            it.copy(error = "You have already reviewed this transaction")
                        }
                    }
                }
        }
    }

    fun setRating(rating: Int) {
        _uiState.update { it.copy(rating = rating.coerceIn(1, 5)) }
    }

    fun setComment(comment: String) {
        _uiState.update { it.copy(comment = comment) }
    }

    /**
     * Submit review with Swift-backed validation, moderation, and optimistic updates.
     * Uses ModerationBridge to check comment content for inappropriate language.
     * Uses OptimisticUpdateBridge for instant feedback and smart rollback.
     */
    fun submit() {
        val state = _uiState.value

        // Use ValidationBridge which delegates to Swift when available
        val validationResult = ValidationBridge.validateReview(
            rating = state.rating,
            comment = state.comment.takeIf { it.isNotBlank() }
        )

        if (!validationResult.isValid) {
            _uiState.update { it.copy(error = validationResult.firstError ?: "Invalid review") }
            return
        }

        // Run Swift-based content moderation check on comment
        if (state.comment.isNotBlank()) {
            val moderationResult = ModerationBridge.checkBeforeSubmission(
                title = null,
                description = state.comment,
                contentType = ModerationContentType.REVIEW
            )

            // Block submission if moderation fails
            if (!moderationResult.canSubmit) {
                val issueDescriptions = moderationResult.issues.joinToString("\n") { it.description }
                _uiState.update {
                    it.copy(
                        error = "Review contains inappropriate content: $issueDescriptions",
                        moderationWarning = if (moderationResult.severity == ModerationSeverity.LOW) {
                            issueDescriptions
                        } else null
                    )
                }
                return
            }
        }

        // Sanitize comment using Swift before submission
        val sanitizedComment = if (state.comment.isNotBlank()) {
            ValidationBridge.sanitizeReviewComment(state.comment)
        } else null

        // Create optimistic update via Swift bridge
        val optimisticId = UUID.randomUUID().toString()
        val optimisticValue = """{"rating":${state.rating},"comment":"${sanitizedComment.orEmpty()}"}"""
        val optimisticUpdate = OptimisticUpdateBridge.createUpdate(
            id = optimisticId,
            entityType = EntityType.REVIEW,
            operation = UpdateOperation.CREATE,
            originalValue = null,
            optimisticValue = optimisticValue
        )

        // Apply optimistic update - show success immediately
        _uiState.update {
            it.copy(
                isSubmitting = true,
                isSubmitted = true,  // Optimistic: show success immediately
                error = null,
                moderationWarning = null
            )
        }

        viewModelScope.launch {
            reviewRepository.submitReview(
                revieweeId = revieweeId,
                postId = postId,
                rating = state.rating,
                comment = sanitizedComment,
                transactionType = transactionType
            ).onSuccess {
                // Confirm optimistic update
                optimisticUpdate?.let { OptimisticUpdateBridge.confirmUpdate(it) }
                _uiState.update {
                    it.copy(isSubmitting = false)
                }
            }.onFailure { error ->
                // Use Swift bridge for rollback decision
                if (optimisticUpdate != null) {
                    val recommendation = OptimisticUpdateBridge.handleError(
                        update = optimisticUpdate,
                        errorCode = "SUBMIT_FAILED",
                        errorMessage = error.message ?: "Failed to submit review",
                        category = categorizeError(error)
                    )

                    if (recommendation.shouldRollback) {
                        // Rollback via Swift bridge
                        OptimisticUpdateBridge.rollback(optimisticUpdate)
                        _uiState.update {
                            it.copy(
                                isSubmitting = false,
                                isSubmitted = false,  // Rollback: show form again
                                error = ErrorBridge.mapReviewError(error)
                            )
                        }
                    } else if (recommendation.shouldRetry && recommendation.delayMs != null) {
                        // Retry after delay
                        delay(recommendation.delayMs)
                        retrySubmit(optimisticUpdate, state.rating, sanitizedComment)
                    }
                } else {
                    _uiState.update {
                        it.copy(
                            isSubmitting = false,
                            isSubmitted = false,
                            error = ErrorBridge.mapReviewError(error)
                        )
                    }
                }
            }
        }
    }

    /**
     * Retry submitting a failed review.
     */
    private fun retrySubmit(
        update: com.foodshare.core.optimistic.OptimisticUpdate,
        rating: Int,
        comment: String?
    ) {
        viewModelScope.launch {
            val incrementedUpdate = OptimisticUpdateBridge.incrementRetry(update)

            reviewRepository.submitReview(
                revieweeId = revieweeId,
                postId = postId,
                rating = rating,
                comment = comment,
                transactionType = transactionType
            ).onSuccess {
                OptimisticUpdateBridge.confirmUpdate(incrementedUpdate)
                _uiState.update { it.copy(isSubmitting = false) }
            }.onFailure { error ->
                val recommendation = OptimisticUpdateBridge.handleError(
                    update = incrementedUpdate,
                    errorCode = "RETRY_FAILED",
                    errorMessage = error.message ?: "Retry failed",
                    category = categorizeError(error)
                )

                if (recommendation.shouldRollback) {
                    OptimisticUpdateBridge.rollback(incrementedUpdate)
                    _uiState.update {
                        it.copy(
                            isSubmitting = false,
                            isSubmitted = false,
                            error = "Review failed after retries. Please try again."
                        )
                    }
                }
            }
        }
    }

    /**
     * Categorize error for OptimisticUpdateBridge.
     */
    private fun categorizeError(error: Throwable): ErrorCategory {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("network") || message.contains("timeout") -> ErrorCategory.NETWORK
            message.contains("unauthorized") || message.contains("401") -> ErrorCategory.AUTHORIZATION
            message.contains("conflict") || message.contains("409") -> ErrorCategory.CONFLICT
            message.contains("validation") || message.contains("400") -> ErrorCategory.VALIDATION
            message.contains("server") || message.contains("500") -> ErrorCategory.SERVER_ERROR
            else -> ErrorCategory.UNKNOWN
        }
    }

    /**
     * Preview moderation for real-time feedback as user types.
     */
    fun checkModeration() {
        val state = _uiState.value
        if (state.comment.isBlank()) {
            _uiState.update { it.copy(moderationWarning = null) }
            return
        }

        val result = ModerationBridge.checkBeforeSubmission(
            title = null,
            description = state.comment,
            contentType = ModerationContentType.REVIEW
        )

        _uiState.update {
            it.copy(
                moderationWarning = if (result.hasIssues && result.canSubmit) {
                    result.issues.joinToString("\n") { issue -> issue.description }
                } else null
            )
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}

/**
 * UI State for Submit Review
 */
data class SubmitReviewUiState(
    val rating: Int = 0,
    val comment: String = "",
    val isSubmitting: Boolean = false,
    val isSubmitted: Boolean = false,
    val error: String? = null,
    val moderationWarning: String? = null  // Swift-based content moderation warning
) {
    val isValid: Boolean get() = rating in 1..5
    val canSubmit: Boolean get() = isValid && !isSubmitting
    val hasModerationWarning: Boolean get() = moderationWarning != null
}
