package com.foodshare.core.errors

import com.foodshare.swift.AuthErrorCategory
import com.foodshare.swift.AuthMappedError
import com.foodshare.swift.CategorizedError
import com.foodshare.swift.ErrorCategory
import com.foodshare.swift.ErrorReportDecision
import com.foodshare.swift.ErrorSeverity
import com.foodshare.swift.NetworkErrorCategory
import com.foodshare.swift.NetworkMappedError
import com.foodshare.swift.RecoveryAction
import com.foodshare.swift.RecoveryStrategy
import com.foodshare.swift.RetryEligibility
import com.foodshare.swift.UserFriendlyError
import com.foodshare.swift.UserGuidance
import com.foodshare.swift.generated.ErrorMappingEngine as SwiftErrorMappingEngine
import org.swift.swiftkit.core.SwiftArena

/**
 * Error categorization and recovery bridge.
 *
 * Architecture (Frameo pattern):
 * - Core error categorization and recovery via Swift engine for cross-platform consistency
 * - Domain-specific error mapping in Kotlin for Android-specific patterns
 */
object ErrorBridge {

    // SwiftArena for memory management of Swift objects
    private val arena: SwiftArena by lazy { SwiftArena.ofAuto() }

    // MARK: - Auth Error Mapping

    /**
     * Map an authentication error to a user-friendly message.
     * This delegates to Swift AuthErrorMapper for consistent error messages across platforms.
     *
     * @param error The Throwable from the auth operation
     * @return User-friendly error message string
     */
    fun mapAuthError(error: Throwable): String {
        return mapAuthError(error.message ?: "Unknown error", extractErrorCode(error))
    }

    /**
     * Map an authentication error message to a user-friendly message.
     *
     * @param errorMessage The error message from Supabase/auth provider
     * @param errorCode Optional error code if available
     * @return User-friendly error message string
     */
    fun mapAuthError(errorMessage: String, errorCode: String? = null): String {
        return mapAuthErrorFull(errorMessage, errorCode).message
    }

    /**
     * Map an authentication error with full details using Swift engine for cross-platform consistency.
     *
     * @param errorMessage The error message from Supabase/auth provider
     * @param errorCode Optional error code if available
     * @return AuthMappedError with message, category, and recovery info
     */
    fun mapAuthErrorFull(errorMessage: String, errorCode: String? = null): AuthMappedError {
        val swiftResult = SwiftErrorMappingEngine.mapAuthError(errorMessage, errorCode ?: "", arena)

        // Map Swift category string to Kotlin enum
        val category = when (swiftResult.category) {
            "invalid_credentials" -> AuthErrorCategory.INVALID_CREDENTIALS
            "email_not_confirmed" -> AuthErrorCategory.EMAIL_NOT_CONFIRMED
            "user_exists" -> AuthErrorCategory.USER_EXISTS
            "user_not_found" -> AuthErrorCategory.USER_NOT_FOUND
            "rate_limited" -> AuthErrorCategory.RATE_LIMITED
            "session_expired" -> AuthErrorCategory.SESSION_EXPIRED
            "weak_password" -> AuthErrorCategory.WEAK_PASSWORD
            "invalid_email" -> AuthErrorCategory.INVALID_EMAIL
            "network_error" -> AuthErrorCategory.NETWORK_ERROR
            "oauth_error" -> AuthErrorCategory.OAUTH_ERROR
            "account_disabled" -> AuthErrorCategory.ACCOUNT_DISABLED
            else -> AuthErrorCategory.UNKNOWN
        }

        return AuthMappedError(
            message = swiftResult.message,
            category = category,
            isRecoverable = swiftResult.isRecoverable,
            suggestion = swiftResult.suggestion
        )
    }

    /**
     * Map a network error to a user-friendly message.
     *
     * @param errorMessage The error message
     * @param statusCode Optional HTTP status code
     * @return User-friendly error message string
     */
    fun mapNetworkError(errorMessage: String, statusCode: Int? = null): String {
        return mapNetworkErrorFull(errorMessage, statusCode).message
    }

