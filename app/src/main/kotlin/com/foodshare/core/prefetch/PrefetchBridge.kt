package com.foodshare.core.prefetch

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedQueue
import kotlin.math.min

/**
 * Prefetch priority levels
 */
enum class PrefetchPriority(val value: Int) {
    LOW(0),
    NORMAL(1),
    HIGH(2),
    CRITICAL(3)
}

/**
 * Prefetch content types
 */
enum class PrefetchContentType(val value: String) {
    LISTING("listing"),
    LISTING_DETAIL("listing_detail"),
    USER_PROFILE("user_profile"),
    CHAT_ROOM("chat_room"),
    CHAT_MESSAGES("chat_messages"),
    FEED_PAGE("feed_page"),
    SEARCH_RESULTS("search_results"),
    IMAGE("image"),
    THUMBNAIL("thumbnail"),
    FORUM_POST("forum_post"),
    NOTIFICATIONS("notifications")
}

/**
 * Prefetch reasons
 */
enum class PrefetchReason(val value: String) {
    USER_INTENT("user_intent"),
    NAVIGATION_PREDICTION("navigation"),
    CACHE_REFRESH("cache_refresh"),
    LIST_SCROLL("list_scroll"),
    APP_FOREGROUND("app_foreground"),
    PUSH_NOTIFICATION("push"),
    SCHEDULED("scheduled"),
    USER_HISTORY("user_history")
}

/**
 * Network state for prefetch decisions
 */
enum class NetworkState(val value: String) {
    WIFI("wifi"),
    CELLULAR("cellular"),
    OFFLINE("offline"),
    UNKNOWN("unknown")
}

/**
 * App screens for navigation prediction
 */
enum class Screen(val value: String) {
    SPLASH("splash"),
    LOGIN("login"),
    REGISTER("register"),
    FEED("feed"),
    LISTING_DETAIL("listing_detail"),
    CREATE_LISTING("create_listing"),
    EDIT_LISTING("edit_listing"),
    SEARCH("search"),
    MAP("map"),
    MESSAGES("messages"),
    CONVERSATION("conversation"),
    PROFILE("profile"),
    EDIT_PROFILE("edit_profile"),
    USER_PROFILE("user_profile"),
    SETTINGS("settings"),
    NOTIFICATIONS("notifications"),
    FORUM("forum"),
    FORUM_POST("forum_post"),
    CREATE_FORUM_POST("create_forum_post"),
    FAVORITES("favorites"),
    REVIEWS("reviews"),
    CHALLENGES("challenges")
}

/**
 * Device state for prefetch decisions
 */
data class DeviceState(
    val networkState: NetworkState,
    val isMetered: Boolean,
    val isLowBattery: Boolean,
    val isLowMemory: Boolean,
    val isCharging: Boolean
)

/**
 * Prefetch configuration
 */
data class PrefetchConfiguration(
    val maxConcurrentRequests: Int = 3,
    val maxQueueSize: Int = 50,
    val defaultTTL: Double = 300.0,
    val maxBytesPerSession: Int = 50 * 1024 * 1024,
    val imagePrefetchLimit: Int = 20
) {
    companion object {
        val STANDARD = PrefetchConfiguration()

        val AGGRESSIVE = PrefetchConfiguration(
            maxConcurrentRequests = 5,
            maxQueueSize = 100,
            maxBytesPerSession = 100 * 1024 * 1024,
            imagePrefetchLimit = 50
        )

        val CONSERVATIVE = PrefetchConfiguration(
            maxConcurrentRequests = 2,
            maxQueueSize = 20,
            maxBytesPerSession = 10 * 1024 * 1024,
            imagePrefetchLimit = 5
        )
    }
}

/**
 * Prefetch stats
 */
@Serializable
data class PrefetchStats(
    val totalRequests: Int = 0,
    val successfulRequests: Int = 0,
    val failedRequests: Int = 0,
    val cacheHits: Int = 0,
    val totalBytes: Int = 0,
    val averageDurationMs: Int = 0,
    val successRate: Double = 0.0,
    val cacheHitRate: Double = 0.0
)

