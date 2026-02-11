package com.foodshare.features.arrangement.presentation

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.domain.repository.AuthRepository
import com.foodshare.features.arrangement.domain.model.Arrangement
import com.foodshare.features.arrangement.domain.model.ArrangementStatus
import com.foodshare.features.arrangement.domain.repository.ArrangementRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * UI State for Arrangement screen.
 */
data class ArrangementUiState(
    val arrangement: Arrangement? = null,
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null,
    val successMessage: String? = null,

    // Form fields for creating arrangement
    val pickupDate: String = "",
    val pickupTime: String = "",
    val pickupLocation: String = "",
    val notes: String = "",

    // Mode flags
    val isCreating: Boolean = false,
    val isOwner: Boolean = false,
    val currentUserId: String? = null
) {
    val canAccept: Boolean
        get() = isOwner && arrangement?.status == ArrangementStatus.PENDING

    val canDecline: Boolean
        get() = isOwner && arrangement?.status == ArrangementStatus.PENDING

    val canConfirm: Boolean
        get() = isOwner && arrangement?.status == ArrangementStatus.ACCEPTED

    val canComplete: Boolean
        get() = isOwner && arrangement?.status == ArrangementStatus.CONFIRMED

    val canMarkNoShow: Boolean
        get() = isOwner && arrangement?.status == ArrangementStatus.CONFIRMED
}

/**
 * ViewModel for Arrangement feature.
 *
 * Handles arrangement creation, viewing, and status updates.
 */
@HiltViewModel
class ArrangementViewModel @Inject constructor(
    private val repository: ArrangementRepository,
    private val authRepository: AuthRepository,
    savedStateHandle: SavedStateHandle
) : ViewModel() {

    private val _uiState = MutableStateFlow(ArrangementUiState())
    val uiState: StateFlow<ArrangementUiState> = _uiState.asStateFlow()

    private val arrangementId: String? = savedStateHandle["arrangementId"]
    private val listingId: Int? = savedStateHandle.get<String>("listingId")?.toIntOrNull()
    private val ownerId: String? = savedStateHandle["ownerId"]

    init {
        loadCurrentUser()

        if (arrangementId != null) {
            loadArrangement(arrangementId)
        } else if (listingId != null && ownerId != null) {
            _uiState.update { it.copy(isCreating = true) }
        }
    }

    private fun loadCurrentUser() {
        viewModelScope.launch {
            authRepository.getCurrentUser()
                .onSuccess { user ->
                    _uiState.update {
                        it.copy(
                            currentUserId = user?.id,
                            isOwner = user?.id == ownerId
                        )
                    }
                }
        }
    }

    fun loadArrangement(id: String) {
        if (_uiState.value.isLoading) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            repository.getArrangement(id)
                .onSuccess { arrangement ->
                    _uiState.update { state ->
                        state.copy(
                            arrangement = arrangement,
                            isLoading = false,
                            isOwner = state.currentUserId == arrangement.ownerId,
                            pickupDate = arrangement.pickupDate ?: "",
                            pickupTime = arrangement.pickupTime ?: "",
                            pickupLocation = arrangement.pickupLocation ?: "",
                            notes = arrangement.notes ?: ""
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapArrangementError(error)
                        )
                    }
                }
        }
    }

    fun createArrangement() {
        val currentListingId = listingId ?: return
        val currentOwnerId = ownerId ?: return

        if (_uiState.value.isSaving) return

        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, error = null) }

            val state = _uiState.value
            repository.createArrangement(
                listingId = currentListingId,
                ownerId = currentOwnerId,
                pickupDate = state.pickupDate.takeIf { it.isNotBlank() },
                pickupTime = state.pickupTime.takeIf { it.isNotBlank() },
                pickupLocation = state.pickupLocation.takeIf { it.isNotBlank() },
                notes = state.notes.takeIf { it.isNotBlank() }
            )
                .onSuccess { arrangement ->
                    _uiState.update {
                        it.copy(
                            arrangement = arrangement,
                            isSaving = false,
                            isCreating = false,
                            successMessage = "Arrangement created successfully"
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isSaving = false,
                            error = ErrorBridge.mapArrangementError(error)
                        )
                    }
                }
        }
    }

    fun acceptArrangement() {
        updateArrangementStatus(ArrangementStatus.ACCEPTED, "Arrangement accepted")
    }

    fun declineArrangement() {
        updateArrangementStatus(ArrangementStatus.DECLINED, "Arrangement declined")
    }

    fun confirmPickup() {
        updateArrangementStatus(ArrangementStatus.CONFIRMED, "Pickup confirmed")
    }

    fun markComplete() {
        updateArrangementStatus(ArrangementStatus.COMPLETED, "Arrangement marked as complete")
    }

    fun markNoShow() {
        updateArrangementStatus(ArrangementStatus.NO_SHOW, "Marked as no-show")
    }

    private fun updateArrangementStatus(status: ArrangementStatus, successMsg: String) {
        val currentArrangement = _uiState.value.arrangement ?: return
        if (_uiState.value.isSaving) return

        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, error = null) }

            repository.updateStatus(currentArrangement.id, status)
                .onSuccess { updatedArrangement ->
                    _uiState.update {
                        it.copy(
                            arrangement = updatedArrangement,
                            isSaving = false,
                            successMessage = successMsg
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isSaving = false,
                            error = ErrorBridge.mapArrangementError(error)
                        )
                    }
                }
        }
    }

    fun updatePickupDate(date: String) {
        _uiState.update { it.copy(pickupDate = date) }
    }

    fun updatePickupTime(time: String) {
        _uiState.update { it.copy(pickupTime = time) }
    }

    fun updatePickupLocation(location: String) {
        _uiState.update { it.copy(pickupLocation = location) }
    }

    fun updateNotes(notes: String) {
        _uiState.update { it.copy(notes = notes) }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun clearSuccessMessage() {
        _uiState.update { it.copy(successMessage = null) }
    }
}
