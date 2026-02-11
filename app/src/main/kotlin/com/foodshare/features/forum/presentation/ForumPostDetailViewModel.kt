package com.foodshare.features.forum.presentation

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
import com.foodshare.features.forum.domain.model.*
import com.foodshare.features.forum.domain.repository.ForumRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI State for Forum Post Detail screen.
 */
data class ForumPostDetailUiState(
    val post: ForumPost? = null,
    val comments: List<ForumComment> = emptyList(),
    val isLoading: Boolean = true,
    val isLoadingComments: Boolean = false,
    val isSubmittingComment: Boolean = false,
    val error: String? = null,
    val commentText: String = "",
    val replyingToComment: ForumComment? = null,
    val reactions: ReactionsSummary = ReactionsSummary(),
    val isBookmarked: Boolean = false,
    val moderationWarning: String? = null  // Swift-based content moderation warning
) {
    val hasModerationWarning: Boolean get() = moderationWarning != null
}

/**
 * ViewModel for Forum Post Detail screen.
 */
@HiltViewModel
class ForumPostDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: ForumRepository,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val postId: Int = savedStateHandle.get<Int>("postId") ?: -1

    private val _uiState = MutableStateFlow(ForumPostDetailUiState())
    val uiState: StateFlow<ForumPostDetailUiState> = _uiState.asStateFlow()

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    init {
        if (postId != -1) {
            loadPost()
        }
    }

    fun loadPost() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            repository.getPost(postId)
                .onSuccess { post ->
                    _uiState.update {
                        it.copy(
                            post = post,
                            isBookmarked = post.isBookmarked,
                            isLoading = false
                        )
                    }
                    // Record view
                    repository.recordView(postId)
                    // Load comments and reactions
                    loadComments()
                    loadReactions()
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(isLoading = false, error = ErrorBridge.mapForumError(error))
                    }
                }
        }
    }

    private fun loadComments() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingComments = true) }

            repository.getComments(postId, limit = 50)
                .onSuccess { comments ->
                    _uiState.update {
                        it.copy(comments = comments, isLoadingComments = false)
                    }
                }
                .onFailure {
                    _uiState.update { it.copy(isLoadingComments = false) }
                }
        }
    }

    private fun loadReactions() {
        viewModelScope.launch {
            repository.getPostReactions(postId)
                .onSuccess { reactions ->
                    _uiState.update { it.copy(reactions = reactions) }
                }
        }
    }

    fun updateCommentText(text: String) {
        _uiState.update { it.copy(commentText = text) }
    }

    fun setReplyingTo(comment: ForumComment?) {
        _uiState.update { it.copy(replyingToComment = comment) }
    }

    /**
     * Submit forum comment with Swift-backed validation and moderation.
     * Uses ModerationBridge to check comment content for inappropriate language.
     */
    fun submitComment() {
        val text = _uiState.value.commentText.trim()
        if (text.isEmpty() || _uiState.value.isSubmittingComment) return

        // Validate comment content using Swift
        val validationResult = ValidationBridge.validateForumComment(text)
        if (!validationResult.isValid) {
            _uiState.update { it.copy(error = validationResult.firstError) }
            return
        }

        // Run Swift-based content moderation check on comment
        val moderationResult = ModerationBridge.checkBeforeSubmission(
            title = null,
            description = text,
            contentType = ModerationContentType.FORUM_COMMENT
        )

        // Block submission if moderation fails
        if (!moderationResult.canSubmit) {
            val issueDescriptions = moderationResult.issues.joinToString("\n") { it.description }
            _uiState.update {
                it.copy(
                    error = "Comment contains inappropriate content: $issueDescriptions",
                    moderationWarning = if (moderationResult.severity == ModerationSeverity.LOW) {
                        issueDescriptions
                    } else null
                )
            }
            return
        }

        // Sanitize comment content using Swift before submission
        val sanitizedText = moderationResult.sanitizedDescription
            ?: ValidationBridge.sanitizeForumComment(text)

        viewModelScope.launch {
            _uiState.update { it.copy(isSubmittingComment = true, moderationWarning = null) }

            val parentId = _uiState.value.replyingToComment?.id

            repository.createComment(postId, sanitizedText, parentId)
                .onSuccess { newComment ->
                    _uiState.update {
                        it.copy(
                            comments = it.comments + newComment,
                            commentText = "",
                            replyingToComment = null,
                            isSubmittingComment = false
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(error = ErrorBridge.mapForumError(error), isSubmittingComment = false)
                    }
                }
        }
    }

    /**
     * Preview moderation for real-time feedback as user types comment.
     */
    fun checkCommentModeration() {
        val text = _uiState.value.commentText.trim()
        if (text.isBlank()) {
            _uiState.update { it.copy(moderationWarning = null) }
            return
        }

        val result = ModerationBridge.checkBeforeSubmission(
            title = null,
            description = text,
            contentType = ModerationContentType.FORUM_COMMENT
        )

        _uiState.update {
            it.copy(
                moderationWarning = if (result.hasIssues && result.canSubmit) {
                    result.issues.joinToString("\n") { issue -> issue.description }
                } else null
            )
        }
    }

    /**
     * Toggle reaction with Swift-backed optimistic updates.
     * Uses OptimisticUpdateBridge for instant feedback and smart rollback.
     */
    fun toggleReaction(reactionType: String) {
        val currentReactions = _uiState.value.reactions

        // Create optimistic update via Swift bridge
        val originalValue = """{"reactions":${currentReactions.totalCount}}"""
        val optimisticValue = """{"reaction":"$reactionType"}"""
        val optimisticUpdate = OptimisticUpdateBridge.createUpdate(
            id = postId.toString(),
            entityType = EntityType.FORUM_POST,
            operation = UpdateOperation.UPDATE,
            originalValue = originalValue,
            optimisticValue = optimisticValue
        )

        // Apply optimistic reaction toggle immediately
        val optimisticReactions = currentReactions.copy(
            totalCount = currentReactions.totalCount + 1  // Optimistic increment
        )
        _uiState.update { it.copy(reactions = optimisticReactions) }

        viewModelScope.launch {
            repository.togglePostReaction(postId, reactionType)
                .onSuccess { reactions ->
                    // Confirm optimistic update with actual server state
                    optimisticUpdate?.let { OptimisticUpdateBridge.confirmUpdate(it) }
                    _uiState.update { it.copy(reactions = reactions) }
                }
                .onFailure { error ->
                    // Use Swift bridge for rollback
                    if (optimisticUpdate != null) {
                        OptimisticUpdateBridge.rollback(optimisticUpdate)
                    }
                    _uiState.update {
                        it.copy(
                            reactions = currentReactions,  // Restore original
                            error = ErrorBridge.mapForumError(error)
                        )
                    }
                }
        }
    }

    /**
     * Toggle bookmark with Swift-backed optimistic updates.
     * Uses OptimisticUpdateBridge for instant feedback and smart rollback.
     */
    fun toggleBookmark() {
        val currentState = _uiState.value.isBookmarked

        // Create optimistic update via Swift bridge
        val originalValue = """{"isBookmarked":$currentState}"""
        val optimisticValue = """{"isBookmarked":${!currentState}}"""
        val optimisticUpdate = OptimisticUpdateBridge.createUpdate(
            id = postId.toString(),
            entityType = EntityType.FORUM_POST,
            operation = if (currentState) UpdateOperation.UNFAVORITE else UpdateOperation.FAVORITE,
            originalValue = originalValue,
            optimisticValue = optimisticValue
        )

        // Apply optimistic update - toggle immediately
        _uiState.update { it.copy(isBookmarked = !currentState) }

        viewModelScope.launch {
            repository.toggleBookmark(postId)
                .onSuccess { isBookmarked ->
                    // Confirm optimistic update
                    optimisticUpdate?.let { OptimisticUpdateBridge.confirmUpdate(it) }
                    _uiState.update { it.copy(isBookmarked = isBookmarked) }
                }
                .onFailure { error ->
                    // Use Swift bridge for rollback decision
                    if (optimisticUpdate != null) {
                        val recommendation = OptimisticUpdateBridge.handleError(
                            update = optimisticUpdate,
                            errorCode = "BOOKMARK_FAILED",
                            errorMessage = error.message ?: "Failed to toggle bookmark",
                            category = categorizeError(error)
                        )

                        if (recommendation.shouldRollback) {
                            // Rollback via Swift bridge
                            OptimisticUpdateBridge.rollback(optimisticUpdate)
                            _uiState.update { it.copy(isBookmarked = currentState) }
                        }
                    } else {
                        // Fallback: revert manually
                        _uiState.update { it.copy(isBookmarked = currentState) }
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

    fun toggleCommentReaction(commentId: Int, reactionType: String) {
        viewModelScope.launch {
            repository.toggleCommentReaction(commentId, reactionType)
                .onSuccess { reactions ->
                    // Update the specific comment's reaction state
                    loadComments() // Reload to get updated reactions
                }
        }
    }

    fun markAsBestAnswer(commentId: Int) {
        viewModelScope.launch {
            repository.markAsBestAnswer(commentId, postId)
                .onSuccess {
                    loadComments()
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = ErrorBridge.mapForumError(error)) }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
