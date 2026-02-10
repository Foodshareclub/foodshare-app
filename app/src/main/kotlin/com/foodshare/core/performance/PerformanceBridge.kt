package com.foodshare.core.performance

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Performance budget enforcement.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for performance budget checking
 * - Threshold checking, severity assessment are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - Budget threshold checking
 * - Metric evaluation
 * - Severity assessment
 * - Optimization recommendations
 */
object PerformanceBridge {

    // Optimization recommendations by metric type
    private val recommendations = mapOf(
        MetricType.STARTUP_TIME to listOf(
            "Consider lazy loading non-critical modules",
            "Use Hilt's lazy injection for heavy dependencies",
            "Defer analytics initialization until after first frame"
        ),
        MetricType.SCREEN_LOAD_TIME to listOf(
            "Implement skeleton loading states",
            "Pre-fetch data based on navigation prediction",
            "Use ViewModelProvider.Factory caching"
        ),
        MetricType.API_RESPONSE_TIME to listOf(
            "Enable response compression",
            "Implement request batching where possible",
            "Add response caching with appropriate TTL"
        ),
        MetricType.IMAGE_LOAD_TIME to listOf(
            "Use appropriate image sizes",
            "Enable disk caching in Coil",
            "Implement progressive loading for large images"
        ),
        MetricType.ANIMATION_FRAME_TIME to listOf(
            "Reduce overdraw in Compose layouts",
            "Use remember {} for expensive calculations",
            "Consider using derivedStateOf for filtered lists"
        ),
        MetricType.MEMORY_USAGE to listOf(
            "Implement bitmap pooling",
            "Clear caches on low memory warnings",
            "Use WeakReference for large cached objects"
        )
    )

    // ========================================================================
    // Budget Checking
    // ========================================================================

    /**
     * Check if a single metric is within budget.
     *
     * @param metric Performance metric to check
     * @param budgets Optional custom budget configuration
     * @return Budget check result with severity and recommendations
     */
    fun checkBudget(
        metric: PerformanceMetric,
        budgets: BudgetConfiguration? = null
    ): BudgetCheckResult {
        val config = budgets ?: BudgetConfiguration()

        val budgetValue = when (metric.type) {
            MetricType.STARTUP_TIME -> config.startupTimeMs.toDouble()
            MetricType.SCREEN_LOAD_TIME -> config.screenLoadTimeMs.toDouble()
            MetricType.API_RESPONSE_TIME -> config.apiResponseTimeMs.toDouble()
            MetricType.IMAGE_LOAD_TIME -> config.imageLoadTimeMs.toDouble()
            MetricType.ANIMATION_FRAME_TIME -> config.animationFrameTimeMs.toDouble()
            MetricType.MEMORY_USAGE -> config.memoryCeilingMB.toDouble()
            MetricType.BUNDLE_SIZE -> config.bundleSizeMB.toDouble()
            MetricType.CUSTOM -> metric.value * 2  // Assume 50% threshold for custom
        }

        val percentUsed = if (budgetValue > 0) {
            (metric.value / budgetValue) * 100
        } else 0.0

        val severity = when {
            percentUsed <= 50 -> BudgetSeverity.HEALTHY
            percentUsed <= 80 -> BudgetSeverity.WARNING
            percentUsed <= 100 -> BudgetSeverity.CRITICAL
            else -> BudgetSeverity.EXCEEDED
        }

        val recommendation = if (severity != BudgetSeverity.HEALTHY) {
            recommendations[metric.type]?.randomOrNull()
        } else null

        return BudgetCheckResult(
            withinBudget = metric.value <= budgetValue,
            metricType = metric.type,
            actualValue = metric.value,
            budgetValue = budgetValue,
            percentUsed = percentUsed,
            severity = severity,
            recommendation = recommendation
        )
    }

