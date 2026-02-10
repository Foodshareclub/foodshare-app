package com.foodshare.core.repository

import kotlinx.serialization.Serializable
import java.security.MessageDigest

/**
 * Repository policy evaluation and data access patterns.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for policy evaluation
 * - Cache/offline decisions, conflict resolution are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - Cache policy evaluation
 * - Offline queue policy evaluation
 * - Conflict resolution strategies
 * - TTL configuration
 * - Cache key generation
 *
 * Example:
 *   val decision = RepositoryBridge.evaluateCachePolicy(
 *       OperationType.READ,
 *       CachePolicy.NETWORK_FIRST,
 *       isOnline = true
 *   )
 *   if (decision.shouldCheckCache) {
 *       checkCache()
 *   }
 */
object RepositoryBridge {

    // ========================================================================
    // Cache Policy Evaluation
    // ========================================================================

    /**
     * Evaluate cache policy for a request.
     */
    fun evaluateCachePolicy(
        operation: OperationType,
        cachePolicy: CachePolicy,
        isOnline: Boolean
    ): CachePolicyDecision {
        // Offline: always use cache if available
        if (!isOnline) {
            return CachePolicyDecision(
                shouldCheckCache = true,
                shouldFetchNetwork = false,
                shouldQueueOffline = operation.isMutation,
                effectivePolicy = CachePolicy.CACHE_ONLY.value
            )
        }

        // Evaluate based on policy
        return when (cachePolicy) {
            CachePolicy.NETWORK_ONLY -> CachePolicyDecision(
                shouldCheckCache = false,
                shouldFetchNetwork = true,
                shouldQueueOffline = false,
                effectivePolicy = cachePolicy.value
            )
            CachePolicy.NETWORK_FIRST -> CachePolicyDecision(
                shouldCheckCache = true,  // Fallback if network fails
                shouldFetchNetwork = true,
                shouldQueueOffline = false,
                effectivePolicy = cachePolicy.value
            )
            CachePolicy.CACHE_FIRST -> CachePolicyDecision(
                shouldCheckCache = true,
                shouldFetchNetwork = true,  // Refresh in background
                shouldQueueOffline = false,
                effectivePolicy = cachePolicy.value
            )
            CachePolicy.CACHE_ONLY -> CachePolicyDecision(
                shouldCheckCache = true,
                shouldFetchNetwork = false,
                shouldQueueOffline = false,
                effectivePolicy = cachePolicy.value
            )
            CachePolicy.STALE_WHILE_REVALIDATE -> CachePolicyDecision(
                shouldCheckCache = true,
                shouldFetchNetwork = true,
                shouldQueueOffline = false,
                effectivePolicy = cachePolicy.value
            )
            CachePolicy.CACHE_IF_FRESH -> CachePolicyDecision(
                shouldCheckCache = true,
                shouldFetchNetwork = true,  // Only if stale
                shouldQueueOffline = false,
                effectivePolicy = cachePolicy.value
            )
        }
    }

    // ========================================================================
    // Offline Policy Evaluation
    // ========================================================================

    /**
     * Evaluate offline policy for a request.
     */
    fun evaluateOfflinePolicy(
        operation: OperationType,
        offlinePolicy: OfflineQueuePolicy,
        isOnline: Boolean
    ): OfflinePolicyDecision {
        // If online, no queuing needed
        if (isOnline) {
            return OfflinePolicyDecision(
                shouldQueue = false,
                shouldFailImmediately = false,
                requiresConfirmation = false
            )
        }

        // Evaluate based on policy and operation
        return when (offlinePolicy) {
            OfflineQueuePolicy.ALWAYS_QUEUE -> OfflinePolicyDecision(
                shouldQueue = true,
                shouldFailImmediately = false,
                requiresConfirmation = false
            )
            OfflineQueuePolicy.QUEUE_IF_IDEMPOTENT -> OfflinePolicyDecision(
                shouldQueue = operation.isIdempotent,
                shouldFailImmediately = !operation.isIdempotent,
                requiresConfirmation = false
            )
            OfflineQueuePolicy.QUEUE_MUTATIONS -> OfflinePolicyDecision(
                shouldQueue = operation.isMutation,
                shouldFailImmediately = !operation.isMutation,
                requiresConfirmation = false
            )
            OfflineQueuePolicy.FAIL_IMMEDIATELY -> OfflinePolicyDecision(
                shouldQueue = false,
                shouldFailImmediately = true,
                requiresConfirmation = false
            )
            OfflineQueuePolicy.QUEUE_WITH_CONFIRMATION -> OfflinePolicyDecision(
                shouldQueue = true,
                shouldFailImmediately = false,
                requiresConfirmation = true
            )
        }
    }

