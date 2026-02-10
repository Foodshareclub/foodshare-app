package com.foodshare.core.batch

import com.foodshare.swift.generated.BatchOperationsEngine as SwiftBatchOperationsEngine
import kotlinx.serialization.Serializable
import org.swift.swiftkit.core.SwiftArena
import java.util.UUID

/**
 * Batch operation orchestration utilities.
 *
 * Architecture (Frameo pattern):
 * - Core calculations (chunk sizing, backoff) via Swift engine for cross-platform consistency
 * - Orchestration and aggregation in Kotlin for Android-specific patterns
 */
object BatchOperationsBridge {

    // SwiftArena for memory management of Swift objects
    private val arena: SwiftArena by lazy { SwiftArena.ofAuto() }

    // MARK: - Validation

    /**
     * Validate a batch operation before execution.
     */
    fun validateBatchOperation(
        itemCount: Int,
        operation: BatchOperationType,
        constraints: BatchConstraints? = null
    ): BatchValidationResult {
        val c = constraints ?: BatchConstraints.DEFAULT
        val errors = mutableListOf<BatchValidationError>()
        val warnings = mutableListOf<String>()

        // Check item count bounds
        if (itemCount < c.minBatchSize) {
            errors.add(BatchValidationError(
                code = "BATCH_TOO_SMALL",
                message = "Batch size $itemCount is below minimum ${c.minBatchSize}"
            ))
        }

        if (itemCount > c.maxBatchSize) {
            errors.add(BatchValidationError(
                code = "BATCH_TOO_LARGE",
                message = "Batch size $itemCount exceeds maximum ${c.maxBatchSize}"
            ))
        }

        // Check delete operations
        if (operation == BatchOperationType.DELETE && !c.allowBatchDelete) {
            errors.add(BatchValidationError(
                code = "DELETE_NOT_ALLOWED",
                message = "Batch delete operations are not allowed"
            ))
        }

        // Add warnings for large batches
        if (itemCount > c.maxBatchSize / 2) {
            warnings.add("Large batch - consider chunking for better performance")
        }

        val validCount = if (errors.isEmpty()) itemCount else 0
        val invalidCount = if (errors.isNotEmpty()) itemCount else 0

        return BatchValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            warnings = warnings,
            validItemCount = validCount,
            invalidItemCount = invalidCount,
            totalItems = itemCount,
            successRate = if (errors.isEmpty()) 1.0 else 0.0
        )
    }

    /**
     * Check if a batch can proceed based on validation result.
     */
    fun canProceed(
        result: BatchValidationResult,
        policy: ValidationPolicy = ValidationPolicy.STRICT
    ): Boolean {
        return when (policy) {
            ValidationPolicy.STRICT -> result.isValid
            ValidationPolicy.ALLOW_PARTIAL -> result.validItemCount > 0
            ValidationPolicy.WARN_ONLY -> true
        }
    }

    // MARK: - Chunk Sizing (Swift-backed for cross-platform consistency)

    /**
     * Calculate optimal chunk size for batch processing using Swift engine.
     */
    fun calculateOptimalChunkSize(
        totalItems: Int,
        config: ChunkConfig? = null,
        context: BatchContext? = null
    ): ChunkSizeResult {
        val cfg = config ?: ChunkConfig.DEFAULT
        val ctx = context ?: BatchContext()

        val swiftResult = SwiftBatchOperationsEngine.calculateOptimalChunkSize(
            totalItems,
            ctx.connectionQuality.value,
            ctx.averageItemSizeBytes ?: 0,
            cfg.defaultChunkSize,
            cfg.minChunkSize,
            cfg.maxChunkSize,
            cfg.maxBytesPerChunk,
            arena
        )

        return ChunkSizeResult(
            recommendedSize = swiftResult.recommendedSize,
            chunkCount = swiftResult.chunkCount,
            totalItems = swiftResult.totalItems,
            reason = swiftResult.reason,
            isSingleChunk = swiftResult.isSingleChunk
        )
    }

    /**
     * Split items into chunks.
     */
    fun <T> splitIntoChunks(items: List<T>, chunkSize: Int): List<List<T>> {
        if (chunkSize <= 0 || items.isEmpty()) return listOf(items)
        return items.chunked(chunkSize)
    }

    // MARK: - Retry Logic

    /**
     * Identify which failed items can be retried.
     */
    fun identifyRetryableItems(
        failures: List<BatchItemFailure>,
        config: BatchRetryConfig? = null
    ): RetryableItemsResult {
        val cfg = config ?: BatchRetryConfig.DEFAULT
        val retryable = mutableListOf<RetryableItem>()
        val nonRetryable = mutableListOf<NonRetryableItem>()

        for (failure in failures) {
            // Check if max retries exceeded
            if (failure.retryCount >= cfg.maxRetries) {
                nonRetryable.add(NonRetryableItem(
                    itemId = failure.itemId,
                    itemIndex = failure.itemIndex,
                    reason = "Max retries (${cfg.maxRetries}) exceeded"
                ))
                continue
            }

            // Check if error category is retryable
            val isRetryable = when (failure.errorCategory) {
                BatchErrorCategory.TRANSIENT -> true
                BatchErrorCategory.NETWORK -> cfg.retryNetworkErrors
                BatchErrorCategory.TIMEOUT -> cfg.retryTimeouts
                BatchErrorCategory.RATE_LIMIT -> true
                BatchErrorCategory.CONFLICT -> cfg.retryConflicts
                BatchErrorCategory.SERVER_ERROR -> true
                BatchErrorCategory.UNKNOWN -> cfg.retryUnknownErrors
                BatchErrorCategory.VALIDATION, BatchErrorCategory.AUTHORIZATION,
                BatchErrorCategory.NOT_FOUND -> false
            }

            if (isRetryable) {
                // Calculate suggested delay based on retry count
                val delay = calculateBackoff(
                    attempt = failure.retryCount,
                    strategy = cfg.backoffStrategy,
                    baseDelayMs = (cfg.baseDelaySeconds * 1000).toLong(),
                    maxDelayMs = (cfg.maxDelaySeconds * 1000).toLong()
                )

                retryable.add(RetryableItem(
                    itemId = failure.itemId,
                    itemIndex = failure.itemIndex,
                    retryCount = failure.retryCount,
                    suggestedDelaySeconds = delay / 1000.0,
                    reason = "Category ${failure.errorCategory.value} is retryable"
                ))
            } else {
                nonRetryable.add(NonRetryableItem(
                    itemId = failure.itemId,
                    itemIndex = failure.itemIndex,
                    reason = "Category ${failure.errorCategory.value} is not retryable"
                ))
            }
        }

        val retryRate = if (failures.isNotEmpty()) {
            retryable.size.toDouble() / failures.size
        } else 0.0

        return RetryableItemsResult(
            retryable = retryable,
            nonRetryable = nonRetryable,
            totalFailures = failures.size,
            retryableCount = retryable.size,
            nonRetryableCount = nonRetryable.size,
            retryRate = retryRate
        )
    }

    /**
     * Calculate backoff delay for retry attempt using Swift engine.
     */
    fun calculateBackoff(
        attempt: Int,
        strategy: BackoffStrategy = BackoffStrategy.EXPONENTIAL_WITH_JITTER,
        baseDelayMs: Long = 1000L,
        maxDelayMs: Long = 30000L
    ): Long {
        val swiftResult = SwiftBatchOperationsEngine.calculateBackoff(
            attempt,
            strategy.value,
            baseDelayMs.toInt(),
            maxDelayMs.toInt(),
            arena
        )
        return swiftResult.delayMs.toLong()
    }

    // MARK: - Result Aggregation

    /**
     * Aggregate batch results from chunk processing.
     */
    fun aggregateBatchResults(
        chunkResults: List<ChunkResult>,
        correlationId: String,
        startTimestampMs: Long
    ): AggregatedBatchResult {
        val totalSuccess = chunkResults.sumOf { it.successCount }
        val totalFailure = chunkResults.sumOf { it.failureCount }
        val totalItems = totalSuccess + totalFailure
        val totalDuration = chunkResults.sumOf { it.durationMs }
        val hasRetries = chunkResults.any { it.retryCount > 0 }
        val retrySuccesses = chunkResults.filter { it.retryCount > 0 }.sumOf { it.successCount }

        // Count top errors
        val errorCounts = mutableMapOf<String, Int>()
        chunkResults.flatMap { it.errors ?: emptyList() }.forEach { error ->
            errorCounts[error.code] = (errorCounts[error.code] ?: 0) + 1
        }
        val topErrors = errorCounts.entries
            .sortedByDescending { it.value }
            .take(5)
            .map { ErrorCount(code = it.key, count = it.value) }

        val successRate = if (totalItems > 0) {
            totalSuccess.toDouble() / totalItems
        } else 0.0

        val itemsPerSecond = if (totalDuration > 0) {
            totalItems.toDouble() / (totalDuration / 1000.0)
        } else 0.0

        val status = when {
            totalFailure == 0 && totalSuccess > 0 -> BatchStatus.SUCCESS
            totalSuccess == 0 && totalFailure > 0 -> BatchStatus.FAILURE
            else -> BatchStatus.PARTIAL_SUCCESS
        }

        return AggregatedBatchResult(
            correlationId = correlationId,
            status = status,
            totalItems = totalItems,
            successCount = totalSuccess,
            failureCount = totalFailure,
            successRate = successRate,
            chunkCount = chunkResults.size,
            totalDurationMs = totalDuration,
            itemsPerSecond = itemsPerSecond,
            topErrors = topErrors,
            hasRetries = hasRetries,
            retrySuccessCount = retrySuccesses
        )
    }

    // MARK: - Correlation ID

    /**
     * Generate a unique correlation ID for batch tracking.
     */
    fun generateCorrelationId(): String {
        return "batch-${UUID.randomUUID()}"
    }
}

