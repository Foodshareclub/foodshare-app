package com.foodshare.features.profile.domain.repository

import com.foodshare.features.profile.presentation.ArrangementHistoryItem

/**
 * Repository interface for profile-related actions and data.
 *
 * Handles arrangement history, newsletter preferences, and email preferences.
 * Separates profile data operations from the general ProfileRepository which
 * focuses on user profile CRUD operations.
 *
 * SYNC: Mirrors iOS profile action patterns
 */
interface ProfileActionRepository {

    /**
     * Load arrangement history for the current user.
     *
     * @return List of arrangement history items ordered by creation date descending
     */
    suspend fun getArrangementHistory(): Result<List<ArrangementHistoryItem>>

    /**
     * Sync newsletter preferences to the backend.
     *
     * @param isSubscribed Whether the user wants to receive newsletters
     * @param frequency Newsletter frequency ("weekly" or "monthly")
     * @param topics List of topic keys the user is interested in
     */
    suspend fun syncNewsletterPreferences(
        isSubscribed: Boolean,
        frequency: String,
        topics: List<String>
    ): Result<Unit>

    /**
     * Sync email preferences to the backend.
     *
     * @param marketingEnabled Whether to receive marketing emails
     * @param productUpdatesEnabled Whether to receive product update emails
     * @param communityNotificationsEnabled Whether to receive community notification emails
     * @param foodAlertsEnabled Whether to receive food alert emails
     * @param weeklyDigestEnabled Whether to receive weekly digest emails
     */
    suspend fun syncEmailPreferences(
        marketingEnabled: Boolean,
        productUpdatesEnabled: Boolean,
        communityNotificationsEnabled: Boolean,
        foodAlertsEnabled: Boolean,
        weeklyDigestEnabled: Boolean
    ): Result<Unit>
}
