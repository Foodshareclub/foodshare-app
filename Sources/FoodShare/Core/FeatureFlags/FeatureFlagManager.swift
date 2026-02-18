//
//  FeatureFlagManager.swift
//  Foodshare
//
//  Enterprise feature flag manager with remote configuration
//



#if !SKIP
import Foundation
import Observation
import OSLog
import Supabase

// MARK: - Feature Flag Manager

/// Manages feature flags with local and remote configuration
///
/// Features:
/// - Local defaults with remote overrides
/// - Percentage-based rollouts
/// - User segment targeting
/// - Local overrides for testing
/// - Automatic refresh from server
///
/// Usage:
/// ```swift
/// // Check if feature is enabled
/// if await FeatureFlagManager.shared.isEnabled(.newFeedAlgorithm) {
///     showNewFeed()
/// }
///
/// // Get flag value with segment
/// let enabled = await FeatureFlagManager.shared.isEnabled(
///     .premiumSubscription,
///     forSegment: "beta_testers"
/// )
///
/// // Override locally (for testing)
/// await FeatureFlagManager.shared.setOverride(.developerTools, enabled: true)
/// ```
@MainActor
@Observable
final class FeatureFlagManager {
    // MARK: - Singleton

    static let shared = FeatureFlagManager()

    // MARK: - Properties

    /// Remote flag values fetched from server
    private var remoteFlags: [FeatureFlag: FeatureFlagValue] = [:]

    /// Local overrides (persisted to UserDefaults)
    private var localOverrides: [FeatureFlag: FeatureFlagOverride] = [:]

    /// Whether flags have been loaded from server
    private(set) var isLoaded = false

    /// Last time flags were refreshed
    private(set) var lastRefreshDate: Date?

    /// User ID for percentage-based rollouts
    private var userId: UUID?

