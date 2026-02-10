package com.foodshare.features.feed.data

import android.util.Log
import com.foodshare.core.realtime.RealtimeChange
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.core.realtime.RealtimeFilter
import com.foodshare.data.dto.FoodListingDto
import com.foodshare.domain.model.FoodListing
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Observes realtime changes to food listings in the feed.
 *
 * Use cases:
 * - New listings posted nearby
 * - Listings becoming unavailable
 * - Listing updates (price, description)
 */
@Singleton
class FeedRealtimeObserver @Inject constructor(
    private val realtimeManager: RealtimeChannelManager
) {
    companion object {
        private const val TAG = "FeedRealtimeObserver"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private val _newListings = MutableSharedFlow<FoodListing>(replay = 0)
    val newListings: SharedFlow<FoodListing> = _newListings.asSharedFlow()

    private val _updatedListings = MutableSharedFlow<FoodListing>(replay = 0)
    val updatedListings: SharedFlow<FoodListing> = _updatedListings.asSharedFlow()

    private val _removedListingIds = MutableSharedFlow<Int>(replay = 0)
    val removedListingIds: SharedFlow<Int> = _removedListingIds.asSharedFlow()

    private val _isObserving = MutableStateFlow(false)
    val isObserving: StateFlow<Boolean> = _isObserving.asStateFlow()

    /**
     * Start observing feed changes.
     *
     * @param userId Optional user ID to filter out own listings
     */
    suspend fun startObserving(userId: String? = null) {
        if (_isObserving.value) {
            Log.d(TAG, "Already observing feed")
            return
        }

        Log.d(TAG, "Starting feed observation")
        _isObserving.value = true

        val filter = RealtimeFilter(
            table = "posts",
            filter = "is_active=eq.true"
        )

        scope.launch {
            try {
                realtimeManager.subscribe<FoodListingDto>(filter)
                    .collect { change ->
                        handleChange(change, userId)
                    }
            } catch (e: Exception) {
                Log.e(TAG, "Feed observation error", e)
                _isObserving.value = false
            }
        }
    }

    /**
     * Stop observing feed changes.
     */
    suspend fun stopObserving() {
        Log.d(TAG, "Stopping feed observation")
        realtimeManager.unsubscribe(RealtimeFilter(table = "posts"))
        _isObserving.value = false
    }

    /**
     * Handle a realtime change event.
     */
    private suspend fun handleChange(
        change: RealtimeChange<FoodListingDto>,
        excludeUserId: String?
    ) {
        when (change) {
            is RealtimeChange.Insert -> {
                val listing = change.record.toDomain()
                // Skip own listings
                if (excludeUserId != null && listing.profileId == excludeUserId) {
                    return
                }
                Log.d(TAG, "New listing: ${listing.id}")
                _newListings.emit(listing)
            }

            is RealtimeChange.Update -> {
                val listing = change.record.toDomain()
                Log.d(TAG, "Updated listing: ${listing.id}")

                // Check if listing became inactive
                if (!listing.isActive || listing.isArranged) {
                    _removedListingIds.emit(listing.id)
                } else {
                    _updatedListings.emit(listing)
                }
            }

            is RealtimeChange.Delete -> {
                change.oldRecord?.let { dto ->
                    Log.d(TAG, "Deleted listing: ${dto.id}")
                    _removedListingIds.emit(dto.id)
                }
            }
        }
    }

    /**
     * Observe new listings as a Flow.
     */
    fun observeNewListings(): Flow<FoodListing> = newListings

    /**
     * Observe listing updates as a Flow.
     */
    fun observeUpdates(): Flow<FoodListing> = updatedListings

    /**
     * Observe removed listing IDs as a Flow.
     */
    fun observeRemovals(): Flow<Int> = removedListingIds

    /**
     * Cleanup resources.
     */
    fun destroy() {
        scope.cancel()
    }
}
