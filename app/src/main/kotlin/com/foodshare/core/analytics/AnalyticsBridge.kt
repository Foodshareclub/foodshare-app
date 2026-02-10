package com.foodshare.core.analytics

import android.content.Context
import android.content.SharedPreferences
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.time.Instant
import java.util.UUID

/**
 * Event categories for analytics
 */
enum class EventCategory(val value: String) {
    NAVIGATION("navigation"),
    LISTING("listing"),
    USER("user"),
    ARRANGEMENT("arrangement"),
    MESSAGING("messaging"),
    SEARCH("search"),
    CHALLENGE("challenge"),
    REVIEW("review"),
    ERROR("error"),
    PERFORMANCE("performance"),
    ENGAGEMENT("engagement"),
    CONVERSION("conversion"),
    SYSTEM("system")
}

/**
 * Standard event names for consistency
 */
enum class StandardEvent(val eventName: String, val category: EventCategory) {
    // Navigation
    SCREEN_VIEW("screen_view", EventCategory.NAVIGATION),
    TAB_SELECTED("tab_selected", EventCategory.NAVIGATION),
    DEEP_LINK_OPENED("deep_link_opened", EventCategory.NAVIGATION),
    BACK_PRESSED("back_pressed", EventCategory.NAVIGATION),

    // Listing
    LISTING_VIEWED("listing_viewed", EventCategory.LISTING),
    LISTING_CREATED("listing_created", EventCategory.LISTING),
    LISTING_EDITED("listing_edited", EventCategory.LISTING),
    LISTING_DELETED("listing_deleted", EventCategory.LISTING),
    LISTING_SHARED("listing_shared", EventCategory.LISTING),
    LISTING_FAVORITED("listing_favorited", EventCategory.LISTING),
    LISTING_UNFAVORITED("listing_unfavorited", EventCategory.LISTING),

    // User
    USER_SIGNED_UP("user_signed_up", EventCategory.USER),
    USER_LOGGED_IN("user_logged_in", EventCategory.USER),
    USER_LOGGED_OUT("user_logged_out", EventCategory.USER),
    PROFILE_UPDATED("profile_updated", EventCategory.USER),
    PROFILE_VIEWED("profile_viewed", EventCategory.USER),

    // Arrangement
    ARRANGEMENT_REQUESTED("arrangement_requested", EventCategory.ARRANGEMENT),
    ARRANGEMENT_ACCEPTED("arrangement_accepted", EventCategory.ARRANGEMENT),
    ARRANGEMENT_DECLINED("arrangement_declined", EventCategory.ARRANGEMENT),
    ARRANGEMENT_CANCELLED("arrangement_cancelled", EventCategory.ARRANGEMENT),
    ARRANGEMENT_COMPLETED("arrangement_completed", EventCategory.ARRANGEMENT),

    // Messaging
    CONVERSATION_STARTED("conversation_started", EventCategory.MESSAGING),
    MESSAGE_SENT("message_sent", EventCategory.MESSAGING),
    MESSAGE_RECEIVED("message_received", EventCategory.MESSAGING),
    CONVERSATION_VIEWED("conversation_viewed", EventCategory.MESSAGING),

    // Search
    SEARCH_PERFORMED("search_performed", EventCategory.SEARCH),
    SEARCH_RESULT_CLICKED("search_result_clicked", EventCategory.SEARCH),
    FILTER_APPLIED("filter_applied", EventCategory.SEARCH),

    // Challenge
    CHALLENGE_VIEWED("challenge_viewed", EventCategory.CHALLENGE),
    CHALLENGE_STARTED("challenge_started", EventCategory.CHALLENGE),
    CHALLENGE_COMPLETED("challenge_completed", EventCategory.CHALLENGE),
    BADGE_EARNED("badge_earned", EventCategory.CHALLENGE),

    // Review
    REVIEW_SUBMITTED("review_submitted", EventCategory.REVIEW),
    REVIEW_VIEWED("review_viewed", EventCategory.REVIEW),

