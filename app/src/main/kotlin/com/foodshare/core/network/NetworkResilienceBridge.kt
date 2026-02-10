package com.foodshare.core.network

import com.foodshare.swift.generated.NetworkResilienceEngine as SwiftEngine
import com.foodshare.swift.generated.RetryDecision as SwiftRetryDecision
import com.foodshare.swift.generated.CircuitBreakerDecision as SwiftCircuitBreakerDecision
import com.foodshare.swift.generated.CircuitBreakerConfig as SwiftCircuitBreakerConfig
import com.foodshare.swift.generated.ConnectionHealthResult as SwiftConnectionHealthResult
import com.foodshare.swift.generated.RetryConfig as SwiftRetryConfig

/**
 * Network resilience utilities using Swift implementation for cross-platform consistency.
 *
 * Architecture (Frameo pattern - swift-java):
 * - Uses Swift NetworkResilienceEngine via swift-java generated classes
 * - Ensures identical retry, backoff, and circuit breaker behavior across iOS and Android
 * - Kotlin data classes provide API compatibility
 *
 * Swift implementation:
 * - foodshare-core/Sources/FoodshareCore/Network/NetworkResilienceEngine.swift
 */
object NetworkResilienceBridge {

    // ========================================================================
    // Backoff Calculation
    // ========================================================================

    enum class BackoffStrategy(val value: String) {
        CONSTANT("constant"),
        LINEAR("linear"),
        EXPONENTIAL("exponential"),
        EXPONENTIAL_WITH_JITTER("exponentialWithJitter"),
        FULL_JITTER("fullJitter"),
        EQUAL_JITTER("equalJitter")
    }

    /**
     * Calculate backoff delay for a retry attempt.
     * Delegates to Swift NetworkResilienceEngine.
     *
     * @param attempt Current attempt number (0-indexed)
     * @param baseDelayMs Base delay in milliseconds
     * @param maxDelayMs Maximum delay in milliseconds
     * @param strategy Backoff strategy to use
     * @return Delay in milliseconds
     */
    fun calculateBackoff(
        attempt: Int,
        baseDelayMs: Int,
        maxDelayMs: Int,
        strategy: BackoffStrategy
    ): Int {
        return SwiftEngine.calculateBackoff(attempt, baseDelayMs, maxDelayMs, strategy.value)
    }

    // ========================================================================
    // Retry Decisions
    // ========================================================================

    data class RetryDecision(
        val shouldRetry: Boolean,
        val delayMs: Int,
        val reason: String
    )

    /**
     * Determine if a request should be retried based on HTTP status code.
     * Delegates to Swift NetworkResilienceEngine.
     *
     * @param statusCode HTTP status code
     * @param currentAttempt Current attempt number (0-indexed)
     * @param maxAttempts Maximum attempts allowed
     * @return Retry decision with delay and reason
     */
    fun shouldRetry(
        statusCode: Int,
        currentAttempt: Int,
        maxAttempts: Int
    ): RetryDecision {
        val swiftResult: SwiftRetryDecision = SwiftEngine.shouldRetry(statusCode, currentAttempt, maxAttempts)
        return swiftResult.use { result ->
            RetryDecision(
                shouldRetry = result.shouldRetry,
                delayMs = result.delayMs,
                reason = result.reason
            )
        }
    }

    // ========================================================================
    // Circuit Breaker
    // ========================================================================

    enum class CircuitState(val value: String) {
        CLOSED("closed"),
        OPEN("open"),
        HALF_OPEN("halfOpen");

        companion object {
            fun fromValue(value: String): CircuitState =
                entries.find { it.value == value } ?: CLOSED
        }
    }

    data class CircuitBreakerDecision(
        val allowed: Boolean,
        val state: CircuitState,
        val waitTimeMs: Int?,
        val reason: String
    )

    data class CircuitBreakerConfig(
        val failureThreshold: Int,
        val successThreshold: Int,
        val resetTimeoutSeconds: Double,
        val failureWindowSeconds: Double,
        val halfOpenRequestPercentage: Int
    )

    /**
     * Evaluate circuit breaker state to decide if request should proceed.
     * Delegates to Swift NetworkResilienceEngine.
     *
     * @param state Current state as JSON string
     * @return Decision with allowed status and suggested state
     */
    fun evaluateCircuitState(state: String?): CircuitBreakerDecision {
        val swiftResult: SwiftCircuitBreakerDecision = SwiftEngine.evaluateCircuitState(state)
        return swiftResult.use { result ->
            CircuitBreakerDecision(
                allowed = result.allowed,
                state = CircuitState.fromValue(result.state),
                waitTimeMs = result.waitTimeMs.orElse(null),
                reason = result.reason
            )
        }
    }

