package com.foodshare.core.ratelimit

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.UUID
import kotlin.math.max
import kotlin.math.min

/**
 * Bridge to Swift Rate Limit Engine.
 * Phase 14: Unified Rate Limiting Service with quota tracking
 */
object RateLimitBridge {

    private val json = Json { ignoreUnknownKeys = true }

    // Local usage tracking
    private val usageRecords = mutableListOf<OperationUsage>()
    private val usageLock = Any()

    // MARK: - Quota Checking

    /**
     * Check if an operation can be performed.
     */
    fun canPerformOperation(
        operation: String,
        userId: String,
        limits: List<RateLimit> = StandardRateLimits.limits
    ): OperationPermission {
        val limit = limits.find { it.operation == operation }
            ?: return OperationPermission(
                allowed = true,
                operation = operation,
                remaining = Int.MAX_VALUE,
                resetsAt = null,
                retryAfter = null
            )

        synchronized(usageLock) {
            val windowStart = System.currentTimeMillis() - (limit.windowSeconds * 1000L)
            val usageInWindow = usageRecords.filter {
                it.operation == operation && it.timestamp > windowStart
            }
            val currentUsage = usageInWindow.size

            val remaining = max(0, limit.maxRequests - currentUsage)
            val allowed = remaining > 0

            val resetsAt = usageInWindow.firstOrNull()?.let {
                it.timestamp + (limit.windowSeconds * 1000L)
            }

            return OperationPermission(
                allowed = allowed,
                operation = operation,
                remaining = remaining,
                resetsAt = resetsAt,
                retryAfter = if (allowed) null else resetsAt?.let { it - System.currentTimeMillis() }
            )
        }
    }

    /**
     * Check multiple operations at once.
     */
    fun checkOperations(
        operations: List<String>,
        userId: String,
        limits: List<RateLimit> = StandardRateLimits.limits
    ): OperationsCheck {
        val permissions = mutableMapOf<String, OperationPermission>()
        val blockers = mutableListOf<OperationBlocker>()

        for (operation in operations) {
            val permission = canPerformOperation(operation, userId, limits)
            permissions[operation] = permission

            if (!permission.allowed) {
                blockers.add(OperationBlocker(
                    operation = operation,
                    retryAfter = permission.retryAfter ?: 60_000L
                ))
            }
        }

        return OperationsCheck(
            allAllowed = blockers.isEmpty(),
            permissions = permissions,
            blockers = blockers
        )
    }

    // MARK: - Quota Tracking

    /**
     * Record an operation for rate limiting.
     */
    fun recordOperation(operation: String, userId: String): OperationUsage {
        val usage = OperationUsage(
            id = UUID.randomUUID().toString(),
            operation = operation,
            userId = userId,
            timestamp = System.currentTimeMillis()
        )

        synchronized(usageLock) {
            usageRecords.add(usage)

            // Cleanup old records (keep last hour)
            val cutoff = System.currentTimeMillis() - 3_600_000
            usageRecords.removeAll { it.timestamp < cutoff }
        }

        return usage
    }

    /**
     * Get current quota status for all operations.
     */
    fun getQuotaStatus(
        userId: String,
        limits: List<RateLimit> = StandardRateLimits.limits
    ): QuotaStatus {
        val quotas = mutableMapOf<String, OperationQuota>()

        for (limit in limits) {
            val permission = canPerformOperation(limit.operation, userId, limits)

            quotas[limit.operation] = OperationQuota(
                operation = limit.operation,
                limit = limit.maxRequests,
                remaining = permission.remaining,
                resetsAt = permission.resetsAt,
                usagePercentage = (limit.maxRequests - permission.remaining).toDouble() / limit.maxRequests * 100
            )
        }

        return QuotaStatus(
            userId = userId,
            quotas = quotas,
            timestamp = System.currentTimeMillis()
        )
    }

    // MARK: - Burst Protection

    /**
     * Check for burst activity (rapid consecutive requests).
     */
    fun detectBurst(
        operation: String,
        config: BurstConfig = BurstConfig()
    ): BurstDetection {
        synchronized(usageLock) {
            val recentUsage = usageRecords
                .filter { it.operation == operation }
                .sortedByDescending { it.timestamp }
                .take(config.windowSize)

            if (recentUsage.size < config.windowSize) {
                return BurstDetection(
                    isBurst = false,
                    requestsInWindow = recentUsage.size,
                    avgIntervalMs = null,
                    recommendation = BurstRecommendation.ALLOW
                )
            }

            // Calculate average interval between requests
            val intervals = mutableListOf<Long>()
            for (i in 0 until recentUsage.size - 1) {
                val interval = recentUsage[i].timestamp - recentUsage[i + 1].timestamp
                intervals.add(interval)
            }

            val avgIntervalMs = intervals.average()
            val isBurst = avgIntervalMs < config.minIntervalMs

            val recommendation = when {
                !isBurst -> BurstRecommendation.ALLOW
                avgIntervalMs < config.minIntervalMs / 2 -> BurstRecommendation.BLOCK
                else -> BurstRecommendation.THROTTLE
            }

            return BurstDetection(
                isBurst = isBurst,
                requestsInWindow = recentUsage.size,
                avgIntervalMs = avgIntervalMs,
                recommendation = recommendation
            )
        }
    }

    // MARK: - Quota Prediction

