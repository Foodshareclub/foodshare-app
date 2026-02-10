package com.foodshare.core.search

import kotlinx.serialization.Serializable

/**
 * Search query processing logic.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for query processing
 * - Text processing algorithms don't require Swift interop
 * - Stop words, suggestions, and highlighting are pure functions
 */
object SearchQueryBridge {

    // Stop words to filter from search queries
    private val stopWords = setOf(
        "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for",
        "of", "with", "by", "from", "is", "are", "was", "were", "be", "been",
        "being", "have", "has", "had", "do", "does", "did", "will", "would",
        "could", "should", "may", "might", "must", "shall", "can", "need",
        "i", "me", "my", "we", "our", "you", "your", "he", "she", "it", "they",
        "this", "that", "these", "those", "what", "which", "who", "whom",
        "some", "any", "no", "not", "all", "each", "every", "both", "few",
        "more", "most", "other", "into", "through", "during", "before", "after",
        "above", "below", "between", "under", "again", "further", "then", "once"
    )

    // Food-related keywords for detection
    private val foodKeywords = setOf(
        "food", "meal", "eat", "eating", "cook", "cooking", "recipe", "dish",
        "breakfast", "lunch", "dinner", "snack", "dessert", "appetizer",
        "vegetable", "fruit", "meat", "fish", "chicken", "beef", "pork",
        "bread", "rice", "pasta", "noodle", "soup", "salad", "sandwich",
        "pizza", "burger", "taco", "sushi", "curry", "stew",
        "dairy", "milk", "cheese", "yogurt", "butter", "cream",
        "vegan", "vegetarian", "organic", "fresh", "homemade", "leftover",
        "grocery", "produce", "bakery", "deli", "pantry", "fridge"
    )

    // Common search suggestions
    private val defaultSuggestions = listOf(
        "fresh vegetables", "homemade bread", "organic produce",
        "vegan meals", "gluten-free", "dairy-free", "nearby food",
        "free food", "surplus groceries", "bakery items"
    )

    // ========================================================================
    // Query Processing
    // ========================================================================

    /**
     * Process a search query fully.
     *
     * @param query Raw search query
     * @return ProcessedQuery with normalized form, tokens, and suggestions
     */
    fun processQuery(query: String): ProcessedQuery {
        val normalized = normalizeQuery(query)
        val tokens = tokenize(query)
        val suggestions = if (query.length >= 2) getSuggestions(query) else emptyList()
        val isFoodRelated = tokens.any { it.lowercase() in foodKeywords }

        return ProcessedQuery(
            original = query,
            normalized = normalized,
            tokens = tokens,
            suggestions = suggestions,
            isValid = query.isNotBlank(),
            isFoodRelated = isFoodRelated
        )
    }

    /**
     * Normalize a search query (trim, lowercase, collapse whitespace).
     *
     * @param query Raw search query
     * @return Normalized query string
     */
    fun normalizeQuery(query: String): String {
        return query.trim()
            .lowercase()
            .replace(Regex("\\s+"), " ")
    }

    /**
     * Tokenize a search query into words.
     *
     * @param query Search query
     * @return List of tokens (stop words filtered)
     */
    fun tokenize(query: String): List<String> {
        return normalizeQuery(query)
            .split(" ")
            .filter { it.isNotEmpty() && it !in stopWords }
    }

    // ========================================================================
    // Query Validation
    // ========================================================================

