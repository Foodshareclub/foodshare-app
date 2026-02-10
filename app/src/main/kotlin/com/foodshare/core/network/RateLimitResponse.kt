package com.foodshare.core.network

import kotlinx.serialization.Serializable
import okhttp3.Headers
import okhttp3.Response

/**
 * Rate limit information parsed from server response headers.
 *
 * Parses unified rate limit headers:
 * - X-RateLimit-Limit: Requests allowed per minute
 * - X-RateLimit-Remaining: Remaining requests in current window
 * - X-RateLimit-Reset: Unix timestamp when window resets
 * - X-RateLimit-Limit-Hour: Requests allowed per hour
 * - X-RateLimit-Remaining-Hour: Remaining requests in hourly window
 * - X-RateLimit-Reset-Hour: Unix timestamp when hourly window resets
 * - X-RateLimit-Tier: User's rate limit tier
 * - Retry-After: Seconds until next request allowed (when rate limited)
 */
@Serializable
data class RateLimitResponse(
    /** Requests allowed per minute */
    val limit: Int,
    /** Remaining requests in current minute window */
    val remaining: Int,
    /** Unix timestamp (seconds) when minute window resets */
    val resetAt: Long,
    /** Requests allowed per hour */
    val limitHour: Int,
    /** Remaining requests in current hourly window */
    val remainingHour: Int,
    /** Unix timestamp (seconds) when hourly window resets */
    val resetAtHour: Long,
    /** User's rate limit tier */
    val tier: UserTier,
    /** Seconds until next request allowed (only set when rate limited) */
    val retryAfter: Int?,
    /** Whether this response indicates rate limiting */
    val isRateLimited: Boolean
) {
    companion object {
        /** Header names */
        private const val HEADER_LIMIT = "X-RateLimit-Limit"
        private const val HEADER_REMAINING = "X-RateLimit-Remaining"
        private const val HEADER_RESET = "X-RateLimit-Reset"
        private const val HEADER_LIMIT_HOUR = "X-RateLimit-Limit-Hour"
        private const val HEADER_REMAINING_HOUR = "X-RateLimit-Remaining-Hour"
        private const val HEADER_RESET_HOUR = "X-RateLimit-Reset-Hour"
        private const val HEADER_TIER = "X-RateLimit-Tier"
        private const val HEADER_RETRY_AFTER = "Retry-After"

        /**
         * Parse rate limit information from OkHttp response.
         */
        fun fromResponse(response: Response): RateLimitResponse? {
            return fromHeaders(response.headers, response.code == 429)
        }

        /**
         * Parse rate limit information from headers.
         */
        fun fromHeaders(headers: Headers, isRateLimited: Boolean = false): RateLimitResponse? {
            val limit = headers[HEADER_LIMIT]?.toIntOrNull() ?: return null

            return RateLimitResponse(
                limit = limit,
                remaining = headers[HEADER_REMAINING]?.toIntOrNull() ?: 0,
                resetAt = headers[HEADER_RESET]?.toLongOrNull() ?: 0L,
                limitHour = headers[HEADER_LIMIT_HOUR]?.toIntOrNull() ?: (limit * 60),
                remainingHour = headers[HEADER_REMAINING_HOUR]?.toIntOrNull() ?: 0,
                resetAtHour = headers[HEADER_RESET_HOUR]?.toLongOrNull() ?: 0L,
                tier = UserTier.fromString(headers[HEADER_TIER]),
                retryAfter = headers[HEADER_RETRY_AFTER]?.toIntOrNull(),
                isRateLimited = isRateLimited
            )
        }

        /**
         * Parse rate limit information from header map (for Ktor/other clients).
         */
        fun fromHeaderMap(
            headers: Map<String, String>,
            isRateLimited: Boolean = false
        ): RateLimitResponse? {
            val limit = headers[HEADER_LIMIT]?.toIntOrNull()
                ?: headers[HEADER_LIMIT.lowercase()]?.toIntOrNull()
                ?: return null

            return RateLimitResponse(
                limit = limit,
                remaining = (headers[HEADER_REMAINING] ?: headers[HEADER_REMAINING.lowercase()])
                    ?.toIntOrNull() ?: 0,
                resetAt = (headers[HEADER_RESET] ?: headers[HEADER_RESET.lowercase()])
                    ?.toLongOrNull() ?: 0L,
                limitHour = (headers[HEADER_LIMIT_HOUR] ?: headers[HEADER_LIMIT_HOUR.lowercase()])
                    ?.toIntOrNull() ?: (limit * 60),
                remainingHour = (headers[HEADER_REMAINING_HOUR] ?: headers[HEADER_REMAINING_HOUR.lowercase()])
                    ?.toIntOrNull() ?: 0,
                resetAtHour = (headers[HEADER_RESET_HOUR] ?: headers[HEADER_RESET_HOUR.lowercase()])
                    ?.toLongOrNull() ?: 0L,
                tier = UserTier.fromString(headers[HEADER_TIER] ?: headers[HEADER_TIER.lowercase()]),
                retryAfter = (headers[HEADER_RETRY_AFTER] ?: headers[HEADER_RETRY_AFTER.lowercase()])
                    ?.toIntOrNull(),
                isRateLimited = isRateLimited
            )
        }
    }

    /** Time until minute window resets in milliseconds */
    val resetInMs: Long
        get() = maxOf(0, (resetAt * 1000) - System.currentTimeMillis())

    /** Time until hourly window resets in milliseconds */
    val resetHourInMs: Long
        get() = maxOf(0, (resetAtHour * 1000) - System.currentTimeMillis())

    /** Retry after in milliseconds (only when rate limited) */
    val retryAfterMs: Long
        get() = (retryAfter ?: 0) * 1000L

    /** Whether we're running low on remaining requests (< 10%) */
    val isNearLimit: Boolean
        get() = remaining.toFloat() / limit < 0.1f

    /** Whether we're running low on hourly requests (< 10%) */
    val isNearHourlyLimit: Boolean
        get() = remainingHour.toFloat() / limitHour < 0.1f

    /** Usage percentage for minute window (0.0 - 1.0) */
    val usagePercentage: Float
        get() = 1.0f - (remaining.toFloat() / limit)

    /** Usage percentage for hourly window (0.0 - 1.0) */
    val hourlyUsagePercentage: Float
        get() = 1.0f - (remainingHour.toFloat() / limitHour)

    /**
     * Get recommended delay before next request.
     * Returns 0 if no delay needed.
     */
    fun getRecommendedDelayMs(): Long {
        if (isRateLimited) {
            return retryAfterMs
        }
        // If near limit, suggest spreading out requests
        if (isNearLimit && remaining > 0) {
            return resetInMs / remaining
        }
        return 0L
    }
}

