package com.foodshare.features.donation.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.domain.repository.AuthRepository
import com.foodshare.features.donation.domain.model.Donation
import com.foodshare.features.donation.domain.model.DonationStatus
import com.foodshare.features.donation.domain.model.DonationType
import com.foodshare.features.donation.domain.repository.DonationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.util.UUID
import javax.inject.Inject

data class DonationUiState(
    val donations: List<Donation> = emptyList(),
    val selectedType: DonationType = DonationType.FOOD,
    val notes: String = "",
    val isLoading: Boolean = false,
    val isSaving: Boolean = false,
    val error: String? = null
)

/**
 * ViewModel for donation management.
 *
 * Handles:
 * - Loading user's donations
 * - Creating new donations
 * - Managing donation type selection and notes
 */
@HiltViewModel
class DonationViewModel @Inject constructor(
    private val donationRepository: DonationRepository,
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(DonationUiState())
    val uiState: StateFlow<DonationUiState> = _uiState.asStateFlow()

    private var currentUserId: String? = null

    init {
        loadUserAndDonations()
    }

    private fun loadUserAndDonations() {
        viewModelScope.launch {
            authRepository.getCurrentUser()
                .onSuccess { user ->
                    currentUserId = user?.id
                    currentUserId?.let { loadDonations(it) }
                }
        }
    }

    private fun loadDonations(userId: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            donationRepository.getDonations(userId)
                .onSuccess { donations ->
                    _uiState.update { it.copy(donations = donations, isLoading = false) }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            error = error.message ?: "Failed to load donations",
                            isLoading = false
                        )
                    }
                }
        }
    }

    fun selectType(type: DonationType) {
        _uiState.update { it.copy(selectedType = type) }
    }

    fun updateNotes(notes: String) {
        _uiState.update { it.copy(notes = notes) }
    }

    fun createDonation() {
        val userId = currentUserId ?: run {
            _uiState.update { it.copy(error = "User not authenticated") }
            return
        }

        val state = _uiState.value
        if (state.notes.isBlank()) {
            _uiState.update { it.copy(error = "Please add notes about your donation") }
            return
        }

        viewModelScope.launch {
            _uiState.update { it.copy(isSaving = true, error = null) }

            val donation = Donation(
                id = UUID.randomUUID().toString(),
                donorId = userId,
                recipientId = null,
                listingId = null,
                amount = null,
                currency = "GBP",
                donationType = state.selectedType,
                status = DonationStatus.PENDING,
                notes = state.notes,
                createdAt = null
            )

            donationRepository.createDonation(donation)
                .onSuccess { createdDonation ->
                    _uiState.update {
                        it.copy(
                            donations = listOf(createdDonation) + it.donations,
                            notes = "",
                            isSaving = false
                        )
                    }
                    // Reload donations to get fresh data
                    loadDonations(userId)
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            error = error.message ?: "Failed to create donation",
                            isSaving = false
                        )
                    }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }
}
