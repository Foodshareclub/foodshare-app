package com.foodshare.core.featureflags

import com.foodshare.swift.generated.FeatureFlagEngine as SwiftFeatureFlagEngine
import kotlinx.serialization.Serializable
import org.swift.swiftkit.core.SwiftArena
import java.time.Instant
import kotlin.math.abs

/**
 * Feature flag evaluation logic.
 *
 * Architecture (Frameo pattern):
 * - Swift engine for cross-platform consistent rollout bucketing
 * - SwiftArena for automatic memory management
 * - Platform-specific logic (date handling, caching) stays in Kotlin
 */
object FeatureFlagBridge {

    // SwiftArena for memory management (auto-releasing)
    private val arena: SwiftArena by lazy { SwiftArena.ofAuto() }

    // MARK: - Flag Evaluation

    /**
     * Evaluate a feature flag for the current user context.
     *
     * @param flag The feature flag to evaluate
     * @param context The user context for targeting
     * @return Evaluation result with detailed explanation
     */
    fun evaluateFlag(flag: FeatureFlag, context: UserContext): FlagEvaluationResult {
        // Check if flag is disabled globally
        if (!flag.isEnabled) {
            return FlagEvaluationResult(
                isEnabled = false,
                flagId = flag.id,
                reason = "disabled",
                explanation = "Flag is globally disabled"
            )
        }

        // Check explicit exclusions first
        if (context.userId in flag.excludeUserIds) {
            return FlagEvaluationResult(
                isEnabled = false,
                flagId = flag.id,
                reason = "excluded",
                explanation = "User is explicitly excluded"
            )
        }

        // Check explicit inclusions
        if (context.userId in flag.includeUserIds) {
            return FlagEvaluationResult(
                isEnabled = true,
                flagId = flag.id,
                reason = "included",
                explanation = "User is explicitly included"
            )
        }

        // Check platform targeting
        if (flag.platforms.isNotEmpty() && context.platform !in flag.platforms) {
            return FlagEvaluationResult(
                isEnabled = false,
                flagId = flag.id,
                reason = "platform",
                explanation = "Platform ${context.platform} not in target platforms"
            )
        }

        // Check environment
        if (flag.environment != null && flag.environment != context.environment) {
            return FlagEvaluationResult(
                isEnabled = false,
                flagId = flag.id,
                reason = "environment",
                explanation = "Environment mismatch"
            )
        }

        // Check version compatibility
        if (flag.minAppVersion != null || flag.maxAppVersion != null) {
            val versionCheck = checkVersionCompatibility(context.appVersion, flag.minAppVersion, flag.maxAppVersion)
            if (!versionCheck.isCompatible) {
                return FlagEvaluationResult(
                    isEnabled = false,
                    flagId = flag.id,
                    reason = "version",
                    explanation = versionCheck.message
                )
            }
        }

        // Check date range
        val now = Instant.now().toString()
        if (flag.startDate != null && now < flag.startDate) {
            return FlagEvaluationResult(
                isEnabled = false,
                flagId = flag.id,
                reason = "notStarted",
                explanation = "Flag not yet active (starts ${flag.startDate})"
            )
        }
        if (flag.endDate != null && now > flag.endDate) {
            return FlagEvaluationResult(
                isEnabled = false,
                flagId = flag.id,
                reason = "expired",
                explanation = "Flag has expired (ended ${flag.endDate})"
            )
        }

        // Check segment targeting
        if (flag.targetSegments.isNotEmpty()) {
            val matchesSegment = matchesAnySegment(context, flag.targetSegments)
            if (!matchesSegment) {
                return FlagEvaluationResult(
                    isEnabled = false,
                    flagId = flag.id,
                    reason = "segment",
                    explanation = "User not in target segments"
                )
            }
        }

        // Check rollout percentage
        if (flag.rolloutPercentage < 100) {
            val rollout = calculateRollout(context.userId, flag.rolloutPercentage, flag.id)
            if (!rollout.isIncluded) {
                return FlagEvaluationResult(
                    isEnabled = false,
                    flagId = flag.id,
                    reason = "rollout",
                    explanation = rollout.explanation
                )
            }
        }

        return FlagEvaluationResult(
            isEnabled = true,
            flagId = flag.id,
            reason = "enabled",
            explanation = "All conditions passed"
        )
    }

