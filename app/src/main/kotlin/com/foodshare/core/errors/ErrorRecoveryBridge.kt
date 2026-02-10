package com.foodshare.core.errors

import kotlinx.serialization.Serializable
import kotlin.math.pow

/**
 * Error recovery engine with smart retry strategies.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for error classification and recovery
 * - Exponential backoff, circuit breaker, fallback actions are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - Error type classification from HTTP status and error codes
 * - Severity assessment and user-facing message generation
 * - Retry strategies with exponential backoff and jitter
 * - Circuit breaker pattern for failure protection
 */
object ErrorRecoveryBridge {

    // Recent errors for circuit breaker
    private val recentErrors = mutableListOf<ErrorRecord>()
    private val recentErrorsLock = Any()

    /**
     * Classify an error and determine its characteristics.
     */
    fun classifyError(
        errorCode: String,
        errorMessage: String?,
        httpStatus: Int?,
        context: ErrorContext
    ): ErrorClassification {
        val errorType = determineErrorType(errorCode, httpStatus, errorMessage)
        val severity = determineSeverity(errorType, httpStatus, context)
        val isRetryable = checkRetryable(errorType, httpStatus, context.attemptNumber)
        val isUserFacing = checkUserFacing(errorType, severity)
        val suggestedAction = determineSuggestedAction(errorType, severity, isRetryable)
        val userMessage = generateUserMessage(errorType, severity)

        return ErrorClassification(
            errorCode = errorCode,
            errorType = errorType,
            severity = severity,
            isRetryable = isRetryable,
            isUserFacing = isUserFacing,
            suggestedAction = suggestedAction,
            userMessage = userMessage
        )
    }

    /**
     * Get recovery strategy for an error.
     */
    fun getRecoveryStrategy(
        classification: ErrorClassification,
        context: ErrorContext
    ): RecoveryStrategy {
        val retrySchedule = if (classification.isRetryable) {
            calculateRetrySchedule(classification.errorType, context.attemptNumber)
        } else null

        val fallbackAction = determineFallbackAction(classification.errorType, context.operation)
        val shouldReport = shouldReportError(classification, context)

        return RecoveryStrategy(
            action = classification.suggestedAction,
            retrySchedule = retrySchedule,
            fallbackAction = fallbackAction,
            shouldReport = shouldReport,
            shouldNotifyUser = classification.isUserFacing,
            userMessage = classification.userMessage
        )
    }

    /**
     * Schedule a retry with exponential backoff.
     */
    fun scheduleRetry(operation: String, attemptNumber: Int): RetrySchedule {
        val baseDelay = 1000L // 1 second
        val maxDelay = 30000L // 30 seconds

        val exponentialDelay = baseDelay * 2.0.pow(attemptNumber.toDouble())
        val clampedDelay = minOf(exponentialDelay, maxDelay.toDouble())

        // Add jitter (±25%)
        val jitter = clampedDelay * (Math.random() * 0.5 - 0.25)
        val finalDelay = maxOf(0.0, clampedDelay + jitter).toLong()

        return RetrySchedule(
            delayMs = finalDelay,
            maxAttempts = 5,
            currentAttempt = attemptNumber + 1,
            backoffType = BackoffType.EXPONENTIAL,
            nextRetryAt = System.currentTimeMillis() + finalDelay
        )
    }

    /**
     * Check if circuit breaker should trip.
     */
    fun shouldTripCircuitBreaker(config: CircuitBreakerConfig = CircuitBreakerConfig()): CircuitBreakerDecision {
        synchronized(recentErrorsLock) {
            val now = System.currentTimeMillis()
            val windowStart = now - config.windowDurationMs

            // Filter errors within window
            val errorsInWindow = recentErrors.filter { it.timestamp >= windowStart }

            if (errorsInWindow.size >= config.failureThreshold) {
                return CircuitBreakerDecision(
                    shouldTrip = true,
                    reason = "Failure count ${errorsInWindow.size} exceeded threshold ${config.failureThreshold}",
                    tripDurationMs = config.tripDurationMs,
                    resetAt = now + config.tripDurationMs
                )
            }

            val failureRate = errorsInWindow.size.toDouble() / (config.windowDurationMs / 1000.0)
            if (failureRate >= config.failureRateThreshold) {
                return CircuitBreakerDecision(
                    shouldTrip = true,
                    reason = "Failure rate $failureRate exceeded threshold ${config.failureRateThreshold}",
                    tripDurationMs = config.tripDurationMs,
                    resetAt = now + config.tripDurationMs
                )
            }

            return CircuitBreakerDecision(
                shouldTrip = false,
                reason = null,
                tripDurationMs = 0,
                resetAt = null
            )
        }
    }

