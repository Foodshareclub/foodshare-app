package com.foodshare.features.create.presentation

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.core.moderation.ModerationBridge
import com.foodshare.core.moderation.ModerationContentType
import com.foodshare.core.moderation.ModerationSeverity
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.domain.location.LocationData
import com.foodshare.domain.location.LocationService
import com.foodshare.domain.model.PostType
import com.foodshare.domain.repository.ListingRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for creating new listings
 *
 * Manages form state, validation, and submission
 */
@HiltViewModel
class CreateListingViewModel @Inject constructor(
    private val listingRepository: ListingRepository,
    val locationService: LocationService
) : ViewModel() {

    private val _uiState = MutableStateFlow(CreateListingUiState())
    val uiState: StateFlow<CreateListingUiState> = _uiState.asStateFlow()

    fun updateTitle(title: String) {
        _uiState.update {
            it.copy(
                title = title,
                titleError = null
            )
        }
    }

    fun updateDescription(description: String) {
        _uiState.update {
            it.copy(
                description = description,
                descriptionError = null
            )
        }
    }

    fun updatePostType(postType: PostType) {
        _uiState.update { it.copy(selectedPostType = postType) }
    }

    fun updatePickupTime(time: String) {
        _uiState.update { it.copy(pickupTime = time) }
    }

    fun updateAddress(address: String) {
        _uiState.update { it.copy(address = address) }
    }

    fun updateLocation(location: LocationData) {
        _uiState.update {
            it.copy(
                location = location,
                address = location.displayAddress
            )
        }
    }

    fun addImage(uri: Uri) {
        _uiState.update { state ->
            if (state.imageUris.size < 5) {
                state.copy(imageUris = state.imageUris + uri)
            } else {
                state.copy(error = "Maximum 5 images allowed")
            }
        }
    }

    fun addImages(uris: List<Uri>) {
        _uiState.update { state ->
            val availableSlots = 5 - state.imageUris.size
            val toAdd = uris.take(availableSlots)
            if (toAdd.isNotEmpty()) {
                state.copy(imageUris = state.imageUris + toAdd)
            } else {
                state.copy(error = "Maximum 5 images allowed")
            }
        }
    }

    fun removeImage(uri: Uri) {
        _uiState.update { state ->
            state.copy(imageUris = state.imageUris - uri)
        }
    }

    fun submit(onSuccess: () -> Unit) {
        if (!validate()) return

        val state = _uiState.value

        // Run Swift-based content moderation check before submission
        val moderationResult = ModerationBridge.checkBeforeSubmission(
            title = state.title,
            description = state.description.ifBlank { null },
            contentType = ModerationContentType.LISTING
        )

        // Block submission if moderation fails
        if (!moderationResult.canSubmit) {
            val issueDescriptions = moderationResult.issues.joinToString("\n") { it.description }
            _uiState.update {
                it.copy(
                    error = "Content moderation: $issueDescriptions",
                    moderationWarning = if (moderationResult.severity == ModerationSeverity.LOW) {
                        issueDescriptions
                    } else null
                )
            }
            return
        }

        // Use sanitized content from moderation result (or original if not sanitized)
        val sanitizedTitle = moderationResult.sanitizedTitle
            ?: ValidationBridge.sanitizeListingTitle(state.title)
        val sanitizedDescription = moderationResult.sanitizedDescription
            ?: if (state.description.isNotBlank()) {
                ValidationBridge.sanitizeListingDescription(state.description)
            } else null

        viewModelScope.launch {
            _uiState.update { it.copy(isSubmitting = true, error = null, moderationWarning = null) }

            listingRepository.createListing(
                title = sanitizedTitle,
                description = sanitizedDescription,
                postType = state.selectedPostType,
                pickupTime = state.pickupTime.ifBlank { null },
                address = state.address.ifBlank { null },
                latitude = state.location?.latitude,
                longitude = state.location?.longitude,
                imageUris = state.imageUris
            ).onSuccess {
                _uiState.update { it.copy(isSubmitting = false, isSuccess = true) }
                onSuccess()
            }.onFailure { e ->
                _uiState.update {
                    it.copy(
                        isSubmitting = false,
                        error = ErrorBridge.mapListingError(e)
                    )
                }
            }
        }
    }

    /**
     * Preview moderation result for current content.
     * Called as user types to provide early feedback.
     */
    fun checkModeration() {
        val state = _uiState.value
        if (state.title.isBlank()) return

        viewModelScope.launch {
            val result = ModerationBridge.checkBeforeSubmission(
                title = state.title,
                description = state.description.ifBlank { null },
                contentType = ModerationContentType.LISTING
            )

            _uiState.update {
                it.copy(
                    moderationWarning = if (result.hasIssues && result.canSubmit) {
                        result.issues.joinToString("\n") { issue -> issue.description }
                    } else null
                )
            }
        }
    }

    private fun validate(): Boolean {
        val state = _uiState.value

        // Use ValidationBridge which delegates to Swift when available
        val result = ValidationBridge.validateListing(
            title = state.title,
            description = state.description
        )

        if (!result.isValid) {
            // Extract specific field errors from validation result
            val titleError = result.errors.firstOrNull {
                it.message.contains("Title", ignoreCase = true)
            }?.message

            val descriptionError = result.errors.firstOrNull {
                it.message.contains("Description", ignoreCase = true)
            }?.message

            _uiState.update {
                it.copy(
                    titleError = titleError,
                    descriptionError = descriptionError
                )
            }
        }

        return result.isValid
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun reset() {
        _uiState.value = CreateListingUiState()
    }
}

/**
 * UI state for the Create Listing screen
 */
data class CreateListingUiState(
    val title: String = "",
    val description: String = "",
    val selectedPostType: PostType = PostType.FOOD,
    val pickupTime: String = "",
    val address: String = "",
    val location: LocationData? = null,
    val imageUris: List<Uri> = emptyList(),
    val isSubmitting: Boolean = false,
    val isSuccess: Boolean = false,
    val error: String? = null,
    val titleError: String? = null,
    val descriptionError: String? = null,
    val moderationWarning: String? = null  // Swift-based content moderation warning
) {
    val isValid: Boolean
        get() = title.isNotBlank() && titleError == null && descriptionError == null

    val canSubmit: Boolean
        get() = isValid && !isSubmitting

    val hasLocation: Boolean
        get() = location != null || address.isNotBlank()

    val hasModerationWarning: Boolean
        get() = moderationWarning != null
}
