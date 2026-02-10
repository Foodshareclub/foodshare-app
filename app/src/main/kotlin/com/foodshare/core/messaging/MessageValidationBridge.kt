package com.foodshare.core.messaging

import kotlinx.serialization.Serializable

/**
 * Message validation bridge.
 *
 * Architecture (Frameo pattern):
 * - Pure Kotlin implementation mirroring Swift MessageValidator
 * - Ensures cross-platform validation consistency
 * - Ready for swift-java migration when bindings are regenerated
 *
 * Swift source: foodshare-core/Sources/FoodshareCore/Validation/MessageValidator.swift
 */
object MessageValidationBridge {

    // ========================================================================
    // Configuration (synced with Swift MessageValidator)
    // ========================================================================

    const val MIN_MESSAGE_LENGTH = 1
    const val MAX_MESSAGE_LENGTH = 2000
    const val MAX_ATTACHMENT_SIZE_MB = 10
    const val MAX_SUBJECT_LENGTH = 100

    val ALLOWED_IMAGE_TYPES = listOf("jpg", "jpeg", "png", "gif", "webp")

    // ========================================================================
    // Message Validation
    // ========================================================================

    /**
     * Validate a chat message.
     *
     * @param content The message content
     * @return Validation result
     */
    fun validateMessage(content: String): MessageValidationResult {
        val errors = mutableListOf<MessageValidationError>()
        val trimmed = content.trim()

        when {
            trimmed.isEmpty() -> errors.add(
                MessageValidationError(
                    field = "content",
                    code = "required",
                    message = "Message cannot be empty"
                )
            )
            trimmed.length < MIN_MESSAGE_LENGTH -> errors.add(
                MessageValidationError(
                    field = "content",
                    code = "too_short",
                    message = "Message must be at least $MIN_MESSAGE_LENGTH character"
                )
            )
            trimmed.length > MAX_MESSAGE_LENGTH -> errors.add(
                MessageValidationError(
                    field = "content",
                    code = "too_long",
                    message = "Message cannot exceed $MAX_MESSAGE_LENGTH characters"
                )
            )
        }

        return MessageValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            sanitizedContent = trimmed.takeIf { errors.isEmpty() }
        )
    }

    /**
     * Validate message with subject (for new conversations).
     *
     * @param subject Optional subject line
     * @param message The message content
     * @return Validation result
     */
    fun validateConversationStart(
        subject: String?,
        message: String
    ): MessageValidationResult {
        val errors = mutableListOf<MessageValidationError>()

        // Validate subject if provided
        subject?.let { subj ->
            val trimmedSubject = subj.trim()
            if (trimmedSubject.length > MAX_SUBJECT_LENGTH) {
                errors.add(
                    MessageValidationError(
                        field = "subject",
                        code = "too_long",
                        message = "Subject cannot exceed $MAX_SUBJECT_LENGTH characters"
                    )
                )
            }
        }

        // Validate message
        val messageResult = validateMessage(message)
        errors.addAll(messageResult.errors)

        return MessageValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            sanitizedContent = messageResult.sanitizedContent
        )
    }

    // ========================================================================
    // Attachment Validation
    // ========================================================================

    /**
     * Validate an attachment.
     *
     * @param fileName The file name
     * @param fileSizeBytes File size in bytes
     * @param mimeType Optional MIME type
     * @return Validation result
     */
    fun validateAttachment(
        fileName: String,
        fileSizeBytes: Long,
        mimeType: String? = null
    ): MessageValidationResult {
        val errors = mutableListOf<MessageValidationError>()
        val maxSizeBytes = MAX_ATTACHMENT_SIZE_MB * 1024L * 1024L

        // Check file size
        if (fileSizeBytes > maxSizeBytes) {
            errors.add(
                MessageValidationError(
                    field = "attachment",
                    code = "too_large",
                    message = "Attachment cannot exceed ${MAX_ATTACHMENT_SIZE_MB}MB"
                )
            )
        }

        // Check file type
        val extension = fileName.substringAfterLast('.', "").lowercase()
        if (extension !in ALLOWED_IMAGE_TYPES) {
            errors.add(
                MessageValidationError(
                    field = "attachment",
                    code = "invalid_type",
                    message = "Only images are allowed (${ALLOWED_IMAGE_TYPES.joinToString(", ")})"
                )
            )
        }

        return MessageValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            sanitizedContent = null
        )
    }

    // ========================================================================
    // Content Moderation
    // ========================================================================

    /**
     * Check if message contains blocked words.
     *
     * @param content The content to check
     * @param blockedWords List of blocked words
     * @return True if contains blocked content
     */
    fun containsBlockedContent(
        content: String,
        blockedWords: List<String>
    ): Boolean {
        val lowercased = content.lowercase()
        return blockedWords.any { lowercased.contains(it.lowercase()) }
    }

    /**
     * Sanitize message content.
     *
     * @param content The content to sanitize
     * @return Sanitized content
     */
    fun sanitize(content: String): String {
        var result = content

        // Remove excessive whitespace
        while (result.contains("  ")) {
            result = result.replace("  ", " ")
        }

        // Remove excessive newlines
        while (result.contains("\n\n\n")) {
            result = result.replace("\n\n\n", "\n\n")
        }

        return result.trim()
    }
}

// ========================================================================
// Data Classes
// ========================================================================

/**
 * Message validation result.
 */
@Serializable
data class MessageValidationResult(
    val isValid: Boolean,
    val errors: List<MessageValidationError>,
    val sanitizedContent: String? = null
) {
    val firstError: MessageValidationError?
        get() = errors.firstOrNull()

    fun errorFor(field: String): MessageValidationError? =
        errors.find { it.field == field }
}

/**
 * Message validation error.
 */
@Serializable
data class MessageValidationError(
    val field: String,
    val code: String,
    val message: String
)
