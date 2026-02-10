package com.foodshare.core.sync

import kotlinx.serialization.Serializable

/**
 * Delta sync implementation.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for sync algorithms
 * - Delta calculation and conflict resolution are pure functions
 * - No JNI required for these stateless operations
 */
object DeltaSyncBridge {

    // MARK: - Delta Sync

    /**
     * Calculate delta between local and server changes.
     *
     * @param localVersion Current local version number
     * @param serverVersion Current server version number
     * @param localChanges Changes made locally
     * @param remoteChanges Changes available on server
     * @return Delta result with changes to push/pull and conflicts
     */
    fun calculateDelta(
        localVersion: Int,
        serverVersion: Int,
        localChanges: List<SyncChange>,
        remoteChanges: List<SyncChange>
    ): DeltaResult {
        val conflicts = mutableListOf<SyncConflictModel>()

        // Build lookup maps for efficient access
        val localById = localChanges.associateBy { it.entityId }
        val remoteById = remoteChanges.associateBy { it.entityId }

        // Find changes that need to be pulled (remote changes not in local or newer)
        val changesToPull = mutableListOf<SyncChange>()
        for (remote in remoteChanges) {
            val local = localById[remote.entityId]
            if (local == null) {
                // Remote-only change, pull it
                changesToPull.add(remote)
            } else if (remote.version > local.version) {
                // Remote is newer by version, pull it (but may still conflict)
                changesToPull.add(remote)
            }
            // iOS parity: version mismatch detection happens in conflict detection below
        }

        // Find changes that need to be pushed (local changes not in remote or newer)
        val changesToPush = mutableListOf<SyncChange>()
        for (local in localChanges) {
            val remote = remoteById[local.entityId]
            if (remote == null) {
                // Local-only change, push it
                changesToPush.add(local)
            } else if (local.version > remote.version) {
                // Local is newer by version, push it (but may still conflict)
                changesToPush.add(local)
            }
        }

        // Detect conflicts - iOS parity: check for version mismatch during delta phase
        for (local in localChanges) {
            val remote = remoteById[local.entityId] ?: continue

            // iOS parity: detect concurrent modifications via version mismatch
            val hasVersionMismatch = local.version != remote.version &&
                local.version > 0 && remote.version > 0

            val conflictType = detectConflict(local, remote)
                ?: if (hasVersionMismatch) ConflictType.VERSION_MISMATCH else null

            if (conflictType != null) {
                conflicts.add(
                    SyncConflictModel(
                        id = "${local.entityId}_${System.currentTimeMillis()}",
                        entityType = local.entityType,
                        entityId = local.entityId,
                        localChange = local,
                        remoteChange = remote,
                        conflictType = conflictType,
                        detectedAt = System.currentTimeMillis().toDouble(),
                        severity = getSeverity(conflictType)
                    )
                )
            }
        }

        return DeltaResult(
            changesToPull = changesToPull,
            changesToPush = changesToPush,
            localVersion = localVersion,
            serverVersion = serverVersion,
            hasConflicts = conflicts.isNotEmpty(),
            conflicts = conflicts
        )
    }