    /**
     * Map a network error with full details.
     */
    fun mapNetworkErrorFull(errorMessage: String, statusCode: Int? = null): NetworkMappedError {
        val lowerMessage = errorMessage.lowercase()

        return when {
            statusCode == 429 || lowerMessage.contains("rate limit") -> NetworkMappedError(
                message = "Too many requests. Please wait a moment.",
                category = NetworkErrorCategory.RATE_LIMITED,
                isRetryable = true
            )

            statusCode in 500..599 -> NetworkMappedError(
                message = "Server error. Please try again later.",
                category = NetworkErrorCategory.SERVER_ERROR,
                isRetryable = true
            )

            statusCode == null || statusCode == 0 || lowerMessage.contains("offline") ||
            lowerMessage.contains("no internet") || lowerMessage.contains("unreachable") -> NetworkMappedError(
                message = "No internet connection",
                category = NetworkErrorCategory.OFFLINE,
                isRetryable = true
            )

            lowerMessage.contains("timeout") || lowerMessage.contains("timed out") -> NetworkMappedError(
                message = "Request timed out. Please try again.",
                category = NetworkErrorCategory.TIMEOUT,
                isRetryable = true
            )

            else -> NetworkMappedError(
                message = "Network error. Please try again.",
                category = NetworkErrorCategory.UNKNOWN,
                isRetryable = true
            )
        }
    }

    // MARK: - Private Helpers

    /**
     * Extract error code from a Throwable if available.
     */
    private fun extractErrorCode(error: Throwable): String? {
        // Check for common patterns in error message that indicate codes
        val message = error.message ?: return null
        val patterns = listOf(
            Regex("code[=:]\\s*([A-Z_]+)", RegexOption.IGNORE_CASE),
            Regex("error[=:]\\s*([A-Z_]+)", RegexOption.IGNORE_CASE)
        )
        for (pattern in patterns) {
            val match = pattern.find(message)
            if (match != null) {
                return match.groupValues[1]
            }
        }
        return null
    }

    // MARK: - Error Categorization (Swift-backed for cross-platform consistency)

    /**
     * Categorize an error based on code, message, and optional status code.
     * Uses Swift engine for cross-platform consistent categorization.
     * Returns category, severity, transience, and other metadata.
     */
    fun categorizeError(
        code: String,
        message: String,
        domain: String = "App",
        statusCode: Int? = null
    ): CategorizedError {
        val swiftResult = SwiftErrorMappingEngine.categorizeError(code, message, statusCode ?: 0, arena)

        // Map Swift category string to Kotlin enum
        val category = mapCategoryString(swiftResult.category)

        // Map Swift severity string to Kotlin enum
        val severity = when (swiftResult.severity) {
            "low" -> ErrorSeverity.LOW
            "medium" -> ErrorSeverity.MEDIUM
            "high" -> ErrorSeverity.HIGH
            "critical" -> ErrorSeverity.CRITICAL
            else -> ErrorSeverity.MEDIUM
        }

        return CategorizedError(
            category = category,
            severity = severity,
            isTransient = swiftResult.isTransient,
            isRetryable = swiftResult.isRetryable,
            requiresUserAction = swiftResult.requiresUserAction(),
            shouldReport = swiftResult.shouldReport(),
            displayName = swiftResult.displayName
        )
    }

    // Helper to map Swift category string to Kotlin enum
    private fun mapCategoryString(categoryStr: String): ErrorCategory {
        return when (categoryStr) {
            "network" -> ErrorCategory.NETWORK
            "timeout" -> ErrorCategory.TIMEOUT
            "authentication" -> ErrorCategory.AUTHENTICATION
            "authorization" -> ErrorCategory.AUTHORIZATION
            "validation" -> ErrorCategory.VALIDATION
            "not_found" -> ErrorCategory.NOT_FOUND
            "conflict" -> ErrorCategory.CONFLICT
            "rate_limit" -> ErrorCategory.RATE_LIMIT
            "server" -> ErrorCategory.SERVER
            "service_unavailable" -> ErrorCategory.SERVICE_UNAVAILABLE
            "storage" -> ErrorCategory.STORAGE
            "parse" -> ErrorCategory.PARSE
            "client" -> ErrorCategory.CLIENT
            else -> ErrorCategory.UNKNOWN
        }
    }