    /**
     * Validate a search query.
     *
     * @param query Search query to validate
     * @return QueryValidationResult with validity and errors
     */
    fun validateQuery(query: String): QueryValidationResult {
        val sanitized = query.trim()
        val errors = mutableListOf<String>()

        // Check minimum length
        if (sanitized.length < 2) {
            errors.add("Search query must be at least 2 characters")
        }

        // Check maximum length
        if (sanitized.length > 100) {
            errors.add("Search query must be less than 100 characters")
        }

        // Check for invalid characters
        val invalidChars = sanitized.filter { !it.isLetterOrDigit() && it != ' ' && it != '-' }
        if (invalidChars.isNotEmpty()) {
            errors.add("Search query contains invalid characters")
        }

        return QueryValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            sanitizedQuery = sanitized.take(100)
        )
    }

    // ========================================================================
    // Suggestions
    // ========================================================================

    /**
     * Get search suggestions based on partial query.
     *
     * @param query Partial search query
     * @return List of suggested queries
     */
    fun getSuggestions(query: String): List<String> {
        val normalized = query.trim().lowercase()
        if (normalized.length < 2) return emptyList()

        // Filter default suggestions that start with or contain the query
        return defaultSuggestions
            .filter { it.contains(normalized) }
            .take(5)
    }

    // ========================================================================
    // Highlight Matching
    // ========================================================================

    /**
     * Get ranges for highlighting matching text in search results.
     *
     * @param text Text to search within
     * @param query Search query
     * @return List of highlight ranges
     */
    fun getHighlightRanges(text: String, query: String): List<HighlightRange> {
        val tokens = tokenize(query)
        if (tokens.isEmpty()) return emptyList()

        val ranges = mutableListOf<HighlightRange>()
        val textLower = text.lowercase()

        for (token in tokens) {
            val tokenLower = token.lowercase()
            var startIndex = 0

            while (true) {
                val index = textLower.indexOf(tokenLower, startIndex)
                if (index == -1) break

                ranges.add(HighlightRange(start = index, length = token.length))
                startIndex = index + 1
            }
        }

        // Sort by position and merge overlapping ranges
        return ranges.sortedBy { it.start }.fold(mutableListOf()) { acc, range ->
            val last = acc.lastOrNull()
            if (last != null && range.start <= last.end) {
                // Merge overlapping
                acc[acc.lastIndex] = HighlightRange(
                    start = last.start,
                    length = maxOf(last.end, range.end) - last.start
                )
            } else {
                acc.add(range)
            }
            acc
        }
    }

    /**
     * Check if query contains food-related terms.
     *
     * @param query Search query
     * @return true if food-related
     */
    fun isFoodRelated(query: String): Boolean {
        val tokens = tokenize(query)
        return tokens.any { it.lowercase() in foodKeywords }
    }
}

// ========================================================================
// Data Classes
// ========================================================================

/**
 * Result of processing a search query.
 */
@Serializable
data class ProcessedQuery(
    val original: String,
    val normalized: String,
    val tokens: List<String> = emptyList(),
    val suggestions: List<String> = emptyList(),
    val isValid: Boolean = true,
    val isFoodRelated: Boolean = false
) {
    companion object {
        fun empty(original: String) = ProcessedQuery(
            original = original,
            normalized = original.trim().lowercase(),
            tokens = emptyList(),
            suggestions = emptyList(),
            isValid = true,
            isFoodRelated = false
        )
    }
}

/**
 * Result of validating a search query.
 */
@Serializable
data class QueryValidationResult(
    val isValid: Boolean,
    val errors: List<String> = emptyList(),
    val sanitizedQuery: String = ""
) {
    val firstError: String?
        get() = errors.firstOrNull()
}

/**
 * Range for highlighting matching text.
 */
@Serializable
data class HighlightRange(
    val start: Int,
    val length: Int
) {
    val end: Int
        get() = start + length
}

// ========================================================================
// Extension Functions
// ========================================================================

/** Process this string as a search query. */
fun String.asSearchQuery(): ProcessedQuery = SearchQueryBridge.processQuery(this)

/** Get normalized form of this search query. */
fun String.normalizeAsQuery(): String = SearchQueryBridge.normalizeQuery(this)

/** Get search suggestions for this partial query. */
fun String.getSearchSuggestions(): List<String> = SearchQueryBridge.getSuggestions(this)
