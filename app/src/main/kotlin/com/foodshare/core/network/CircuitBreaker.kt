package com.foodshare.core.network

import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong

/**
 * Circuit breaker states for fault tolerance.
 *
 * SYNC: This mirrors Swift FoodshareCore.CircuitState
 */
enum class CircuitState {
    /** Normal operation - requests flow through */
    CLOSED,
    /** Circuit tripped - requests fail fast */
    OPEN,
    /** Testing recovery - limited requests allowed */
    HALF_OPEN
}

/**
 * Circuit breaker pattern implementation for fault tolerance.
 *
 * Prevents cascading failures by failing fast when a service is unavailable.
 * State transitions: CLOSED → OPEN → HALF_OPEN → CLOSED
 *
 * SYNC: This mirrors Swift FoodshareCore.CircuitBreaker
 *
 * @param name Identifier for this circuit breaker (for logging)
 * @param failureThreshold Consecutive failures before opening circuit
 * @param resetTimeoutMs Time to wait before attempting recovery
 * @param halfOpenRequests Number of test requests in half-open state
 */
class CircuitBreaker(
    val name: String,
    private val failureThreshold: Int = 5,
    private val resetTimeoutMs: Long = 30_000,
    private val halfOpenRequests: Int = 3
) {
    private val mutex = Mutex()

    @Volatile
    private var state: CircuitState = CircuitState.CLOSED

    private val consecutiveFailures = AtomicInteger(0)
    private val halfOpenSuccesses = AtomicInteger(0)
    private val halfOpenAttempts = AtomicInteger(0)
    private val lastFailureTime = AtomicLong(0)

    // Metrics
    private val totalRequests = AtomicLong(0)
    private val totalFailures = AtomicLong(0)
    private val totalSuccesses = AtomicLong(0)

    /**
     * Current state of the circuit breaker.
     */
    val currentState: CircuitState
        get() = state

    /**
     * Circuit breaker metrics for monitoring.
     */
    data class Metrics(
        val state: CircuitState,
        val totalRequests: Long,
        val totalSuccesses: Long,
        val totalFailures: Long,
        val consecutiveFailures: Int,
        val failureRate: Double
    )

    /**
     * Get current metrics.
     */
    fun getMetrics(): Metrics {
        val total = totalRequests.get()
        val failures = totalFailures.get()
        return Metrics(
            state = state,
            totalRequests = total,
            totalSuccesses = totalSuccesses.get(),
            totalFailures = failures,
            consecutiveFailures = consecutiveFailures.get(),
            failureRate = if (total > 0) failures.toDouble() / total else 0.0
        )
    }

    /**
     * Check if a request can proceed.
     *
     * @return true if the request should be allowed, false if it should fail fast
     */
    suspend fun canProceed(): Boolean = mutex.withLock {
        totalRequests.incrementAndGet()

        when (state) {
            CircuitState.CLOSED -> true

            CircuitState.OPEN -> {
                val timeSinceFailure = System.currentTimeMillis() - lastFailureTime.get()
                if (timeSinceFailure >= resetTimeoutMs) {
                    // Transition to half-open
                    transitionTo(CircuitState.HALF_OPEN)
                    halfOpenAttempts.set(0)
                    halfOpenSuccesses.set(0)
                    true
                } else {
                    // Still in cooldown
                    false
                }
            }

            CircuitState.HALF_OPEN -> {
                // Allow limited requests in half-open state
                halfOpenAttempts.incrementAndGet() <= halfOpenRequests
            }
        }
    }

    /**
     * Record a successful request.
     */
    suspend fun recordSuccess() = mutex.withLock {
        totalSuccesses.incrementAndGet()

        when (state) {
            CircuitState.CLOSED -> {
                // Reset consecutive failures
                consecutiveFailures.set(0)
            }

            CircuitState.HALF_OPEN -> {
                val successes = halfOpenSuccesses.incrementAndGet()
                if (successes >= halfOpenRequests) {
                    // Recovery successful - close circuit
                    transitionTo(CircuitState.CLOSED)
                    consecutiveFailures.set(0)
                }
            }

            CircuitState.OPEN -> {
                // Shouldn't happen, but handle gracefully
            }
        }
    }

    /**
     * Record a failed request.
     */
    suspend fun recordFailure() = mutex.withLock {
        totalFailures.incrementAndGet()
        lastFailureTime.set(System.currentTimeMillis())

        when (state) {
            CircuitState.CLOSED -> {
                val failures = consecutiveFailures.incrementAndGet()
                if (failures >= failureThreshold) {
                    // Too many failures - open circuit
                    transitionTo(CircuitState.OPEN)
                }
            }

            CircuitState.HALF_OPEN -> {
                // Recovery failed - back to open
                transitionTo(CircuitState.OPEN)
            }

            CircuitState.OPEN -> {
                // Already open, update failure time
            }
        }
    }

    /**
     * Execute a request with circuit breaker protection.
     *
     * @param block The suspending function to execute
     * @return Result of the operation
     * @throws CircuitOpenException if circuit is open
     */
    suspend fun <T> execute(block: suspend () -> T): Result<T> {
        if (!canProceed()) {
            return Result.failure(CircuitOpenException(name, remainingCooldownMs()))
        }

        return try {
            val result = block()
            recordSuccess()
            Result.success(result)
        } catch (e: Exception) {
            recordFailure()
            Result.failure(e)
        }
    }

    /**
     * Force the circuit to a specific state (for testing/admin).
     */
    suspend fun forceState(newState: CircuitState) = mutex.withLock {
        transitionTo(newState)
        if (newState == CircuitState.CLOSED) {
            consecutiveFailures.set(0)
        }
    }

    /**
     * Reset the circuit breaker to initial state.
     */
    suspend fun reset() = mutex.withLock {
        state = CircuitState.CLOSED
        consecutiveFailures.set(0)
        halfOpenSuccesses.set(0)
        halfOpenAttempts.set(0)
        lastFailureTime.set(0)
    }

    /**
     * Get remaining cooldown time in milliseconds.
     */
    fun remainingCooldownMs(): Long {
        if (state != CircuitState.OPEN) return 0
        val elapsed = System.currentTimeMillis() - lastFailureTime.get()
        return maxOf(0, resetTimeoutMs - elapsed)
    }

    private fun transitionTo(newState: CircuitState) {
        val oldState = state
        state = newState
        onStateChange?.invoke(name, oldState, newState)
    }

    companion object {
        /**
         * Global state change listener for logging/monitoring.
         */
        var onStateChange: ((name: String, from: CircuitState, to: CircuitState) -> Unit)? = null
    }
}

