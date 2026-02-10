package com.foodshare.core.offline

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import kotlin.math.min
import kotlin.math.pow
import kotlin.random.Random

/**
 * Offline queue orchestrator.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for queue management
 * - Dependency graph and retry logic are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - Priority-based execution order
 * - Dependency graph for operation ordering
 * - Exponential backoff retry logic
 * - Conflict detection
 * - Integration with SyncManager
 */
object OfflineQueueBridge {

    private val operations = ConcurrentHashMap<String, QueuedOperation>()
    private val dependencyEdges = ConcurrentLinkedQueue<DependencyEdge>()

    private val _queueState = MutableStateFlow(QueueState())
    val queueState: StateFlow<QueueState> = _queueState.asStateFlow()

    private val eventListeners = mutableListOf<(OfflineQueueEvent) -> Unit>()

    // ========================================================================
    // Retry Logic
    // ========================================================================

    // Non-retryable error codes
    private val nonRetryableErrors = setOf(
        "INVALID_INPUT",
        "AUTH_ERROR",
        "FORBIDDEN",
        "NOT_FOUND",
        "VALIDATION_ERROR"
    )

    /**
     * Calculate retry delay with exponential backoff.
     */
    fun calculateRetryDelay(
        attempt: Int,
        baseDelayMs: Int = 5000,
        maxDelayMs: Int = 300000
    ): Int {
        // Exponential backoff with jitter
        val exponential = (baseDelayMs * 2.0.pow(attempt)).toInt()
        val jitter = Random.nextInt(0, (exponential * 0.3).toInt().coerceAtLeast(1))
        return min(exponential + jitter, maxDelayMs)
    }

    /**
     * Check if an operation should be retried.
     * Considers error type and retry count.
     */
    fun shouldRetryOperation(
        retryCount: Int,
        maxRetries: Int,
        errorCode: String?
    ): Boolean {
        if (retryCount >= maxRetries) return false
        if (errorCode != null && errorCode in nonRetryableErrors) return false
        return true
    }

    // ========================================================================
    // Queue Operations
    // ========================================================================

    /**
     * Enqueue an operation.
     */
    fun enqueue(operation: QueuedOperation) {
        operations[operation.id] = operation

        // Add to dependency graph if has dependencies
        operation.dependsOn.forEach { depId ->
            dependencyEdges.add(DependencyEdge(operation.id, depId))
        }

        updateState()
        emit(OfflineQueueEvent.OperationQueued(operation))
    }

    /**
     * Enqueue multiple operations.
     */
    fun enqueueAll(ops: List<QueuedOperation>) {
        ops.forEach { op ->
            operations[op.id] = op
            op.dependsOn.forEach { depId ->
                dependencyEdges.add(DependencyEdge(op.id, depId))
            }
        }
        updateState()
    }

    /**
     * Get an operation by ID.
     */
    fun getOperation(id: String): QueuedOperation? = operations[id]

    /**
     * Update operation status.
     */
    fun updateStatus(id: String, status: OperationStatus) {
        operations[id]?.let { op ->
            operations[id] = op.copy(status = status)
            updateState()
        }
    }

    /**
     * Remove an operation.
     */
    fun remove(id: String) {
        operations.remove(id)
        dependencyEdges.removeIf { it.from == id || it.to == id }
        updateState()
    }

    /**
     * Clear all operations.
     */
    fun clear() {
        operations.clear()
        dependencyEdges.clear()
        updateState()
        emit(OfflineQueueEvent.QueueCleared)
    }

    // ========================================================================
    // Dependency Graph
    // ========================================================================

    /**
     * Add a dependency between operations.
     */
    fun addDependency(fromId: String, toId: String): Boolean {
        // Check for cycles using DFS
        if (wouldCreateCycle(fromId, toId)) {
            return false
        }

        dependencyEdges.add(DependencyEdge(fromId, toId))
        return true
    }

    /**
     * Check if adding an edge would create a cycle.
     */
    private fun wouldCreateCycle(fromId: String, toId: String): Boolean {
        val edges = dependencyEdges.toList() + DependencyEdge(fromId, toId)
        val graph = edges.groupBy { it.from }.mapValues { it.value.map { e -> e.to } }

        // DFS to detect cycle
        val visited = mutableSetOf<String>()
        val recursionStack = mutableSetOf<String>()

        fun hasCycle(node: String): Boolean {
            if (node in recursionStack) return true
            if (node in visited) return false

            visited.add(node)
            recursionStack.add(node)

            for (neighbor in graph[node].orEmpty()) {
                if (hasCycle(neighbor)) return true
            }

            recursionStack.remove(node)
            return false
        }

        return graph.keys.any { hasCycle(it) }
    }

