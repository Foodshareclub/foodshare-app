package com.foodshare.core.input

import com.foodshare.core.validation.ValidationBridge
import com.foodshare.core.validation.ValidationResult

/**
 * Processed input with validation and sanitization results.
 *
 * @property sanitized The sanitized input text
 * @property isValid Whether the input passed validation
 * @property errors List of validation error messages
 */
data class ProcessedInput(
    val sanitized: String,
    val isValid: Boolean,
    val errors: List<String>
) {
    /**
     * Get the first error message, or null if valid.
     */
    val firstError: String?
        get() = errors.firstOrNull()

    /**
     * Throw an exception if input is invalid.
     *
     * @throws InvalidInputException if input is invalid
     */
    fun orThrow(): String {
        if (!isValid) {
            throw InvalidInputException(firstError ?: "Invalid input")
        }
        return sanitized
    }

    /**
     * Get sanitized input or null if invalid.
     */
    fun orNull(): String? = if (isValid) sanitized else null

    /**
     * Get sanitized input or default value if invalid.
     */
    fun orDefault(default: String): String = if (isValid) sanitized else default

    companion object {
        /**
         * Create a valid processed input.
         */
        fun valid(sanitized: String): ProcessedInput {
            return ProcessedInput(sanitized, true, emptyList())
        }

        /**
         * Create an invalid processed input.
         */
        fun invalid(sanitized: String, errors: List<String>): ProcessedInput {
            return ProcessedInput(sanitized, false, errors)
        }
    }
}

/**
 * Exception thrown when input validation fails.
 */
class InvalidInputException(message: String) : Exception(message)

/**
 * Unified input processing utility.
 *
 * Provides type-safe processing pipelines that validate AND sanitize
 * input using Swift-backed validators.
 *
 * Usage:
 * ```kotlin
 * val result = InputProcessor.processForumTitle(title)
 * if (result.isValid) {
 *     repository.createPost(title = result.sanitized)
 * } else {
 *     showError(result.firstError)
 * }
 * ```
 */
object InputProcessor {

    // ========================================================================
    // Forum Processing
    // ========================================================================

    /**
     * Process forum title - validate and sanitize.
     *
     * Validation rules: 5-200 characters, no dangerous content
     * Sanitization: trim, strip HTML, normalize whitespace
     */
    fun processForumTitle(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeForumTitle(input)
        val validation = ValidationBridge.validateForumTitle(sanitized)

        return ProcessedInput(
            sanitized = sanitized,
            isValid = validation.isValid,
            errors = validation.errorMessages
        )
    }

    /**
     * Process forum content - validate and sanitize.
     *
     * Validation rules: 20-10000 characters, no dangerous content
     * Sanitization: trim, escape HTML, normalize whitespace
     */
    fun processForumContent(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeForumContent(input)
        val validation = ValidationBridge.validateForumContent(sanitized)

        return ProcessedInput(
            sanitized = sanitized,
            isValid = validation.isValid,
            errors = validation.errorMessages
        )
    }

    /**
     * Process forum comment - validate and sanitize.
     *
     * Validation rules: 5-5000 characters, no dangerous content
     * Sanitization: trim, escape HTML, normalize whitespace
     */
    fun processForumComment(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeForumComment(input)
        val validation = ValidationBridge.validateForumComment(sanitized)

        return ProcessedInput(
            sanitized = sanitized,
            isValid = validation.isValid,
            errors = validation.errorMessages
        )
    }

    // ========================================================================
    // Message Processing
    // ========================================================================

    /**
     * Process chat message - validate and sanitize.
     *
     * Validation rules: 1-2000 characters
     * Sanitization: trim, escape HTML
     */
    fun processMessage(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeMessage(input)
        val validation = ValidationBridge.validateMessage(sanitized)

        return ProcessedInput(
            sanitized = sanitized,
            isValid = validation.isValid,
            errors = validation.errorMessages
        )
    }

    // ========================================================================
    // Listing Processing
    // ========================================================================

