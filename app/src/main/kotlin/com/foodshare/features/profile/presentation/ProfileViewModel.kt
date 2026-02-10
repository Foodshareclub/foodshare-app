package com.foodshare.features.profile.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.moderation.ModerationBridge
import com.foodshare.core.moderation.ModerationContentType
import com.foodshare.core.moderation.ModerationSeverity
import com.foodshare.core.optimistic.EntityType
import com.foodshare.core.optimistic.ErrorCategory
import com.foodshare.core.optimistic.OptimisticUpdateBridge
import com.foodshare.core.optimistic.UpdateOperation
import com.foodshare.core.utilities.DateTimeFormatter
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.domain.model.UserProfile
import com.foodshare.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for the Profile screen
 *
 * Manages user profile data and actions with Swift validation.
 *
 * SYNC: Mirrors Swift ProfileViewModel
 */
@HiltViewModel
class ProfileViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(ProfileUiState())
    val uiState: StateFlow<ProfileUiState> = _uiState.asStateFlow()

    init {
        loadProfile()
        observeUser()
    }

    private fun observeUser() {
        viewModelScope.launch {
            authRepository.currentUser.collect { user ->
                _uiState.update { it.copy(user = user) }
            }
        }
    }

    private fun loadProfile() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            authRepository.getCurrentUser()
                .onSuccess { user ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            user = user,
                            error = null
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = error.message ?: "Failed to load profile"
                        )
                    }
                }
        }
    }

    // ========================================================================
    // Edit Profile with Swift Validation
    // ========================================================================

    /**
     * Enter edit mode with current profile values.
     */
    fun startEditing() {
        val user = _uiState.value.user ?: return
        _uiState.update {
            it.copy(
                editState = EditProfileState(
                    nickname = user.nickname ?: "",
                    bio = user.bio ?: ""
                )
            )
        }
    }

    /**
     * Cancel editing and discard changes.
     */
    fun cancelEditing() {
        _uiState.update { it.copy(editState = null) }
    }

    /**
     * Update nickname with Swift validation.
     */
    fun updateNickname(nickname: String) {
        val editState = _uiState.value.editState ?: return

        // Validate using Swift (matches iOS)
        val validationError = ValidationBridge.validateNickname(nickname)

        _uiState.update {
            it.copy(
                editState = editState.copy(
                    nickname = nickname,
                    nicknameError = validationError
                )
            )
        }
    }

    /**
     * Update bio with Swift validation.
     */
    fun updateBio(bio: String) {
        val editState = _uiState.value.editState ?: return

        // Validate using Swift (matches iOS)
        val validationError = ValidationBridge.validateBio(bio)

        _uiState.update {
            it.copy(
                editState = editState.copy(
                    bio = bio,
                    bioError = validationError
                )
            )
        }
    }

    /**
     * Save profile with Swift sanitization, moderation, and optimistic updates.
     * Uses ModerationBridge to check profile content for inappropriate language.
     * Uses OptimisticUpdateBridge for instant feedback and smart rollback.
     */
    fun saveProfile() {
        val editState = _uiState.value.editState ?: return
        val currentUser = _uiState.value.user ?: return

        // Validate all fields before saving
        if (!editState.isValid) {
            return
        }

        // Run Swift-based content moderation check on profile content
        val moderationResult = ModerationBridge.checkBeforeSubmission(
            title = editState.nickname.takeIf { it.isNotBlank() },
            description = editState.bio.takeIf { it.isNotBlank() },
            contentType = ModerationContentType.PROFILE
        )

        // Block save if moderation fails
        if (!moderationResult.canSubmit) {
            val issueDescriptions = moderationResult.issues.joinToString("\n") { it.description }
            _uiState.update {
                it.copy(
                    error = "Profile contains inappropriate content: $issueDescriptions",
                    editState = editState.copy(
                        moderationWarning = if (moderationResult.severity == ModerationSeverity.LOW) {
                            issueDescriptions
                        } else null
                    )
                )
            }
            return
        }

        // Use sanitized content from moderation result (or fallback to ValidationBridge)
        val sanitizedNickname = moderationResult.sanitizedTitle
            ?: ValidationBridge.sanitizeDisplayName(editState.nickname)
        val sanitizedBio = moderationResult.sanitizedDescription
            ?: ValidationBridge.sanitizeBio(editState.bio)

        // Create optimistic update via Swift bridge
        val originalValue = """{"nickname":"${currentUser.nickname.orEmpty()}","bio":"${currentUser.bio.orEmpty()}"}"""
        val optimisticValue = """{"nickname":"$sanitizedNickname","bio":"$sanitizedBio"}"""
        val optimisticUpdate = OptimisticUpdateBridge.createUpdate(
            id = currentUser.id,
            entityType = EntityType.PROFILE,
            operation = UpdateOperation.UPDATE,
            originalValue = originalValue,
            optimisticValue = optimisticValue
        )

        // Apply optimistic update - show updated profile immediately
        val optimisticUser = currentUser.copy(
            nickname = sanitizedNickname.ifBlank { null },
            bio = sanitizedBio.ifBlank { null }
        )
        _uiState.update {
            it.copy(
                user = optimisticUser,
                editState = null,
                isSaving = true
            )
        }

        viewModelScope.launch {
            authRepository.updateProfile(
                nickname = sanitizedNickname.ifBlank { null },
                bio = sanitizedBio.ifBlank { null }
            )
                .onSuccess { user ->
                    // Confirm optimistic update
                    optimisticUpdate?.let { OptimisticUpdateBridge.confirmUpdate(it) }
                    _uiState.update {
                        it.copy(
                            user = user,
                            isSaving = false,
                            error = null
                        )
                    }
                }
                .onFailure { error ->
                    // Use Swift bridge for rollback decision
                    if (optimisticUpdate != null) {
                        val recommendation = OptimisticUpdateBridge.handleError(
                            update = optimisticUpdate,
                            errorCode = "SAVE_FAILED",
                            errorMessage = error.message ?: "Failed to save profile",
                            category = categorizeError(error)
                        )

                        if (recommendation.shouldRollback) {
                            // Rollback via Swift bridge - restore original user
                            OptimisticUpdateBridge.rollback(optimisticUpdate)
                            _uiState.update {
                                it.copy(
                                    user = currentUser,  // Restore original
                                    editState = editState,  // Restore edit state
                                    isSaving = false,
                                    error = error.message ?: "Failed to save profile"
                                )
                            }
                        } else if (recommendation.shouldRetry && recommendation.delayMs != null) {
                            // Retry after delay
                            delay(recommendation.delayMs)
                            retrySaveProfile(
                                optimisticUpdate,
                                currentUser,
                                editState,
                                sanitizedNickname,
                                sanitizedBio
                            )
                        }
                    } else {
                        _uiState.update {
                            it.copy(
                                user = currentUser,
                                editState = editState,
                                isSaving = false,
                                error = error.message ?: "Failed to save profile"
                            )
                        }
                    }
                }
        }
    }

    /**
     * Retry saving a failed profile update.
     */
    private fun retrySaveProfile(
        update: com.foodshare.core.optimistic.OptimisticUpdate,
        originalUser: UserProfile,
        editState: EditProfileState,
        nickname: String,
        bio: String
    ) {
        viewModelScope.launch {
            val incrementedUpdate = OptimisticUpdateBridge.incrementRetry(update)

            authRepository.updateProfile(
                nickname = nickname.ifBlank { null },
                bio = bio.ifBlank { null }
            ).onSuccess { user ->
                OptimisticUpdateBridge.confirmUpdate(incrementedUpdate)
                _uiState.update { it.copy(user = user, isSaving = false) }
            }.onFailure { error ->
                val recommendation = OptimisticUpdateBridge.handleError(
                    update = incrementedUpdate,
                    errorCode = "RETRY_FAILED",
                    errorMessage = error.message ?: "Retry failed",
                    category = categorizeError(error)
                )

                if (recommendation.shouldRollback) {
                    OptimisticUpdateBridge.rollback(incrementedUpdate)
                    _uiState.update {
                        it.copy(
                            user = originalUser,
                            editState = editState,
                            isSaving = false,
                            error = "Profile update failed after retries. Please try again."
                        )
                    }
                }
            }
        }
    }

    /**
     * Categorize error for OptimisticUpdateBridge.
     */
    private fun categorizeError(error: Throwable): ErrorCategory {
        val message = error.message?.lowercase() ?: ""
        return when {
            message.contains("network") || message.contains("timeout") -> ErrorCategory.NETWORK
            message.contains("unauthorized") || message.contains("401") -> ErrorCategory.AUTHORIZATION
            message.contains("conflict") || message.contains("409") -> ErrorCategory.CONFLICT
            message.contains("validation") || message.contains("400") -> ErrorCategory.VALIDATION
            message.contains("server") || message.contains("500") -> ErrorCategory.SERVER_ERROR
            else -> ErrorCategory.UNKNOWN
        }
    }

    /**
     * Preview moderation for real-time feedback as user edits profile.
     * Called when user finishes editing nickname or bio.
     */
    fun checkModeration() {
        val editState = _uiState.value.editState ?: return
        if (editState.nickname.isBlank() && editState.bio.isBlank()) {
            _uiState.update {
                it.copy(editState = editState.copy(moderationWarning = null))
            }
            return
        }

        val result = ModerationBridge.checkBeforeSubmission(
            title = editState.nickname.takeIf { it.isNotBlank() },
            description = editState.bio.takeIf { it.isNotBlank() },
            contentType = ModerationContentType.PROFILE
        )

        _uiState.update {
            it.copy(
                editState = editState.copy(
                    moderationWarning = if (result.hasIssues && result.canSubmit) {
                        result.issues.joinToString("\n") { issue -> issue.description }
                    } else null
                )
            )
        }
    }

    // ========================================================================
    // Standard Actions
    // ========================================================================

    fun signOut(onSignedOut: () -> Unit) {
        viewModelScope.launch {
            _uiState.update { it.copy(isSigningOut = true) }

            authRepository.signOut()
                .onSuccess {
                    _uiState.update { it.copy(isSigningOut = false) }
                    onSignedOut()
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isSigningOut = false,
                            error = error.message ?: "Failed to sign out"
                        )
                    }
                }
        }
    }

    fun refresh() {
        loadProfile()
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}