/**
 * Navigation prediction result
 */
@Serializable
data class NavigationPrediction(
    val screen: String,
    val probability: Double
)

/**
 * Prefetch logic.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for prefetch queue management
 * - Navigation prediction, device state, queue management are pure functions
 * - No JNI required for these operations
 */
object PrefetchBridge {
    private val scope = CoroutineScope(Dispatchers.IO + Job())

    private val _stats = MutableStateFlow(PrefetchStats())
    val stats: StateFlow<PrefetchStats> = _stats.asStateFlow()

    private var isInitialized = false
    private var isPaused = false
    private var configuration = PrefetchConfiguration.STANDARD
    private var currentDeviceState: DeviceState? = null

    // Navigation history for prediction
    private val navigationHistory = ConcurrentLinkedQueue<NavigationEntry>()
    private const val MAX_HISTORY_SIZE = 100

    // Prefetch queue
    private val prefetchQueue = ConcurrentLinkedQueue<PrefetchRequest>()

    // Stats tracking
    private var totalRequests = 0
    private var successfulRequests = 0
    private var failedRequests = 0
    private var cacheHits = 0
    private var totalBytes = 0

    // Navigation transition probabilities (simplified Markov chain)
    private val transitionProbabilities = ConcurrentHashMap<String, MutableMap<String, Int>>()

    /**
     * Initialize the prefetch system with configuration
     */
    fun initialize(
        context: Context,
        configuration: PrefetchConfiguration = PrefetchConfiguration.STANDARD
    ) {
        if (isInitialized) return

        this.configuration = configuration
        updateDeviceState(context)
        isInitialized = true
    }

    /**
     * Update device state from Android system
     */
    fun updateDeviceState(context: Context) {
        currentDeviceState = getDeviceState(context)
    }

