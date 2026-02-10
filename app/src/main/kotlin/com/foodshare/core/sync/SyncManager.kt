package com.foodshare.core.sync

import android.content.Context
import android.util.Log
import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.network.RPCConfig
import com.foodshare.data.dto.FoodListingDto
import com.foodshare.domain.repository.BatchFavoriteOperation
import com.foodshare.domain.repository.FavoriteAction
import com.foodshare.domain.repository.FavoritesRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.rpc
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Sync state representation.
 */
sealed class SyncState {
    object Idle : SyncState()
    object Syncing : SyncState()
    data class Error(val message: String, val retryInMs: Long? = null) : SyncState()
    data class Success(val itemsSynced: Int, val timestamp: Long) : SyncState()
}

/**
 * Conflict resolution strategies.
 */
enum class ConflictResolution {
    /** Use the local version */
    KEEP_LOCAL,
    /** Use the remote/server version */
    KEEP_REMOTE,
    /** Attempt to merge changes */
    MERGE,
    /** Require manual resolution */
    MANUAL
}

/**
 * Manages offline-first sync with Supabase backend.
 *
 * Features:
 * - Delta sync using server-side versioning
 * - Pending operations queue for offline changes
 * - Automatic sync on network reconnection
 * - Conflict detection and resolution
 *
 * SYNC: This mirrors Swift FoodshareCore.SyncManager
 */
