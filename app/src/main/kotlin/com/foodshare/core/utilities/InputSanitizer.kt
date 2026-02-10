package com.foodshare.core.utilities

import android.net.Uri

/**
 * Input sanitization utilities for security.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for text sanitization
 * - No JNI required for these pure string operations
 */
object InputSanitizer {

    // MARK: - Text Sanitization

    /**
     * Sanitize text input by normalizing whitespace and removing control characters.
     */
    fun sanitizeText(input: String): String {
        return input
            .trim()
            // Normalize newlines (CRLF and CR to LF)
            .replace("\r\n", "\n")
            .replace("\r", "\n")
            // Collapse multiple spaces to single space
            .replace(Regex("[ \\t]+"), " ")
            // Collapse multiple newlines to max 2
            .replace(Regex("\\n{3,}"), "\n\n")
            // Remove zero-width characters
            .replace(Regex("[\\u200B-\\u200D\\uFEFF]"), "")
    }

    /**
     * Escape HTML special characters to prevent XSS attacks.
     */
    fun escapeHTML(input: String): String {
        return input
            .replace("&", "&amp;")   // Must be first
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&#39;")
    }

    /**
     * Strip all HTML tags from input.
     */
    fun stripHTML(input: String): String {
        return input
            // Remove script/style tags and their content
            .replace(Regex("<script[^>]*>[\\s\\S]*?</script>", RegexOption.IGNORE_CASE), "")
            .replace(Regex("<style[^>]*>[\\s\\S]*?</style>", RegexOption.IGNORE_CASE), "")
            // Remove all HTML tags
            .replace(Regex("<[^>]+>"), "")
            // Decode common HTML entities
            .replace("&nbsp;", " ")
            .replace("&amp;", "&")
            .replace("&lt;", "<")
            .replace("&gt;", ">")
            .replace("&quot;", "\"")
            .replace("&#39;", "'")
            // Clean up whitespace
            .trim()
    }

    /**
     * Sanitize for SQL (basic protection - always use parameterized queries)
     */
    fun sanitizeForSQL(input: String): String {
        return input
            .replace("'", "''")
            .replace("\\", "\\\\")
    }

    // MARK: - URL Sanitization

    /**
     * Validate and sanitize URL string
     * @return Sanitized URL or null if invalid
     */
    fun sanitizeURL(input: String): String? {
        val trimmed = input.trim()

        return try {
            val uri = Uri.parse(trimmed)
            val scheme = uri.scheme?.lowercase()

            if (scheme == "http" || scheme == "https") {
                uri.toString()
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    // MARK: - Email Sanitization

    /**
     * Sanitize email address
     */
    fun sanitizeEmail(input: String): String {
        return input.trim().lowercase()
    }

    // MARK: - Filename Sanitization

    /**
     * Sanitize filename for safe storage
     */
    fun sanitizeFilename(input: String): String {
        // Remove path separators and dangerous characters
        val dangerousChars = setOf('/', '\\', ':', '*', '?', '"', '<', '>', '|')
        var sanitized = input.filter { it !in dangerousChars }

        // Remove leading dots (hidden files)
        sanitized = sanitized.trimStart('.')

        // Limit length
        if (sanitized.length > 255) {
            sanitized = sanitized.take(255)
        }

        // Ensure not empty
        if (sanitized.isEmpty()) {
            sanitized = "unnamed"
        }

        return sanitized
    }

    // MARK: - Length Validation

    /**
     * Truncate string to maximum length
     */
    fun truncate(input: String, maxLength: Int): String {
        return if (input.length <= maxLength) {
            input
        } else {
            input.take(maxLength)
        }
    }

    /**
     * Validate string length is within bounds
     */
    fun validateLength(input: String, min: Int = 0, max: Int = Int.MAX_VALUE): Boolean {
        return input.length in min..max
    }
}

/**
 * Validation patterns for common input types
 */
object ValidationPattern {
    /** Email regex pattern */
    val email = Regex("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")

    /** Phone number pattern (basic) */
    val phone = Regex("^[+]?[0-9]{10,15}$")

    /** Username pattern (alphanumeric + underscore) */
    val username = Regex("^[a-zA-Z0-9_]{3,30}$")

    /** Strong password pattern */
    val strongPassword = Regex("^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@\$!%*?&])[A-Za-z\\d@\$!%*?&]{8,}$")

    /**
     * Check if string matches pattern
     */
    fun matches(input: String, pattern: Regex): Boolean {
        return pattern.matches(input)
    }
}

// MARK: - String Extensions

/**
 * Sanitized version of the string
 */
val String.sanitized: String
    get() = InputSanitizer.sanitizeText(this)

/**
 * HTML-escaped version of the string
 */
val String.htmlEscaped: String
    get() = InputSanitizer.escapeHTML(this)

/**
 * HTML-stripped version of the string
 */
val String.htmlStripped: String
    get() = InputSanitizer.stripHTML(this)

/**
 * Truncated to max length
 */
fun String.truncated(maxLength: Int): String =
    InputSanitizer.truncate(this, maxLength)

/**
 * Check if string is within length bounds
 */
fun String.isWithinLength(min: Int = 0, max: Int = Int.MAX_VALUE): Boolean =
    InputSanitizer.validateLength(this, min, max)
