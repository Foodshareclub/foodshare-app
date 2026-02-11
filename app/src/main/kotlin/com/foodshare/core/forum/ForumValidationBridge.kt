package com.foodshare.core.forum

import com.foodshare.core.validation.ValidationBridge
import com.foodshare.core.validation.ValidationResult

/**
 * Forum validation bridge - delegates to swift-java ValidationBridge
 * for cross-platform parity, adds forum-specific helpers.
 */
object ForumValidationBridge {

    const val MIN_TITLE_LENGTH = ValidationBridge.MIN_FORUM_TITLE_LENGTH
    const val MAX_TITLE_LENGTH = ValidationBridge.MAX_FORUM_TITLE_LENGTH
    const val MIN_CONTENT_LENGTH = ValidationBridge.MIN_FORUM_CONTENT_LENGTH
    const val MAX_CONTENT_LENGTH = ValidationBridge.MAX_FORUM_CONTENT_LENGTH
    const val MAX_COMMENT_DEPTH = ValidationBridge.MAX_COMMENT_DEPTH
    const val MAX_TAGS = 5
    const val MAX_TAG_LENGTH = 30
    const val MAX_POLL_OPTIONS = 6
    const val MIN_POLL_OPTIONS = 2

    fun validateTitle(title: String): ValidationResult {
        return ValidationBridge.validateForumTitle(title)
    }

    fun validateContent(content: String): ValidationResult {
        return ValidationBridge.validateForumContent(content)
    }

    fun validateComment(content: String): ValidationResult {
        return ValidationBridge.validateForumComment(content)
    }

    fun validateCommentDepth(depth: Int): Boolean {
        return ValidationBridge.validateCommentDepth(depth)
    }

    fun sanitizeTitle(title: String): String {
        return ValidationBridge.sanitizeForumTitle(title)
    }

    fun sanitizeContent(content: String): String {
        return ValidationBridge.sanitizeForumContent(content)
    }

    fun validateTags(tags: List<String>): List<String> {
        val errors = mutableListOf<String>()
        if (tags.size > MAX_TAGS) errors.add("Maximum $MAX_TAGS tags allowed")
        tags.forEachIndexed { index, tag ->
            if (tag.isBlank()) errors.add("Tag ${index + 1} is empty")
            if (tag.length > MAX_TAG_LENGTH) errors.add("Tag '$tag' exceeds $MAX_TAG_LENGTH characters")
            if (!tag.matches(Regex("^[a-zA-Z0-9-_ ]+$"))) {
                errors.add("Tag '$tag' contains invalid characters")
            }
        }
        if (tags.distinct().size != tags.size) errors.add("Duplicate tags are not allowed")
        return errors
    }

    fun validatePollOptions(options: List<String>): List<String> {
        val errors = mutableListOf<String>()
        if (options.size < MIN_POLL_OPTIONS) errors.add("At least $MIN_POLL_OPTIONS options required")
        if (options.size > MAX_POLL_OPTIONS) errors.add("Maximum $MAX_POLL_OPTIONS options allowed")
        options.forEachIndexed { index, option ->
            if (option.isBlank()) errors.add("Option ${index + 1} is empty")
            if (option.length > 200) errors.add("Option ${index + 1} exceeds 200 characters")
        }
        if (options.distinct().size != options.size) errors.add("Duplicate options are not allowed")
        return errors
    }
}
