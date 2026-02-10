package com.foodshare.core.realtime

import android.util.Log
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Centralized manager for Supabase Realtime subscriptions.
 *
 * Features:
 * - Prevents duplicate subscriptions
 * - Automatic cleanup on logout
 * - Channel lifecycle management
 * - Stale channel detection
 *
 * SYNC: This mirrors Swift FoodshareCore.RealtimeChannelManager
 */
@Singleton
class RealtimeChannelManager @Inject constructor(
    private val supabaseClient: SupabaseClient
) {
    companion object {
        private const val TAG = "RealtimeManager"
        private const val DEFAULT_STALE_TIMEOUT_MS = 30 * 60 * 1000L // 30 minutes
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mutex = Mutex()

    private val activeChannels = mutableMapOf<String, ManagedChannel>()
    private val _subscriptions = MutableStateFlow<Map<String, SubscriptionInfo>>(emptyMap())
    val subscriptions: StateFlow<Map<String, SubscriptionInfo>> = _subscriptions.asStateFlow()

    @PublishedApi
    internal val json = Json { ignoreUnknownKeys = true }

    /**
     * Internal wrapper for managed channels.
     */
    private data class ManagedChannel(
        val channel: RealtimeChannel,
        val filter: RealtimeFilter,
        var state: SubscriptionState = SubscriptionState.DISCONNECTED,
        val subscribedAt: Long = System.currentTimeMillis(),
        var lastEventAt: Long? = null,
        var eventCount: Int = 0
    )

    /**
     * Subscribe to a table with optional filter.
     *
     * @param filter Subscription filter configuration
     * @return Flow of realtime changes
     */
    suspend inline fun <reified T> subscribe(
        filter: RealtimeFilter
    ): Flow<RealtimeChange<T>> {
        return subscribeInternal(filter) { record ->
            json.decodeFromString<T>(record)
        }
    }

    /**
     * Internal subscribe implementation (non-inline to access private members).
     */
    @PublishedApi
    internal suspend fun <T> subscribeInternal(
        filter: RealtimeFilter,
        decoder: (String) -> T
    ): Flow<RealtimeChange<T>> = mutex.withLock {
        val channelName = buildChannelName(filter)

        // Check for existing subscription
        activeChannels[channelName]?.let { managed ->
            Log.d(TAG, "Reusing existing channel: $channelName")
            return@withLock createChangeFlowInternal(managed.channel, filter, channelName, decoder)
        }

        // Create new channel
        Log.d(TAG, "Creating new channel: $channelName")
        val channel = supabaseClient.channel(channelName)

        val managed = ManagedChannel(
            channel = channel,
            filter = filter,
            state = SubscriptionState.CONNECTING
        )
        activeChannels[channelName] = managed
        updateSubscriptionsState()

        // Subscribe to channel
        try {
            channel.subscribe()
            managed.state = SubscriptionState.SUBSCRIBED
            updateSubscriptionsState()
            Log.d(TAG, "Channel subscribed: $channelName")
        } catch (e: Exception) {
            managed.state = SubscriptionState.ERROR
            updateSubscriptionsState()
            Log.e(TAG, "Failed to subscribe to channel: $channelName", e)
            throw e
        }

        return@withLock createChangeFlowInternal(channel, filter, channelName, decoder)
    }

    /**
     * Create a Flow of realtime changes from a channel (non-inline).
     */
    private fun <T> createChangeFlowInternal(
        channel: RealtimeChannel,
        filter: RealtimeFilter,
        channelName: String,
        decoder: (String) -> T
    ): Flow<RealtimeChange<T>> {
        // Create flows for each event type
        val insertFlow = channel.postgresChangeFlow<PostgresAction.Insert>(schema = filter.schema) {
            table = filter.table
        }.map { action ->
            val record = decoder(action.record.toString())
            RealtimeChange.Insert(record, filter.table, filter.schema) as RealtimeChange<T>
        }

        val updateFlow = channel.postgresChangeFlow<PostgresAction.Update>(schema = filter.schema) {
            table = filter.table
        }.map { action ->
            val record = decoder(action.record.toString())
            val oldRecord: T? = action.oldRecord?.let {
                try { decoder(it.toString()) } catch (e: Exception) { null }
            }
            RealtimeChange.Update(record, oldRecord, filter.table, filter.schema) as RealtimeChange<T>
        }

        val deleteFlow = channel.postgresChangeFlow<PostgresAction.Delete>(schema = filter.schema) {
            table = filter.table
        }.map { action ->
            val oldRecord: T? = action.oldRecord?.let {
                try { decoder(it.toString()) } catch (e: Exception) { null }
            }
            RealtimeChange.Delete(oldRecord, filter.table, filter.schema) as RealtimeChange<T>
        }

        // Merge all event flows
        return merge(insertFlow, updateFlow, deleteFlow)
            .onEach { change ->
                // Update metrics
                activeChannels[channelName]?.let { managed ->
                    managed.lastEventAt = System.currentTimeMillis()
                    managed.eventCount++
                    updateSubscriptionsState()
                }
            }
            .catch { e ->
                Log.e(TAG, "Error in realtime flow: $channelName", e)
                activeChannels[channelName]?.state = SubscriptionState.ERROR
                updateSubscriptionsState()
                throw e
            }
    }

    /**
     * Unsubscribe from a specific channel.
     */
    suspend fun unsubscribe(channelName: String) = mutex.withLock {
        activeChannels[channelName]?.let { managed ->
            try {
                managed.channel.unsubscribe()
                Log.d(TAG, "Unsubscribed from channel: $channelName")
            } catch (e: Exception) {
                Log.w(TAG, "Error unsubscribing from channel: $channelName", e)
            }
            activeChannels.remove(channelName)
            updateSubscriptionsState()
        }
    }

    /**
     * Unsubscribe from a table/filter combination.
     */
    suspend fun unsubscribe(filter: RealtimeFilter) {
        unsubscribe(buildChannelName(filter))
    }

    /**
     * Unsubscribe from all channels.
     */
    suspend fun unsubscribeAll() = mutex.withLock {
        Log.d(TAG, "Unsubscribing from all channels (${activeChannels.size})")
        activeChannels.forEach { (name, managed) ->
            try {
                managed.channel.unsubscribe()
            } catch (e: Exception) {
                Log.w(TAG, "Error unsubscribing from channel: $name", e)
            }
        }
        activeChannels.clear()
        updateSubscriptionsState()
    }

    /**
     * Clean up stale channels that haven't received events.
     */
    suspend fun cleanupStaleChannels(maxAgeMs: Long = DEFAULT_STALE_TIMEOUT_MS) = mutex.withLock {
        val now = System.currentTimeMillis()
        val staleChannels = activeChannels.filter { (_, managed) ->
            val lastActivity = managed.lastEventAt ?: managed.subscribedAt
            now - lastActivity > maxAgeMs
        }

        if (staleChannels.isNotEmpty()) {
            Log.d(TAG, "Cleaning up ${staleChannels.size} stale channels")
            staleChannels.forEach { (name, managed) ->
                try {
                    managed.channel.unsubscribe()
                } catch (e: Exception) {
                    Log.w(TAG, "Error cleaning up stale channel: $name", e)
                }
                activeChannels.remove(name)
            }
            updateSubscriptionsState()
        }
    }

    /**
     * Get information about a specific subscription.
     */
    fun getSubscriptionInfo(channelName: String): SubscriptionInfo? {
        return activeChannels[channelName]?.toInfo(channelName)
    }

    /**
     * Get all active subscriptions.
     */
    fun getActiveSubscriptions(): List<SubscriptionInfo> {
        return activeChannels.map { (name, managed) -> managed.toInfo(name) }
    }

    /**
     * Check if a subscription exists.
     */
    fun isSubscribed(filter: RealtimeFilter): Boolean {
        return activeChannels.containsKey(buildChannelName(filter))
    }

    /**
     * Build a unique channel name from filter.
     */
    private fun buildChannelName(filter: RealtimeFilter): String {
        val base = "${filter.schema}:${filter.table}"
        return filter.filter?.let { "$base:$it" } ?: base
    }

    /**
     * Update the subscriptions state flow.
     */
    private fun updateSubscriptionsState() {
        _subscriptions.value = activeChannels.mapValues { (name, managed) ->
            managed.toInfo(name)
        }
    }

    /**
     * Convert ManagedChannel to SubscriptionInfo.
     */
    private fun ManagedChannel.toInfo(channelName: String) = SubscriptionInfo(
        channelName = channelName,
        table = filter.table,
        filter = filter,
        state = state,
        subscribedAt = subscribedAt,
        lastEventAt = lastEventAt,
        eventCount = eventCount
    )

    /**
     * Cleanup resources.
     */
    fun destroy() {
        scope.launch {
            unsubscribeAll()
        }
        scope.cancel()
    }
}

/**
 * Extension for subscribing to a table without filter.
 */
suspend inline fun <reified T> RealtimeChannelManager.subscribeToTable(
    table: String,
    schema: String = "public"
): Flow<RealtimeChange<T>> {
    return subscribe(RealtimeFilter(table = table, schema = schema))
}

/**
 * Extension for subscribing to changes for a specific user.
 */
suspend inline fun <reified T> RealtimeChannelManager.subscribeForUser(
    table: String,
    userId: String,
    userIdColumn: String = "user_id"
): Flow<RealtimeChange<T>> {
    return subscribe(RealtimeFilter.byUser(table, userId, userIdColumn))
}
