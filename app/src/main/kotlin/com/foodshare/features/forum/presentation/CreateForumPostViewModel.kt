package com.foodshare.features.forum.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.moderation.ModerationBridge
import com.foodshare.core.moderation.ModerationContentType
import com.foodshare.core.moderation.ModerationSeverity
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.features.forum.domain.model.*
import com.foodshare.features.forum.domain.repository.ForumRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI State for Create Forum Post screen.
 */
data class CreateForumPostUiState(
    val title: String = "",
    val description: String = "",
    val selectedCategory: ForumCategory? = null,
    val postType: ForumPostType = ForumPostType.DISCUSSION,
    val categories: List<ForumCategory> = ForumCategory.defaults,
    val isLoading: Boolean = false,
    val isSubmitting: Boolean = false,
    val error: String? = null,
    val isSuccess: Boolean = false,
    val moderationWarning: String? = null  // Swift-based content moderation warning
) {
    val isValid: Boolean
        get() = title.isNotBlank() && description.isNotBlank() &&
                titleError == null && descriptionError == null

    val hasModerationWarning: Boolean get() = moderationWarning != null

    /** Validate title using Swift validation. */
    val titleError: String?
        get() {
            if (title.isBlank()) return null // Don't show error for empty
            val result = ValidationBridge.validateForumTitle(title)
            return result.firstError
        }

    /** Validate description using Swift validation. */
    val descriptionError: String?
        get() {
            if (description.isBlank()) return null // Don't show error for empty
            val result = ValidationBridge.validateForumContent(description)
            return result.firstError
        }
}

/**
 * ViewModel for Create Forum Post screen.
 */
@HiltViewModel
class CreateForumPostViewModel @Inject constructor(
    private val repository: ForumRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(CreateForumPostUiState())
    val uiState: StateFlow<CreateForumPostUiState> = _uiState.asStateFlow()

    init {
        loadCategories()
    }

    private fun loadCategories() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            repository.getCategories()
                .onSuccess { categories ->
                    _uiState.update {
                        it.copy(
                            categories = categories.ifEmpty { ForumCategory.defaults },
                            isLoading = false
                        )
                    }
                }
                .onFailure {
                    _uiState.update {
                        it.copy(
                            categories = ForumCategory.defaults,
                            isLoading = false
                        )
                    }
                }
        }
    }

    fun updateTitle(title: String) {
        _uiState.update { it.copy(title = title) }
    }

    fun updateDescription(description: String) {
        _uiState.update { it.copy(description = description) }
    }

    fun selectCategory(category: ForumCategory?) {
        _uiState.update { it.copy(selectedCategory = category) }
    }

    fun selectPostType(postType: ForumPostType) {
        _uiState.update { it.copy(postType = postType) }
    }

    /**
     * Submit forum post with Swift-backed validation and moderation.
     * Uses ModerationBridge to check content for inappropriate language.
     */
    fun submitPost() {
        val state = _uiState.value
        if (!state.isValid || state.isSubmitting) return

        // Final validation using Swift before submit
        val titleResult = ValidationBridge.validateForumTitle(state.title)
        if (!titleResult.isValid) {
            _uiState.update { it.copy(error = titleResult.firstError) }
            return
        }

        val contentResult = ValidationBridge.validateForumContent(state.description)
        if (!contentResult.isValid) {
            _uiState.update { it.copy(error = contentResult.firstError) }
            return
        }

        // Run Swift-based content moderation check before submission
        val moderationResult = ModerationBridge.checkBeforeSubmission(
            title = state.title,
            description = state.description,
            contentType = ModerationContentType.FORUM_POST
        )

        // Block submission if moderation fails
        if (!moderationResult.canSubmit) {
            val issueDescriptions = moderationResult.issues.joinToString("\n") { it.description }
            _uiState.update {
                it.copy(
                    error = "Post contains inappropriate content: $issueDescriptions",
                    moderationWarning = if (moderationResult.severity == ModerationSeverity.LOW) {
                        issueDescriptions
                    } else null
                )
            }
            return
        }

        // Use sanitized content from moderation result (or fallback to ValidationBridge)
        val sanitizedTitle = moderationResult.sanitizedTitle
            ?: ValidationBridge.sanitizeForumTitle(state.title)
        val sanitizedDescription = moderationResult.sanitizedDescription
            ?: ValidationBridge.sanitizeForumContent(state.description)

        viewModelScope.launch {
            _uiState.update { it.copy(isSubmitting = true, error = null, moderationWarning = null) }

            repository.createPost(
                title = sanitizedTitle,
                description = sanitizedDescription,
                categoryId = state.selectedCategory?.id,
                postType = state.postType
            )
                .onSuccess {
                    _uiState.update { it.copy(isSubmitting = false, isSuccess = true) }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(isSubmitting = false, error = error.message ?: "Failed to create post")
                    }
                }
        }
    }

    /**
     * Preview moderation for real-time feedback as user types.
     * Called when user finishes editing title or description.
     */
    fun checkModeration() {
        val state = _uiState.value
        if (state.title.isBlank() && state.description.isBlank()) {
            _uiState.update { it.copy(moderationWarning = null) }
            return
        }

        val result = ModerationBridge.checkBeforeSubmission(
            title = state.title.takeIf { it.isNotBlank() },
            description = state.description.takeIf { it.isNotBlank() },
            contentType = ModerationContentType.FORUM_POST
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
