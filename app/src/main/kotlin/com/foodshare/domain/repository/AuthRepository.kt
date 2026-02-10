package com.foodshare.domain.repository

import com.foodshare.domain.model.UserProfile
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for authentication operations
 *
 * Matches iOS: AuthenticationService patterns
 */
interface AuthRepository {

    /**
     * Current authenticated user profile
     */
    val currentUser: Flow<UserProfile?>

    /**
     * Whether user is authenticated
     */
    val isAuthenticated: Flow<Boolean>

    /**
     * Sign in with email and password
     */
    suspend fun signIn(email: String, password: String): Result<UserProfile>

    /**
     * Sign up with email and password
     */
    suspend fun signUp(email: String, password: String, nickname: String? = null): Result<UserProfile>

    /**
     * Sign out current user
     */
    suspend fun signOut(): Result<Unit>

    /**
     * Get current user profile
     */
    suspend fun getCurrentUser(): Result<UserProfile?>

    /**
     * Refresh session
     */
    suspend fun refreshSession(): Result<Unit>

    /**
     * Sign in with Google OAuth
     */
    suspend fun signInWithGoogle(): Result<Unit>

    /**
     * Sign in with Apple OAuth
     */
    suspend fun signInWithApple(): Result<Unit>

    /**
     * Handle OAuth callback/deep link
     */
    suspend fun handleOAuthCallback(url: String): Result<UserProfile>

    /**
     * Update user profile
     */
    suspend fun updateProfile(nickname: String?, bio: String?): Result<UserProfile>
}
