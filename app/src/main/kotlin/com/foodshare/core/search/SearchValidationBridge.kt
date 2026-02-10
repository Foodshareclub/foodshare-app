package com.foodshare.core.search

import kotlinx.serialization.Serializable

/**
 * Search validation bridge.
 *
 * Architecture (Frameo pattern):
 * - Pure Kotlin implementation mirroring Swift SearchValidator
 * - Ensures cross-platform validation consistency
 * - Ready for swift-java migration when bindings are regenerated
 *
 * Swift source: foodshare-core/Sources/FoodshareCore/Validation/SearchValidator.swift
 */
object SearchValidationBridge {

    // ========================================================================
    // Configuration (synced with Swift SearchValidator)
    // ========================================================================

    const val MIN_QUERY_LENGTH = 1
    const val MAX_QUERY_LENGTH = 200
    const val MIN_RADIUS_KM = 0.1
    const val MAX_RADIUS_KM = 100.0
    const val MAX_FILTERS = 20
    const val DEFAULT_PAGE_SIZE = 20
    const val MAX_PAGE_SIZE = 100

    // Characters to remove from search queries
    private val INVALID_CHARACTERS = setOf('<', '>', '{', '}', '[', ']', '\\', '|')

    // ========================================================================
    // Query Validation
    // ========================================================================

    /**
     * Validate a search query.
     *
     * @param query The search query
     * @return Validation result
     */
    fun validateQuery(query: String): SearchValidationResult {
        val errors = mutableListOf<SearchValidationError>()
        val sanitized = sanitizeQuery(query)

        when {
            sanitized.isEmpty() -> errors.add(
                SearchValidationError(
                    field = "query",
                    code = "required",
                    message = "Search query is required"
                )
            )
            sanitized.length < MIN_QUERY_LENGTH -> errors.add(
                SearchValidationError(
                    field = "query",
                    code = "too_short",
                    message = "Search query must be at least $MIN_QUERY_LENGTH character"
                )
            )
            sanitized.length > MAX_QUERY_LENGTH -> errors.add(
                SearchValidationError(
                    field = "query",
                    code = "too_long",
                    message = "Search query cannot exceed $MAX_QUERY_LENGTH characters"
                )
            )
        }

        return SearchValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            sanitizedQuery = sanitized.takeIf { errors.isEmpty() }
        )
    }

    /**
     * Validate search with filters.
     *
     * @param query Optional search query
     * @param filters Search filters
     * @return Validation result
     */
    fun validateSearch(
        query: String?,
        filters: SearchFiltersInput
    ): SearchValidationResult {
        val errors = mutableListOf<SearchValidationError>()
        var sanitizedQuery: String? = null

        // Validate query if provided
        query?.let { q ->
            val queryResult = validateQuery(q)
            if (!queryResult.isValid) {
                errors.addAll(queryResult.errors)
            }
            sanitizedQuery = queryResult.sanitizedQuery
        }

        // Validate radius
        filters.radiusKm?.let { radius ->
            when {
                radius < MIN_RADIUS_KM -> errors.add(
                    SearchValidationError(
                        field = "radius",
                        code = "too_small",
                        message = "Search radius must be at least $MIN_RADIUS_KM km"
                    )
                )
                radius > MAX_RADIUS_KM -> errors.add(
                    SearchValidationError(
                        field = "radius",
                        code = "too_large",
                        message = "Search radius cannot exceed $MAX_RADIUS_KM km"
                    )
                )
            }
        }

        // Validate page size
        filters.pageSize?.let { pageSize ->
            when {
                pageSize < 1 -> errors.add(
                    SearchValidationError(
                        field = "pageSize",
                        code = "invalid",
                        message = "Page size must be at least 1"
                    )
                )
                pageSize > MAX_PAGE_SIZE -> errors.add(
                    SearchValidationError(
                        field = "pageSize",
                        code = "too_large",
                        message = "Page size cannot exceed $MAX_PAGE_SIZE"
                    )
                )
            }
        }

        // Validate filter count
        val totalFilters = filters.categories.size +
            filters.dietaryPreferences.size +
            (if (filters.radiusKm != null) 1 else 0) +
            (if (filters.minRating != null) 1 else 0)

        if (totalFilters > MAX_FILTERS) {
            errors.add(
                SearchValidationError(
                    field = "filters",
                    code = "too_many",
                    message = "Maximum $MAX_FILTERS filters allowed"
                )
            )
        }

        return SearchValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            sanitizedQuery = sanitizedQuery
        )
    }

    // ========================================================================
    // Query Sanitization
    // ========================================================================

    /**
     * Sanitize a search query.
     *
     * @param query The query to sanitize
     * @return Sanitized query
     */
    fun sanitizeQuery(query: String): String {
        var result = query.trim()

        // Remove excessive whitespace
        while (result.contains("  ")) {
            result = result.replace("  ", " ")
        }

        // Remove problematic characters
        result = result.filterNot { it in INVALID_CHARACTERS }

        return result
    }

    /**
     * Extract search terms from query.
     *
     * @param query The search query
     * @return List of search terms
     */
    fun extractTerms(query: String): List<String> {
        val sanitized = sanitizeQuery(query)
        return sanitized
            .split(" ")
            .filter { it.isNotEmpty() && it.length >= 2 }
    }

    /**
     * Check if query is valid for autocomplete.
     *
     * @param query The query to check
     * @return True if valid for autocomplete
     */
    fun isValidForAutocomplete(query: String): Boolean {
        val sanitized = sanitizeQuery(query)
        return sanitized.length >= MIN_QUERY_LENGTH && sanitized.length <= MAX_QUERY_LENGTH
    }

    // ========================================================================
    // Location Validation
    // ========================================================================

    /**
     * Validate search location.
     *
     * @param latitude Latitude coordinate
     * @param longitude Longitude coordinate
     * @return Validation result
     */
    fun validateLocation(
        latitude: Double,
        longitude: Double
    ): SearchValidationResult {
        val errors = mutableListOf<SearchValidationError>()

        if (latitude < -90 || latitude > 90) {
            errors.add(
                SearchValidationError(
                    field = "latitude",
                    code = "invalid",
                    message = "Latitude must be between -90 and 90"
                )
            )
        }

        if (longitude < -180 || longitude > 180) {
            errors.add(
                SearchValidationError(
                    field = "longitude",
                    code = "invalid",
                    message = "Longitude must be between -180 and 180"
                )
            )
        }

        return SearchValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            sanitizedQuery = null
        )
    }
}

// ========================================================================
// Data Classes
// ========================================================================

/**
 * Search filters input.
 */
@Serializable
data class SearchFiltersInput(
    val categories: List<String> = emptyList(),
    val dietaryPreferences: List<String> = emptyList(),
    val radiusKm: Double? = null,
    val minRating: Double? = null,
    val pageSize: Int? = null,
    val availableOnly: Boolean = true
) {
    companion object {
        val EMPTY = SearchFiltersInput()
    }
}

/**
 * Search validation result.
 */
@Serializable
data class SearchValidationResult(
    val isValid: Boolean,
    val errors: List<SearchValidationError>,
    val sanitizedQuery: String? = null
) {
    val firstError: SearchValidationError?
        get() = errors.firstOrNull()

    fun errorFor(field: String): SearchValidationError? =
        errors.find { it.field == field }
}

/**
 * Search validation error.
 */
@Serializable
data class SearchValidationError(
    val field: String,
    val code: String,
    val message: String
)
