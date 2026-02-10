package com.foodshare.core.cache

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Interface for repositories that support offline queueing of operations.
 *
 * When offline, operations are queued and executed when connectivity returns.
 *
 * SYNC: Mirrors iOS QueueableRepository protocol
 */
interface QueueableRepository {
    val syncManager: SyncManager
}

/**
 * Represents an operation queued for later execution.
 */
@Serializable
data class QueuedOperation(
    val id: String = UUID.randomUUID().toString(),
    val operationType: String,
    val entityType: String,
    val entityId: String,
    val payload: String,
    val timestamp: Long = System.currentTimeMillis(),
    val retryCount: Int = 0,
    val status: OperationStatus = OperationStatus.PENDING
) {
    @Serializable
    enum class OperationStatus {
        PENDING,
        IN_PROGRESS,
        COMPLETED,
        FAILED
    }
}

/**
 * Common operation types for queueing.
 */
object OperationType {
    const val TOGGLE_FAVORITE = "toggle_favorite"
    const val SEND_MESSAGE = "send_message"
    const val MARK_READ = "mark_read"
    const val TOGGLE_BOOKMARK = "toggle_bookmark"
    const val UPDATE_PROFILE = "update_profile"
    const val SUBMIT_REVIEW = "submit_review"
}

/**
 * Entity types for queue operations.
 */
object EntityType {
    const val LISTING = "listing"
    const val MESSAGE = "message"
    const val ROOM = "room"
    const val FORUM_POST = "forum_post"
    const val PROFILE = "profile"
    const val REVIEW = "review"
}

/**
 * Sync progress callback.
 */
data class SyncProgress(
    val total: Int,
    val completed: Int,
    val failed: Int,
    val currentOperation: String? = null
) {
    val remaining: Int get() = total - completed - failed
    val percentage: Float get() = if (total > 0) (completed.toFloat() / total) else 0f
    val isComplete: Boolean get() = remaining == 0
}

/**
 * Interface for managing offline operation sync.
 */
interface SyncManager {
    /**
     * Queue an operation for later execution.
     */
    suspend fun enqueue(operation: QueuedOperation)

    /**
     * Get all pending operations.
     */
    suspend fun getPending(): List<QueuedOperation>

    /**
     * Get pending operations by entity type.
     */
    suspend fun getPendingByType(entityType: String): List<QueuedOperation>

    /**
     * Mark operation as completed.
     */
    suspend fun markCompleted(operationId: String)

    /**
     * Mark operation as failed with retry increment.
     */
    suspend fun markFailed(operationId: String)

    /**
     * Remove completed/failed operations.
     */
    suspend fun cleanup()

    /**
     * Clear all pending operations.
     */
    suspend fun clearAll()

    /**
     * Observe pending operation count.
     */
    fun observePendingCount(): Flow<Int>

    /**
     * Observe sync progress during flush.
     */
    fun observeProgress(): Flow<SyncProgress?>

    /**
     * Execute all pending operations.
     *
     * @param executor Function to execute each operation
     * @return Number of successfully executed operations
     */
    suspend fun flush(executor: suspend (QueuedOperation) -> Boolean): Int
}

// DataStore extension for sync queue
private val Context.syncQueueDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "sync_queue"
)

/**
 * DataStore-based implementation of SyncManager.
 */
