package com.foodshare.core.admin

import com.foodshare.core.validation.ValidationBridge
import com.foodshare.core.validation.ValidationResult
import com.foodshare.core.validation.ValidationError

/**
 * Bridge to Swift AdminValidator via swift-java generated classes.
 *
 * Uses the same SwiftArena pattern as ValidationBridge for memory management.
 * Delegates to SwiftAdminValidator when JNI bindings are regenerated after
 * adding AdminValidator.swift.
 *
 * Fallback: pure Kotlin validation matching Swift constants until bindings exist.
 */
object AdminValidationBridge {

    const val MIN_BAN_REASON_LENGTH = 10
    const val MAX_BAN_REASON_LENGTH = 500
    const val MIN_MODERATION_NOTES_LENGTH = 5
    const val MAX_MODERATION_NOTES_LENGTH = 1000

    fun validateBanReason(reason: String): ValidationResult {
        val trimmed = reason.trim()
        val errors = mutableListOf<String>()

        when {
            trimmed.isEmpty() -> errors.add("Ban reason is required")
            trimmed.length < MIN_BAN_REASON_LENGTH ->
                errors.add("Ban reason must be at least $MIN_BAN_REASON_LENGTH characters")
            trimmed.length > MAX_BAN_REASON_LENGTH ->
                errors.add("Ban reason cannot exceed $MAX_BAN_REASON_LENGTH characters")
        }

        return ValidationResult(
            isValid = errors.isEmpty(),
            errors = errors.map { ValidationError.Custom(it) }
        )
    }

    fun validateModerationNotes(notes: String): ValidationResult {
        val trimmed = notes.trim()
        val errors = mutableListOf<String>()

        when {
            trimmed.isEmpty() -> errors.add("Moderation notes are required")
            trimmed.length < MIN_MODERATION_NOTES_LENGTH ->
                errors.add("Notes must be at least $MIN_MODERATION_NOTES_LENGTH characters")
            trimmed.length > MAX_MODERATION_NOTES_LENGTH ->
                errors.add("Notes cannot exceed $MAX_MODERATION_NOTES_LENGTH characters")
        }

        return ValidationResult(
            isValid = errors.isEmpty(),
            errors = errors.map { ValidationError.Custom(it) }
        )
    }
}
