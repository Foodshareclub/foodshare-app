package com.foodshare.core.cache

import kotlinx.serialization.Serializable
import kotlinx.serialization.SerialName
import kotlinx.serialization.json.Json
import java.security.MessageDigest
import java.time.Instant
import java.util.UUID

/**
 * Cache Invalidation Bridge
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for cache key generation and invalidation
 * - Pattern matching, TTL calculations, freshness checks are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - Cache key generation with versioning
 * - Event creation for invalidation
 * - Pattern-based key matching
 * - Freshness scoring and TTL management
 */
object CacheInvalidationBridge {

    private val json = Json { ignoreUnknownKeys = true }

    private const val CACHE_VERSION = "v1"
    private const val CACHE_PREFIX = "fs"

    // =========================================================================
    // Entity Types
    // =========================================================================

    /**
     * Types of entities that can be cached.
     */
    enum class EntityType(val value: String) {
        LISTING("listing"),
        USER("user"),
        PROFILE("profile"),
        CHAT_ROOM("chatRoom"),
        MESSAGE("message"),
        NOTIFICATION("notification"),
        REVIEW("review"),
        FAVORITE("favorite"),
        CHALLENGE("challenge"),
        FORUM_POST("forumPost"),
        FORUM_COMMENT("forumComment"),
        CATEGORY("category"),
        SEARCH("search"),
        FEED("feed"),
        DASHBOARD("dashboard")
    }

    /**
     * Types of invalidation events.
     */
    enum class EventType(val value: String) {
        CREATE("create"),
        UPDATE("update"),
        DELETE("delete"),
        EXPIRE("expire"),
        REFRESH("refresh"),
        BULK_UPDATE("bulkUpdate"),
        RELATION_CHANGE("relationChange"),
        USER_ACTION("userAction")
    }

    // TTL values in seconds by entity type
    private val entityTTLs = mapOf(
        EntityType.LISTING to 300.0,        // 5 min
        EntityType.USER to 600.0,           // 10 min
        EntityType.PROFILE to 600.0,        // 10 min
        EntityType.CHAT_ROOM to 60.0,       // 1 min
        EntityType.MESSAGE to 30.0,         // 30 sec
        EntityType.NOTIFICATION to 120.0,   // 2 min
        EntityType.REVIEW to 300.0,         // 5 min
        EntityType.FAVORITE to 60.0,        // 1 min
        EntityType.CHALLENGE to 300.0,      // 5 min
        EntityType.FORUM_POST to 300.0,     // 5 min
        EntityType.FORUM_COMMENT to 120.0,  // 2 min
        EntityType.CATEGORY to 3600.0,      // 1 hour
        EntityType.SEARCH to 120.0,         // 2 min
        EntityType.FEED to 60.0,            // 1 min
        EntityType.DASHBOARD to 120.0       // 2 min
    )

    // Stale thresholds (percentage of TTL)
    private val staleThresholdRatio = 0.7  // Mark as stale at 70% of TTL

    // Prefetch priorities by entity type (0-100)
    private val prefetchPriorities = mapOf(
        EntityType.LISTING to 80,
        EntityType.USER to 60,
        EntityType.PROFILE to 70,
        EntityType.CHAT_ROOM to 90,
        EntityType.MESSAGE to 95,
        EntityType.FEED to 85,
        EntityType.NOTIFICATION to 75
    )

    // =========================================================================
    // Key Generation
    // =========================================================================

    /**
     * Generates a cache key for a single entity.
     */
    fun generateEntityKey(entityType: EntityType, entityId: String): String {
        return "$CACHE_PREFIX:$CACHE_VERSION:${entityType.value}:$entityId"
    }

    /**
     * Generates a cache key for a paginated list.
     */
    fun generateListKey(
        entityType: EntityType,
        page: Int = 1,
        limit: Int = 20,
        filter: String? = null
    ): String {
        val base = "$CACHE_PREFIX:$CACHE_VERSION:${entityType.value}:list:p$page:l$limit"
        return if (filter != null) {
            "$base:f${hashString(filter)}"
        } else {
            base
        }
    }

    /**
     * Generates a cache key for a query with parameters.
     */
    fun generateQueryKey(entityType: EntityType, params: Map<String, String>): String {
        val sortedParams = params.entries.sortedBy { it.key }
        val paramsHash = hashString(sortedParams.joinToString("&") { "${it.key}=${it.value}" })
        return "$CACHE_PREFIX:$CACHE_VERSION:${entityType.value}:query:$paramsHash"
    }

