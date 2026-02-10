package com.foodshare.core.sync

import android.util.Log

/**
 * Integration layer for SyncManager with delta sync algorithms.
 *
 * Architecture (Frameo pattern):
 * - Uses DeltaSyncBridge for sync calculations
 * - No JNI required - all operations are local
 */
object SyncManagerIntegration {

    private const val TAG = "SyncManagerIntegration"

    /**
     * Convert pending operations to SyncChange format for Swift processing.
     */
    fun convertToSyncChanges(operations: List<PendingOperation>): List<SyncChange> {
        return operations.map { op ->
            SyncChange(
                id = op.id,
                entityType = op.tableName,
                entityId = op.recordId ?: "",
                operation = ChangeOperation.fromOperationType(op.type),
                version = 1, // Version tracking would be added to PendingOperation
                timestamp = op.createdAt.toDouble() / 1000.0, // Convert ms to seconds
                payload = parsePayload(op.payload)
            )
        }
    }

    /**
     * Calculate what needs to be synced using Swift delta algorithm.
     */
    fun calculateSyncDelta(
        localVersion: Int,
        serverVersion: Int,
        localOperations: List<PendingOperation>,
        serverChanges: List<SyncChange>
    ): DeltaResult {
        val localChanges = convertToSyncChanges(localOperations)

        return DeltaSyncBridge.calculateDelta(
            localVersion = localVersion,
            serverVersion = serverVersion,
            localChanges = localChanges,
            remoteChanges = serverChanges
        )
    }

    /**
     * Resolve a sync conflict using Swift logic.
     *
     * Example usage in SyncManager.handleConflict():
     * ```
     * val conflict = SyncManagerIntegration.buildConflict(operation, remoteData)
     * val strategy = DeltaSyncBridge.getSuggestedStrategy(conflict)
     * val resolved = DeltaSyncBridge.resolveConflict(conflict, strategy)
     * ```
     */
    fun buildConflict(
        localOperation: PendingOperation,
        remoteDataJson: String
    ): SyncConflictModel {
        val localChange = SyncChange(
            id = localOperation.id,
            entityType = localOperation.tableName,
            entityId = localOperation.recordId ?: "",
            operation = ChangeOperation.fromOperationType(localOperation.type),
            version = 1,
            timestamp = localOperation.createdAt.toDouble() / 1000.0,
            payload = parsePayload(localOperation.payload)
        )

        val remoteChange = SyncChange(
            id = "${localOperation.id}_remote",
            entityType = localOperation.tableName,
            entityId = localOperation.recordId ?: "",
            operation = ChangeOperation.UPDATE, // Assume update for now
            version = 2, // Server has newer version
            timestamp = System.currentTimeMillis().toDouble() / 1000.0,
            payload = parsePayload(remoteDataJson)
        )

        return SyncConflictModel(
            id = "${localOperation.id}_conflict",
            entityType = localOperation.tableName,
            entityId = localOperation.recordId ?: "",
            localChange = localChange,
            remoteChange = remoteChange,
            conflictType = ConflictType.UPDATE_UPDATE,
            detectedAt = System.currentTimeMillis().toDouble() / 1000.0,
            severity = ConflictSeverity.MEDIUM
        )
    }

    /**
     * Resolve a conflict and convert back to PendingOperation format.
     */
    fun resolveAndConvert(
        conflict: SyncConflictModel,
        resolution: ConflictResolution
    ): PendingOperation? {
        val strategy = when (resolution) {
            ConflictResolution.KEEP_LOCAL -> ResolutionStrategy.KEEP_LOCAL
            ConflictResolution.KEEP_REMOTE -> ResolutionStrategy.KEEP_REMOTE
            ConflictResolution.MERGE -> ResolutionStrategy.MERGE
            ConflictResolution.MANUAL -> ResolutionStrategy.MANUAL
        }

        val resolved = DeltaSyncBridge.resolveConflict(conflict, strategy)

        if (!resolved.wasAutomatic) {
            Log.w(TAG, "Conflict requires manual resolution: ${conflict.id}")
            return null
        }

        // Convert resolved change back to PendingOperation format
        return PendingOperation(
            id = resolved.change.id,
            type = when (resolved.change.operation) {
                ChangeOperation.CREATE -> OperationType.CREATE
                ChangeOperation.UPDATE -> OperationType.UPDATE
                ChangeOperation.DELETE -> OperationType.DELETE
            },
            tableName = resolved.change.entityType,
            recordId = resolved.change.entityId,
            payload = serializePayload(resolved.change.payload),
            createdAt = (resolved.change.timestamp * 1000).toLong(),
            retryCount = 0,
            lastError = null,
            idempotencyKey = java.util.UUID.randomUUID().toString()
        )
    }

