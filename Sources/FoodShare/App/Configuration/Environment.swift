//
//  Environment.swift
//  Foodshare
//
//  Environment configuration
//  Reads from environment variables (Xcode scheme) or Config.plist (bundled file)
//

import Foundation

enum AppEnvironment {
    /// Load configuration from Config.plist bundled with the app
    private static let config: [String: String] = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: String] else {
            return [:]
        }
        return dict
    }()

    /// Get value from environment or Config.plist (environment takes precedence)
    private static func getValue(key: String, configKey: String? = nil) -> String? {
        // First try environment variable (for Xcode scheme configuration)
        if let envValue = ProcessInfo.processInfo.environment[key] {
            return envValue
        }

        // Fall back to Config.plist (for bundled configuration)
        let plistKey = configKey ?? key
        return config[plistKey]
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