    // Error
    ERROR_OCCURRED("error_occurred", EventCategory.ERROR),
    NETWORK_ERROR("network_error", EventCategory.ERROR),

    // Performance
    APP_LAUNCHED("app_launched", EventCategory.PERFORMANCE),
    SCREEN_LOAD_TIME("screen_load_time", EventCategory.PERFORMANCE),
    API_RESPONSE_TIME("api_response_time", EventCategory.PERFORMANCE),

    // Engagement
    SESSION_STARTED("session_started", EventCategory.ENGAGEMENT),
    SESSION_ENDED("session_ended", EventCategory.ENGAGEMENT),
    FEATURE_DISCOVERED("feature_discovered", EventCategory.ENGAGEMENT),

    // Conversion
    FIRST_LISTING_CREATED("first_listing_created", EventCategory.CONVERSION),
    FIRST_ARRANGEMENT_COMPLETED("first_arrangement_completed", EventCategory.CONVERSION),
    RETENTION_MILESTONE("retention_milestone", EventCategory.CONVERSION)
}

/**
 * Standard property keys
 */
object PropertyKey {
    const val SCREEN_NAME = "screen_name"
    const val SCREEN_CLASS = "screen_class"
    const val PREVIOUS_SCREEN = "previous_screen"
    const val TAB_NAME = "tab_name"
    const val LISTING_ID = "listing_id"
    const val USER_ID = "user_id"
    const val ARRANGEMENT_ID = "arrangement_id"
    const val CONVERSATION_ID = "conversation_id"
    const val CHALLENGE_ID = "challenge_id"
    const val SEARCH_QUERY = "search_query"
    const val SEARCH_RESULT_COUNT = "search_result_count"
    const val FILTER_TYPE = "filter_type"
    const val FILTER_VALUE = "filter_value"
    const val DURATION_MS = "duration_ms"
    const val LOAD_TIME_MS = "load_time_ms"
    const val ERROR_CODE = "error_code"
    const val ERROR_MESSAGE = "error_message"
    const val ERROR_TYPE = "error_type"
    const val SOURCE = "source"
    const val SUCCESS = "success"
    const val IS_FIRST_TIME = "is_first_time"
    const val IS_OFFLINE = "is_offline"
    const val PLATFORM = "platform"
    const val APP_VERSION = "app_version"
}

/**
 * Analytics event data class
 */
@Serializable
data class AnalyticsEvent(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val category: String,
    val properties: Map<String, String> = emptyMap(),
    val timestamp: String = java.time.Instant.now().toString(),
    val sessionId: String? = null,
    val userId: String? = null,
    val deviceId: String,
    val platform: String = "android",
    val appVersion: String
)

/**
 * Session data class
 */
@Serializable
data class Session(
    val id: String,
    val startedAt: String,
    val lastActivityAt: String,
    val endedAt: String? = null,
    val deviceId: String,
    val userId: String? = null,
    val eventCount: Int = 0,
    val screenViewCount: Int = 0,
    val sessionNumber: Int = 1,
    val entryScreen: String? = null,
    val exitScreen: String? = null,
    val properties: Map<String, String> = emptyMap()
) {
    val isActive: Boolean get() = endedAt == null
}

/**
 * Session statistics
 */
@Serializable
data class SessionStats(
    val totalSessions: Int,
    val currentSessionId: String? = null,
    val currentSessionDuration: Double = 0.0,
    val currentSessionEventCount: Int = 0,
    val currentSessionScreenViews: Int = 0,
    val isActive: Boolean = false
)

/**
 * Batch configuration
 */
data class BatchConfig(
    val maxBatchSize: Int = 50,
    val maxBatchAgeSeconds: Long = 30,
    val maxQueueSize: Int = 500,
    val persistToDisk: Boolean = true,
    val retryAttempts: Int = 3,
    val retryDelayMs: Long = 1000
)

