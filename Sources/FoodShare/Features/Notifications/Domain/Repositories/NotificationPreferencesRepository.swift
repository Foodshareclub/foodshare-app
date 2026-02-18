// MARK: - NotificationPreferencesRepository.swift
// Enterprise Notification Preferences Repository Protocol
// FoodShare iOS - Clean Architecture Domain Layer


#if !SKIP
import Foundation

// MARK: - Repository Protocol

/// Repository protocol for notification preferences management
/// Follows Clean Architecture - Domain layer defines interface, Data layer implements
public protocol NotificationPreferencesRepository: Sendable {

    // MARK: - Fetch Operations

    /// Fetch all notification preferences for the current user
    /// - Returns: Complete notification preferences including settings and per-category preferences
    /// - Throws: Network or parsing errors
    func fetchPreferences() async throws -> NotificationPreferences

    // MARK: - Update Operations

    /// Update global notification settings (push/email/sms enabled, quiet hours, DND, digest)
    /// - Parameter settings: The settings to update (only non-nil fields are updated)
    /// - Returns: Updated global settings
    /// - Throws: Network or validation errors
    func updateSettings(_ settings: UpdateSettingsRequest) async throws -> NotificationGlobalSettings

    /// Update a single category/channel preference
    /// - Parameter preference: The preference to update
    /// - Throws: Network or validation errors
    func updatePreference(_ preference: CategoryPreference) async throws

    /// Batch update multiple preferences
    /// - Parameter preferences: Array of preferences to update
    /// - Throws: Network or validation errors
    func updatePreferences(_ preferences: [CategoryPreference]) async throws

    // MARK: - Do Not Disturb

    /// Enable Do Not Disturb mode
    /// - Parameter request: DND configuration (duration or specific end time)
    /// - Returns: Updated DND state
    /// - Throws: Network errors
    func enableDND(_ request: EnableDNDRequest) async throws -> DoNotDisturb

    /// Disable Do Not Disturb mode
    /// - Throws: Network errors
    func disableDND() async throws

    // MARK: - Phone Verification (for SMS)

    /// Initiate phone verification for SMS notifications
    /// - Parameter phoneNumber: Phone number to verify
    /// - Throws: Network or validation errors
    func initiatePhoneVerification(phoneNumber: String) async throws

    /// Verify phone number with code
    /// - Parameters:
    ///   - phoneNumber: Phone number being verified
    ///   - code: 6-digit verification code
    /// - Returns: Whether verification succeeded
    /// - Throws: Network or validation errors
    func verifyPhone(phoneNumber: String, code: String) async throws -> Bool
}

// MARK: - Repository Errors

/// Errors that can occur during preference operations
public enum NotificationPreferencesError: Error, LocalizedError, Sendable {
    case notAuthenticated
    case networkError(underlying: Error)
    case invalidResponse
    case serverError(message: String)
    case validationError(message: String)
    case phoneVerificationFailed
    case phoneVerificationExpired
    case rateLimited(retryAfter: TimeInterval?)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to manage notification preferences"
        case let .networkError(underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case let .serverError(message):
            return message
        case let .validationError(message):
            return message
        case .phoneVerificationFailed:
            return "Phone verification failed. Please try again."
        case .phoneVerificationExpired:
            return "Verification code expired. Please request a new code."
        case let .rateLimited(retryAfter):
            if let seconds = retryAfter {
                return "Too many requests. Please try again in \(Int(seconds)) seconds."
            }
            return "Too many requests. Please try again later."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            "Sign in to continue"
        case .networkError:
            "Check your internet connection and try again"
        case .invalidResponse, .serverError:
            "Please try again later"
        case .validationError:
            "Check your input and try again"
        case .phoneVerificationFailed:
            "Double-check the code and try again"
        case .phoneVerificationExpired:
            "Request a new verification code"
        case .rateLimited:
            "Wait a moment before trying again"
        }
    }
}

// MARK: - Mock Repository for Previews/Testing