    /**
     * Generates a pattern for matching related cache keys.
     */
    fun generatePattern(entityType: EntityType, entityId: String? = null): String {
        return if (entityId != null) {
            "$CACHE_PREFIX:$CACHE_VERSION:${entityType.value}:$entityId*"
        } else {
            "$CACHE_PREFIX:$CACHE_VERSION:${entityType.value}:*"
        }
    }

    /**
     * Hash a string for cache key generation.
     */
    private fun hashString(input: String): String {
        val bytes = MessageDigest.getInstance("MD5").digest(input.toByteArray())
        return bytes.take(8).joinToString("") { "%02x".format(it) }
    }

    // =========================================================================
    // Convenience Key Generators
    // =========================================================================

    fun listingKey(id: String) = generateEntityKey(EntityType.LISTING, id)
    fun listingDetailKey(id: String) = "${generateEntityKey(EntityType.LISTING, id)}:detail"
    fun userKey(id: String) = generateEntityKey(EntityType.USER, id)
    fun profileKey(id: String) = generateEntityKey(EntityType.PROFILE, id)
    fun chatRoomKey(id: String) = generateEntityKey(EntityType.CHAT_ROOM, id)

    fun feedKey(userId: String, page: Int = 1): String {
        return generateQueryKey(EntityType.FEED, mapOf("userId" to userId, "page" to page.toString()))
    }

    fun dashboardKey(userId: String): String {
        return generateQueryKey(EntityType.DASHBOARD, mapOf("userId" to userId))
    }

    fun notificationsKey(userId: String, page: Int = 1): String {
        return generateQueryKey(
            EntityType.NOTIFICATION,
            mapOf("userId" to userId, "page" to page.toString())
        )
    }

    fun searchKey(query: String, filters: Map<String, String> = emptyMap(), page: Int = 1): String {
        val params = filters.toMutableMap()
        params["q"] = query
        params["page"] = page.toString()
        return generateQueryKey(EntityType.SEARCH, params)
    }

    fun challengesKey(userId: String? = null): String {
        val params = mutableMapOf<String, String>()
        userId?.let { params["userId"] = it }
        return generateQueryKey(EntityType.CHALLENGE, params)
    }

    // =========================================================================
    // Event Creation
    // =========================================================================

    /**
     * Creates an invalidation event.
     */
    fun createEvent(
        eventType: EventType,
        entityType: EntityType,
        entityId: String? = null,
        cascadeInvalidation: Boolean = true
    ): InvalidationEvent? {
        val affectedKeys = mutableListOf<String>()

        // Add primary key
        entityId?.let {
            affectedKeys.add(generateEntityKey(entityType, it))
        }

        // Add related patterns if cascading
        if (cascadeInvalidation) {
            affectedKeys.add(generatePattern(entityType, entityId))

            // Add cascade patterns based on entity type
            when (entityType) {
                EntityType.LISTING -> {
                    affectedKeys.add(generatePattern(EntityType.FEED))
                    affectedKeys.add(generatePattern(EntityType.SEARCH))
                }
                EntityType.MESSAGE -> {
                    entityId?.let { id ->
                        // Invalidate chat room when message changes
                        affectedKeys.add(generatePattern(EntityType.CHAT_ROOM))
                    }
                }
                EntityType.REVIEW -> {
                    affectedKeys.add(generatePattern(EntityType.PROFILE))
                }
                EntityType.FAVORITE -> {
                    affectedKeys.add(generatePattern(EntityType.LISTING))
                }
                else -> {}
            }
        }

        return InvalidationEvent(
            id = UUID.randomUUID().toString(),
            eventType = eventType.value,
            entityType = entityType.value,
            entityId = entityId,
            affectedKeys = affectedKeys,
            cascadeInvalidation = cascadeInvalidation,
            timestamp = Instant.now().toString()
        )
    }

    /**
     * Creates a creation event.
     */
    fun createdEvent(entityType: EntityType, id: String): InvalidationEvent? {
        return createEvent(EventType.CREATE, entityType, id, cascadeInvalidation = true)
    }