    /**
     * Merge local and remote changes using Swift algorithm.
     */
    fun mergeChanges(
        localOperations: List<PendingOperation>,
        serverChanges: List<SyncChange>
    ): MergedChanges {
        val localChanges = convertToSyncChanges(localOperations)

        return DeltaSyncBridge.mergeChanges(
            localChanges = localChanges,
            remoteChanges = serverChanges
        )
    }

    /**
     * Validate a pending operation using Swift validation.
     */
    fun validateOperation(operation: PendingOperation): ChangeValidationResult {
        val change = SyncChange(
            id = operation.id,
            entityType = operation.tableName,
            entityId = operation.recordId ?: "",
            operation = ChangeOperation.fromOperationType(operation.type),
            version = 1,
            timestamp = operation.createdAt.toDouble() / 1000.0,
            payload = parsePayload(operation.payload)
        )

        return DeltaSyncBridge.validateChange(change)
    }

    /**
     * Get next version number for sync.
     */
    fun getNextVersion(localVersion: Int, serverVersion: Int): Int {
        return DeltaSyncBridge.reconcileVersion(localVersion, serverVersion)
    }

    // MARK: - Helper Methods

    /**
     * Parse JSON payload to Map<String, String>.
     */
    private fun parsePayload(json: String): Map<String, String> {
        return try {
            // Simple JSON parsing - in production use kotlinx.serialization
            val map = mutableMapOf<String, String>()
            // This is a simplified parser - you'd use proper JSON parsing here
            json.trim('{', '}')
                .split(',')
                .forEach { pair ->
                    val parts = pair.split(':')
                    if (parts.size == 2) {
                        val key = parts[0].trim().trim('"')
                        val value = parts[1].trim().trim('"')
                        map[key] = value
                    }
                }
            map
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse payload: ${e.message}")
            emptyMap()
        }
    }

    /**
     * Serialize payload map to JSON string.
     */
    private fun serializePayload(payload: Map<String, String>): String {
        return try {
            payload.entries.joinToString(",", "{", "}") { (key, value) ->
                "\"$key\":\"$value\""
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to serialize payload: ${e.message}")
            "{}"
        }
    }
}

/**
 * Extension to demonstrate integration in SyncManager.
 *
 * Usage example:
 * ```kotlin
 * class SyncManager {
 *     suspend fun performDeltaSyncWithSwift(): Result<Int> {
 *         val localOps = database.pendingOperationDao().getAll()
 *         val serverChanges = fetchServerChanges() // From Supabase
 *
 *         // Use Swift delta algorithm
 *         val delta = SyncManagerIntegration.calculateSyncDelta(
 *             localVersion = getCurrentVersion(),
 *             serverVersion = getServerVersion(),
 *             localOperations = localOps,
 *             serverChanges = serverChanges
 *         )
 *
 *         // Process changes
 *         pushChanges(delta.changesToPush)
 *         pullChanges(delta.changesToPull)
 *
 *         // Handle conflicts
 *         for (conflict in delta.conflicts) {
 *             val strategy = DeltaSyncBridge.getSuggestedStrategy(conflict)
 *             val resolved = DeltaSyncBridge.resolveConflict(conflict, strategy)
 *             if (resolved.wasAutomatic) {
 *                 applyResolvedChange(resolved)
 *             } else {
 *                 // Store for manual resolution
 *                 database.syncConflictDao().insert(conflict)
 *             }
 *         }
 *
 *         return Result.success(delta.changesToPull.size + delta.changesToPush.size)
 *     }
 * }
 * ```
 */
