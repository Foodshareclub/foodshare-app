package com.foodshare.core.optimistic

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.security.MessageDigest
import java.time.Instant
import java.time.format.DateTimeFormatter
import kotlin.math.min
import kotlin.math.pow

/**
 * Optimistic update lifecycle management.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for update state machines
 * - Rollback decision logic, backoff calculations are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - Update lifecycle management (create, apply, confirm, rollback)
 * - Rollback decision logic based on error categories
 * - Retry strategy with exponential backoff
 * - Idempotency key generation and duplicate detection
 * - Batch processing with conflict detection
 */
object OptimisticUpdateBridge {

    // ========================================================================
    // Update Lifecycle
    // ========================================================================

    /**
     * Create an optimistic update.
     *
     * @param id Entity identifier
     * @param entityType Type of entity being updated
     * @param operation Type of operation (create, update, delete, etc.)
     * @param originalValue JSON string of original value (null for creates)
     * @param optimisticValue JSON string of optimistic value
     * @return OptimisticUpdate or null on failure
     */
    fun createUpdate(
        id: String,
        entityType: EntityType,
        operation: UpdateOperation,
        originalValue: String?,
        optimisticValue: String
    ): OptimisticUpdate? {
        if (id.isBlank() || optimisticValue.isBlank()) return null

        val timestamp = DateTimeFormatter.ISO_INSTANT.format(Instant.now())

        return OptimisticUpdate(
            id = id,
            entityType = entityType,
            operation = operation,
            originalValue = originalValue,
            optimisticValue = optimisticValue,
            createdAt = timestamp,
            state = UpdateState.PENDING,
            retryCount = 0
        )
    }

    /**
     * Apply an optimistic update immediately.
     *
     * @param update The update to apply
     * @return ApplyResult with success status
     */
    fun applyUpdate(update: OptimisticUpdate): ApplyResult {
        // Validate state transition
        if (update.state != UpdateState.PENDING) {
            return ApplyResult(
                success = false,
                error = "Update must be in PENDING state to apply, current: ${update.state.value}",
                update = update
            )
        }

        // Transition to APPLIED state
        val appliedUpdate = update.copy(state = UpdateState.APPLIED)

        return ApplyResult(
            success = true,
            error = null,
            update = appliedUpdate
        )
    }

    /**
     * Confirm an optimistic update after server success.
     *
     * @param update The update to confirm
     * @return Confirmed update or original on failure
     */
    fun confirmUpdate(update: OptimisticUpdate): OptimisticUpdate {
        // Valid transitions to CONFIRMED: APPLIED, SYNCING
        return when (update.state) {
            UpdateState.APPLIED, UpdateState.SYNCING -> {
                update.copy(state = UpdateState.CONFIRMED)
            }
            else -> update
        }
    }

    // ========================================================================
    // Rollback
    // ========================================================================

    /**
     * Determine if rollback should occur based on error.
     *
     * @param error The error that occurred
     * @param update The update that failed
     * @param maxRetries Maximum retry attempts (default 3)
     * @return RollbackDecision with rollback recommendation
     */
    fun shouldRollback(
        error: UpdateError,
        update: OptimisticUpdate,
        maxRetries: Int = 3
    ): RollbackDecision {
        // Check if max retries exceeded
        if (update.retryCount >= maxRetries) {
            return RollbackDecision(
                shouldRollback = true,
                reason = RollbackReason.MAX_RETRIES_EXCEEDED,
                canRetry = false,
                suggestedDelay = null
            )
        }

        // Determine based on error category
        return when (error.category) {
            ErrorCategory.NETWORK -> {
                // Network errors are retryable
                val delay = calculateBackoffDelay(update.retryCount)
                RollbackDecision(
                    shouldRollback = false,
                    reason = RollbackReason.RETRYABLE,
                    canRetry = true,
                    suggestedDelay = delay
                )
            }
            ErrorCategory.SERVER_ERROR -> {
                // Server errors might recover, retry with longer delay
                val delay = calculateBackoffDelay(update.retryCount, baseDelay = 2.0)
                RollbackDecision(
                    shouldRollback = false,
                    reason = RollbackReason.RETRYABLE,
                    canRetry = true,
                    suggestedDelay = delay
                )
            }
            ErrorCategory.VALIDATION -> {
                // Validation errors won't succeed on retry
                RollbackDecision(
                    shouldRollback = true,
                    reason = RollbackReason.VALIDATION_FAILED,
                    canRetry = false,
                    suggestedDelay = null
                )
            }
            ErrorCategory.CONFLICT -> {
                // Conflicts require user intervention
                RollbackDecision(
                    shouldRollback = true,
                    reason = RollbackReason.SERVER_CONFLICT,
                    canRetry = false,
                    suggestedDelay = null
                )
            }
            ErrorCategory.AUTHORIZATION -> {
                // Auth errors require re-authentication
                RollbackDecision(
                    shouldRollback = true,
                    reason = RollbackReason.UNAUTHORIZED,
                    canRetry = false,
                    suggestedDelay = null
                )
            }
            ErrorCategory.UNKNOWN -> {
                // Unknown errors - rollback to be safe
                RollbackDecision(
                    shouldRollback = true,
                    reason = RollbackReason.UNKNOWN_ERROR,
                    canRetry = false,
                    suggestedDelay = null
                )
            }
        }
    }