    /**
     * Creates an update event.
     */
    fun updatedEvent(entityType: EntityType, id: String): InvalidationEvent? {
        return createEvent(EventType.UPDATE, entityType, id, cascadeInvalidation = true)
    }

    /**
     * Creates a deletion event.
     */
    fun deletedEvent(entityType: EntityType, id: String): InvalidationEvent? {
        return createEvent(EventType.DELETE, entityType, id, cascadeInvalidation = true)
    }

    // =========================================================================
    // Pattern Matching
    // =========================================================================

    /**
     * Checks if a cache key matches a pattern (supports * wildcard).
     */
    fun matchesPattern(key: String, pattern: String): Boolean {
        // Convert glob pattern to regex
        val regexPattern = pattern
            .replace(".", "\\.")
            .replace("*", ".*")
            .let { "^$it$" }

        return try {
            Regex(regexPattern).matches(key)
        } catch (e: Exception) {
            false
        }
    }

    /**
     * Parses a cache key to extract information.
     */
    fun parseKey(key: String): CacheKeyInfo? {
        val parts = key.split(":")
        if (parts.size < 3) return null

        val prefix = parts.getOrNull(0)
        val version = parts.getOrNull(1)
        val entityTypeStr = parts.getOrNull(2)

        if (prefix != CACHE_PREFIX || version != CACHE_VERSION) return null

        val entityType = entityTypeStr ?: return null
        val remainder = parts.drop(3)

        val isListKey = remainder.any { it.startsWith("list") || it.startsWith("p") }
        val isQueryKey = remainder.any { it.startsWith("query") }
        val isGeoKey = remainder.any { it.startsWith("geo") || it.startsWith("lat") }

        val entityId = if (!isListKey && !isQueryKey && remainder.isNotEmpty()) {
            remainder.firstOrNull()
        } else null

        val variant = remainder.getOrNull(1)

        return CacheKeyInfo(
            entityType = entityType,
            entityId = entityId,
            variant = variant,
            isListKey = isListKey,
            isQueryKey = isQueryKey,
            isGeoKey = isGeoKey
        )
    }

    // =========================================================================
    // Cache Strategy Methods
    // =========================================================================

    /**
     * Get TTL (time-to-live) for an entity type in seconds.
     */
    fun getCacheTTL(entityType: EntityType): Double {
        return entityTTLs[entityType] ?: 300.0  // Default 5 min
    }

    /**
     * Check if cached data is still fresh.
     */
    fun isCacheFresh(cachedAt: Long, entityType: EntityType): Boolean {
        val ttl = getCacheTTL(entityType)
        val now = System.currentTimeMillis() / 1000.0
        val cachedAtSeconds = cachedAt / 1000.0
        return (now - cachedAtSeconds) < ttl
    }

    /**
     * Generate a consistent cache key for an entity.
     */
    fun generateCacheKey(entityType: EntityType, entityId: String): String? {
        return generateEntityKey(entityType, entityId)
    }

    /**
     * Get cache strategy for an entity type.
     * Returns JSON with strategy details like {"type": "timeToLive", "ttl": 300}
     */
    fun getCacheStrategy(entityType: EntityType): String? {
        val ttl = getCacheTTL(entityType)
        val stale = getStaleThreshold(entityType)
        return """{"type":"timeToLive","ttl":$ttl,"staleThreshold":$stale}"""
    }

    /**
     * Get freshness state for cached data.
     * Returns one of: "fresh", "stale", "expired", "unknown"
     */
    fun getFreshnessState(cachedAt: Long, entityType: EntityType): String {
        val ttl = getCacheTTL(entityType)
        val staleThreshold = getStaleThreshold(entityType)
        val now = System.currentTimeMillis() / 1000.0
        val cachedAtSeconds = cachedAt / 1000.0
        val age = now - cachedAtSeconds

        return when {
            age < 0 -> "unknown"
            age < staleThreshold -> "fresh"
            age < ttl -> "stale"
            else -> "expired"
        }
    }

    /**
     * Get stale threshold for an entity type in seconds.
     */
    fun getStaleThreshold(entityType: EntityType): Double {
        val ttl = getCacheTTL(entityType)
        return ttl * staleThresholdRatio
    }