    /**
     * Categorize an HTTP error by status code.
     */
    fun categorizeHttpError(statusCode: Int, message: String = ""): CategorizedError {
        return categorizeError(
            code = "HTTP_$statusCode",
            message = message.ifEmpty { getHttpStatusMessage(statusCode) },
            domain = "HTTP",
            statusCode = statusCode
        )
    }

    /**
     * Categorize a Supabase error.
     */
    fun categorizeSupabaseError(code: String, message: String): CategorizedError {
        return categorizeError(
            code = code,
            message = message,
            domain = "Supabase"
        )
    }

    /**
     * Categorize a network/connectivity error.
     */
    fun categorizeNetworkError(message: String = "Network connection unavailable"): CategorizedError {
        return categorizeError(
            code = "NETWORK_OFFLINE",
            message = message,
            domain = "Network"
        )
    }

    // MARK: - Recovery Strategy (Swift-backed for cross-platform consistency)

    /**
     * Get a recovery strategy for an error category using Swift engine.
     * Returns recommended actions, delays, and user guidance.
     */
    fun getRecoveryStrategy(
        category: ErrorCategory,
        severity: ErrorSeverity? = null
    ): RecoveryStrategy {
        val categoryStr = when (category) {
            ErrorCategory.NETWORK -> "network"
            ErrorCategory.TIMEOUT -> "timeout"
            ErrorCategory.AUTHENTICATION -> "authentication"
            ErrorCategory.AUTHORIZATION -> "authorization"
            ErrorCategory.VALIDATION -> "validation"
            ErrorCategory.NOT_FOUND -> "not_found"
            ErrorCategory.CONFLICT -> "conflict"
            ErrorCategory.RATE_LIMIT -> "rate_limit"
            ErrorCategory.SERVER -> "server"
            ErrorCategory.SERVICE_UNAVAILABLE -> "service_unavailable"
            ErrorCategory.STORAGE -> "storage"
            ErrorCategory.PARSE -> "parse"
            ErrorCategory.CLIENT -> "client"
            ErrorCategory.UNKNOWN -> "unknown"
        }

        val swiftResult = SwiftErrorMappingEngine.getRecoveryStrategy(categoryStr, arena)

        // Map Swift action string to Kotlin enum
        val primaryAction = mapActionString(swiftResult.primaryAction)
        val fallbackAction = mapActionString(swiftResult.fallbackAction)

        // Parse alternative actions JSON
        val alternativeActions = parseActionsJson(swiftResult.alternativeActionsJson)

        return RecoveryStrategy(
            primaryAction = primaryAction,
            alternativeActions = alternativeActions,
            fallbackAction = fallbackAction,
            autoRecoveryPossible = swiftResult.isAutoRecoveryPossible,
            recommendedDelaySeconds = swiftResult.recommendedDelaySeconds,
            maxRetries = swiftResult.maxRetries,
            shouldRetry = swiftResult.shouldRetry(),
            guidance = UserGuidance(
                title = swiftResult.guidanceTitle,
                message = swiftResult.guidanceMessage,
                actionLabel = swiftResult.guidanceActionLabel
            )
        )
    }

    // Helper to map Swift action string to Kotlin enum
    private fun mapActionString(actionStr: String): RecoveryAction {
        return when (actionStr) {
            "retry" -> RecoveryAction.RETRY
            "wait_and_retry" -> RecoveryAction.WAIT_AND_RETRY
            "check_connection" -> RecoveryAction.CHECK_CONNECTION
            "reauthenticate" -> RecoveryAction.REAUTHENTICATE
            "refresh_token" -> RecoveryAction.REFRESH_TOKEN
            "fix_input" -> RecoveryAction.FIX_INPUT
            "clear_cache" -> RecoveryAction.CLEAR_CACHE
            "enable_offline_mode" -> RecoveryAction.ENABLE_OFFLINE_MODE
            "contact_support" -> RecoveryAction.CONTACT_SUPPORT
            else -> RecoveryAction.DISMISS
        }
    }

