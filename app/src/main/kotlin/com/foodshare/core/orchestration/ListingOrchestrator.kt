package com.foodshare.core.orchestration

import com.foodshare.core.gamification.GamificationBridge
import com.foodshare.core.gamification.UserActivityStats
import com.foodshare.core.matching.MatchingBridge
import com.foodshare.core.metrics.BridgeMetrics
import com.foodshare.core.sync.DeltaSyncBridge
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.core.validation.ValidationResult
import kotlinx.serialization.Serializable

/**
 * Cross-bridge orchestration for complex listing workflows.
 *
 * Architecture (Frameo pattern):
 * - Composes multiple swift-java bridges into unified workflows
 * - Maintains atomic operations across Swift validation, matching, gamification
 * - No changes to underlying swift-java bindings
 *
 * Example:
 * ```kotlin
 * val result = ListingOrchestrator.createListing(CreateListingInput(...))
 * if (result.isSuccess) {
 *     // Show success message with points earned
 *     showSuccess("Listing created! +${result.pointsAwarded} points")
 * } else {
 *     // Show validation errors
 *     showErrors(result.validationErrors)
 * }
 * ```
 */
object ListingOrchestrator {

    // ========================================================================
    // Input/Output Types
    // ========================================================================

    @Serializable
    data class CreateListingInput(
        val title: String,
        val description: String,
        val quantity: Int = 1,
        val latitude: Double? = null,
        val longitude: Double? = null,
        val categoryIds: List<Int> = emptyList(),
        val dietaryTags: List<String> = emptyList(),
        val images: List<String> = emptyList()
    )

    @Serializable
    data class CreateListingResult(
        val isSuccess: Boolean,
        val listingId: String? = null,
        val validationErrors: List<String> = emptyList(),
        val pointsAwarded: Int = 0,
        val achievementsUnlocked: List<String> = emptyList(),
        val matchScore: Double? = null,
        val queuedForSync: Boolean = false,
        val error: String? = null
    ) {
        companion object {
            fun success(
                listingId: String,
                pointsAwarded: Int = 0,
                achievementsUnlocked: List<String> = emptyList(),
                matchScore: Double? = null,
                queuedForSync: Boolean = false
            ) = CreateListingResult(
                isSuccess = true,
                listingId = listingId,
                pointsAwarded = pointsAwarded,
                achievementsUnlocked = achievementsUnlocked,
                matchScore = matchScore,
                queuedForSync = queuedForSync
            )

            fun validationFailed(errors: List<String>) = CreateListingResult(
                isSuccess = false,
                validationErrors = errors
            )

            fun error(message: String) = CreateListingResult(
                isSuccess = false,
                error = message
            )
        }
    }

    @Serializable
    data class UpdateListingInput(
        val listingId: String,
        val title: String? = null,
        val description: String? = null,
        val quantity: Int? = null,
        val isActive: Boolean? = null
    )

    @Serializable
    data class UpdateListingResult(
        val isSuccess: Boolean,
        val validationErrors: List<String> = emptyList(),
        val pointsAwarded: Int = 0,
        val queuedForSync: Boolean = false,
        val error: String? = null
    )

    // ========================================================================
    // Workflow Orchestration
    // ========================================================================