    // ========================================================================
    // Conflict Resolution
    // ========================================================================

    /**
     * Suggest a conflict resolution strategy based on timestamps.
     */
    fun suggestConflictStrategy(
        localModifiedMs: Long,
        remoteModifiedMs: Long
    ): ConflictResolutionStrategy {
        // If timestamps are close (within 5 seconds), suggest merge or ask user
        val timeDiff = kotlin.math.abs(localModifiedMs - remoteModifiedMs)
        return when {
            timeDiff < 5000 -> ConflictResolutionStrategy.ASK_USER
            localModifiedMs > remoteModifiedMs -> ConflictResolutionStrategy.KEEP_LOCAL
            else -> ConflictResolutionStrategy.LAST_WRITE_WINS
        }
    }

    /**
     * Resolve a conflict with given strategy.
     */
    fun resolveConflict(
        strategy: ConflictResolutionStrategy,
        localModifiedMs: Long,
        remoteModifiedMs: Long
    ): ConflictWinner {
        return when (strategy) {
            ConflictResolutionStrategy.KEEP_LOCAL -> ConflictWinner.LOCAL
            ConflictResolutionStrategy.KEEP_REMOTE -> ConflictWinner.REMOTE
            ConflictResolutionStrategy.LAST_WRITE_WINS -> {
                if (localModifiedMs >= remoteModifiedMs) ConflictWinner.LOCAL
                else ConflictWinner.REMOTE
            }
            ConflictResolutionStrategy.MERGE -> ConflictWinner.MERGED
            ConflictResolutionStrategy.ASK_USER -> ConflictWinner.UNDECIDED
            ConflictResolutionStrategy.CUSTOM -> ConflictWinner.UNDECIDED
        }
    }

    // ========================================================================
    // TTL Configuration
    // ========================================================================

    /**
     * Get TTL for a data freshness type.
     */
    fun getTTL(freshness: DataFreshness): Long {
        return getTTLSeconds(freshness).toLong() * 1000
    }

    /**
     * Get TTL in seconds.
     */
    fun getTTLSeconds(freshness: DataFreshness): Double {
        return when (freshness) {
            DataFreshness.VOLATILE -> 10.0       // 10 seconds
            DataFreshness.SHORT -> 60.0          // 1 minute
            DataFreshness.MEDIUM -> 300.0        // 5 minutes
            DataFreshness.LONG -> 3600.0         // 1 hour
            DataFreshness.STATIC -> 86400.0      // 24 hours
        }
    }

    // ========================================================================
    // Cache Key Generation
    // ========================================================================

    /**
     * Generate cache key for an entity.
     */
    fun generateCacheKey(entityType: String, entityId: String): String {
        return "$entityType:$entityId"
    }

    /**
     * Generate cache key for a query.
     */
    fun generateCacheKey(entityType: String, queryParams: Map<String, String>): String {
        if (queryParams.isEmpty()) {
            return "$entityType:list"
        }

        // Sort params for consistent keys
        val sortedParams = queryParams.entries.sortedBy { it.key }
        val paramsStr = sortedParams.joinToString("&") { "${it.key}=${it.value}" }

        // Generate hash for long query strings
        val hash = MessageDigest.getInstance("MD5")
            .digest(paramsStr.toByteArray())
            .take(8)
            .joinToString("") { "%02x".format(it) }

        return "$entityType:list:$hash"
    }
}

// ========================================================================
// Enums
// ========================================================================

enum class OperationType(val value: String) {
    CREATE("create"),
    READ("read"),
    UPDATE("update"),
    DELETE("delete"),
    SYNC("sync"),
    BATCH("batch");

    val isIdempotent: Boolean
        get() = this in listOf(READ, DELETE)

    val isMutation: Boolean
        get() = this in listOf(CREATE, UPDATE, DELETE)
}