/**
 * Event batch
 */
@Serializable
data class EventBatch(
    val id: String = UUID.randomUUID().toString(),
    val events: List<AnalyticsEvent>,
    val createdAt: String = java.time.Instant.now().toString(),
    val attempts: Int = 0
)

/**
 * Analytics bridge - local implementation
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for analytics and session tracking
 * - Event batching, session management are pure functions
 * - No JNI required for these operations
 */
class AnalyticsBridge private constructor(
    private val context: Context,
    private val deviceId: String,
    private val appVersion: String
) {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    // Local session tracker state
    private var currentSession: Session? = null
    private var sessionNumber: Int = 0
    private var sessionTimeoutSeconds: Double = 1800.0 // 30 minutes
    private var lastActivityTime: Long = 0
    private var backgroundedAt: Long? = null

    private var currentUserId: String? = null
    private val eventQueue = mutableListOf<AnalyticsEvent>()
    private val pendingBatches = mutableListOf<EventBatch>()
    private var config = BatchConfig()

    private var uploadHandler: (suspend (List<AnalyticsEvent>) -> Boolean)? = null

    companion object {
        private const val PREFS_NAME = "analytics_prefs"
        private const val KEY_SESSION_NUMBER = "session_number"
        private const val KEY_DEVICE_ID = "device_id"
        private const val KEY_PENDING_EVENTS = "pending_events"

        @Volatile
        private var instance: AnalyticsBridge? = null

        fun initialize(context: Context, appVersion: String): AnalyticsBridge {
            return instance ?: synchronized(this) {
                instance ?: run {
                    val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
                    val deviceId = prefs.getString(KEY_DEVICE_ID, null)
                        ?: UUID.randomUUID().toString().also {
                            prefs.edit().putString(KEY_DEVICE_ID, it).apply()
                        }

                    AnalyticsBridge(context.applicationContext, deviceId, appVersion).also {
                        instance = it
                        it.initializeSessionTracker()
                    }
                }
            }
        }

        fun getInstance(): AnalyticsBridge {
            return instance ?: throw IllegalStateException("AnalyticsBridge not initialized")
        }
    }

    /**
     * Initialize the session tracker (local implementation)
     */
    private fun initializeSessionTracker() {
        sessionNumber = prefs.getInt(KEY_SESSION_NUMBER, 0)
        lastActivityTime = System.currentTimeMillis()
    }

    /**
     * Set upload handler for batches
     */
    fun setUploadHandler(handler: suspend (List<AnalyticsEvent>) -> Boolean) {
        uploadHandler = handler
    }

    /**
     * Configure batching behavior
     */
    fun configure(config: BatchConfig) {
        this.config = config
    }

    // ========== Session Management ==========

    /**
     * Start a new session (local implementation)
     */
    suspend fun startSession(entryScreen: String? = null): Session = withContext(Dispatchers.Default) {
        sessionNumber++
        prefs.edit().putInt(KEY_SESSION_NUMBER, sessionNumber).apply()

        val now = Instant.now().toString()
        val session = Session(
            id = UUID.randomUUID().toString(),
            startedAt = now,
            lastActivityAt = now,
            deviceId = deviceId,
            userId = currentUserId,
            sessionNumber = sessionNumber,
            entryScreen = entryScreen
        )

        currentSession = session
        lastActivityTime = System.currentTimeMillis()

        trackEvent(StandardEvent.SESSION_STARTED, mapOf(
            "session_number" to sessionNumber.toString()
        ))

        session
    }

    /**
     * End current session (local implementation)
     */
    suspend fun endSession(reason: String = "user_action") = withContext(Dispatchers.Default) {
        val stats = getSessionStats()
        if (stats.isActive) {
            trackEvent(StandardEvent.SESSION_ENDED, mapOf(
                "duration_sec" to stats.currentSessionDuration.toString(),
                "event_count" to stats.currentSessionEventCount.toString(),
                "screen_views" to stats.currentSessionScreenViews.toString(),
                "reason" to reason
            ))
        }

        currentSession = currentSession?.copy(
            endedAt = Instant.now().toString(),
            exitScreen = currentSession?.exitScreen
        )

        flushEvents()
    }

    /**
     * Get current session ID (local implementation)
     */
    fun getSessionId(): String? = currentSession?.id

    /**
     * Get session statistics (local implementation)
     */
    fun getSessionStats(): SessionStats {
        val session = currentSession
        val durationSeconds = if (session != null && session.isActive) {
            val started = try {
                Instant.parse(session.startedAt).toEpochMilli()
            } catch (e: Exception) { System.currentTimeMillis() }
            (System.currentTimeMillis() - started) / 1000.0
        } else 0.0

        return SessionStats(
            totalSessions = sessionNumber,
            currentSessionId = session?.id,
            currentSessionDuration = durationSeconds,
            currentSessionEventCount = session?.eventCount ?: 0,
            currentSessionScreenViews = session?.screenViewCount ?: 0,
            isActive = session?.isActive ?: false
        )
    }

    /**
     * Set current user ID (local implementation)
     */
    fun setUserId(userId: String?) {
        currentUserId = userId
        currentSession = currentSession?.copy(userId = userId)
    }

    // ========== Lifecycle Handling ==========

    /**
     * Call when app goes to background (local implementation)
     */
    fun onAppBackgrounded() {
        backgroundedAt = System.currentTimeMillis()
        persistPendingEvents()
    }

    /**
     * Call when app comes to foreground (local implementation)
     */
    fun onAppForegrounded() {
        val bgTime = backgroundedAt
        if (bgTime != null) {
            val backgroundDuration = (System.currentTimeMillis() - bgTime) / 1000.0
            if (backgroundDuration > sessionTimeoutSeconds) {
                // Session timed out while in background
                currentSession = currentSession?.copy(endedAt = Instant.ofEpochMilli(bgTime).toString())
            }
        }
        backgroundedAt = null
        lastActivityTime = System.currentTimeMillis()
        loadPendingEvents()
    }

    /**
     * Check for session timeout (local implementation)
     */
    fun checkSessionTimeout() {
        val inactiveSeconds = (System.currentTimeMillis() - lastActivityTime) / 1000.0
        if (inactiveSeconds > sessionTimeoutSeconds && currentSession?.isActive == true) {
            currentSession = currentSession?.copy(endedAt = Instant.now().toString())
        }
    }

    /**
     * Record activity (updates last activity time)
     */
    private fun recordActivity() {
        lastActivityTime = System.currentTimeMillis()
        currentSession = currentSession?.copy(
            lastActivityAt = Instant.now().toString(),
            eventCount = (currentSession?.eventCount ?: 0) + 1
        )
    }

    /**
     * Record screen view
     */
    private fun recordScreenView(screenName: String) {
        recordActivity()
        currentSession = currentSession?.copy(
            screenViewCount = (currentSession?.screenViewCount ?: 0) + 1,
            exitScreen = screenName
        )
    }

    // ========== Event Tracking ==========

    /**
     * Track a standard event (local implementation)
     */
    suspend fun trackEvent(
        event: StandardEvent,
        properties: Map<String, String> = emptyMap()
    ) = withContext(Dispatchers.Default) {
        trackCustomEvent(event.eventName, event.category, properties)
    }

    /**
     * Track a custom event (local implementation)
     */
    suspend fun trackCustomEvent(
        eventName: String,
        category: EventCategory,
        properties: Map<String, String> = emptyMap()
    ) = withContext(Dispatchers.Default) {
        recordActivity()

        // Normalize properties locally
        val normalizedProps = normalizeProperties(properties)

        // Create event locally
        val event = createEvent(eventName, category.value, normalizedProps)
        enqueueEvent(event)
    }

    /**
     * Track screen view (local implementation)
     */
    suspend fun trackScreenView(
        screenName: String,
        screenClass: String? = null,
        properties: Map<String, String> = emptyMap()
    ) = withContext(Dispatchers.Default) {
        recordScreenView(screenName)

        val fullProperties = properties.toMutableMap().apply {
            put(PropertyKey.SCREEN_NAME, screenName)
            screenClass?.let { put(PropertyKey.SCREEN_CLASS, it) }
        }

        trackEvent(StandardEvent.SCREEN_VIEW, fullProperties)
    }

    /**
     * Normalize event properties (local implementation)
     */
    private fun normalizeProperties(properties: Map<String, String>): Map<String, String> {
        return properties.mapValues { (_, value) ->
            // Trim and limit string length
            value.trim().take(500)
        }.filterValues { it.isNotEmpty() }
    }

    /**
     * Create an analytics event (local implementation)
     */
    private fun createEvent(
        eventName: String,
        category: String,
        properties: Map<String, String>
    ): AnalyticsEvent {
        return AnalyticsEvent(
            id = UUID.randomUUID().toString(),
            name = eventName,
            category = category,
            properties = properties,
            timestamp = Instant.now().toString(),
            sessionId = getSessionId(),
            userId = currentUserId,
            deviceId = deviceId,
            platform = "android",
            appVersion = appVersion
        )
    }

    /**
     * Track error
     */
    suspend fun trackError(
        errorType: String,
        errorMessage: String,
        errorCode: String? = null,
        properties: Map<String, String> = emptyMap()
    ) = withContext(Dispatchers.Default) {
        val fullProperties = properties.toMutableMap().apply {
            put(PropertyKey.ERROR_TYPE, errorType)
            put(PropertyKey.ERROR_MESSAGE, errorMessage)
            errorCode?.let { put(PropertyKey.ERROR_CODE, it) }
        }

        trackEvent(StandardEvent.ERROR_OCCURRED, fullProperties)
    }

    /**
     * Track performance metric
     */
    suspend fun trackPerformance(
        metricName: String,
        durationMs: Long,
        properties: Map<String, String> = emptyMap()
    ) = withContext(Dispatchers.Default) {
        val fullProperties = properties.toMutableMap().apply {
            put(PropertyKey.DURATION_MS, durationMs.toString())
        }

        trackCustomEvent(metricName, EventCategory.PERFORMANCE, fullProperties)
    }

    // ========== Batching ==========

    private fun enqueueEvent(event: AnalyticsEvent) {
        synchronized(eventQueue) {
            eventQueue.add(event)

            if (shouldFlush()) {
                createBatch()
            }
        }
    }

    private fun shouldFlush(): Boolean {
        return eventQueue.size >= config.maxBatchSize ||
                eventQueue.size >= config.maxQueueSize
    }

    private fun createBatch() {
        if (eventQueue.isEmpty()) return

        val batchEvents = eventQueue.take(config.maxBatchSize).toList()
        eventQueue.subList(0, minOf(config.maxBatchSize, eventQueue.size)).clear()

        val batch = EventBatch(events = batchEvents)
        pendingBatches.add(batch)
    }

    /**
     * Flush all pending events
     */
    suspend fun flushEvents() = withContext(Dispatchers.IO) {
        synchronized(eventQueue) {
            while (eventQueue.isNotEmpty()) {
                createBatch()
            }
        }

        processPendingBatches()
    }

    private suspend fun processPendingBatches() {
        val handler = uploadHandler ?: return

        val batchesToProcess = synchronized(pendingBatches) {
            pendingBatches.toList()
        }

        for (batch in batchesToProcess) {
            try {
                val success = handler(batch.events)
                if (success) {
                    synchronized(pendingBatches) {
                        pendingBatches.removeAll { it.id == batch.id }
                    }
                } else {
                    handleBatchFailure(batch)
                }
            } catch (e: Exception) {
                handleBatchFailure(batch)
            }
        }
    }

    private fun handleBatchFailure(batch: EventBatch) {
        synchronized(pendingBatches) {
            val index = pendingBatches.indexOfFirst { it.id == batch.id }
            if (index >= 0) {
                val updatedBatch = batch.copy(attempts = batch.attempts + 1)
                if (updatedBatch.attempts >= config.retryAttempts) {
                    pendingBatches.removeAt(index)
                } else {
                    pendingBatches[index] = updatedBatch
                }
            }
        }
    }

    // ========== Persistence ==========

    private fun persistPendingEvents() {
        synchronized(eventQueue) {
            if (eventQueue.isEmpty() && pendingBatches.isEmpty()) return

            val allEvents = eventQueue.toList() +
                    pendingBatches.flatMap { it.events }

            val eventsJson = json.encodeToString(allEvents)
            prefs.edit().putString(KEY_PENDING_EVENTS, eventsJson).apply()
        }
    }

    private fun loadPendingEvents() {
        val eventsJson = prefs.getString(KEY_PENDING_EVENTS, null) ?: return

        try {
            val events = json.decodeFromString<List<AnalyticsEvent>>(eventsJson)
            synchronized(eventQueue) {
                eventQueue.clear()
                eventQueue.addAll(events)
            }
            prefs.edit().remove(KEY_PENDING_EVENTS).apply()
        } catch (e: Exception) {
            // Ignore parsing errors
        }
    }

    /**
     * Get analytics statistics
     */
    fun getStats(): AnalyticsStats {
        return synchronized(eventQueue) {
            AnalyticsStats(
                queuedEvents = eventQueue.size,
                pendingBatches = pendingBatches.size,
                pendingEvents = pendingBatches.sumOf { it.events.size },
                deviceId = deviceId,
                sessionStats = getSessionStats()
            )
        }
    }

    /**
     * Clear all queued events
     */
    fun clear() {
        synchronized(eventQueue) {
            eventQueue.clear()
            pendingBatches.clear()
        }
        prefs.edit().remove(KEY_PENDING_EVENTS).apply()
    }

    /**
     * Release resources (local implementation)
     */
    fun release() {
        currentSession = null
        instance = null
    }
}

