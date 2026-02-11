package com.foodshare.features.settings.data.repository

import com.foodshare.features.settings.domain.repository.*
import com.foodshare.features.settings.presentation.*
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of SettingsRepository
 */
@Singleton
class SupabaseSettingsRepository @Inject constructor(
    private val supabaseClient: SupabaseClient
) : SettingsRepository {

    override suspend fun getCurrentUserId(): String? {
        return supabaseClient.auth.currentUserOrNull()?.id
    }

    // Blocked Users
    override suspend fun getBlockedUsers(): Result<List<BlockedUser>> {
        return try {
            val userId = getCurrentUserId() ?: return Result.failure(IllegalStateException("Not authenticated"))

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

            Result.success(blockedUserDetails)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun unblockUser(userId: String): Result<Unit> {
        return try {
            val currentUserId = getCurrentUserId() ?: return Result.failure(IllegalStateException("Not authenticated"))

            supabaseClient.from("blocked_users")
                .delete {
                    filter {
                        eq("blocker_id", currentUserId)
                        eq("blocked_id", userId)
                    }
                }

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // Two Factor Auth
    override suspend fun getTwoFactorStatus(): Result<TwoFactorStatus> {
        return try {
            val user = supabaseClient.auth.currentUserOrNull()
                ?: return Result.failure(IllegalStateException("Not authenticated"))

            val hasMFA = user.factors?.isNotEmpty() == true
            val enrolledFactors = user.factors?.size ?: 0

            Result.success(TwoFactorStatus(
                isEnabled = hasMFA,
                enrolledFactors = enrolledFactors
            ))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun enableTwoFactor(friendlyName: String): Result<TwoFactorSetupData> {
        return try {
            val enrollResult = supabaseClient.auth.mfa.enroll(
                factorType = io.github.jan.supabase.auth.mfa.FactorType.TOTP,
                friendlyName = friendlyName
            )

            Result.success(TwoFactorSetupData(
                factorId = enrollResult.id,
                qrCode = enrollResult.data.qrCode,
                secret = enrollResult.data.secret
            ))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun verifyTwoFactor(factorId: String, code: String): Result<Unit> {
        return try {
            supabaseClient.auth.mfa.createChallengeAndVerify(
                factorId = factorId,
                code = code
            )
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun disableTwoFactor(): Result<Unit> {
        return try {
            val user = supabaseClient.auth.currentUserOrNull()
                ?: return Result.failure(IllegalStateException("Not authenticated"))

            user.factors?.forEach { factor ->
                supabaseClient.auth.mfa.unenroll(factor.id)
            }

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // Privacy Settings
    override suspend fun getPrivacySettings(): Result<PrivacySettings> {
        return try {
            val userId = getCurrentUserId() ?: return Result.failure(IllegalStateException("Not authenticated"))

            val profile = supabaseClient.from("profiles")
                .select {
                    filter {
                        eq("id", userId)
                    }
                }
                .decodeSingle<ProfilePrivacyResponse>()

            val settings = profile.privacy_settings ?: PrivacySettings()
            Result.success(settings)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun updatePrivacySettings(settings: PrivacySettings): Result<Unit> {
        return try {
            val userId = getCurrentUserId() ?: return Result.failure(IllegalStateException("Not authenticated"))

            val privacySettings = buildJsonObject {
                put("profileVisible", settings.profileVisible)
                put("showLocation", settings.showLocation)
                put("allowMessages", settings.allowMessages)
            }

            supabaseClient.from("profiles")
                .update({
                    set("privacy_settings", privacySettings)
                }) {
                    filter {
                        eq("id", userId)
                    }
                }

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // Login Security
    override suspend fun getLoginHistory(): Result<List<LoginRecord>> {
        return try {
            // Placeholder - would need custom implementation
            Result.success(emptyList())
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun getActiveSessions(): Result<List<ActiveSession>> {
        return try {
            val currentSession = supabaseClient.auth.currentSessionOrNull()
            val sessions = mutableListOf<ActiveSession>()

            currentSession?.let { session ->
                sessions.add(
                    ActiveSession(
                        id = session.accessToken.take(12),
                        deviceName = "Current Device",
                        lastActiveAt = "Now",
                        isCurrent = true
                    )
                )
            }

            Result.success(sessions)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun revokeSession(sessionId: String): Result<Unit> {
        return try {
            // Placeholder - Supabase doesn't have a direct way to revoke individual sessions
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    override suspend fun changePassword(currentPassword: String, newPassword: String): Result<Unit> {
        return try {
            // Re-authenticate with current password to verify identity
            val user = supabaseClient.auth.currentUserOrNull()
            val email = user?.email

            if (email != null) {
                supabaseClient.auth.signInWith(Email) {
                    this.email = email
                    this.password = currentPassword
                }
            }

            // Update to new password
            supabaseClient.auth.updateUser {
                password = newPassword
            }

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // Account Deletion
    override suspend fun requestAccountDeletion(reason: String?, password: String): Result<Unit> {
        return try {
            // Re-authenticate with password to verify identity
            val user = supabaseClient.auth.currentUserOrNull()
            val email = user?.email
                ?: throw IllegalStateException("No email found for current user")

            supabaseClient.auth.signInWith(Email) {
                this.email = email
                this.password = password
            }

            // Call the RPC function to request account deletion
            supabaseClient.postgrest.rpc(
                function = "request_account_deletion",
                parameters = buildJsonObject {
                    put("reason", reason ?: "user_requested")
                }
            )

            // Sign out the user
            supabaseClient.auth.signOut()

            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // Security Score
    override suspend fun getSecurityScore(): Result<SecurityScoreData> {
        return try {
            val user = supabaseClient.auth.currentUserOrNull()
                ?: return Result.failure(IllegalStateException("Not authenticated"))

            val emailVerified = user.emailConfirmedAt != null
            val hasMFA = user.factors?.isNotEmpty() == true
            val hasStrongPassword = true // Assume true for now
            val profileComplete = checkProfileComplete(user.id).getOrDefault(false)

            Result.success(SecurityScoreData(
                emailVerified = emailVerified,
                hasMFA = hasMFA,
                hasStrongPassword = hasStrongPassword,
                profileComplete = profileComplete
            ))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    // Profile Completeness
    override suspend fun checkProfileComplete(userId: String): Result<Boolean> {
        return try {
            val profile = supabaseClient.from("profiles")
                .select {
                    filter {
                        eq("id", userId)
                    }
                }
                .decodeSingle<ProfileCompletenessCheck>()

            val isComplete = !profile.nickname.isNullOrBlank() && !profile.bio.isNullOrBlank()
            Result.success(isComplete)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}

// DTOs for Supabase queries

@Serializable
private data class BlockedUserRecord(
    val blocker_id: String,
    val blocked_id: String,
    val created_at: String
)

@Serializable
private data class BlockedUserProfile(
    val id: String,
    val nickname: String?,
    val avatar_url: String?
)

@Serializable
private data class ProfilePrivacyResponse(
    val id: String,
    val privacy_settings: PrivacySettings? = null
)

@Serializable
private data class ProfileCompletenessCheck(
    val id: String,
    val nickname: String? = null,
    val bio: String? = null
)
