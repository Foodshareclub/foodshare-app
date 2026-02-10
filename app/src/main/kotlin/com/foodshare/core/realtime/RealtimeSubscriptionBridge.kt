package com.foodshare.core.realtime

import kotlinx.serialization.Serializable
import java.security.MessageDigest
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.min
import kotlin.math.pow

/**
 * Realtime subscription lifecycle management.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for channel state machine
 * - Reconnection with exponential backoff
 * - Message deduplication
 * - No JNI required for these stateless operations
 *
 * Example:
 *   val bridge = RealtimeSubscriptionBridge
 *   bridge.registerChannel("messages", "realtime:messages", "messages")
 *   bridge.markConnected("messages")
 *   if (bridge.shouldProcessMessage("messages", msgId)) {
 *       processMessage(msg)
 *   }
 */
object RealtimeSubscriptionBridge {

    // Local state tracking
    private val channelStates = ConcurrentHashMap<String, ChannelState>()
    private val channelInfo = ConcurrentHashMap<String, ChannelInfo>()
    private val reconnectAttempts = ConcurrentHashMap<String, Int>()
    private val seenMessages = ConcurrentHashMap<String, MutableSet<String>>()

    // ========================================================================
    // Channel Registration
    // ========================================================================

    /**
     * Register a channel subscription.
     */
    fun registerChannel(
        channelId: String,
        topic: String,
        table: String? = null,
        filter: String? = null
    ): ChannelInfo? {
        val info = ChannelInfo(
            channelId = channelId,
            topic = topic,
            table = table,
            filter = filter,
            state = ChannelState.DISCONNECTED.value,
            messageCount = 0,
            errorCount = 0
        )

        channelStates[channelId] = ChannelState.DISCONNECTED
        channelInfo[channelId] = info
        reconnectAttempts[channelId] = 0
        seenMessages[channelId] = ConcurrentHashMap.newKeySet()

        return info
    }

    /**
     * Remove a channel subscription.
     */
    fun removeChannel(channelId: String) {
        channelStates.remove(channelId)
        reconnectAttempts.remove(channelId)
        seenMessages.remove(channelId)
    }

    /**
     * Get current channel state.
     */
    fun getChannelState(channelId: String): ChannelState {
        return channelStates[channelId] ?: ChannelState.DISCONNECTED
    }

    /**
     * Get all registered channel IDs.
     */
    fun getRegisteredChannels(): List<String> {
        return channelStates.keys().toList()
    }

    // ========================================================================
    // State Transitions
    // ========================================================================

    /**
     * Process a channel event and return the transition result.
     */
    fun processEvent(channelId: String, event: ChannelEvent): ChannelTransitionResult? {
        val currentState = channelStates[channelId] ?: ChannelState.DISCONNECTED
        val attempts = reconnectAttempts[channelId] ?: 0

        // State machine transitions
        val (newState, newAttempts) = when (event) {
            ChannelEvent.CONNECT -> {
                ChannelState.CONNECTING to attempts
            }
            ChannelEvent.CONNECTED -> {
                ChannelState.CONNECTED to 0  // Reset attempts on success
            }
            ChannelEvent.DISCONNECT, ChannelEvent.CONNECTION_LOST -> {
                ChannelState.DISCONNECTED to attempts
            }
            ChannelEvent.RECONNECT -> {
                ChannelState.RECONNECTING to attempts + 1
            }
            ChannelEvent.RECONNECT_FAILED -> {
                if (attempts >= 10) {
                    ChannelState.FAILED to attempts
                } else {
                    ChannelState.BACKING_OFF to attempts
                }
            }
            ChannelEvent.BACKOFF_COMPLETE -> {
                ChannelState.RECONNECTING to attempts
            }
            ChannelEvent.MAX_RETRIES_REACHED -> {
                ChannelState.FAILED to attempts
            }
            ChannelEvent.CLOSE -> {
                ChannelState.CLOSED to 0
            }
            ChannelEvent.RESET -> {
                ChannelState.DISCONNECTED to 0
            }
        }

        val transitioned = newState != currentState
        channelStates[channelId] = newState
        reconnectAttempts[channelId] = newAttempts

        return ChannelTransitionResult(
            previousState = currentState.value,
            currentState = newState.value,
            transitioned = transitioned,
            reconnectAttempts = newAttempts
        )
    }

