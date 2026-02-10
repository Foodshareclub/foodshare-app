package com.foodshare.swift

import kotlinx.serialization.Serializable

/**
 * Result of validation operations.
 * Mirrors Swift's ValidationResult struct.
 */
@Serializable
data class ValidationResult(
    val isValid: Boolean,
    val errors: List<String> = emptyList()
) {
    val firstError: String?
        get() = errors.firstOrNull()
    
    companion object {
        val VALID = ValidationResult(isValid = true, errors = emptyList())
    }
}