@Singleton
class SyncManager @Inject constructor(
    @ApplicationContext private val context: Context,
    private val supabaseClient: SupabaseClient,
    private val rpcClient: RateLimitedRPCClient,
    private val networkMonitor: NetworkMonitor,
    private val favoritesRepository: FavoritesRepository
) {
    companion object {
        private const val TAG = "SyncManager"
        private const val MAX_RETRIES = 3
        private const val BATCH_SIZE = 50
        private const val SYNC_DEBOUNCE_MS = 2000L
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val database = SyncDatabase.getInstance(context)
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private val _syncState = MutableStateFlow<SyncState>(SyncState.Idle)
    val syncState: StateFlow<SyncState> = _syncState.asStateFlow()

    private val _pendingCount = MutableStateFlow(0)
    val pendingCount: StateFlow<Int> = _pendingCount.asStateFlow()

    private val _conflictCount = MutableStateFlow(0)
    val conflictCount: StateFlow<Int> = _conflictCount.asStateFlow()

    private var lastSyncAttempt: Long = 0

    init {
        // Monitor pending operations
        scope.launch {
            database.pendingOperationDao().observeCount().collect {
                _pendingCount.value = it
            }
        }

        // Monitor conflicts
        scope.launch {
            database.syncConflictDao().observeUnresolvedCount().collect {
                _conflictCount.value = it
            }
        }

        // Setup network reconnection listener
        networkMonitor.addReconnectionListener {
            scope.launch {
                Log.d(TAG, "Network reconnected, triggering sync")
                delay(SYNC_DEBOUNCE_MS) // Debounce
                performFullSync()
            }
        }
    }

    /**
     * Perform a full sync: push pending changes, then pull delta updates.
     */
    suspend fun performFullSync(): Result<Int> {
        if (_syncState.value is SyncState.Syncing) {
            Log.d(TAG, "Sync already in progress")
            return Result.failure(IllegalStateException("Sync already in progress"))
        }

        if (!networkMonitor.isCurrentlyOnline()) {
            Log.d(TAG, "Offline, skipping sync")
            return Result.failure(IllegalStateException("No network connection"))
        }

        _syncState.value = SyncState.Syncing
        lastSyncAttempt = System.currentTimeMillis()

        return try {
            var totalSynced = 0

            // 1. Process pending operations (push)
            val pushResult = processPendingOperations()
            pushResult.onSuccess { pushed ->
                totalSynced += pushed
                Log.d(TAG, "Pushed $pushed pending operations")
            }

            // 2. Perform delta sync (pull)
            val pullResult = performDeltaSync()
            pullResult.onSuccess { pulled ->
                totalSynced += pulled
                Log.d(TAG, "Pulled $pulled records")
            }

            _syncState.value = SyncState.Success(totalSynced, System.currentTimeMillis())
            Result.success(totalSynced)

        } catch (e: Exception) {
            Log.e(TAG, "Sync failed", e)
            _syncState.value = SyncState.Error(e.message ?: "Sync failed", 30_000)
            Result.failure(e)
        }
    }

    /**
     * Perform delta sync - fetch only changes since last sync.
     */
    suspend fun performDeltaSync(): Result<Int> {
        val userId = supabaseClient.auth.currentUserOrNull()?.id
            ?: return Result.failure(IllegalStateException("Not authenticated"))

        var totalPulled = 0

        // Sync listings
        val listingsVersion = database.syncVersionDao().getVersion("posts")?.version ?: 0
        val listingsResult = syncListings(listingsVersion)
        listingsResult.onSuccess { count ->
            totalPulled += count
        }

        return Result.success(totalPulled)
    }

    /**
     * Sync listings from server.
     */
    private suspend fun syncListings(sinceVersion: Long): Result<Int> {
        return try {
            // Call delta sync RPC
            val params = DeltaSyncParams(
                tableName = "posts",
                sinceVersion = sinceVersion,
                limit = BATCH_SIZE
            )

            val response = rpcClient.call<DeltaSyncParams, DeltaSyncResponse>(
                functionName = "get_delta_sync",
                params = params,
                config = RPCConfig.sync
            ).getOrThrow()

            // Update local cache
            val listings = response.records.map { record ->
                json.decodeFromString<FoodListingDto>(record.toString())
            }

            if (listings.isNotEmpty()) {
                val cached = listings.map { dto ->
                    CachedListing(
                        id = dto.id,
                        profileId = dto.profileId,
                        postName = dto.postName,
                        postDescription = dto.postDescription,
                        postType = dto.postType,
                        postAddress = dto.postAddress,
                        latitude = dto.latitude,
                        longitude = dto.longitude,
                        images = dto.images?.let { json.encodeToString(it) },
                        isActive = dto.isActive,
                        isArranged = dto.isArranged,
                        createdAt = dto.createdAt,
                        updatedAt = dto.updatedAt,
                        syncVersion = response.newVersion
                    )
                }
                database.cachedListingDao().upsertAll(cached)
            }

            // Update sync version
            database.syncVersionDao().upsert(
                SyncVersion(
                    tableName = "posts",
                    version = response.newVersion,
                    lastSyncAt = System.currentTimeMillis()
                )
            )

            Result.success(listings.size)

        } catch (e: Exception) {
            Log.e(TAG, "Failed to sync listings", e)
            Result.failure(e)
        }
    }

    /**
     * Process pending operations queue.
     */
    suspend fun processPendingOperations(): Result<Int> {
        var totalProcessed = 0

        // First, batch process favorites using the atomic RPC
        val favoritesResult = processPendingFavorites()
        favoritesResult.onSuccess { count ->
            totalProcessed += count
            Log.d(TAG, "Batch processed $count favorite operations")
        }

        // Then process other operations individually
        val pending = database.pendingOperationDao()
            .getPendingWithRetryLimit(MAX_RETRIES, BATCH_SIZE)
            .filter { it.tableName != "favorites" }

        if (pending.isEmpty()) {
            return Result.success(totalProcessed)
        }

        for (operation in pending) {
            if (!networkMonitor.isCurrentlyOnline()) {
                Log.d(TAG, "Went offline, stopping pending operations processing")
                break
            }

            try {
                processOperation(operation)
                database.pendingOperationDao().delete(operation)
                totalProcessed++
            } catch (e: Exception) {
                Log.e(TAG, "Failed to process operation ${operation.id}", e)
                database.pendingOperationDao().incrementRetry(operation.id, e.message)

                // Check for conflict
                if (isConflictError(e)) {
                    handleConflict(operation, e)
                }
            }
        }

        return Result.success(totalProcessed)
    }

    /**
     * Batch process pending favorite operations using atomic RPC.
     *
     * This is more efficient than individual operations and handles
     * mixed add/remove operations in a single request.
     */
    private suspend fun processPendingFavorites(): Result<Int> {
        val pendingFavorites = database.pendingOperationDao()
            .getPendingWithRetryLimit(MAX_RETRIES, BATCH_SIZE)
            .filter { it.tableName == "favorites" }

        if (pendingFavorites.isEmpty()) {
            return Result.success(0)
        }

        return try {
            // Convert pending operations to batch operations
            val batchOperations = pendingFavorites.mapNotNull { operation ->
                try {
                    val postId = operation.recordId?.toIntOrNull() ?: return@mapNotNull null
                    val action = when (operation.type) {
                        OperationType.CREATE -> FavoriteAction.ADD
                        OperationType.DELETE -> FavoriteAction.REMOVE
                        OperationType.UPDATE -> FavoriteAction.TOGGLE
                    }

                    BatchFavoriteOperation(
                        postId = postId,
                        action = action,
                        correlationId = operation.idempotencyKey ?: operation.id
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to parse favorite operation ${operation.id}", e)
                    null
                }
            }

            if (batchOperations.isEmpty()) {
                return Result.success(0)
            }

            // Call batch RPC
            val result = favoritesRepository.batchToggleFavorites(batchOperations)

            result.onSuccess { batchResult ->
                // Mark successful operations as completed
                val successfulIds = batchResult.results
                    .filter { it.success }
                    .map { it.correlationId }
                    .toSet()

                for (operation in pendingFavorites) {
                    val correlationId = operation.idempotencyKey ?: operation.id
                    if (correlationId in successfulIds) {
                        database.pendingOperationDao().delete(operation)
                    } else {
                        // Find the error for this operation
                        val opResult = batchResult.results.find { it.correlationId == correlationId }
                        database.pendingOperationDao().incrementRetry(
                            operation.id,
                            opResult?.error ?: "Unknown error"
                        )
                    }
                }

                Log.d(TAG, "Batch favorites: ${batchResult.processed} processed, " +
                        "${successfulIds.size} successful")
            }

            result.onFailure { e ->
                Log.e(TAG, "Batch favorites failed", e)
                // Increment retry for all operations
                for (operation in pendingFavorites) {
                    database.pendingOperationDao().incrementRetry(operation.id, e.message)
                }
            }

            Result.success(batchOperations.size)

        } catch (e: Exception) {
            Log.e(TAG, "Failed to batch process favorites", e)
            Result.failure(e)
        }
    }

    /**
     * Process a single pending operation.
     */
    private suspend fun processOperation(operation: PendingOperation) {
        when (operation.type) {
            OperationType.CREATE -> {
                supabaseClient.from(operation.tableName)
                    .insert(operation.payload) {
                        // Use idempotency key header if supported
                    }
            }
            OperationType.UPDATE -> {
                operation.recordId?.let { recordId ->
                    supabaseClient.from(operation.tableName)
                        .update(operation.payload) {
                            filter {
                                eq("id", recordId)
                            }
                        }
                }
            }
            OperationType.DELETE -> {
                operation.recordId?.let { recordId ->
                    supabaseClient.from(operation.tableName)
                        .delete {
                            filter {
                                eq("id", recordId)
                            }
                        }
                }
            }
        }
    }

    /**
     * Queue a pending operation for later sync.
     */
    suspend fun queueOperation(
        type: OperationType,
        table: String,
        recordId: String?,
        payload: Any
    ) {
        val operation = PendingOperation(
            id = UUID.randomUUID().toString(),
            type = type,
            tableName = table,
            recordId = recordId,
            payload = json.encodeToString(payload),
            createdAt = System.currentTimeMillis(),
            idempotencyKey = generateIdempotencyKey(type, table, recordId)
        )

        database.pendingOperationDao().insert(operation)
        Log.d(TAG, "Queued ${type.name} operation for $table")

        // Try to sync immediately if online
        if (networkMonitor.isCurrentlyOnline()) {
            scope.launch {
                delay(SYNC_DEBOUNCE_MS)
                processPendingOperations()
            }
        }
    }

    /**
     * Check if an exception indicates a conflict.
     */
    private fun isConflictError(e: Exception): Boolean {
        val message = e.message?.lowercase() ?: return false
        return message.contains("conflict") ||
                message.contains("409") ||
                message.contains("version mismatch") ||
                message.contains("concurrent modification")
    }

    /**
     * Handle a sync conflict.
     */
    private suspend fun handleConflict(operation: PendingOperation, error: Exception) {
        // Fetch remote version
        val remoteData = try {
            operation.recordId?.let { recordId ->
                supabaseClient.from(operation.tableName)
                    .select {
                        filter { eq("id", recordId) }
                    }
                    .decodeSingleOrNull<String>()
            } ?: "{}"
        } catch (e: Exception) {
            "{}"
        }

        val conflict = SyncConflict(
            id = UUID.randomUUID().toString(),
            tableName = operation.tableName,
            recordId = operation.recordId ?: "",
            localData = operation.payload,
            remoteData = remoteData,
            conflictType = "update_conflict",
            detectedAt = System.currentTimeMillis()
        )

        database.syncConflictDao().insert(conflict)
        Log.w(TAG, "Conflict detected for ${operation.tableName}:${operation.recordId}")
    }

    /**
     * Resolve a sync conflict.
     */
    suspend fun resolveConflict(
        conflictId: String,
        resolution: ConflictResolution,
        mergedData: String? = null
    ): Result<Unit> {
        val conflict = database.syncConflictDao().getUnresolved()
            .find { it.id == conflictId }
            ?: return Result.failure(IllegalArgumentException("Conflict not found"))

        return try {
            when (resolution) {
                ConflictResolution.KEEP_LOCAL -> {
                    // Re-queue the local changes
                    queueOperation(
                        OperationType.UPDATE,
                        conflict.tableName,
                        conflict.recordId,
                        conflict.localData
                    )
                }
                ConflictResolution.KEEP_REMOTE -> {
                    // Update local cache with remote data
                    // This happens automatically on next sync
                }
                ConflictResolution.MERGE -> {
                    // Use provided merged data
                    mergedData?.let { merged ->
                        queueOperation(
                            OperationType.UPDATE,
                            conflict.tableName,
                            conflict.recordId,
                            merged
                        )
                    }
                }
                ConflictResolution.MANUAL -> {
                    // Leave for manual resolution
                    return Result.success(Unit)
                }
            }

            database.syncConflictDao().resolve(
                conflictId,
                System.currentTimeMillis(),
                resolution.name
            )

            Result.success(Unit)

        } catch (e: Exception) {
            Log.e(TAG, "Failed to resolve conflict", e)
            Result.failure(e)
        }
    }

    /**
     * Get cached listings for offline display.
     */
    suspend fun getCachedListings(): List<CachedListing> {
        return database.cachedListingDao().getAll()
    }

    /**
     * Clear all sync data (call on logout).
     */
    suspend fun clearAllData() {
        database.syncVersionDao().clearAll()
        database.pendingOperationDao().clearAll()
        database.cachedListingDao().clearAll()
        database.cachedProfileDao().clearAll()
        database.syncConflictDao().clearAll()
        _syncState.value = SyncState.Idle
        Log.d(TAG, "Cleared all sync data")
    }

    /**
     * Cleanup old cached data.
     */
    suspend fun cleanupOldData(maxAgeMs: Long = 7 * 24 * 60 * 60 * 1000L) {
        val cutoff = System.currentTimeMillis() - maxAgeMs
        database.cachedListingDao().deleteOlderThan(cutoff)
        database.syncConflictDao().deleteResolvedOlderThan(cutoff)
        Log.d(TAG, "Cleaned up data older than ${maxAgeMs / (24 * 60 * 60 * 1000)} days")
    }
}

/**
 * Parameters for delta sync RPC.
 */
@Serializable
private data class DeltaSyncParams(
    val tableName: String,
    val sinceVersion: Long,
    val limit: Int = 50
)

/**
 * Response from delta sync RPC.
 */
@Serializable
private data class DeltaSyncResponse(
    val records: List<kotlinx.serialization.json.JsonElement>,
    val newVersion: Long,
    val hasMore: Boolean = false
)
