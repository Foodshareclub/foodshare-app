package com.foodshare.features.challenges.presentation

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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
 * UI State for Challenge Detail screen.
 */
data class ChallengeDetailUiState(
    val challenge: ChallengeWithStatus? = null,
    val leaderboard: List<ChallengeLeaderboardEntry> = emptyList(),
    val isLoading: Boolean = true,
    val isLoadingLeaderboard: Boolean = false,
    val isActionLoading: Boolean = false,
    val error: String? = null,
    val isLiked: Boolean = false,
    val likeCount: Int = 0
)

/**
 * ViewModel for Challenge Detail screen.
 */
@HiltViewModel
class ChallengeDetailViewModel @Inject constructor(
    savedStateHandle: SavedStateHandle,
    private val repository: ChallengeRepository,
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val challengeId: Int = savedStateHandle.get<Int>("challengeId") ?: -1

    private val _uiState = MutableStateFlow(ChallengeDetailUiState())
    val uiState: StateFlow<ChallengeDetailUiState> = _uiState.asStateFlow()

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    init {
        if (challengeId != -1) {
            loadChallenge()
        }
    }

    fun loadChallenge() {
        val userId = currentUserId ?: return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            repository.getChallenge(challengeId, userId)
                .onSuccess { challengeWithStatus ->
                    _uiState.update {
                        it.copy(
                            challenge = challengeWithStatus,
                            likeCount = challengeWithStatus.challenge.likesCount,
                            isLoading = false
                        )
                    }
                    checkLikeStatus()
                    loadLeaderboard()
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(isLoading = false, error = error.message)
                    }
                }
        }
    }

    private fun loadLeaderboard() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoadingLeaderboard = true) }

            repository.getLeaderboard(challengeId, limit = 20)
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

    private fun checkLikeStatus() {
        val userId = currentUserId ?: return

        viewModelScope.launch {
            repository.hasLiked(challengeId, userId)
                .onSuccess { isLiked ->
                    _uiState.update { it.copy(isLiked = isLiked) }
                }
        }
    }

    fun acceptChallenge() {
        val userId = currentUserId ?: return
        if (_uiState.value.isActionLoading) return

        viewModelScope.launch {
            _uiState.update { it.copy(isActionLoading = true) }

            repository.acceptChallenge(challengeId, userId)
                .onSuccess {
                    loadChallenge() // Refresh to get updated status
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = error.message, isActionLoading = false) }
                }
        }
    }

    fun completeChallenge() {
        val userId = currentUserId ?: return
        if (_uiState.value.isActionLoading) return

        viewModelScope.launch {
            _uiState.update { it.copy(isActionLoading = true) }

            repository.completeChallenge(challengeId, userId)
                .onSuccess {
                    loadChallenge()
                }
                .onFailure { error ->
                    _uiState.update { it.copy(error = error.message, isActionLoading = false) }
                }
        }
    }

    fun toggleLike() {
        val userId = currentUserId ?: return
        val currentState = _uiState.value

        // Optimistic update
        val newLiked = !currentState.isLiked
        val newCount = if (newLiked) currentState.likeCount + 1 else maxOf(0, currentState.likeCount - 1)

        _uiState.update {
            it.copy(isLiked = newLiked, likeCount = newCount)
        }

        viewModelScope.launch {
            repository.toggleLike(challengeId, userId)
                .onSuccess { (isLiked, likeCount) ->
                    _uiState.update {
                        it.copy(isLiked = isLiked, likeCount = likeCount)
                    }
                }
                .onFailure {
                    // Revert optimistic update
                    _uiState.update {
                        it.copy(isLiked = currentState.isLiked, likeCount = currentState.likeCount)
                    }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