    /**
     * Check if cached data should be revalidated.
     */
    fun shouldRevalidate(
        cachedAt: Long,
        entityType: EntityType,
        userFocused: Boolean = false
    ): Boolean {
        val state = getFreshnessState(cachedAt, entityType)
        return when {
            state == "expired" -> true
            state == "stale" -> true
            userFocused && state == "fresh" -> {
                // For user-focused content, revalidate more aggressively
                val freshness = getFreshnessScore(cachedAt, entityType)
                freshness < 0.5
            }
            else -> false
        }
    }

    /**
     * Get freshness score (0.0 = expired, 1.0 = fresh).
     */
    fun getFreshnessScore(cachedAt: Long, entityType: EntityType): Double {
        val ttl = getCacheTTL(entityType)
        val now = System.currentTimeMillis() / 1000.0
        val cachedAtSeconds = cachedAt / 1000.0
        val age = now - cachedAtSeconds

        return when {
            age < 0 -> 1.0
            age >= ttl -> 0.0
            else -> 1.0 - (age / ttl)
        }
    }

    /**
     * Get remaining TTL in seconds, or null if expired.
     */
    fun getRemainingTTL(cachedAt: Long, entityType: EntityType): Double? {
        val ttl = getCacheTTL(entityType)
        val now = System.currentTimeMillis() / 1000.0
        val cachedAtSeconds = cachedAt / 1000.0
        val remaining = ttl - (now - cachedAtSeconds)
        return if (remaining > 0) remaining else null
    }

    /**
     * Check if entity type should be prefetched.
     */
    fun shouldPrefetch(entityType: EntityType): Boolean {
        return prefetchPriorities.containsKey(entityType)
    }

    /**
     * Get prefetch priority for an entity type (0-100).
     */
    fun getPrefetchPriority(entityType: EntityType): Int {
        return prefetchPriorities[entityType] ?: 50
    }
}

// =============================================================================
// Data Models
// =============================================================================

/**
 * Represents a cache invalidation event.
 */
@Serializable
data class InvalidationEvent(
    val id: String,
    @SerialName("eventType") val eventType: String,
    @SerialName("entityType") val entityType: String,
    @SerialName("entityId") val entityId: String? = null,
    @SerialName("affectedKeys") val affectedKeys: List<String> = emptyList(),
    @SerialName("cascadeInvalidation") val cascadeInvalidation: Boolean = true,
    val timestamp: String,
    val metadata: Map<String, String> = emptyMap()
)

/**
 * Information parsed from a cache key.
 */
@Serializable
data class CacheKeyInfo(
    @SerialName("entityType") val entityType: String,
    @SerialName("entityId") val entityId: String? = null,
    val variant: String? = null,
    @SerialName("isListKey") val isListKey: Boolean = false,
    @SerialName("isQueryKey") val isQueryKey: Boolean = false,
    @SerialName("isGeoKey") val isGeoKey: Boolean = false
)

/**
 * Result of a cache invalidation operation.
 */
@Serializable
data class InvalidationResult(
    @SerialName("eventId") val eventId: String,
    @SerialName("keysInvalidated") val keysInvalidated: List<String> = emptyList(),
    @SerialName("keysMarkedStale") val keysMarkedStale: List<String> = emptyList(),
    @SerialName("cascadeCount") val cascadeCount: Int = 0,
    @SerialName("durationMs") val durationMs: Double = 0.0,
    val errors: List<String> = emptyList()
) {
    val success: Boolean get() = errors.isEmpty()
    val totalAffected: Int get() = keysInvalidated.size + keysMarkedStale.size
}

/**
 * Scope configuration for cache invalidation.
 */
data class InvalidationScope(
    val strategy: InvalidationStrategy = InvalidationStrategy.IMMEDIATE,
    val maxDepth: Int = 3,
    val includeRelated: Boolean = true,
    val includeAggregates: Boolean = true,
    val excludePatterns: List<String> = emptyList()
) {
    companion object {
        val DEFAULT = InvalidationScope()
        val MINIMAL = InvalidationScope(
            strategy = InvalidationStrategy.IMMEDIATE,
            maxDepth = 1,
            includeRelated = false,
            includeAggregates = false
        )
        val AGGRESSIVE = InvalidationScope(
            strategy = InvalidationStrategy.CASCADE,
            maxDepth = 5,
            includeRelated = true,
            includeAggregates = true
        )
        val SOFT = InvalidationScope(
            strategy = InvalidationStrategy.STALE_WHILE_REVALIDATE,
            maxDepth = 2,
            includeRelated = true,
            includeAggregates = true
        )
    }
}

