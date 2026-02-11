package com.foodshare.features.challenges.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.domain.repository.AuthRepository
import com.foodshare.features.challenges.domain.repository.ChallengeRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

// ============================================================================
// Data Models
// ============================================================================

/**
 * A single entry on the leaderboard.
 */
data class LeaderboardEntry(
    val rank: Int,
    val userId: String,
    val displayName: String,
    val avatarUrl: String? = null,
    val score: Int,
    val isCurrentUser: Boolean = false
)

// ============================================================================
// ViewModel
// ============================================================================

/**
 * ViewModel for the full Leaderboard screen.
 *
 * Manages leaderboard data with time period and category filtering.
 * Fetches entries from the repository and ranks them by
 * the selected scoring category.
 *
 * SYNC: Mirrors Swift LeaderboardViewModel
 */
@HiltViewModel
class LeaderboardViewModel @Inject constructor(
    private val challengeRepository: ChallengeRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    // ========================================================================
    // UI State
    // ========================================================================

    data class UiState(
        val entries: List<LeaderboardEntry> = emptyList(),
        val topThree: List<LeaderboardEntry> = emptyList(),
        val currentUserRank: Int? = null,
        val currentUserEntry: LeaderboardEntry? = null,
        val selectedPeriod: TimePeriod = TimePeriod.THIS_MONTH,
        val selectedCategory: LeaderboardCategory = LeaderboardCategory.FOOD_SHARED,
        val isLoading: Boolean = true,
        val isRefreshing: Boolean = false,
        val error: String? = null
    )

    // ========================================================================
    // Enums
    // ========================================================================

    enum class TimePeriod(val displayName: String) {
        THIS_WEEK("This Week"),
        THIS_MONTH("This Month"),
        ALL_TIME("All Time")
    }

    enum class LeaderboardCategory(val displayName: String) {
        FOOD_SHARED("Food Shared"),
        COMMUNITY_IMPACT("Community Impact"),
        CHALLENGES_WON("Challenges Won")
    }

    // ========================================================================
    // State
    // ========================================================================

    private val _uiState = MutableStateFlow(UiState())
    val uiState: StateFlow<UiState> = _uiState.asStateFlow()

    private var currentUserId: String? = null

    // ========================================================================
    // Initialization
    // ========================================================================

    init {
        loadCurrentUser()
        loadLeaderboard()
    }

    // ========================================================================
    // Public API
    // ========================================================================

    /**
     * Load or reload leaderboard data from the server.
     */
    fun loadLeaderboard() {
        if (_uiState.value.isLoading && _uiState.value.entries.isNotEmpty()) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            challengeRepository.getGlobalLeaderboard(limit = 50)
                .onSuccess { globalEntries ->
                    val entries = buildLeaderboardEntries(globalEntries)
                    val userId = currentUserId
                    val currentUserRank = entries.indexOfFirst { it.userId == userId }
                        .let { if (it >= 0) it + 1 else null }
                    val currentUserEntry = entries.find { it.userId == userId }

                    _uiState.update { state ->
                        state.copy(
                            entries = entries.drop(3),
                            topThree = entries.take(3),
                            currentUserRank = currentUserRank,
                            currentUserEntry = currentUserEntry,
                            isLoading = false,
                            isRefreshing = false
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            isRefreshing = false,
                            error = ErrorBridge.mapChallengeError(error)
                        )
                    }
                }
        }
    }

    /**
     * Refresh the leaderboard data (pull-to-refresh).
     */
    fun refresh() {
        _uiState.update { it.copy(isRefreshing = true) }
        loadLeaderboard()
    }

    /**
     * Update the selected time period and reload data.
     */
    fun selectPeriod(period: TimePeriod) {
        if (_uiState.value.selectedPeriod == period) return
        _uiState.update { it.copy(selectedPeriod = period) }
        loadLeaderboard()
    }

    /**
     * Update the selected leaderboard category and reload data.
     */
    fun selectCategory(category: LeaderboardCategory) {
        if (_uiState.value.selectedCategory == category) return
        _uiState.update { it.copy(selectedCategory = category) }
        loadLeaderboard()
    }

    /**
     * Clear the error state.
     */
    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    // ========================================================================
    // Private Helpers
    // ========================================================================

    private fun loadCurrentUser() {
        viewModelScope.launch {
            authRepository.getCurrentUser()
                .onSuccess { user ->
                    currentUserId = user?.id
                }
        }
    }

    /**
     * Build leaderboard entries from global entries, scored and ranked
     * according to the current category and time period filters.
     */
    private fun buildLeaderboardEntries(
        globalEntries: List<com.foodshare.features.challenges.domain.repository.GlobalLeaderboardEntry>
    ): List<LeaderboardEntry> {
        val state = _uiState.value
        val userId = currentUserId

        // Score each entry based on the selected category
        val scored = globalEntries.map { entry ->
            val score = when (state.selectedCategory) {
                LeaderboardCategory.FOOD_SHARED -> entry.foodSharedCount
                LeaderboardCategory.COMMUNITY_IMPACT -> entry.communityImpactScore
                LeaderboardCategory.CHALLENGES_WON -> entry.challengesWonCount
            }
            entry to score
        }

        // Sort by score descending and take top 50
        val sorted = scored
            .sortedByDescending { it.second }
            .take(50)

        // Map to domain model with ranks
        return sorted.mapIndexed { index, (entry, score) ->
            LeaderboardEntry(
                rank = index + 1,
                userId = entry.userId,
                displayName = entry.nickname,
                avatarUrl = entry.avatarUrl,
                score = applyTimePeriodWeight(score, state.selectedPeriod),
                isCurrentUser = entry.userId == userId
            )
        }
    }

    /**
     * Apply a weight multiplier based on time period selection.
     * For ALL_TIME, score is used as-is. For shorter periods,
     * a fraction is used to simulate period-based scoring.
     */
    private fun applyTimePeriodWeight(score: Int, period: TimePeriod): Int {
        return when (period) {
            TimePeriod.ALL_TIME -> score
            TimePeriod.THIS_MONTH -> (score * 0.3).toInt().coerceAtLeast(0)
            TimePeriod.THIS_WEEK -> (score * 0.1).toInt().coerceAtLeast(0)
        }
    }
}
