//
//  SupabaseActivityRepository.swift
//  Foodshare
//
//  Supabase implementation of activity repository with offline-first support
//  Features retry logic with exponential backoff for transient failures
//



#if !SKIP
import Foundation
import OSLog
import Supabase

@MainActor
final class SupabaseActivityRepository: BaseSupabaseRepository, ActivityRepository {
    // In-memory cache for activities
    private var cachedActivities: [ActivityItem] = []

    init(supabase: Supabase.SupabaseClient) {
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "ActivityRepository")
    }

    // MARK: - Fetch Activities (Server-Side)

    func fetchActivities(offset: Int, limit: Int) async throws -> [ActivityItem] {
        let dtos: [MixedActivityDTO] = try await executeRPC(
            "get_mixed_activity_feed",
            params: MixedActivityParams(pLimit: limit, pOffset: offset)
        )
        
        let items = dtos.map { $0.toActivityItem() }
        logger.debug("Fetched \(items.count) activity items (offset: \(offset))")
        return items
    }

    // MARK: - Caching

    func fetchCachedActivities() async -> [ActivityItem] {
        logger.debug("Fetching \(self.cachedActivities.count) cached activities")
        return cachedActivities
    }

    func cacheActivities(_ activities: [ActivityItem]) async throws {
        cachedActivities = activities
        logger.debug("Cached \(activities.count) activities in memory")
    }
}

// MARK: - DTOs

/// Parameters for the get_mixed_activity_feed RPC
private struct MixedActivityParams: Encodable {
    let pLimit: Int
    let pOffset: Int

    enum CodingKeys: String, CodingKey {
        case pLimit = "p_limit"
        case pOffset = "p_offset"
    }
}

/// DTO for decoding the get_mixed_activity_feed RPC response
private struct MixedActivityDTO: Decodable {
    let activityType: String
    let title: String
    let subtitle: String
    let imageUrl: String?
    let timestamp: Date
    let actorName: String?
    let actorAvatarUrl: String?
    let linkedPostId: Int?
    let linkedForumId: Int?
    let linkedProfileId: UUID?

    enum CodingKeys: String, CodingKey {
        case activityType = "activity_type"
        case title
        case subtitle
        case imageUrl = "image_url"
        case timestamp
        case actorName = "actor_name"
        case actorAvatarUrl = "actor_avatar_url"
        case linkedPostId = "linked_post_id"
        case linkedForumId = "linked_forum_id"
        case linkedProfileId = "linked_profile_id"
    }

    func toActivityItem() -> ActivityItem {
        let type = ActivityType(rawValue: activityType) ?? .newListing

        return ActivityItem(
            id: UUID(),
            type: type,
            title: title,
            subtitle: subtitle,
            imageURL: imageUrl.flatMap { URL(string: $0) },
            timestamp: timestamp,
            actorName: actorName,
            actorAvatarURL: actorAvatarUrl.flatMap { URL(string: $0) },
            linkedPostId: linkedPostId,
            linkedForumId: linkedForumId,
            linkedProfileId: linkedProfileId,
        )
    }
}


#endif