    /**
     * Predict when quota will be available.
     */
    fun predictAvailability(
        operation: String,
        requestedCount: Int,
        limits: List<RateLimit> = StandardRateLimits.limits
    ): AvailabilityPrediction {
        val limit = limits.find { it.operation == operation }
            ?: return AvailabilityPrediction(
                availableNow = true,
                availableAt = System.currentTimeMillis(),
                waitTimeMs = 0,
                requestedCount = requestedCount
            )

        synchronized(usageLock) {
            val windowStart = System.currentTimeMillis() - (limit.windowSeconds * 1000L)
            val usageInWindow = usageRecords
                .filter { it.operation == operation && it.timestamp > windowStart }
                .sortedBy { it.timestamp }

            val currentUsage = usageInWindow.size
            val available = limit.maxRequests - currentUsage

            if (available >= requestedCount) {
                return AvailabilityPrediction(
                    availableNow = true,
                    availableAt = System.currentTimeMillis(),
                    waitTimeMs = 0,
                    requestedCount = requestedCount
                )
            }

            // Calculate when enough quota will be available
            val neededToFree = requestedCount - available
            if (neededToFree <= usageInWindow.size) {
                val releaseTime = usageInWindow[neededToFree - 1].timestamp +
                    (limit.windowSeconds * 1000L)
                val waitTime = releaseTime - System.currentTimeMillis()

                return AvailabilityPrediction(
                    availableNow = false,
                    availableAt = releaseTime,
                    waitTimeMs = max(0, waitTime),
                    requestedCount = requestedCount
                )
            }

            // Would need to wait for full window
            return AvailabilityPrediction(
                availableNow = false,
                availableAt = System.currentTimeMillis() + (limit.windowSeconds * 1000L),
                waitTimeMs = limit.windowSeconds * 1000L,
                requestedCount = requestedCount
            )
        }
    }

    // MARK: - Adaptive Rate Limiting

    /**
     * Calculate adaptive limit based on user behavior.
     */
    fun calculateAdaptiveLimit(
        baseLimit: RateLimit,
        userBehavior: UserBehavior
    ): RateLimit {
        var multiplier = 1.0

        // Good behavior increases limit
        if (userBehavior.errorRate < 0.01) {
            multiplier += 0.2
        }
        if (userBehavior.averageRequestInterval > 5.0) {
            multiplier += 0.1
        }
        if (userBehavior.accountAgeDays > 30) {
            multiplier += 0.1
        }

        // Bad behavior decreases limit
        if (userBehavior.errorRate > 0.1) {
            multiplier -= 0.3
        }
        if (userBehavior.recentViolations > 0) {
            multiplier -= 0.2 * userBehavior.recentViolations
        }

        // Clamp multiplier
        multiplier = max(0.5, min(2.0, multiplier))

        return RateLimit(
            operation = baseLimit.operation,
            maxRequests = (baseLimit.maxRequests * multiplier).toInt(),
            windowSeconds = baseLimit.windowSeconds,
            isAdaptive = true
        )
    }

    /**
     * Clear local usage records (for testing).
     */
    fun clearUsage() {
        synchronized(usageLock) {
            usageRecords.clear()
        }
    }
}

// MARK: - Data Classes

@Serializable
data class RateLimit(
    val operation: String,
    val maxRequests: Int,
    val windowSeconds: Long,
    val isAdaptive: Boolean = false
)

@Serializable
data class OperationUsage(
    val id: String,
    val operation: String,
    val userId: String,
    val timestamp: Long
)

@Serializable
data class OperationPermission(
    val allowed: Boolean,
    val operation: String,
    val remaining: Int,
    val resetsAt: Long?,
    val retryAfter: Long?
)

@Serializable
data class OperationsCheck(
    val allAllowed: Boolean,
    val permissions: Map<String, OperationPermission>,
    val blockers: List<OperationBlocker>
)

@Serializable
data class OperationBlocker(
    val operation: String,
    val retryAfter: Long
)

@Serializable
data class OperationQuota(
    val operation: String,
    val limit: Int,
    val remaining: Int,
    val resetsAt: Long?,
    val usagePercentage: Double
)

@Serializable
data class QuotaStatus(
    val userId: String,
    val quotas: Map<String, OperationQuota>,
    val timestamp: Long
)

@Serializable
data class BurstConfig(
    val windowSize: Int = 10,
    val minIntervalMs: Long = 100
)

@Serializable
data class BurstDetection(
    val isBurst: Boolean,
    val requestsInWindow: Int,
    val avgIntervalMs: Double?,
    val recommendation: BurstRecommendation
)

@Serializable
enum class BurstRecommendation {
    ALLOW,
    THROTTLE,
    BLOCK
}

@Serializable
data class AvailabilityPrediction(
    val availableNow: Boolean,
    val availableAt: Long,
    val waitTimeMs: Long,
    val requestedCount: Int
)

@Serializable
data class UserBehavior(
    val errorRate: Double,
    val averageRequestInterval: Double,
    val accountAgeDays: Int,
    val recentViolations: Int
)

/**
 * Standard rate limits for Foodshare operations.
 */
object StandardRateLimits {
    val limits = listOf(
        RateLimit("listings.create", 10, 3600),
        RateLimit("listings.update", 30, 3600),
        RateLimit("messages.send", 100, 3600),
        RateLimit("favorites.toggle", 50, 3600),
        RateLimit("search.query", 60, 60),
        RateLimit("reviews.create", 5, 3600),
        RateLimit("reports.create", 10, 3600),
        RateLimit("auth.login", 5, 300),
        RateLimit("auth.signup", 3, 3600),
        RateLimit("profile.update", 10, 3600)
    )
}