    /**
     * Get current device state
     */
    fun getDeviceState(context: Context): DeviceState {
        val connectivityManager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager

        val network = connectivityManager.activeNetwork
        val capabilities = network?.let { connectivityManager.getNetworkCapabilities(it) }

        val networkState = when {
            capabilities == null -> NetworkState.OFFLINE
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> NetworkState.WIFI
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> NetworkState.CELLULAR
            else -> NetworkState.UNKNOWN
        }

        val isMetered = connectivityManager.isActiveNetworkMetered

        val batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val isLowBattery = batteryLevel < 20

        val isCharging = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            batteryManager.isCharging
        } else {
            batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_STATUS) ==
                    BatteryManager.BATTERY_STATUS_CHARGING
        }

        val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
        val memoryInfo = android.app.ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(memoryInfo)
        val isLowMemory = memoryInfo.lowMemory

        return DeviceState(
            networkState = networkState,
            isMetered = isMetered,
            isLowBattery = isLowBattery,
            isLowMemory = isLowMemory,
            isCharging = isCharging
        )
    }

    /**
     * Record navigation for prediction
     */
    fun recordNavigation(screen: Screen, context: Map<String, String> = emptyMap()) {
        val lastScreen = navigationHistory.lastOrNull()?.screen

        // Add to history
        navigationHistory.add(NavigationEntry(screen, System.currentTimeMillis(), context))

        // Trim history if needed
        while (navigationHistory.size > MAX_HISTORY_SIZE) {
            navigationHistory.poll()
        }

        // Update transition probabilities
        lastScreen?.let { prev ->
            val transitions = transitionProbabilities.getOrPut(prev.value) { mutableMapOf() }
            transitions[screen.value] = (transitions[screen.value] ?: 0) + 1
        }
    }

    /**
     * Get navigation predictions based on history
     */
    fun predictNextScreens(count: Int = 3): List<NavigationPrediction> {
        val currentScreen = navigationHistory.lastOrNull()?.screen ?: return emptyList()
        val transitions = transitionProbabilities[currentScreen.value] ?: return emptyList()

        val total = transitions.values.sum().toDouble()
        if (total == 0.0) return emptyList()

        return transitions.entries
            .map { NavigationPrediction(it.key, it.value / total) }
            .sortedByDescending { it.probability }
            .take(count)
    }

    /**
     * Enqueue a prefetch request
     */
    fun enqueue(
        contentType: PrefetchContentType,
        contentId: String? = null,
        url: String? = null,
        priority: PrefetchPriority = PrefetchPriority.NORMAL,
        reason: PrefetchReason = PrefetchReason.NAVIGATION_PREDICTION,
        ttl: Double = 0.0
    ) {
        if (isPaused) return
        if (prefetchQueue.size >= configuration.maxQueueSize) return

        // Check device state constraints
        val device = currentDeviceState
        if (device != null) {
            if (device.networkState == NetworkState.OFFLINE) return
            if (device.isLowBattery && !device.isCharging && priority.value < PrefetchPriority.HIGH.value) return
            if (device.isLowMemory && priority.value < PrefetchPriority.CRITICAL.value) return
            if (device.isMetered && priority.value < PrefetchPriority.NORMAL.value) return
        }

        val request = PrefetchRequest(
            contentType = contentType,
            contentId = contentId,
            url = url,
            priority = priority,
            reason = reason,
            ttl = if (ttl > 0) ttl else configuration.defaultTTL,
            timestamp = System.currentTimeMillis()
        )

        prefetchQueue.add(request)
        totalRequests++
        updateStats()
    }

    /**
     * Prefetch listing detail
     */
    fun prefetchListingDetail(listingId: String, priority: PrefetchPriority = PrefetchPriority.NORMAL) {
        enqueue(
            contentType = PrefetchContentType.LISTING_DETAIL,
            contentId = listingId,
            priority = priority,
            reason = PrefetchReason.USER_INTENT,
            ttl = 180.0
        )
    }

    /**
     * Prefetch user profile
     */
    fun prefetchUserProfile(userId: String, priority: PrefetchPriority = PrefetchPriority.NORMAL) {
        enqueue(
            contentType = PrefetchContentType.USER_PROFILE,
            contentId = userId,
            priority = priority,
            reason = PrefetchReason.USER_INTENT,
            ttl = 300.0
        )
    }

    /**
     * Prefetch chat messages
     */
    fun prefetchChatMessages(roomId: String, priority: PrefetchPriority = PrefetchPriority.NORMAL) {
        enqueue(
            contentType = PrefetchContentType.CHAT_MESSAGES,
            contentId = roomId,
            priority = priority,
            reason = PrefetchReason.USER_INTENT,
            ttl = 60.0
        )
    }

    /**
     * Prefetch images
     */
    fun prefetchImages(urls: List<String>, priority: PrefetchPriority = PrefetchPriority.NORMAL) {
        if (urls.isEmpty()) return
        val limit = min(urls.size, configuration.imagePrefetchLimit)
        urls.take(limit).forEach { url ->
            enqueue(
                contentType = PrefetchContentType.IMAGE,
                url = url,
                priority = priority,
                reason = PrefetchReason.LIST_SCROLL,
                ttl = 600.0
            )
        }
    }

    /**
     * Prefetch for scroll position
     */
    fun prefetchForScroll(
        visibleRange: IntRange,
        totalItems: Int,
        itemIds: List<String>,
        contentType: PrefetchContentType
    ) {
        // Prefetch items ahead of visible range
        val prefetchStart = visibleRange.last + 1
        val prefetchEnd = min(prefetchStart + 5, totalItems - 1)

        for (i in prefetchStart..prefetchEnd) {
            if (i < itemIds.size) {
                enqueue(
                    contentType = contentType,
                    contentId = itemIds[i],
                    priority = PrefetchPriority.LOW,
                    reason = PrefetchReason.LIST_SCROLL,
                    ttl = 120.0
                )
            }
        }
    }

    /**
     * Pause prefetching
     */
    fun pause() {
        isPaused = true
    }

    /**
     * Resume prefetching
     */
    fun resume() {
        isPaused = false
    }

    /**
     * Clear prefetch queue
     */
    fun clearQueue() {
        prefetchQueue.clear()
    }

    /**
     * Get prefetch stats
     */
    fun getStats(): PrefetchStats {
        val successRate = if (totalRequests > 0) {
            successfulRequests.toDouble() / totalRequests
        } else 0.0

        val cacheHitRate = if (totalRequests > 0) {
            cacheHits.toDouble() / totalRequests
        } else 0.0

        return PrefetchStats(
            totalRequests = totalRequests,
            successfulRequests = successfulRequests,
            failedRequests = failedRequests,
            cacheHits = cacheHits,
            totalBytes = totalBytes,
            averageDurationMs = 0,  // Would need timing tracking
            successRate = successRate,
            cacheHitRate = cacheHitRate
        )
    }

    /**
     * Reset prefetch stats
     */
    fun resetStats() {
        totalRequests = 0
        successfulRequests = 0
        failedRequests = 0
        cacheHits = 0
        totalBytes = 0
        _stats.value = PrefetchStats()
    }

    /**
     * Refresh stats flow
     */
    fun refreshStats() {
        _stats.value = getStats()
    }

    private fun updateStats() {
        _stats.value = getStats()
    }

    /**
     * Record successful prefetch
     */
    fun recordSuccess(bytes: Int = 0) {
        successfulRequests++
        totalBytes += bytes
        updateStats()
    }

    /**
     * Record failed prefetch
     */
    fun recordFailure() {
        failedRequests++
        updateStats()
    }

    /**
     * Record cache hit
     */
    fun recordCacheHit() {
        cacheHits++
        updateStats()
    }
}

