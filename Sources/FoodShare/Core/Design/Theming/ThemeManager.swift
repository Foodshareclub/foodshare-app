//
//  ThemeManager.swift
//  Foodshare
//
//  Enterprise Theme System - Observable State Manager
//  Manages theme selection, color scheme, and persistence
//
//  REFACTORED: Now syncs color scheme with UserPreferencesService for cross-device sync
//  Visual theme (color palette) remains local-only as it's a device preference
//


#if !SKIP
import OSLog
import SwiftUI

// MARK: - Theme Manager

private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ThemeManager")

/// Central manager for theme state and persistence
/// Uses @Observable for efficient SwiftUI updates
///
/// Color scheme (light/dark/system) syncs to database via UserPreferencesService
/// Visual theme (Nature, Ocean, etc.) is stored locally per device
@Observable
@MainActor
final class ThemeManager {
    // MARK: - Singleton

    /// Shared instance for app-wide access
    static let shared = ThemeManager()

    // MARK: - Published State

    /// Currently active theme
    private(set) var currentTheme: any Theme

    /// Current effective color scheme (after applying preference)
    private(set) var effectiveColorScheme: ColorScheme

    /// User's color scheme preference
    private(set) var colorSchemePreference: ColorSchemePreference

    // MARK: - Persistence (Visual theme only - color scheme syncs via UserPreferencesService)

    @ObservationIgnored
    private let userDefaults = UserDefaults.standard

    private var storedThemeId: String {
        get { userDefaults.string(forKey: "selectedThemeId") ?? ThemeID.nature.rawValue }
        set { userDefaults.set(newValue, forKey: "selectedThemeId") }
    }

    // MARK: - Available Themes

    /// All available themes in display order
    let availableThemes: [any Theme] = [
        NatureTheme(),
        BrandTheme(),
        OceanTheme(),
        SunsetTheme(),
        ForestTheme(),
        CoralTheme(),
        MidnightTheme(),
        MonochromeTheme()
    ]

    // MARK: - Computed Properties

    /// Current theme's palette for the effective color scheme
    var currentPalette: ThemePalette {
        currentTheme.palette(for: effectiveColorScheme)
    }

    /// SwiftUI-compatible color scheme for preferredColorScheme modifier
    var preferredColorScheme: ColorScheme? {
        colorSchemePreference.toColorScheme
    }

    // MARK: - Initialization

    private init() {
        // Migrate: Remove old redundant colorSchemePreference from UserDefaults
        // Color scheme is now synced via UserPreferencesService
        if userDefaults.string(forKey: "colorSchemePreference") != nil {
            userDefaults.removeObject(forKey: "colorSchemePreference")
            logger.info("🧹 [THEME] Migrated: Removed redundant colorSchemePreference from UserDefaults")
        }

        // Load visual theme from local storage (device-specific preference)
        let themeId = userDefaults.string(forKey: "selectedThemeId") ?? ThemeID.nature.rawValue

        // Find theme by ID or fallback to Nature
        currentTheme = NatureTheme()

        // Default to dark until we load from UserPreferencesService
        colorSchemePreference = .dark
        effectiveColorScheme = .dark

        // Restore visual theme with logging
        if let theme = availableThemes.first(where: { $0.id == themeId }) {
            currentTheme = theme
            logger.info("Restored visual theme: \(theme.displayName, privacy: .public)")
        } else if themeId != ThemeID.nature.rawValue {
            logger.warning("Theme not found for ID: \(themeId, privacy: .public), falling back to Nature")
        }

        logger
            .debug(
                "Color scheme preference: \(self.colorSchemePreference.displayName, privacy: .public) (will sync from server)",
            )
    }

    // MARK: - Theme Selection (Visual theme - local only)

    /// Set the active visual theme (local to device)
    /// - Parameter theme: The theme to activate
    func setTheme(_ theme: any Theme) {
        currentTheme = theme
        storedThemeId = theme.id
        HapticManager.light()
    }

    /// Set theme by ID
    /// - Parameter id: The theme identifier
    func setTheme(id: String) {
        guard let theme = availableThemes.first(where: { $0.id == id }) else { return }
        setTheme(theme)
    }

    /// Set theme by ThemeID enum
    /// - Parameter themeId: The type-safe theme identifier
    func setTheme(_ themeId: ThemeID) {
        setTheme(id: themeId.rawValue)
    }

    // MARK: - Color Scheme (Syncs to database)

    /// Set the user's color scheme preference and sync to server
    /// - Parameter preference: The new preference
    /// - Parameter syncToServer: Whether to sync to UserPreferencesService (default: true)
    func setColorSchemePreference(_ preference: ColorSchemePreference, syncToServer: Bool = true) {
        colorSchemePreference = preference

        // Update effective scheme if not system
        if let scheme = preference.toColorScheme {
            effectiveColorScheme = scheme
        }

        HapticManager.light()

        // Sync to server for cross-device consistency
        if syncToServer {
            Task {
                await syncColorSchemeToServer(preference)
            }
        }
    }

    /// Sync color scheme preference to UserPreferencesService
    private func syncColorSchemeToServer(_ preference: ColorSchemePreference) async {
        let appTheme: AppTheme = switch preference {
        case .system: .system
        case .light: .light
        case .dark: .dark
        }

        do {
            try await UserPreferencesService.shared.setTheme(appTheme)
            logger.info("✅ [THEME] Color scheme synced to server: \(preference.displayName)")
        } catch {
            logger.warning("⚠️ [THEME] Failed to sync color scheme to server: \(error.localizedDescription)")
            // Non-fatal - local preference still works
        }
    }

    /// Apply color scheme from UserPreferencesService (called after loading preferences)
    /// - Parameter appTheme: The theme from server preferences
    func applyFromServerPreferences(_ appTheme: AppTheme) {
        let preference: ColorSchemePreference = switch appTheme {
        case .system: .system
        case .light: .light
        case .dark: .dark
        }

        // Apply without syncing back to server (we just loaded from there)
        setColorSchemePreference(preference, syncToServer: false)
        logger.info("✅ [THEME] Applied color scheme from server: \(preference.displayName)")
    }

    /// Update the effective color scheme based on system appearance
    /// Called when system color scheme changes
    /// - Parameter systemScheme: The current system color scheme
    func updateFromSystemScheme(_ systemScheme: ColorScheme) {
        if colorSchemePreference == .system {
            effectiveColorScheme = systemScheme
        } else if let preferredScheme = colorSchemePreference.toColorScheme {
            effectiveColorScheme = preferredScheme
        }
    }

    // MARK: - Convenience

    /// Check if a specific theme is currently active
    /// - Parameter themeId: The theme ID to check
    /// - Returns: True if the theme is active
    func isThemeActive(_ themeId: String) -> Bool {
        currentTheme.id == themeId
    }

    /// Get theme by ID
    /// - Parameter id: The theme identifier
    /// - Returns: The theme if found, nil otherwise
    func theme(for id: String) -> (any Theme)? {
        availableThemes.first { $0.id == id }
    }
}

// MARK: - Preview Support
//
// For previews, use the `.previewWithTheme(_:scheme:)` view modifier
// from ThemeEnvironment.swift which injects theme via environment values
// without mutating the singleton state.

#endif
