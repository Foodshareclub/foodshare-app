package com.foodshare.core.network

import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.Duration.Companion.seconds

/**
 * Configuration for RPC operations.
 *
 * SYNC: This mirrors Swift FoodshareCore.RPCConfig
 *
 * @param maxRequests Maximum requests per window
 * @param windowMs Time window in milliseconds
 * @param circuitFailureThreshold Failures before circuit opens
 * @param circuitResetTimeoutMs Time before circuit tries to recover
 * @param maxRetries Maximum retry attempts
 * @param initialRetryDelayMs Initial retry delay (doubles each retry)
 * @param maxRetryDelayMs Maximum retry delay
 * @param timeoutMs Request timeout
 * @param requiresAuditLog Whether operations need audit logging
 */
data class RPCConfig(
    val maxRequests: Int,
    val windowMs: Long,
    val circuitFailureThreshold: Int = 5,
    val circuitResetTimeoutMs: Long = 30_000,
    val maxRetries: Int = 3,
    val initialRetryDelayMs: Long = 500,
    val maxRetryDelayMs: Long = 4_000,
    val timeoutMs: Long = 30_000,
    val requiresAuditLog: Boolean = false
) {
    /**
     * Calculate retry delay with exponential backoff.
     *
     * @param attempt Current attempt number (0-based)
     * @return Delay in milliseconds
     */
    fun getRetryDelay(attempt: Int): Long {
        val delay = initialRetryDelayMs * (1 shl attempt) // 2^attempt
        return minOf(delay, maxRetryDelayMs)
    }

    /**
     * Get retry delays as a sequence.
     */
    fun getRetryDelays(): List<Duration> {
        return (0 until maxRetries).map { getRetryDelay(it).milliseconds }
    }

    companion object {
        /**
         * Default configuration (alias for normal).
         */
        val default: RPCConfig get() = normal

        /**
         * Strict configuration for sensitive operations.
         *
         * Use for: authentication, profile updates, payment operations
         * - Low rate limit (10 req/min)
         * - Audit logging enabled
         * - Shorter circuit reset
         */
        val strict = RPCConfig(
            maxRequests = 10,
            windowMs = 60_000,
            circuitFailureThreshold = 3,
            circuitResetTimeoutMs = 60_000,
            maxRetries = 2,
            initialRetryDelayMs = 1_000,
            maxRetryDelayMs = 4_000,
            timeoutMs = 30_000,
            requiresAuditLog = true
        )

        /**
         * Normal configuration for standard operations.
         *
         * Use for: creating listings, sending messages, profile fetches
         * - Moderate rate limit (60 req/min)
         * - Standard retry policy
         */
        val normal = RPCConfig(
            maxRequests = 60,
            windowMs = 60_000,
            circuitFailureThreshold = 5,
            circuitResetTimeoutMs = 30_000,
            maxRetries = 3,
            initialRetryDelayMs = 500,
            maxRetryDelayMs = 4_000,
            timeoutMs = 30_000,
            requiresAuditLog = false
        )

        /**
         * Bulk configuration for read-heavy operations.
         *
         * Use for: feed fetches, search, listing browsing
         * - High rate limit (300 req/min)
         * - More retries with shorter delays
         */
        val bulk = RPCConfig(
            maxRequests = 300,
            windowMs = 60_000,
            circuitFailureThreshold = 10,
            circuitResetTimeoutMs = 15_000,
            maxRetries = 5,
            initialRetryDelayMs = 200,
            maxRetryDelayMs = 2_000,
            timeoutMs = 15_000,
            requiresAuditLog = false
        )

        /**
         * Realtime configuration for subscription-related calls.
         *
         * Use for: realtime setup, presence, channel operations
         * - Moderate rate limit
         * - Longer timeout for connection setup
         */
        val realtime = RPCConfig(
            maxRequests = 30,
            windowMs = 60_000,
            circuitFailureThreshold = 5,
            circuitResetTimeoutMs = 10_000,
            maxRetries = 3,
            initialRetryDelayMs = 1_000,
            maxRetryDelayMs = 8_000,
            timeoutMs = 60_000,
            requiresAuditLog = false
        )

        /**
         * Background sync configuration.
         *
         * Use for: delta sync, cache refresh, background updates
         * - Very high rate limit
         * - More retries for reliability
         * - Longer delays to be gentle
         */
        val sync = RPCConfig(
            maxRequests = 500,
            windowMs = 60_000,
            circuitFailureThreshold = 10,
            circuitResetTimeoutMs = 60_000,
            maxRetries = 5,
            initialRetryDelayMs = 1_000,
            maxRetryDelayMs = 16_000,
            timeoutMs = 120_000,
            requiresAuditLog = false
        )

        /**
         * Relaxed configuration for BFF aggregated endpoints.
         *
         * Use for: home screen data, feed data, aggregated responses
         * - High rate limit (200 req/min)
         * - More lenient parsing (ignores unknown keys)
         * - Longer timeout for complex queries
         */
        val relaxed = RPCConfig(
            maxRequests = 200,
            windowMs = 60_000,
            circuitFailureThreshold = 8,
            circuitResetTimeoutMs = 20_000,
            maxRetries = 4,
            initialRetryDelayMs = 300,
            maxRetryDelayMs = 3_000,
            timeoutMs = 45_000,
            requiresAuditLog = false
        )
    }
}

