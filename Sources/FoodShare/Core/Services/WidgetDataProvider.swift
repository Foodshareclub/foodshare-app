//
//  WidgetDataProvider.swift
//  Foodshare
//
//  Service for updating widget data in the shared App Group container
//

#if !SKIP
import CoreLocation
#endif
import Foundation
import OSLog
import Supabase
import WidgetKit

// MARK: - RPC Parameters

private struct WidgetNearbyPostsParams: Encodable {
    let userLat: Double
    let userLng: Double
    let radiusMeters: Double
    let postTypeFilter: String?
    let pageLimit: Int
    let pageCursor: Int?

    enum CodingKeys: String, CodingKey {
        case userLat = "user_lat"
        case userLng = "user_lng"
        case radiusMeters = "radius_meters"
        case postTypeFilter = "post_type_filter"
        case pageLimit = "page_limit"
        case pageCursor = "page_cursor"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userLat, forKey: .userLat)
        try container.encode(userLng, forKey: .userLng)
        try container.encode(radiusMeters, forKey: .radiusMeters)
        if let filter = postTypeFilter {
            try container.encode(filter, forKey: .postTypeFilter)
        } else {
            try container.encodeNil(forKey: .postTypeFilter)
        }
        try container.encode(pageLimit, forKey: .pageLimit)
        if let cursor = pageCursor {
            try container.encode(cursor, forKey: .pageCursor)
        } else {
            try container.encodeNil(forKey: .pageCursor)
        }
    }
}

// MARK: - Widget Data Provider