    /**
     * Mark channel as connecting.
     */
    fun markConnecting(channelId: String): ChannelTransitionResult? {
        return processEvent(channelId, ChannelEvent.CONNECT)
    }

    /**
     * Mark channel as connected.
     */
    fun markConnected(channelId: String): ChannelTransitionResult? {
        return processEvent(channelId, ChannelEvent.CONNECTED)
    }

    /**
     * Mark channel as disconnected (lost connection).
     */
    fun markDisconnected(channelId: String): ChannelTransitionResult? {
        return processEvent(channelId, ChannelEvent.CONNECTION_LOST)
    }

    /**
     * Mark reconnection attempt as failed.
     */
    fun markReconnectFailed(channelId: String): ChannelTransitionResult? {
        return processEvent(channelId, ChannelEvent.RECONNECT_FAILED)
    }

    /**
     * Close a channel.
     */
    fun closeChannel(channelId: String): ChannelTransitionResult? {
        return processEvent(channelId, ChannelEvent.CLOSE)
    }

    /**
     * Reset a channel to initial state.
     */
    fun resetChannel(channelId: String): ChannelTransitionResult? {
        seenMessages[channelId]?.clear()
        return processEvent(channelId, ChannelEvent.RESET)
    }

    // ========================================================================
    // Reconnection
    // ========================================================================

    /**
     * Get reconnection delay for a channel.
     */
    fun getReconnectionDelay(
        channelId: String,
        policy: ReconnectionPolicy = ReconnectionPolicy.DEFAULT
    ): Long {
        val attempts = reconnectAttempts[channelId] ?: 0

        val baseDelayMs = when (policy) {
            ReconnectionPolicy.IMMEDIATE -> 0L
            ReconnectionPolicy.AGGRESSIVE -> 500L
            ReconnectionPolicy.DEFAULT -> 1000L
            ReconnectionPolicy.CONSERVATIVE -> 2000L
            ReconnectionPolicy.LINEAR -> 1000L
        }

        val maxDelayMs = when (policy) {
            ReconnectionPolicy.IMMEDIATE -> 0L
            ReconnectionPolicy.AGGRESSIVE -> 10_000L
            ReconnectionPolicy.DEFAULT -> 30_000L
            ReconnectionPolicy.CONSERVATIVE -> 60_000L
            ReconnectionPolicy.LINEAR -> 30_000L
        }

        if (policy == ReconnectionPolicy.IMMEDIATE) return 0L

        val delay = if (policy == ReconnectionPolicy.LINEAR) {
            baseDelayMs * (attempts + 1)
        } else {
            // Exponential backoff with jitter
            val exponentialDelay = baseDelayMs * 2.0.pow(attempts.toDouble())
            val jitter = (Math.random() * 0.3 - 0.15) * exponentialDelay
            (exponentialDelay + jitter).toLong()
        }

        return min(delay, maxDelayMs)
    }

    /**
     * Check if should retry reconnection.
     */
    fun shouldRetryReconnection(
        channelId: String,
        maxAttempts: Int = 10
    ): Boolean {
        val attempts = reconnectAttempts[channelId] ?: 0
        return attempts < maxAttempts
    }

    /**
     * Get current reconnection attempt count.
     */
    fun getReconnectAttempts(channelId: String): Int {
        return reconnectAttempts[channelId] ?: 0
    }

    /**
     * Get channels that need reconnection.
     */
    fun getChannelsNeedingReconnection(): List<String> {
        return channelStates.entries
            .filter { (_, state) ->
                state == ChannelState.RECONNECTING ||
                state == ChannelState.BACKING_OFF ||
                state == ChannelState.DISCONNECTED
            }
            .filter { (id, _) ->
                shouldRetryReconnection(id)
            }
            .map { it.key }
    }

