package com.foodshare.core.search

import com.foodshare.core.validation.ValidationBridge
import com.foodshare.core.validation.ValidationResult

/**
 * Search validation bridge - delegates to swift-java ValidationBridge
 * for cross-platform parity, adds search-specific helpers.
 */
object SearchValidationBridge {

    const val MAX_QUERY_LENGTH = ValidationBridge.MAX_SEARCH_QUERY_LENGTH
    const val MIN_RADIUS_KM = ValidationBridge.MIN_SEARCH_RADIUS_KM
    const val MAX_RADIUS_KM = ValidationBridge.MAX_SEARCH_RADIUS_KM

    fun validateSearchQuery(query: String): ValidationResult {
        return ValidationBridge.validateSearchQuery(query)
    }

    fun validateSearchRadius(radiusKm: Double): Boolean {
        return ValidationBridge.validateSearchRadius(radiusKm)
    }

    fun clampSearchRadius(radiusKm: Double): Double {
        return ValidationBridge.clampSearchRadius(radiusKm)
    }

    fun sanitizeSearchQuery(query: String): String {
        return ValidationBridge.sanitizeText(query)
    }

    fun validateFilters(
        category: String?,
        minDistance: Double?,
        maxDistance: Double?,
        sortBy: String?
    ): List<String> {
        val errors = mutableListOf<String>()
        minDistance?.let {
            if (it < 0) errors.add("Minimum distance cannot be negative")
        }
        maxDistance?.let {
            if (!validateSearchRadius(it)) errors.add("Maximum distance out of range")
        }
        if (minDistance != null && maxDistance != null && minDistance > maxDistance) {
            errors.add("Minimum distance cannot exceed maximum distance")
        }
        val validSorts = setOf("distance", "newest", "oldest", "rating", "relevance")
        sortBy?.let {
            if (it.lowercase() !in validSorts) errors.add("Invalid sort option: $it")
        }
        return errors
    }
}