    /**
     * Merge local and remote changes, resolving conflicts automatically where possible.
     *
     * @param localChanges Changes made locally
     * @param remoteChanges Changes from server
     * @return Merged changes with conflict information
     */
    fun mergeChanges(
        localChanges: List<SyncChange>,
        remoteChanges: List<SyncChange>
    ): MergedChanges {
        val merged = mutableListOf<SyncChange>()
        val conflicts = mutableListOf<SyncConflictModel>()
        var autoResolved = 0

        // Add all remote-only changes
        val localIds = localChanges.map { it.entityId }.toSet()
        merged.addAll(remoteChanges.filter { it.entityId !in localIds })

        // Add all local-only changes
        val remoteIds = remoteChanges.map { it.entityId }.toSet()
        merged.addAll(localChanges.filter { it.entityId !in remoteIds })

        // Handle overlapping changes
        for (local in localChanges) {
            val remote = remoteChanges.find { it.entityId == local.entityId } ?: continue
            val conflictType = detectConflict(local, remote)

            if (conflictType == null) {
                // No conflict - use the newer version (iOS parity: prefer local on tie)
                merged.add(if (local.timestamp >= remote.timestamp) local else remote)
            } else if (getSeverity(conflictType) == ConflictSeverity.LOW) {
                // Auto-resolve low severity conflicts using last-write-wins (iOS parity: prefer local on tie)
                merged.add(if (local.timestamp >= remote.timestamp) local else remote)
                autoResolved++
            } else {
                conflicts.add(
                    SyncConflictModel(
                        id = "${local.entityId}_${System.currentTimeMillis()}",
                        entityType = local.entityType,
                        entityId = local.entityId,
                        localChange = local,
                        remoteChange = remote,
                        conflictType = conflictType,
                        detectedAt = System.currentTimeMillis().toDouble(),
                        severity = getSeverity(conflictType)
                    )
                )
            }
        }

        return MergedChanges(
            merged = merged,
            conflicts = conflicts,
            autoResolved = autoResolved,
            requiresManual = conflicts.count { it.severity == ConflictSeverity.HIGH }
        )
    }

    // MARK: - Conflict Resolution

    /**
     * Resolve a sync conflict using the specified strategy.
     *
     * @param conflict The conflict to resolve
     * @param strategy Resolution strategy to use
     * @return Resolved change
     */
    fun resolveConflict(
        conflict: SyncConflictModel,
        strategy: ResolutionStrategy
    ): ResolvedChange {
        val resolvedChange = when (strategy) {
            ResolutionStrategy.KEEP_LOCAL -> conflict.localChange
            ResolutionStrategy.KEEP_REMOTE -> conflict.remoteChange
            ResolutionStrategy.LAST_WRITE_WINS ->
                // iOS parity: use >= to prefer local on timestamp tie
                if (conflict.localChange.timestamp >= conflict.remoteChange.timestamp)
                    conflict.localChange else conflict.remoteChange
            ResolutionStrategy.MERGE -> {
                // Simple merge: combine payloads with local priority
                val mergedPayload = conflict.remoteChange.payload + conflict.localChange.payload
                conflict.localChange.copy(
                    payload = mergedPayload,
                    version = maxOf(conflict.localChange.version, conflict.remoteChange.version) + 1
                )
            }
            ResolutionStrategy.MANUAL -> conflict.localChange
        }

        return ResolvedChange(
            change = resolvedChange,
            strategy = strategy,
            wasAutomatic = strategy != ResolutionStrategy.MANUAL,
            mergedFields = if (strategy == ResolutionStrategy.MERGE)
                conflict.localChange.payload.keys.toList() else null
        )
    }

    /**
     * Get recommended resolution strategy for a conflict.
     *
     * @param conflict The conflict to analyze
     * @return Recommended resolution strategy
     */
    fun getSuggestedStrategy(conflict: SyncConflictModel): ResolutionStrategy {
        return getSuggestedStrategy(conflict, ConflictPolicy.DEFAULT)
    }

    /**
     * Get recommended resolution strategy for a conflict with policy.
     * iOS parity: supports entity-type-specific strategy overrides.
     *
     * @param conflict The conflict to analyze
     * @param policy Conflict resolution policy
     * @return Recommended resolution strategy
     */
    fun getSuggestedStrategy(
        conflict: SyncConflictModel,
        policy: ConflictPolicy
    ): ResolutionStrategy {
        // iOS parity: check entity-specific overrides first
        policy.entityOverrides[conflict.entityType]?.let { return it }

        // Fall back to severity-based defaults
        return when (conflict.severity) {
            ConflictSeverity.LOW -> ResolutionStrategy.LAST_WRITE_WINS
            ConflictSeverity.MEDIUM -> policy.defaultStrategy
            ConflictSeverity.HIGH -> ResolutionStrategy.MANUAL
        }
    }

