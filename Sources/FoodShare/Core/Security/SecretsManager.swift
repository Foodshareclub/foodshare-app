//
//  SecretsManager.swift
//  Foodshare
//
//  Centralized secrets management with Keychain storage
//  Migrates Config.plist secrets to Keychain on first launch
//
//  Security Flow:
//  1. CI injects secrets as environment variables at build time
//  2. ci_post_clone.sh writes secrets to Config.plist (not in git)
//  3. On first launch, secrets migrate from Config.plist to Keychain
//  4. Subsequent launches read directly from Keychain
//  5. Config.plist can be cleared after migration
//

import Foundation
import OSLog

/// Secret keys managed by the app
enum SecretKey: String, CaseIterable, Sendable {
    case supabaseURL = "supabase_url"
    case supabasePublishableKey = "supabase_publishable_key"
    case upstashRedisURL = "upstash_redis_url"
    case upstashRedisToken = "upstash_redis_token"
    case resendAPIKey = "resend_api_key"
    case nextdoorClientId = "nextdoor_client_id"

    /// Config.plist key name
    var configPlistKey: String {
        switch self {
        case .supabaseURL: "SupabaseURL"
        case .supabasePublishableKey: "SupabasePublishableKey"
        case .upstashRedisURL: "UpstashRedisURL"
        case .upstashRedisToken: "UpstashRedisToken"
        case .resendAPIKey: "ResendAPIKey"
        case .nextdoorClientId: "NextdoorClientId"
        }
    }

    /// Environment variable name
    var environmentKey: String {
        switch self {
        case .supabaseURL: "SUPABASE_URL"
        case .supabasePublishableKey: "SUPABASE_PUBLISHABLE_KEY"
        case .upstashRedisURL: "UPSTASH_REDIS_URL"
        case .upstashRedisToken: "UPSTASH_REDIS_TOKEN"
        case .resendAPIKey: "RESEND_API_KEY"
        case .nextdoorClientId: "NEXTDOOR_CLIENT_ID"
        }
    }

    /// Whether this secret is required for app operation
    var isRequired: Bool {
        switch self {
        case .supabaseURL, .supabasePublishableKey:
            true
        default:
            false
        }
    }
}

/// Thread-safe secrets manager using actor isolation
actor SecretsManager {
    /// Shared instance
    static let shared = SecretsManager()

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "SecretsManager")
    private let keychain = KeychainHelper.shared

    /// UserDefaults key for tracking migration status
    private let migrationCompletedKey = "secrets_migration_completed_v1"

    /// In-memory cache for performance
    private var cache: [SecretKey: String] = [:]

    private init() {}

    // MARK: - Public API

    /// Get a secret value
    /// - Parameter key: The secret key
    /// - Returns: The secret value, or nil if not found
    func get(_ key: SecretKey) async -> String? {
        // Check cache first
        if let cached = cache[key] {
            return cached
        }

        // Try environment variable (for development/CI)
        if let envValue = ProcessInfo.processInfo.environment[key.environmentKey] {
            cache[key] = envValue
            return envValue
        }

        // Try Keychain
        do {
            if let keychainValue = try await keychain.retrieve(forKey: key.rawValue) {
                cache[key] = keychainValue
                return keychainValue
            }
        } catch {
            logger
                .error("Failed to retrieve secret from Keychain: \(key.rawValue), error: \(error.localizedDescription)")
        }

        // Try Config.plist as fallback (for backwards compatibility)
        if let plistValue = getFromConfigPlist(key) {
            // Migrate to Keychain for next time
            Task {
                try? await set(plistValue, for: key)
            }
            cache[key] = plistValue
            return plistValue
        }

        return nil
    }

    /// Get a required secret (throws if not found)
    /// - Parameter key: The secret key
    /// - Returns: The secret value
    func getRequired(_ key: SecretKey) async throws -> String {
        guard let value = await get(key) else {
            throw SecretsError.missingRequired(key)
        }
        return value
    }

    /// Set a secret value in Keychain
    /// - Parameters:
    ///   - value: The secret value
    ///   - key: The secret key
    func set(_ value: String, for key: SecretKey) async throws {
        try await keychain.save(value, forKey: key.rawValue)
        cache[key] = value
        logger.debug("Saved secret to Keychain: \(key.rawValue)")
    }

    /// Delete a secret from Keychain
    /// - Parameter key: The secret key
    func delete(_ key: SecretKey) async throws {
        try await keychain.delete(forKey: key.rawValue)
        cache.removeValue(forKey: key)
        logger.debug("Deleted secret from Keychain: \(key.rawValue)")
    }

    /// Clear all cached secrets (doesn't delete from Keychain)
    func clearCache() {
        cache.removeAll()
    }

    // MARK: - Migration

    /// Migrate secrets from Config.plist to Keychain
    /// Should be called on app launch
    func migrateIfNeeded() async {
        let defaults = UserDefaults.standard

        // Check if migration already completed
        guard !defaults.bool(forKey: migrationCompletedKey) else {
            logger.debug("Secrets migration already completed")
            return
        }

        logger.info("Starting secrets migration from Config.plist to Keychain...")

        var migratedCount = 0
        var failedCount = 0

        for key in SecretKey.allCases {
            // Skip if already in Keychain
            if await keychain.exists(forKey: key.rawValue) {
                continue
            }

            // Try to get from Config.plist
            if let value = getFromConfigPlist(key) {
                do {
                    try await set(value, for: key)
                    migratedCount += 1
                } catch {
                    logger.error("Failed to migrate secret: \(key.rawValue), error: \(error.localizedDescription)")
                    failedCount += 1
                }
            }
        }

        if failedCount == 0 {
            defaults.set(true, forKey: migrationCompletedKey)
            logger.info("Secrets migration completed. Migrated \(migratedCount) secrets.")
        } else {
            logger
                .warning("Secrets migration completed with errors. Migrated: \(migratedCount), Failed: \(failedCount)")
        }
    }

    /// Validate that all required secrets are available
    /// - Returns: List of missing required secrets
    func validateRequiredSecrets() async -> [SecretKey] {
        var missing: [SecretKey] = []

        for key in SecretKey.allCases where key.isRequired {
            if await get(key) == nil {
                missing.append(key)
            }
        }

        return missing
    }

    // MARK: - Convenience Properties

    /// Supabase URL (with caching)
    var supabaseURL: String? {
        get async {
            await get(.supabaseURL)
        }
    }

    /// Supabase publishable key (with caching)
    var supabasePublishableKey: String? {
        get async {
            await get(.supabasePublishableKey)
        }
    }

    // MARK: - Private Helpers

    private func getFromConfigPlist(_ key: SecretKey) -> String? {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let dict = NSDictionary(contentsOfFile: path) as? [String: Any],
              let value = dict[key.configPlistKey] as? String,
              !value.isEmpty else
        {
            return nil
        }
        return value
    }
}

// MARK: - Errors

enum SecretsError: LocalizedError, Sendable {
    case missingRequired(SecretKey)
    case migrationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .missingRequired(key):
            "Required secret missing: \(key.rawValue)"
        case let .migrationFailed(message):
            "Secrets migration failed: \(message)"
        }
    }
}

// MARK: - AppEnvironment Integration

/// Extension to integrate with existing AppEnvironment pattern
extension AppEnvironment {
    /// Get Supabase URL from SecretsManager
    static func supabaseURLSecure() async -> String? {
        await SecretsManager.shared.supabaseURL
    }

    /// Get Supabase publishable key from SecretsManager
    static func supabasePublishableKeySecure() async -> String? {
        await SecretsManager.shared.supabasePublishableKey
    }
}