    /**
     * Quick check if a flag is enabled.
     */
    fun isEnabled(flag: FeatureFlag, context: UserContext): Boolean {
        return evaluateFlag(flag, context).isEnabled
    }

    /**
     * Evaluate multiple flags at once.
     */
    fun evaluateMultiple(
        flags: List<FeatureFlag>,
        context: UserContext
    ): Map<String, FlagEvaluationResult> {
        return flags.associate { flag ->
            flag.id to evaluateFlag(flag, context)
        }
    }

    /**
     * Get all enabled flags for a user.
     */
    fun getEnabledFlags(
        flags: List<FeatureFlag>,
        context: UserContext
    ): List<FeatureFlag> {
        return flags.filter { isEnabled(it, context) }
    }

    // MARK: - User Segments

    /**
     * Check if a user belongs to a specific segment.
     *
     * @param context User context
     * @param segmentId Segment identifier (e.g., "beta", "internal", "ios", "android")
     * @return Segment match result
     */
    fun checkUserSegment(context: UserContext, segmentId: String): SegmentMatchResult {
        val matches = when (segmentId.lowercase()) {
            "beta" -> context.isBetaTester
            "internal" -> context.isInternal
            "ios" -> context.platform.lowercase() == "ios"
            "android" -> context.platform.lowercase() == "android"
            "new_users" -> {
                // Users created in last 30 days
                val createdAt = context.accountCreatedAt
                if (createdAt != null) {
                    try {
                        val created = Instant.parse(createdAt)
                        val daysSinceCreation = java.time.Duration.between(created, Instant.now()).toDays()
                        daysSinceCreation <= 30
                    } catch (e: Exception) { false }
                } else false
            }
            "power_users" -> context.customAttributes["power_user"] == "true"
            else -> segmentId in context.segments
        }

        return SegmentMatchResult(
            matches = matches,
            segmentId = segmentId,
            explanation = if (matches) "User matches segment '$segmentId'" else "User not in segment '$segmentId'"
        )
    }

    /**
     * Check if user matches any of the given segments.
     */
    fun matchesAnySegment(context: UserContext, segments: Set<String>): Boolean {
        if (segments.isEmpty()) return true
        return segments.any { checkUserSegment(context, it).matches }
    }

    /**
     * Get all segments a user belongs to from a list of available segments.
     */
    fun getUserSegments(context: UserContext, availableSegments: List<String>): List<String> {
        return availableSegments.filter { checkUserSegment(context, it).matches }
    }

    // MARK: - Rollout Calculation (Swift Engine)

    /**
     * Calculate rollout bucket and inclusion for a user.
     * Uses Swift engine for cross-platform consistent hashing (djb2 algorithm).
     *
     * @param userId User identifier
     * @param percentage Rollout percentage (0-100)
     * @param flagId Optional flag ID for per-flag bucketing
     * @return Rollout result with bucket info
     */
    fun calculateRollout(
        userId: String,
        percentage: Int,
        flagId: String? = null
    ): RolloutResult {
        // Use Swift engine for cross-platform consistent bucketing
        val swiftResult = SwiftFeatureFlagEngine.calculateRollout(
            userId,
            percentage,
            flagId ?: "",
            arena
        )

        return RolloutResult(
            isIncluded = swiftResult.isIncluded,
            bucket = swiftResult.bucket,
            percentage = swiftResult.percentage,
            threshold = percentage,
            explanation = swiftResult.explanation
        )
    }

    /**
     * Get the user's rollout bucket for a flag.
     * Uses Swift engine for cross-platform consistency.
     */
    fun getRolloutBucket(userId: String, flagId: String? = null): Int {
        return SwiftFeatureFlagEngine.calculateRolloutBucket(userId, flagId ?: "")
    }

    // MARK: - Version Compatibility (Swift Engine)

    /**
     * Check version compatibility for a feature flag.
     * Uses Swift engine for cross-platform consistent version parsing.
     *
     * @param appVersion Current app version
     * @param minVersion Minimum required version (optional)
     * @param maxVersion Maximum allowed version (optional)
     * @return Version check result
     */
    fun checkVersionCompatibility(
        appVersion: String,
        minVersion: String? = null,
        maxVersion: String? = null
    ): VersionCheckResult {
        // Use Swift engine for cross-platform consistent version checking
        val swiftResult = SwiftFeatureFlagEngine.checkVersionCompatibility(
            appVersion,
            minVersion ?: "",
            maxVersion ?: "",
            arena
        )

        return VersionCheckResult(
            isCompatible = swiftResult.isCompatible,
            reason = swiftResult.reason,
            message = swiftResult.message,
            appVersion = appVersion,
            minVersion = minVersion,
            maxVersion = maxVersion
        )
    }