    // Helper to parse actions JSON array
    private fun parseActionsJson(json: String): List<RecoveryAction> {
        return try {
            // Simple JSON array parsing
            json.trim()
                .removePrefix("[")
                .removeSuffix("]")
                .split(",")
                .mapNotNull { it.trim().removeSurrounding("\"").takeIf { s -> s.isNotEmpty() } }
                .map { mapActionString(it) }
        } catch (e: Exception) {
            emptyList()
        }
    }

    /**
     * Get a recovery strategy for a categorized error.
     */
    fun getRecoveryStrategy(error: CategorizedError): RecoveryStrategy {
        return getRecoveryStrategy(error.category, error.severity)
    }

    /**
     * Convenience: Get recovery strategy from an exception.
     */
    fun getRecoveryStrategy(exception: Throwable): RecoveryStrategy {
        val categorized = categorizeFromException(exception)
        return getRecoveryStrategy(categorized)
    }

    // MARK: - User-Friendly Messages

    /**
     * Map an error to a user-friendly display message.
     * Includes title, message, icon, and display style.
     */
    fun mapToUserFriendlyError(
        code: String,
        message: String,
        statusCode: Int? = null
    ): UserFriendlyError {
        val categorized = categorizeError(code, message, statusCode = statusCode)
        val strategy = getRecoveryStrategy(categorized.category)

        val (title, userMessage, icon, style) = when (categorized.category) {
            ErrorCategory.NETWORK -> listOf(
                "Connection Error",
                "Please check your internet connection and try again.",
                "wifi_off",
                "warning"
            )
            ErrorCategory.TIMEOUT -> listOf(
                "Request Timeout",
                "The request took too long. Please try again.",
                "schedule",
                "warning"
            )
            ErrorCategory.AUTHENTICATION -> listOf(
                "Authentication Error",
                "Please sign in again to continue.",
                "lock",
                "error"
            )
            ErrorCategory.AUTHORIZATION -> listOf(
                "Access Denied",
                "You don't have permission to perform this action.",
                "block",
                "error"
            )
            ErrorCategory.VALIDATION -> listOf(
                "Invalid Input",
                message.ifBlank { "Please check your input and try again." },
                "error",
                "warning"
            )
            ErrorCategory.NOT_FOUND -> listOf(
                "Not Found",
                "The requested item could not be found.",
                "search_off",
                "info"
            )
            ErrorCategory.RATE_LIMIT -> listOf(
                "Too Many Requests",
                "Please wait a moment before trying again.",
                "timer",
                "warning"
            )
            ErrorCategory.SERVER, ErrorCategory.SERVICE_UNAVAILABLE -> listOf(
                "Server Error",
                "Something went wrong on our end. Please try again later.",
                "cloud_off",
                "error"
            )
            ErrorCategory.CONFLICT -> listOf(
                "Conflict",
                "The data was modified. Please refresh and try again.",
                "sync_problem",
                "warning"
            )
            else -> listOf(
                "Error",
                message.ifBlank { "An unexpected error occurred." },
                "warning",
                "error"
            )
        }

        return UserFriendlyError(
            title = title,
            message = userMessage,
            suggestion = strategy.guidance?.message,
            icon = icon,
            style = style,
            dismissable = !categorized.requiresUserAction,
            showRetry = categorized.isRetryable
        )
    }

    /**
     * Map a categorized error to user-friendly display.
     */
    fun mapToUserFriendlyError(error: CategorizedError): UserFriendlyError {
        return mapToUserFriendlyError(
            code = error.displayName,
            message = error.displayName,
            statusCode = null
        )
    }

    /**
     * Map HTTP status code to user-friendly error.
     */
    fun mapHttpStatusToUserError(statusCode: Int): UserFriendlyError {
        val categorized = categorizeHttpError(statusCode)
        return mapToUserFriendlyError(categorized)
    }

