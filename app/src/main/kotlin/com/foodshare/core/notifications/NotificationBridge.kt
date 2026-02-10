package com.foodshare.core.notifications

import kotlinx.serialization.Serializable
import java.time.DayOfWeek
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Notification scheduling logic.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for notification scheduling
 * - Quiet hours, priority calculation, consolidation are pure functions
 * - No JNI required for these stateless operations
 */
object NotificationBridge {

    // ========================================================================
    // Quiet Hours
    // ========================================================================

    /**
     * Check if current time is within quiet hours.
     *
     * @param config Quiet hours configuration (null for default)
     * @param currentTimestamp Current time as Unix timestamp (0 for now)
     * @return Quiet hours evaluation result
     */
    fun isInQuietHours(
        config: QuietHoursConfig? = null,
        currentTimestamp: Double = 0.0
    ): QuietHoursResult {
        val cfg = config ?: QuietHoursConfig()
        if (!cfg.enabled) {
            return QuietHoursResult(isInQuietHours = false)
        }

        val now = if (currentTimestamp > 0) {
            LocalDateTime.ofInstant(
                java.time.Instant.ofEpochMilli((currentTimestamp * 1000).toLong()),
                ZoneId.systemDefault()
            )
        } else {
            LocalDateTime.now()
        }

        val currentHour = now.hour
        val currentMinute = now.minute
        val currentDay = now.dayOfWeek.value

        // Check if it's a quiet day
        val isQuietDay = currentDay in cfg.quietDays

        // Check time range (handles overnight periods)
        val currentTimeMinutes = currentHour * 60 + currentMinute
        val startTimeMinutes = cfg.startHour * 60 + cfg.startMinute
        val endTimeMinutes = cfg.endHour * 60 + cfg.endMinute

        val isInTimeRange = if (startTimeMinutes <= endTimeMinutes) {
            // Same day quiet hours (e.g., 14:00 - 16:00)
            currentTimeMinutes in startTimeMinutes until endTimeMinutes
        } else {
            // Overnight quiet hours (e.g., 22:00 - 07:00)
            currentTimeMinutes >= startTimeMinutes || currentTimeMinutes < endTimeMinutes
        }

        val isInQuietHours = isInTimeRange || isQuietDay

        // Calculate delay until quiet hours end
        val delayMs = if (isInQuietHours && !isQuietDay) {
            val minutesUntilEnd = if (currentTimeMinutes < endTimeMinutes) {
                endTimeMinutes - currentTimeMinutes
            } else {
                (24 * 60 - currentTimeMinutes) + endTimeMinutes
            }
            minutesUntilEnd * 60 * 1000.0
        } else 0.0

        return QuietHoursResult(
            isInQuietHours = isInQuietHours,
            isQuietDay = isQuietDay,
            delayMs = delayMs
        )
    }

    /**
     * Evaluate quiet hours for a specific notification.
     */
    fun evaluateQuietHours(
        config: QuietHoursConfig? = null,
        notification: NotificationRequest,
        currentTimestamp: Double = 0.0
    ): QuietHoursEvaluation {
        val result = isInQuietHours(config, currentTimestamp)
        val cfg = config ?: QuietHoursConfig()

        if (!result.isInQuietHours) {
            return QuietHoursEvaluation(shouldDelay = false, reason = "notInQuietHours")
        }

        // Check if category is allowed during quiet hours
        if (notification.category in cfg.allowedCategoriesDuringQuiet) {
            return QuietHoursEvaluation(
                shouldDelay = false,
                reason = "allowedCategory",
                canOverride = true
            )
        }

        // Check if urgent override is allowed
        if (cfg.allowUrgentOverride && (notification.isUrgent ||
            notification.priority == NotificationPriority.URGENT ||
            notification.priority == NotificationPriority.CRITICAL)) {
            return QuietHoursEvaluation(
                shouldDelay = false,
                reason = "urgentOverride",
                canOverride = true
            )
        }

        val nowMs = if (currentTimestamp > 0) currentTimestamp * 1000 else System.currentTimeMillis().toDouble()
        return QuietHoursEvaluation(
            shouldDelay = true,
            reason = "inQuietHours",
            delayUntilTimestamp = (nowMs + result.delayMs) / 1000,
            canOverride = false
        )
    }

    // ========================================================================
    // Priority Calculation
    // ========================================================================

