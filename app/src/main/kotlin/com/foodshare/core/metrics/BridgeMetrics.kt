package com.foodshare.core.metrics

import android.util.Log
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.asSharedFlow
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicLong

/**
 * Instrumentation layer for swift-java bridge calls.
 *
 * Architecture (Frameo pattern):
 * - Wraps bridge calls with timing and observability
 * - No changes to underlying swift-java bindings
 * - Enables performance monitoring of Swift calls
 *
 * Usage:
 * ```kotlin
 * val result = BridgeMetrics.timed("ValidationBridge", "validateListing") {
 *     ValidationBridge.validateListing(title, description)
 * }
 * ```
 */
object BridgeMetrics {

    private const val TAG = "BridgeMetrics"

    // Metrics storage
    private val callCounts = ConcurrentHashMap<String, AtomicLong>()
    private val totalDurations = ConcurrentHashMap<String, AtomicLong>()
    private val maxDurations = ConcurrentHashMap<String, AtomicLong>()
    private val errorCounts = ConcurrentHashMap<String, AtomicLong>()

    // Real-time metrics flow
    private val _metricsFlow = MutableSharedFlow<BridgeCallMetric>(extraBufferCapacity = 64)
    val metricsFlow: SharedFlow<BridgeCallMetric> = _metricsFlow.asSharedFlow()

    // Thresholds for slow call warnings
    private const val SLOW_CALL_THRESHOLD_MS = 100L
    private const val VERY_SLOW_CALL_THRESHOLD_MS = 500L

    // ========================================================================
    // Timing Functions
    // ========================================================================

    /**
     * Execute a bridge operation with timing instrumentation.
     *
     * @param bridgeName Name of the bridge (e.g., "ValidationBridge")
     * @param operationName Name of the operation (e.g., "validateListing")
     * @param operation The operation to execute
     * @return Result of the operation
     */
    inline fun <T> timed(
        bridgeName: String,
        operationName: String,
        operation: () -> T
    ): T {
        val key = "$bridgeName.$operationName"
        val startTime = System.nanoTime()
        var success = true
        var error: Throwable? = null

        return try {
            operation()
        } catch (e: Throwable) {
            success = false
            error = e
            incrementErrorCount(key)
            throw e
        } finally {
            val durationNs = System.nanoTime() - startTime
            val durationMs = durationNs / 1_000_000
            recordCall(key, durationMs, success, error)
        }
    }

    /**
     * Execute a bridge operation with timing (simplified API).
     *
     * @param key Full operation key (e.g., "ValidationBridge.validateListing")
     * @param operation The operation to execute
     * @return Result of the operation
     */
    inline fun <T> timed(key: String, operation: () -> T): T {
        val parts = key.split(".", limit = 2)
        val bridgeName = parts.getOrElse(0) { "Unknown" }
        val operationName = parts.getOrElse(1) { "unknown" }
        return timed(bridgeName, operationName, operation)
    }

    /**
     * Execute a suspend bridge operation with timing instrumentation.
     *
     * @param bridgeName Name of the bridge
     * @param operationName Name of the operation
     * @param operation The suspend operation to execute
     * @return Result of the operation
     */
    suspend inline fun <T> timedSuspend(
        bridgeName: String,
        operationName: String,
        crossinline operation: suspend () -> T
    ): T {
        val key = "$bridgeName.$operationName"
        val startTime = System.nanoTime()
        var success = true
        var error: Throwable? = null

        return try {
            operation()
        } catch (e: Throwable) {
            success = false
            error = e
            incrementErrorCount(key)
            throw e
        } finally {
            val durationNs = System.nanoTime() - startTime
            val durationMs = durationNs / 1_000_000
            recordCall(key, durationMs, success, error)
        }
    }

    // ========================================================================
    // Metrics Recording
    // ========================================================================

    @PublishedApi
    internal fun recordCall(key: String, durationMs: Long, success: Boolean, error: Throwable?) {
        // Update call count
        callCounts.getOrPut(key) { AtomicLong(0) }.incrementAndGet()

        // Update total duration
        totalDurations.getOrPut(key) { AtomicLong(0) }.addAndGet(durationMs)

        // Update max duration
        maxDurations.getOrPut(key) { AtomicLong(0) }.updateAndGet { current ->
            maxOf(current, durationMs)
        }

        // Log slow calls
        if (durationMs >= VERY_SLOW_CALL_THRESHOLD_MS) {
            Log.w(TAG, "Very slow bridge call: $key took ${durationMs}ms")
        } else if (durationMs >= SLOW_CALL_THRESHOLD_MS) {
            Log.d(TAG, "Slow bridge call: $key took ${durationMs}ms")
        }

        // Emit metric
        val metric = BridgeCallMetric(
            key = key,
            durationMs = durationMs,
            success = success,
            errorType = error?.javaClass?.simpleName,
            timestamp = System.currentTimeMillis()
        )
        _metricsFlow.tryEmit(metric)
    }

