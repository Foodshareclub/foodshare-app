package com.foodshare.swift

/**
 * Listing validation with local Kotlin implementation.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for validation rules
 * - No JNI required for these stateless operations
 */
class ListingValidator {

    companion object {
        const val MIN_TITLE_LENGTH = 3
        const val MAX_TITLE_LENGTH = 100
        const val MAX_DESCRIPTION_LENGTH = 500
        const val MAX_EXPIRATION_DAYS = 30
    }

    /**
     * Validate listing fields.
     */
    fun validate(
        title: String,
        description: String,
        quantity: Int = 1
    ): ValidationResult {
        val errors = mutableListOf<String>()

        val trimmedTitle = title.trim()
        when {
            trimmedTitle.isEmpty() -> errors.add("Title is required")
            trimmedTitle.length < MIN_TITLE_LENGTH ->
                errors.add("Title must be at least $MIN_TITLE_LENGTH characters")
            trimmedTitle.length > MAX_TITLE_LENGTH ->
                errors.add("Title cannot exceed $MAX_TITLE_LENGTH characters")
        }

        val trimmedDescription = description.trim()
        if (trimmedDescription.length > MAX_DESCRIPTION_LENGTH) {
            errors.add("Description cannot exceed $MAX_DESCRIPTION_LENGTH characters")
        }

        if (quantity < 1) {
            errors.add("Quantity must be at least 1")
        }

        return ValidationResult(
            isValid = errors.isEmpty(),
            errors = errors
        )
    }
}
