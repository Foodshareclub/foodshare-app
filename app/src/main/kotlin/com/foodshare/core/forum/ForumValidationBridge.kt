package com.foodshare.core.forum

import kotlinx.serialization.Serializable

/**
 * Forum validation bridge.
 *
 * Architecture (Frameo pattern):
 * - Pure Kotlin implementation mirroring Swift ForumValidator
 * - Ensures cross-platform validation consistency
 * - Ready for swift-java migration when bindings are regenerated
 *
 * Swift source: foodshare-core/Sources/FoodshareCore/Validation/ForumValidator.swift
 */
object ForumValidationBridge {

    // ========================================================================
    // Configuration (synced with Swift ForumValidator)
    // ========================================================================

    const val MIN_POST_TITLE_LENGTH = 5
    const val MAX_POST_TITLE_LENGTH = 200
    const val MIN_POST_CONTENT_LENGTH = 10
    const val MAX_POST_CONTENT_LENGTH = 10000
    const val MIN_COMMENT_LENGTH = 1
    const val MAX_COMMENT_LENGTH = 5000
    const val MAX_TAG_COUNT = 10
    const val MAX_TAG_LENGTH = 50

    // ========================================================================
    // Post Validation
    // ========================================================================

    /**
     * Validate a forum post.
     *
     * @param title Post title
     * @param content Post content
     * @param tags List of tags
     * @return Validation result
     */
    fun validatePost(
        title: String,
        content: String,
        tags: List<String> = emptyList()
    ): ForumValidationResult {
        val errors = mutableListOf<ForumValidationError>()

        // Validate title
        validatePostTitle(title)?.let { errors.add(it) }

        // Validate content
        validatePostContent(content)?.let { errors.add(it) }

        // Validate tags
        validateTags(tags)?.let { errors.add(it) }

        return ForumValidationResult(
            isValid = errors.isEmpty(),
            errors = errors
        )
    }

    /**
     * Validate post title.
     *
     * @param title The title to validate
     * @return Error if invalid, null if valid
     */
    fun validatePostTitle(title: String): ForumValidationError? {
        val trimmed = title.trim()

        return when {
            trimmed.isEmpty() -> ForumValidationError(
                field = "title",
                code = "required",
                message = "Title is required"
            )
            trimmed.length < MIN_POST_TITLE_LENGTH -> ForumValidationError(
                field = "title",
                code = "too_short",
                message = "Title must be at least $MIN_POST_TITLE_LENGTH characters"
            )
            trimmed.length > MAX_POST_TITLE_LENGTH -> ForumValidationError(
                field = "title",
                code = "too_long",
                message = "Title cannot exceed $MAX_POST_TITLE_LENGTH characters"
            )
            else -> null
        }
    }

    /**
     * Validate post content.
     *
     * @param content The content to validate
     * @return Error if invalid, null if valid
     */
    fun validatePostContent(content: String): ForumValidationError? {
        val trimmed = content.trim()

        return when {
            trimmed.isEmpty() -> ForumValidationError(
                field = "content",
                code = "required",
                message = "Content is required"
            )
            trimmed.length < MIN_POST_CONTENT_LENGTH -> ForumValidationError(
                field = "content",
                code = "too_short",
                message = "Content must be at least $MIN_POST_CONTENT_LENGTH characters"
            )
            trimmed.length > MAX_POST_CONTENT_LENGTH -> ForumValidationError(
                field = "content",
                code = "too_long",
                message = "Content cannot exceed $MAX_POST_CONTENT_LENGTH characters"
            )
            else -> null
        }
    }

    // ========================================================================
    // Comment Validation
    // ========================================================================

    /**
     * Validate a forum comment.
     *
     * @param content Comment content
     * @return Validation result
     */
    fun validateComment(content: String): ForumValidationResult {
        val errors = mutableListOf<ForumValidationError>()
        val trimmed = content.trim()

        when {
            trimmed.isEmpty() -> errors.add(
                ForumValidationError(
                    field = "content",
                    code = "required",
                    message = "Comment cannot be empty"
                )
            )
            trimmed.length < MIN_COMMENT_LENGTH -> errors.add(
                ForumValidationError(
                    field = "content",
                    code = "too_short",
                    message = "Comment must be at least $MIN_COMMENT_LENGTH character"
                )
            )
            trimmed.length > MAX_COMMENT_LENGTH -> errors.add(
                ForumValidationError(
                    field = "content",
                    code = "too_long",
                    message = "Comment cannot exceed $MAX_COMMENT_LENGTH characters"
                )
            )
        }

        return ForumValidationResult(
            isValid = errors.isEmpty(),
            errors = errors
        )
    }

    // ========================================================================
    // Tag Validation
    // ========================================================================

    /**
     * Validate tags.
     *
     * @param tags List of tags
     * @return Error if invalid, null if valid
     */
    fun validateTags(tags: List<String>): ForumValidationError? {
        if (tags.size > MAX_TAG_COUNT) {
            return ForumValidationError(
                field = "tags",
                code = "too_many",
                message = "Maximum $MAX_TAG_COUNT tags allowed"
            )
        }

        for (tag in tags) {
            val trimmed = tag.trim()
            if (trimmed.isEmpty()) {
                return ForumValidationError(
                    field = "tags",
                    code = "empty_tag",
                    message = "Tags cannot be empty"
                )
            }

            if (trimmed.length > MAX_TAG_LENGTH) {
                return ForumValidationError(
                    field = "tags",
                    code = "tag_too_long",
                    message = "Tags cannot exceed $MAX_TAG_LENGTH characters"
                )
            }
        }

        return null
    }

    /**
     * Validate a single tag.
     *
     * @param tag The tag to validate
     * @return True if valid
     */
    fun validateTag(tag: String): Boolean {
        val trimmed = tag.trim()
        return trimmed.isNotEmpty() && trimmed.length <= MAX_TAG_LENGTH
    }
}

// ========================================================================
// Data Classes
// ========================================================================

/**
 * Forum validation result.
 */
@Serializable
data class ForumValidationResult(
    val isValid: Boolean,
    val errors: List<ForumValidationError>
) {
    val firstError: ForumValidationError?
        get() = errors.firstOrNull()

    fun errorFor(field: String): ForumValidationError? =
        errors.find { it.field == field }
}

/**
 * Forum validation error.
 */
@Serializable
data class ForumValidationError(
    val field: String,
    val code: String,
    val message: String
)