    /**
     * Check multiple metrics against budgets.
     *
     * @param metrics List of performance metrics
     * @param budgets Optional custom budget configuration
     * @return Summary of all budget checks
     */
    fun checkAllBudgets(
        metrics: List<PerformanceMetric>,
        budgets: BudgetConfiguration? = null
    ): BudgetSummary {
        if (metrics.isEmpty()) return createDefaultSummary()

        val results = metrics.map { checkBudget(it, budgets) }

        val exceededCount = results.count { !it.withinBudget }
        val warningCount = results.count { it.severity == BudgetSeverity.WARNING }
        val passedCount = results.count { it.severity == BudgetSeverity.HEALTHY }

        val overallHealth = when {
            exceededCount > 0 -> BudgetSeverity.EXCEEDED
            results.any { it.severity == BudgetSeverity.CRITICAL } -> BudgetSeverity.CRITICAL
            warningCount > 0 -> BudgetSeverity.WARNING
            else -> BudgetSeverity.HEALTHY
        }

        return BudgetSummary(
            overallHealth = overallHealth,
            results = results,
            exceededCount = exceededCount,
            warningCount = warningCount,
            passedCount = passedCount
        )
    }

    /**
     * Get default budget configuration.
     *
     * @return Default budget thresholds
     */
    fun getDefaultBudgets(): BudgetConfiguration = BudgetConfiguration()

    // ========================================================================
    // Convenience Methods
    // ========================================================================

    /**
     * Quick check if startup time is within budget.
     */
    fun checkStartupTime(timeMs: Long): BudgetCheckResult {
        return checkBudget(
            PerformanceMetric(
                type = MetricType.STARTUP_TIME,
                value = timeMs.toDouble()
            )
        )
    }

    /**
     * Quick check if screen load time is within budget.
     */
    fun checkScreenLoadTime(timeMs: Long, screenName: String? = null): BudgetCheckResult {
        return checkBudget(
            PerformanceMetric(
                type = MetricType.SCREEN_LOAD_TIME,
                value = timeMs.toDouble(),
                label = screenName
            )
        )
    }

    /**
     * Quick check if API response time is within budget.
     */
    fun checkApiResponseTime(timeMs: Long, endpoint: String? = null): BudgetCheckResult {
        return checkBudget(
            PerformanceMetric(
                type = MetricType.API_RESPONSE_TIME,
                value = timeMs.toDouble(),
                label = endpoint
            )
        )
    }

    /**
     * Quick check if image load time is within budget.
     */
    fun checkImageLoadTime(timeMs: Long): BudgetCheckResult {
        return checkBudget(
            PerformanceMetric(
                type = MetricType.IMAGE_LOAD_TIME,
                value = timeMs.toDouble()
            )
        )
    }

    /**
     * Quick check if animation frame time is within budget (for 60fps).
     */
    fun checkAnimationFrameTime(timeMs: Double): BudgetCheckResult {
        return checkBudget(
            PerformanceMetric(
                type = MetricType.ANIMATION_FRAME_TIME,
                value = timeMs
            )
        )
    }

    /**
     * Quick check if memory usage is within budget.
     */
    fun checkMemoryUsage(memoryMB: Long): BudgetCheckResult {
        return checkBudget(
            PerformanceMetric(
                type = MetricType.MEMORY_USAGE,
                value = memoryMB.toDouble()
            )
        )
    }

    /**
     * Check custom metric with custom threshold.
     */
    fun checkCustomMetric(
        value: Double,
        label: String,
        threshold: Double
    ): BudgetCheckResult {
        val metric = PerformanceMetric(
            type = MetricType.CUSTOM,
            value = value,
            label = label
        )

        // For custom metrics, calculate locally since threshold varies
        val percentUsed = (value / threshold) * 100
        val severity = when {
            percentUsed <= 50 -> BudgetSeverity.HEALTHY
            percentUsed <= 80 -> BudgetSeverity.WARNING
            percentUsed <= 100 -> BudgetSeverity.CRITICAL
            else -> BudgetSeverity.EXCEEDED
        }

        return BudgetCheckResult(
            withinBudget = value <= threshold,
            metricType = MetricType.CUSTOM,
            actualValue = value,
            budgetValue = threshold,
            percentUsed = percentUsed,
            severity = severity,
            recommendation = null
        )
    }

    // ========================================================================
    // Helpers
    // ========================================================================

