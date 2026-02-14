//
//  CurrentUserCache.swift
//  Foodshare
//
//  Global actor-based cache for the current user's profile.
//  The logged-in user's profile is accessed across many features
//  (Feed, Messaging, Forum, Profile, etc.). This centralizes caching
//  to eliminate duplicate API calls.
//

import Foundation
import OSLog

/// Global actor-based cache for the current authenticated user's profile.
///
/// The current user's profile is needed across many features for:
/// - Displaying user avatar/name in headers
/// - Checking user preferences
/// - Personalization features
/// - Authorization checks
///
/// Usage:
/// ```swift
/// if let profile = await CurrentUserCache.shared.getProfile() {
///     // Use cached profile
/// }
/// ```
actor CurrentUserCache {
    // MARK: - Singleton

    static let shared = CurrentUserCache()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "CurrentUserCache")

    /// Cached user profile
    private var profile: UserProfile?

    /// The user ID this cache is for
    private var cachedUserId: UUID?

    /// When the cache was last populated
    private var lastFetchTime: Date?

    /// Cache TTL: 5 minutes (user profile changes infrequently)
    private let cacheTTL: TimeInterval = 300

    /// In-flight fetch task to prevent duplicate requests
    private var fetchTask: Task<UserProfile?, Error>?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Get the current user's profile from cache.
    ///
    /// - Returns: Cached profile if valid and for the same user, nil otherwise
    func getProfile() -> UserProfile? {
        guard isCacheValid else { return nil }
        return profile
    }

    /// Get the current user's profile, fetching if needed.
    ///
    /// - Parameters:
    ///   - userId: The current user's ID
    ///   - forceRefresh: If true, bypasses cache and fetches fresh data
    ///   - fetchProfile: Closure to fetch profile from repository
    /// - Returns: User profile or nil if fetch fails
    func getProfile(
        userId: UUID,
        forceRefresh: Bool = false,
        fetchProfile: @Sendable () async throws -> UserProfile,
    ) async throws -> UserProfile {
        // Check if cache is for a different user
        if cachedUserId != userId {
            invalidate()
            cachedUserId = userId
        }

        // Return cached if valid and not forcing refresh
        if !forceRefresh, isCacheValid, let cached = profile {
            logger.debug("📦 Current user profile from cache")
            return cached
        }

        // If already fetching, wait for that task
        if let existingTask = fetchTask {
            logger.debug("⏳ Waiting for in-flight profile fetch")
            if let result = try await existingTask.value {
                return result
            }
            throw CacheFetchError.fetchFailed
        }

        // Fetch directly (avoid Task capture issues)
        logger.debug("🌐 Fetching current user profile")
        do {
            let fetched = try await fetchProfile()
            setProfile(fetched)
            return fetched
        } catch {
            logger.warning("Failed to fetch profile: \(error.localizedDescription)")
            throw error
        }
    }

    /// Update the cached profile (call after profile edits)
    func setProfile(_ profile: UserProfile) {
        self.profile = profile
        self.cachedUserId = profile.id
        self.lastFetchTime = Date()
        logger.debug("📦 Current user profile cached")
    }

    /// Invalidate the cache (call on logout)
    func invalidate() {
        profile = nil
        cachedUserId = nil
        lastFetchTime = nil
        fetchTask?.cancel()
        fetchTask = nil
        logger.debug("🗑️ Current user cache invalidated")
    }

    /// Check if the cache is for a specific user
    func isForUser(_ userId: UUID) -> Bool {
        cachedUserId == userId && isCacheValid
    }

    // MARK: - Private

    private var isCacheValid: Bool {
        guard let lastFetch = lastFetchTime, profile != nil else {
            return false
        }
        return Date().timeIntervalSince(lastFetch) < cacheTTL
    }

    enum CacheFetchError: Error {
        case fetchFailed
    }
}

// MARK: - Convenience Extensions

extension CurrentUserCache {
    /// Get user's display name (nickname) if cached
    func getDisplayName() -> String? {
        profile?.nickname
    }

    /// Get user's avatar URL if cached
    func getAvatarURL() -> URL? {
        guard let urlString = profile?.avatarUrl else { return nil }
        return URL(string: urlString)
    }

    /// Get user's search radius preference if cached
    func getSearchRadius() -> Int? {
        profile?.searchRadiusKm
    }
}