// MARK: - Data Models

/**
 * Type of batch operation.
 */
@Serializable
enum class BatchOperationType(val value: String) {
    CREATE("create"),
    UPDATE("update"),
    DELETE("delete"),
    SYNC("sync"),
    UPSERT("upsert")
}

/**
 * Constraints for batch operations.
 */
@Serializable
data class BatchConstraints(
    val maxBatchSize: Int = 1000,
    val minBatchSize: Int = 1,
    val allowBatchDelete: Boolean = true,
    val maxProcessingTimeSeconds: Int = 300,
    val requireUniqueIds: Boolean = true
) {
    companion object {
        val DEFAULT = BatchConstraints()
        val STRICT = BatchConstraints(
            maxBatchSize = 100,
            allowBatchDelete = false,
            maxProcessingTimeSeconds = 60
        )
        val BULK = BatchConstraints(
            maxBatchSize = 10000,
            minBatchSize = 100,
            maxProcessingTimeSeconds = 600
        )
    }
}

/**
 * Validation policy for batch operations.
 */
enum class ValidationPolicy {
    STRICT,         // All items must be valid
    ALLOW_PARTIAL,  // Allow if some items valid
    WARN_ONLY       // Only log warnings
}

/**
 * Result of batch validation.
 */
@Serializable
data class BatchValidationResult(
    val isValid: Boolean,
    val errors: List<BatchValidationError> = emptyList(),
    val warnings: List<String> = emptyList(),
    val validItemCount: Int = 0,
    val invalidItemCount: Int = 0,
    val totalItems: Int = 0,
    val successRate: Double = 0.0
)

