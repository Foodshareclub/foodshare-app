//
//  CacheWarmingService.swift
//  Foodshare
//
//  Prefetches commonly accessed data on app launch to reduce perceived latency
//  and minimize API calls during user navigation.
//

import Foundation
import OSLog

/// Service that warms caches by prefetching commonly accessed data.
///
/// Call `warmCaches()` after authentication to prefetch:
/// - Categories (rarely change, used across multiple screens)
/// - User profile (needed for personalization)
///
/// Uses low-priority background execution to avoid blocking the UI.
@MainActor
final class CacheWarmingService {
    // MARK: - Singleton

    static let shared = CacheWarmingService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "CacheWarmingService")
    private var isWarming = false
    private var lastWarmTime: Date?

    /// Minimum interval between cache warming attempts (5 minutes)
    private let minWarmInterval: TimeInterval = 300

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Warm caches by prefetching commonly accessed data.
    /// Runs in background with low priority to avoid blocking UI.
    ///
    /// - Parameter userId: The authenticated user's ID (if available)
    func warmCaches(userId: UUID? = nil) {
        // Prevent concurrent warming
        guard !isWarming else {
            logger.debug("Cache warming already in progress, skipping")
            return
        }

        // Prevent too frequent warming
        if let lastWarm = lastWarmTime, Date().timeIntervalSince(lastWarm) < minWarmInterval {
            logger.debug("Cache warmed recently, skipping")
            return
        }

        isWarming = true
        lastWarmTime = Date()

        Task(priority: .background) { [weak self] in
            await self?.performCacheWarming(userId: userId)
        }
    }

    /// Warm caches specific to authenticated users
    /// Call this after successful authentication
    func warmAuthenticatedCaches(userId: UUID) {
        warmCaches(userId: userId)
    }

    // MARK: - Private Implementation

    private func performCacheWarming(userId: UUID?) async {
        logger.info("🔥 Starting cache warming...")
        let startTime = CFAbsoluteTimeGetCurrent()

        // Warm in parallel for maximum efficiency
        await withTaskGroup(of: Void.self) { group in
            // Categories - rarely change, used by Feed, Search, Forum
            group.addTask { await self.warmCategories() }

            // User profile - if authenticated
            if let userId {
                group.addTask { await self.warmUserProfile(userId: userId) }
            }
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        logger.info("✅ Cache warming completed in \(String(format: "%.2f", elapsed))s")

        await MainActor.run {
            self.isWarming = false
        }
    }

    private func warmCategories() async {
        do {
            // Use global CategoriesCache - shared across all features
            _ = try await CategoriesCache.shared.getCategories()
            logger.debug("📦 Categories cache warmed")
        } catch {
            logger.warning("Failed to warm categories cache: \(error.localizedDescription)")
        }
    }

    private func warmUserProfile(userId: UUID) async {
        do {
            // Use the profile repository to fetch user profile
            // This will be deduplicated if another request is in flight
            let profileRepository = SupabaseProfileRepository(supabase: SupabaseManager.shared.client)
            _ = try await profileRepository.fetchProfile(userId: userId)
            logger.debug("👤 User profile cache warmed")
        } catch {
            logger.warning("Failed to warm user profile cache: \(error.localizedDescription)")
        }
    }
}
