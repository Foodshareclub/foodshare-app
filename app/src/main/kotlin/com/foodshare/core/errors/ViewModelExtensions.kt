package com.foodshare.core.errors

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Launches a coroutine in [viewModelScope] with standardized error handling.
 *
 * This extension provides:
 * - Automatic error catching and mapping through domain-specific error mappers
 * - Consistent error handling pattern across all ViewModels
 * - Simplified error callback interface
 *
 * The caught exception is mapped to a user-friendly error message using the
 * appropriate domain-specific error mapper. ViewModels should typically pass
 * this error message to their UI state.
 *
 * Example usage:
 * ```
 * fun loadData() {
 *     launchSafe(
 *         onError = { errorMessage ->
 *             _uiState.update { it.copy(error = errorMessage) }
 *         }
 *     ) {
 *         val data = repository.getData()
 *         _uiState.update { it.copy(data = data) }
 *     }
 * }
 * ```
 *
 * For domain-specific error handling, ViewModels can use the appropriate
 * ErrorBridge mapper (e.g., mapListingError, mapProfileError, etc.):
 * ```
 * fun updateProfile() {
 *     launchSafe(
 *         onError = { errorMessage ->
 *             _uiState.update { it.copy(error = errorMessage) }
 *         }
 *     ) {
 *         repository.updateProfile(profile)
 *     }
 * }
 * ```
 *
 * @param onError Callback invoked with user-friendly error message when an exception occurs.
 *                Defaults to no-op if not provided.
 * @param block The coroutine block to execute
 */
fun ViewModel.launchSafe(
    onError: (String) -> Unit = {},
    block: suspend CoroutineScope.() -> Unit
) {
    viewModelScope.launch {
        try {
            block()
        } catch (e: Exception) {
            // Use the general error message, or fallback to exception message
            val errorMessage = e.message ?: "An unexpected error occurred"
            onError(errorMessage)
        }
    }
}
