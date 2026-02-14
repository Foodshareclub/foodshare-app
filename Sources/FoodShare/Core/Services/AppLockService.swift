//
//  AppLockService.swift
//  Foodshare
//
//  Service for managing app lock with biometric authentication
//  Leverages FoodShareSecurity's BiometricAuth for actual authentication
//

import Foundation
import OSLog
import SwiftUI
import FoodShareSecurity

/// Service for managing app-level biometric lock
@MainActor
@Observable
final class AppLockService {
    // MARK: - Singleton

    static let shared = AppLockService()

    // MARK: - Observable State

    /// Whether the app is currently locked
    private(set) var isLocked = false

    /// Whether biometric authentication is in progress
    private(set) var isAuthenticating = false

    /// Last authentication error message
    private(set) var lastError: String?

    /// Time when the app was last locked
    private(set) var lockedAt: Date?

    // MARK: - Settings (Persisted)

    /// Whether app lock is enabled
    @ObservationIgnored
    @AppStorage("app_lock_enabled") var isEnabled = false

    /// Whether to lock when going to background
    @ObservationIgnored
    @AppStorage("lock_on_background") var lockOnBackground = true

    /// Delay in seconds before locking after going to background (0 = immediate)
    @ObservationIgnored
    @AppStorage("lock_delay_seconds") var lockDelay: Int = 0

    /// Whether to require biometric on app launch
    @ObservationIgnored
    @AppStorage("lock_on_launch") var lockOnLaunch = true

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AppLock")
    private var backgroundTask: Task<Void, Never>?

    // MARK: - Computed Properties

    /// Available biometric type (Face ID, Touch ID, or none)
    var availableBiometricType: BiometricAuth.BiometricType {
        BiometricAuth.shared.availableBiometricType
    }

    /// Whether biometric authentication is available on this device
    var isBiometricAvailable: Bool {
        availableBiometricType != .none
    }

    /// Display name for the available biometric type
    var biometricDisplayName: String {
        availableBiometricType.displayName
    }

    /// SF Symbol icon name for the available biometric type
    var biometricIconName: String {
        availableBiometricType.iconName
    }

    /// Lock delay options for settings UI
    static let lockDelayOptions: [(Int, String)] = [
        (0, "Immediately"),
        (5, "5 seconds"),
        (15, "15 seconds"),
        (30, "30 seconds"),
        (60, "1 minute"),
        (300, "5 minutes"),
    ]

    // MARK: - Initialization

    private init() {
        logger.info("AppLockService initialized (enabled: \(self.isEnabled), biometric: \(self.biometricDisplayName))")

        // Lock on launch if enabled
        if isEnabled && lockOnLaunch {
            isLocked = true
            lockedAt = Date()
        }
    }

    // MARK: - Public Methods

    /// Lock the app if app lock is enabled
    func lock() {
        guard isEnabled else { return }

        isLocked = true
        lockedAt = Date()
        lastError = nil
        logger.info("App locked")
    }

    /// Attempt to unlock the app using biometric authentication
    /// - Returns: True if unlock was successful
    @discardableResult
    func unlock() async -> Bool {
        guard isLocked else { return true }
        guard !isAuthenticating else { return false }

        isAuthenticating = true
        lastError = nil

        defer {
            isAuthenticating = false
        }

        do {
            let success = try await BiometricAuth.shared.authenticate(
                reason: "Unlock Foodshare"
            )

            if success {
                isLocked = false
                lockedAt = nil
                logger.info("App unlocked successfully")
                return true
            } else {
                lastError = "Authentication failed"
                logger.warning("Biometric authentication returned false")
                return false
            }
        } catch let error as BiometricError {
            lastError = error.errorDescription
            logger.error("Biometric authentication failed: \(error.localizedDescription)")
            return false
        } catch {
            lastError = error.localizedDescription
            logger.error("Unexpected authentication error: \(error.localizedDescription)")
            return false
        }
    }

    /// Enable app lock (requires successful biometric authentication)
    /// - Returns: True if app lock was enabled successfully
    @discardableResult
    func enable() async -> Bool {
        guard isBiometricAvailable else {
            lastError = "Biometric authentication is not available on this device"
            return false
        }

        isAuthenticating = true
        lastError = nil

        defer {
            isAuthenticating = false
        }

        do {
            let success = try await BiometricAuth.shared.authenticate(
                reason: "Enable \(biometricDisplayName) for Foodshare"
            )

            if success {
                isEnabled = true
                logger.info("App lock enabled")
                return true
            } else {
                lastError = "Authentication failed"
                return false
            }
        } catch let error as BiometricError {
            lastError = error.errorDescription
            logger.error("Failed to enable app lock: \(error.localizedDescription)")
            return false
        } catch {
            lastError = error.localizedDescription
            logger.error("Unexpected error enabling app lock: \(error.localizedDescription)")
            return false
        }
    }

    /// Disable app lock
    func disable() {
        isEnabled = false
        isLocked = false
        lockedAt = nil
        lastError = nil
        logger.info("App lock disabled")
    }

    /// Handle scene phase changes for automatic locking
    /// - Parameter phase: The new scene phase
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            handleBackgroundTransition()
        case .active:
            handleActiveTransition()
        case .inactive:
            // Do nothing on inactive - waiting for background or active
            break
        @unknown default:
            break
        }
    }

    // MARK: - Private Methods

    private func handleBackgroundTransition() {
        guard isEnabled, lockOnBackground else { return }

        backgroundTask?.cancel()

        if lockDelay == 0 {
            // Lock immediately
            lock()
        } else {
            // Schedule delayed lock
            backgroundTask = Task {
                try? await Task.sleep(for: .seconds(lockDelay))

                if !Task.isCancelled {
                    lock()
                }
            }
        }
    }

    private func handleActiveTransition() {
        // Cancel any pending lock
        backgroundTask?.cancel()
        backgroundTask = nil

        // Don't auto-unlock here - user must authenticate
    }

    /// Clear any authentication errors
    func clearError() {
        lastError = nil
    }
}

// MARK: - Lock Delay Option

/// Represents a lock delay option for the settings UI
struct LockDelayOption: Identifiable, Hashable {
    let seconds: Int
    let displayName: String

    var id: Int { seconds }

    static let options: [LockDelayOption] = [
        LockDelayOption(seconds: 0, displayName: "Immediately"),
        LockDelayOption(seconds: 5, displayName: "5 seconds"),
        LockDelayOption(seconds: 15, displayName: "15 seconds"),
        LockDelayOption(seconds: 30, displayName: "30 seconds"),
        LockDelayOption(seconds: 60, displayName: "1 minute"),
        LockDelayOption(seconds: 300, displayName: "5 minutes"),
    ]
}
