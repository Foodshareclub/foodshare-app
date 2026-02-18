//
//  SupabaseManager.swift
//  Foodshare
//
//  Singleton wrapper providing access to the shared SupabaseClient
//  iOS: Delegates to AuthenticationService's client
//  Android: Creates supabase-kt client directly from AppEnvironment
//


#if !SKIP
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

#else

import Foundation

/// Singleton providing Supabase configuration (Android/Skip)
/// Stores the URL and key. Actual supabase-kt client creation happens in Kotlin.
final class SupabaseManager {
    // MARK: - Singleton

    static let shared = SupabaseManager()

    // MARK: - Properties

    let supabaseURL: String
    let supabaseKey: String

    // MARK: - Initialization

    private init() {
        self.supabaseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        self.supabaseKey = AppEnvironment.supabasePublishableKey ?? ""
    }
}

#endif
