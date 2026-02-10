package com.foodshare.core.sync

import android.content.Context
import android.util.Log
import androidx.hilt.work.HiltWorker
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker for background sync operations.
 *
 * Handles:
 * - Periodic delta sync
 * - One-time sync on network reconnection
 * - Processing pending offline operations
 *
 * SYNC: This mirrors Swift background task scheduling
 */
@HiltWorker
class SyncWorker @AssistedInject constructor(
    @Assisted context: Context,
    @Assisted params: WorkerParameters,
    private val syncManager: SyncManager
) : CoroutineWorker(context, params) {

    companion object {
        private const val TAG = "SyncWorker"

        // Work names
        const val PERIODIC_SYNC_WORK = "periodic_sync"
        const val ONE_TIME_SYNC_WORK = "one_time_sync"
        const val PENDING_OPS_WORK = "pending_operations"

        // Input data keys
        const val KEY_SYNC_TYPE = "sync_type"
        const val KEY_FORCE_FULL = "force_full"

        // Sync types
        const val SYNC_TYPE_FULL = "full"
        const val SYNC_TYPE_DELTA = "delta"
        const val SYNC_TYPE_PENDING = "pending"

        /**
         * Schedule periodic background sync.
         *
         * @param context Application context
         * @param intervalMinutes Sync interval in minutes (default 15)
         */
        fun schedulePeriodicSync(
            context: Context,
            intervalMinutes: Long = 15
        ) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .setRequiresBatteryNotLow(true)
                .build()

            val request = PeriodicWorkRequestBuilder<SyncWorker>(
                intervalMinutes, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    1, TimeUnit.MINUTES
                )
                .setInputData(workDataOf(
                    KEY_SYNC_TYPE to SYNC_TYPE_DELTA
                ))
                .build()

            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    PERIODIC_SYNC_WORK,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
                )

            Log.d(TAG, "Scheduled periodic sync every $intervalMinutes minutes")
        }

        /**
         * Cancel periodic sync.
         */
        fun cancelPeriodicSync(context: Context) {
            WorkManager.getInstance(context)
                .cancelUniqueWork(PERIODIC_SYNC_WORK)
            Log.d(TAG, "Cancelled periodic sync")
        }

        /**
         * Trigger immediate one-time sync.
         *
         * @param context Application context
         * @param forceFull Force full sync instead of delta
         */
        fun triggerImmediateSync(
            context: Context,
            forceFull: Boolean = false
        ) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<SyncWorker>()
                .setConstraints(constraints)
                .setInputData(workDataOf(
                    KEY_SYNC_TYPE to if (forceFull) SYNC_TYPE_FULL else SYNC_TYPE_DELTA,
                    KEY_FORCE_FULL to forceFull
                ))
                .build()

            WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    ONE_TIME_SYNC_WORK,
                    ExistingWorkPolicy.REPLACE,
                    request
                )

            Log.d(TAG, "Triggered immediate sync (forceFull=$forceFull)")
        }

        /**
         * Process pending offline operations.
         */
        fun processPendingOperations(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<SyncWorker>()
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    30, TimeUnit.SECONDS
                )
                .setInputData(workDataOf(
                    KEY_SYNC_TYPE to SYNC_TYPE_PENDING
                ))
                .build()

            WorkManager.getInstance(context)
                .enqueueUniqueWork(
                    PENDING_OPS_WORK,
                    ExistingWorkPolicy.REPLACE,
                    request
                )

            Log.d(TAG, "Scheduled pending operations processing")
        }
    }

    override suspend fun doWork(): Result {
        val syncType = inputData.getString(KEY_SYNC_TYPE) ?: SYNC_TYPE_DELTA
        Log.d(TAG, "Starting sync work: $syncType")

        return try {
            when (syncType) {
                SYNC_TYPE_FULL -> {
                    syncManager.performFullSync()
                        .fold(
                            onSuccess = {
                                Log.d(TAG, "Full sync completed: $it items")
                                Result.success()
                            },
                            onFailure = {
                                Log.e(TAG, "Full sync failed", it)
                                if (runAttemptCount < 3) Result.retry() else Result.failure()
                            }
                        )
                }

                SYNC_TYPE_DELTA -> {
                    syncManager.performDeltaSync()
                        .fold(
                            onSuccess = {
                                Log.d(TAG, "Delta sync completed: $it items")
                                Result.success()
                            },
                            onFailure = {
                                Log.e(TAG, "Delta sync failed", it)
                                if (runAttemptCount < 3) Result.retry() else Result.failure()
                            }
                        )
                }

                SYNC_TYPE_PENDING -> {
                    syncManager.processPendingOperations()
                        .fold(
                            onSuccess = {
                                Log.d(TAG, "Processed $it pending operations")
                                Result.success()
                            },
                            onFailure = {
                                Log.e(TAG, "Pending operations failed", it)
                                if (runAttemptCount < 3) Result.retry() else Result.failure()
                            }
                        )
                }

                else -> {
                    Log.w(TAG, "Unknown sync type: $syncType")
                    Result.failure()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Sync worker exception", e)
            if (runAttemptCount < 3) Result.retry() else Result.failure()
        }
    }
}

/**
 * Extension to start sync when app comes to foreground.
 */
fun SyncManager.scheduleBackgroundSync(context: Context) {
    SyncWorker.schedulePeriodicSync(context)
}

/**
 * Extension to trigger sync on network reconnection.
 */
fun NetworkMonitor.setupSyncOnReconnect(context: Context) {
    addReconnectionListener {
        SyncWorker.triggerImmediateSync(context)
        SyncWorker.processPendingOperations(context)
    }
}