/**
 * RPC function registry with configurations.
 *
 * Maps RPC function names to their appropriate configurations.
 */
object RPCFunctionRegistry {
    private val configs = mutableMapOf<String, RPCConfig>()

    init {
        // Authentication (strict)
        register("sign_in", RPCConfig.strict)
        register("sign_up", RPCConfig.strict)
        register("sign_out", RPCConfig.strict)
        register("reset_password", RPCConfig.strict)
        register("update_password", RPCConfig.strict)
        register("delete_account", RPCConfig.strict)

        // Profile (normal with audit)
        register("update_profile", RPCConfig.normal.copy(requiresAuditLog = true))
        register("get_profile", RPCConfig.normal)
        register("get_profile_by_id", RPCConfig.normal)

        // Listings (normal/bulk)
        register("create_post", RPCConfig.normal.copy(requiresAuditLog = true))
        register("update_post", RPCConfig.normal.copy(requiresAuditLog = true))
        register("delete_post", RPCConfig.normal.copy(requiresAuditLog = true))
        register("get_nearby_posts", RPCConfig.bulk)
        register("get_post_by_id", RPCConfig.bulk)
        register("search_posts", RPCConfig.bulk)

        // Messaging (normal)
        register("send_message", RPCConfig.normal)
        register("get_messages", RPCConfig.normal)
        register("get_conversations", RPCConfig.normal)
        register("mark_messages_read", RPCConfig.normal)

        // Favorites (normal)
        register("add_favorite", RPCConfig.normal)
        register("remove_favorite", RPCConfig.normal)
        register("get_favorites", RPCConfig.normal)

        // Arrangements (normal with audit)
        register("create_arrangement", RPCConfig.normal.copy(requiresAuditLog = true))
        register("update_arrangement", RPCConfig.normal.copy(requiresAuditLog = true))
        register("cancel_arrangement", RPCConfig.normal.copy(requiresAuditLog = true))

        // Categories/Metadata (bulk)
        register("get_categories", RPCConfig.bulk)
        register("get_app_config", RPCConfig.bulk)

        // Sync (sync config)
        register("get_delta_sync", RPCConfig.sync)
        register("full_sync", RPCConfig.sync)

        // Realtime (realtime config)
        register("subscribe_channel", RPCConfig.realtime)
        register("unsubscribe_channel", RPCConfig.realtime)

        // Push notifications (normal)
        register("register_push_token", RPCConfig.normal)
        register("update_push_settings", RPCConfig.normal)
    }

    /**
     * Register a configuration for an RPC function.
     */
    @Synchronized
    fun register(functionName: String, config: RPCConfig) {
        configs[functionName] = config
    }

    /**
     * Get configuration for an RPC function.
     *
     * @return Config for the function, or default normal config
     */
    @Synchronized
    fun getConfig(functionName: String): RPCConfig {
        return configs[functionName] ?: RPCConfig.normal
    }

    /**
     * Check if a function requires audit logging.
     */
    fun requiresAuditLog(functionName: String): Boolean {
        return getConfig(functionName).requiresAuditLog
    }

    /**
     * Get all registered function names.
     */
    @Synchronized
    fun getAllFunctions(): Set<String> = configs.keys.toSet()
}