/**
 * Validation error for a batch item.
 */
@Serializable
data class BatchValidationError(
    val code: String,
    val message: String,
    val itemIndex: Int? = null
)

/**
 * Configuration for chunk splitting.
 */
@Serializable
data class ChunkConfig(
    val defaultChunkSize: Int = 50,
    val minChunkSize: Int = 10,
    val maxChunkSize: Int = 100,
    val maxBytesPerChunk: Int = 1_000_000
) {
    companion object {
        val DEFAULT = ChunkConfig()
        val CONSERVATIVE = ChunkConfig(
            defaultChunkSize = 20,
            minChunkSize = 5,
            maxChunkSize = 50
        )
        val AGGRESSIVE = ChunkConfig(
            defaultChunkSize = 100,
            minChunkSize = 25,
            maxChunkSize = 200
        )
    }
}

/**
 * Context for batch operations.
 */
@Serializable
data class BatchContext(
    val connectionQuality: ConnectionQuality = ConnectionQuality.GOOD,
    val averageItemSizeBytes: Int? = null,
    val availableMemoryMB: Int? = null,
    val preferLargeChunks: Boolean = false
)

/**
 * Connection quality levels.
 */
@Serializable
enum class ConnectionQuality(val value: String) {
    EXCELLENT("excellent"),
    GOOD("good"),
    FAIR("fair"),
    POOR("poor"),
    OFFLINE("offline")
}

/**
 * Result of chunk size calculation.
 */
@Serializable
data class ChunkSizeResult(
    val recommendedSize: Int,
    val chunkCount: Int,
    val totalItems: Int,
    val reason: String,
    val isSingleChunk: Boolean
)

/**
 * Configuration for retry behavior.
 */
