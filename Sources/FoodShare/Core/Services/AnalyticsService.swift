//
//  AnalyticsService.swift
//  Foodshare
//
//  Analytics service using server-side RPCs for view tracking and trending posts.
//  Phase 4: Ultra-Thin Client Architecture
//

import Foundation
import OSLog
import Supabase

// MARK: - Analytics Response Types

/// Response from track_view RPC
private struct TrackViewResponse: Decodable {
    let success: Bool
    let counted: Bool?
    let viewCount: Int?
    let message: String?
    let error: AnalyticsRPCError?

    enum CodingKeys: String, CodingKey {
        case success
        case counted
        case viewCount = "view_count"
        case message
        case error
    }
}

/// Response from get_trending_posts RPC
private struct TrendingPostsResponse: Decodable {
    let success: Bool
    let posts: [TrendingPost]?
    let windowHours: Int?
    let error: AnalyticsRPCError?

    enum CodingKeys: String, CodingKey {
        case success
        case posts
        case windowHours = "window_hours"
        case error
    }
}

/// Trending post from RPC
struct TrendingPost: Decodable, Identifiable, Sendable {
    let id: Int
    let postName: String
    let postDescription: String?
    let images: [String]?
    let postType: String
    let latitude: Double
    let longitude: Double
    let postAddress: String?
    let profileId: UUID
    let createdAt: Date
    let viewCount: Int
    let likeCount: Int
    let trendingScore: Double
    let distanceKm: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case postName = "post_name"
        case postDescription = "post_description"
        case images
        case postType = "post_type"
        case latitude
        case longitude
        case postAddress = "post_address"
        case profileId = "profile_id"
        case createdAt = "created_at"
        case viewCount = "view_count"
        case likeCount = "like_count"
        case trendingScore = "trending_score"
        case distanceKm = "distance_km"
    }
}

/// Response from get_post_analytics RPC
private struct PostAnalyticsResponse: Decodable {
    let success: Bool
    let analytics: PostAnalytics?
    let periodDays: Int?
    let error: AnalyticsRPCError?

    enum CodingKeys: String, CodingKey {
        case success
        case analytics
        case periodDays = "period_days"
        case error
    }
}

/// Post analytics data
struct PostAnalytics: Decodable, Sendable {
    let totalViews: Int
    let totalLikes: Int
    let viewsByDay: [DailyViews]
    let uniqueViewers: Int
    let engagementRate: Double

    enum CodingKeys: String, CodingKey {
        case totalViews = "total_views"
        case totalLikes = "total_likes"
        case viewsByDay = "views_by_day"
        case uniqueViewers = "unique_viewers"
        case engagementRate = "engagement_rate"
    }

    struct DailyViews: Decodable, Sendable {
        let date: String
        let count: Int
    }
}

/// RPC error response
private struct AnalyticsRPCError: Decodable {
    let code: String
    let message: String
}

// MARK: - Analytics Service

