package com.foodshare.core.messaging

import com.foodshare.core.validation.ValidationBridge
import com.foodshare.core.validation.ValidationResult

/**
 * Message validation bridge - delegates to swift-java ValidationBridge
 * for cross-platform parity, adds messaging-specific helpers.
 */
object MessageValidationBridge {

    const val MAX_MESSAGE_LENGTH = ValidationBridge.MAX_MESSAGE_LENGTH
    const val MAX_ATTACHMENT_SIZE_MB = 10
    const val MAX_ATTACHMENTS = 5
    const val SUPPORTED_IMAGE_TYPES = "jpg,jpeg,png,gif,webp"

    fun validateMessage(content: String): ValidationResult {
        return ValidationBridge.validateMessage(content)
    }

    fun sanitizeMessage(content: String): String {
        return ValidationBridge.sanitizeMessage(content)
    }

    fun validateAttachment(fileName: String, sizeBytes: Long): String? {
        if (fileName.isBlank()) return "File name is required"
        val extension = fileName.substringAfterLast('.', "").lowercase()
        val supportedTypes = SUPPORTED_IMAGE_TYPES.split(",")
        if (extension !in supportedTypes) return "Unsupported file type: $extension"
        val sizeMB = sizeBytes / (1024.0 * 1024.0)
        if (sizeMB > MAX_ATTACHMENT_SIZE_MB) return "File too large (max ${MAX_ATTACHMENT_SIZE_MB}MB)"
        return null
    }

    fun validateAttachmentCount(count: Int): String? {
        if (count > MAX_ATTACHMENTS) return "Maximum $MAX_ATTACHMENTS attachments allowed"
        return null
    }

    fun isMessageTooLong(content: String): Boolean = content.length > MAX_MESSAGE_LENGTH

    fun remainingCharacters(content: String): Int = MAX_MESSAGE_LENGTH - content.length
}