@Serializable
data class BatchRetryConfig(
    val maxRetries: Int = 3,
    val baseDelaySeconds: Double = 1.0,
    val maxDelaySeconds: Double = 30.0,
    val backoffStrategy: BackoffStrategy = BackoffStrategy.EXPONENTIAL_WITH_JITTER,
    val retryNetworkErrors: Boolean = true,
    val retryTimeouts: Boolean = true,
    val retryConflicts: Boolean = false,
    val retryUnknownErrors: Boolean = false,
    val retryOnTotalFailure: Boolean = false,
    val maxFailureRateForPartialRetry: Double = 0.5
) {
    companion object {
        val DEFAULT = BatchRetryConfig()
        val AGGRESSIVE = BatchRetryConfig(
            maxRetries = 5,
            baseDelaySeconds = 0.5,
            maxDelaySeconds = 60.0,
            retryConflicts = true,
            retryUnknownErrors = true,
            retryOnTotalFailure = true,
            maxFailureRateForPartialRetry = 0.8
        )
        val CONSERVATIVE = BatchRetryConfig(
            maxRetries = 2,
            baseDelaySeconds = 2.0,
            maxDelaySeconds = 10.0,
            retryTimeouts = false,
            maxFailureRateForPartialRetry = 0.3
        )
    }
}

/**
 * Backoff strategies for retries.
 */
@Serializable
enum class BackoffStrategy(val value: String) {
    CONSTANT("constant"),
    LINEAR("linear"),
    EXPONENTIAL("exponential"),
    EXPONENTIAL_WITH_JITTER("exponentialWithJitter")
}

/**
 * A failed batch item.
 */
@Serializable
data class BatchItemFailure(
    val itemId: String,
    val itemIndex: Int,
    val errorCode: String,
    val errorMessage: String,
    val errorCategory: BatchErrorCategory,
    val retryCount: Int = 0
)

/**
 * Categories of batch errors.
 */
@Serializable
enum class BatchErrorCategory(val value: String) {
    TRANSIENT("transient"),
    NETWORK("network"),
    TIMEOUT("timeout"),
    RATE_LIMIT("rateLimit"),
    VALIDATION("validation"),
    AUTHORIZATION("authorization"),
    NOT_FOUND("notFound"),
    CONFLICT("conflict"),
    SERVER_ERROR("serverError"),
    UNKNOWN("unknown")
}

/**
 * Result of identifying retryable items.
 */
@Serializable
data class RetryableItemsResult(
    val retryable: List<RetryableItem> = emptyList(),
    val nonRetryable: List<NonRetryableItem> = emptyList(),
    val totalFailures: Int = 0,
    val retryableCount: Int = 0,
    val nonRetryableCount: Int = 0,
    val retryRate: Double = 0.0
)

/**
 * An item that can be retried.
 */
@Serializable
data class RetryableItem(
    val itemId: String,
    val itemIndex: Int,
    val retryCount: Int,
    val suggestedDelaySeconds: Double,
    val reason: String
)

/**
 * An item that cannot be retried.
 */
@Serializable
data class NonRetryableItem(
    val itemId: String,
    val itemIndex: Int,
    val reason: String
)

/**
 * Result from processing a single chunk.
 */
@Serializable
data class ChunkResult(
    val chunkIndex: Int,
    val successCount: Int,
    val failureCount: Int,
    val durationMs: Int,
    val retryCount: Int = 0,
    val errors: List<ChunkError>? = null
)

/**
 * Error from chunk processing.
 */
@Serializable
data class ChunkError(
    val code: String,
    val message: String,
    val category: String,
    val itemIndex: Int? = null
)

/**
 * Aggregated result from all chunks.
 */
@Serializable
data class AggregatedBatchResult(
    val correlationId: String,
    val status: BatchStatus,
    val totalItems: Int,
    val successCount: Int,
    val failureCount: Int,
    val successRate: Double,
    val chunkCount: Int,
    val totalDurationMs: Int,
    val itemsPerSecond: Double,
    val topErrors: List<ErrorCount> = emptyList(),
    val hasRetries: Boolean = false,
    val retrySuccessCount: Int = 0
) {
    val isFullySuccessful: Boolean get() = failureCount == 0
    val isPartialSuccess: Boolean get() = successCount > 0 && failureCount > 0
    val isCompleteFailure: Boolean get() = successCount == 0 && failureCount > 0
}

/**
 * Overall batch status.
 */
@Serializable
enum class BatchStatus(val value: String) {
    SUCCESS("success"),
    PARTIAL_SUCCESS("partialSuccess"),
    FAILURE("failure")
}

/**
 * Count of a specific error code.
 */
@Serializable
data class ErrorCount(
    val code: String,
    val count: Int
)