    /// User segments for targeting
    private var userSegments: Set<String> = []

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "FeatureFlags")
    private let defaults = UserDefaults.standard
    private let overridesKey = "feature_flag_overrides"

    // MARK: - Initialization

    private init() {
        loadLocalOverrides()
    }

    // MARK: - Configuration

    /// Configure the manager with user context
    func configure(userId: UUID, segments: [String] = []) {
        self.userId = userId
        self.userSegments = Set(segments)
        logger.info("Configured with user: \(userId.uuidString.prefix(8))..., segments: \(segments)")
    }

    /// Add a user segment
    func addSegment(_ segment: String) {
        userSegments.insert(segment)
    }

    /// Remove a user segment
    func removeSegment(_ segment: String) {
        userSegments.remove(segment)
    }

    // MARK: - Flag Checking

    /// Check if a feature flag is enabled
    ///
    /// Priority order:
    /// 1. Local override (if set)
    /// 2. Remote value (if loaded and not expired)
    /// 3. Default value
    func isEnabled(_ flag: FeatureFlag) -> Bool {
        // Check local override first
        if let override = localOverrides[flag] {
            logger.debug("Using override for \(flag.rawValue): \(override.enabled)")
            return override.enabled
        }

        // Check remote value
        if let remote = remoteFlags[flag], !remote.isExpired {
            // Check segment targeting
            if let targetSegments = remote.targetSegments, !targetSegments.isEmpty {
                let hasTargetSegment = !userSegments.isDisjoint(with: targetSegments)
                if !hasTargetSegment {
                    logger.debug("User not in target segments for \(flag.rawValue)")
                    return flag.defaultValue
                }
            }

            // Check percentage rollout
            if remote.rolloutPercentage < 100 {
                let inRollout = isUserInRollout(flag: flag, percentage: remote.rolloutPercentage)
                logger.debug("\(flag.rawValue) rollout check: \(inRollout) (\(remote.rolloutPercentage)%)")
                return inRollout && remote.enabled
            }

            return remote.enabled
        }

        // Fall back to default
        return flag.defaultValue
    }

    /// Check if flag is enabled for a specific segment
    func isEnabled(_ flag: FeatureFlag, forSegment segment: String) -> Bool {
        // Temporarily add segment, check flag, restore
        let wasInSegment = userSegments.contains(segment)
        userSegments.insert(segment)
        let result = isEnabled(flag)
        if !wasInSegment {
            userSegments.remove(segment)
        }
        return result
    }

    /// Get all enabled flags
    var enabledFlags: [FeatureFlag] {
        FeatureFlag.allCases.filter { isEnabled($0) }
    }

    /// Get all flags with their current values
    var allFlagValues: [(flag: FeatureFlag, enabled: Bool, source: String)] {
        FeatureFlag.allCases.map { flag in
            let enabled = isEnabled(flag)
            let source = if localOverrides[flag] != nil {
                "override"
            } else if remoteFlags[flag] != nil {
                "remote"
            } else {
                "default"
            }
            return (flag, enabled, source)
        }
    }

    // MARK: - Rollout Logic

    private func isUserInRollout(flag: FeatureFlag, percentage: Int) -> Bool {
        guard let userId else {
            // No user ID, use random but consistent bucket
            return false
        }

        // Create a stable hash based on user ID and flag
        let input = "\(userId.uuidString):\(flag.rawValue)"
        let hash = input.hashValue
        let bucket = abs(hash) % 100

        return bucket < percentage
    }

    // MARK: - Local Overrides

    /// Set a local override for a flag
    func setOverride(_ flag: FeatureFlag, enabled: Bool, reason: String = "Manual override") {
        let override = FeatureFlagOverride(flag: flag, enabled: enabled, reason: reason)
        localOverrides[flag] = override
        saveLocalOverrides()
        logger.info("Set override for \(flag.rawValue): \(enabled) (\(reason))")
    }

    /// Remove a local override
    func removeOverride(_ flag: FeatureFlag) {
        localOverrides.removeValue(forKey: flag)
        saveLocalOverrides()
        logger.info("Removed override for \(flag.rawValue)")
    }

    /// Clear all local overrides
    func clearAllOverrides() {
        localOverrides.removeAll()
        saveLocalOverrides()
        logger.info("Cleared all overrides")
    }

    /// Get current override for a flag
    func override(for flag: FeatureFlag) -> FeatureFlagOverride? {
        localOverrides[flag]
    }

    /// Whether a flag has a local override
    func hasOverride(_ flag: FeatureFlag) -> Bool {
        localOverrides[flag] != nil
    }

    private func loadLocalOverrides() {
        guard let data = defaults.data(forKey: overridesKey),
              let overrides = try? JSONDecoder().decode([FeatureFlagOverride].self, from: data) else
        {
            return
        }

        localOverrides = Dictionary(uniqueKeysWithValues: overrides.map { ($0.flag, $0) })
        logger.debug("Loaded \(overrides.count) local overrides")
    }

    private func saveLocalOverrides() {
        let overrides = Array(localOverrides.values)
        if let data = try? JSONEncoder().encode(overrides) {
            defaults.set(data, forKey: overridesKey)
        }
    }

    // MARK: - Remote Loading

    /// Database row structure for feature_flags table
    private struct FeatureFlagRow: Codable, Sendable {
        let id: UUID
        let flagKey: String
        let enabled: Bool
        let rolloutPercentage: Int
        let targetSegments: [String]?
        let expiresAt: Date?
        let description: String?
        let category: String?
        let createdAt: Date
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case flagKey = "flag_key"
            case enabled
            case rolloutPercentage = "rollout_percentage"
            case targetSegments = "target_segments"
            case expiresAt = "expires_at"
            case description
            case category
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }

    /// Refresh flags from the server using default Supabase client
    func refresh() async throws {
        logger.notice("🚩 refresh() called - starting Supabase load")
        try await loadFromSupabase(using: SupabaseManager.shared.client)
        logger.notice("🚩 refresh() completed - isLoaded=\(self.isLoaded), flagCount=\(self.remoteFlags.count)")
    }

    /// Load flags from Supabase
    ///
    /// Queries the feature_flags table and populates remoteFlags dictionary.
    /// Falls back to cached/default values if fetch fails.
    ///
    /// - Parameter client: Supabase client to use for the query
    func loadFromSupabase(using client: SupabaseClient) async throws {
        logger.info("Fetching feature flags from Supabase")

        do {
            let rows: [FeatureFlagRow] = try await client
                .from("feature_flags")
                .select()
                .execute()
                .value

            logger.debug("Received \(rows.count) feature flags from server")

            var loadedCount = 0
            for row in rows {
                // Map flag_key to FeatureFlag enum
                guard let flag = FeatureFlag(rawValue: row.flagKey) else {
                    logger.warning("Unknown feature flag key: \(row.flagKey)")
                    continue
                }

                let value = FeatureFlagValue(
                    flag: flag,
                    enabled: row.enabled,
                    rolloutPercentage: row.rolloutPercentage,
                    targetSegments: row.targetSegments,
                    expiresAt: row.expiresAt,
                    updatedAt: row.updatedAt,
                )

                remoteFlags[flag] = value
                loadedCount += 1
            }

            isLoaded = true
            lastRefreshDate = Date()
            logger.info("Loaded \(loadedCount) feature flags from Supabase")

            // Log the free_premium_trial flag specifically
            if let trialFlag = remoteFlags[.freePremiumTrial] {
                logger
                    .notice(
                        "🚩 free_premium_trial loaded: enabled=\(trialFlag.enabled), rollout=\(trialFlag.rolloutPercentage)%",
                    )
            } else {
                logger.error("🚩 free_premium_trial NOT found in response")
            }

            // Cache the results for offline access
            cacheFlags()

        } catch {
            logger.error("🚩 ERROR loading from Supabase: \(error.localizedDescription)")

            // Try to load from cache as fallback
            if loadCachedFlags() {
                logger.notice("🚩 Using cached flags as fallback")
            } else {
                logger.error("🚩 No cached flags available, throwing error")
                // Re-throw if we have no fallback
                throw error
            }
        }
    }

    // MARK: - Caching

    private let cacheKey = "feature_flags_cache"
    private let cacheTimestampKey = "feature_flags_cache_timestamp"
    private let maxCacheAge: TimeInterval = 24 * 60 * 60 // 24 hours

    /// Cache current flags to UserDefaults for offline access
    private func cacheFlags() {
        let cacheData = remoteFlags.values.map { value in
            CachedFlagValue(
                flagKey: value.flag.rawValue,
                enabled: value.enabled,
                rolloutPercentage: value.rolloutPercentage,
                targetSegments: value.targetSegments,
                expiresAt: value.expiresAt,
                updatedAt: value.updatedAt,
            )
        }

        if let data = try? JSONEncoder().encode(cacheData) {
            defaults.set(data, forKey: cacheKey)
            defaults.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
            logger.debug("Cached \(cacheData.count) feature flags")
        }
    }

    /// Load flags from cache
    /// - Returns: Whether cache was successfully loaded
    @discardableResult
    private func loadCachedFlags() -> Bool {
        // Check cache age
        let timestamp = defaults.double(forKey: cacheTimestampKey)
        if timestamp > 0 {
            let cacheDate = Date(timeIntervalSince1970: timestamp)
            if Date().timeIntervalSince(cacheDate) > maxCacheAge {
                logger.debug("Feature flags cache expired")
                return false
            }
        }

        guard let data = defaults.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([CachedFlagValue].self, from: data) else
        {
            return false
        }

        for item in cached {
            guard let flag = FeatureFlag(rawValue: item.flagKey) else { continue }

            let value = FeatureFlagValue(
                flag: flag,
                enabled: item.enabled,
                rolloutPercentage: item.rolloutPercentage,
                targetSegments: item.targetSegments,
                expiresAt: item.expiresAt,
                updatedAt: item.updatedAt,
            )

            remoteFlags[flag] = value
        }

        isLoaded = true
        logger.debug("Loaded \(cached.count) feature flags from cache")
        return true
    }

    /// Cached flag value structure
    private struct CachedFlagValue: Codable {
        let flagKey: String
        let enabled: Bool
        let rolloutPercentage: Int
        let targetSegments: [String]?
        let expiresAt: Date?
        let updatedAt: Date
    }

    // MARK: - Debug

    /// Debug description of all flags
    var debugDescription: String {
        var lines = ["Feature Flags:"]

        for category in FeatureFlag.Category.allCases {
            let flags = FeatureFlag.allCases.filter { $0.category == category }
            lines.append("\n\(category.rawValue):")

            for flag in flags {
                let enabled = isEnabled(flag)
                let override = localOverrides[flag]
                let remote = remoteFlags[flag]

                var status = enabled ? "[ON]" : "[OFF]"
                if override != nil {
                    status += " (override)"
                } else if remote != nil {
                    status += " (remote)"
                } else {
                    status += " (default)"
                }

                lines.append("  \(flag.displayName): \(status)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

// MARK: - Convenience Extensions

extension FeatureFlagManager {
    /// Quick check for common flags
    var isNewFeedEnabled: Bool {
        isEnabled(.newFeedAlgorithm)
    }
    var isChallengesEnabled: Bool {
        isEnabled(.challenges)
    }
    var isAchievementsEnabled: Bool {
        isEnabled(.achievements)
    }
    var isPremiumEnabled: Bool {
        isEnabled(.premiumSubscription)
    }
    var isDeveloperToolsEnabled: Bool {
        isEnabled(.developerTools)
    }

    /// Check if free premium trial is active (bypasses premium gates for map & challenges)
    var isFreePremiumTrialEnabled: Bool {
        let enabled = isEnabled(.freePremiumTrial)
        let hasRemote = remoteFlags[.freePremiumTrial] != nil
        let hasOverride = localOverrides[.freePremiumTrial] != nil
        logger
            .notice(
                "🚩 freePremiumTrial check: enabled=\(enabled), hasRemote=\(hasRemote), hasOverride=\(hasOverride), isLoaded=\(self.isLoaded)",
            )
        return enabled
    }
}

// MARK: - SwiftUI Integration

import SwiftUI

/// View modifier for conditionally showing content based on feature flag
struct FeatureFlagModifier: ViewModifier {
    let flag: FeatureFlag
    @State private var isEnabled = false

    func body(content: Content) -> some View {
        Group {
            if isEnabled {
                content
            }
        }
        .task {
            isEnabled = await FeatureFlagManager.shared.isEnabled(flag)
        }
    }
}

extension View {
    /// Show this view only if the feature flag is enabled
    func featureFlag(_ flag: FeatureFlag) -> some View {
        modifier(FeatureFlagModifier(flag: flag))
    }
}


#endif
