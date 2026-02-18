//
//  Environment.swift
//  Foodshare
//
//  Environment configuration
//  iOS: Reads from environment variables (Xcode scheme) or Config.plist (bundled file)
//  Android: Reads from ProcessInfo environment (set from BuildConfig in Main.kt)
//


import Foundation

#if !SKIP

/// Token class used to locate the framework bundle containing Config.plist
private final class _EnvironmentBundleToken {}

enum AppEnvironment {
    /// Load configuration from Config.plist bundled with the app
    private static let config: [String: String] = {
        // Try SPM resource bundle first, then fall back to main bundle
        let bundles = [Bundle(for: _EnvironmentBundleToken.self), Bundle.main]
        for bundle in bundles {
            // Check inside SPM resource bundle (foodshare-app_FoodShare.bundle)
            if let resourceBundleURL = bundle.url(forResource: "foodshare-app_FoodShare", withExtension: "bundle"),
               let resourceBundle = Bundle(url: resourceBundleURL),
               let path = resourceBundle.path(forResource: "Config", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
                return dict
            }
            // Check directly in bundle
            if let path = bundle.path(forResource: "Config", ofType: "plist"),
               let dict = NSDictionary(contentsOfFile: path) as? [String: String] {
                return dict
            }
        }
        return [:]
    }()

    /// Placeholder values that indicate "not configured"
    private static let placeholders: Set<String> = ["SET_VIA_XCODE_ENV", "SET_VIA_ACTION_SECRETS", ""]

    /// Get value from environment or Config.plist (environment takes precedence)
    /// Returns nil for empty strings and placeholder values
    private static func getValue(key: String, configKey: String? = nil) -> String? {
        // First try environment variable (for Xcode scheme / CI injection)
        if let envValue = ProcessInfo.processInfo.environment[key],
           !placeholders.contains(envValue) {
            return envValue
        }

        // Fall back to Config.plist (for bundled configuration)
        let plistKey = configKey ?? key
        if let plistValue = config[plistKey],
           !placeholders.contains(plistValue) {
            return plistValue
        }

        return nil
    }

    static var supabaseURL: String? {
        getValue(key: "SUPABASE_URL", configKey: "SupabaseURL")
    }

    static var supabasePublishableKey: String? {
        getValue(key: "SUPABASE_PUBLISHABLE_KEY", configKey: "SupabasePublishableKey")
    }

    static var upstashRedisURL: String? {
        getValue(key: "UPSTASH_REDIS_URL", configKey: "UpstashRedisURL")
    }

    static var upstashRedisToken: String? {
        getValue(key: "UPSTASH_REDIS_TOKEN", configKey: "UpstashRedisToken")
    }

    static var resendAPIKey: String? {
        getValue(key: "RESEND_API_KEY", configKey: "ResendAPIKey")
    }

    // MARK: - OAuth Providers

    /// Nextdoor OAuth Client ID for Sign in with Nextdoor
    static var nextdoorClientId: String? {
        getValue(key: "NEXTDOOR_CLIENT_ID", configKey: "NextdoorClientId")
    }

    static var verboseLogging: Bool {
        #if DEBUG
            return true
        #else
            return ProcessInfo.processInfo.environment["VERBOSE_LOGGING"] == "true"
        #endif
    }
}

#else

// MARK: - Android Environment (Skip)
// Reads from ProcessInfo.processInfo.environment which is populated from
// BuildConfig values in Main.kt's AndroidAppMain.onCreate()

enum AppEnvironment {
    /// Get value from environment, returning nil for empty strings
    private static func getValue(key: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[key], !value.isEmpty {
            return value
        }
        return nil
    }

    static var supabaseURL: String? {
        getValue(key: "SUPABASE_URL")
    }

    static var supabasePublishableKey: String? {
        getValue(key: "SUPABASE_PUBLISHABLE_KEY")
    }

    static var upstashRedisURL: String? {
        getValue(key: "UPSTASH_REDIS_URL")
    }

    static var upstashRedisToken: String? {
        getValue(key: "UPSTASH_REDIS_TOKEN")
    }

    static var resendAPIKey: String? {
        getValue(key: "RESEND_API_KEY")
    }

    static var nextdoorClientId: String? {
        getValue(key: "NEXTDOOR_CLIENT_ID")
    }

    static var verboseLogging: Bool {
        true // Always verbose in development
    }
}

#endif