    private fun createDefaultResult(metric: PerformanceMetric): BudgetCheckResult {
        return BudgetCheckResult(
            withinBudget = true,
            metricType = metric.type,
            actualValue = metric.value,
            budgetValue = 0.0,
            percentUsed = 0.0,
            severity = BudgetSeverity.HEALTHY,
            recommendation = null
        )
    }

    private fun createDefaultSummary(): BudgetSummary {
        return BudgetSummary(
            overallHealth = BudgetSeverity.HEALTHY,
            results = emptyList(),
            exceededCount = 0,
            warningCount = 0,
            passedCount = 0
        )
    }
}

// ========================================================================
// Data Classes
// ========================================================================

@Serializable
data class BudgetConfiguration(
    val startupTimeMs: Int = 3000,
    val screenLoadTimeMs: Int = 500,
    val apiResponseTimeMs: Int = 2000,
    val imageLoadTimeMs: Int = 1000,
    val animationFrameTimeMs: Int = 16,  // 60fps
    val memoryCeilingMB: Int = 200,
    val bundleSizeMB: Int = 50
)

@Serializable
enum class MetricType(val value: String) {
    @SerialName("startup_time") STARTUP_TIME("startup_time"),
    @SerialName("screen_load_time") SCREEN_LOAD_TIME("screen_load_time"),
    @SerialName("api_response_time") API_RESPONSE_TIME("api_response_time"),
    @SerialName("image_load_time") IMAGE_LOAD_TIME("image_load_time"),
    @SerialName("animation_frame_time") ANIMATION_FRAME_TIME("animation_frame_time"),
    @SerialName("memory_usage") MEMORY_USAGE("memory_usage"),
    @SerialName("bundle_size") BUNDLE_SIZE("bundle_size"),
    @SerialName("custom") CUSTOM("custom")
}

@Serializable
data class PerformanceMetric(
    val type: MetricType,
    val value: Double,
    val label: String? = null,
    val timestamp: Long = System.currentTimeMillis()
)

@Serializable
enum class BudgetSeverity {
    @SerialName("healthy") HEALTHY,
    @SerialName("warning") WARNING,
    @SerialName("critical") CRITICAL,
    @SerialName("exceeded") EXCEEDED
}

@Serializable
data class BudgetCheckResult(
    val withinBudget: Boolean,
    val metricType: MetricType,
    val actualValue: Double,
    val budgetValue: Double,
    val percentUsed: Double,
    val severity: BudgetSeverity,
    val recommendation: String?
) {
    val isHealthy: Boolean get() = severity == BudgetSeverity.HEALTHY
    val needsAttention: Boolean get() = severity != BudgetSeverity.HEALTHY
    val isCritical: Boolean get() = severity == BudgetSeverity.CRITICAL || severity == BudgetSeverity.EXCEEDED
}

@Serializable
data class BudgetSummary(
    val overallHealth: BudgetSeverity,
    val results: List<BudgetCheckResult>,
    val exceededCount: Int,
    val warningCount: Int,
    val passedCount: Int
) {
    val isHealthy: Boolean get() = overallHealth == BudgetSeverity.HEALTHY
    val hasIssues: Boolean get() = exceededCount > 0 || warningCount > 0

    fun getExceededMetrics(): List<BudgetCheckResult> =
        results.filter { !it.withinBudget }

    fun getWarningMetrics(): List<BudgetCheckResult> =
        results.filter { it.severity == BudgetSeverity.WARNING }
}

// ========================================================================
// Extension Functions
// ========================================================================

/** Check if this timing is within screen load budget. */
fun Long.isWithinScreenLoadBudget(): Boolean =
    PerformanceBridge.checkScreenLoadTime(this).withinBudget

/** Check if this timing is within API response budget. */
fun Long.isWithinApiResponseBudget(): Boolean =
    PerformanceBridge.checkApiResponseTime(this).withinBudget

/** Get budget severity for this frame time. */
fun Double.getFrameTimeSeverity(): BudgetSeverity =
    PerformanceBridge.checkAnimationFrameTime(this).severity