    // Priority weights by config preset
    private val priorityWeights = mapOf(
        "default" to mapOf(
            "base" to 1.0,
            "urgency" to 0.3,
            "category" to 0.2,
            "engagement" to 0.2,
            "timing" to 0.1
        ),
        "foodSharing" to mapOf(
            "base" to 1.0,
            "urgency" to 0.4,
            "category" to 0.3,
            "engagement" to 0.15,
            "timing" to 0.15
        )
    )

    // Category priority boosts
    private val categoryBoosts = mapOf(
        "safety" to 0.5,
        "security" to 0.5,
        "arrangement" to 0.3,
        "message" to 0.2,
        "listing" to 0.1,
        "promotion" to -0.1
    )

    /**
     * Calculate notification priority.
     */
    fun calculatePriority(
        notification: NotificationRequest,
        context: NotificationContext? = null,
        configPreset: String = "default"
    ): PriorityResult {
        val weights = priorityWeights[configPreset] ?: priorityWeights["default"]!!
        val factors = mutableMapOf<String, Double>()
        val adjustments = mutableListOf<String>()

        // Base priority score
        val basePriorityScore = when (notification.priority) {
            NotificationPriority.LOW -> 0.2
            NotificationPriority.NORMAL -> 0.5
            NotificationPriority.HIGH -> 0.7
            NotificationPriority.URGENT -> 0.9
            NotificationPriority.CRITICAL -> 1.0
        }
        factors["base"] = basePriorityScore

        // Urgency factor
        val urgencyFactor = if (notification.isUrgent) 0.3 else 0.0
        factors["urgency"] = urgencyFactor
        if (notification.isUrgent) adjustments.add("urgency_boost")

        // Category boost
        val categoryBoost = categoryBoosts[notification.category] ?: 0.0
        factors["category"] = 0.5 + categoryBoost
        if (categoryBoost != 0.0) adjustments.add("category_${notification.category}")

        // Engagement factor
        val engagementFactor = context?.categoryEngagement?.get(notification.category) ?: 0.5
        factors["engagement"] = engagementFactor

        // Timing factor
        val timingFactor = context?.timeOfDayPreference ?: 1.0
        factors["timing"] = timingFactor

        // Calculate weighted score
        var totalScore = 0.0
        factors.forEach { (key, value) ->
            val weight = weights[key] ?: 0.0
            totalScore += value * weight
        }

        // Clamp to 0-1
        totalScore = totalScore.coerceIn(0.0, 1.0)

        // Determine calculated priority
        val calculatedPriority = when {
            totalScore >= 0.9 -> "critical"
            totalScore >= 0.7 -> "urgent"
            totalScore >= 0.5 -> "high"
            totalScore >= 0.3 -> "normal"
            else -> "low"
        }

        val originalPriority = notification.priority.name.lowercase()
        return PriorityResult(
            originalPriority = originalPriority,
            calculatedPriority = calculatedPriority,
            score = totalScore,
            wasElevated = calculatedPriority > originalPriority,
            wasReduced = calculatedPriority < originalPriority,
            factors = factors,
            adjustments = adjustments
        )
    }

    // ========================================================================
    // Consolidation
    // ========================================================================

    // Consolidation thresholds by preset
    private val consolidationThresholds = mapOf(
        "default" to 3,
        "aggressive" to 2,
        "conservative" to 5
    )

    /**
     * Check if a notification should be consolidated with existing ones.
     */
    fun shouldConsolidate(
        notification: NotificationRequest,
        existingNotifications: List<NotificationRequest> = emptyList(),
        configPreset: String = "default"
    ): ConsolidationDecision {
        if (existingNotifications.isEmpty()) {
            return ConsolidationDecision(shouldConsolidate = false, reason = "noExisting")
        }

        // Don't consolidate urgent/critical notifications
        if (notification.priority == NotificationPriority.URGENT ||
            notification.priority == NotificationPriority.CRITICAL ||
            notification.isUrgent) {
            return ConsolidationDecision(shouldConsolidate = false, reason = "highPriority")
        }

        // Find similar notifications by category
        val similarNotifications = existingNotifications.filter { existing ->
            existing.category == notification.category &&
            existing.priority != NotificationPriority.URGENT &&
            existing.priority != NotificationPriority.CRITICAL
        }

        val threshold = consolidationThresholds[configPreset] ?: consolidationThresholds["default"]!!
        val shouldConsolidate = similarNotifications.size >= threshold

        return ConsolidationDecision(
            shouldConsolidate = shouldConsolidate,
            reason = if (shouldConsolidate) "thresholdReached" else "belowThreshold",
            groupKey = if (shouldConsolidate) "group_${notification.category}" else null,
            existingCount = similarNotifications.size
        )
    }

    // ========================================================================
    // Delivery Optimization
    // ========================================================================

