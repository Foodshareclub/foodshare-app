//
//  BiometricAuth.swift
//  FoodShare
//
//  Biometric authentication service using LocalAuthentication.
//  Provides Face ID / Touch ID with failed-attempt tracking and lockout.
//


#if !SKIP
import Foundation
import LocalAuthentication

// MARK: - BiometricType

/// Biometric type available on the device
enum BiometricType: Sendable {
    case faceID
    case touchID
    case none

    var iconName: String {
        switch self {
        case .faceID: "faceid"
        case .touchID: "touchid"
        case .none: "lock"
        }
    }

    var displayName: String {
        switch self {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .none: "None"
        }
    }
}

// MARK: - BiometricError

/// Biometric authentication errors
enum BiometricError: Error, LocalizedError {
    case notAvailable
    case authenticationFailed
    case cancelled
    case tooManyAttempts
    case biometricChanged
    case jailbreakDetected
    case lockout

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            "Biometric authentication is not available on this device"
        case .authenticationFailed:
            "Biometric authentication failed"
        case .cancelled:
            "Authentication was cancelled"
        case .tooManyAttempts:
            "Too many failed attempts. Please try again later"
        case .biometricChanged:
            "Biometric data has changed. Please re-authenticate with your password"
        case .jailbreakDetected:
            "Security compromise detected. Biometric authentication is disabled"
        case .lockout:
            "Biometric authentication is locked. Please try again later"
        }
    }
}

// MARK: - BiometricAuth

/// Biometric authentication service with failed-attempt tracking and lockout
@MainActor
final class BiometricAuth: Sendable {
    static let shared = BiometricAuth()

    private static let maxFailedAttempts = 5
    private static let lockoutDuration: TimeInterval = 300 // 5 minutes

    private let failedAttemptsKey = "biometricFailedAttempts"
    private let lockoutEndTimeKey = "biometricLockoutEndTime"
    private let requireBiometricKey = "requireBiometricForSensitiveActions"

    private init() {}

    // MARK: - Public Properties

    /// Number of consecutive failed authentication attempts
    var failedAttempts: Int {
        UserDefaults.standard.integer(forKey: failedAttemptsKey)
    }

    /// Whether the user is currently locked out due to too many failed attempts
    var isLockedOut: Bool {
        guard let endTime = lockoutEndTime else { return false }
        if Date() < endTime {
            return true
        }
        // Lockout expired — clear it
        clearLockout()
        return false
    }

    /// When the current lockout period ends, or nil if not locked out
    var lockoutEndTime: Date? {
        let interval = UserDefaults.standard.double(forKey: lockoutEndTimeKey)
        guard interval > 0 else { return nil }
        let date = Date(timeIntervalSince1970: interval)
        if Date() >= date {
            clearLockout()
            return nil
        }
        return date
    }

    /// Whether biometric authentication is enabled on this device
    var isBiometricEnabled: Bool {
        availableBiometricType != .none
    }

    /// Whether biometric is required for sensitive actions (user preference)
    var requireBiometricForSensitiveActions: Bool {
        get {
            UserDefaults.standard.bool(forKey: requireBiometricKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: requireBiometricKey)
        }
    }

    /// The biometric type available on this device
    var availableBiometricType: BiometricType {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }

        switch context.biometryType {
        case .faceID:
            return .faceID
        case .touchID:
            return .touchID
        default:
            return .none
        }
    }

    // MARK: - Authentication

    /// Authenticate using biometrics
    /// - Parameter reason: Localized reason string shown to the user
    /// - Returns: `true` if authentication succeeded
    /// - Throws: `BiometricError` on failure
    func authenticate(reason: String) async throws -> Bool {
        guard !isLockedOut else {
            throw BiometricError.tooManyAttempts
        }

        guard availableBiometricType != .none else {
            throw BiometricError.notAvailable
        }

        let context = LAContext()
        context.localizedCancelTitle = "Cancel"

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )

            if success {
                resetFailedAttempts()
            }

            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .systemCancel, .appCancel:
                throw BiometricError.cancelled
            case .biometryLockout:
                recordFailedAttempt()
                throw BiometricError.tooManyAttempts
            case .biometryNotAvailable:
                throw BiometricError.notAvailable
            case .biometryNotEnrolled:
                throw BiometricError.notAvailable
            case .invalidContext:
                throw BiometricError.biometricChanged
            default:
                recordFailedAttempt()
                throw BiometricError.authenticationFailed
            }
        }
    }

    /// Enable biometrics for the app (prompts the user to authenticate)
    func enableBiometrics() async throws {
        guard availableBiometricType != .none else {
            throw BiometricError.notAvailable
        }

        let success = try await authenticate(reason: "Enable biometric authentication for FoodShare")
        if success {
            requireBiometricForSensitiveActions = true
        } else {
            throw BiometricError.authenticationFailed
        }
    }

    /// Disable biometrics for the app
    func disableBiometrics() {
        requireBiometricForSensitiveActions = false
    }

    // MARK: - Private Helpers

    private func recordFailedAttempt() {
        let attempts = failedAttempts + 1
        UserDefaults.standard.set(attempts, forKey: failedAttemptsKey)

        if attempts >= Self.maxFailedAttempts {
            let endTime = Date().addingTimeInterval(Self.lockoutDuration)
            UserDefaults.standard.set(endTime.timeIntervalSince1970, forKey: lockoutEndTimeKey)
        }
    }

    private func resetFailedAttempts() {
        UserDefaults.standard.set(0, forKey: failedAttemptsKey)
        UserDefaults.standard.removeObject(forKey: lockoutEndTimeKey)
    }

    private nonisolated func clearLockout() {
        UserDefaults.standard.set(0, forKey: failedAttemptsKey)
        UserDefaults.standard.removeObject(forKey: lockoutEndTimeKey)
    }
}

#endif
