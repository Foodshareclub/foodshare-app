//
//  SecurityScoreService.swift
//  Foodshare
//
//  Security score calculator for user account security level
//  Provides visual feedback on account protection status
//

import Foundation
import FoodShareSecurity
import SwiftUI
import FoodShareSecurity

// MARK: - Security Score Level

enum SecurityScoreLevel: String, Sendable {
    case critical   // 0-25
    case low        // 26-50
    case medium     // 51-75
    case high       // 76-100

    var displayName: String {
        switch self {
        case .critical: "Critical"
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    /// Localized display name using translation service
    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .critical: t.t("security.score_level.critical")
        case .low: t.t("security.score_level.low")
        case .medium: t.t("security.score_level.medium")
        case .high: t.t("security.score_level.high")
        }
    }

    var color: Color {
        switch self {
        case .critical: .red
        case .low: .orange
        case .medium: .yellow
        case .high: .green
        }
    }

    var icon: String {
        switch self {
        case .critical: "exclamationmark.shield.fill"
        case .low: "shield.fill"
        case .medium: "shield.lefthalf.filled"
        case .high: "checkmark.shield.fill"
        }
    }

    var recommendation: String {
        switch self {
        case .critical:
            "Your account is at risk. Enable biometrics and verify your email immediately."
        case .low:
            "Your account needs better protection. Consider enabling more security features."
        case .medium:
            "Good start! Enable a few more features for maximum protection."
        case .high:
            "Excellent! Your account is well protected."
        }
    }

    /// Localized recommendation using translation service
    @MainActor
    func localizedRecommendation(using t: EnhancedTranslationService) -> String {
        switch self {
        case .critical: t.t("security.recommendations.critical")
        case .low: t.t("security.recommendations.low")
        case .medium: t.t("security.recommendations.medium")
        case .high: t.t("security.recommendations.high")
        }
    }
}

// MARK: - Security Check Item

struct SecurityCheckItem: Identifiable, Sendable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let points: Int
    let isEnabled: Bool
    let action: SecurityAction?

    enum SecurityAction: Sendable {
        case enableBiometrics
        case verifyEmail
        case enablePrivacyBlur
        case enableScreenRecordingWarning
        case setSessionTimeout
        case enableClipboardClear
        case enableSensitiveActionProtection
    }
}

// MARK: - Security Score Service

@MainActor
final class SecurityScoreService {

    // MARK: - Singleton

    static let shared = SecurityScoreService()

    private init() {}

    // MARK: - Score Calculation

    /// Calculate current security score (0-100)
    func calculateScore() -> Int {
        let checks = getSecurityChecks()
        let totalPoints = checks.reduce(0) { $0 + $1.points }
        let earnedPoints = checks.filter { $0.isEnabled }.reduce(0) { $0 + $1.points }

        guard totalPoints > 0 else { return 0 }
        return Int((Double(earnedPoints) / Double(totalPoints)) * 100)
    }

    /// Get security level based on score
    func getSecurityLevel() -> SecurityScoreLevel {
        let score = calculateScore()

        switch score {
        case 0...25: return .critical
        case 26...50: return .low
        case 51...75: return .medium
        default: return .high
        }
    }

    /// Get all security check items
    func getSecurityChecks() -> [SecurityCheckItem] {
        let biometricService = BiometricAuth.shared
        let privacyService = PrivacyProtectionService.shared

        return [
            // Biometrics (25 points)
            SecurityCheckItem(
                id: "biometrics",
                title: "Biometric Authentication",
                description: "Use Face ID or Touch ID to unlock the app",
                icon: biometricService.availableBiometricType.iconName,
                points: 25,
                isEnabled: biometricService.isBiometricEnabled,
                action: .enableBiometrics
            ),

            // Email verified (20 points)
            SecurityCheckItem(
                id: "email_verified",
                title: "Email Verified",
                description: "Verify your email address for account recovery",
                icon: "envelope.badge.shield.half.filled",
                points: 20,
                isEnabled: AuthenticationService.shared.isEmailVerified,
                action: .verifyEmail
            ),

            // Privacy blur (15 points)
            SecurityCheckItem(
                id: "privacy_blur",
                title: "Privacy Screen",
                description: "Hide app content in app switcher",
                icon: "eye.slash.fill",
                points: 15,
                isEnabled: privacyService.privacyBlurEnabled,
                action: .enablePrivacyBlur
            ),

            // Screen recording warning (10 points)
            SecurityCheckItem(
                id: "screen_recording",
                title: "Screen Recording Alert",
                description: "Get warned when screen recording is active",
                icon: "record.circle",
                points: 10,
                isEnabled: privacyService.screenRecordingWarningEnabled,
                action: .enableScreenRecordingWarning
            ),

            // Session timeout (10 points)
            SecurityCheckItem(
                id: "session_timeout",
                title: "Session Timeout",
                description: "Auto sign-out after inactivity",
                icon: "timer",
                points: 10,
                isEnabled: privacyService.sessionTimeoutDuration < .infinity,
                action: .setSessionTimeout
            ),

            // Clipboard auto-clear (10 points)
            SecurityCheckItem(
                id: "clipboard_clear",
                title: "Clipboard Protection",
                description: "Auto-clear clipboard after copying sensitive data",
                icon: "doc.on.clipboard",
                points: 10,
                isEnabled: privacyService.clipboardAutoClearEnabled,
                action: .enableClipboardClear
            ),

            // Sensitive action protection (10 points)
            SecurityCheckItem(
                id: "sensitive_actions",
                title: "Sensitive Action Protection",
                description: "Require authentication for critical actions",
                icon: "hand.raised.fill",
                points: 10,
                isEnabled: biometricService.requireBiometricForSensitiveActions,
                action: .enableSensitiveActionProtection
            )
        ]
    }

    /// Get incomplete security checks (for recommendations)
    func getIncompleteChecks() -> [SecurityCheckItem] {
        getSecurityChecks().filter { !$0.isEnabled }
    }

    /// Get completed security checks
    func getCompletedChecks() -> [SecurityCheckItem] {
        getSecurityChecks().filter { $0.isEnabled }
    }
}