    // MARK: - Cache Management

    // Cache TTL configurations by preset (in seconds)
    private val cacheTTLs = mapOf(
        "default" to 3600.0,        // 1 hour
        "offlineFirst" to 86400.0,  // 24 hours
        "minimal" to 300.0          // 5 minutes
    )

    /**
     * Get cache statistics and stale flag IDs.
     *
     * @param cachedFlags Map of cached flag entries
     * @param configPreset Cache config preset ("default", "offlineFirst", "minimal")
     * @return Cache stats with stale flag IDs
     */
    fun getCacheStats(
        cachedFlags: Map<String, CachedFlag>,
        configPreset: String = "default"
    ): CacheStatsResult {
        if (cachedFlags.isEmpty()) {
            return CacheStatsResult(
                totalEntries = 0,
                freshEntries = 0,
                staleEntries = 0,
                averageAgeSeconds = 0.0,
                freshPercentage = 0.0,
                staleIds = emptyList(),
                needsRefreshIds = emptyList()
            )
        }

        val now = Instant.now()
        val ttl = cacheTTLs[configPreset] ?: cacheTTLs["default"]!!

        val staleIds = mutableListOf<String>()
        val needsRefreshIds = mutableListOf<String>()
        var totalAgeSeconds = 0.0
        var freshCount = 0

        cachedFlags.forEach { (id, cached) ->
            val cachedAt = try {
                Instant.parse(cached.cachedAt)
            } catch (e: Exception) {
                Instant.EPOCH
            }

            val ageSeconds = java.time.Duration.between(cachedAt, now).seconds.toDouble()
            totalAgeSeconds += ageSeconds

            val effectiveTTL = cached.ttlSeconds.coerceAtMost(ttl)
            if (ageSeconds > effectiveTTL) {
                staleIds.add(id)
            } else {
                freshCount++
            }

            // Mark for refresh at 80% of TTL
            if (ageSeconds > effectiveTTL * 0.8) {
                needsRefreshIds.add(id)
            }
        }

        val totalEntries = cachedFlags.size
        return CacheStatsResult(
            totalEntries = totalEntries,
            freshEntries = freshCount,
            staleEntries = staleIds.size,
            averageAgeSeconds = totalAgeSeconds / totalEntries,
            freshPercentage = (freshCount.toDouble() / totalEntries) * 100,
            staleIds = staleIds,
            needsRefreshIds = needsRefreshIds
        )
    }

    /**
     * Get flag IDs that need refreshing from cache.
     */
    fun getFlagsNeedingRefresh(
        cachedFlags: Map<String, CachedFlag>,
        configPreset: String = "default"
    ): List<String> {
        return getCacheStats(cachedFlags, configPreset).needsRefreshIds
    }
}

// MARK: - Data Models

@Serializable
data class FeatureFlag(
    val id: String,
    val name: String,
    val description: String? = null,
    val isEnabled: Boolean = true,
    val rolloutPercentage: Int = 100,
    val minAppVersion: String? = null,
    val maxAppVersion: String? = null,
    val platforms: Set<String> = emptySet(),
    val targetSegments: Set<String> = emptySet(),
    val includeUserIds: Set<String> = emptySet(),
    val excludeUserIds: Set<String> = emptySet(),
    val environment: String? = null,
    val startDate: String? = null, // ISO8601 date string
    val endDate: String? = null,   // ISO8601 date string
    val metadata: Map<String, String> = emptyMap(),
    val updatedAt: String? = null  // ISO8601 date string
)

@Serializable
data class UserContext(
    val userId: String,
    val email: String? = null,
    val segments: Set<String> = emptySet(),
    val appVersion: String,
    val platform: String,
    val environment: String = "production",
    val countryCode: String? = null,
    val languageCode: String? = null,
    val isBetaTester: Boolean = false,
    val isInternal: Boolean = false,
    val accountCreatedAt: String? = null, // ISO8601 date string
    val customAttributes: Map<String, String> = emptyMap()
)

@Serializable
data class FlagEvaluationResult(
    val isEnabled: Boolean,
    val flagId: String,
    val reason: String,
    val explanation: String,
    val fromCache: Boolean = false
)