    /**
     * Record an error for circuit breaker tracking.
     */
    fun recordError(errorCode: String, operation: String, message: String? = null) {
        synchronized(recentErrorsLock) {
            recentErrors.add(ErrorRecord(
                errorCode = errorCode,
                operation = operation,
                timestamp = System.currentTimeMillis(),
                message = message
            ))

            // Cleanup old errors (keep last 5 minutes)
            val cutoff = System.currentTimeMillis() - 300_000
            recentErrors.removeAll { it.timestamp < cutoff }
        }
    }

    /**
     * Get user-friendly error message.
     */
    fun getUserFriendlyMessage(error: ErrorClassification): String {
        return error.userMessage
    }

    /**
     * Check if error should be reported to analytics.
     */
    fun shouldReportToAnalytics(error: ErrorClassification): Boolean {
        return error.severity == ErrorSeverity.HIGH ||
               error.severity == ErrorSeverity.CRITICAL ||
               error.errorType == ErrorType.UNKNOWN
    }

    // Private helpers

    private fun determineErrorType(
        errorCode: String,
        httpStatus: Int?,
        message: String?
    ): ErrorType {
        if (errorCode.contains("network") || errorCode.contains("connection") ||
            errorCode.contains("timeout") || httpStatus == null) {
            return when {
                errorCode.contains("timeout") -> ErrorType.NETWORK_TIMEOUT
                errorCode.contains("offline") -> ErrorType.NETWORK_OFFLINE
                else -> ErrorType.NETWORK_ERROR
            }
        }

        httpStatus?.let { status ->
            return when (status) {
                400 -> ErrorType.VALIDATION_ERROR
                401 -> ErrorType.AUTHENTICATION_EXPIRED
                403 -> ErrorType.AUTHORIZATION_DENIED
                404 -> ErrorType.RESOURCE_NOT_FOUND
                409 -> ErrorType.CONFLICT_ERROR
                422 -> ErrorType.VALIDATION_ERROR
                429 -> ErrorType.RATE_LIMITED
                in 500..599 -> ErrorType.SERVER_ERROR
                else -> ErrorType.UNKNOWN
            }
        }

        return when {
            errorCode.contains("auth") || errorCode.contains("token") -> ErrorType.AUTHENTICATION_EXPIRED
            errorCode.contains("validation") || errorCode.contains("invalid") -> ErrorType.VALIDATION_ERROR
            errorCode.contains("conflict") -> ErrorType.CONFLICT_ERROR
            errorCode.contains("rate") || errorCode.contains("limit") -> ErrorType.RATE_LIMITED
            else -> ErrorType.UNKNOWN
        }
    }

    private fun determineSeverity(
        errorType: ErrorType,
        httpStatus: Int?,
        context: ErrorContext
    ): ErrorSeverity {
        return when (errorType) {
            ErrorType.NETWORK_OFFLINE, ErrorType.NETWORK_TIMEOUT ->
                if (context.attemptNumber > 3) ErrorSeverity.HIGH else ErrorSeverity.MEDIUM
            ErrorType.NETWORK_ERROR -> ErrorSeverity.MEDIUM
            ErrorType.AUTHENTICATION_EXPIRED -> ErrorSeverity.HIGH
            ErrorType.AUTHORIZATION_DENIED -> ErrorSeverity.HIGH
            ErrorType.VALIDATION_ERROR -> ErrorSeverity.LOW
            ErrorType.RESOURCE_NOT_FOUND -> ErrorSeverity.MEDIUM
            ErrorType.CONFLICT_ERROR -> ErrorSeverity.MEDIUM
            ErrorType.RATE_LIMITED -> if (context.attemptNumber > 5) ErrorSeverity.HIGH else ErrorSeverity.MEDIUM
            ErrorType.SERVER_ERROR -> ErrorSeverity.HIGH
            ErrorType.UNKNOWN -> ErrorSeverity.MEDIUM
        }
    }

