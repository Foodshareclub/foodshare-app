//
//  EmailPreferencesService.swift
//  Foodshare
//
//  Manages email notification preferences
//  Actor-based, thread-safe implementation
//

import Foundation
import OSLog
import Supabase

// MARK: - Email Preferences Model

/// User's email notification preferences
struct EmailPreferences: Codable, Sendable {
    let id: UUID?
    let profileId: UUID
    var chatNotifications: Bool
    var foodListingsNotifications: Bool
    var feedbackNotifications: Bool
    var reviewReminders: Bool
    var notificationFrequency: NotificationFrequency
    var quietHoursStart: String?
    var quietHoursEnd: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case chatNotifications = "chat_notifications"
        case foodListingsNotifications = "food_listings_notifications"
        case feedbackNotifications = "feedback_notifications"
        case reviewReminders = "review_reminders"
        case notificationFrequency = "notification_frequency"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Default preferences for new users
    static func defaults(for profileId: UUID) -> EmailPreferences {
        EmailPreferences(
            id: nil,
            profileId: profileId,
            chatNotifications: true,
            foodListingsNotifications: true,
            feedbackNotifications: false,
            reviewReminders: true,
            notificationFrequency: .instant,
            quietHoursStart: nil,
            quietHoursEnd: nil,
            createdAt: nil,
            updatedAt: nil,
        )
    }
}

// MARK: - Notification Frequency

enum NotificationFrequency: String, Codable, Sendable, CaseIterable {
    case instant
    case dailyDigest = "daily_digest"
    case weeklyDigest = "weekly_digest"

    var titleKey: String {
        switch self {
        case .instant: "email_preferences.frequency.instant.title"
        case .dailyDigest: "email_preferences.frequency.daily.title"
        case .weeklyDigest: "email_preferences.frequency.weekly.title"
        }
    }

    var descriptionKey: String {
        switch self {
        case .instant: "email_preferences.frequency.instant.description"
        case .dailyDigest: "email_preferences.frequency.daily.description"
        case .weeklyDigest: "email_preferences.frequency.weekly.description"
        }
    }

    var icon: String {
        switch self {
        case .instant: "bolt.fill"
        case .dailyDigest: "sun.max.fill"
        case .weeklyDigest: "calendar.badge.clock"
        }
    }
}

// MARK: - Email Preferences Service

