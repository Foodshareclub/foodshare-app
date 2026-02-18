//
//  OnboardingManager.swift
//  Foodshare
//
//  Onboarding state management following CareEcho pattern
//  Tracks whether user has completed initial legal disclaimers
//


#if !SKIP
import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class OnboardingManager {
    // MARK: - Singleton

    static let shared = OnboardingManager()

    // MARK: - State

    /// Whether the user has completed the onboarding flow
    var hasCompletedOnboarding: Bool {
        didSet {
            persistOnboardingState()
            logger.info("🔄 [ONBOARDING] Completion state changed: \(self.hasCompletedOnboarding)")
        }
    }

    /// Timestamp when onboarding was completed
    var onboardingCompletedAt: Date?

    /// Current onboarding version (for future migrations)
    var onboardingVersion: Int {
        didSet {
            userDefaults.set(onboardingVersion, forKey: onboardingVersionKey)
        }
    }

    // MARK: - Private

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "OnboardingManager")
    private let userDefaults = UserDefaults.standard
    private let onboardingCompletedKey = "foodshare.onboarding.isCompleted"
    private let onboardingCompletedAtKey = "foodshare.onboarding.completedAt"
    private let onboardingVersionKey = "foodshare.onboarding.version"

    /// Current required onboarding version
    /// Increment this to force users to re-complete onboarding after major changes
    private static let requiredOnboardingVersion = 1

    // MARK: - Initialization

    private init() {
        // Restore onboarding state from UserDefaults
        let savedVersion = userDefaults.integer(forKey: onboardingVersionKey)
        onboardingVersion = savedVersion

        // Check if onboarding needs to be re-done due to version change
        if savedVersion < Self.requiredOnboardingVersion {
            hasCompletedOnboarding = false
            onboardingCompletedAt = nil
        } else {
            hasCompletedOnboarding = userDefaults.bool(forKey: onboardingCompletedKey)
            if let completedTimestamp = userDefaults.object(forKey: onboardingCompletedAtKey) as? Date {
                onboardingCompletedAt = completedTimestamp
            }
        }

        logger
            .info(
                "🔐 [ONBOARDING] OnboardingManager initialized, hasCompleted: \(self.hasCompletedOnboarding), version: \(self.onboardingVersion)",
            )
    }

    // MARK: - Public Methods

    /// Mark onboarding as completed
    /// Call this when user accepts terms and proceeds from OnboardingView
    func completeOnboarding() {
        logger.info("✅ [ONBOARDING] Marking onboarding as completed")
        hasCompletedOnboarding = true
        onboardingCompletedAt = Date()
        onboardingVersion = Self.requiredOnboardingVersion
        userDefaults.set(onboardingCompletedAt, forKey: onboardingCompletedAtKey)
        HapticManager.success()
    }

    /// Reset onboarding state (for testing or when terms change significantly)
    func resetOnboarding() {
        logger.warning("⚠️ [ONBOARDING] Resetting onboarding state")
        hasCompletedOnboarding = false
        onboardingCompletedAt = nil
        userDefaults.removeObject(forKey: onboardingCompletedAtKey)
    }

    /// Check if user needs to re-complete onboarding (e.g., terms updated)
    var needsOnboardingRefresh: Bool {
        onboardingVersion < Self.requiredOnboardingVersion
    }

    /// Days since onboarding was completed (nil if not completed)
    var daysSinceOnboarding: Int? {
        guard let completedAt = onboardingCompletedAt else {
            return nil
        }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: completedAt, to: Date())
        return components.day
    }

    // MARK: - Private Methods

    private func persistOnboardingState() {
        userDefaults.set(hasCompletedOnboarding, forKey: onboardingCompletedKey)
    }

    /// Reset for testing purposes
    func resetForTesting() {
        hasCompletedOnboarding = false
        onboardingCompletedAt = nil
        onboardingVersion = 0
        userDefaults.removeObject(forKey: onboardingCompletedKey)
        userDefaults.removeObject(forKey: onboardingCompletedAtKey)
        userDefaults.removeObject(forKey: onboardingVersionKey)
        logger.warning("⚠️ [ONBOARDING] State reset for testing")
    }
}

#endif