    private fun checkRetryable(
        errorType: ErrorType,
        httpStatus: Int?,
        attemptNumber: Int
    ): Boolean {
        if (attemptNumber >= 5) return false

        return when (errorType) {
            ErrorType.NETWORK_OFFLINE, ErrorType.NETWORK_TIMEOUT, ErrorType.NETWORK_ERROR -> true
            ErrorType.RATE_LIMITED -> true
            ErrorType.SERVER_ERROR -> true
            ErrorType.AUTHENTICATION_EXPIRED -> true
            ErrorType.VALIDATION_ERROR, ErrorType.AUTHORIZATION_DENIED, ErrorType.RESOURCE_NOT_FOUND -> false
            ErrorType.CONFLICT_ERROR -> false
            ErrorType.UNKNOWN -> attemptNumber < 2
        }
    }

    private fun checkUserFacing(errorType: ErrorType, severity: ErrorSeverity): Boolean {
        return when (errorType) {
            ErrorType.VALIDATION_ERROR -> true
            ErrorType.AUTHENTICATION_EXPIRED, ErrorType.AUTHORIZATION_DENIED -> true
            ErrorType.RESOURCE_NOT_FOUND -> true
            ErrorType.CONFLICT_ERROR -> true
            ErrorType.NETWORK_OFFLINE -> true
            ErrorType.RATE_LIMITED -> severity == ErrorSeverity.HIGH
            ErrorType.NETWORK_TIMEOUT, ErrorType.NETWORK_ERROR, ErrorType.SERVER_ERROR -> severity == ErrorSeverity.HIGH
            ErrorType.UNKNOWN -> severity == ErrorSeverity.HIGH
        }
    }

    private fun determineSuggestedAction(
        errorType: ErrorType,
        severity: ErrorSeverity,
        isRetryable: Boolean
    ): SuggestedAction {
        if (isRetryable) return SuggestedAction.RETRY

        return when (errorType) {
            ErrorType.AUTHENTICATION_EXPIRED -> SuggestedAction.REFRESH_AUTH
            ErrorType.AUTHORIZATION_DENIED -> SuggestedAction.ESCALATE
            ErrorType.VALIDATION_ERROR -> SuggestedAction.FIX_INPUT
            ErrorType.CONFLICT_ERROR -> SuggestedAction.RESOLVE_CONFLICT
            ErrorType.RESOURCE_NOT_FOUND -> SuggestedAction.ABORT
            ErrorType.RATE_LIMITED -> SuggestedAction.WAIT_AND_RETRY
            else -> if (severity == ErrorSeverity.HIGH) SuggestedAction.ESCALATE else SuggestedAction.RETRY
        }
    }

    private fun generateUserMessage(errorType: ErrorType, severity: ErrorSeverity): String {
        return when (errorType) {
            ErrorType.NETWORK_OFFLINE -> "You appear to be offline. Please check your internet connection."
            ErrorType.NETWORK_TIMEOUT -> "The request timed out. Please try again."
            ErrorType.NETWORK_ERROR -> "Unable to connect to the server. Please try again."
            ErrorType.AUTHENTICATION_EXPIRED -> "Your session has expired. Please sign in again."
            ErrorType.AUTHORIZATION_DENIED -> "You don't have permission to perform this action."
            ErrorType.VALIDATION_ERROR -> "Please check your input and try again."
            ErrorType.RESOURCE_NOT_FOUND -> "The requested item could not be found."
            ErrorType.CONFLICT_ERROR -> "This item has been modified. Please refresh and try again."
            ErrorType.RATE_LIMITED -> "Too many requests. Please wait a moment and try again."
            ErrorType.SERVER_ERROR -> "Something went wrong on our end. Please try again later."
            ErrorType.UNKNOWN -> "An unexpected error occurred. Please try again."
        }
    }