/**
 * Analytics statistics
 */
data class AnalyticsStats(
    val queuedEvents: Int,
    val pendingBatches: Int,
    val pendingEvents: Int,
    val deviceId: String,
    val sessionStats: SessionStats
)

/**
 * Event builder for fluent API
 */
class EventBuilder(private val eventName: String, private val category: EventCategory) {
    private val properties = mutableMapOf<String, String>()

    fun property(key: String, value: String) = apply { properties[key] = value }
    fun property(key: String, value: Int) = apply { properties[key] = value.toString() }
    fun property(key: String, value: Long) = apply { properties[key] = value.toString() }
    fun property(key: String, value: Double) = apply { properties[key] = value.toString() }
    fun property(key: String, value: Boolean) = apply { properties[key] = value.toString() }

    fun listingId(id: String) = property(PropertyKey.LISTING_ID, id)
    fun userId(id: String) = property(PropertyKey.USER_ID, id)
    fun source(source: String) = property(PropertyKey.SOURCE, source)
    fun success(success: Boolean) = property(PropertyKey.SUCCESS, success)
    fun durationMs(ms: Long) = property(PropertyKey.DURATION_MS, ms)

    suspend fun track() {
        AnalyticsBridge.getInstance().trackCustomEvent(eventName, category, properties)
    }

    fun build(): Pair<String, Map<String, String>> = eventName to properties
}

/**
 * DSL for building events
 */
fun event(event: StandardEvent, block: EventBuilder.() -> Unit = {}): EventBuilder {
    return EventBuilder(event.eventName, event.category).apply(block)
}

fun customEvent(name: String, category: EventCategory, block: EventBuilder.() -> Unit = {}): EventBuilder {
    return EventBuilder(name, category).apply(block)
}
