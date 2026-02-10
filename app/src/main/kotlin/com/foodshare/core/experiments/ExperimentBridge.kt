package com.foodshare.core.experiments

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.util.Date
import kotlin.math.*
import kotlin.random.Random

/**
 * Bridge to Swift Experiment Engine.
 * Phase 17: A/B Testing Infrastructure with Thompson Sampling
 */
object ExperimentBridge {

    private val json = Json { ignoreUnknownKeys = true }

    // MARK: - Variant Selection

    /**
     * Get variant for an experiment.
     */
    fun getVariant(
        experimentId: String,
        userId: String,
        experiment: Experiment
    ): Variant {
        if (!experiment.isActive) {
            return experiment.controlVariant
        }

        // Check if user is in target audience
        if (!isUserInAudience(userId, experiment.audience)) {
            return experiment.controlVariant
        }

        // Deterministic assignment based on user ID and experiment ID
        val hashInput = "$userId-$experimentId"
        val hashValue = stableHash(hashInput)
        val bucket = hashValue % 100

        // Find variant based on bucket
        var cumulativePercentage = 0
        for (variant in experiment.variants) {
            cumulativePercentage += variant.percentage
            if (bucket < cumulativePercentage) {
                return variant
            }
        }

        return experiment.controlVariant
    }

    private fun stableHash(input: String): Int {
        var hash = 5381
        for (char in input.toByteArray(Charsets.UTF_8)) {
            hash = ((hash shl 5) + hash) + char.toInt()
        }
        return abs(hash)
    }

    private fun isUserInAudience(userId: String, audience: ExperimentAudience): Boolean {
        return when (audience) {
            is ExperimentAudience.All -> true
            is ExperimentAudience.Percentage -> {
                val bucket = stableHash(userId) % 100
                bucket < audience.pct
            }
            is ExperimentAudience.UserIds -> audience.ids.contains(userId)
            is ExperimentAudience.NewUsers -> false // Would check user creation date
            is ExperimentAudience.PremiumUsers -> false // Would check subscription status
        }
    }

    // MARK: - Feature Flags

    /**
     * Check if a feature is enabled.
     */
    fun isFeatureEnabled(
        featureId: String,
        userId: String,
        flags: List<FeatureFlag>
    ): Boolean {
        val flag = flags.find { it.id == featureId } ?: return false

        if (!flag.isEnabled) {
            return false
        }

        // Check rollout percentage
        flag.rolloutPercentage?.let { rolloutPercentage ->
            val bucket = stableHash("$userId-$featureId") % 100
            return bucket < rolloutPercentage
        }

        // Check user targeting
        flag.targetUserIds?.let { targetUserIds ->
            return targetUserIds.contains(userId)
        }

        return flag.isEnabled
    }

    /**
     * Get all enabled features for a user.
     */
    fun getEnabledFeatures(userId: String, flags: List<FeatureFlag>): List<String> {
        return flags
            .filter { isFeatureEnabled(it.id, userId, flags) }
            .map { it.id }
    }

    // MARK: - Exposure Tracking

    /**
     * Track experiment exposure.
     */
    fun trackExposure(
        experimentId: String,
        variantId: String,
        userId: String
    ): ExposureEvent {
        return ExposureEvent(
            experimentId = experimentId,
            variantId = variantId,
            userId = userId,
            timestamp = System.currentTimeMillis(),
            sessionId = java.util.UUID.randomUUID().toString()
        )
    }

    // MARK: - Multi-Armed Bandit

    /**
     * Select variant using Thompson Sampling.
     */
    fun thompsonSamplingSelect(variants: List<BanditVariant>): BanditVariant {
        require(variants.isNotEmpty()) { "Variants cannot be empty" }

        var bestVariant = variants[0]
        var bestSample = 0.0

        for (variant in variants) {
            // Beta distribution sampling
            val alpha = (variant.successes + 1).toDouble()
            val beta = (variant.failures + 1).toDouble()
            val sample = betaSample(alpha, beta)

            if (sample > bestSample) {
                bestSample = sample
                bestVariant = variant
            }
        }

        return bestVariant
    }

    private fun betaSample(alpha: Double, beta: Double): Double {
        // Simplified beta sampling using gamma distribution
        val x = gammaSample(alpha)
        val y = gammaSample(beta)
        return x / (x + y)
    }

