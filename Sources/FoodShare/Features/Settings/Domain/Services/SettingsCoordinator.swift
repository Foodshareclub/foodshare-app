//
//  SettingsCoordinator.swift
//  Foodshare
//
//  Unified facade for settings management
//  Coordinates PreferencesService, UserPreferencesService, PrivacyProtectionService, and ThemeManager
//

import Foundation
import OSLog
import SwiftUI

// MARK: - Sync Status

/// Status of settings synchronization with the server
enum SettingsSyncStatus: Sendable {
    case synced
    case syncing
    case pendingSync(Int)
    case error(String)

    var displayText: String {
        switch self {
        case .synced: "Synced"
        case .syncing: "Syncing..."
        case let .pendingSync(count): "\(count) pending"
        case let .error(message): "Error: \(message)"
        }
    }

    var icon: String {
        switch self {
        case .synced: "checkmark.circle.fill"
        case .syncing: "arrow.triangle.2.circlepath"
        case .pendingSync: "clock.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .synced: .DesignSystem.success
        case .syncing: .DesignSystem.brandBlue
        case .pendingSync: .DesignSystem.accentOrange
        case .error: .DesignSystem.error
        }
    }
}

// MARK: - Settings Coordinator

/// Unified coordinator for all settings-related services
/// Provides a single source of truth for settings state and operations
@MainActor
@Observable
final class SettingsCoordinator {
    // MARK: - Singleton

    static let shared = SettingsCoordinator()

    // MARK: - Dependencies