    // MARK: - Retry Eligibility

    /**
     * Check if an error is retryable.
     * Returns eligibility, recommended delay, and retry configuration.
     */
    fun isRetryable(
        code: String,
        message: String,
        category: ErrorCategory,
        statusCode: Int? = null,
        attemptCount: Int = 0
    ): RetryEligibility {
        val maxAttempts = when (category) {
            ErrorCategory.NETWORK, ErrorCategory.TIMEOUT -> 3
            ErrorCategory.RATE_LIMIT -> 3
            ErrorCategory.SERVER, ErrorCategory.SERVICE_UNAVAILABLE -> 3
            ErrorCategory.CONFLICT -> 1
            else -> 0
        }

        if (attemptCount >= maxAttempts) {
            return RetryEligibility.notRetryable("Max attempts ($maxAttempts) reached")
        }

        val canRetry = category in listOf(
            ErrorCategory.NETWORK,
            ErrorCategory.TIMEOUT,
            ErrorCategory.RATE_LIMIT,
            ErrorCategory.SERVER,
            ErrorCategory.SERVICE_UNAVAILABLE,
            ErrorCategory.CONFLICT
        )

        if (!canRetry) {
            return RetryEligibility.notRetryable("Error type is not retryable")
        }

        // Calculate delay with exponential backoff
        val baseDelay = when (category) {
            ErrorCategory.RATE_LIMIT -> 30000
            ErrorCategory.SERVER, ErrorCategory.SERVICE_UNAVAILABLE -> 5000
            else -> 1000
        }
        val delay = (baseDelay * (1 shl attemptCount)).coerceAtMost(60000)

        return RetryEligibility(
            canRetry = true,
            reason = "Transient error - retry recommended",
            recommendedDelayMs = delay,
            confidence = 0.8,
            maxAttempts = maxAttempts,
            backoffMultiplier = 2.0,
            useJitter = true
        )
    }

    /**
     * Check if a categorized error is retryable.
     */
    fun isRetryable(error: CategorizedError, attemptCount: Int = 0): RetryEligibility {
        return isRetryable(
            code = error.displayName,
            message = error.displayName,
            category = error.category,
            statusCode = null,
            attemptCount = attemptCount
        )
    }

    /**
     * Quick check if an error category is generally retryable.
     */
    fun isQuickRetryable(category: ErrorCategory): Boolean {
        return when (category) {
            ErrorCategory.NETWORK,
            ErrorCategory.TIMEOUT,
            ErrorCategory.SERVER,
            ErrorCategory.SERVICE_UNAVAILABLE,
            ErrorCategory.RATE_LIMIT -> true
            else -> false
        }
    }

    // MARK: - Error Reporting

    /**
     * Check if an error should be reported to analytics/crash reporting.
     * Considers severity, category, and sampling rules.
     */
    fun shouldReportError(
        code: String,
        message: String,
        category: ErrorCategory,
        severity: ErrorSeverity
    ): ErrorReportDecision {
        // Always report high/critical severity
        if (severity == ErrorSeverity.HIGH || severity == ErrorSeverity.CRITICAL) {
            return ErrorReportDecision.report("High/critical severity error")
        }

        // Always report unknown errors
        if (category == ErrorCategory.UNKNOWN) {
            return ErrorReportDecision.report("Unknown error type for investigation")
        }

        // Always report server errors
        if (category == ErrorCategory.SERVER || category == ErrorCategory.SERVICE_UNAVAILABLE) {
            return ErrorReportDecision.report("Server error for monitoring")
        }

        // Skip transient network errors at low severity
        if ((category == ErrorCategory.NETWORK || category == ErrorCategory.TIMEOUT) &&
            severity == ErrorSeverity.LOW) {
            return ErrorReportDecision.skip("Low severity transient error")
        }

        // Skip validation errors (user input issues)
        if (category == ErrorCategory.VALIDATION && severity == ErrorSeverity.LOW) {
            return ErrorReportDecision.skip("User validation error")
        }

        // Report medium severity with sampling
        if (severity == ErrorSeverity.MEDIUM) {
            return ErrorReportDecision(
                shouldReport = true,
                shouldSample = true,
                reason = "Medium severity - sample for trends"
            )
        }

        return ErrorReportDecision.skip("Does not meet reporting criteria")
    }