@Serializable
data class SegmentMatchResult(
    val matches: Boolean,
    val segmentId: String,
    val explanation: String
)

@Serializable
data class RolloutResult(
    val isIncluded: Boolean,
    val bucket: Int,
    val percentage: Int,
    val threshold: Int = 0,
    val explanation: String
)

@Serializable
data class VersionCheckResult(
    val isCompatible: Boolean,
    val reason: String,
    val message: String,
    val appVersion: String,
    val minVersion: String? = null,
    val maxVersion: String? = null
)

@Serializable
data class CachedFlag(
    val flag: FeatureFlag,
    val cachedAt: String, // ISO8601 date string
    val ttlSeconds: Double = 3600.0
)

@Serializable
data class CacheStatsResult(
    val totalEntries: Int,
    val freshEntries: Int,
    val staleEntries: Int,
    val averageAgeSeconds: Double,
    val freshPercentage: Double,
    val staleIds: List<String>,
    val needsRefreshIds: List<String>,
    val error: String? = null
)

// =============================================================================
// MARK: - A/B Testing / Experiments
// =============================================================================

/**
 * Experiment/A/B testing infrastructure.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for experiment assignment
 * - Weighted selection, targeting, exposure logging are pure functions
 * - No JNI required for these stateless operations
 */
object ExperimentBridge {

    // SwiftArena for memory management (auto-releasing)
    private val arena: SwiftArena by lazy { SwiftArena.ofAuto() }

    // ========================================================================
    // Variant Assignment
    // ========================================================================

    /**
     * Get experiment variant for a user.
     *
     * @param experiment The experiment definition
     * @param userId User identifier for assignment
     * @param overrides Optional variant overrides map
     * @return Assigned variant
     */
    fun getVariant(
        experiment: Experiment,
        userId: String,
        overrides: Map<String, String> = emptyMap()
    ): ExperimentVariant {
        // Check for override first
        val overrideVariantId = overrides[experiment.id]
        if (overrideVariantId != null) {
            return experiment.variants.find { it.id == overrideVariantId }
                ?: experiment.controlVariant
        }

        // Check if experiment is active
        if (!experiment.isActive) {
            return experiment.controlVariant
        }

        // Check date range
        val now = System.currentTimeMillis()
        if (experiment.startDate != null && now < experiment.startDate) {
            return experiment.controlVariant
        }
        if (experiment.endDate != null && now > experiment.endDate) {
            return experiment.controlVariant
        }

        // Check targeting
        if (!evaluateTargeting(experiment.targeting, userId)) {
            return experiment.controlVariant
        }

        // Weighted selection using consistent hashing
        val seed = "$userId:${experiment.id}:${experiment.salt}"
        return weightedSelect(experiment.variants, seed)
    }

    /**
     * Get multiple experiment assignments at once.
     *
     * @param experiments List of experiments
     * @param userId User identifier
     * @param overrides Optional variant overrides
     * @return Assignments with exposure events
     */
    fun getAssignments(
        experiments: List<Experiment>,
        userId: String,
        overrides: Map<String, String> = emptyMap()
    ): ExperimentAssignments {
        val assignments = experiments.associate { experiment ->
            experiment.id to getVariant(experiment, userId, overrides)
        }

        val exposures = assignments.map { (experimentId, variant) ->
            ExperimentExposure(
                experimentId = experimentId,
                variantId = variant.id,
                userId = userId,
                timestamp = System.currentTimeMillis()
            )
        }

        return ExperimentAssignments(assignments, exposures)
    }

    /**
     * Quick check if user is in a specific variant.
     */
    fun isInVariant(
        experiment: Experiment,
        userId: String,
        variantId: String
    ): Boolean {
        return getVariant(experiment, userId).id == variantId
    }

    /**
     * Get config value for a user's assigned variant.
     */
    fun getConfigValue(
        experiment: Experiment,
        userId: String,
        configKey: String
    ): String? {
        return getVariant(experiment, userId).config[configKey]
    }

    // ========================================================================
    // Exposure Logging
    // ========================================================================

