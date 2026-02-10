package com.foodshare.core.network

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.ConcurrentLinkedDeque

/**
 * Rate limiter using sliding window algorithm.
 *
 * Limits the number of requests within a time window to prevent
 * overwhelming the backend and hitting Supabase rate limits.
 *
 * SYNC: This mirrors Swift FoodshareCore.RateLimiter
 *
 * @param maxRequests Maximum requests allowed in the window
 * @param windowMs Time window in milliseconds
 */
class RateLimiter(
    private val maxRequests: Int,
    private val windowMs: Long
) {
    private val timestamps = ConcurrentLinkedDeque<Long>()
    private val mutex = Mutex()

    /**
     * Check if a request can proceed without exceeding the rate limit.
     *
     * @return true if request is allowed, false if rate limited
     */
    suspend fun tryAcquire(): Boolean = mutex.withLock {
        val now = System.currentTimeMillis()
        pruneOldTimestamps(now)

        if (timestamps.size < maxRequests) {
            timestamps.addLast(now)
            true
        } else {
            false
        }
    }

    /**
     * Acquire permission to proceed, waiting if necessary.
     *
     * @param timeoutMs Maximum time to wait for permission
     * @return true if permission acquired, false if timed out
     */
    suspend fun acquire(timeoutMs: Long = windowMs): Boolean {
        val startTime = System.currentTimeMillis()

        while (System.currentTimeMillis() - startTime < timeoutMs) {
            if (tryAcquire()) {
                return true
            }

            // Wait for the oldest request to expire
            val waitTime = getWaitTimeMs()
            if (waitTime > 0 && waitTime < timeoutMs) {
                kotlinx.coroutines.delay(minOf(waitTime, 100))
            } else {
                kotlinx.coroutines.delay(50)
            }
        }

        return false
    }

    /**
     * Get the time to wait before next request is allowed.
     *
     * @return Wait time in milliseconds, 0 if request can proceed immediately
     */
    fun getWaitTimeMs(): Long {
        val now = System.currentTimeMillis()
        pruneOldTimestampsSync(now)

        if (timestamps.size < maxRequests) {
            return 0
        }

        val oldest = timestamps.peekFirst() ?: return 0
        val expiry = oldest + windowMs
        return maxOf(0, expiry - now)
    }

    /**
     * Get current number of requests in the window.
     */
    fun getCurrentCount(): Int {
        pruneOldTimestampsSync(System.currentTimeMillis())
        return timestamps.size
    }

    /**
     * Get remaining requests allowed in current window.
     */
    fun getRemainingRequests(): Int {
        return maxOf(0, maxRequests - getCurrentCount())
    }

    /**
     * Reset the rate limiter (clear all timestamps).
     */
    suspend fun reset() = mutex.withLock {
        timestamps.clear()
    }

    private fun pruneOldTimestamps(now: Long) {
        val cutoff = now - windowMs
        while (timestamps.isNotEmpty() && (timestamps.peekFirst() ?: Long.MAX_VALUE) < cutoff) {
            timestamps.pollFirst()
        }
    }

    private fun pruneOldTimestampsSync(now: Long) {
        val cutoff = now - windowMs
        while (timestamps.isNotEmpty() && (timestamps.peekFirst() ?: Long.MAX_VALUE) < cutoff) {
            timestamps.pollFirst()
        }
    }
}

/**
 * Composite rate limiter that enforces multiple limits.
 *
 * Useful for enforcing both per-function and global limits.
 */
class CompositeRateLimiter(
    private val limiters: List<RateLimiter>
) {
    /**
     * Check if all rate limiters allow the request.
     */
    suspend fun tryAcquire(): Boolean {
        // Check all limiters first
        for (limiter in limiters) {
            if (!limiter.tryAcquire()) {
                return false
            }
        }
        return true
    }

    /**
     * Get the maximum wait time across all limiters.
     */
    fun getWaitTimeMs(): Long {
        return limiters.maxOfOrNull { it.getWaitTimeMs() } ?: 0
    }
}

/**
 * Registry of rate limiters for different operations.
 */
object RateLimiterRegistry {
    private val limiters = mutableMapOf<String, RateLimiter>()
    private val globalLimiter = RateLimiter(
        maxRequests = 300,
        windowMs = 60_000 // 300 req/min global
    )

    /**
     * Get or create a rate limiter for the given operation.
     */
    @Synchronized
    fun getOrCreate(
        name: String,
        maxRequests: Int = 60,
        windowMs: Long = 60_000
    ): RateLimiter {
        return limiters.getOrPut(name) {
            RateLimiter(maxRequests, windowMs)
        }
    }

    /**
     * Get the global rate limiter.
     */
    fun getGlobal(): RateLimiter = globalLimiter

    /**
     * Get a composite limiter that enforces both per-operation and global limits.
     */
    @Synchronized
    fun getComposite(
        name: String,
        maxRequests: Int = 60,
        windowMs: Long = 60_000
    ): CompositeRateLimiter {
        val operationLimiter = getOrCreate(name, maxRequests, windowMs)
        return CompositeRateLimiter(listOf(operationLimiter, globalLimiter))
    }

    /**
     * Get status of all rate limiters.
     */
    @Synchronized
    fun getAllStatus(): Map<String, RateLimiterStatus> {
        val status = mutableMapOf<String, RateLimiterStatus>()
        status["global"] = RateLimiterStatus(
            currentCount = globalLimiter.getCurrentCount(),
            remainingRequests = globalLimiter.getRemainingRequests(),
            waitTimeMs = globalLimiter.getWaitTimeMs()
        )
        limiters.forEach { (name, limiter) ->
            status[name] = RateLimiterStatus(
                currentCount = limiter.getCurrentCount(),
                remainingRequests = limiter.getRemainingRequests(),
                waitTimeMs = limiter.getWaitTimeMs()
            )
        }
        return status
    }

    /**
     * Reset all rate limiters (for testing).
     */
    suspend fun resetAll() {
        globalLimiter.reset()
        limiters.values.forEach { it.reset() }
    }

    /**
     * Clear all rate limiters (for testing).
     */
    @Synchronized
    fun clear() {
        limiters.clear()
    }
}

/**
 * Status of a rate limiter.
 */
data class RateLimiterStatus(
    val currentCount: Int,
    val remainingRequests: Int,
    val waitTimeMs: Long
)

/**
 * Exception thrown when rate limit is exceeded.
 */
class RateLimitException(
    val operationName: String,
    val waitTimeMs: Long
) : Exception("Rate limit exceeded for '$operationName'. Retry in ${waitTimeMs}ms")