/**
 * User tier for rate limiting.
 */
@Serializable
enum class UserTier(val value: String) {
    ANONYMOUS("anonymous"),
    FREE("free"),
    VERIFIED("verified"),
    PREMIUM("premium"),
    ADMIN("admin");

    companion object {
        fun fromString(value: String?): UserTier {
            return entries.find { it.value == value?.lowercase() } ?: ANONYMOUS
        }
    }

    /** Get display name for this tier */
    val displayName: String
        get() = when (this) {
            ANONYMOUS -> "Anonymous"
            FREE -> "Free"
            VERIFIED -> "Verified"
            PREMIUM -> "Premium"
            ADMIN -> "Admin"
        }

    /** Whether this tier gets enhanced limits */
    val hasEnhancedLimits: Boolean
        get() = this in listOf(VERIFIED, PREMIUM, ADMIN)
}

/**
 * Rate limit error response from server.
 */
@Serializable
data class RateLimitErrorResponse(
    val success: Boolean = false,
    val error: RateLimitErrorDetail
) {
    @Serializable
    data class RateLimitErrorDetail(
        val code: String,
        val message: String,
        val details: RateLimitErrorDetails?
    )

    @Serializable
    data class RateLimitErrorDetails(
        val retryAfterMs: Long,
        val retryAfterSec: Int,
        val tier: String?,
        val limits: RateLimitLimits?
    )

    @Serializable
    data class RateLimitLimits(
        val perMinute: Int,
        val perHour: Int
    )

    /** Whether this is a burst limit error */
    val isBurstLimitError: Boolean
        get() = error.code == "BURST_LIMIT_EXCEEDED"

    /** Whether this is a standard rate limit error */
    val isRateLimitError: Boolean
        get() = error.code == "RATE_LIMIT_EXCEEDED"
}

/**
 * Rate limit interceptor for OkHttp.
 *
 * Automatically handles rate limit responses and exposes rate limit info.
 */
class RateLimitInterceptor : okhttp3.Interceptor {
    private var lastRateLimitInfo: RateLimitResponse? = null
    private val lock = Any()

    /** Get the most recent rate limit info */
    fun getLastRateLimitInfo(): RateLimitResponse? = synchronized(lock) { lastRateLimitInfo }

    override fun intercept(chain: okhttp3.Interceptor.Chain): Response {
        val request = chain.request()
        val response = chain.proceed(request)

        // Parse rate limit headers
        val rateLimitInfo = RateLimitResponse.fromResponse(response)
        if (rateLimitInfo != null) {
            synchronized(lock) {
                lastRateLimitInfo = rateLimitInfo
            }
        }

        return response
    }
}

/**
 * Rate limit state tracker for UI updates.
 */
object RateLimitStateTracker {
    private var currentState: RateLimitResponse? = null
    private val listeners = mutableListOf<(RateLimitResponse?) -> Unit>()

    /** Update current rate limit state */
    fun update(response: RateLimitResponse?) {
        currentState = response
        listeners.forEach { it(response) }
    }

    /** Get current rate limit state */
    fun getCurrent(): RateLimitResponse? = currentState

    /** Add listener for state changes */
    fun addListener(listener: (RateLimitResponse?) -> Unit) {
        listeners.add(listener)
    }

    /** Remove listener */
    fun removeListener(listener: (RateLimitResponse?) -> Unit) {
        listeners.remove(listener)
    }

    /** Check if currently rate limited */
    fun isRateLimited(): Boolean = currentState?.isRateLimited == true

    /** Get retry delay if rate limited */
    fun getRetryDelayMs(): Long = currentState?.retryAfterMs ?: 0L
}