    /**
     * Get operations ready for execution (no pending dependencies).
     */
    fun getReadyOperations(): List<QueuedOperation> {
        val pending = operations.values
            .filter { it.status == OperationStatus.PENDING || it.status == OperationStatus.RETRYING }
            .map { it.id }
            .toSet()

        return operations.values
            .filter { op ->
                (op.status == OperationStatus.PENDING || op.status == OperationStatus.RETRYING) &&
                op.dependsOn.none { depId -> pending.contains(depId) }
            }
            .sortedByDescending { it.priority.ordinal }
    }

    /**
     * Get execution order using topological sort (Kahn's algorithm).
     */
    fun getExecutionOrder(): List<String>? {
        val edges = dependencyEdges.toList()
        val graph = edges.groupBy { it.from }.mapValues { it.value.map { e -> e.to }.toMutableList() }
        val inDegree = mutableMapOf<String, Int>()

        // Initialize in-degree for all nodes
        val allNodes = (edges.map { it.from } + edges.map { it.to }).toSet()
        allNodes.forEach { inDegree[it] = 0 }

        // Calculate in-degrees
        for (edge in edges) {
            inDegree[edge.to] = inDegree.getOrDefault(edge.to, 0) + 1
        }

        // Start with nodes that have no incoming edges
        val queue = ArrayDeque(inDegree.filter { it.value == 0 }.keys)
        val result = mutableListOf<String>()

        while (queue.isNotEmpty()) {
            val node = queue.removeFirst()
            result.add(node)

            for (neighbor in graph[node].orEmpty()) {
                inDegree[neighbor] = inDegree[neighbor]!! - 1
                if (inDegree[neighbor] == 0) {
                    queue.add(neighbor)
                }
            }
        }

        // If we couldn't process all nodes, there's a cycle
        return if (result.size == allNodes.size) result else null
    }

    /**
     * Mark operation as complete and remove from dependency graph.
     */
    fun markComplete(id: String) {
        operations[id]?.let { op ->
            operations[id] = op.copy(status = OperationStatus.COMPLETED)
            dependencyEdges.removeIf { it.to == id }
            updateState()
            emit(OfflineQueueEvent.OperationCompleted(op))
        }
    }

    /**
     * Mark operation as failed.
     */
    fun markFailed(id: String, error: String) {
        operations[id]?.let { op ->
            val updated = op.copy(
                status = OperationStatus.FAILED,
                lastError = error
            )
            operations[id] = updated
            updateState()
            emit(OfflineQueueEvent.OperationFailed(updated, error))
        }
    }

    /**
     * Retry an operation with incremented retry count.
     */
    fun retry(id: String, error: String): Boolean {
        val op = operations[id] ?: return false

        if (!shouldRetryOperation(op.retryCount, op.maxRetries, error)) {
            markFailed(id, error)
            return false
        }

        val updated = op.copy(
            status = OperationStatus.RETRYING,
            retryCount = op.retryCount + 1,
            lastError = error,
            lastAttemptAt = System.currentTimeMillis()
        )
        operations[id] = updated
        updateState()
        emit(OfflineQueueEvent.OperationRetrying(updated, updated.retryCount))
        return true
    }

    // ========================================================================
    // Query Methods
    // ========================================================================

    /**
     * Get all pending operations.
     */
    fun getPendingOperations(): List<QueuedOperation> =
        operations.values.filter { it.status == OperationStatus.PENDING }

    /**
     * Get all failed operations.
     */
    fun getFailedOperations(): List<QueuedOperation> =
        operations.values.filter { it.status == OperationStatus.FAILED }

    /**
     * Get operations for a specific entity.
     */
    fun getOperationsForEntity(
        entityType: String,
        entityId: String? = null
    ): List<QueuedOperation> =
        operations.values.filter { op ->
            op.entityType == entityType && (entityId == null || op.entityId == entityId)
        }

    /**
     * Check if queue is empty (no pending work).
     */
    fun isEmpty(): Boolean =
        operations.values.none {
            it.status in listOf(
                OperationStatus.PENDING,
                OperationStatus.IN_PROGRESS,
                OperationStatus.RETRYING
            )
        }

    /**
     * Get queue statistics.
     */
    fun getStats(): QueueStats {
        val ops = operations.values.toList()
        return QueueStats(
            totalCount = ops.size,
            pendingCount = ops.count { it.status == OperationStatus.PENDING },
            inProgressCount = ops.count { it.status == OperationStatus.IN_PROGRESS },
            completedCount = ops.count { it.status == OperationStatus.COMPLETED },
            failedCount = ops.count { it.status == OperationStatus.FAILED },
            blockedCount = ops.count { it.status == OperationStatus.BLOCKED },
            oldestOperationMs = ops.minOfOrNull { it.createdAt },
            newestOperationMs = ops.maxOfOrNull { it.createdAt }
        )
    }

    // ========================================================================
    // Event Handling
    // ========================================================================

    /**
     * Add event listener.
     */
    fun addEventListener(listener: (OfflineQueueEvent) -> Unit) {
        eventListeners.add(listener)
    }