    private fun gammaSample(shape: Double): Double {
        // Marsaglia and Tsang's method
        if (shape >= 1) {
            val d = shape - 1.0 / 3.0
            val c = 1.0 / sqrt(9.0 * d)

            while (true) {
                var x: Double
                var v: Double

                do {
                    x = Random.nextDouble(-10.0, 10.0)
                    v = 1.0 + c * x
                } while (v <= 0)

                v = v * v * v
                val u = Random.nextDouble()

                if (u < 1.0 - 0.0331 * (x * x) * (x * x)) {
                    return d * v
                }

                if (ln(u) < 0.5 * x * x + d * (1.0 - v + ln(v))) {
                    return d * v
                }
            }
        } else {
            return gammaSample(shape + 1) * Random.nextDouble().pow(1.0 / shape)
        }
    }

    // MARK: - Experiment Analysis

    /**
     * Calculate statistical significance.
     */
    fun calculateSignificance(
        control: VariantMetrics,
        treatment: VariantMetrics
    ): SignificanceResult {
        val controlRate = control.conversions.toDouble() / maxOf(control.visitors, 1)
        val treatmentRate = treatment.conversions.toDouble() / maxOf(treatment.visitors, 1)

        val pooledRate = (control.conversions + treatment.conversions).toDouble() /
                (control.visitors + treatment.visitors)

        val standardError = sqrt(
            pooledRate * (1 - pooledRate) *
            (1.0 / control.visitors + 1.0 / treatment.visitors)
        )

        if (standardError <= 0) {
            return SignificanceResult(
                controlRate = controlRate,
                treatmentRate = treatmentRate,
                relativeLift = 0.0,
                zScore = 0.0,
                pValue = 1.0,
                isSignificant = false,
                confidence = 0.0
            )
        }

        val zScore = (treatmentRate - controlRate) / standardError

        // Approximate p-value from z-score
        val pValue = 2 * (1 - normalCDF(abs(zScore)))

        val relativeLift = if (controlRate > 0) {
            (treatmentRate - controlRate) / controlRate * 100
        } else 0.0

        return SignificanceResult(
            controlRate = controlRate,
            treatmentRate = treatmentRate,
            relativeLift = relativeLift,
            zScore = zScore,
            pValue = pValue,
            isSignificant = pValue < 0.05,
            confidence = (1 - pValue) * 100
        )
    }

    private fun normalCDF(x: Double): Double {
        // Approximation using error function
        val a1 = 0.254829592
        val a2 = -0.284496736
        val a3 = 1.421413741
        val a4 = -1.453152027
        val a5 = 1.061405429
        val p = 0.3275911

        val sign = if (x < 0) -1.0 else 1.0
        val absX = abs(x) / sqrt(2.0)

        val t = 1.0 / (1.0 + p * absX)
        val y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * exp(-absX * absX)

        return 0.5 * (1.0 + sign * y)
    }
}

// MARK: - Data Classes

@Serializable
data class Experiment(
    val id: String,
    val name: String,
    val description: String,
    val variants: List<Variant>,
    val audience: ExperimentAudience,
    val isActive: Boolean,
    val startDate: Long,
    val endDate: Long?
) {
    val controlVariant: Variant
        get() = variants.find { it.isControl } ?: variants.first()
}

@Serializable
data class Variant(
    val id: String,
    val name: String,
    val percentage: Int,
    val isControl: Boolean = false,
    val payload: Map<String, String> = emptyMap()
)

@Serializable
sealed class ExperimentAudience {
    @Serializable
    data object All : ExperimentAudience()

    @Serializable
    data class Percentage(val pct: Int) : ExperimentAudience()

    @Serializable
    data class UserIds(val ids: List<String>) : ExperimentAudience()

    @Serializable
    data object NewUsers : ExperimentAudience()

    @Serializable
    data object PremiumUsers : ExperimentAudience()
}

@Serializable
data class FeatureFlag(
    val id: String,
    val name: String,
    val description: String,
    val isEnabled: Boolean,
    val rolloutPercentage: Int? = null,
    val targetUserIds: List<String>? = null
)

@Serializable
data class ExposureEvent(
    val experimentId: String,
    val variantId: String,
    val userId: String,
    val timestamp: Long,
    val sessionId: String
)

@Serializable
data class BanditVariant(
    val id: String,
    val name: String,
    val successes: Int,
    val failures: Int
) {
    val totalTrials: Int get() = successes + failures
    val successRate: Double get() = if (totalTrials > 0) successes.toDouble() / totalTrials else 0.0
}

@Serializable
data class VariantMetrics(
    val visitors: Int,
    val conversions: Int
)

@Serializable
data class SignificanceResult(
    val controlRate: Double,
    val treatmentRate: Double,
    val relativeLift: Double,
    val zScore: Double,
    val pValue: Double,
    val isSignificant: Boolean,
    val confidence: Double
)