    /**
     * Perform rollback for an update.
     *
     * @param update The update to rollback
     * @return RollbackResult with rollback status
     */
    fun rollback(update: OptimisticUpdate): RollbackResult {
        // Determine rollback action based on operation
        val action = when (update.operation) {
            UpdateOperation.CREATE -> RollbackAction.REMOVE_CREATED
            UpdateOperation.UPDATE -> RollbackAction.RESTORE_ORIGINAL
            UpdateOperation.DELETE -> RollbackAction.RESTORE_ORIGINAL
            UpdateOperation.FAVORITE, UpdateOperation.UNFAVORITE -> RollbackAction.RESTORE_ORIGINAL
        }

        // Transition to ROLLED_BACK state
        val rolledBackUpdate = update.copy(state = UpdateState.ROLLED_BACK)

        return RollbackResult(
            success = true,
            rolledBackUpdate = rolledBackUpdate,
            restoredValue = update.originalValue,
            action = action,
            error = null
        )
    }

    // ========================================================================
    // Retry Logic
    // ========================================================================

    /**
     * Increment retry count for an update.
     *
     * @param update The update to retry
     * @return Updated update with incremented retry count
     */
    fun incrementRetry(update: OptimisticUpdate): OptimisticUpdate {
        return update.copy(
            retryCount = update.retryCount + 1,
            state = UpdateState.PENDING  // Reset to pending for retry
        )
    }

    /**
     * Calculate exponential backoff delay.
     *
     * @param retryCount Current retry count
     * @param baseDelay Base delay in seconds (default 1.0)
     * @param maxDelay Maximum delay in seconds (default 30.0)
     * @return Delay in seconds
     */
    fun calculateBackoffDelay(
        retryCount: Int,
        baseDelay: Double = 1.0,
        maxDelay: Double = 30.0
    ): Double {
        // Exponential backoff: baseDelay * 2^retryCount
        val exponentialDelay = baseDelay * 2.0.pow(retryCount.toDouble())

        // Add jitter (±25%)
        val jitter = exponentialDelay * (Math.random() * 0.5 - 0.25)
        val delayWithJitter = exponentialDelay + jitter

        // Clamp to max delay
        return min(delayWithJitter, maxDelay)
    }

    // ========================================================================
    // Batch Operations
    // ========================================================================

    /**
     * Process batch of updates, determining which can be applied.
     *
     * @param updates List of updates to process
     * @return BatchProcessResult with applicable/rejected updates
     */
    fun processBatch(updates: List<OptimisticUpdate>): BatchProcessResult {
        if (updates.isEmpty()) {
            return BatchProcessResult(
                applicable = emptyList(),
                rejected = emptyList(),
                conflicts = emptyList()
            )
        }

        val applicable = mutableListOf<OptimisticUpdate>()
        val rejected = mutableListOf<OptimisticUpdate>()
        val conflicts = mutableListOf<BatchConflict>()

        // Group by entity key
        val byEntity = updates.groupBy { "${it.entityType.value}:${it.id}" }

        for ((_, entityUpdates) in byEntity) {
            if (entityUpdates.size == 1) {
                // Single update, no conflict possible
                applicable.add(entityUpdates.first())
            } else {
                // Multiple updates for same entity - detect conflicts
                // Sort by creation time
                val sorted = entityUpdates.sortedBy { it.createdAt }

                // First update is applicable
                applicable.add(sorted.first())

                // Rest are conflicts
                for (i in 1 until sorted.size) {
                    rejected.add(sorted[i])
                    conflicts.add(BatchConflict(first = sorted[i - 1], second = sorted[i]))
                }
            }
        }

        return BatchProcessResult(
            applicable = applicable,
            rejected = rejected,
            conflicts = conflicts
        )
    }

