//
//  SettingsViewModel.swift
//  Foodshare
//
//  ViewModel for Settings screen following MVVM + Clean Architecture
//



#if !SKIP
import Foundation
import Supabase
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    // MARK: - Properties

    // Sheet presentation states
    var showDeleteConfirmation = false
    var showSignOutConfirmation = false
    var showDeleteError = false
    var showDonation = false
    var showHelp = false
    var showFeedback = false
    var showSubscription = false
    var showThemePicker = false
    var showLanguagePicker = false
    var showAppIconPicker = false

    // Loading states
    var isDeletingAccount = false
    var isSavingRadius = false

    // Error states
    var deleteAccountError: String?

    // Dependencies
    private let preferencesService: PreferencesService
    private let locationManager: LocationManager
    private let appState: AppState

    // MARK: - Computed Properties

    var currentUser: AuthUserProfile? {
        appState.currentUser
    }

    var isPremium: Bool {
        appState.isPremium
    }

    var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    // MARK: - Initialization

    init(
        preferencesService: PreferencesService = .shared,
        locationManager: LocationManager = .init(),
        appState: AppState,
    ) {
        self.preferencesService = preferencesService
        self.locationManager = locationManager
        self.appState = appState
    }

    // MARK: - Preference Actions

    /// Update search radius with validation
    func updateSearchRadius(_ radius: Double) async {
        isSavingRadius = true
        defer { isSavingRadius = false }

        preferencesService.searchRadius = radius
        preferencesService.validateSearchRadius()

        // Optionally sync to backend profile
        do {
            try await appState.updateSearchRadius(radius)
        } catch {
            await AppLogger.shared.error("Failed to sync search radius to backend", error: error)
            // Don't show error to user - local preference is saved
        }
    }

    /// Toggle location services with permission handling
    func toggleLocationServices(_ enabled: Bool) async {
        if enabled {
            await requestLocationPermission()
        } else {
            preferencesService.locationEnabled = false
        }
    }

    /// Request location permission from system
    private func requestLocationPermission() async {
        do {
            try await locationManager.requestPermission()
            preferencesService.locationEnabled = true
        } catch LocationError.permissionDenied {
            preferencesService.locationEnabled = false
            // User should be directed to Settings app
            await AppLogger.shared.warning("Location permission denied")
        } catch LocationError.locationServicesDisabled {
            preferencesService.locationEnabled = false
            await AppLogger.shared.warning("Location services disabled at device level")
        } catch {
            preferencesService.locationEnabled = false
            await AppLogger.shared.error("Failed to request location permission", error: error)
        }
    }

    /// Update notification preferences
    func updateNotificationPreference(_ type: SettingsNotificationType, enabled: Bool) async {
        switch type {
        case .push:
            preferencesService.notificationsEnabled = enabled
            if enabled {
                await requestNotificationPermission()
            }
        case .messages:
            preferencesService.messageAlertsEnabled = enabled
        case .likes:
            preferencesService.likeNotificationsEnabled = enabled
        }

        // Sync to backend
        do {
            try await appState.updateNotificationPreferences(
                push: preferencesService.notificationsEnabled,
                messages: preferencesService.messageAlertsEnabled,
                likes: preferencesService.likeNotificationsEnabled,
            )
        } catch {
            await AppLogger.shared.error("Failed to sync notification preferences", error: error)
        }
    }

    /// Request notification permission from system
    private func requestNotificationPermission() async {
        // This would integrate with UNUserNotificationCenter
        // For now, just log
        await AppLogger.shared.debug("Requesting notification permission")
    }

    // MARK: - Account Actions

    /// Sign out the current user
    func signOut() async {
        await appState.signOut()
    }

    /// Delete the current user account
    func deleteAccount() async throws {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await appState.deleteAccount()
        } catch {
            deleteAccountError = error.localizedDescription
            showDeleteError = true
            throw error
        }
    }

    /// Update user profile
    func updateProfile(name: String) async throws {
        try await appState.updateProfile(name: name)
    }

    // MARK: - Helper Methods

    /// Dismiss error alert
    func dismissError() {
        showDeleteError = false
        deleteAccountError = nil
    }

    /// Create feedback view model
    func createFeedbackViewModel(supabase: Supabase.SupabaseClient) -> FeedbackViewModel {
        let repository = SupabaseFeedbackRepository(supabase: supabase)
        return FeedbackViewModel(
            repository: repository,
            userId: currentUser?.id,
            defaultName: currentUser?.displayName ?? "",
            defaultEmail: currentUser?.email ?? "",
        )
    }
}

// MARK: - Supporting Types

enum SettingsNotificationType {
    case push
    case messages
    case likes
}


#endif