/**
 * Navigation history entry
 */
private data class NavigationEntry(
    val screen: Screen,
    val timestamp: Long,
    val context: Map<String, String>
)

/**
 * Prefetch request
 */
private data class PrefetchRequest(
    val contentType: PrefetchContentType,
    val contentId: String?,
    val url: String?,
    val priority: PrefetchPriority,
    val reason: PrefetchReason,
    val ttl: Double,
    val timestamp: Long
)

/**
 * Composable hook for prefetch on navigation
 */
@Composable
fun rememberPrefetchNavigation(screen: Screen) {
    val context = LocalContext.current

    LaunchedEffect(screen) {
        PrefetchBridge.recordNavigation(screen)
    }

    DisposableEffect(Unit) {
        PrefetchBridge.updateDeviceState(context)
        onDispose { }
    }
}

/**
 * Composable hook for prefetch on scroll
 */
@Composable
fun rememberPrefetchOnScroll(
    visibleRange: IntRange,
    totalItems: Int,
    itemIds: List<String>,
    contentType: PrefetchContentType
) {
    LaunchedEffect(visibleRange) {
        PrefetchBridge.prefetchForScroll(
            visibleRange = visibleRange,
            totalItems = totalItems,
            itemIds = itemIds,
            contentType = contentType
        )
    }
}

/**
 * Extension for prefetching listing on hover/long press
 */
fun prefetchOnInteraction(listingId: String) {
    PrefetchBridge.prefetchListingDetail(listingId, PrefetchPriority.HIGH)
}

/**
 * Extension for prefetching user profile on hover/long press
 */
fun prefetchUserOnInteraction(userId: String) {
    PrefetchBridge.prefetchUserProfile(userId, PrefetchPriority.HIGH)
}

/**
 * Extension for prefetching chat room on hover/long press
 */
fun prefetchChatOnInteraction(roomId: String) {
    PrefetchBridge.prefetchChatMessages(roomId, PrefetchPriority.HIGH)
}
