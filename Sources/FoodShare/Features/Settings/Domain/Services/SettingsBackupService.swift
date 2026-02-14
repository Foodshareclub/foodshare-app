//
//  SettingsBackupService.swift
//  Foodshare
//
//  Service for backing up and restoring app settings
//

import Foundation
import OSLog
#if !SKIP
import UIKit
#endif

// MARK: - Settings Backup

/// A backup of user settings that can be exported and restored
struct SettingsBackup: Codable, Sendable {
    let version: String
    let createdAt: Date
    let deviceName: String
    let preferences: PreferencesBackup
    let privacy: PrivacyBackup
    let appearance: AppearanceBackup
    let appLock: AppLockBackup

    struct PreferencesBackup: Codable, Sendable {
        let searchRadius: Double
        let notificationsEnabled: Bool
        let locationEnabled: Bool
        let messageAlertsEnabled: Bool
        let likeNotificationsEnabled: Bool
    }

    struct PrivacyBackup: Codable, Sendable {
        let privacyBlurEnabled: Bool
        let screenRecordingWarningEnabled: Bool
        let sessionTimeoutDuration: Double
        let clipboardAutoClearEnabled: Bool
        let clipboardClearDelay: Double
    }

    struct AppearanceBackup: Codable, Sendable {
        let themeId: String
        let colorSchemePreference: String
    }

    struct AppLockBackup: Codable, Sendable {
        let isEnabled: Bool
        let lockOnBackground: Bool
        let lockDelay: Int
        let lockOnLaunch: Bool
    }
}

// MARK: - Backup Error

enum SettingsBackupError: LocalizedError, Sendable {
    case encodingFailed(String)
    case decodingFailed(String)
    case fileWriteFailed(String)
    case fileReadFailed(String)
    case versionMismatch(expected: String, found: String)
    case invalidBackupFile

    var errorDescription: String? {
        switch self {
        case let .encodingFailed(reason):
            "Failed to encode settings: \(reason)"
        case let .decodingFailed(reason):
            "Failed to decode settings: \(reason)"
        case let .fileWriteFailed(reason):
            "Failed to write backup file: \(reason)"
        case let .fileReadFailed(reason):
            "Failed to read backup file: \(reason)"
        case let .versionMismatch(expected, found):
            "Backup version mismatch. Expected \(expected), found \(found)"
        case .invalidBackupFile:
            "Invalid backup file format"
        }
    }
}

// MARK: - Settings Backup Service