/// Actor-based service for managing email notification preferences
actor EmailPreferencesService {
    // MARK: - Singleton

    static let shared = EmailPreferencesService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "EmailPreferences")

    /// Cached preferences
    private var cachedPreferences: EmailPreferences?
    private var cacheTimestamp: Date?
    private let cacheExpiration: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    private init() {
        logger.info("📧 [EMAIL-PREFS] EmailPreferencesService initialized")
    }

    // MARK: - Fetch Preferences

    /// Get email preferences for current user
    @MainActor
    func getPreferences() async throws -> EmailPreferences {
        // Check cache
        if let cached = await getCachedPreferences() {
            return cached
        }

        logger.debug("📧 [EMAIL-PREFS] Fetching preferences from server")

        let supabase = SupabaseManager.shared.client

        guard let userId = try? await supabase.auth.session.user.id else {
            throw EmailPreferencesError.notAuthenticated
        }

        let preferences: [EmailPreferences] = try await supabase
            .from("email_preferences")
            .select()
            .eq("profile_id", value: userId.uuidString)
            .execute()
            .value

        if let existing = preferences.first {
            await cachePreferences(existing)
            return existing
        }

        // Return defaults if no preferences exist
        let defaults = EmailPreferences.defaults(for: userId)
        return defaults
    }

    // MARK: - Save Preferences

    /// Save email preferences
    @MainActor
    func savePreferences(_ preferences: EmailPreferences) async throws {
        logger.info("📧 [EMAIL-PREFS] Saving preferences")

        let supabase = SupabaseManager.shared.client

        guard let userId = try? await supabase.auth.session.user.id else {
            throw EmailPreferencesError.notAuthenticated
        }

        // Prepare upsert data
        let data: [String: AnyJSON] = [
            "profile_id": .string(userId.uuidString),
            "chat_notifications": .bool(preferences.chatNotifications),
            "food_listings_notifications": .bool(preferences.foodListingsNotifications),
            "feedback_notifications": .bool(preferences.feedbackNotifications),
            "review_reminders": .bool(preferences.reviewReminders),
            "notification_frequency": .string(preferences.notificationFrequency.rawValue),
            "quiet_hours_start": preferences.quietHoursStart.map { .string($0) } ?? .null,
            "quiet_hours_end": preferences.quietHoursEnd.map { .string($0) } ?? .null,
            "updated_at": .string(ISO8601DateFormatter().string(from: Date()))
        ]

        try await supabase
            .from("email_preferences")
            .upsert(data, onConflict: "profile_id")
            .execute()

        // Update cache
        await cachePreferences(preferences)

        HapticManager.success()
        logger.info("✅ [EMAIL-PREFS] Preferences saved successfully")
    }

    // MARK: - Quick Toggles

    /// Toggle chat notifications
    @MainActor
    func toggleChatNotifications() async throws -> Bool {
        var prefs = try await getPreferences()
        prefs.chatNotifications.toggle()
        try await savePreferences(prefs)
        return prefs.chatNotifications
    }

    /// Toggle food listings notifications
    @MainActor
    func toggleFoodListingsNotifications() async throws -> Bool {
        var prefs = try await getPreferences()
        prefs.foodListingsNotifications.toggle()
        try await savePreferences(prefs)
        return prefs.foodListingsNotifications
    }

    /// Toggle feedback notifications
    @MainActor
    func toggleFeedbackNotifications() async throws -> Bool {
        var prefs = try await getPreferences()
        prefs.feedbackNotifications.toggle()
        try await savePreferences(prefs)
        return prefs.feedbackNotifications
    }

    /// Toggle review reminders
    @MainActor
    func toggleReviewReminders() async throws -> Bool {
        var prefs = try await getPreferences()
        prefs.reviewReminders.toggle()
        try await savePreferences(prefs)
        return prefs.reviewReminders
    }

    /// Set notification frequency
    @MainActor
    func setNotificationFrequency(_ frequency: NotificationFrequency) async throws {
        var prefs = try await getPreferences()
        prefs.notificationFrequency = frequency
        try await savePreferences(prefs)
    }

    /// Set quiet hours
    @MainActor
    func setQuietHours(start: String?, end: String?) async throws {
        var prefs = try await getPreferences()
        prefs.quietHoursStart = start
        prefs.quietHoursEnd = end
        try await savePreferences(prefs)
    }

    // MARK: - Cache Management

    private func getCachedPreferences() -> EmailPreferences? {
        guard let cached = cachedPreferences,
              let timestamp = cacheTimestamp,
              Date().timeIntervalSince(timestamp) < cacheExpiration else {
            return nil
        }
        return cached
    }

    private func cachePreferences(_ preferences: EmailPreferences) {
        cachedPreferences = preferences
        cacheTimestamp = Date()
    }

    /// Clear cached preferences (call on sign-out)
    func clearCache() {
        cachedPreferences = nil
        cacheTimestamp = nil
        logger.info("🧹 [EMAIL-PREFS] Cache cleared")
    }
}

// MARK: - Errors

/// Errors that can occur during email preferences operations.
///
/// Thread-safe for Swift 6 concurrency.
enum EmailPreferencesError: LocalizedError, Sendable {
    /// User is not authenticated
    case notAuthenticated
    /// Failed to save preferences
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Please sign in to manage notification preferences"
        case let .saveFailed(message):
            "Failed to save preferences: \(message)"
        }
    }
}