    /**
     * Create an exposure event for tracking.
     *
     * @param experimentId Experiment identifier
     * @param variantId Assigned variant identifier
     * @param userId User identifier
     * @param context Additional context
     * @return Exposure event
     */
    fun createExposure(
        experimentId: String,
        variantId: String,
        userId: String,
        context: Map<String, String> = emptyMap()
    ): ExperimentExposure {
        return ExperimentExposure(
            experimentId = experimentId,
            variantId = variantId,
            userId = userId,
            context = context.ifEmpty { null },
            timestamp = System.currentTimeMillis()
        )
    }

    /**
     * Check if exposure should be logged (deduplication).
     *
     * @param exposure New exposure
     * @param recentExposures Recent exposures for deduplication
     * @param dedupeWindowSeconds Time window for deduplication
     * @return true if exposure should be logged
     */
    fun shouldLogExposure(
        exposure: ExperimentExposure,
        recentExposures: List<ExperimentExposure>,
        dedupeWindowSeconds: Int = 3600
    ): Boolean {
        val windowMs = dedupeWindowSeconds * 1000L
        val cutoff = System.currentTimeMillis() - windowMs

        // Check for duplicate in recent window
        return recentExposures.none { recent ->
            recent.experimentId == exposure.experimentId &&
            recent.variantId == exposure.variantId &&
            recent.userId == exposure.userId &&
            recent.timestamp >= cutoff
        }
    }

    // ========================================================================
    // Targeting Evaluation
    // ========================================================================

    /**
     * Evaluate experiment targeting.
     *
     * @param targeting Targeting configuration
     * @param userId User identifier
     * @param userAttributes User attributes for targeting
     * @return true if user matches targeting
     */
    fun evaluateTargeting(
        targeting: ExperimentTargeting?,
        userId: String,
        userAttributes: Map<String, String> = emptyMap()
    ): Boolean {
        if (targeting == null) return true

        // Check excluded users
        if (targeting.excludedUserIds?.contains(userId) == true) {
            return false
        }

        // Check included users (overrides percentage)
        if (targeting.includedUserIds?.contains(userId) == true) {
            return true
        }

        // Check percentage targeting
        if (targeting.userPercentage != null && targeting.userPercentage < 100.0) {
            val bucket = abs(userId.hashCode()) % 100
            if (bucket >= targeting.userPercentage) {
                return false
            }
        }

        // Check attribute rules
        targeting.attributeRules?.forEach { rule ->
            val attributeValue = userAttributes[rule.attribute]
            val matches = evaluateRule(attributeValue, rule)
            if (rule.required && !matches) {
                return false
            }
        }

        return true
    }

    /**
     * Evaluate a single attribute rule.
     */
    private fun evaluateRule(attributeValue: String?, rule: AttributeRule): Boolean {
        if (attributeValue == null) return false

        return when (rule.operator) {
            RuleOperator.EQUALS -> attributeValue == rule.value
            RuleOperator.NOT_EQUALS -> attributeValue != rule.value
            RuleOperator.CONTAINS -> attributeValue.contains(rule.value)
            RuleOperator.STARTS_WITH -> attributeValue.startsWith(rule.value)
            RuleOperator.ENDS_WITH -> attributeValue.endsWith(rule.value)
            RuleOperator.GREATER_THAN -> {
                val attrNum = attributeValue.toDoubleOrNull()
                val ruleNum = rule.value.toDoubleOrNull()
                if (attrNum != null && ruleNum != null) attrNum > ruleNum else false
            }
            RuleOperator.LESS_THAN -> {
                val attrNum = attributeValue.toDoubleOrNull()
                val ruleNum = rule.value.toDoubleOrNull()
                if (attrNum != null && ruleNum != null) attrNum < ruleNum else false
            }
            RuleOperator.IN_LIST -> {
                val listValues = rule.value.split(",").map { it.trim() }
                attributeValue in listValues
            }
        }
    }

    // ========================================================================
    // Advanced Selection (Swift Engine)
    // ========================================================================

