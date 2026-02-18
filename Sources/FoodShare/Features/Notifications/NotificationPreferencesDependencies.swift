// MARK: - NotificationPreferencesDependencies.swift
// Dependency Injection for Notification Preferences
// FoodShare iOS - Clean Architecture


#if !SKIP
import Foundation
import SwiftUI

// MARK: - Environment Key

extension EnvironmentValues {
    @Entry public var notificationPreferencesRepository: (any NotificationPreferencesRepository)?
}

// MARK: - View Extensions

extension View {
    /// Inject notification preferences repository into environment
    @MainActor
    public func withNotificationPreferencesRepository(_ repository: any NotificationPreferencesRepository) -> some View {
        environment(\.notificationPreferencesRepository, repository)
    }
}

// MARK: - Factory for Creating ViewModels

@MainActor
public enum NotificationPreferencesFactory {

    /// Create a notification preferences view model using the Supabase repository
    public static func makeViewModel() -> NotificationPreferencesViewModel {
        let repository = SupabaseNotificationPreferencesRepository(
            client: AuthenticationService.shared.supabase
        )
        return NotificationPreferencesViewModel(repository: repository)
    }

    /// Create the enterprise notification settings view
    public static func makeSettingsView() -> some View {
        let viewModel = makeViewModel()
        return EnterpriseNotificationSettingsView(viewModel: viewModel)
    }
}

#endif