    /**
     * Remove event listener.
     */
    fun removeEventListener(listener: (OfflineQueueEvent) -> Unit) {
        eventListeners.remove(listener)
    }

    private fun emit(event: OfflineQueueEvent) {
        eventListeners.forEach { it(event) }
    }

    private fun updateState() {
        _queueState.value = QueueState(
            stats = getStats(),
            readyCount = getReadyOperations().size,
            hasPendingWork = !isEmpty()
        )
    }
}

// ========================================================================
// Data Classes
// ========================================================================

@Serializable
data class QueuedOperation(
    val id: String = UUID.randomUUID().toString(),
    val operationType: String,
    val entityType: String,
    val entityId: String? = null,
    val payload: String,
    val createdAt: Long = System.currentTimeMillis(),
    val priority: OperationPriority = OperationPriority.NORMAL,
    val retryCount: Int = 0,
    val maxRetries: Int = 3,
    val lastError: String? = null,
    val lastAttemptAt: Long? = null,
    val idempotencyKey: String = UUID.randomUUID().toString(),
    val status: OperationStatus = OperationStatus.PENDING,
    val dependsOn: List<String> = emptyList(),
    val metadata: Map<String, String> = emptyMap()
) {
    val canRetry: Boolean
        get() = retryCount < maxRetries

    val isEligibleForExecution: Boolean
        get() = status == OperationStatus.PENDING || status == OperationStatus.RETRYING

    companion object {
        fun create(
            operationType: String,
            entityType: String,
            entityId: String? = null,
            payload: String,
            priority: OperationPriority = OperationPriority.NORMAL,
            dependsOn: List<String> = emptyList()
        ): QueuedOperation = QueuedOperation(
            operationType = operationType,
            entityType = entityType,
            entityId = entityId,
            payload = payload,
            priority = priority,
            dependsOn = dependsOn
        )
    }
}

@Serializable
enum class OperationStatus {
    PENDING,
    IN_PROGRESS,
    RETRYING,
    COMPLETED,
    FAILED,
    CANCELLED,
    BLOCKED
}

@Serializable
enum class OperationPriority {
    LOW,
    NORMAL,
    HIGH,
    CRITICAL
}

@Serializable
data class DependencyEdge(
    val from: String,
    val to: String
)

@Serializable
data class QueueStats(
    val totalCount: Int = 0,
    val pendingCount: Int = 0,
    val inProgressCount: Int = 0,
    val completedCount: Int = 0,
    val failedCount: Int = 0,
    val blockedCount: Int = 0,
    val oldestOperationMs: Long? = null,
    val newestOperationMs: Long? = null
) {
    val hasPendingWork: Boolean
        get() = pendingCount > 0 || inProgressCount > 0 || blockedCount > 0
}

data class QueueState(
    val stats: QueueStats = QueueStats(),
    val readyCount: Int = 0,
    val hasPendingWork: Boolean = false
)

sealed class OfflineQueueEvent {
    data class OperationQueued(val operation: QueuedOperation) : OfflineQueueEvent()
    data class OperationStarted(val operation: QueuedOperation) : OfflineQueueEvent()
    data class OperationCompleted(val operation: QueuedOperation) : OfflineQueueEvent()
    data class OperationFailed(val operation: QueuedOperation, val error: String) : OfflineQueueEvent()
    data class OperationRetrying(val operation: QueuedOperation, val attempt: Int) : OfflineQueueEvent()
    data object QueueStarted : OfflineQueueEvent()
    data object QueuePaused : OfflineQueueEvent()
    data object QueueCleared : OfflineQueueEvent()
    data class ConflictDetected(val operationId: String, val conflictType: String) : OfflineQueueEvent()
    data class NetworkStatusChanged(val isOnline: Boolean) : OfflineQueueEvent()
}

// ========================================================================
// Retry Policy Configuration
// ========================================================================

@Serializable
data class RetryPolicy(
    val maxRetries: Int = 3,
    val baseDelayMs: Int = 5000,
    val maxDelayMs: Int = 300000,
    val retryableErrorCodes: Set<String> = setOf(
        "TIMEOUT",
        "SERVER_ERROR",
        "NETWORK_ERROR",
        "OFFLINE"
    )
) {
    companion object {
        val DEFAULT = RetryPolicy()
        val AGGRESSIVE = RetryPolicy(maxRetries = 5, baseDelayMs = 2000)
        val CONSERVATIVE = RetryPolicy(maxRetries = 2, baseDelayMs = 10000)
    }

    fun getDelay(attempt: Int): Int =
        OfflineQueueBridge.calculateRetryDelay(attempt, baseDelayMs, maxDelayMs)

    fun shouldRetry(retryCount: Int, errorCode: String?): Boolean =
        OfflineQueueBridge.shouldRetryOperation(retryCount, maxRetries, errorCode)
}