    /**
     * Get optimal delivery time for a notification.
     */
    fun getOptimalDeliveryTime(
        notification: NotificationRequest,
        preferences: EngagementPreferences? = null,
        constraintsPreset: String = "default"
    ): DeliveryTimeResult {
        val nowSeconds = System.currentTimeMillis() / 1000.0

        // High priority notifications deliver immediately
        if (notification.priority == NotificationPriority.URGENT ||
            notification.priority == NotificationPriority.CRITICAL ||
            notification.isUrgent ||
            constraintsPreset == "immediate") {
            return DeliveryTimeResult(
                recommendedTimestamp = nowSeconds,
                reason = "immediate",
                confidence = 1.0,
                isImmediate = true
            )
        }

        // If no preferences, deliver now
        if (preferences == null || preferences.hourlyEngagement.isEmpty()) {
            return DeliveryTimeResult(
                recommendedTimestamp = nowSeconds,
                reason = "noPreferences",
                confidence = 0.5,
                isImmediate = true
            )
        }

        // Find best hour based on engagement
        val now = LocalDateTime.now()
        val currentHour = now.hour

        // Look for best time in next 24 hours
        var bestHour = currentHour
        var bestEngagement = preferences.hourlyEngagement[currentHour] ?: 0.5

        for (offset in 1..23) {
            val hour = (currentHour + offset) % 24
            val engagement = preferences.hourlyEngagement[hour] ?: 0.5
            if (engagement > bestEngagement) {
                bestEngagement = engagement
                bestHour = hour
            }
        }

        // If current hour is good enough, deliver now
        val currentEngagement = preferences.hourlyEngagement[currentHour] ?: 0.5
        if (currentEngagement >= bestEngagement * 0.8) {
            return DeliveryTimeResult(
                recommendedTimestamp = nowSeconds,
                reason = "currentTimeGood",
                confidence = currentEngagement,
                isImmediate = true
            )
        }

        // Calculate delay to best hour
        val hoursUntilBest = if (bestHour > currentHour) {
            bestHour - currentHour
        } else {
            24 - currentHour + bestHour
        }
        val delaySeconds = hoursUntilBest * 3600.0

        return DeliveryTimeResult(
            recommendedTimestamp = nowSeconds + delaySeconds,
            reason = "optimalTime",
            confidence = bestEngagement,
            isImmediate = false,
            delaySeconds = delaySeconds
        )
    }

    // ========================================================================
    // Validation
    // ========================================================================

    /**
     * Validate notification content before sending.
     */
    fun validateNotificationContent(notification: NotificationRequest): ContentValidationResult {
        val errors = mutableListOf<String>()
        val warnings = mutableListOf<String>()

        // Validate ID
        if (notification.id.isBlank()) {
            errors.add("Notification ID is required")
        }

        // Validate title
        if (notification.title.isBlank()) {
            errors.add("Notification title is required")
        } else if (notification.title.length > 100) {
            warnings.add("Title exceeds recommended length of 100 characters")
        }

        // Validate body
        if (notification.body.isBlank()) {
            errors.add("Notification body is required")
        } else if (notification.body.length > 500) {
            warnings.add("Body exceeds recommended length of 500 characters")
        }

        // Validate category
        if (notification.category.isBlank()) {
            errors.add("Notification category is required")
        }

        return ContentValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            warnings = warnings,
            hasWarnings = warnings.isNotEmpty()
        )
    }

    // ========================================================================
    // Full Scheduling
    // ========================================================================

    /**
     * Schedule a notification with full optimization.
     */
    fun scheduleNotification(
        notification: NotificationRequest,
        settings: NotificationSettings? = null,
        pendingNotifications: List<NotificationRequest> = emptyList()
    ): SchedulingDecision {
        // Validate first
        val validation = validateNotificationContent(notification)
        if (!validation.isValid) {
            return SchedulingDecision(
                action = "discard",
                reason = "Invalid notification: ${validation.errors.firstOrNull()}"
            )
        }

        val cfg = settings ?: NotificationSettings()

        // Check quiet hours
        val quietResult = evaluateQuietHours(cfg.quietHoursConfig, notification)
        if (quietResult.shouldDelay) {
            return SchedulingDecision(
                action = "schedule",
                reason = "Quiet hours - delayed until ${quietResult.delayUntilTimestamp}",
                scheduledTimestamp = quietResult.delayUntilTimestamp
            )
        }

        // Check consolidation
        val consolidationResult = shouldConsolidate(
            notification,
            pendingNotifications,
            cfg.consolidationConfigPreset
        )
        if (consolidationResult.shouldConsolidate) {
            return SchedulingDecision(
                action = "consolidate",
                reason = "Consolidated with ${consolidationResult.existingCount} similar notifications",
                consolidationInfo = ConsolidationInfo(
                    groupKey = consolidationResult.groupKey ?: "default",
                    existingCount = consolidationResult.existingCount
                )
            )
        }

        // Get optimal delivery time
        val deliveryResult = getOptimalDeliveryTime(
            notification,
            constraintsPreset = cfg.deliveryConstraintsPreset
        )

        return if (deliveryResult.isImmediate) {
            SchedulingDecision(action = "deliverNow", reason = deliveryResult.reason)
        } else {
            SchedulingDecision(
                action = "schedule",
                reason = deliveryResult.reason,
                scheduledTimestamp = deliveryResult.recommendedTimestamp
            )
        }
    }
}