enum class CachePolicy(val value: String) {
    NETWORK_ONLY("network_only"),
    NETWORK_FIRST("network_first"),
    CACHE_FIRST("cache_first"),
    CACHE_ONLY("cache_only"),
    STALE_WHILE_REVALIDATE("stale_while_revalidate"),
    CACHE_IF_FRESH("cache_if_fresh");

    val usesCache: Boolean
        get() = this != NETWORK_ONLY

    val usesNetwork: Boolean
        get() = this != CACHE_ONLY

    val prefersCache: Boolean
        get() = this in listOf(CACHE_FIRST, CACHE_ONLY, STALE_WHILE_REVALIDATE, CACHE_IF_FRESH)
}

enum class OfflineQueuePolicy(val value: String) {
    ALWAYS_QUEUE("always_queue"),
    QUEUE_IF_IDEMPOTENT("queue_if_idempotent"),
    QUEUE_MUTATIONS("queue_mutations"),
    FAIL_IMMEDIATELY("fail_immediately"),
    QUEUE_WITH_CONFIRMATION("queue_with_confirmation");

    val allowsQueuing: Boolean
        get() = this != FAIL_IMMEDIATELY
}

enum class ConflictResolutionStrategy(val value: String) {
    KEEP_LOCAL("keep_local"),
    KEEP_REMOTE("keep_remote"),
    LAST_WRITE_WINS("last_write_wins"),
    MERGE("merge"),
    ASK_USER("ask_user"),
    CUSTOM("custom");

    companion object {
        fun fromValue(value: String): ConflictResolutionStrategy =
            entries.find { it.value == value } ?: LAST_WRITE_WINS
    }
}

enum class ConflictWinner(val value: String) {
    LOCAL("local"),
    REMOTE("remote"),
    MERGED("merged"),
    UNDECIDED("undecided");

    companion object {
        fun fromValue(value: String): ConflictWinner =
            entries.find { it.value == value } ?: UNDECIDED
    }
}

enum class DataFreshness(val value: String) {
    VOLATILE("volatile"),   // < 10s
    SHORT("short"),         // < 1min
    MEDIUM("medium"),       // < 5min
    LONG("long"),           // < 1hr
    STATIC("static");       // < 24hr

    companion object {
        fun fromTTLMs(ttlMs: Long): DataFreshness = when {
            ttlMs < 10_000 -> VOLATILE
            ttlMs < 60_000 -> SHORT
            ttlMs < 300_000 -> MEDIUM
            ttlMs < 3_600_000 -> LONG
            else -> STATIC
        }
    }
}

// ========================================================================
// Data Classes
// ========================================================================

@Serializable
data class CachePolicyDecision(
    val shouldCheckCache: Boolean,
    val shouldFetchNetwork: Boolean,
    val shouldQueueOffline: Boolean,
    val effectivePolicy: String
) {
    companion object {
        fun default(policy: CachePolicy) = CachePolicyDecision(
            shouldCheckCache = policy.usesCache,
            shouldFetchNetwork = policy.usesNetwork,
            shouldQueueOffline = false,
            effectivePolicy = policy.value
        )
    }
}

@Serializable
data class OfflinePolicyDecision(
    val shouldQueue: Boolean,
    val shouldFailImmediately: Boolean,
    val requiresConfirmation: Boolean
) {
    companion object {
        fun default() = OfflinePolicyDecision(
            shouldQueue = false,
            shouldFailImmediately = true,
            requiresConfirmation = false
        )
    }
}

@Serializable
data class RepositoryError(
    val code: String,
    val message: String,
    val isRetryable: Boolean = false,
    val isOfflineError: Boolean = false,
    val originalError: String? = null
) {
    companion object {
        val NOT_FOUND = RepositoryError("NOT_FOUND", "Resource not found")
        val UNAUTHORIZED = RepositoryError("UNAUTHORIZED", "Not authorized")
        val OFFLINE = RepositoryError("OFFLINE", "No network connection", isRetryable = true, isOfflineError = true)
        val TIMEOUT = RepositoryError("TIMEOUT", "Request timed out", isRetryable = true)
        val SERVER_ERROR = RepositoryError("SERVER_ERROR", "Server error", isRetryable = true)
        val VALIDATION = RepositoryError("VALIDATION_ERROR", "Validation failed")
        val CONFLICT = RepositoryError("CONFLICT", "Data conflict detected")
        val UNKNOWN = RepositoryError("UNKNOWN", "Unknown error")
    }
}