    /**
     * Detect conflict type between two changes.
     *
     * @param local Local change
     * @param remote Remote change
     * @return Conflict type, or null if no conflict
     */
    fun detectConflict(local: SyncChange, remote: SyncChange): ConflictType? {
        if (local.entityId != remote.entityId) return null

        return when {
            local.operation == ChangeOperation.UPDATE &&
                remote.operation == ChangeOperation.UPDATE -> ConflictType.UPDATE_UPDATE
            local.operation == ChangeOperation.UPDATE &&
                remote.operation == ChangeOperation.DELETE -> ConflictType.UPDATE_DELETE
            local.operation == ChangeOperation.DELETE &&
                remote.operation == ChangeOperation.UPDATE -> ConflictType.DELETE_UPDATE
            local.operation == ChangeOperation.CREATE &&
                remote.operation == ChangeOperation.CREATE -> ConflictType.CREATE_CREATE
            local.version != remote.version -> ConflictType.VERSION_MISMATCH
            else -> null
        }
    }

    /**
     * Prioritize conflicts for resolution.
     *
     * @param conflicts Conflicts to prioritize
     * @return Sorted conflicts (highest priority first)
     */
    fun prioritizeConflicts(conflicts: List<SyncConflictModel>): List<SyncConflictModel> {
        return conflicts.sortedByDescending { conflict ->
            when (conflict.severity) {
                ConflictSeverity.HIGH -> 3
                ConflictSeverity.MEDIUM -> 2
                ConflictSeverity.LOW -> 1
            }
        }
    }

    // MARK: - Validation

    /**
     * Validate a change object.
     *
     * @param change Change to validate
     * @return Validation result
     */
    fun validateChange(change: SyncChange): ChangeValidationResult {
        val errors = mutableListOf<String>()

        if (change.id.isBlank()) errors.add("Change ID is required")
        if (change.entityType.isBlank()) errors.add("Entity type is required")
        if (change.entityId.isBlank()) errors.add("Entity ID is required")
        if (change.version < 0) errors.add("Version must be non-negative")

        return ChangeValidationResult(
            isValid = errors.isEmpty(),
            errors = errors
        )
    }

    /**
     * Reconcile version numbers.
     *
     * @param localVersion Current local version
     * @param serverVersion Current server version
     * @return Next version to use
     */
    fun reconcileVersion(localVersion: Int, serverVersion: Int): Int {
        return maxOf(localVersion, serverVersion) + 1
    }

    // MARK: - Private Helpers

    private fun getSeverity(conflictType: ConflictType): ConflictSeverity {
        return when (conflictType) {
            ConflictType.UPDATE_UPDATE -> ConflictSeverity.MEDIUM
            ConflictType.UPDATE_DELETE -> ConflictSeverity.HIGH
            ConflictType.DELETE_UPDATE -> ConflictSeverity.HIGH
            ConflictType.CREATE_CREATE -> ConflictSeverity.MEDIUM
            ConflictType.VERSION_MISMATCH -> ConflictSeverity.LOW
        }
    }
}

// MARK: - Sync Models

/**
 * Represents a change to be synced.
 */
@Serializable
data class SyncChange(
    val id: String,
    val entityType: String,
    val entityId: String,
    val operation: ChangeOperation,
    val version: Int,
    val timestamp: Double,
    val payload: Map<String, String>
)

@Serializable
enum class ChangeOperation {
    CREATE,
    UPDATE,
    DELETE;

    companion object {
        fun fromOperationType(type: OperationType): ChangeOperation = when (type) {
            OperationType.CREATE -> CREATE
            OperationType.UPDATE -> UPDATE
            OperationType.DELETE -> DELETE
        }
    }
}

/**
 * Result of delta sync calculation.
 */
@Serializable
data class DeltaResult(
    val changesToPull: List<SyncChange>,
    val changesToPush: List<SyncChange>,
    val localVersion: Int,
    val serverVersion: Int,
    val hasConflicts: Boolean,
    val conflicts: List<SyncConflictModel>
) {
    companion object {
        fun empty(localVersion: Int, serverVersion: Int) = DeltaResult(
            changesToPull = emptyList(),
            changesToPush = emptyList(),
            localVersion = localVersion,
            serverVersion = serverVersion,
            hasConflicts = false,
            conflicts = emptyList()
        )
    }
}

