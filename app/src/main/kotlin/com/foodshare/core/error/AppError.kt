package com.foodshare.core.error

/**
 * Unified error handling for the application.
 *
 * SYNC: This mirrors Swift FoodshareCore.AppError
 * Source: swift-core/Sources/FoodshareCore/Constants/ErrorCodes.swift
 *
 * When Swift bindings are available, errors can be mapped using ErrorBridge.
 */
sealed class AppError(
    override val message: String,
    override val cause: Throwable? = null
) : Exception(message, cause) {

    // MARK: - Network Errors

    object NetworkUnavailable : AppError("No internet connection")

    data class ServerError(
        val code: Int,
        val detail: String? = null
    ) : AppError(detail ?: "Server error ($code)")

    object Timeout : AppError("Request timed out")

    object RequestFailed : AppError("Request failed")

    // MARK: - Authentication Errors

    object Unauthorized : AppError("Please log in to continue")

    object SessionExpired : AppError("Your session has expired")

    object InvalidCredentials : AppError("Invalid email or password")

    object EmailNotConfirmed : AppError("Please check your email to confirm your account")

    object UserAlreadyExists : AppError("An account with this email already exists")

    // MARK: - Data Errors

    object NotFound : AppError("The requested item was not found")

    object InvalidData : AppError("Invalid data received")

    data class DecodingError(val detail: String) : AppError("Failed to parse data: $detail")

    data class ValidationError(
        val field: String,
        val reason: String
    ) : AppError("$field: $reason")

    // MARK: - Location Errors

    object LocationPermissionDenied : AppError("Location permission is required")

    object LocationUnavailable : AppError("Unable to get your location")

    // MARK: - Storage Errors

    object StoragePermissionDenied : AppError("Storage permission is required")

    object UploadFailed : AppError("Failed to upload file")

    // MARK: - Rate Limiting

    object RateLimitExceeded : AppError("Too many requests. Please try again later")

    // MARK: - Generic

    data class Unknown(
        val detail: String,
        val originalError: Throwable? = null
    ) : AppError(detail, originalError)

    // MARK: - Properties

    /**
     * Whether this error can be recovered from by retrying
     */
    val isRecoverable: Boolean
        get() = when (this) {
            NetworkUnavailable, Timeout, RateLimitExceeded, SessionExpired -> true
            is ServerError -> code in 500..599
            else -> false
        }

    /**
     * User-friendly message for display
     */
    fun getUserFriendlyMessage(): String = when (this) {
        NetworkUnavailable -> "Please check your internet connection and try again"
        is ServerError -> "Something went wrong. Please try again later"
        Timeout -> "The request took too long. Please try again"
        Unauthorized, SessionExpired -> "Please log in to continue"
        InvalidCredentials -> "The email or password you entered is incorrect"
        EmailNotConfirmed -> "Please check your email and click the confirmation link"
        UserAlreadyExists -> "An account with this email already exists. Try logging in instead"
        NotFound -> "We couldn't find what you were looking for"
        InvalidData, is DecodingError -> "Something went wrong. Please try again"
        is ValidationError -> "$field: $reason"
        LocationPermissionDenied -> "Please enable location access in Settings"
        LocationUnavailable -> "We couldn't determine your location"
        StoragePermissionDenied -> "Please enable storage access in Settings"
        UploadFailed -> "Failed to upload. Please try again"
        RateLimitExceeded -> "You're doing that too fast. Please wait a moment"
        RequestFailed -> "Request failed. Please try again"
        is Unknown -> "An unexpected error occurred"
    }

    /**
     * Icon name for display (Material Icons)
     */
    val iconName: String
        get() = when (this) {
            NetworkUnavailable -> "wifi_off"
            is ServerError, Timeout -> "cloud_off"
            Unauthorized, SessionExpired, InvalidCredentials -> "lock"
            EmailNotConfirmed, UserAlreadyExists -> "email"
            NotFound -> "search_off"
            InvalidData, is DecodingError, is ValidationError -> "error"
            LocationPermissionDenied, LocationUnavailable -> "location_off"
            StoragePermissionDenied, UploadFailed -> "folder_off"
            RateLimitExceeded -> "schedule"
            RequestFailed -> "error_outline"
            is Unknown -> "help"
        }

    companion object {
        /**
         * Create AppError from a generic Throwable
         */
        fun from(throwable: Throwable): AppError {
            return when (throwable) {
                is AppError -> throwable
                is java.net.UnknownHostException -> NetworkUnavailable
                is java.net.SocketTimeoutException -> Timeout
                is java.net.ConnectException -> NetworkUnavailable
                is kotlinx.serialization.SerializationException ->
                    DecodingError(throwable.message ?: "Serialization failed")
                else -> Unknown(
                    detail = throwable.message ?: "Unknown error",
                    originalError = throwable
                )
            }
        }

        /**
         * Map HTTP status code to AppError
         */
        fun fromHttpCode(code: Int, message: String? = null): AppError {
            return when (code) {
                401 -> Unauthorized
                403 -> Unauthorized
                404 -> NotFound
                422 -> InvalidData
                429 -> RateLimitExceeded
                in 400..499 -> ServerError(code, message ?: "Client error")
                in 500..599 -> ServerError(code, message ?: "Server error")
                else -> Unknown(message ?: "HTTP $code")
            }
        }
    }
}

/**
 * Database-specific error codes (matches Supabase RPC errors).
 *
 * SYNC: This mirrors Swift FoodshareCore.DatabaseErrorCode
 * Source: swift-core/Sources/FoodshareCore/Constants/ErrorCodes.swift
 */
enum class DatabaseErrorCode(val code: String, val message: String) {
    NOT_FOUND("NOT_FOUND", "The requested resource was not found"),
    UNAUTHORIZED("UNAUTHORIZED", "You don't have permission to perform this action"),
    FORBIDDEN("FORBIDDEN", "Access forbidden"),
    VALIDATION_ERROR("VALIDATION_ERROR", "Validation failed"),
    CONFLICT("CONFLICT", "Resource conflict"),
    RATE_LIMIT_EXCEEDED("RATE_LIMIT_EXCEEDED", "Too many requests"),
    // Legacy codes (Kotlin-specific)
    INVALID_PARAMETERS("INVALID_PARAMETERS", "Invalid parameters provided"),
    DUPLICATE_ENTRY("DUPLICATE_ENTRY", "This entry already exists"),
    CONSTRAINT_VIOLATION("CONSTRAINT_VIOLATION", "Data constraint violation"),
    UNKNOWN_ERROR("UNKNOWN_ERROR", "An unknown database error occurred");

    companion object {
        fun fromCode(code: String): DatabaseErrorCode {
            return entries.find { it.code == code } ?: UNKNOWN_ERROR
        }
    }
}

/**
 * Bridge for Swift error mapping.
 *
 * Provides conversion utilities when Swift bindings are available.
 * Currently serves as a namespace for error-related utilities.
 */
object ErrorBridge {
    /**
     * Convert a generic exception to AppError.
     */
    fun fromException(e: Throwable): AppError = AppError.from(e)

    /**
     * Convert an HTTP status code to AppError.
     */
    fun fromHttpStatus(code: Int, message: String? = null): AppError =
        AppError.fromHttpCode(code, message)

    /**
     * Convert a database error code string to DatabaseErrorCode.
     */
    fun fromDatabaseCode(code: String): DatabaseErrorCode =
        DatabaseErrorCode.fromCode(code)
}
