//
//  ChallengeEngagementService.swift
//  Foodshare
//
//  Handles challenge engagement: likes and batch status checks
//  Uses single RPC calls for optimal performance (Phase 3: Ultra-Thin Client)
//

import Foundation
import OSLog
import Supabase

// MARK: - Challenge Engagement Status

/// Engagement status for a single challenge
struct ChallengeEngagementStatus: Sendable {
    let isLiked: Bool
    let likeCount: Int
}

// MARK: - Challenge Engagement Service

/// Actor-based service for managing challenge engagement (likes)
/// Uses repository pattern for database operations
actor ChallengeEngagementService {
    // MARK: - Singleton

    nonisolated static let shared: ChallengeEngagementService = {
        ChallengeEngagementService(supabase: MainActor.assumeIsolated { AuthenticationService.shared.supabase })
    }()

    // MARK: - Properties

    private let supabase: SupabaseClient
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ChallengeEngagement")

    /// In-memory cache for engagement status (cleared on sign-out)
    private var engagementCache: [Int: ChallengeEngagementStatus] = [:]

    /// Cache expiration time (5 minutes)
    private let cacheExpiration: TimeInterval = 300
    private var cacheTimestamps: [Int: Date] = [:]

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        logger.info("📊 [CHALLENGE-ENGAGEMENT] ChallengeEngagementService initialized")
    }

    // MARK: - Like Operations

    /// Toggle like on a challenge using repository
    /// Returns new like state and count
    @MainActor
    func toggleLike(challengeId: Int) async throws -> (isLiked: Bool, likeCount: Int) {
        logger.info("❤️ [CHALLENGE-ENGAGEMENT] Toggling like for challenge: \(challengeId)")

        guard let userId = try? await supabase.auth.session.user.id else {
            logger.error("❌ [CHALLENGE-ENGAGEMENT] User not authenticated")
            throw ChallengeEngagementError.notAuthenticated
        }

        // Use repository for database operations
        let repository = SupabaseChallengeRepository(supabase: supabase)

        do {
            let result = try await repository.toggleChallengeLike(challengeId: challengeId, profileId: userId)

            // Update cache
            await updateCache(challengeId: challengeId, isLiked: result.isLiked, likeCount: result.likeCount)

            logger
                .info(
                    "\(result.isLiked ? "❤️" : "💔") [CHALLENGE-ENGAGEMENT] \(result.isLiked ? "Liked" : "Unliked") challenge: \(challengeId)",
                )

            return (result.isLiked, result.likeCount)
        } catch {
            logger.error("❌ [CHALLENGE-ENGAGEMENT] Toggle like failed: \(error.localizedDescription)")
            throw ChallengeEngagementError.networkError(error.localizedDescription)
        }
    }

    /// Check if user has liked a challenge
    @MainActor
    func checkLiked(challengeId: Int) async throws -> (isLiked: Bool, likeCount: Int) {
        logger.debug("🔍 [CHALLENGE-ENGAGEMENT] Checking like status for challenge: \(challengeId)")

        // Check cache first
        if let cached = await getCachedStatus(challengeId: challengeId) {
            return (cached.isLiked, cached.likeCount)
        }

        guard let userId = try? await supabase.auth.session.user.id else {
            logger.error("❌ [CHALLENGE-ENGAGEMENT] User not authenticated")
            throw ChallengeEngagementError.notAuthenticated
        }

        let repository = SupabaseChallengeRepository(supabase: supabase)

        do {
            let isLiked = try await repository.hasLikedChallenge(challengeId: challengeId, profileId: userId)

            // Get challenge to fetch like count
            let challenge = try await repository.fetchChallenge(id: challengeId, userId: userId)
            let likeCount = challenge.challenge.challengeLikesCounter

            // Update cache
            await updateCache(challengeId: challengeId, isLiked: isLiked, likeCount: likeCount)

            return (isLiked, likeCount)
        } catch {
            logger.error("❌ [CHALLENGE-ENGAGEMENT] Check liked failed: \(error.localizedDescription)")
            throw ChallengeEngagementError.networkError(error.localizedDescription)
        }
    }

    // MARK: - Cache Management

    /// Update engagement cache
    private func updateCache(challengeId: Int, isLiked: Bool, likeCount: Int) {
        engagementCache[challengeId] = ChallengeEngagementStatus(
            isLiked: isLiked,
            likeCount: likeCount,
        )
        cacheTimestamps[challengeId] = Date()
    }

    /// Get cached engagement status if valid
    func getCachedStatus(challengeId: Int) -> ChallengeEngagementStatus? {
        guard let status = engagementCache[challengeId],
              let timestamp = cacheTimestamps[challengeId],
              Date().timeIntervalSince(timestamp) < cacheExpiration else
        {
            return nil
        }
        return status
    }

    /// Clear all cached engagement data (call on sign-out)
    func clearCache() {
        engagementCache.removeAll()
        cacheTimestamps.removeAll()
        logger.info("🧹 [CHALLENGE-ENGAGEMENT] Cache cleared")
    }
}

// MARK: - Challenge Engagement Errors

/// Errors that can occur during challenge engagement operations.
///
/// Thread-safe for Swift 6 concurrency.
enum ChallengeEngagementError: LocalizedError, Sendable {
    /// User is not authenticated
    case notAuthenticated
    /// Network request failed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Please sign in to like challenges"
        case let .networkError(message):
            "Network error: \(message)"
        }
    }
}
