package com.foodshare.core.auth

import com.foodshare.domain.model.UserProfile
import com.foodshare.domain.repository.AuthRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import kotlinx.coroutines.flow.Flow
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class AuthenticationService @Inject constructor(
    private val authRepository: AuthRepository,
    private val supabaseClient: SupabaseClient,
    private val guestManager: GuestManager
) {
    val currentUser: Flow<UserProfile?> = authRepository.currentUser
    val isAuthenticated: Flow<Boolean> = authRepository.isAuthenticated

    suspend fun signInWithEmail(email: String, password: String): Result<UserProfile> {
        guestManager.endGuestSession()
        return authRepository.signIn(email, password)
    }

    suspend fun signInWithGoogle(): Result<Unit> {
        guestManager.endGuestSession()
        return authRepository.signInWithGoogle()
    }

    suspend fun signInWithApple(): Result<Unit> {
        guestManager.endGuestSession()
        return authRepository.signInWithApple()
    }

    suspend fun continueAsGuest() {
        guestManager.startGuestSession()
    }

    suspend fun signOut(): Result<Unit> {
        guestManager.endGuestSession()
        return authRepository.signOut()
    }

    suspend fun isMFAEnabled(): Boolean {
        return try {
            val factors = supabaseClient.auth.mfa.retrieveFactorsForCurrentUser()
            factors.any { it.isVerified }
        } catch (e: Exception) { false }
    }
}