/// Actor-based service for creating and restoring settings backups
actor SettingsBackupService {
    // MARK: - Singleton

    static let shared = SettingsBackupService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "SettingsBackup")
    private let currentVersion = "1.0.0"

    // MARK: - Initialization

    private init() {}

    // MARK: - Create Backup

    /// Create a backup of current settings
    /// - Returns: URL of the created backup file
    func createBackup() async throws -> URL {
        logger.info("Creating settings backup")

        // Gather settings from services (need to access on MainActor)
        let backup = await MainActor.run {
            let prefs = PreferencesService.shared
            let privacy = PrivacyProtectionService.shared
            let theme = ThemeManager.shared
            let appLock = AppLockService.shared

            return SettingsBackup(
                version: currentVersion,
                createdAt: Date(),
                #if !SKIP
                deviceName: UIDevice.current.name,
                #else
                deviceName: "Android",
                #endif
                preferences: SettingsBackup.PreferencesBackup(
                    searchRadius: prefs.searchRadius,
                    notificationsEnabled: prefs.notificationsEnabled,
                    locationEnabled: prefs.locationEnabled,
                    messageAlertsEnabled: prefs.messageAlertsEnabled,
                    likeNotificationsEnabled: prefs.likeNotificationsEnabled
                ),
                privacy: SettingsBackup.PrivacyBackup(
                    privacyBlurEnabled: privacy.privacyBlurEnabled,
                    screenRecordingWarningEnabled: privacy.screenRecordingWarningEnabled,
                    sessionTimeoutDuration: privacy.sessionTimeoutDuration,
                    clipboardAutoClearEnabled: privacy.clipboardAutoClearEnabled,
                    clipboardClearDelay: privacy.clipboardClearDelay
                ),
                appearance: SettingsBackup.AppearanceBackup(
                    themeId: theme.currentTheme.id,
                    colorSchemePreference: theme.colorSchemePreference.rawValue
                ),
                appLock: SettingsBackup.AppLockBackup(
                    isEnabled: appLock.isEnabled,
                    lockOnBackground: appLock.lockOnBackground,
                    lockDelay: appLock.lockDelay,
                    lockOnLaunch: appLock.lockOnLaunch
                )
            )
        }

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data: Data
        do {
            data = try encoder.encode(backup)
        } catch {
            throw SettingsBackupError.encodingFailed(error.localizedDescription)
        }

        // Create backup directory
        let backupDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("settings_backups", isDirectory: true)

        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)

        // Generate filename
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "foodshare_settings_\(timestamp).json"
        let fileURL = backupDir.appendingPathComponent(filename)

        // Write file
        do {
            try data.write(to: fileURL)
        } catch {
            throw SettingsBackupError.fileWriteFailed(error.localizedDescription)
        }

        logger.info("Settings backup created: \(fileURL.lastPathComponent)")
        return fileURL
    }

    // MARK: - Restore Backup

    /// Restore settings from a backup file
    /// - Parameter url: URL of the backup file
    func restoreBackup(from url: URL) async throws {
        logger.info("Restoring settings from backup: \(url.lastPathComponent)")

        // Read file
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SettingsBackupError.fileReadFailed(error.localizedDescription)
        }

        // Decode backup
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let backup: SettingsBackup
        do {
            backup = try decoder.decode(SettingsBackup.self, from: data)
        } catch {
            throw SettingsBackupError.decodingFailed(error.localizedDescription)
        }

        // Version check (allow minor version differences)
        let backupMajor = backup.version.split(separator: ".").first ?? "0"
        let currentMajor = currentVersion.split(separator: ".").first ?? "0"
        if backupMajor != currentMajor {
            throw SettingsBackupError.versionMismatch(expected: currentVersion, found: backup.version)
        }

        // Apply settings on MainActor
        await MainActor.run {
            let prefs = PreferencesService.shared
            let privacy = PrivacyProtectionService.shared
            let theme = ThemeManager.shared
            let appLock = AppLockService.shared

            // Preferences
            prefs.searchRadius = backup.preferences.searchRadius
            prefs.notificationsEnabled = backup.preferences.notificationsEnabled
            prefs.locationEnabled = backup.preferences.locationEnabled
            prefs.messageAlertsEnabled = backup.preferences.messageAlertsEnabled
            prefs.likeNotificationsEnabled = backup.preferences.likeNotificationsEnabled

            // Privacy
            privacy.privacyBlurEnabled = backup.privacy.privacyBlurEnabled
            privacy.screenRecordingWarningEnabled = backup.privacy.screenRecordingWarningEnabled
            privacy.sessionTimeoutDuration = backup.privacy.sessionTimeoutDuration
            privacy.clipboardAutoClearEnabled = backup.privacy.clipboardAutoClearEnabled
            privacy.clipboardClearDelay = backup.privacy.clipboardClearDelay

            // Appearance
            theme.setTheme(id: backup.appearance.themeId)
            if let colorPref = ColorSchemePreference(rawValue: backup.appearance.colorSchemePreference) {
                theme.setColorSchemePreference(colorPref)
            }

            // App Lock (only restore non-sensitive settings)
            appLock.lockOnBackground = backup.appLock.lockOnBackground
            appLock.lockDelay = backup.appLock.lockDelay
            appLock.lockOnLaunch = backup.appLock.lockOnLaunch
            // Note: Don't restore isEnabled - user must manually enable biometric
        }

        logger.info("Settings restored from backup dated \(backup.createdAt)")
    }

    // MARK: - Validate Backup

    /// Validate a backup file without restoring it
    /// - Parameter url: URL of the backup file
    /// - Returns: The backup metadata if valid
    func validateBackup(at url: URL) async throws -> SettingsBackup {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SettingsBackupError.fileReadFailed(error.localizedDescription)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode(SettingsBackup.self, from: data)
        } catch {
            throw SettingsBackupError.invalidBackupFile
        }
    }

    // MARK: - List Backups

    /// List available backup files in the backup directory
    /// - Returns: Array of backup file URLs sorted by date (newest first)
    func listBackups() async -> [URL] {
        let backupDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("settings_backups", isDirectory: true)

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("foodshare_settings_") }
            .sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
    }

    // MARK: - Delete Backup

    /// Delete a backup file
    /// - Parameter url: URL of the backup file to delete
    func deleteBackup(at url: URL) async throws {
        try FileManager.default.removeItem(at: url)
        logger.info("Deleted backup: \(url.lastPathComponent)")
    }
}
