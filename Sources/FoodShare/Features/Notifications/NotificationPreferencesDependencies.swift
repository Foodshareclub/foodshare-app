// MARK: - NotificationPreferencesDependencies.swift
// Dependency Injection for Notification Preferences
// FoodShare iOS - Clean Architecture

import Foundation
import Supabase

// MARK: - Dependency Container Extension

extension DependencyContainer {

    /// Notification preferences repository (lazy initialized)
    @MainActor
    public var notificationPreferencesRepository: NotificationPreferencesRepository {
        if let cached = resolve(NotificationPreferencesRepository.self) {
            return cached
        }

        let repository = SupabaseNotificationPreferencesRepository(client: supabaseClient)
        register(repository as NotificationPreferencesRepository)
        return repository
    }

    /// Create notification preferences view model
    @MainActor
    public func makeNotificationPreferencesViewModel() -> NotificationPreferencesViewModel {
        NotificationPreferencesViewModel(repository: notificationPreferencesRepository)
    }
}

extension EnvironmentValues {
    @Entry public var notificationPreferencesRepository: NotificationPreferencesRepository?
}

// MARK: - View Extensions

import SwiftUI

extension View {
    /// Inject notification preferences repository into environment
    @MainActor
    public func withNotificationPreferencesRepository(_ repository: NotificationPreferencesRepository) -> some View {
        environment(\.notificationPreferencesRepository, repository)
    }
}

// MARK: - Factory for Creating Views

@MainActor
public struct NotificationPreferencesFactory {

    private let dependencies: DependencyContainer

    public init(dependencies: DependencyContainer) {
        self.dependencies = dependencies
    }

    /// Create the enterprise notification settings view
    public func makeSettingsView() -> some View {
        let viewModel = dependencies.makeNotificationPreferencesViewModel()
        return EnterpriseNotificationSettingsView(viewModel: viewModel)
    }
}