    // ========================================================================
    // Message Deduplication
    // ========================================================================

    /**
     * Check if a message should be processed (not a duplicate).
     */
    fun shouldProcessMessage(channelId: String, messageId: String): Boolean {
        val seen = seenMessages[channelId] ?: run {
            val newSet = ConcurrentHashMap.newKeySet<String>()
            seenMessages[channelId] = newSet
            newSet
        }

        return if (seen.contains(messageId)) {
            false
        } else {
            seen.add(messageId)
            // Limit size
            if (seen.size > 1000) {
                val toRemove = seen.take(seen.size - 1000)
                toRemove.forEach { seen.remove(it) }
            }
            true
        }
    }

    /**
     * Generate a fingerprint for a message.
     */
    fun generateMessageFingerprint(
        table: String,
        eventType: String,
        recordId: String,
        timestamp: String? = null
    ): String {
        val input = "$table:$eventType:$recordId:${timestamp ?: ""}"
        val md = MessageDigest.getInstance("MD5")
        val digest = md.digest(input.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    /**
     * Clear seen messages for a channel.
     */
    fun clearSeenMessages(channelId: String) {
        seenMessages[channelId]?.clear()
    }

    // ========================================================================
    // Health & Stats
    // ========================================================================

    /**
     * Get subscription health summary.
     */
    fun getHealth(): SubscriptionHealth {
        val total = channelStates.size
        val connected = channelStates.values.count { it == ChannelState.CONNECTED }
        val reconnecting = channelStates.values.count {
            it == ChannelState.RECONNECTING || it == ChannelState.BACKING_OFF
        }
        val failed = channelStates.values.count { it == ChannelState.FAILED }

        val status = when {
            failed > 0 || reconnecting > connected -> HealthStatus.DEGRADED
            connected == total && total > 0 -> HealthStatus.HEALTHY
            total == 0 -> HealthStatus.UNKNOWN
            else -> HealthStatus.CONNECTING
        }

        return SubscriptionHealth(
            status = status,
            totalChannels = total,
            connectedChannels = connected,
            reconnectingChannels = reconnecting,
            failedChannels = failed
        )
    }

    /**
     * Reset all channels.
     */
    fun resetAll() {
        channelStates.keys.forEach { channelId ->
            channelStates[channelId] = ChannelState.DISCONNECTED
            reconnectAttempts[channelId] = 0
            seenMessages[channelId]?.clear()
        }
    }
}

// ========================================================================
// Data Classes
// ========================================================================

enum class ChannelState(val value: String) {
    DISCONNECTED("disconnected"),
    CONNECTING("connecting"),
    CONNECTED("connected"),
    RECONNECTING("reconnecting"),
    BACKING_OFF("backing_off"),
    FAILED("failed"),
    CLOSED("closed");

    val isActive: Boolean get() = this == CONNECTED
    val isTransitioning: Boolean get() = this in listOf(CONNECTING, RECONNECTING, BACKING_OFF)
    val shouldAutoReconnect: Boolean get() = this in listOf(DISCONNECTED, RECONNECTING, BACKING_OFF)

    companion object {
        fun fromValue(value: String): ChannelState =
            entries.find { it.value == value } ?: DISCONNECTED
    }
}

enum class ChannelEvent(val value: String) {
    CONNECT("connect"),
    CONNECTED("connected"),
    DISCONNECT("disconnect"),
    CONNECTION_LOST("connection_lost"),
    RECONNECT("reconnect"),
    RECONNECT_FAILED("reconnect_failed"),
    BACKOFF_COMPLETE("backoff_complete"),
    MAX_RETRIES_REACHED("max_retries_reached"),
    CLOSE("close"),
    RESET("reset")
}

enum class ReconnectionPolicy(val value: String) {
    DEFAULT("default"),
    AGGRESSIVE("aggressive"),
    CONSERVATIVE("conservative"),
    LINEAR("linear"),
    IMMEDIATE("immediate")
}

enum class HealthStatus {
    HEALTHY,
    CONNECTING,
    DEGRADED,
    UNKNOWN
}

@Serializable
data class ChannelInfo(
    val channelId: String,
    val topic: String,
    val table: String? = null,
    val filter: String? = null,
    val state: String = "disconnected",
    val messageCount: Int = 0,
    val errorCount: Int = 0
)

@Serializable
data class ChannelTransitionResult(
    val previousState: String,
    val currentState: String,
    val transitioned: Boolean,
    val reconnectAttempts: Int
)

data class SubscriptionHealth(
    val status: HealthStatus,
    val totalChannels: Int,
    val connectedChannels: Int,
    val reconnectingChannels: Int,
    val failedChannels: Int
) {
    val connectionRate: Float
        get() = if (totalChannels > 0) connectedChannels.toFloat() / totalChannels else 0f
}

// ========================================================================
// Event Processing Extension
// ========================================================================

/**
 * Realtime event processing with local implementations.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for event filtering, transformation, batching
 * - No JNI required for these stateless operations
 */
object RealtimeEventProcessorBridge {

    /**
     * Filter realtime events based on criteria.
     */
    fun filterEvents(
        events: List<RealtimeEventData>,
        filter: EventFilterData
    ): List<RealtimeEventData> {
        return events.filter { event ->
            // Filter by table
            if (filter.table != null && event.table != filter.table) return@filter false

            // Filter by event types
            if (filter.eventTypes != null && event.eventType !in filter.eventTypes) return@filter false

            // Filter by user ID
            if (filter.userId != null && event.userId != filter.userId && event.affectedUserId != filter.userId) {
                return@filter false
            }

            // Filter by entity ID
            if (filter.entityId != null && event.recordId != filter.entityId) return@filter false

            // Filter by time range
            if (filter.since != null && event.timestamp < filter.since) return@filter false
            if (filter.until != null && event.timestamp > filter.until) return@filter false

            true
        }
    }

    /**
     * Transform events for UI consumption.
     */
    fun transformForUI(events: List<RealtimeEventData>): List<UIEventUpdate> {
        return events.map { event ->
            val uiType = when (event.eventType) {
                RealtimeEventType.INSERT -> UIEventTypeData.ADDED
                RealtimeEventType.UPDATE -> UIEventTypeData.MODIFIED
                RealtimeEventType.DELETE -> UIEventTypeData.REMOVED
            }

            val animationType = when (event.eventType) {
                RealtimeEventType.INSERT -> AnimationTypeData.SLIDE_IN
                RealtimeEventType.UPDATE -> AnimationTypeData.HIGHLIGHT
                RealtimeEventType.DELETE -> AnimationTypeData.FADE_OUT
            }

            val requiresRefresh = event.eventType == RealtimeEventType.DELETE ||
                    (event.changedFields?.size ?: 0) > 3

            UIEventUpdate(
                id = event.id,
                type = uiType,
                entityType = event.table,
                entityId = event.recordId,
                timestamp = event.timestamp,
                payload = event.payload,
                requiresRefresh = requiresRefresh,
                animationType = animationType
            )
        }
    }

    /**
     * Batch multiple events for the same entity.
     */
    fun batchEvents(events: List<RealtimeEventData>): List<BatchedEventData> {
        // Group by entity key (table:recordId)
        val grouped = events.groupBy { "${it.table}:${it.recordId}" }

        return grouped.map { (entityKey, entityEvents) ->
            val sortedEvents = entityEvents.sortedBy { it.timestamp }
            val firstEvent = sortedEvents.first()
            val lastEvent = sortedEvents.last()

            // Determine effective event type
            val hasInsert = entityEvents.any { it.eventType == RealtimeEventType.INSERT }
            val hasDelete = entityEvents.any { it.eventType == RealtimeEventType.DELETE }

            val effectiveType = when {
                hasDelete -> RealtimeEventType.DELETE
                hasInsert && !hasDelete -> RealtimeEventType.INSERT
                else -> RealtimeEventType.UPDATE
            }

            BatchedEventData(
                entityKey = entityKey,
                table = firstEvent.table,
                recordId = firstEvent.recordId,
                events = sortedEvents,
                effectiveEventType = effectiveType,
                latestTimestamp = lastEvent.timestamp
            )
        }
    }

    /**
     * Optimize subscriptions by consolidating overlapping filters.
     */
    fun optimizeSubscriptions(subscriptions: List<SubscriptionConfigData>): List<SubscriptionConfigData> {
        // Group by table
        val byTable = subscriptions.groupBy { it.table }

        return byTable.flatMap { (table, subs) ->
            // If there's a subscription with no filter, it covers all others
            val noFilter = subs.find { it.filter.isNullOrBlank() }
            if (noFilter != null) {
                listOf(noFilter)
            } else {
                // Keep distinct subscriptions
                subs.distinctBy { "${it.table}:${it.filter}:${it.eventTypes.sorted()}" }
            }
        }
    }

    /**
     * Calculate diff between current and desired subscriptions.
     */
    fun calculateSubscriptionDiff(
        current: List<SubscriptionConfigData>,
        desired: List<SubscriptionConfigData>
    ): SubscriptionDiff {
        val currentKeys = current.map { "${it.table}:${it.filter}" }.toSet()
        val desiredKeys = desired.map { "${it.table}:${it.filter}" }.toSet()

        val toAdd = desired.filter { "${it.table}:${it.filter}" !in currentKeys }
        val toRemove = current.filter { "${it.table}:${it.filter}" !in desiredKeys }
        val unchanged = current.filter { "${it.table}:${it.filter}" in desiredKeys }

        return SubscriptionDiff(
            toAdd = toAdd,
            toRemove = toRemove,
            unchanged = unchanged
        )
    }
}

// Event Processing Data Classes

@Serializable
enum class RealtimeEventType(val value: String) {
    INSERT("INSERT"),
    UPDATE("UPDATE"),
    DELETE("DELETE")
}

@Serializable
enum class UIEventTypeData(val value: String) {
    ADDED("added"),
    MODIFIED("modified"),
    REMOVED("removed")
}

@Serializable
enum class AnimationTypeData(val value: String) {
    NONE("none"),
    FADE_IN("fade_in"),
    FADE_OUT("fade_out"),
    HIGHLIGHT("highlight"),
    SLIDE_IN("slide_in"),
    SLIDE_OUT("slide_out")
}

@Serializable
data class RealtimeEventData(
    val id: String,
    val table: String,
    val eventType: RealtimeEventType,
    val recordId: String,
    val timestamp: String,  // ISO8601
    val userId: String? = null,
    val affectedUserId: String? = null,
    val payload: String? = null,
    val changedFields: List<String>? = null
)

@Serializable
data class EventFilterData(
    val table: String? = null,
    val eventTypes: List<RealtimeEventType>? = null,
    val userId: String? = null,
    val entityId: String? = null,
    val since: String? = null,  // ISO8601
    val until: String? = null   // ISO8601
)

@Serializable
data class UIEventUpdate(
    val id: String,
    val type: UIEventTypeData,
    val entityType: String,
    val entityId: String,
    val timestamp: String,
    val payload: String?,
    val requiresRefresh: Boolean,
    val animationType: AnimationTypeData
)

@Serializable
data class BatchedEventData(
    val entityKey: String,
    val table: String,
    val recordId: String,
    val events: List<RealtimeEventData>,
    val effectiveEventType: RealtimeEventType,
    val latestTimestamp: String
) {
    val eventCount: Int get() = events.size
}

@Serializable
data class SubscriptionConfigData(
    val id: String,
    val table: String,
    val filter: String? = null,
    val eventTypes: List<RealtimeEventType> = listOf(
        RealtimeEventType.INSERT,
        RealtimeEventType.UPDATE,
        RealtimeEventType.DELETE
    )
)

@Serializable
data class SubscriptionDiff(
    val toAdd: List<SubscriptionConfigData>,
    val toRemove: List<SubscriptionConfigData>,
    val unchanged: List<SubscriptionConfigData>
) {
    val hasChanges: Boolean get() = toAdd.isNotEmpty() || toRemove.isNotEmpty()
}