    /**
     * Get circuit breaker configuration for a preset.
     * Delegates to Swift NetworkResilienceEngine.
     *
     * @param preset "default", "sensitive", or "tolerant"
     * @return Configuration object
     */
    fun getCircuitBreakerConfig(preset: String = "default"): CircuitBreakerConfig {
        val swiftResult: SwiftCircuitBreakerConfig = SwiftEngine.getCircuitBreakerConfig(preset)
        return swiftResult.use { config ->
            CircuitBreakerConfig(
                failureThreshold = config.failureThreshold,
                successThreshold = config.successThreshold,
                resetTimeoutSeconds = config.resetTimeoutSeconds,
                failureWindowSeconds = config.failureWindowSeconds,
                halfOpenRequestPercentage = config.halfOpenRequestPercentage
            )
        }
    }

    // ========================================================================
    // Connection Health
    // ========================================================================

    enum class ConnectionStatus(val value: String) {
        HEALTHY("healthy"),
        DEGRADED("degraded"),
        UNSTABLE("unstable"),
        DISCONNECTED("disconnected"),
        UNKNOWN("unknown");

        companion object {
            fun fromValue(value: String): ConnectionStatus =
                entries.find { it.value == value } ?: UNKNOWN
        }
    }

    enum class ConnectionQuality(val value: String, val score: Int) {
        EXCELLENT("excellent", 100),
        GOOD("good", 75),
        FAIR("fair", 50),
        POOR("poor", 25),
        NONE("none", 0);

        companion object {
            fun fromValue(value: String): ConnectionQuality =
                entries.find { it.value == value } ?: FAIR
        }
    }

    enum class ConnectionType(val value: String) {
        WIFI("wifi"),
        CELLULAR("cellular"),
        ETHERNET("ethernet"),
        UNKNOWN("unknown"),
        NONE("none");

        companion object {
            fun fromValue(value: String): ConnectionType =
                entries.find { it.value == value } ?: UNKNOWN
        }
    }

    data class ConnectionHealthResult(
        val status: ConnectionStatus,
        val quality: ConnectionQuality,
        val healthScore: Int,
        val averageLatencyMs: Double?,
        val errorRate: Double,
        val connectionType: ConnectionType,
        val recommendation: String,
        val shouldProceed: Boolean,
        val shouldUseOfflineMode: Boolean
    )

    /**
     * Evaluate connection health from metrics.
     * Delegates to Swift NetworkResilienceEngine.
     *
     * @param errorRate Error rate (0.0 - 1.0)
     * @param averageLatencyMs Average latency in milliseconds
     * @param connectionType Type of connection
     * @return Health evaluation result
     */
    fun evaluateConnectionHealth(
        errorRate: Double,
        averageLatencyMs: Double?,
        connectionType: String
    ): ConnectionHealthResult {
        val swiftResult: SwiftConnectionHealthResult = SwiftEngine.evaluateConnectionHealth(
            errorRate,
            averageLatencyMs,
            connectionType
        )
        return swiftResult.use { result ->
            ConnectionHealthResult(
                status = ConnectionStatus.fromValue(result.status),
                quality = ConnectionQuality.fromValue(result.quality),
                healthScore = result.healthScore,
                averageLatencyMs = result.averageLatencyMs.orElse(null),
                errorRate = result.errorRate,
                connectionType = ConnectionType.fromValue(result.connectionType),
                recommendation = result.recommendation,
                shouldProceed = result.shouldProceed,
                shouldUseOfflineMode = result.shouldUseOfflineMode
            )
        }
    }

    // ========================================================================
    // Retry Policy Configuration
    // ========================================================================

    data class RetryConfig(
        val maxAttempts: Int,
        val retryOnUnknown: Boolean
    )

    /**
     * Get retry policy configuration for a preset.
     * Delegates to Swift NetworkResilienceEngine.
     *
     * @param preset "default", "aggressive", "conservative", "noRetry", "rateLimitAware"
     * @return Retry configuration
     */
    fun getRetryConfig(preset: String = "default"): RetryConfig {
        val swiftResult: SwiftRetryConfig = SwiftEngine.getRetryConfig(preset)
        return swiftResult.use { config ->
            RetryConfig(
                maxAttempts = config.maxAttempts,
                retryOnUnknown = config.retryOnUnknown
            )
        }
    }
}