@Singleton
class DataStoreSyncManager @Inject constructor(
    private val context: Context
) : SyncManager {

    private val json = Json {
        ignoreUnknownKeys = true
        isLenient = true
    }

    private val _pendingCount = MutableStateFlow(0)
    private val _progress = MutableStateFlow<SyncProgress?>(null)

    companion object {
        private val OPERATIONS_KEY = stringPreferencesKey("queued_operations")
        private const val MAX_RETRIES = 3
    }

    override suspend fun enqueue(operation: QueuedOperation) {
        context.syncQueueDataStore.edit { prefs ->
            val existing = prefs[OPERATIONS_KEY]?.let {
                json.decodeFromString<List<QueuedOperation>>(it)
            } ?: emptyList()

            val updated = existing + operation
            prefs[OPERATIONS_KEY] = json.encodeToString(updated)
        }
        updatePendingCount()
    }

    override suspend fun getPending(): List<QueuedOperation> {
        val prefs = context.syncQueueDataStore.data.first()
        return prefs[OPERATIONS_KEY]?.let {
            json.decodeFromString<List<QueuedOperation>>(it)
        }?.filter { it.status == QueuedOperation.OperationStatus.PENDING }
            ?: emptyList()
    }

    override suspend fun getPendingByType(entityType: String): List<QueuedOperation> {
        return getPending().filter { it.entityType == entityType }
    }

    override suspend fun markCompleted(operationId: String) {
        updateOperationStatus(operationId, QueuedOperation.OperationStatus.COMPLETED)
    }

    override suspend fun markFailed(operationId: String) {
        context.syncQueueDataStore.edit { prefs ->
            val existing = prefs[OPERATIONS_KEY]?.let {
                json.decodeFromString<List<QueuedOperation>>(it)
            } ?: return@edit

            val updated = existing.map { op ->
                if (op.id == operationId) {
                    val newRetryCount = op.retryCount + 1
                    if (newRetryCount >= MAX_RETRIES) {
                        op.copy(status = QueuedOperation.OperationStatus.FAILED, retryCount = newRetryCount)
                    } else {
                        op.copy(retryCount = newRetryCount)
                    }
                } else op
            }
            prefs[OPERATIONS_KEY] = json.encodeToString(updated)
        }
        updatePendingCount()
    }

    override suspend fun cleanup() {
        context.syncQueueDataStore.edit { prefs ->
            val existing = prefs[OPERATIONS_KEY]?.let {
                json.decodeFromString<List<QueuedOperation>>(it)
            } ?: return@edit

            val active = existing.filter {
                it.status != QueuedOperation.OperationStatus.COMPLETED &&
                        it.status != QueuedOperation.OperationStatus.FAILED
            }
            prefs[OPERATIONS_KEY] = json.encodeToString(active)
        }
        updatePendingCount()
    }

    override suspend fun clearAll() {
        context.syncQueueDataStore.edit { prefs ->
            prefs.remove(OPERATIONS_KEY)
        }
        _pendingCount.value = 0
    }

    override fun observePendingCount(): Flow<Int> = _pendingCount.asStateFlow()

    override fun observeProgress(): Flow<SyncProgress?> = _progress.asStateFlow()

    override suspend fun flush(executor: suspend (QueuedOperation) -> Boolean): Int {
        val pending = getPending()
        if (pending.isEmpty()) return 0

        var completed = 0
        var failed = 0

        _progress.value = SyncProgress(
            total = pending.size,
            completed = 0,
            failed = 0
        )

        for (operation in pending) {
            _progress.value = _progress.value?.copy(
                currentOperation = "${operation.operationType}: ${operation.entityId}"
            )

            updateOperationStatus(operation.id, QueuedOperation.OperationStatus.IN_PROGRESS)

            val success = try {
                executor(operation)
            } catch (e: Exception) {
                false
            }

            if (success) {
                markCompleted(operation.id)
                completed++
            } else {
                markFailed(operation.id)
                failed++
            }

            _progress.value = SyncProgress(
                total = pending.size,
                completed = completed,
                failed = failed
            )
        }

        cleanup()
        _progress.value = null

        return completed
    }

    private suspend fun updateOperationStatus(
        operationId: String,
        status: QueuedOperation.OperationStatus
    ) {
        context.syncQueueDataStore.edit { prefs ->
            val existing = prefs[OPERATIONS_KEY]?.let {
                json.decodeFromString<List<QueuedOperation>>(it)
            } ?: return@edit

            val updated = existing.map { op ->
                if (op.id == operationId) op.copy(status = status) else op
            }
            prefs[OPERATIONS_KEY] = json.encodeToString(updated)
        }
        updatePendingCount()
    }

    private suspend fun updatePendingCount() {
        _pendingCount.value = getPending().size
    }
}

/**
 * Extension to queue operation if offline.
 *
 * @param isOnline Current connectivity status
 * @param syncManager The sync manager for queueing
 * @param operationType Type of operation (e.g., TOGGLE_FAVORITE)
 * @param entityType Type of entity (e.g., LISTING)
 * @param entityId ID of the entity
 * @param payload Serialized operation data
 * @param onlineAction Action to perform if online
 */
suspend fun <T> queueIfOffline(
    isOnline: Boolean,
    syncManager: SyncManager,
    operationType: String,
    entityType: String,
    entityId: String,
    payload: String,
    onlineAction: suspend () -> Result<T>
): Result<T> {
    return if (isOnline) {
        onlineAction()
    } else {
        syncManager.enqueue(
            QueuedOperation(
                operationType = operationType,
                entityType = entityType,
                entityId = entityId,
                payload = payload
            )
        )
        Result.failure(OfflineOperationQueuedException())
    }
}

/**
 * Exception thrown when an operation is queued for later execution.
 */
class OfflineOperationQueuedException : Exception("Operation queued for sync when online")

/**
 * Extension for batch operations.
 */
suspend fun SyncManager.enqueueBatch(operations: List<QueuedOperation>) {
    operations.forEach { enqueue(it) }
}