/// Service for analytics operations using server-side RPCs
actor AnalyticsService {
    // MARK: - Singleton

    static let shared = AnalyticsService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "Analytics")

    /// Session ID for view debouncing
    private let sessionId: String

    // MARK: - Initialization

    private init() {
        // Generate session ID for this app session
        sessionId = UUID().uuidString
        logger.info("📊 [ANALYTICS] AnalyticsService initialized with session: \(self.sessionId.prefix(8))...")
    }

    // MARK: - View Tracking

    /// Track a view for a post (server-side debounced)
    /// Returns the current view count
    @MainActor
    func trackView(postId: Int) async throws -> Int {
        logger.debug("👁️ [ANALYTICS] Tracking view for post: \(postId)")

        let supabase = SupabaseManager.shared.client

        let params: [String: AnyEncodableValue] = [
            "p_post_id": .int(postId),
            "p_session_id": .string(sessionId)
        ]

        let response = try await supabase
            .rpc("track_view", params: params)
            .execute()

        let result = try JSONDecoder().decode(TrackViewResponse.self, from: response.data)

        guard result.success else {
            if let error = result.error {
                logger.error("❌ [ANALYTICS] Track view failed: \(error.message)")
                throw AnalyticsError.serverError(error.message)
            }
            throw AnalyticsError.serverError("Unknown error")
        }

        let viewCount = result.viewCount ?? 0
        let counted = result.counted ?? false

        if counted {
            logger.debug("✅ [ANALYTICS] View counted for post \(postId), total: \(viewCount)")
        } else {
            logger.debug("⏭️ [ANALYTICS] View debounced for post \(postId)")
        }

        return viewCount
    }

    // MARK: - Trending Posts

    /// Get trending posts based on recent engagement
    @MainActor
    func getTrendingPosts(
        limit: Int = 20,
        offset: Int = 0,
        hoursWindow: Int = 24,
        latitude: Double? = nil,
        longitude: Double? = nil,
        radiusKm: Double? = nil,
    ) async throws -> [TrendingPost] {
        logger.info("🔥 [ANALYTICS] Fetching trending posts")

        let supabase = SupabaseManager.shared.client

        var params: [String: AnyEncodableValue] = [
            "p_limit": .int(limit),
            "p_offset": .int(offset),
            "p_hours_window": .int(hoursWindow)
        ]

        if let lat = latitude, let lng = longitude {
            params["p_latitude"] = .double(lat)
            params["p_longitude"] = .double(lng)
        }

        if let radius = radiusKm {
            params["p_radius_km"] = .double(radius)
        }

        let response = try await supabase
            .rpc("get_trending_posts", params: params)
            .execute()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(TrendingPostsResponse.self, from: response.data)

        guard result.success else {
            if let error = result.error {
                logger.error("❌ [ANALYTICS] Get trending failed: \(error.message)")
                throw AnalyticsError.serverError(error.message)
            }
            throw AnalyticsError.serverError("Unknown error")
        }

        let posts = result.posts ?? []
        logger.info("✅ [ANALYTICS] Fetched \(posts.count) trending posts")

        return posts
    }

    // MARK: - Post Analytics (for post owners)

    /// Get analytics for a specific post (owner only)
    @MainActor
    func getPostAnalytics(postId: Int, days: Int = 7) async throws -> PostAnalytics {
        logger.info("📈 [ANALYTICS] Fetching analytics for post: \(postId)")

        let supabase = SupabaseManager.shared.client

        let response = try await supabase
            .rpc("get_post_analytics", params: [
                "p_post_id": postId,
                "p_days": days
            ])
            .execute()

        let result = try JSONDecoder().decode(PostAnalyticsResponse.self, from: response.data)

        guard result.success, let analytics = result.analytics else {
            if let error = result.error {
                logger.error("❌ [ANALYTICS] Get analytics failed: \(error.message)")
                switch error.code {
                case "AUTH_FORBIDDEN":
                    throw AnalyticsError.notAuthorized
                case "POST_NOT_FOUND":
                    throw AnalyticsError.postNotFound
                default:
                    throw AnalyticsError.serverError(error.message)
                }
            }
            throw AnalyticsError.serverError("Unknown error")
        }

        logger.info("✅ [ANALYTICS] Fetched analytics: \(analytics.totalViews) views, \(analytics.totalLikes) likes")

        return analytics
    }
}

// MARK: - Encodable Value Helper

/// Helper enum for mixed-type RPC parameters
private enum AnyEncodableValue: Encodable {
    case int(Int)
    case double(Double)
    case string(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        }
    }
}

// MARK: - Analytics Errors

/// Errors that can occur during analytics operations
enum AnalyticsError: LocalizedError, Sendable {
    case postNotFound
    case notAuthorized
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .postNotFound:
            "Post not found"
        case .notAuthorized:
            "Not authorized to view analytics"
        case let .serverError(message):
            message
        }
    }
}