#if DEBUG
    /// Mock repository for SwiftUI previews and unit tests
    /// Enhanced with comprehensive testing support including:
    /// - Configurable failure modes
    /// - Call counting for verification
    /// - Retry simulation with fail counts
    /// - Custom error types
    public actor MockNotificationPreferencesRepository: NotificationPreferencesRepository {

        // MARK: - State

        public var preferences: NotificationPreferences
        public var shouldFail = false
        public var delay: TimeInterval = 0.1
        public var failCount = 0
        public var errorType: NotificationPreferencesError =
            .networkError(underlying: URLError(.notConnectedToInternet))

        // MARK: - Call Tracking

        public private(set) var fetchCallCount = 0
        public private(set) var updateSettingsCallCount = 0
        public private(set) var updatePreferenceCallCount = 0
        public private(set) var enableDNDCallCount = 0
        public private(set) var disableDNDCallCount = 0
        public private(set) var initiatePhoneVerificationCallCount = 0
        public private(set) var verifyPhoneCallCount = 0

        // MARK: - Internal Tracking

        private var currentFailCount = 0

        // MARK: - Initialization

        public init(preferences: NotificationPreferences = .mock) {
            self.preferences = preferences
        }

        // MARK: - Configuration Methods

        /// Reset all call counts
        public func resetCallCounts() {
            fetchCallCount = 0
            updateSettingsCallCount = 0
            updatePreferenceCallCount = 0
            enableDNDCallCount = 0
            disableDNDCallCount = 0
            initiatePhoneVerificationCallCount = 0
            verifyPhoneCallCount = 0
            currentFailCount = 0
        }

        // MARK: - Repository Implementation

        public func fetchPreferences() async throws -> NotificationPreferences {
            fetchCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            // Handle fail count (fail N times then succeed)
            if failCount > 0 {
                if currentFailCount < failCount {
                    currentFailCount += 1
                    throw errorType
                }
            } else if shouldFail {
                throw errorType
            }

            return preferences
        }

        public func updateSettings(_ settings: UpdateSettingsRequest) async throws -> NotificationGlobalSettings {
            updateSettingsCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail { throw errorType }

            if let pushEnabled = settings.push_enabled {
                preferences.settings.pushEnabled = pushEnabled
            }
            if let emailEnabled = settings.email_enabled {
                preferences.settings.emailEnabled = emailEnabled
            }
            if let smsEnabled = settings.sms_enabled {
                preferences.settings.smsEnabled = smsEnabled
            }
            if let quietHours = settings.quiet_hours {
                preferences.settings.quietHours = QuietHours(
                    enabled: quietHours.enabled ?? false,
                    start: quietHours.start ?? "22:00",
                    end: quietHours.end ?? "08:00",
                    timezone: quietHours.timezone ?? TimeZone.current.identifier
                )
            }
            if let digest = settings.digest {
                if let daily = digest.daily_enabled {
                    preferences.settings.digest.dailyEnabled = daily
                }
                if let time = digest.daily_time {
                    preferences.settings.digest.dailyTime = time
                }
                if let weekly = digest.weekly_enabled {
                    preferences.settings.digest.weeklyEnabled = weekly
                }
                if let day = digest.weekly_day {
                    preferences.settings.digest.weeklyDay = day
                }
            }

            return preferences.settings
        }

        public func updatePreference(_ preference: CategoryPreference) async throws {
            updatePreferenceCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail { throw errorType }

            var categoryPrefs = preferences.preferences[preference.category.rawValue] ?? [:]
            categoryPrefs[preference.channel.rawValue] = NotificationPreferences.CategoryPreferenceData(
                enabled: preference.enabled,
                frequency: preference.frequency.rawValue,
            )
            preferences.preferences[preference.category.rawValue] = categoryPrefs
        }

        public func updatePreferences(_ prefs: [CategoryPreference]) async throws {
            for pref in prefs {
                try await updatePreference(pref)
            }
        }

        public func enableDND(_ request: EnableDNDRequest) async throws -> DoNotDisturb {
            enableDNDCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail { throw errorType }

            let until: Date = if let durationHours = request.duration_hours {
                Date().addingTimeInterval(TimeInterval(durationHours * 3600))
            } else if let untilString = request.until,
                      let date = ISO8601DateFormatter().date(from: untilString)
            {
                date
            } else {
                Date().addingTimeInterval(8 * 3600) // Default 8 hours
            }

            preferences.settings.dnd = DoNotDisturb(enabled: true, until: until)
            return preferences.settings.dnd
        }

        public func disableDND() async throws {
            disableDNDCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail { throw errorType }
            preferences.settings.dnd = DoNotDisturb(enabled: false, until: nil)
        }

        public func initiatePhoneVerification(phoneNumber: String) async throws {
            initiatePhoneVerificationCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail { throw errorType }
            preferences.settings.phoneNumber = phoneNumber
        }

        public func verifyPhone(phoneNumber: String, code: String) async throws -> Bool {
            verifyPhoneCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail { throw NotificationPreferencesError.phoneVerificationFailed }

            // Mock: accept "123456" as valid code
            if code == "123456" {
                preferences.settings.phoneVerified = true
                preferences.settings.smsEnabled = true
                return true
            }
            throw NotificationPreferencesError.phoneVerificationFailed
        }
    }

    // MARK: - Mock Data

    extension NotificationPreferences {
        /// Mock preferences for previews
        public static var mock: NotificationPreferences {
            var prefs = NotificationPreferences()

            // Set up some default preferences
            for category in NotificationCategory.allCases {
                var categoryPrefs: [String: CategoryPreferenceData] = [:]

                // Push enabled for most categories
                categoryPrefs["push"] = CategoryPreferenceData(
                    enabled: category != .marketing,
                    frequency: "instant",
                )

                // Email enabled for important categories
                categoryPrefs["email"] = CategoryPreferenceData(
                    enabled: [.chats, .system].contains(category),
                    frequency: category == .chats ? "instant" : "daily",
                )

                // SMS disabled by default
                categoryPrefs["sms"] = CategoryPreferenceData(
                    enabled: false,
                    frequency: "never",
                )

                prefs.preferences[category.rawValue] = categoryPrefs
            }

            return prefs
        }
    }
#endif

#endif
