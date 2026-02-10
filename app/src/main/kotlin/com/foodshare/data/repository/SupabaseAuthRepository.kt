package com.foodshare.data.repository

import android.content.Context
import android.content.Intent
import android.net.Uri
import com.foodshare.data.dto.UserProfileDto
import com.foodshare.domain.model.UserProfile
import com.foodshare.domain.repository.AuthRepository
import dagger.hilt.android.qualifiers.ApplicationContext
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Apple
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of AuthRepository
 *
 * Handles authentication operations using supabase-kt
 */
@Singleton
class SupabaseAuthRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    @ApplicationContext private val context: Context
) : AuthRepository {

    companion object {
        private const val REDIRECT_URL = "club.foodshare://auth"
    }

    override val currentUser: Flow<UserProfile?>
        get() = supabaseClient.auth.sessionStatus.map { status ->
            when (status) {
                is SessionStatus.Authenticated -> {
                    try {
                        fetchUserProfile(status.session.user?.id ?: return@map null)
                    } catch (e: Exception) {
                        null
                    }
                }
                else -> null
            }
        }

    override val isAuthenticated: Flow<Boolean>
        get() = supabaseClient.auth.sessionStatus.map { status ->
            status is SessionStatus.Authenticated
        }

    override suspend fun signIn(email: String, password: String): Result<UserProfile> {
        return runCatching {
            supabaseClient.auth.signInWith(Email) {
                this.email = email
                this.password = password
            }

            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User ID not found after sign in")

            fetchUserProfile(userId)
        }
    }

    override suspend fun signUp(
        email: String,
        password: String,
        nickname: String?
    ): Result<UserProfile> {
        return runCatching {
            supabaseClient.auth.signUpWith(Email) {
                this.email = email
                this.password = password
            }

            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User ID not found after sign up")

            // Create initial profile
            createUserProfile(userId, email, nickname)

            fetchUserProfile(userId)
        }
    }

    override suspend fun signOut(): Result<Unit> {
        return runCatching {
            supabaseClient.auth.signOut()
        }
    }

    override suspend fun getCurrentUser(): Result<UserProfile?> {
        return runCatching {
            val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return@runCatching null
            fetchUserProfile(userId)
        }
    }

    override suspend fun refreshSession(): Result<Unit> {
        return runCatching {
            supabaseClient.auth.refreshCurrentSession()
        }
    }

    private suspend fun fetchUserProfile(userId: String): UserProfile {
        return supabaseClient.from("profiles")
            .select {
                filter { eq("id", userId) }
            }
            .decodeSingle<UserProfileDto>()
            .toDomain()
    }

    private suspend fun createUserProfile(userId: String, email: String, nickname: String?) {
        val profileData = buildJsonObject {
            put("id", userId)
            put("email", email)
            nickname?.let { put("nickname", it) }
        }

        supabaseClient.from("profiles")
            .insert(profileData)
    }

    override suspend fun signInWithGoogle(): Result<Unit> {
        return runCatching {
            supabaseClient.auth.signInWith(Google)
        }
    }

    override suspend fun signInWithApple(): Result<Unit> {
        return runCatching {
            supabaseClient.auth.signInWith(Apple)
        }
    }

    override suspend fun handleOAuthCallback(url: String): Result<UserProfile> {
        return runCatching {
            // Parse the OAuth callback URL
            val uri = Uri.parse(url)

            // For PKCE flow, extract the code and exchange it for a session
            val code = uri.getQueryParameter("code")
            if (code != null) {
                // Exchange the code for a session
                supabaseClient.auth.exchangeCodeForSession(code)
            } else {
                // Fallback: Extract tokens from the URL fragment or query parameters (implicit flow)
                val accessToken = uri.getQueryParameter("access_token")
                    ?: uri.fragment?.let { fragment ->
                        Uri.parse("?$fragment").getQueryParameter("access_token")
                    }

                val refreshToken = uri.getQueryParameter("refresh_token")
                    ?: uri.fragment?.let { fragment ->
                        Uri.parse("?$fragment").getQueryParameter("refresh_token")
                    }

                if (accessToken != null && refreshToken != null) {
                    supabaseClient.auth.importSession(
                        io.github.jan.supabase.auth.user.UserSession(
                            accessToken = accessToken,
                            refreshToken = refreshToken,
                            expiresIn = 3600,
                            tokenType = "bearer",
                            user = null
                        )
                    )
                }
            }

            // Get or create user profile
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("No user after OAuth callback")

            val email = supabaseClient.auth.currentUserOrNull()?.email ?: ""

            // Try to fetch existing profile, create if not exists
            try {
                fetchUserProfile(userId)
            } catch (e: Exception) {
                createUserProfile(userId, email, null)
                fetchUserProfile(userId)
            }
        }
    }

    override suspend fun updateProfile(nickname: String?, bio: String?): Result<UserProfile> {
        return runCatching {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: throw IllegalStateException("User not authenticated")

            val updateData = buildJsonObject {
                nickname?.let { put("nickname", it) }
                bio?.let { put("bio", it) }
            }

            supabaseClient.from("profiles")
                .update(updateData) {
                    filter { eq("id", userId) }
                }

            fetchUserProfile(userId)
        }
    }
}