/**
 * Exception thrown when circuit breaker is open.
 */
class CircuitOpenException(
    val circuitName: String,
    val remainingCooldownMs: Long
) : Exception("Circuit '$circuitName' is open. Retry in ${remainingCooldownMs}ms")

/**
 * Registry of circuit breakers for different operations.
 */
object CircuitBreakerRegistry {
    private val breakers = mutableMapOf<String, CircuitBreaker>()

    /**
     * Get or create a circuit breaker for the given name.
     */
    @Synchronized
    fun getOrCreate(
        name: String,
        failureThreshold: Int = 5,
        resetTimeoutMs: Long = 30_000,
        halfOpenRequests: Int = 3
    ): CircuitBreaker {
        return breakers.getOrPut(name) {
            CircuitBreaker(
                name = name,
                failureThreshold = failureThreshold,
                resetTimeoutMs = resetTimeoutMs,
                halfOpenRequests = halfOpenRequests
            )
        }
    }

    /**
     * Get a circuit breaker by name if it exists.
     */
    @Synchronized
    fun get(name: String): CircuitBreaker? = breakers[name]

    /**
     * Get all circuit breakers and their states.
     */
    @Synchronized
    fun getAllMetrics(): Map<String, CircuitBreaker.Metrics> {
        return breakers.mapValues { it.value.getMetrics() }
    }

    /**
     * Reset all circuit breakers.
     */
    suspend fun resetAll() {
        breakers.values.forEach { it.reset() }
    }

    /**
     * Clear all circuit breakers (for testing).
     */
    @Synchronized
    fun clear() {
        breakers.clear()
    }
}