    /**
     * Check if a categorized error should be reported.
     */
    fun shouldReportError(error: CategorizedError): ErrorReportDecision {
        return shouldReportError(
            code = error.displayName,
            message = error.displayName,
            category = error.category,
            severity = error.severity
        )
    }

    // MARK: - Exception Helpers

    /**
     * Categorize from a Kotlin exception.
     */
    fun categorizeFromException(exception: Throwable): CategorizedError {
        val message = exception.message ?: exception::class.simpleName ?: "Unknown error"
        val code = when (exception) {
            is java.net.UnknownHostException -> "NETWORK_OFFLINE"
            is java.net.SocketTimeoutException -> "TIMEOUT"
            is java.net.ConnectException -> "CONNECTION_FAILED"
            is java.io.IOException -> "IO_ERROR"
            is SecurityException -> "SECURITY_ERROR"
            is IllegalArgumentException -> "VALIDATION_ERROR"
            is IllegalStateException -> "STATE_ERROR"
            else -> "UNKNOWN_ERROR"
        }
        return categorizeError(code, message)
    }

    /**
     * Determine the primary recovery action for an exception.
     */
    fun getPrimaryRecoveryAction(exception: Throwable): RecoveryAction {
        val strategy = getRecoveryStrategy(exception)
        return strategy.primaryAction
    }

    // MARK: - Helpers

    private fun getHttpStatusMessage(statusCode: Int): String {
        return when (statusCode) {
            400 -> "Bad request"
            401 -> "Unauthorized"
            403 -> "Forbidden"
            404 -> "Not found"
            408 -> "Request timeout"
            409 -> "Conflict"
            422 -> "Unprocessable entity"
            429 -> "Too many requests"
            500 -> "Internal server error"
            502 -> "Bad gateway"
            503 -> "Service unavailable"
            504 -> "Gateway timeout"
            else -> "HTTP error $statusCode"
        }
    }

    // MARK: - Domain-Specific Error Mapping (Frameo Pattern)
    // These methods provide consistent error messages across ViewModels