    // ========================================================================
    // Idempotency
    // ========================================================================

    /**
     * Generate an idempotency key for an update.
     *
     * @param userId Current user ID
     * @param entityType Type of entity
     * @param entityId Entity identifier
     * @param operation Type of operation
     * @return Idempotency key string
     */
    fun generateIdempotencyKey(
        userId: String,
        entityType: EntityType,
        entityId: String,
        operation: UpdateOperation
    ): String {
        // Create a unique key from components
        val input = "${userId}:${entityType.value}:${entityId}:${operation.value}:${System.currentTimeMillis()}"

        // Generate MD5 hash for compact key
        val md = MessageDigest.getInstance("MD5")
        val digest = md.digest(input.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    /**
     * Check if an operation is a duplicate.
     *
     * @param idempotencyKey Key to check
     * @param recentKeys List of recent idempotency keys
     * @param windowSeconds Time window in seconds (default 60) - not used in simple check
     * @return true if duplicate
     */
    fun isDuplicate(
        idempotencyKey: String,
        recentKeys: List<String>,
        @Suppress("UNUSED_PARAMETER") windowSeconds: Double = 60.0
    ): Boolean {
        // Simple check: key exists in recent keys
        return idempotencyKey in recentKeys
    }

    // ========================================================================
    // Convenience Methods
    // ========================================================================

    /**
     * Create and apply an optimistic update in one call.
     *
     * @param id Entity identifier
     * @param entityType Type of entity
     * @param operation Type of operation
     * @param originalValue Original value (null for creates)
     * @param optimisticValue New optimistic value
     * @return ApplyResult or null on failure
     */
    fun createAndApply(
        id: String,
        entityType: EntityType,
        operation: UpdateOperation,
        originalValue: String?,
        optimisticValue: String
    ): ApplyResult? {
        val update = createUpdate(id, entityType, operation, originalValue, optimisticValue)
            ?: return null
        return applyUpdate(update)
    }

    /**
     * Handle server error with automatic rollback decision.
     *
     * @param update The failed update
     * @param errorCode Error code from server
     * @param errorMessage Error message
     * @param category Error category
     * @return Pair of (should retry, delay in ms) or null to rollback immediately
     */
    fun handleError(
        update: OptimisticUpdate,
        errorCode: String,
        errorMessage: String,
        category: ErrorCategory
    ): RetryRecommendation {
        val error = UpdateError(
            code = errorCode,
            message = errorMessage,
            category = category,
            isRetryable = category == ErrorCategory.NETWORK || category == ErrorCategory.SERVER_ERROR
        )

        val decision = shouldRollback(error, update)

        return if (decision.shouldRollback) {
            RetryRecommendation(
                shouldRetry = false,
                shouldRollback = true,
                delayMs = null,
                reason = decision.reason.value
            )
        } else if (decision.canRetry) {
            val delayMs = ((decision.suggestedDelay ?: 1.0) * 1000).toLong()
            RetryRecommendation(
                shouldRetry = true,
                shouldRollback = false,
                delayMs = delayMs,
                reason = "retryable"
            )
        } else {
            RetryRecommendation(
                shouldRetry = false,
                shouldRollback = true,
                delayMs = null,
                reason = decision.reason.value
            )
        }
    }
}

// ========================================================================
// Data Classes
// ========================================================================

@Serializable
enum class EntityType(val value: String) {
    @SerialName("listing") LISTING("listing"),
    @SerialName("profile") PROFILE("profile"),
    @SerialName("favorite") FAVORITE("favorite"),
    @SerialName("review") REVIEW("review"),
    @SerialName("message") MESSAGE("message"),
    @SerialName("forum_post") FORUM_POST("forum_post"),
    @SerialName("forum_comment") FORUM_COMMENT("forum_comment")
}

@Serializable
enum class UpdateOperation(val value: String) {
    @SerialName("create") CREATE("create"),
    @SerialName("update") UPDATE("update"),
    @SerialName("delete") DELETE("delete"),
    @SerialName("favorite") FAVORITE("favorite"),
    @SerialName("unfavorite") UNFAVORITE("unfavorite")
}

@Serializable
enum class UpdateState(val value: String) {
    @SerialName("pending") PENDING("pending"),
    @SerialName("applied") APPLIED("applied"),
    @SerialName("syncing") SYNCING("syncing"),
    @SerialName("confirmed") CONFIRMED("confirmed"),
    @SerialName("failed") FAILED("failed"),
    @SerialName("rolled_back") ROLLED_BACK("rolled_back")
}

@Serializable
data class OptimisticUpdate(
    val id: String,
    val entityType: EntityType,
    val operation: UpdateOperation,
    val originalValue: String?,
    val optimisticValue: String,
    val createdAt: String,  // ISO8601
    val state: UpdateState,
    val retryCount: Int = 0
)

@Serializable
data class ApplyResult(
    val success: Boolean,
    val error: String? = null,
    val update: OptimisticUpdate
)

@Serializable
enum class ErrorCategory(val value: String) {
    @SerialName("network") NETWORK("network"),
    @SerialName("validation") VALIDATION("validation"),
    @SerialName("conflict") CONFLICT("conflict"),
    @SerialName("authorization") AUTHORIZATION("authorization"),
    @SerialName("server_error") SERVER_ERROR("server_error"),
    @SerialName("unknown") UNKNOWN("unknown")
}

@Serializable
data class UpdateError(
    val code: String,
    val message: String,
    val category: ErrorCategory,
    val isRetryable: Boolean
)

@Serializable
enum class RollbackReason(val value: String) {
    @SerialName("max_retries_exceeded") MAX_RETRIES_EXCEEDED("max_retries_exceeded"),
    @SerialName("validation_failed") VALIDATION_FAILED("validation_failed"),
    @SerialName("server_conflict") SERVER_CONFLICT("server_conflict"),
    @SerialName("unauthorized") UNAUTHORIZED("unauthorized"),
    @SerialName("unknown_error") UNKNOWN_ERROR("unknown_error"),
    @SerialName("retryable") RETRYABLE("retryable"),
    @SerialName("user_cancelled") USER_CANCELLED("user_cancelled")
}

@Serializable
data class RollbackDecision(
    val shouldRollback: Boolean,
    val reason: RollbackReason,
    val canRetry: Boolean,
    val suggestedDelay: Double? = null
)

@Serializable
enum class RollbackAction(val value: String) {
    @SerialName("none") NONE("none"),
    @SerialName("restore_original") RESTORE_ORIGINAL("restore_original"),
    @SerialName("remove_created") REMOVE_CREATED("remove_created"),
    @SerialName("refresh_from_server") REFRESH_FROM_SERVER("refresh_from_server")
}

@Serializable
data class RollbackResult(
    val success: Boolean,
    val rolledBackUpdate: OptimisticUpdate,
    val restoredValue: String?,
    val action: RollbackAction,
    val error: String? = null
)

@Serializable
data class BatchConflict(
    val first: OptimisticUpdate,
    val second: OptimisticUpdate
)

@Serializable
data class BatchProcessResult(
    val applicable: List<OptimisticUpdate>,
    val rejected: List<OptimisticUpdate>,
    val conflicts: List<BatchConflict>
) {
    val hasConflicts: Boolean get() = conflicts.isNotEmpty()
    val totalCount: Int get() = applicable.size + rejected.size
}

data class RetryRecommendation(
    val shouldRetry: Boolean,
    val shouldRollback: Boolean,
    val delayMs: Long?,
    val reason: String
)

// ========================================================================
// Extension Functions
// ========================================================================

/** Check if this update is pending. */
fun OptimisticUpdate.isPending(): Boolean = state == UpdateState.PENDING

/** Check if this update is applied but not confirmed. */
fun OptimisticUpdate.isApplied(): Boolean = state == UpdateState.APPLIED

/** Check if this update was successfully confirmed. */
fun OptimisticUpdate.isConfirmed(): Boolean = state == UpdateState.CONFIRMED

/** Check if this update failed and was rolled back. */
fun OptimisticUpdate.isRolledBack(): Boolean = state == UpdateState.ROLLED_BACK

/** Check if this update can be retried. */
fun OptimisticUpdate.canRetry(maxRetries: Int = 3): Boolean =
    retryCount < maxRetries && (state == UpdateState.FAILED || state == UpdateState.PENDING)
