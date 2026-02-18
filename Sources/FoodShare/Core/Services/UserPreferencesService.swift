//
//  UserPreferencesService.swift
//  Foodshare
//
//  Service for managing user preferences with cloud sync.
//  Replaces UserDefaults with server-side storage for cross-device sync.
//  Phase 4: Ultra-Thin Client Architecture
//



#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - User Preferences Model

/// User preferences that sync across devices
struct UserPreferences: Codable, Sendable, Equatable {
    var searchRadiusKm: Double
    var feedViewMode: SyncedFeedViewMode
    var notificationsEnabled: Bool
    var emailNotifications: Bool
    var pushNotifications: Bool
    var showDistance: Bool
    var preferredCategories: [Int]
    var theme: AppTheme
    var language: String

    enum CodingKeys: String, CodingKey {
        case searchRadiusKm = "search_radius_km"
        case feedViewMode = "feed_view_mode"
        case notificationsEnabled = "notifications_enabled"
        case emailNotifications = "email_notifications"
        case pushNotifications = "push_notifications"
        case showDistance = "show_distance"
        case preferredCategories = "preferred_categories"
        case theme
        case language
    }

    /// Default preferences
    static let `default` = UserPreferences(
        searchRadiusKm: 5.0,
        feedViewMode: .grid,
        notificationsEnabled: true,
        emailNotifications: true,
        pushNotifications: true,
        showDistance: true,
        preferredCategories: [],
        theme: .dark,
        language: "en",
    )
}

/// Feed view mode options for backend sync (distinct from FeedViewMode in FeedPreferencesService)
enum SyncedFeedViewMode: String, Codable, Sendable, CaseIterable {
    case grid
    case list
    case map
}

/// App theme options
enum AppTheme: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

// MARK: - RPC Response Types

private struct PreferencesResponse: Decodable {
    let success: Bool
    let preferences: UserPreferences?
    let error: PreferencesRPCError?
}

private struct PreferencesRPCError: Decodable {
    let code: String
    let message: String
}

/// Wrapper for update preferences RPC params
private struct UpdatePreferencesParams: Encodable {
    let p_preferences: UserPreferences
}

// MARK: - User Preferences Service

/// Service for managing user preferences with cloud sync
@MainActor
@Observable
final class UserPreferencesService {
    // MARK: - Singleton

    static let shared = UserPreferencesService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "UserPreferences")

    /// Current user preferences (observable for UI binding)
    private(set) var preferences: UserPreferences = .default

    /// Whether preferences have been loaded from server
    private(set) var isLoaded = false

    /// Local cache key
    private let cacheKey = "user_preferences_cache"

    // MARK: - Initialization

    private init() {
        loadFromCache()
        logger.info("⚙️ [PREFS] UserPreferencesService initialized")
    }

    // MARK: - Load Preferences

    /// Load preferences from server (or cache if offline)
    /// Automatically syncs theme to ThemeManager for cross-device consistency
    func loadPreferences() async {
        logger.info("⚙️ [PREFS] Loading preferences from server")

        let supabase = SupabaseManager.shared.client

        do {
            let response = try await supabase
                .rpc("get_user_preferences")
                .execute()

            let result = try JSONDecoder().decode(PreferencesResponse.self, from: response.data)

            if result.success, let serverPrefs = result.preferences {
                preferences = serverPrefs
                saveToCache(serverPrefs)
                isLoaded = true

                // Sync theme to ThemeManager for UI consistency
                ThemeManager.shared.applyFromServerPreferences(serverPrefs.theme)

                logger.info("✅ [PREFS] Loaded preferences from server (theme: \(serverPrefs.theme.rawValue))")
            } else if let error = result.error {
                logger.error("❌ [PREFS] Failed to load preferences: \(error.message)")
                // Keep using cached/default preferences
            }
        } catch {
            logger.warning("⚠️ [PREFS] Server load failed, using cache: \(error.localizedDescription)")
            // Apply cached theme to ThemeManager
            ThemeManager.shared.applyFromServerPreferences(preferences.theme)
        }
    }

    // MARK: - Update Preferences

    /// Update preferences on server
    func updatePreferences(_ newPreferences: UserPreferences) async throws {
        logger.info("⚙️ [PREFS] Updating preferences")

        let supabase = SupabaseManager.shared.client

        let params = UpdatePreferencesParams(p_preferences: newPreferences)

        let response = try await supabase
            .rpc("update_user_preferences", params: params)
            .execute()

        let result = try JSONDecoder().decode(PreferencesResponse.self, from: response.data)

        guard result.success, let updatedPrefs = result.preferences else {
            if let error = result.error {
                logger.error("❌ [PREFS] Update failed: \(error.message)")
                throw PreferencesError.serverError(error.message)
            }
            throw PreferencesError.serverError("Unknown error")
        }

        // Update local state
        preferences = updatedPrefs
        saveToCache(updatedPrefs)

        logger.info("✅ [PREFS] Preferences updated successfully")
    }

    /// Update a single preference
    func updatePreference<T>(_ keyPath: WritableKeyPath<UserPreferences, T>, value: T) async throws {
        var newPrefs = preferences
        newPrefs[keyPath: keyPath] = value
        try await updatePreferences(newPrefs)
    }

    // MARK: - Quick Setters

    /// Update search radius
    func setSearchRadius(_ radiusKm: Double) async throws {
        try await updatePreference(\.searchRadiusKm, value: radiusKm)
    }

    /// Update feed view mode
    func setFeedViewMode(_ mode: SyncedFeedViewMode) async throws {
        try await updatePreference(\.feedViewMode, value: mode)
    }

    /// Update notifications enabled
    func setNotificationsEnabled(_ enabled: Bool) async throws {
        try await updatePreference(\.notificationsEnabled, value: enabled)
    }

    /// Update theme
    func setTheme(_ theme: AppTheme) async throws {
        try await updatePreference(\.theme, value: theme)
    }

    // MARK: - Cache Management

    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return }

        do {
            preferences = try JSONDecoder().decode(UserPreferences.self, from: data)
            logger.debug("⚙️ [PREFS] Loaded from cache")
        } catch {
            logger.warning("⚠️ [PREFS] Cache decode failed: \(error.localizedDescription)")
        }
    }

    private func saveToCache(_ prefs: UserPreferences) {
        do {
            let data = try JSONEncoder().encode(prefs)
            UserDefaults.standard.set(data, forKey: cacheKey)
            logger.debug("⚙️ [PREFS] Saved to cache")
        } catch {
            logger.warning("⚠️ [PREFS] Cache save failed: \(error.localizedDescription)")
        }
    }

    /// Clear cached preferences (call on sign-out)
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        preferences = .default
        isLoaded = false
        logger.info("🧹 [PREFS] Cache cleared")
    }
}

// MARK: - Preferences Errors

enum PreferencesError: LocalizedError, Sendable {
    case notAuthenticated
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Please sign in to save preferences"
        case let .serverError(message):
            message
        }
    }
}


#endif
