package com.foodshare.features.challenges.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.features.challenges.domain.model.*
import com.foodshare.features.challenges.domain.repository.ChallengeRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI State for Challenges screen.
 */
data class ChallengesUiState(
    val publishedChallenges: List<Challenge> = emptyList(),
    val userChallenges: List<ChallengeWithStatus> = emptyList(),
    val selectedChallenge: ChallengeWithStatus? = null,
    val leaderboard: List<ChallengeLeaderboardEntry> = emptyList(),
    val isLoading: Boolean = false,
    val isLoadingLeaderboard: Boolean = false,
    val isJoining: Boolean = false,
    val error: String? = null,
    val selectedFilter: ChallengeFilter = ChallengeFilter.ALL,
    val viewMode: ChallengeViewMode = ChallengeViewMode.LIST,
    val joinedChallengesCount: Int = 0,
    val completedChallengesCount: Int = 0,
    // Like states for optimistic updates
    val likeStates: Map<Int, Boolean> = emptyMap(),
    val likeCounts: Map<Int, Int> = emptyMap()
) {
    val filteredChallenges: List<ChallengeWithStatus>
        get() = when (selectedFilter) {
            ChallengeFilter.ALL -> userChallenges
            ChallengeFilter.JOINED -> userChallenges.filter {
                it.status == ChallengeUserStatus.ACCEPTED || it.status == ChallengeUserStatus.COMPLETED
            }
            ChallengeFilter.COMPLETED -> userChallenges.filter {
                it.status == ChallengeUserStatus.COMPLETED
            }
        }

    val deckChallenges: List<ChallengeWithStatus>
        get() = userChallenges.filter { it.status == ChallengeUserStatus.NOT_JOINED }
}

/**
 * ViewModel for Challenges feature.
 *
 * SYNC: This mirrors Swift ChallengesViewModel
 */
@HiltViewModel
class ChallengesViewModel @Inject constructor(
    private val repository: ChallengeRepository,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChallengesUiState())
    val uiState: StateFlow<ChallengesUiState> = _uiState.asStateFlow()

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    init {
        loadChallenges()
    }

    fun loadChallenges() {
        val userId = currentUserId ?: return
        if (_uiState.value.isLoading) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            repository.getUserChallengesWithCounts(userId)
                .onSuccess { result ->
                    _uiState.update { state ->
                        // Initialize like states from challenges
                        val likeCounts = result.challenges.associate {
                            it.challenge.id to it.challenge.likesCount
                        }

                        state.copy(
                            userChallenges = result.challenges,
                            joinedChallengesCount = result.joinedCount,
                            completedChallengesCount = result.completedCount,
                            likeCounts = likeCounts,
                            isLoading = false
                        )
                    }

                    // Check like states for all challenges
                    result.challenges.forEach { challengeWithStatus ->
                        checkLikeStatus(challengeWithStatus.challenge.id)
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(isLoading = false, error = ErrorBridge.mapChallengeError(error))
                    }
                }
        }
    }

    fun selectChallenge(challenge: Challenge) {
        val userId = currentUserId ?: return

        viewModelScope.launch {
            repository.getChallenge(challenge.id, userId)
                .onSuccess { challengeWithStatus ->
                    _uiState.update { it.copy(selectedChallenge = challengeWithStatus) }
                    loadLeaderboard(challenge.id)
                }
        }
    }

    fun clearSelectedChallenge() {
        _uiState.update { it.copy(selectedChallenge = null, leaderboard = emptyList()) }
    }

    fun acceptChallenge(challengeId: Int) {
        val userId = currentUserId ?: return
        if (_uiState.value.isJoining) return

        viewModelScope.launch {
            _uiState.update { it.copy(isJoining = true) }

            repository.acceptChallenge(challengeId, userId)
                .onSuccess {
                    loadChallenges() // Refresh to get updated counts
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = ErrorBridge.mapChallengeError(error)) }
                }

            _uiState.update { it.copy(isJoining = false) }
        }
    }

    fun completeChallenge(challengeId: Int) {
        val userId = currentUserId ?: return

        viewModelScope.launch {
            repository.completeChallenge(challengeId, userId)
                .onSuccess {
                    loadChallenges()
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = ErrorBridge.mapChallengeError(error)) }
                }
        }
    }

    fun rejectChallenge(challengeId: Int) {
        val userId = currentUserId ?: return

        viewModelScope.launch {
            repository.rejectChallenge(challengeId, userId)
                .onSuccess {
                    loadChallenges()
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = ErrorBridge.mapChallengeError(error)) }
                }
        }
    }

    fun loadLeaderboard(challengeId: Int) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingLeaderboard = true) }

            repository.getLeaderboard(challengeId, limit = 10)
                .onSuccess { entries ->
                    _uiState.update {
                        it.copy(leaderboard = entries, isLoadingLeaderboard = false)
                    }
                }
                .onFailure {
                    _uiState.update { it.copy(isLoadingLeaderboard = false) }
                }
        }
    }

    fun toggleLike(challengeId: Int) {
        val userId = currentUserId ?: return
        val currentState = _uiState.value

        // Optimistic update
        val currentlyLiked = currentState.likeStates[challengeId] ?: false
        val currentCount = currentState.likeCounts[challengeId] ?: 0
        val newLiked = !currentlyLiked
        val newCount = if (newLiked) currentCount + 1 else maxOf(0, currentCount - 1)

        _uiState.update { state ->
            state.copy(
                likeStates = state.likeStates + (challengeId to newLiked),
                likeCounts = state.likeCounts + (challengeId to newCount)
            )
        }

        viewModelScope.launch {
            repository.toggleLike(challengeId, userId)
                .onSuccess { (isLiked, likeCount) ->
                    // Server response - update with actual values
                    _uiState.update { state ->
                        state.copy(
                            likeStates = state.likeStates + (challengeId to isLiked),
                            likeCounts = state.likeCounts + (challengeId to likeCount)
                        )
                    }
                }
                .onFailure {
                    // Revert optimistic update
                    _uiState.update { state ->
                        state.copy(
                            likeStates = state.likeStates + (challengeId to currentlyLiked),
                            likeCounts = state.likeCounts + (challengeId to currentCount)
                        )
                    }
                }
        }
    }

    private fun checkLikeStatus(challengeId: Int) {
        val userId = currentUserId ?: return

        viewModelScope.launch {
            repository.hasLiked(challengeId, userId)
                .onSuccess { isLiked ->
                    _uiState.update { state ->
                        state.copy(likeStates = state.likeStates + (challengeId to isLiked))
                    }
                }
        }
    }

    fun setFilter(filter: ChallengeFilter) {
        _uiState.update { it.copy(selectedFilter = filter) }
    }

    fun setViewMode(mode: ChallengeViewMode) {
        _uiState.update { it.copy(viewMode = mode) }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