    private fun calculateRetrySchedule(errorType: ErrorType, attemptNumber: Int): RetrySchedule {
        val baseDelay = when (errorType) {
            ErrorType.RATE_LIMITED -> 30_000L
            ErrorType.SERVER_ERROR -> 5_000L
            ErrorType.NETWORK_TIMEOUT -> 2_000L
            else -> 1_000L
        }
        val maxDelay = when (errorType) {
            ErrorType.RATE_LIMITED -> 300_000L
            else -> 30_000L
        }

        val exponentialDelay = baseDelay * 2.0.pow(attemptNumber.toDouble())
        val clampedDelay = minOf(exponentialDelay, maxDelay.toDouble())
        val jitter = clampedDelay * (Math.random() * 0.5 - 0.25)
        val finalDelay = maxOf(0.0, clampedDelay + jitter).toLong()

        return RetrySchedule(
            delayMs = finalDelay,
            maxAttempts = 5,
            currentAttempt = attemptNumber + 1,
            backoffType = BackoffType.EXPONENTIAL,
            nextRetryAt = System.currentTimeMillis() + finalDelay
        )
    }

    private fun determineFallbackAction(errorType: ErrorType, operation: String): FallbackAction? {
        return when (errorType) {
            ErrorType.NETWORK_OFFLINE, ErrorType.NETWORK_ERROR -> {
                when {
                    operation.contains("sync") || operation.contains("fetch") -> FallbackAction.USE_CACHE
                    operation.contains("create") || operation.contains("update") -> FallbackAction.QUEUE_FOR_LATER
                    else -> null
                }
            }
            ErrorType.SERVER_ERROR -> FallbackAction.USE_CACHE
            ErrorType.RATE_LIMITED -> FallbackAction.QUEUE_FOR_LATER
            else -> null
        }
    }

    private fun shouldReportError(classification: ErrorClassification, context: ErrorContext): Boolean {
        return classification.errorType == ErrorType.SERVER_ERROR ||
               context.attemptNumber >= 3 ||
               classification.severity == ErrorSeverity.HIGH ||
               classification.errorType == ErrorType.UNKNOWN
    }
}

// MARK: - Data Classes

@Serializable
enum class ErrorType {
    NETWORK_OFFLINE,
    NETWORK_TIMEOUT,
    NETWORK_ERROR,
    AUTHENTICATION_EXPIRED,
    AUTHORIZATION_DENIED,
    VALIDATION_ERROR,
    RESOURCE_NOT_FOUND,
    CONFLICT_ERROR,
    RATE_LIMITED,
    SERVER_ERROR,
    UNKNOWN
}

@Serializable
enum class ErrorSeverity {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
}

@Serializable
enum class SuggestedAction {
    RETRY,
    WAIT_AND_RETRY,
    REFRESH_AUTH,
    FIX_INPUT,
    RESOLVE_CONFLICT,
    ABORT,
    ESCALATE
}

@Serializable
data class ErrorContext(
    val operation: String,
    val attemptNumber: Int = 1,
    val lastAttemptAt: Long? = null,
    val additionalInfo: Map<String, String> = emptyMap()
)

@Serializable
data class ErrorClassification(
    val errorCode: String,
    val errorType: ErrorType,
    val severity: ErrorSeverity,
    val isRetryable: Boolean,
    val isUserFacing: Boolean,
    val suggestedAction: SuggestedAction,
    val userMessage: String
)

@Serializable
data class RecoveryStrategy(
    val action: SuggestedAction,
    val retrySchedule: RetrySchedule?,
    val fallbackAction: FallbackAction?,
    val shouldReport: Boolean,
    val shouldNotifyUser: Boolean,
    val userMessage: String
)

@Serializable
data class RetrySchedule(
    val delayMs: Long,
    val maxAttempts: Int,
    val currentAttempt: Int,
    val backoffType: BackoffType,
    val nextRetryAt: Long
)

@Serializable
enum class BackoffType {
    FIXED,
    LINEAR,
    EXPONENTIAL
}

@Serializable
enum class FallbackAction {
    USE_CACHE,
    QUEUE_FOR_LATER,
    USE_DEFAULT,
    SKIP_OPERATION
}

@Serializable
data class CircuitBreakerConfig(
    val failureThreshold: Int = 5,
    val failureRateThreshold: Double = 0.5,
    val windowDurationMs: Long = 60_000,
    val tripDurationMs: Long = 30_000
)

@Serializable
data class CircuitBreakerDecision(
    val shouldTrip: Boolean,
    val reason: String?,
    val tripDurationMs: Long,
    val resetAt: Long?
)

data class ErrorRecord(
    val errorCode: String,
    val operation: String,
    val timestamp: Long,
    val message: String?
)