    /**
     * Map a listing-related error to a user-friendly message.
     * Used by CreateListingViewModel, FeedViewModel, etc.
     */
    fun mapListingError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("duplicate") -> "This listing already exists"
            message.contains("permission") || message.contains("unauthorized") ->
                "You don't have permission to manage this listing"
            message.contains("not found") -> "Listing not found"
            message.contains("expired") -> "This listing has expired"
            message.contains("validation") -> "Please check your listing details"
            message.contains("image") || message.contains("photo") ->
                "Failed to upload image. Please try again."
            message.contains("network") || message.contains("connection") ->
                "Connection error. Please check your internet."
            message.contains("timeout") -> "Request timed out. Please try again."
            else -> error.message ?: "Failed to process listing"
        }
    }

    /**
     * Map a profile-related error to a user-friendly message.
     * Used by ProfileViewModel.
     */
    fun mapProfileError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("duplicate") || message.contains("already exists") ->
                "This nickname is already taken"
            message.contains("permission") || message.contains("unauthorized") ->
                "You don't have permission to update this profile"
            message.contains("not found") -> "Profile not found"
            message.contains("validation") -> "Please check your profile details"
            message.contains("avatar") || message.contains("image") ->
                "Failed to upload avatar. Please try again."
            message.contains("network") || message.contains("connection") ->
                "Connection error. Please check your internet."
            else -> error.message ?: "Failed to update profile"
        }
    }

    /**
     * Map a message/chat error to a user-friendly message.
     * Used by ConversationViewModel, MessagesListViewModel.
     */
    fun mapMessageError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("blocked") -> "You cannot message this user"
            message.contains("permission") || message.contains("unauthorized") ->
                "You don't have permission to send messages here"
            message.contains("not found") -> "Conversation not found"
            message.contains("rate limit") -> "Sending too fast. Please slow down."
            message.contains("network") || message.contains("connection") ->
                "Connection error. Message will be sent when online."
            message.contains("timeout") -> "Message sending timed out. Retrying..."
            else -> error.message ?: "Failed to send message"
        }
    }

    /**
     * Map a feed-related error to a user-friendly message.
     * Used by FeedViewModel.
     */
    fun mapFeedError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("network") || message.contains("connection") ->
                "Connection error. Pull to refresh."
            message.contains("timeout") -> "Request timed out. Pull to refresh."
            message.contains("rate limit") -> "Loading too fast. Please wait."
            message.contains("location") -> "Could not determine your location"
            else -> error.message ?: "Failed to load listings"
        }
    }

    /**
     * Map a review-related error to a user-friendly message.
     * Used by ReviewsViewModel.
     */
    fun mapReviewError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("duplicate") || message.contains("already") ->
                "You've already reviewed this"
            message.contains("permission") || message.contains("unauthorized") ->
                "You don't have permission to review this"
            message.contains("not found") -> "Review not found"
            message.contains("self") -> "You cannot review yourself"
            message.contains("network") || message.contains("connection") ->
                "Connection error. Please try again."
            else -> error.message ?: "Failed to submit review"
        }
    }

    /**
     * Map a search-related error to a user-friendly message.
     * Used by SearchViewModel.
     */
    fun mapSearchError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("network") || message.contains("connection") ->
                "Connection error. Please try again."
            message.contains("timeout") -> "Search timed out. Try a simpler query."
            message.contains("rate limit") -> "Searching too fast. Please wait."
            message.contains("invalid") || message.contains("query") ->
                "Invalid search query"
            else -> error.message ?: "Search failed"
        }
    }

    /**
     * Map a forum-related error to a user-friendly message.
     * Used by ForumViewModel, CreateForumPostViewModel.
     */
    fun mapForumError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("duplicate") -> "This post already exists"
            message.contains("permission") || message.contains("unauthorized") ->
                "You don't have permission to post here"
            message.contains("not found") -> "Post not found"
            message.contains("locked") || message.contains("closed") ->
                "This thread is locked"
            message.contains("moderation") -> "Your post is under review"
            message.contains("network") || message.contains("connection") ->
                "Connection error. Please try again."
            else -> error.message ?: "Failed to process forum post"
        }
    }

    /**
     * Map a favorites-related error to a user-friendly message.
     * Used by FeedViewModel for favorite toggle operations.
     */
    fun mapFavoritesError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("not found") -> "Listing no longer available"
            message.contains("network") || message.contains("connection") ->
                "Connection error. Will sync when online."
            else -> error.message ?: "Failed to update favorites"
        }
    }

    /**
     * Map a location-related error to a user-friendly message.
     * Used by MapViewModel.
     */
    fun mapLocationError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("permission") || message.contains("denied") ->
                "Location permission required"
            message.contains("gps") || message.contains("provider") ->
                "Location services unavailable"
            message.contains("timeout") -> "Location request timed out"
            message.contains("network") || message.contains("connection") ->
                "Connection error. Please try again."
            message.contains("accuracy") -> "Could not get accurate location"
            else -> error.message ?: "Location error"
        }
    }

    /**
     * Map an activity feed error to a user-friendly message.
     * Used by ActivityViewModel.
     */
    fun mapActivityError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("network") || message.contains("connection") ->
                "Connection error. Pull to refresh."
            message.contains("timeout") -> "Request timed out. Pull to refresh."
            message.contains("not found") -> "Activity not found"
            else -> error.message ?: "Failed to load activity"
        }
    }

    /**
     * Map a challenge-related error to a user-friendly message.
     * Used by ChallengesViewModel, ChallengeDetailViewModel.
     */
    fun mapChallengeError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("already") || message.contains("duplicate") ->
                "You've already joined this challenge"
            message.contains("expired") || message.contains("ended") ->
                "This challenge has ended"
            message.contains("full") || message.contains("capacity") ->
                "This challenge is full"
            message.contains("not found") -> "Challenge not found"
            message.contains("permission") || message.contains("unauthorized") ->
                "You don't have permission for this challenge"
            message.contains("network") || message.contains("connection") ->
                "Connection error. Please try again."
            else -> error.message ?: "Failed to process challenge"
        }
    }

    /**
     * Map a notification-related error to a user-friendly message.
     * Used by NotificationsViewModel.
     */
    fun mapNotificationError(error: Throwable): String {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("network") || message.contains("connection") ->
                "Connection error. Pull to refresh."
            message.contains("timeout") -> "Request timed out. Pull to refresh."
            message.contains("not found") -> "Notification not found"
            message.contains("permission") -> "Notification permission required"
            else -> error.message ?: "Failed to load notifications"
        }
    }

    /**
     * Simple error categorization for ViewModels.
     * Returns a high-level category that ViewModels can use for UI decisions.
     */
    fun quickCategorize(error: Throwable): SimpleErrorCategory {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("network") || message.contains("connection") ||
            message.contains("offline") || error is java.net.UnknownHostException ||
            error is java.net.ConnectException -> SimpleErrorCategory.NETWORK

            message.contains("timeout") || error is java.net.SocketTimeoutException ->
                SimpleErrorCategory.TIMEOUT

            message.contains("unauthorized") || message.contains("401") ||
            message.contains("authentication") -> SimpleErrorCategory.AUTHENTICATION

            message.contains("permission") || message.contains("403") ||
            message.contains("forbidden") -> SimpleErrorCategory.AUTHORIZATION

            message.contains("not found") || message.contains("404") ->
                SimpleErrorCategory.NOT_FOUND

            message.contains("conflict") || message.contains("409") ->
                SimpleErrorCategory.CONFLICT

            message.contains("validation") || message.contains("400") ||
            message.contains("invalid") -> SimpleErrorCategory.VALIDATION

            message.contains("rate limit") || message.contains("429") ||
            message.contains("too many") -> SimpleErrorCategory.RATE_LIMITED

            message.contains("server") || message.contains("500") ||
            message.contains("503") -> SimpleErrorCategory.SERVER

            else -> SimpleErrorCategory.UNKNOWN
        }
    }
}