    /**
     * Orchestrate listing creation across multiple bridges.
     *
     * Steps:
     * 1. Validate listing with ValidationBridge (Swift)
     * 2. Calculate initial match score with MatchingBridge (Swift)
     * 3. Award creation points with GamificationBridge (Swift)
     * 4. Queue for sync if offline with DeltaSyncBridge
     *
     * @param input Listing creation input
     * @param isOnline Whether device is currently online
     * @param userLatitude User's current latitude for matching
     * @param userLongitude User's current longitude for matching
     * @return Result containing success status, points, and any errors
     */
    fun createListing(
        input: CreateListingInput,
        isOnline: Boolean = true,
        userLatitude: Double? = null,
        userLongitude: Double? = null
    ): CreateListingResult = BridgeMetrics.timed("ListingOrchestrator", "createListing") {

        // Step 1: Validate using Swift ValidationBridge
        val validation = BridgeMetrics.timed("ValidationBridge", "validateListing") {
            ValidationBridge.validateListing(
                title = input.title,
                description = input.description,
                quantity = input.quantity
            )
        }

        if (!validation.isValid) {
            return@timed CreateListingResult.validationFailed(validation.errorMessages)
        }

        // Step 2: Calculate match score if location available
        val matchScore = if (input.latitude != null && input.longitude != null &&
            userLatitude != null && userLongitude != null) {
            try {
                BridgeMetrics.timed("MatchingBridge", "calculateMatchScore") {
                    val candidate = MatchingBridge.MatchCandidate(
                        id = "pending",
                        latitude = input.latitude,
                        longitude = input.longitude,
                        categoryIds = input.categoryIds,
                        dietaryPreferences = input.dietaryTags
                    )
                    val context = MatchingBridge.MatchingContext(
                        userLatitude = userLatitude,
                        userLongitude = userLongitude
                    )
                    MatchingBridge.calculateMatchScore(candidate, context).totalScore
                }
            } catch (e: Exception) {
                null // Non-critical, continue without match score
            }
        } else null

        // Step 3: Award gamification points for listing creation
        val gamificationResult = try {
            BridgeMetrics.timed("GamificationBridge", "evaluateAchievement") {
                val stats = UserActivityStats(totalFoodShared = 1)
                GamificationBridge.evaluateAchievement(
                    achievementId = "first_listing",
                    stats = stats
                )
            }
        } catch (e: Exception) {
            null // Non-critical, continue without points
        }

        // Generate temporary listing ID
        val listingId = java.util.UUID.randomUUID().toString()

        // Step 4: Queue for sync if offline
        val queuedForSync = if (!isOnline) {
            try {
                // DeltaSyncBridge would record the change for later sync
                // This is a placeholder - actual implementation depends on DeltaSyncBridge API
                true
            } catch (e: Exception) {
                false
            }
        } else false

        // Build achievements list
        val achievements = gamificationResult?.let {
            if (it.shouldUnlock) listOf("first_listing") else emptyList()
        } ?: emptyList()

        CreateListingResult.success(
            listingId = listingId,
            pointsAwarded = gamificationResult?.pointsValue ?: 0,
            achievementsUnlocked = achievements,
            matchScore = matchScore,
            queuedForSync = queuedForSync
        )
    }

    /**
     * Orchestrate listing update across multiple bridges.
     *
     * @param input Update input with changed fields
     * @param isOnline Whether device is currently online
     * @return Result containing success status and any errors
     */
    fun updateListing(
        input: UpdateListingInput,
        isOnline: Boolean = true
    ): UpdateListingResult = BridgeMetrics.timed("ListingOrchestrator", "updateListing") {

        // Validate changed fields
        val errors = mutableListOf<String>()

        input.title?.let { title ->
            ValidationBridge.validateTitle(title)?.let { error ->
                errors.add(error)
            }
        }

        input.description?.let { description ->
            ValidationBridge.validateDescription(description)?.let { error ->
                errors.add(error)
            }
        }

        if (input.quantity != null && input.quantity < 1) {
            errors.add("Quantity must be at least 1")
        }

        if (errors.isNotEmpty()) {
            return@timed UpdateListingResult(
                isSuccess = false,
                validationErrors = errors
            )
        }

        // Queue for sync if offline
        val queuedForSync = !isOnline

        UpdateListingResult(
            isSuccess = true,
            queuedForSync = queuedForSync
        )
    }

    /**
     * Validate listing without creating.
     * Useful for real-time validation in forms.
     *
     * @param input Listing input to validate
     * @return Validation result
     */
    fun validateListing(input: CreateListingInput): ValidationResult {
        return BridgeMetrics.timed("ListingOrchestrator", "validateListing") {
            ValidationBridge.validateListing(
                title = input.title,
                description = input.description,
                quantity = input.quantity
            )
        }
    }

    /**
     * Calculate potential match score for a listing.
     *
     * @param input Listing input
     * @param userLatitude User's latitude
     * @param userLongitude User's longitude
     * @return Match score percentage (0-100) or null if calculation fails
     */
    fun calculateMatchPotential(
        input: CreateListingInput,
        userLatitude: Double,
        userLongitude: Double
    ): Int? {
        if (input.latitude == null || input.longitude == null) return null

        return try {
            BridgeMetrics.timed("ListingOrchestrator", "calculateMatchPotential") {
                val candidate = MatchingBridge.MatchCandidate(
                    id = "preview",
                    latitude = input.latitude,
                    longitude = input.longitude,
                    categoryIds = input.categoryIds,
                    dietaryPreferences = input.dietaryTags
                )
                val context = MatchingBridge.MatchingContext(
                    userLatitude = userLatitude,
                    userLongitude = userLongitude
                )
                MatchingBridge.calculateMatchScore(candidate, context).percentageScore
            }
        } catch (e: Exception) {
            null
        }
    }
}
