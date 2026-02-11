package com.foodshare.core.errors

/**
 * Centralized UI error handler that maps exceptions to user-friendly messages.
 *
 * This object provides a consistent interface for handling errors in UI components
 * (ViewModels, Composables). It uses ErrorBridge's domain-specific mappers and
 * categorization to provide appropriate error messages.
 *
 * Use this for:
 * - Generic error handling when you don't know the domain context
 * - Fallback error handling
 * - Quick error categorization (network, auth, etc.)
 *
 * For domain-specific contexts (listings, profile, etc.), prefer using the
 * specialized ErrorBridge methods directly (e.g., ErrorBridge.mapListingError).
 *
 * Example usage:
 * ```
 * // Simple error handling
 * try {
 *     performOperation()
 * } catch (e: Exception) {
 *     val message = UiErrorHandler.handle(e)
 *     showError(message)
 * }
 *
 * // With fallback message
 * val errorMessage = UiErrorHandler.handleOrDefault(
 *     error = exception,
 *     default = "Could not load data"
 * )
 *
 * // Quick categorization
 * val category = ErrorBridge.quickCategorize(exception)
 * if (category.isRetryable) {
 *     // Show retry button
 * }
 * ```
 */
object UiErrorHandler {

    /**
     * Map an exception to a user-friendly error message.
     *
     * This uses ErrorBridge's quick categorization to determine the error type
     * and provide an appropriate message. For more specific error handling,
     * use domain-specific mappers like ErrorBridge.mapListingError().
     *
     * @param error The exception to handle
     * @return User-friendly error message
     */
    fun handle(error: Throwable): String {
        val category = ErrorBridge.quickCategorize(error)

        return when (category) {
            SimpleErrorCategory.NETWORK -> "No internet connection. Please check your network."
            SimpleErrorCategory.TIMEOUT -> "Request timed out. Please try again."
            SimpleErrorCategory.AUTHENTICATION -> "Authentication failed. Please sign in again."
            SimpleErrorCategory.AUTHORIZATION -> "You don't have permission to perform this action."
            SimpleErrorCategory.NOT_FOUND -> "The requested item could not be found."
            SimpleErrorCategory.CONFLICT -> "The data was modified. Please refresh and try again."
            SimpleErrorCategory.VALIDATION -> error.message ?: "Please check your input and try again."
            SimpleErrorCategory.RATE_LIMITED -> "Too many requests. Please wait a moment."
            SimpleErrorCategory.SERVER -> "Server error. Please try again later."
            SimpleErrorCategory.UNKNOWN -> error.message ?: "An unexpected error occurred"
        }
    }

    /**
     * Handle a nullable error with a default message.
     *
     * Useful for optional error handling where you want to provide a
     * context-specific default message.
     *
     * @param error The nullable exception to handle
     * @param default The default message if error is null (default: "An unexpected error occurred")
     * @return User-friendly error message
     */
    fun handleOrDefault(error: Throwable?, default: String = "An unexpected error occurred"): String {
        return error?.let { handle(it) } ?: default
    }
}
