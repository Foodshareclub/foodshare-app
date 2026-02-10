package com.foodshare.core.prefetch

import android.app.Application
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.os.Build
import android.os.PowerManager
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.work.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.concurrent.TimeUnit

/**
 * Prefetch scheduler state
 */
enum class PrefetchSchedulerState {
    IDLE,
    ACTIVE,
    PAUSED,
    BACKGROUND
}

/**
 * Scheduled prefetch types
 */
enum class ScheduledPrefetchType {
    FEED_REFRESH,
    NOTIFICATIONS_CHECK,
    MESSAGES_SYNC,
    USER_DATA_REFRESH,
    FAVORITES_SYNC
}

/**
 * Android-specific scheduler for intelligent prefetching
 */
class PrefetchScheduler private constructor(
    private val context: Context
) : DefaultLifecycleObserver {

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var networkCallback: ConnectivityManager.NetworkCallback? = null
    private var powerSaveModeReceiver: android.content.BroadcastReceiver? = null

    private val _state = MutableStateFlow(PrefetchSchedulerState.IDLE)
    val state: StateFlow<PrefetchSchedulerState> = _state.asStateFlow()

    private val _isWifiConnected = MutableStateFlow(false)
    val isWifiConnected: StateFlow<Boolean> = _isWifiConnected.asStateFlow()

    private val _isPowerSaveMode = MutableStateFlow(false)
    val isPowerSaveMode: StateFlow<Boolean> = _isPowerSaveMode.asStateFlow()

    private var idleJob: Job? = null
    private var periodicJob: Job? = null

    companion object {
        @Volatile
        private var instance: PrefetchScheduler? = null

        fun getInstance(context: Context): PrefetchScheduler {
            return instance ?: synchronized(this) {
                instance ?: PrefetchScheduler(context.applicationContext).also {
                    instance = it
                }
            }
        }

        private const val IDLE_PREFETCH_DELAY_MS = 5000L
        private const val PERIODIC_REFRESH_INTERVAL_MS = 60000L
        private const val WORK_NAME_PERIODIC = "prefetch_periodic"
        private const val WORK_NAME_BACKGROUND = "prefetch_background"
    }

    /**
     * Initialize the scheduler
     */
    fun initialize(application: Application) {
        // Initialize prefetch bridge
        PrefetchBridge.initialize(context)

        // Register lifecycle observer
        ProcessLifecycleOwner.get().lifecycle.addObserver(this)

        // Set up network monitoring
        setupNetworkMonitoring()

        // Set up power save mode monitoring
        setupPowerSaveModeMonitoring()

        // Schedule background work
        scheduleBackgroundWork()

        _state.value = PrefetchSchedulerState.IDLE
    }

    /**
     * Start the scheduler
     */
    fun start() {
        _state.value = PrefetchSchedulerState.ACTIVE
        startPeriodicRefresh()
    }

    /**
     * Stop the scheduler
     */
    fun stop() {
        _state.value = PrefetchSchedulerState.PAUSED
        idleJob?.cancel()
        periodicJob?.cancel()
        PrefetchBridge.pause()
    }

    /**
     * Shutdown the scheduler
     */
    fun shutdown() {
        stop()
        unregisterNetworkCallback()
        unregisterPowerSaveModeReceiver()
        scope.cancel()
        WorkManager.getInstance(context).cancelAllWorkByTag(WORK_NAME_PERIODIC)
        WorkManager.getInstance(context).cancelAllWorkByTag(WORK_NAME_BACKGROUND)
    }

    // MARK: - Lifecycle Callbacks

    override fun onStart(owner: LifecycleOwner) {
        // App came to foreground
        _state.value = PrefetchSchedulerState.ACTIVE

        // Update device state
        PrefetchBridge.updateDeviceState(context)

        // Resume prefetching
        PrefetchBridge.resume()

        // Trigger foreground prefetch
        triggerForegroundPrefetch()

        // Start periodic refresh
        startPeriodicRefresh()
    }

    override fun onStop(owner: LifecycleOwner) {
        // App went to background
        _state.value = PrefetchSchedulerState.BACKGROUND

        // Stop periodic refresh
        periodicJob?.cancel()

        // Pause non-critical prefetching
        if (_isPowerSaveMode.value || !_isWifiConnected.value) {
            PrefetchBridge.pause()
        }
    }

    // MARK: - Network Monitoring

    private fun setupNetworkMonitoring() {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val networkRequest = NetworkRequest.Builder()
            .addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            .build()

        networkCallback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                val capabilities = connectivityManager.getNetworkCapabilities(network)
                val isWifi = capabilities?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true

                _isWifiConnected.value = isWifi

                // Update device state
                PrefetchBridge.updateDeviceState(context)

                // Resume if on WiFi
                if (isWifi && _state.value == PrefetchSchedulerState.ACTIVE) {
                    PrefetchBridge.resume()
                    triggerNetworkRestoredPrefetch()
                }
            }

            override fun onLost(network: Network) {
                _isWifiConnected.value = false
                PrefetchBridge.updateDeviceState(context)
            }

            override fun onCapabilitiesChanged(
                network: Network,
                capabilities: NetworkCapabilities
            ) {
                val isWifi = capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI)
                _isWifiConnected.value = isWifi
                PrefetchBridge.updateDeviceState(context)
            }
        }

        connectivityManager.registerNetworkCallback(networkRequest, networkCallback!!)
    }

    private fun unregisterNetworkCallback() {
        networkCallback?.let {
            val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
            try {
                connectivityManager.unregisterNetworkCallback(it)
            } catch (e: Exception) {
                // Already unregistered
            }
        }
        networkCallback = null
    }

    // MARK: - Power Save Mode

    private fun setupPowerSaveModeMonitoring() {
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        _isPowerSaveMode.value = powerManager.isPowerSaveMode

        powerSaveModeReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent?) {
                _isPowerSaveMode.value = powerManager.isPowerSaveMode
                PrefetchBridge.updateDeviceState(context)

                if (_isPowerSaveMode.value) {
                    // Switch to conservative mode
                    PrefetchBridge.pause()
                } else if (_state.value == PrefetchSchedulerState.ACTIVE) {
                    PrefetchBridge.resume()
                }
            }
        }

        context.registerReceiver(
            powerSaveModeReceiver,
            android.content.IntentFilter(PowerManager.ACTION_POWER_SAVE_MODE_CHANGED)
        )
    }

    private fun unregisterPowerSaveModeReceiver() {
        powerSaveModeReceiver?.let {
            try {
                context.unregisterReceiver(it)
            } catch (e: Exception) {
                // Already unregistered
            }
        }
        powerSaveModeReceiver = null
    }

    // MARK: - Prefetch Triggers

    /**
     * Trigger prefetch when app comes to foreground
     */
    private fun triggerForegroundPrefetch() {
        scope.launch {
            // Prefetch feed
            PrefetchBridge.enqueue(
                contentType = PrefetchContentType.FEED_PAGE,
                priority = PrefetchPriority.HIGH,
                reason = PrefetchReason.APP_FOREGROUND,
                ttl = 120.0
            )

            // Prefetch notifications
            PrefetchBridge.enqueue(
                contentType = PrefetchContentType.NOTIFICATIONS,
                priority = PrefetchPriority.HIGH,
                reason = PrefetchReason.APP_FOREGROUND,
                ttl = 60.0
            )

            // Prefetch chat rooms
            PrefetchBridge.enqueue(
                contentType = PrefetchContentType.CHAT_ROOM,
                priority = PrefetchPriority.NORMAL,
                reason = PrefetchReason.APP_FOREGROUND,
                ttl = 60.0
            )
        }
    }

    /**
     * Trigger prefetch when network is restored
     */
    private fun triggerNetworkRestoredPrefetch() {
        scope.launch {
            // Refresh stale data
            PrefetchBridge.enqueue(
                contentType = PrefetchContentType.FEED_PAGE,
                priority = PrefetchPriority.NORMAL,
                reason = PrefetchReason.CACHE_REFRESH,
                ttl = 120.0
            )

            PrefetchBridge.enqueue(
                contentType = PrefetchContentType.NOTIFICATIONS,
                priority = PrefetchPriority.NORMAL,
                reason = PrefetchReason.CACHE_REFRESH,
                ttl = 60.0
            )
        }
    }

    /**
     * Trigger prefetch when user is idle
     */
    fun triggerIdlePrefetch() {
        idleJob?.cancel()
        idleJob = scope.launch {
            delay(IDLE_PREFETCH_DELAY_MS)

            if (_state.value != PrefetchSchedulerState.ACTIVE) return@launch

            // Low priority prefetch when idle
            PrefetchBridge.enqueue(
                contentType = PrefetchContentType.FEED_PAGE,
                priority = PrefetchPriority.LOW,
                reason = PrefetchReason.SCHEDULED,
                ttl = 300.0
            )
        }
    }

    /**
     * Cancel idle prefetch (user became active)
     */
    fun cancelIdlePrefetch() {
        idleJob?.cancel()
        idleJob = null
    }

    /**
     * Start periodic refresh
     */
    private fun startPeriodicRefresh() {
        periodicJob?.cancel()
        periodicJob = scope.launch {
            while (isActive && _state.value == PrefetchSchedulerState.ACTIVE) {
                delay(PERIODIC_REFRESH_INTERVAL_MS)

                // Refresh stats
                PrefetchBridge.refreshStats()

                // Check if we should continue
                if (_isPowerSaveMode.value) continue

                // Periodic low-priority prefetch
                PrefetchBridge.enqueue(
                    contentType = PrefetchContentType.NOTIFICATIONS,
                    priority = PrefetchPriority.LOW,
                    reason = PrefetchReason.SCHEDULED,
                    ttl = 60.0
                )
            }
        }
    }

    // MARK: - Background Work

    /**
     * Schedule background prefetch work
     */
    private fun scheduleBackgroundWork() {
        // Constraints for background work
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.UNMETERED)
            .setRequiresBatteryNotLow(true)
            .build()

        // Periodic background work
        val periodicWork = PeriodicWorkRequestBuilder<PrefetchWorker>(
            15, TimeUnit.MINUTES,
            5, TimeUnit.MINUTES
        )
            .setConstraints(constraints)
            .addTag(WORK_NAME_PERIODIC)
            .build()

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK_NAME_PERIODIC,
            ExistingPeriodicWorkPolicy.KEEP,
            periodicWork
        )
    }

    /**
     * Schedule one-time background prefetch
     */
    fun scheduleOneTimePrefetch(type: ScheduledPrefetchType, delayMinutes: Long = 0) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val data = workDataOf("prefetch_type" to type.name)

        val workRequest = OneTimeWorkRequestBuilder<PrefetchWorker>()
            .setConstraints(constraints)
            .setInputData(data)
            .setInitialDelay(delayMinutes, TimeUnit.MINUTES)
            .addTag(WORK_NAME_BACKGROUND)
            .build()

        WorkManager.getInstance(context).enqueue(workRequest)
    }

    // MARK: - User Intent Triggers

    /**
     * Trigger prefetch based on user intent
     */
    fun onUserIntent(screen: Screen) {
        scope.launch {
            // Record navigation
            PrefetchBridge.recordNavigation(screen)

            // Trigger specific prefetch based on intent
            when (screen) {
                Screen.FEED -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.FEED_PAGE,
                        priority = PrefetchPriority.HIGH,
                        reason = PrefetchReason.USER_INTENT,
                        ttl = 120.0
                    )
                }
                Screen.MESSAGES -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.CHAT_ROOM,
                        priority = PrefetchPriority.HIGH,
                        reason = PrefetchReason.USER_INTENT,
                        ttl = 60.0
                    )
                }
                Screen.NOTIFICATIONS -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.NOTIFICATIONS,
                        priority = PrefetchPriority.HIGH,
                        reason = PrefetchReason.USER_INTENT,
                        ttl = 30.0
                    )
                }
                Screen.FORUM -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.FORUM_POST,
                        priority = PrefetchPriority.NORMAL,
                        reason = PrefetchReason.USER_INTENT,
                        ttl = 120.0
                    )
                }
                Screen.SEARCH -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.SEARCH_RESULTS,
                        priority = PrefetchPriority.NORMAL,
                        reason = PrefetchReason.USER_INTENT,
                        ttl = 60.0
                    )
                }
                else -> { }
            }
        }
    }

    /**
     * Trigger prefetch for push notification
     */
    fun onPushNotification(type: String, contentId: String?) {
        scope.launch {
            val contentType = when (type) {
                "message" -> PrefetchContentType.CHAT_MESSAGES
                "listing" -> PrefetchContentType.LISTING_DETAIL
                "review" -> PrefetchContentType.USER_PROFILE
                else -> PrefetchContentType.NOTIFICATIONS
            }

            PrefetchBridge.enqueue(
                contentType = contentType,
                contentId = contentId,
                priority = PrefetchPriority.HIGH,
                reason = PrefetchReason.PUSH_NOTIFICATION,
                ttl = 60.0
            )
        }
    }
}