/**
 * Simple error category enum for ViewModel UI decisions.
 * Use this when you just need to know if an error is retryable/transient.
 */
enum class SimpleErrorCategory {
    NETWORK,        // Transient - auto-retry appropriate
    TIMEOUT,        // Transient - auto-retry appropriate
    AUTHENTICATION, // Requires re-login
    AUTHORIZATION,  // User lacks permission
    NOT_FOUND,      // Resource doesn't exist
    CONFLICT,       // Concurrent modification
    VALIDATION,     // User input error
    RATE_LIMITED,   // Transient - wait and retry
    SERVER,         // Server error - wait and retry
    UNKNOWN;        // Fallback

    val isTransient: Boolean
        get() = this in listOf(NETWORK, TIMEOUT, RATE_LIMITED, SERVER)

    val isRetryable: Boolean
        get() = this in listOf(NETWORK, TIMEOUT, RATE_LIMITED, SERVER, CONFLICT)

    val requiresUserAction: Boolean
        get() = this in listOf(AUTHENTICATION, VALIDATION, AUTHORIZATION)
}

// MARK: - Extension Functions

/**
 * Extension to check if a CategorizedError suggests the user should be prompted.
 */
val CategorizedError.requiresPrompt: Boolean
    get() = requiresUserAction || !isRetryable

/**
 * Extension to get a simple retry delay in milliseconds.
 */
fun RecoveryStrategy.getDelayMillis(): Long {
    return (recommendedDelaySeconds * 1000).toLong()
}

/**
 * Extension to check if auto-retry is appropriate.
 */
fun RecoveryStrategy.shouldAutoRetry(currentAttempt: Int): Boolean {
    return autoRecoveryPossible && currentAttempt < maxRetries
}
