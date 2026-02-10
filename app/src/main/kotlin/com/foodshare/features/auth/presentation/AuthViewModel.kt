package com.foodshare.features.auth.presentation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.foodshare.core.errors.ErrorBridge
import com.foodshare.core.validation.PasswordStrengthLevel
import com.foodshare.core.validation.ValidationBridge
import com.foodshare.domain.model.UserProfile
import com.foodshare.domain.repository.AuthRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * ViewModel for authentication screens
 *
 * Handles sign in, sign up, and auth state management
 */
@HiltViewModel
class AuthViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    val currentUser: StateFlow<UserProfile?> = authRepository.currentUser
        .stateIn(viewModelScope, SharingStarted.Eagerly, null)

    val isAuthenticated: StateFlow<Boolean> = authRepository.isAuthenticated
        .stateIn(viewModelScope, SharingStarted.Eagerly, false)

    init {
        checkCurrentSession()
    }

    private fun checkCurrentSession() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            authRepository.getCurrentUser()
                .onSuccess { user ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            authState = if (user != null) AuthState.Authenticated else AuthState.Unauthenticated
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            authState = AuthState.Unauthenticated
                        )
                    }
                }
        }
    }

    fun updateEmail(email: String) {
        _uiState.update { it.copy(email = email, emailError = null) }
    }

    fun updatePassword(password: String) {
        // Calculate password strength using Swift-backed ValidationBridge
        val strength = if (password.isNotEmpty()) {
            ValidationBridge.evaluatePasswordStrength(password)
        } else {
            PasswordStrengthLevel.NONE
        }

        _uiState.update {
            it.copy(
                password = password,
                passwordError = null,
                passwordStrength = strength
            )
        }
    }

    fun updateConfirmPassword(confirmPassword: String) {
        _uiState.update { it.copy(confirmPassword = confirmPassword, confirmPasswordError = null) }
    }

    fun updateNickname(nickname: String) {
        _uiState.update { it.copy(nickname = nickname) }
    }

    fun toggleAuthMode() {
        _uiState.update {
            it.copy(
                isSignUp = !it.isSignUp,
                error = null,
                emailError = null,
                passwordError = null,
                confirmPasswordError = null
            )
        }
    }

    fun signIn() {
        val state = _uiState.value

        // Validate
        if (!validateEmail(state.email)) return
        if (!validatePassword(state.password)) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            authRepository.signIn(state.email, state.password)
                .onSuccess { user ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            authState = AuthState.Authenticated,
                            error = null
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapAuthError(error)
                        )
                    }
                }
        }
    }

    fun signUp() {
        val state = _uiState.value

        // Validate
        if (!validateEmail(state.email)) return
        if (!validatePassword(state.password)) return
        if (!validateConfirmPassword(state.password, state.confirmPassword)) return

        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            authRepository.signUp(
                email = state.email,
                password = state.password,
                nickname = state.nickname.takeIf { it.isNotBlank() }
            )
                .onSuccess { user ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            authState = AuthState.Authenticated,
                            error = null
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapAuthError(error)
                        )
                    }
                }
        }
    }

    fun signOut() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }

            authRepository.signOut()
                .onSuccess {
                    _uiState.update {
                        AuthUiState(authState = AuthState.Unauthenticated)
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = "Failed to sign out"
                        )
                    }
                }
        }
    }

    fun signInWithGoogle() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            authRepository.signInWithGoogle()
                .onSuccess {
                    // OAuth flow started - waiting for callback
                    // The session will be handled by handleOAuthCallback
                    _uiState.update { it.copy(isLoading = false) }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapAuthError(error)
                        )
                    }
                }
        }
    }

    fun signInWithApple() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            authRepository.signInWithApple()
                .onSuccess {
                    // OAuth flow started - waiting for callback
                    _uiState.update { it.copy(isLoading = false) }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapAuthError(error)
                        )
                    }
                }
        }
    }

    fun handleOAuthCallback(url: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true, error = null) }

            authRepository.handleOAuthCallback(url)
                .onSuccess {
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            authState = AuthState.Authenticated,
                            error = null
                        )
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.copy(
                            isLoading = false,
                            error = ErrorBridge.mapAuthError(error)
                        )
                    }
                }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    /**
     * Validate email using Swift-backed ValidationBridge.
     *
     * Delegates to Swift AuthValidator when available.
     */
    private fun validateEmail(email: String): Boolean {
        val error = ValidationBridge.validateEmail(email)
        if (error != null) {
            _uiState.update { it.copy(emailError = error) }
            return false
        }
        return true
    }

    /**
     * Validate password using Swift-backed ValidationBridge.
     *
     * Delegates to Swift AuthValidator when available.
     */
    private fun validatePassword(password: String): Boolean {
        val error = ValidationBridge.validatePassword(password)
        if (error != null) {
            _uiState.update { it.copy(passwordError = error) }
            return false
        }
        return true
    }

    private fun validateConfirmPassword(password: String, confirmPassword: String): Boolean {
        return if (confirmPassword != password) {
            _uiState.update { it.copy(confirmPasswordError = "Passwords do not match") }
            false
        } else {
            true
        }
    }
}

/**
 * UI state for authentication screens
 */
data class AuthUiState(
    val email: String = "",
    val password: String = "",
    val confirmPassword: String = "",
    val nickname: String = "",
    val isSignUp: Boolean = false,
    val isLoading: Boolean = false,
    val error: String? = null,
    val emailError: String? = null,
    val passwordError: String? = null,
    val confirmPasswordError: String? = null,
    val authState: AuthState = AuthState.Idle,
    val passwordStrength: PasswordStrengthLevel = PasswordStrengthLevel.NONE
)

/**
 * Authentication state
 */
sealed class AuthState {
    data object Idle : AuthState()
    data object Unauthenticated : AuthState()
    data object Authenticated : AuthState()
}