/**
 * WorkManager worker for background prefetch
 */
class PrefetchWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        return try {
            // Initialize if needed
            PrefetchBridge.initialize(applicationContext)

            // Get prefetch type
            val typeStr = inputData.getString("prefetch_type")
            val type = typeStr?.let {
                try {
                    ScheduledPrefetchType.valueOf(it)
                } catch (e: Exception) {
                    null
                }
            }

            // Execute prefetch based on type
            when (type) {
                ScheduledPrefetchType.FEED_REFRESH -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.FEED_PAGE,
                        priority = PrefetchPriority.LOW,
                        reason = PrefetchReason.SCHEDULED,
                        ttl = 300.0
                    )
                }
                ScheduledPrefetchType.NOTIFICATIONS_CHECK -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.NOTIFICATIONS,
                        priority = PrefetchPriority.LOW,
                        reason = PrefetchReason.SCHEDULED,
                        ttl = 60.0
                    )
                }
                ScheduledPrefetchType.MESSAGES_SYNC -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.CHAT_ROOM,
                        priority = PrefetchPriority.LOW,
                        reason = PrefetchReason.SCHEDULED,
                        ttl = 60.0
                    )
                }
                ScheduledPrefetchType.USER_DATA_REFRESH -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.USER_PROFILE,
                        priority = PrefetchPriority.LOW,
                        reason = PrefetchReason.SCHEDULED,
                        ttl = 300.0
                    )
                }
                ScheduledPrefetchType.FAVORITES_SYNC -> {
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.LISTING,
                        priority = PrefetchPriority.LOW,
                        reason = PrefetchReason.SCHEDULED,
                        ttl = 300.0
                    )
                }
                null -> {
                    // Default background prefetch
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.FEED_PAGE,
                        priority = PrefetchPriority.LOW,
                        reason = PrefetchReason.SCHEDULED,
                        ttl = 300.0
                    )
                    PrefetchBridge.enqueue(
                        contentType = PrefetchContentType.NOTIFICATIONS,
                        priority = PrefetchPriority.LOW,
                        reason = PrefetchReason.SCHEDULED,
                        ttl = 60.0
                    )
                }
            }

            Result.success()
        } catch (e: Exception) {
            Result.retry()
        }
    }
}