/**
 * Edit profile state with validation.
 */
data class EditProfileState(
    val nickname: String = "",
    val bio: String = "",
    val nicknameError: String? = null,
    val bioError: String? = null,
    val moderationWarning: String? = null  // Swift-based content moderation warning
) {
    val isValid: Boolean
        get() = nicknameError == null && bioError == null

    val hasChanges: Boolean
        get() = nickname.isNotBlank() || bio.isNotBlank()

    val hasModerationWarning: Boolean get() = moderationWarning != null
}

/**
 * UI state for the Profile screen
 */
data class ProfileUiState(
    val user: UserProfile? = null,
    val isLoading: Boolean = false,
    val isSigningOut: Boolean = false,
    val isSaving: Boolean = false,
    val editState: EditProfileState? = null,
    val error: String? = null
) {
    val isEditing: Boolean get() = editState != null

    val displayName: String
        get() = user?.nickname ?: user?.email?.substringBefore("@") ?: "User"

    val initials: String
        get() = displayName.take(2).uppercase()

    /**
     * Member since formatted for display.
     */
    val memberSince: String
        get() = user?.createdAt?.let { DateTimeFormatter.formatRelativeDate(it) }
            ?: "Recently joined"

    /**
     * Member duration (e.g., "Member for 2 years").
     */
    val memberDuration: String
        get() = user?.createdAt?.let {
            "Member for ${DateTimeFormatter.formatRelativeDate(it).replace(" ago", "")}"
        } ?: "New member"

    /**
     * Rating formatted with count.
     */
    val ratingDisplay: String
        get() = user?.ratingAverage?.let { avg ->
            val count = user.ratingCount ?: 0
            String.format("%.1f (%d reviews)", avg, count)
        } ?: "No reviews yet"

    /**
     * Stats formatted for display.
     */
    val statsDisplay: String
        get() = user?.let {
            val shared = it.itemsShared ?: 0
            val received = it.itemsReceived ?: 0
            "$shared shared · $received received"
        } ?: ""
}
