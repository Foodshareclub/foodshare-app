package com.foodshare.swift

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Error category for classification.
 * Maps to Swift ErrorCategory enum.
 */
@Serializable
enum class ErrorCategory(val value: String) {
    @SerialName("network") NETWORK("network"),
    @SerialName("authentication") AUTHENTICATION("authentication"),
    @SerialName("authorization") AUTHORIZATION("authorization"),
    @SerialName("validation") VALIDATION("validation"),
    @SerialName("notFound") NOT_FOUND("notFound"),
    @SerialName("conflict") CONFLICT("conflict"),
    @SerialName("timeout") TIMEOUT("timeout"),
    @SerialName("rateLimit") RATE_LIMIT("rateLimit"),
    @SerialName("server") SERVER("server"),
    @SerialName("serviceUnavailable") SERVICE_UNAVAILABLE("serviceUnavailable"),
    @SerialName("client") CLIENT("client"),
    @SerialName("storage") STORAGE("storage"),
    @SerialName("parse") PARSE("parse"),
    @SerialName("unknown") UNKNOWN("unknown");

    companion object {
        fun fromValue(value: String): ErrorCategory {
            return entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Error severity level.
 */
@Serializable
enum class ErrorSeverity(val value: String) {
    @SerialName("low") LOW("low"),
    @SerialName("medium") MEDIUM("medium"),
    @SerialName("high") HIGH("high"),
    @SerialName("critical") CRITICAL("critical");

    companion object {
        fun fromValue(value: String): ErrorSeverity {
            return entries.find { it.value == value } ?: MEDIUM
        }
    }
}


/**
 * Categorized error with metadata.
 */
@Serializable
data class CategorizedError(
    val category: ErrorCategory,
    val severity: ErrorSeverity,
    val isTransient: Boolean,
    val isRetryable: Boolean,
    val requiresUserAction: Boolean,
    val shouldReport: Boolean,
    val displayName: String
)

/**
 * Recovery action types.
 */
@Serializable
enum class RecoveryAction(val value: String) {
    @SerialName("retry") RETRY("retry"),
    @SerialName("checkConnection") CHECK_CONNECTION("checkConnection"),
    @SerialName("reauthenticate") REAUTHENTICATE("reauthenticate"),
    @SerialName("refreshToken") REFRESH_TOKEN("refreshToken"),
    @SerialName("fixInput") FIX_INPUT("fixInput"),
    @SerialName("contactSupport") CONTACT_SUPPORT("contactSupport"),
    @SerialName("waitAndRetry") WAIT_AND_RETRY("waitAndRetry"),
    @SerialName("enableOfflineMode") ENABLE_OFFLINE_MODE("enableOfflineMode"),
    @SerialName("clearCache") CLEAR_CACHE("clearCache"),
    @SerialName("updateApp") UPDATE_APP("updateApp"),
    @SerialName("dismiss") DISMISS("dismiss"),
    @SerialName("none") NONE("none");

    companion object {
        fun fromValue(value: String): RecoveryAction {
            return entries.find { it.value == value } ?: NONE
        }
    }
}

/**
 * User guidance for error recovery.
 */
@Serializable
data class UserGuidance(
    val title: String,
    val message: String,
    val actionLabel: String
)

/**
 * Recovery strategy for an error.
 */
@Serializable
data class RecoveryStrategy(
    val primaryAction: RecoveryAction,
    val alternativeActions: List<RecoveryAction> = emptyList(),
    val fallbackAction: RecoveryAction = RecoveryAction.DISMISS,
    val allActions: List<RecoveryAction> = emptyList(),
    val autoRecoveryPossible: Boolean = false,
    val recommendedDelaySeconds: Double = 0.0,
    val maxRetries: Int = 0,
    val shouldRetry: Boolean = false,
    val guidance: UserGuidance? = null
) {
    companion object {
        fun default() = RecoveryStrategy(
            primaryAction = RecoveryAction.DISMISS,
            alternativeActions = emptyList(),
            fallbackAction = RecoveryAction.DISMISS,
            autoRecoveryPossible = false,
            recommendedDelaySeconds = 0.0,
            maxRetries = 0,
            shouldRetry = false,
            guidance = UserGuidance(
                title = "Something went wrong",
                message = "Please try again later.",
                actionLabel = "OK"
            )
        )
    }
}

/**
 * User-friendly error for display.
 */
@Serializable
data class UserFriendlyError(
    val title: String,
    val message: String,
    val suggestion: String? = null,
    val icon: String = "warning",
    val style: String = "error",
    val dismissable: Boolean = true,
    val showRetry: Boolean = false
) {
    val fullMessage: String
        get() = if (suggestion != null) "$message $suggestion" else message

    companion object {
        fun default(message: String = "Something went wrong") = UserFriendlyError(
            title = "Error",
            message = message,
            suggestion = "Please try again",
            icon = "warning",
            style = "error",
            dismissable = true,
            showRetry = true
        )
    }
}

/**
 * Retry eligibility result.
 */
@Serializable
data class RetryEligibility(
    val canRetry: Boolean,
    val reason: String,
    val recommendedDelayMs: Int = 0,
    val confidence: Double = 0.0,
    val maxAttempts: Int = 0,
    val backoffMultiplier: Double = 1.0,
    val useJitter: Boolean = false
) {
    companion object {
        fun notRetryable(reason: String) = RetryEligibility(
            canRetry = false,
            reason = reason,
            recommendedDelayMs = 0,
            confidence = 1.0
        )

        fun retryable(delayMs: Int, reason: String = "Transient error") = RetryEligibility(
            canRetry = true,
            reason = reason,
            recommendedDelayMs = delayMs,
            confidence = 0.8
        )
    }
}

/**
 * Error report decision.
 */
@Serializable
data class ErrorReportDecision(
    val shouldReport: Boolean,
    val shouldSample: Boolean,
    val reason: String
) {
    companion object {
        fun report(reason: String = "Meets criteria") = ErrorReportDecision(
            shouldReport = true,
            shouldSample = true,
            reason = reason
        )

        fun skip(reason: String = "Below threshold") = ErrorReportDecision(
            shouldReport = false,
            shouldSample = false,
            reason = reason
        )
    }
}

// MARK: - Auth Error Mapping

/**
 * Result of mapping an auth error to user-friendly format.
 * Maps to Swift AuthMappedError.
 */
@Serializable
data class AuthMappedError(
    val message: String,
    val category: AuthErrorCategory,
    val isRecoverable: Boolean,
    val suggestion: String? = null
) {
    val fullMessage: String
        get() = if (suggestion != null) "$message $suggestion" else message

    companion object {
        fun default(message: String = "An unexpected error occurred") = AuthMappedError(
            message = message,
            category = AuthErrorCategory.UNKNOWN,
            isRecoverable = true,
            suggestion = "Please try again."
        )
    }
}

/**
 * Categories of authentication errors.
 * Maps to Swift AuthErrorCategory enum.
 */
@Serializable
enum class AuthErrorCategory(val value: String) {
    @SerialName("invalidCredentials") INVALID_CREDENTIALS("invalidCredentials"),
    @SerialName("emailNotConfirmed") EMAIL_NOT_CONFIRMED("emailNotConfirmed"),
    @SerialName("userExists") USER_EXISTS("userExists"),
    @SerialName("userNotFound") USER_NOT_FOUND("userNotFound"),
    @SerialName("rateLimited") RATE_LIMITED("rateLimited"),
    @SerialName("sessionExpired") SESSION_EXPIRED("sessionExpired"),
    @SerialName("weakPassword") WEAK_PASSWORD("weakPassword"),
    @SerialName("invalidEmail") INVALID_EMAIL("invalidEmail"),
    @SerialName("networkError") NETWORK_ERROR("networkError"),
    @SerialName("oauthError") OAUTH_ERROR("oauthError"),
    @SerialName("accountDisabled") ACCOUNT_DISABLED("accountDisabled"),
    @SerialName("unknown") UNKNOWN("unknown");

    val requiresReauth: Boolean
        get() = this == SESSION_EXPIRED || this == INVALID_CREDENTIALS

    companion object {
        fun fromValue(value: String): AuthErrorCategory {
            return entries.find { it.value == value } ?: UNKNOWN
        }
    }
}

/**
 * Result of mapping a network error.
 * Maps to Swift NetworkMappedError.
 */
@Serializable
data class NetworkMappedError(
    val message: String,
    val category: NetworkErrorCategory,
    val isRetryable: Boolean
)

/**
 * Categories of network errors.
 * Maps to Swift NetworkErrorCategory enum.
 */
@Serializable
enum class NetworkErrorCategory(val value: String) {
    @SerialName("offline") OFFLINE("offline"),
    @SerialName("timeout") TIMEOUT("timeout"),
    @SerialName("rateLimited") RATE_LIMITED("rateLimited"),
    @SerialName("serverError") SERVER_ERROR("serverError"),
    @SerialName("unknown") UNKNOWN("unknown");

    companion object {
        fun fromValue(value: String): NetworkErrorCategory {
            return entries.find { it.value == value } ?: UNKNOWN
        }
    }
}