/**
 * Strategy for cache invalidation.
 */
enum class InvalidationStrategy {
    IMMEDIATE,
    STALE_WHILE_REVALIDATE,
    BATCHED,
    SOFT,
    CASCADE
}

/**
 * State of a cache entry.
 */
enum class CacheEntryState {
    FRESH,
    STALE,
    REVALIDATING,
    EXPIRED,
    INVALIDATED
}

/**
 * Manager for coordinating cache invalidation.
 */
class CacheInvalidationManager {

    private val listeners = mutableListOf<CacheInvalidationListener>()
    private val pendingEvents = mutableListOf<InvalidationEvent>()

    /**
     * Adds a listener for invalidation events.
     */
    fun addListener(listener: CacheInvalidationListener) {
        listeners.add(listener)
    }

    /**
     * Removes a listener.
     */
    fun removeListener(listener: CacheInvalidationListener) {
        listeners.remove(listener)
    }

    /**
     * Processes an invalidation event.
     */
    fun processEvent(event: InvalidationEvent, scope: InvalidationScope = InvalidationScope.DEFAULT) {
        // Get patterns to invalidate based on event
        val patterns = getInvalidationPatterns(event)

        when (scope.strategy) {
            InvalidationStrategy.IMMEDIATE, InvalidationStrategy.CASCADE -> {
                listeners.forEach { it.onInvalidateKeys(patterns) }
            }
            InvalidationStrategy.STALE_WHILE_REVALIDATE, InvalidationStrategy.SOFT -> {
                listeners.forEach { it.onMarkStale(patterns) }
            }
            InvalidationStrategy.BATCHED -> {
                pendingEvents.add(event)
            }
        }
    }

    /**
     * Flushes pending batched events.
     */
    fun flushPending() {
        if (pendingEvents.isEmpty()) return

        val allPatterns = pendingEvents.flatMap { getInvalidationPatterns(it) }.distinct()
        listeners.forEach { it.onInvalidateKeys(allPatterns) }
        pendingEvents.clear()
    }

    /**
     * Clears all cache.
     */
    fun clearAll() {
        listeners.forEach { it.onClearAll() }
    }

    private fun getInvalidationPatterns(event: InvalidationEvent): List<String> {
        val patterns = mutableListOf<String>()

        // Direct entity pattern
        event.entityId?.let { id ->
            CacheInvalidationBridge.EntityType.entries.find { it.value == event.entityType }?.let { type ->
                patterns.add(CacheInvalidationBridge.generatePattern(type, id))
            }
        }

        // Add affected keys
        patterns.addAll(event.affectedKeys)

        return patterns.distinct()
    }

    // Convenience methods for common invalidation scenarios

    fun onListingCreated(id: String, userId: String) {
        val event = CacheInvalidationBridge.createdEvent(
            CacheInvalidationBridge.EntityType.LISTING,
            id
        ) ?: return
        processEvent(event)
    }

    fun onListingUpdated(id: String) {
        val event = CacheInvalidationBridge.updatedEvent(
            CacheInvalidationBridge.EntityType.LISTING,
            id
        ) ?: return
        processEvent(event)
    }

    fun onListingDeleted(id: String) {
        val event = CacheInvalidationBridge.deletedEvent(
            CacheInvalidationBridge.EntityType.LISTING,
            id
        ) ?: return
        processEvent(event)
    }

    fun onMessageSent(roomId: String) {
        val event = CacheInvalidationBridge.updatedEvent(
            CacheInvalidationBridge.EntityType.CHAT_ROOM,
            roomId
        ) ?: return
        processEvent(event, InvalidationScope.SOFT)
    }

    fun onFavoriteToggled(listingId: String) {
        val event = CacheInvalidationBridge.updatedEvent(
            CacheInvalidationBridge.EntityType.FAVORITE,
            listingId
        ) ?: return
        processEvent(event, InvalidationScope.SOFT)
    }
}

/**
 * Listener for cache invalidation events.
 */
interface CacheInvalidationListener {
    fun onInvalidateKeys(keys: List<String>)
    fun onMarkStale(keys: List<String>)
    fun onClearAll()
}
