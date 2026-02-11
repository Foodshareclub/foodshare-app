package com.foodshare.features.settings.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import javax.inject.Inject

/**
 * ViewModel for Blocked Users screen
 */
@HiltViewModel
class BlockedUsersViewModel @Inject constructor(
    private val supabaseClient: SupabaseClient
) : ViewModel() {

    private val _uiState = MutableStateFlow(BlockedUsersUiState())
    val uiState: StateFlow<BlockedUsersUiState> = _uiState.asStateFlow()

    init {
        loadBlockedUsers()
    }

    private fun loadBlockedUsers() {
        viewModelScope.launch {
            try {
                val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return@launch

                val blockedUsers = supabaseClient.from("blocked_users")
                    .select {
                        filter {
                            eq("blocker_id", userId)
                        }
                    }
                    .decodeList<BlockedUserRecord>()

                // Fetch profile details for blocked users
                val blockedUserDetails = blockedUsers.mapNotNull { record ->
                    try {
                        val profile = supabaseClient.from("profiles")
                            .select {
                                filter {
                                    eq("id", record.blocked_id)
                                }
                            }
                            .decodeSingle<BlockedUserProfile>()

                        BlockedUser(
                            id = record.blocked_id,
                            nickname = profile.nickname ?: "Unknown User",
                            avatarUrl = profile.avatar_url,
                            blockedAt = record.created_at
                        )
                    } catch (e: Exception) {
                        null
                    }
                }

                _uiState.update {
                    it.copy(
                        blockedUsers = blockedUserDetails,
                        isLoading = false
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(
                        isLoading = false,
                        error = e.message
                    )
                }
            }
        }
    }

    fun unblockUser(userId: String) {
        viewModelScope.launch {
            try {
                val currentUserId = supabaseClient.auth.currentUserOrNull()?.id ?: return@launch

                supabaseClient.from("blocked_users")
                    .delete {
                        filter {
                            eq("blocker_id", currentUserId)
                            eq("blocked_id", userId)
                        }
                    }

                // Remove from local state
                _uiState.update {
                    it.copy(
                        blockedUsers = it.blockedUsers.filter { user -> user.id != userId }
                    )
                }
            } catch (e: Exception) {
                _uiState.update {
                    it.copy(error = e.message)
                }
            }
        }
    }
}

/**
 * UI state for Blocked Users screen
 */
data class BlockedUsersUiState(
    val blockedUsers: List<BlockedUser> = emptyList(),
    val isLoading: Boolean = true,
    val error: String? = null
)

/**
 * Blocked user model
 */
data class BlockedUser(
    val id: String,
    val nickname: String,
    val avatarUrl: String?,
    val blockedAt: String
)

/**
 * Blocked user record from database
 */
@Serializable
data class BlockedUserRecord(
    val blocker_id: String,
    val blocked_id: String,
    val created_at: String
)

/**
 * Blocked user profile
 */
@Serializable
data class BlockedUserProfile(
    val id: String,
    val nickname: String?,
    val avatar_url: String?
)