/**
 * Result of merging changes.
 */
@Serializable
data class MergedChanges(
    val merged: List<SyncChange>,
    val conflicts: List<SyncConflictModel>,
    val autoResolved: Int,
    val requiresManual: Int
) {
    companion object {
        fun empty() = MergedChanges(
            merged = emptyList(),
            conflicts = emptyList(),
            autoResolved = 0,
            requiresManual = 0
        )
    }
}

/**
 * Represents a sync conflict.
 */
@Serializable
data class SyncConflictModel(
    val id: String,
    val entityType: String,
    val entityId: String,
    val localChange: SyncChange,
    val remoteChange: SyncChange,
    val conflictType: ConflictType,
    val detectedAt: Double,
    val severity: ConflictSeverity
)

@Serializable
enum class ConflictType {
    UPDATE_UPDATE,
    UPDATE_DELETE,
    DELETE_UPDATE,
    CREATE_CREATE,
    VERSION_MISMATCH
}

@Serializable
enum class ConflictSeverity {
    LOW,      // Auto-resolvable
    MEDIUM,   // Prefer one side
    HIGH      // Requires manual resolution
}

/**
 * Strategy for resolving conflicts.
 */
@Serializable
enum class ResolutionStrategy {
    KEEP_LOCAL,      // Use local version
    KEEP_REMOTE,     // Use remote version
    LAST_WRITE_WINS, // Use most recent timestamp
    MERGE,           // Attempt to merge changes
    MANUAL           // Requires manual intervention
}

/**
 * Result of conflict resolution.
 */
@Serializable
data class ResolvedChange(
    val change: SyncChange,
    val strategy: ResolutionStrategy,
    val wasAutomatic: Boolean,
    val mergedFields: List<String>? = null,
    val discardedFields: List<String>? = null
) {
    companion object {
        fun default(change: SyncChange) = ResolvedChange(
            change = change,
            strategy = ResolutionStrategy.KEEP_LOCAL,
            wasAutomatic = false
        )
    }
}

/**
 * Change validation result.
 */
@Serializable
data class ChangeValidationResult(
    val isValid: Boolean,
    val errors: List<String> = emptyList()
)

/**
 * Conflict resolution policy.
 * iOS parity: allows entity-type-specific strategy overrides.
 */
@Serializable
data class ConflictPolicy(
    val defaultStrategy: ResolutionStrategy = ResolutionStrategy.KEEP_REMOTE,
    val entityOverrides: Map<String, ResolutionStrategy> = emptyMap()
) {
    companion object {
        /**
         * Default policy: prefer remote for medium severity, manual for high.
         */
        val DEFAULT = ConflictPolicy()

        /**
         * Local-first policy: prefer local changes when possible.
         */
        val LOCAL_FIRST = ConflictPolicy(
            defaultStrategy = ResolutionStrategy.KEEP_LOCAL
        )

        /**
         * Remote-first policy: prefer remote changes when possible.
         */
        val REMOTE_FIRST = ConflictPolicy(
            defaultStrategy = ResolutionStrategy.KEEP_REMOTE
        )

        /**
         * Food-sharing optimized policy: prioritize listing availability.
         */
        val FOOD_SHARING = ConflictPolicy(
            defaultStrategy = ResolutionStrategy.LAST_WRITE_WINS,
            entityOverrides = mapOf(
                "listing" to ResolutionStrategy.LAST_WRITE_WINS,
                "message" to ResolutionStrategy.KEEP_LOCAL,  // Local messages shouldn't be lost
                "profile" to ResolutionStrategy.MERGE        // Profile fields can be merged
            )
        )
    }

    /**
     * Get strategy for a specific entity type.
     */
    fun strategyFor(entityType: String): ResolutionStrategy {
        return entityOverrides[entityType] ?: defaultStrategy
    }
}