// ========================================================================
// Data Models
// ========================================================================

@Serializable
data class NotificationRequest(
    val id: String,
    val category: String,
    val title: String,
    val body: String,
    val priority: NotificationPriority = NotificationPriority.NORMAL,
    val isUrgent: Boolean = false,
    val timeSensitivity: String? = null,
    val relatedEntityId: String? = null,
    val createdAt: String? = null,  // ISO8601
    val expiresAt: String? = null,   // ISO8601
    val data: Map<String, String> = emptyMap()
)

@Serializable
enum class NotificationPriority {
    LOW, NORMAL, HIGH, URGENT, CRITICAL
}

@Serializable
data class QuietHoursConfig(
    val enabled: Boolean = true,
    val startHour: Int = 22,
    val startMinute: Int = 0,
    val endHour: Int = 7,
    val endMinute: Int = 0,
    val quietDays: Set<Int> = emptySet(),
    val allowedCategoriesDuringQuiet: Set<String> = setOf("safety", "security"),
    val allowUrgentOverride: Boolean = true
)

@Serializable
data class QuietHoursResult(
    val isInQuietHours: Boolean,
    val isQuietDay: Boolean = false,
    val endTimestamp: Double = 0.0,
    val delayMs: Double = 0.0,
    val error: String? = null
)

@Serializable
data class QuietHoursEvaluation(
    val shouldDelay: Boolean,
    val reason: String,
    val delayUntilTimestamp: Double? = null,
    val canOverride: Boolean = false,
    val error: String? = null
)

@Serializable
data class NotificationContext(
    val isActivelyUsingApp: Boolean = false,
    val categoryEngagement: Map<String, Double> = emptyMap(),
    val timeOfDayPreference: Double = 1.0,
    val focusMode: String? = null
)

@Serializable
data class PriorityResult(
    val originalPriority: String,
    val calculatedPriority: String,
    val score: Double,
    val wasElevated: Boolean = false,
    val wasReduced: Boolean = false,
    val factors: Map<String, Double> = emptyMap(),
    val adjustments: List<String> = emptyList(),
    val error: String? = null
)

@Serializable
data class ConsolidationDecision(
    val shouldConsolidate: Boolean,
    val reason: String,
    val groupKey: String? = null,
    val existingCount: Int = 0,
    val error: String? = null
)

@Serializable
data class EngagementPreferences(
    val hourlyEngagement: Map<Int, Double> = emptyMap(),
    val preferredDays: Set<Int> = setOf(2, 3, 4, 5, 6),
    val averageResponseTime: Double = 300.0
)

@Serializable
data class DeliveryTimeResult(
    val recommendedTimestamp: Double,
    val reason: String,
    val confidence: Double,
    val isImmediate: Boolean = false,
    val delaySeconds: Double = 0.0,
    val alternativeTimestamps: List<Double> = emptyList(),
    val error: String? = null
)

@Serializable
data class ContentValidationResult(
    val isValid: Boolean,
    val errors: List<String> = emptyList(),
    val warnings: List<String> = emptyList(),
    val hasWarnings: Boolean = false
)

@Serializable
data class NotificationSettings(
    val quietHoursConfig: QuietHoursConfig = QuietHoursConfig(),
    val consolidationConfigPreset: String = "default",
    val deliveryConstraintsPreset: String = "default"
)

@Serializable
data class SchedulingDecision(
    val action: String,  // deliverNow, schedule, consolidate, discard
    val reason: String,
    val scheduledTimestamp: Double? = null,
    val consolidationInfo: ConsolidationInfo? = null
)

@Serializable
data class ConsolidationInfo(
    val groupKey: String,
    val existingCount: Int
)