    @PublishedApi
    internal fun incrementErrorCount(key: String) {
        errorCounts.getOrPut(key) { AtomicLong(0) }.incrementAndGet()
    }

    // ========================================================================
    // Metrics Retrieval
    // ========================================================================

    /**
     * Get summary statistics for a specific operation.
     */
    fun getStats(key: String): BridgeCallStats? {
        val calls = callCounts[key]?.get() ?: return null
        val totalMs = totalDurations[key]?.get() ?: 0L
        val maxMs = maxDurations[key]?.get() ?: 0L
        val errors = errorCounts[key]?.get() ?: 0L

        return BridgeCallStats(
            key = key,
            callCount = calls,
            totalDurationMs = totalMs,
            averageDurationMs = if (calls > 0) totalMs.toDouble() / calls else 0.0,
            maxDurationMs = maxMs,
            errorCount = errors,
            errorRate = if (calls > 0) errors.toDouble() / calls else 0.0
        )
    }

    /**
     * Get summary statistics for all operations.
     */
    fun getAllStats(): List<BridgeCallStats> {
        return callCounts.keys.mapNotNull { getStats(it) }
            .sortedByDescending { it.callCount }
    }

    /**
     * Get statistics for a specific bridge.
     */
    fun getStatsByBridge(bridgeName: String): List<BridgeCallStats> {
        return callCounts.keys
            .filter { it.startsWith("$bridgeName.") }
            .mapNotNull { getStats(it) }
            .sortedByDescending { it.callCount }
    }

    /**
     * Get top N slowest operations by average duration.
     */
    fun getSlowestOperations(limit: Int = 10): List<BridgeCallStats> {
        return getAllStats()
            .sortedByDescending { it.averageDurationMs }
            .take(limit)
    }

    /**
     * Get top N most error-prone operations.
     */
    fun getMostErrorProne(limit: Int = 10): List<BridgeCallStats> {
        return getAllStats()
            .filter { it.errorCount > 0 }
            .sortedByDescending { it.errorRate }
            .take(limit)
    }

    /**
     * Reset all metrics.
     */
    fun reset() {
        callCounts.clear()
        totalDurations.clear()
        maxDurations.clear()
        errorCounts.clear()
    }

    /**
     * Get a formatted summary string for debugging.
     */
    fun getSummary(): String {
        val stats = getAllStats()
        if (stats.isEmpty()) return "No bridge metrics recorded"

        val totalCalls = stats.sumOf { it.callCount }
        val totalErrors = stats.sumOf { it.errorCount }
        val avgDuration = stats.map { it.averageDurationMs }.average()

        return buildString {
            appendLine("=== Bridge Metrics Summary ===")
            appendLine("Total calls: $totalCalls")
            appendLine("Total errors: $totalErrors (${String.format("%.2f", totalErrors.toDouble() / totalCalls * 100)}%)")
            appendLine("Average duration: ${String.format("%.2f", avgDuration)}ms")
            appendLine()
            appendLine("Top 5 by calls:")
            stats.take(5).forEach { stat ->
                appendLine("  ${stat.key}: ${stat.callCount} calls, avg ${String.format("%.2f", stat.averageDurationMs)}ms")
            }
        }
    }
}

/**
 * Individual bridge call metric.
 */
data class BridgeCallMetric(
    val key: String,
    val durationMs: Long,
    val success: Boolean,
    val errorType: String?,
    val timestamp: Long
)

/**
 * Aggregated statistics for a bridge operation.
 */
data class BridgeCallStats(
    val key: String,
    val callCount: Long,
    val totalDurationMs: Long,
    val averageDurationMs: Double,
    val maxDurationMs: Long,
    val errorCount: Long,
    val errorRate: Double
) {
    val bridgeName: String
        get() = key.substringBefore(".")

    val operationName: String
        get() = key.substringAfter(".", "unknown")
}
