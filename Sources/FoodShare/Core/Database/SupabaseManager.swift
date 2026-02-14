//
//  SupabaseManager.swift
//  Foodshare
//
//  Singleton wrapper providing access to the shared SupabaseClient
//  This bridges the AuthenticationService's client to a simple shared interface
//

import Foundation
import Supabase

/// Singleton providing access to the shared SupabaseClient
/// Use this for components that need database access without authentication context
@MainActor
final class SupabaseManager {
    // MARK: - Singleton

    static let shared = SupabaseManager()

    // MARK: - Properties

    /// The shared SupabaseClient instance
    /// This delegates to AuthenticationService's client to ensure consistent configuration
    var client: SupabaseClient {
        AuthenticationService.shared.supabase
    }

    // MARK: - Initialization

    private init() {}
}
