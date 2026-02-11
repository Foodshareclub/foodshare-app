package com.foodshare.features.settings.domain.repository

import com.foodshare.features.settings.presentation.*

/**
 * Repository for managing user settings and security features
 */
interface SettingsRepository {
    suspend fun getCurrentUserId(): String?

    // Blocked Users
    suspend fun getBlockedUsers(): Result<List<BlockedUser>>
    suspend fun unblockUser(userId: String): Result<Unit>

    // Two Factor Auth
    suspend fun getTwoFactorStatus(): Result<TwoFactorStatus>
    suspend fun enableTwoFactor(friendlyName: String): Result<TwoFactorSetupData>
    suspend fun verifyTwoFactor(factorId: String, code: String): Result<Unit>
    suspend fun disableTwoFactor(): Result<Unit>

    // Privacy Settings
    suspend fun getPrivacySettings(): Result<PrivacySettings>
    suspend fun updatePrivacySettings(settings: PrivacySettings): Result<Unit>

    // Login Security
    suspend fun getLoginHistory(): Result<List<LoginRecord>>
    suspend fun getActiveSessions(): Result<List<ActiveSession>>
    suspend fun revokeSession(sessionId: String): Result<Unit>
    suspend fun changePassword(currentPassword: String, newPassword: String): Result<Unit>

    // Account Deletion
    suspend fun requestAccountDeletion(reason: String?, password: String): Result<Unit>

    // Security Score
    suspend fun getSecurityScore(): Result<SecurityScoreData>

    // Profile Completeness
    suspend fun checkProfileComplete(userId: String): Result<Boolean>
}

/**
 * Two-factor authentication status
 */
data class TwoFactorStatus(
    val isEnabled: Boolean,
    val enrolledFactors: Int
)

/**
 * Two-factor setup data
 */
data class TwoFactorSetupData(
    val factorId: String,
    val qrCode: String,
    val secret: String
)

/**
 * Security score data
 */
data class SecurityScoreData(
    val emailVerified: Boolean,
    val hasMFA: Boolean,
    val hasStrongPassword: Boolean,
    val profileComplete: Boolean
)

/**
 * Login record data
 */
data class LoginRecord(
    val id: String,
    val timestamp: String,
    val ipAddress: String,
    val deviceInfo: String
)