    private let preferencesService: PreferencesService
    private let userPreferencesService: UserPreferencesService
    private let privacyService: PrivacyProtectionService
    private let themeManager: ThemeManager
    private let appLockService: AppLockService
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "SettingsCoordinator")

    // MARK: - Observable State

    /// Current sync status
    private(set) var syncStatus: SettingsSyncStatus = .synced

    /// All settings grouped by category
    private(set) var allSettings: [SettingsCategory: [SettingItem]] = SettingItem.itemsByCategory

    /// Search query for filtering settings
    var searchQuery = "" {
        didSet {
            updateFilteredSettings()
        }
    }

    /// Filtered settings based on search query
    private(set) var filteredSettings: [SettingsCategory: [SettingItem]] = [:]

    /// Categories that match the current search
    private(set) var matchingCategories: [SettingsCategory] = SettingsCategory.sortedCases

    /// Expanded section states
    var expandedSections: Set<SettingsCategory>

    // MARK: - Batch Update State

    private var pendingUpdates: [String: Any] = [:]
    private var debounceTask: Task<Void, Never>?

    // MARK: - Initialization

    private init(
        preferencesService: PreferencesService = .shared,
        userPreferencesService: UserPreferencesService = .shared,
        privacyService: PrivacyProtectionService = .shared,
        themeManager: ThemeManager = .shared,
        appLockService: AppLockService = .shared
    ) {
        self.preferencesService = preferencesService
        self.userPreferencesService = userPreferencesService
        self.privacyService = privacyService
        self.themeManager = themeManager
        self.appLockService = appLockService

        // Initialize all sections as expanded
        self.expandedSections = Set(SettingsCategory.allCases)

        // Load persisted expanded state
        loadExpandedState()

        // Initialize filtered settings
        self.filteredSettings = allSettings

        logger.info("SettingsCoordinator initialized")
    }

    // MARK: - Search

    private func updateFilteredSettings() {
        if searchQuery.isEmpty {
            filteredSettings = allSettings
            matchingCategories = SettingsCategory.sortedCases
        } else {
            let matchingItems = SettingItem.search(searchQuery)
            filteredSettings = Dictionary(grouping: matchingItems, by: \.category)
            matchingCategories = SettingsCategory.sortedCases.filter { filteredSettings[$0]?.isEmpty == false }

            // Auto-expand matching categories when searching
            for category in matchingCategories {
                expandedSections.insert(category)
            }
        }
    }

    /// Check if a category has matching items in the current search
    func categoryHasMatches(_ category: SettingsCategory) -> Bool {
        if searchQuery.isEmpty { return true }
        return filteredSettings[category]?.isEmpty == false
    }

    /// Get matching items for a category
    func matchingItems(for category: SettingsCategory) -> [SettingItem] {
        filteredSettings[category] ?? []
    }

    // MARK: - Section Expansion

    /// Toggle expansion state for a section
    func toggleSection(_ category: SettingsCategory) {
        if expandedSections.contains(category) {
            expandedSections.remove(category)
        } else {
            expandedSections.insert(category)
        }
        saveExpandedState()
    }

    /// Check if a section is expanded
    func isSectionExpanded(_ category: SettingsCategory) -> Bool {
        expandedSections.contains(category)
    }

    /// Expand all sections
    func expandAll() {
        expandedSections = Set(SettingsCategory.allCases)
        saveExpandedState()
    }

    /// Collapse all sections
    func collapseAll() {
        expandedSections.removeAll()
        saveExpandedState()
    }

    private func loadExpandedState() {
        guard let data = UserDefaults.standard.data(forKey: "settings.expanded_sections"),
              let expanded = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        expandedSections = Set(expanded.compactMap { SettingsCategory(rawValue: $0) })
    }

    private func saveExpandedState() {
        let expanded = expandedSections.map(\.rawValue)
        if let data = try? JSONEncoder().encode(expanded) {
            UserDefaults.standard.set(data, forKey: "settings.expanded_sections")
        }
    }

    // MARK: - Batch Updates

    /// Queue an update to be batched with others
    func queueUpdate(_ key: String, value: Any) {
        pendingUpdates[key] = value

        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(200))

            if !Task.isCancelled {
                await flushUpdates()
            }
        }
    }

    /// Flush all pending updates to the server
    func flushUpdates() async {
        guard !pendingUpdates.isEmpty else { return }

        let updates = pendingUpdates
        pendingUpdates.removeAll()

        syncStatus = .syncing

        do {
            // Process each update based on its key
            for (key, value) in updates {
                switch key {
                case "searchRadius":
                    if let radius = value as? Double {
                        try await userPreferencesService.setSearchRadius(radius)
                    }
                case "theme":
                    if let theme = value as? AppTheme {
                        try await userPreferencesService.setTheme(theme)
                    }
                case "notificationsEnabled":
                    if let enabled = value as? Bool {
                        try await userPreferencesService.setNotificationsEnabled(enabled)
                    }
                default:
                    logger.warning("Unknown update key: \(key)")
                }
            }

            syncStatus = .synced
            logger.info("Flushed \(updates.count) settings updates")
        } catch {
            syncStatus = .error(error.localizedDescription)
            logger.error("Failed to flush updates: \(error.localizedDescription)")
        }
    }

    // MARK: - Preferences Accessors

    /// Search radius in localized units
    var searchRadius: Double {
        get { preferencesService.searchRadius }
        set {
            preferencesService.searchRadius = newValue
            queueUpdate("searchRadius", value: newValue)
        }
    }

    /// Whether notifications are enabled
    var notificationsEnabled: Bool {
        get { preferencesService.notificationsEnabled }
        set {
            preferencesService.notificationsEnabled = newValue
            queueUpdate("notificationsEnabled", value: newValue)
        }
    }

    /// Whether location services are enabled
    var locationEnabled: Bool {
        get { preferencesService.locationEnabled }
        set { preferencesService.locationEnabled = newValue }
    }

    /// Whether message alerts are enabled
    var messageAlertsEnabled: Bool {
        get { preferencesService.messageAlertsEnabled }
        set { preferencesService.messageAlertsEnabled = newValue }
    }

    /// Whether like notifications are enabled
    var likeNotificationsEnabled: Bool {
        get { preferencesService.likeNotificationsEnabled }
        set { preferencesService.likeNotificationsEnabled = newValue }
    }

    // MARK: - Privacy Accessors

    /// Whether privacy blur is enabled
    var privacyBlurEnabled: Bool {
        get { privacyService.privacyBlurEnabled }
        set { privacyService.privacyBlurEnabled = newValue }
    }

    /// Whether screen recording warning is enabled
    var screenRecordingWarningEnabled: Bool {
        get { privacyService.screenRecordingWarningEnabled }
        set { privacyService.screenRecordingWarningEnabled = newValue }
    }

    // MARK: - Theme Accessors

    /// Current color scheme preference
    var colorSchemePreference: ColorSchemePreference {
        get { themeManager.colorSchemePreference }
        set { themeManager.setColorSchemePreference(newValue) }
    }

    /// Current theme
    var currentTheme: any Theme {
        themeManager.currentTheme
    }

    /// Set the current theme
    func setTheme(_ theme: any Theme) {
        themeManager.setTheme(theme)
    }

    // MARK: - App Lock Accessors

    /// Whether app lock is enabled
    var appLockEnabled: Bool {
        appLockService.isEnabled
    }

    /// Whether biometric authentication is available
    var isBiometricAvailable: Bool {
        appLockService.isBiometricAvailable
    }

    /// Biometric type display name
    var biometricDisplayName: String {
        appLockService.biometricDisplayName
    }

    // MARK: - Actions

    /// Reload all settings from services
    func refresh() async {
        syncStatus = .syncing

        await userPreferencesService.loadPreferences()

        syncStatus = .synced
        logger.info("Settings refreshed from server")
    }

    /// Reset all settings to defaults
    func resetToDefaults() {
        preferencesService.resetToDefaults()
        logger.info("Settings reset to defaults")
    }
}