@MainActor
final class WidgetDataProvider {
    static let shared = WidgetDataProvider(supabase: AuthenticationService.shared.supabase)

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "WidgetDataProvider")
    private let appGroupIdentifier = "group.club.foodshare"
    private let supabase: SupabaseClient

    private var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    init(supabase: SupabaseClient) {
        self.supabase = supabase
    }

    // MARK: - Update All Widget Data

    /// Update all widget data - call this periodically or on significant data changes
    func updateAllWidgetData(userId: UUID?, userLocation: CLLocationCoordinate2D?) async {
        logger.info("📱 [Widget] Updating all widget data...")

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.updateNearbyFoodData(location: userLocation)
            }

            if let userId {
                group.addTask {
                    await self.updateUserStats(userId: userId)
                }

                group.addTask {
                    await self.updateActiveChallenge(userId: userId)
                }
            }
        }

        // Reload all widget timelines
        WidgetCenter.shared.reloadAllTimelines()

        logger.info("✅ [Widget] All widget data updated")
    }

    // MARK: - Nearby Food Data

    func updateNearbyFoodData(location: CLLocationCoordinate2D?) async {
        guard let containerURL else {
            logger.warning("⚠️ [Widget] App Group container not available")
            return
        }

        do {
            var items: [NearbyFoodItemDTO] = []

            if let location {
                // Fetch nearby listings from Supabase using PostGIS
                let params = WidgetNearbyPostsParams(
                    userLat: location.latitude,
                    userLng: location.longitude,
                    radiusMeters: 16093.4, // ~10 miles in meters
                    postTypeFilter: nil,
                    pageLimit: 10,
                    pageCursor: nil,
                )
                let response = try await supabase
                    .rpc("get_nearby_posts", params: params)
                    .execute()

                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                items = try decoder.decode([NearbyFoodItemDTO].self, from: response.data)
            } else {
                // Fallback: fetch recent listings without distance
                let response = try await supabase
                    .from("posts")
                    .select("id, post_name, post_type")
                    .eq("is_active", value: true)
                    .eq("is_arranged", value: false)
                    .order("created_at", ascending: false)
                    .limit(10)
                    .execute()

                struct SimpleListing: Decodable {
                    let id: Int64
                    let postName: String
                    let postType: String?

                    enum CodingKeys: String, CodingKey {
                        case id
                        case postName = "post_name"
                        case postType = "post_type"
                    }
                }

                let listings = try JSONDecoder().decode([SimpleListing].self, from: response.data)
                items = listings.map { listing in
                    NearbyFoodItemDTO(
                        id: listing.id,
                        name: listing.postName,
                        category: listing.postType ?? "other",
                        distance: 0,
                        imageURL: nil,
                    )
                }
            }

            // Write to shared container
            let fileURL = containerURL.appendingPathComponent("nearby_food.json")
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL)

            logger.debug("📦 [Widget] Saved \(items.count) nearby food items")
        } catch {
            logger.error("❌ [Widget] Failed to update nearby food data: \(error.localizedDescription)")
        }
    }

    // MARK: - User Stats Data

    func updateUserStats(userId: UUID) async {
        guard let containerURL else { return }

        do {
            let response = try await supabase
                .from("profile_stats")
                .select("*")
                .eq("id", value: userId.uuidString)
                .single()
                .execute()

            struct ProfileStatsDTO: Decodable {
                let totalShared: Int?
                let totalReceived: Int?
                let impactScore: Int?
                let currentStreak: Int?
                let rank: Int?

                enum CodingKeys: String, CodingKey {
                    case totalShared = "total_shared"
                    case totalReceived = "total_received"
                    case impactScore = "impact_score"
                    case currentStreak = "current_streak"
                    case rank
                }
            }

            let statsResponse = try JSONDecoder().decode(ProfileStatsDTO.self, from: response.data)

            let stats = UserStatsDTO(
                totalShared: statsResponse.totalShared ?? 0,
                totalReceived: statsResponse.totalReceived ?? 0,
                impactScore: statsResponse.impactScore ?? 0,
                streak: statsResponse.currentStreak ?? 0,
                rank: statsResponse.rank,
            )

            let fileURL = containerURL.appendingPathComponent("user_stats.json")
            let data = try JSONEncoder().encode(stats)
            try data.write(to: fileURL)

            logger.debug("📊 [Widget] Saved user stats")
        } catch {
            logger.error("❌ [Widget] Failed to update user stats: \(error.localizedDescription)")
        }
    }

    // MARK: - Active Challenge Data

    func updateActiveChallenge(userId: UUID) async {
        guard let containerURL else { return }

        do {
            // Fetch user's active challenge
            let response = try await supabase
                .from("challenge_participants")
                .select("""
                    progress,
                    challenges (
                        id,
                        title,
                        description,
                        goal,
                        reward,
                        category,
                        end_date
                    )
                """)
                .eq("profile_id", value: userId.uuidString)
                .eq("status", value: "active")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()

            struct ChallengeParticipantDTO: Decodable {
                let progress: Int
                let challenges: ChallengeDTO

                struct ChallengeDTO: Decodable {
                    let id: Int64
                    let title: String
                    let description: String?
                    let goal: Int
                    let reward: String?
                    let category: String?
                    let endDate: Date?

                    enum CodingKeys: String, CodingKey {
                        case id, title, description, goal, reward, category
                        case endDate = "end_date"
                    }
                }
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let participants = try decoder.decode([ChallengeParticipantDTO].self, from: response.data)

            if let participant = participants.first {
                let challenge = participant.challenges
                let daysRemaining = if let endDate = challenge.endDate {
                    max(0, Calendar.current.dateComponents([.day], from: Date(), to: endDate).day ?? 0)
                } else {
                    7 // Default
                }

                let activeChallenge = ActiveChallengeDTO(
                    id: challenge.id,
                    title: challenge.title,
                    description: challenge.description ?? "",
                    progress: participant.progress,
                    goal: challenge.goal,
                    daysRemaining: daysRemaining,
                    reward: challenge.reward ?? "Badge",
                    category: challenge.category ?? "general",
                )

                let fileURL = containerURL.appendingPathComponent("active_challenge.json")
                let data = try JSONEncoder().encode(activeChallenge)
                try data.write(to: fileURL)

                logger.debug("🏆 [Widget] Saved active challenge")
            } else {
                // No active challenge - remove the file
                let fileURL = containerURL.appendingPathComponent("active_challenge.json")
                try? FileManager.default.removeItem(at: fileURL)

                logger.debug("🏆 [Widget] No active challenge")
            }
        } catch {
            logger.error("❌ [Widget] Failed to update active challenge: \(error.localizedDescription)")
        }
    }

    // MARK: - Clear Widget Data

    func clearAllWidgetData() {
        guard let containerURL else { return }

        let files = ["nearby_food.json", "user_stats.json", "active_challenge.json"]

        for file in files {
            let fileURL = containerURL.appendingPathComponent(file)
            try? FileManager.default.removeItem(at: fileURL)
        }

        WidgetCenter.shared.reloadAllTimelines()
        logger.info("🧹 [Widget] Cleared all widget data")
    }
}

// MARK: - DTOs for Widget Data

struct NearbyFoodItemDTO: Codable {
    let id: Int64
    let name: String
    let category: String
    let distance: Double
    let imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name = "post_name"
        case category = "post_type"
        case distance = "distance_miles"
        case imageURL = "image_url"
    }

    init(id: Int64, name: String, category: String, distance: Double, imageURL: String?) {
        self.id = id
        self.name = name
        self.category = category
        self.distance = distance
        self.imageURL = imageURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int64.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decodeIfPresent(String.self, forKey: .category) ?? "other"
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 0
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
    }
}

struct UserStatsDTO: Codable {
    let totalShared: Int
    let totalReceived: Int
    let impactScore: Int
    let streak: Int
    let rank: Int?
}

struct ActiveChallengeDTO: Codable {
    let id: Int64
    let title: String
    let description: String
    let progress: Int
    let goal: Int
    let daysRemaining: Int
    let reward: String
    let category: String
}