    /**
     * Weighted variant selection.
     * Uses Swift engine for cross-platform consistent deterministic bucketing.
     *
     * @param variants Available variants with weights
     * @param seed Selection seed for determinism (format: "userId:experimentId:salt")
     * @return Selected variant
     */
    fun weightedSelect(
        variants: List<ExperimentVariant>,
        seed: String
    ): ExperimentVariant {
        if (variants.isEmpty()) {
            return ExperimentVariant(id = "control", name = "Control", weight = 100.0)
        }

        if (variants.size == 1) {
            return variants.first()
        }

        // Parse seed into components (userId:experimentId:salt)
        val parts = seed.split(":")
        val userId = parts.getOrElse(0) { "" }
        val experimentId = parts.getOrElse(1) { "" }
        val salt = parts.getOrElse(2) { "" }

        // Prepare weights as comma-separated string
        val weightsStr = variants.joinToString(",") { it.weight.toString() }

        // Use Swift engine for cross-platform consistent selection
        val swiftResult = SwiftFeatureFlagEngine.weightedSelect(
            userId,
            experimentId,
            salt,
            weightsStr,
            arena
        )

        val selectedIndex = swiftResult.variantIndex.coerceIn(0, variants.lastIndex)
        return variants[selectedIndex]
    }

    /**
     * Multi-armed bandit selection (epsilon-greedy).
     *
     * @param variants Available variants
     * @param conversionRates Conversion rates per variant
     * @param epsilon Exploration probability (default 0.1)
     * @param seed Selection seed
     * @return Selected variant
     */
    fun banditSelect(
        variants: List<ExperimentVariant>,
        conversionRates: Map<String, Double>,
        epsilon: Double = 0.1,
        seed: String
    ): ExperimentVariant {
        if (variants.isEmpty()) {
            return ExperimentVariant(id = "control", name = "Control", weight = 100.0)
        }

        val hash = abs(seed.hashCode())
        val random = (hash % 1000) / 1000.0

        // Explore: random selection
        if (random < epsilon) {
            val index = hash % variants.size
            return variants[index]
        }

        // Exploit: select best performing variant
        val bestVariant = variants.maxByOrNull { variant ->
            conversionRates[variant.id] ?: 0.0
        }

        return bestVariant ?: variants.first()
    }
}

// =============================================================================
// MARK: - Experiment Data Models
// =============================================================================

@Serializable
data class Experiment(
    val id: String,
    val name: String,
    val description: String? = null,
    val variants: List<ExperimentVariant>,
    val targeting: ExperimentTargeting? = null,
    val salt: String = "",
    val isActive: Boolean = true,
    val startDate: Long? = null,
    val endDate: Long? = null
) {
    val controlVariant: ExperimentVariant
        get() = variants.firstOrNull { it.id == "control" } ?: variants.first()
}

@Serializable
data class ExperimentVariant(
    val id: String,
    val name: String,
    val weight: Double,
    val config: Map<String, String> = emptyMap()
) {
    fun configValue(key: String): String? = config[key]
    fun configBool(key: String): Boolean = config[key]?.lowercase() == "true"
    fun configInt(key: String): Int? = config[key]?.toIntOrNull()
    fun configDouble(key: String): Double? = config[key]?.toDoubleOrNull()
}

@Serializable
data class ExperimentTargeting(
    val userPercentage: Double? = null,
    val includedUserIds: List<String>? = null,
    val excludedUserIds: List<String>? = null,
    val attributeRules: List<AttributeRule>? = null
)

@Serializable
data class AttributeRule(
    val attribute: String,
    val operator: RuleOperator,
    val value: String,
    val required: Boolean = false
)

@Serializable
enum class RuleOperator {
    @kotlinx.serialization.SerialName("eq") EQUALS,
    @kotlinx.serialization.SerialName("neq") NOT_EQUALS,
    @kotlinx.serialization.SerialName("contains") CONTAINS,
    @kotlinx.serialization.SerialName("starts_with") STARTS_WITH,
    @kotlinx.serialization.SerialName("ends_with") ENDS_WITH,
    @kotlinx.serialization.SerialName("gt") GREATER_THAN,
    @kotlinx.serialization.SerialName("lt") LESS_THAN,
    @kotlinx.serialization.SerialName("in") IN_LIST
}

@Serializable
data class ExperimentExposure(
    val experimentId: String,
    val variantId: String,
    val userId: String? = null,
    val context: Map<String, String>? = null,
    val timestamp: Long = System.currentTimeMillis()
)

@Serializable
data class ExperimentAssignments(
    val assignments: Map<String, ExperimentVariant>,
    val exposures: List<ExperimentExposure>
) {
    fun variant(experimentId: String): ExperimentVariant? = assignments[experimentId]
    fun isInVariant(experimentId: String, variantId: String): Boolean =
        assignments[experimentId]?.id == variantId
    fun configValue(experimentId: String, key: String): String? =
        assignments[experimentId]?.config?.get(key)
}