    /**
     * Process listing title - validate and sanitize.
     *
     * Validation rules: 3-100 characters
     * Sanitization: trim, strip HTML, single line
     */
    fun processListingTitle(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeListingTitle(input)
        val validation = ValidationBridge.validateTitle(sanitized)

        return ProcessedInput(
            sanitized = sanitized,
            isValid = validation == null,
            errors = listOfNotNull(validation)
        )
    }

    /**
     * Process listing description - validate and sanitize.
     *
     * Validation rules: max 500 characters
     * Sanitization: trim, escape HTML, normalize whitespace
     */
    fun processListingDescription(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeListingDescription(input)
        val validation = ValidationBridge.validateDescription(sanitized)

        return ProcessedInput(
            sanitized = sanitized,
            isValid = validation == null,
            errors = listOfNotNull(validation)
        )
    }

    // ========================================================================
    // Profile Processing
    // ========================================================================

    /**
     * Process bio - validate and sanitize.
     *
     * Validation rules: max 300 characters
     * Sanitization: trim, escape HTML, normalize whitespace
     */
    fun processBio(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeBio(input)
        val validation = ValidationBridge.validateBio(sanitized)

        return ProcessedInput(
            sanitized = sanitized,
            isValid = validation == null,
            errors = listOfNotNull(validation)
        )
    }

    /**
     * Process display name - validate and sanitize.
     *
     * Validation rules: 2-50 characters
     * Sanitization: trim, strip HTML, single line
     */
    fun processDisplayName(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeDisplayName(input)
        val validation = ValidationBridge.validateNickname(sanitized)

        return ProcessedInput(
            sanitized = sanitized,
            isValid = validation == null,
            errors = listOfNotNull(validation)
        )
    }

    // ========================================================================
    // Review Processing
    // ========================================================================

    /**
     * Process review comment - validate and sanitize.
     *
     * Validation rules: max 500 characters
     * Sanitization: trim, escape HTML, remove dangerous content
     */
    fun processReviewComment(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeReviewComment(input)

        // Review comments are optional, so only validate if non-empty
        val isValid = sanitized.isEmpty() ||
                sanitized.length <= ValidationBridge.MAX_COMMENT_LENGTH

        val errors = if (sanitized.length > ValidationBridge.MAX_COMMENT_LENGTH) {
            listOf("Comment cannot exceed ${ValidationBridge.MAX_COMMENT_LENGTH} characters")
        } else {
            emptyList()
        }

        return ProcessedInput(
            sanitized = sanitized,
            isValid = isValid,
            errors = errors
        )
    }

    // ========================================================================
    // Search Processing
    // ========================================================================

    /**
     * Process search query - validate and sanitize.
     *
     * Validation rules: max 200 characters, no dangerous patterns
     * Sanitization: trim, normalize whitespace
     */
    fun processSearchQuery(input: String): ProcessedInput {
        val trimmed = input.trim()
        val validation = ValidationBridge.validateSearchQuery(trimmed)

        return ProcessedInput(
            sanitized = trimmed,
            isValid = validation.isValid,
            errors = validation.errorMessages
        )
    }

    // ========================================================================
    // Generic Processing
    // ========================================================================

    /**
     * Process any text for XSS-safe display.
     *
     * Sanitization: trim, escape HTML, normalize whitespace
     */
    fun processForDisplay(input: String): ProcessedInput {
        val sanitized = ValidationBridge.sanitizeAndEscapeHTML(input)

        return ProcessedInput(
            sanitized = sanitized,
            isValid = true,
            errors = emptyList()
        )
    }
}

// ========================================================================
// Extension Functions
// ========================================================================

/**
 * Process string as forum title.
 */
fun String.processAsForumTitle(): ProcessedInput = InputProcessor.processForumTitle(this)

/**
 * Process string as forum content.
 */
fun String.processAsForumContent(): ProcessedInput = InputProcessor.processForumContent(this)

/**
 * Process string as message.
 */
fun String.processAsMessage(): ProcessedInput = InputProcessor.processMessage(this)

/**
 * Process string as listing title.
 */
fun String.processAsListingTitle(): ProcessedInput = InputProcessor.processListingTitle(this)

/**
 * Process string for safe display.
 */
fun String.processForDisplay(): ProcessedInput = InputProcessor.processForDisplay(this)
