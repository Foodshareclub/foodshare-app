package com.foodshare.core.realtime

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

/**
 * Represents a realtime database change event.
 *
 * SYNC: This mirrors Swift FoodshareCore.RealtimeChange
 *
 * @param T The type of the record being changed
 */
sealed class RealtimeChange<out T> {
    /**
     * A new record was inserted.
     */
    data class Insert<T>(
        val record: T,
        val table: String,
        val schema: String = "public"
    ) : RealtimeChange<T>()

    /**
     * An existing record was updated.
     */
    data class Update<T>(
        val record: T,
        val oldRecord: T?,
        val table: String,
        val schema: String = "public"
    ) : RealtimeChange<T>()

    /**
     * A record was deleted.
     */
    data class Delete<T>(
        val oldRecord: T?,
        val table: String,
        val schema: String = "public"
    ) : RealtimeChange<T>()

    /**
     * Get the current/new record if available.
     */
    fun currentRecord(): T? = when (this) {
        is Insert -> record
        is Update -> record
        is Delete -> null
    }

    /**
     * Get the old record if available.
     */
    fun previousRecord(): T? = when (this) {
        is Insert -> null
        is Update -> oldRecord
        is Delete -> oldRecord
    }

    /**
     * Map the record type to another type.
     */
    fun <R> map(transform: (T) -> R): RealtimeChange<R> = when (this) {
        is Insert -> Insert(transform(record), table, schema)
        is Update -> Update(
            transform(record),
            oldRecord?.let(transform),
            table,
            schema
        )
        is Delete -> Delete(
            oldRecord?.let(transform),
            table,
            schema
        )
    }
}

/**
 * Raw realtime change event before deserialization.
 */
@Serializable
data class RawRealtimeChange(
    val type: String,
    val table: String,
    val schema: String = "public",
    val record: JsonElement? = null,
    val oldRecord: JsonElement? = null,
    val commitTimestamp: String? = null
)

/**
 * Realtime subscription filter configuration.
 */
data class RealtimeFilter(
    val table: String,
    val schema: String = "public",
    val event: RealtimeEvent = RealtimeEvent.ALL,
    val filter: String? = null
) {
    /**
     * Build Supabase filter string.
     */
    fun toFilterString(): String? = filter

    companion object {
        /**
         * Filter for changes to a specific row by ID.
         */
        fun byId(table: String, column: String, id: Any): RealtimeFilter {
            return RealtimeFilter(
                table = table,
                filter = "$column=eq.$id"
            )
        }

        /**
         * Filter for changes by user ID.
         */
        fun byUser(table: String, userId: String, column: String = "user_id"): RealtimeFilter {
            return RealtimeFilter(
                table = table,
                filter = "$column=eq.$userId"
            )
        }

        /**
         * Filter for changes by profile ID.
         */
        fun byProfile(table: String, profileId: String, column: String = "profile_id"): RealtimeFilter {
            return RealtimeFilter(
                table = table,
                filter = "$column=eq.$profileId"
            )
        }
    }
}

/**
 * Types of realtime events to subscribe to.
 */
enum class RealtimeEvent {
    INSERT,
    UPDATE,
    DELETE,
    ALL;

    fun toPostgresEvent(): String = when (this) {
        INSERT -> "INSERT"
        UPDATE -> "UPDATE"
        DELETE -> "DELETE"
        ALL -> "*"
    }
}

/**
 * Realtime subscription state.
 */
enum class SubscriptionState {
    /** Not subscribed */
    DISCONNECTED,
    /** Connecting to channel */
    CONNECTING,
    /** Successfully subscribed */
    SUBSCRIBED,
    /** Subscription error */
    ERROR
}

/**
 * Realtime subscription info for tracking.
 */
data class SubscriptionInfo(
    val channelName: String,
    val table: String,
    val filter: RealtimeFilter?,
    val state: SubscriptionState,
    val subscribedAt: Long,
    val lastEventAt: Long? = null,
    val eventCount: Int = 0
)
