//
//  PostActivityService.swift
//  Foodshare
//
//  Fetches and manages post activity timeline.
//  Actor-based, thread-safe implementation.
//
//  TODO: Migrate to Edge Function when api-v1-activity endpoint is created.
//  Currently reads directly from post_activity_logs table since no backend
//  endpoint exists for activity log reads.
//

import Foundation
import OSLog
import Supabase

// MARK: - Post Activity Type

/// Types of activities that can occur on a post
enum PostActivityType: String, Codable, Sendable, CaseIterable {
    case created
    case updated
    case deleted
    case restored
    case activated
    case deactivated
    case expired
    case viewed
    case contacted
    case arranged
    case arrangementCancelled = "arrangement_cancelled"
    case collected
    case notCollected = "not_collected"
    case reported
    case flagged
    case unflagged
    case approved
    case rejected
    case hidden
    case unhidden
    case liked
    case unliked
    case shared
    case bookmarked
    case unbookmarked
    case adminEdited = "admin_edited"
    case adminNoteAdded = "admin_note_added"
    case adminStatusChanged = "admin_status_changed"
    case autoExpired = "auto_expired"
    case autoDeactivated = "auto_deactivated"
    case locationUpdated = "location_updated"
    case imagesUpdated = "images_updated"

    /// Human-readable label
    var label: String {
        switch self {
        case .created: "Created"
        case .updated: "Updated"
        case .deleted: "Deleted"
        case .restored: "Restored"
        case .activated: "Activated"
        case .deactivated: "Deactivated"
        case .expired: "Expired"
        case .viewed: "Viewed"
        case .contacted: "Contacted"
        case .arranged: "Arranged"
        case .arrangementCancelled: "Arrangement Cancelled"
        case .collected: "Collected"
        case .notCollected: "Not Collected"
        case .reported: "Reported"
        case .flagged: "Flagged"
        case .unflagged: "Unflagged"
        case .approved: "Approved"
        case .rejected: "Rejected"
        case .hidden: "Hidden"
        case .unhidden: "Unhidden"
        case .liked: "Liked"
        case .unliked: "Unliked"
        case .shared: "Shared"
        case .bookmarked: "Bookmarked"
        case .unbookmarked: "Unbookmarked"
        case .adminEdited: "Admin Edited"
        case .adminNoteAdded: "Admin Note Added"
        case .adminStatusChanged: "Admin Status Changed"
        case .autoExpired: "Auto Expired"
        case .autoDeactivated: "Auto Deactivated"
        case .locationUpdated: "Location Updated"
        case .imagesUpdated: "Images Updated"
        }
    }

    @MainActor
    func localizedLabel(using t: EnhancedTranslationService) -> String {
        switch self {
        case .created: t.t("activity.type.created")
        case .updated: t.t("activity.type.updated")
        case .deleted: t.t("activity.type.deleted")
        case .restored: t.t("activity.type.restored")
        case .activated: t.t("activity.type.activated")
        case .deactivated: t.t("activity.type.deactivated")
        case .expired: t.t("activity.type.expired")
        case .viewed: t.t("activity.type.viewed")
        case .contacted: t.t("activity.type.contacted")
        case .arranged: t.t("activity.type.arranged")
        case .arrangementCancelled: t.t("activity.type.arrangement_cancelled")
        case .collected: t.t("activity.type.collected")
        case .notCollected: t.t("activity.type.not_collected")
        case .reported: t.t("activity.type.reported")
        case .flagged: t.t("activity.type.flagged")
        case .unflagged: t.t("activity.type.unflagged")
        case .approved: t.t("activity.type.approved")
        case .rejected: t.t("activity.type.rejected")
        case .hidden: t.t("activity.type.hidden")
        case .unhidden: t.t("activity.type.unhidden")
        case .liked: t.t("activity.type.liked")
        case .unliked: t.t("activity.type.unliked")
        case .shared: t.t("activity.type.shared")
        case .bookmarked: t.t("activity.type.bookmarked")
        case .unbookmarked: t.t("activity.type.unbookmarked")
        case .adminEdited: t.t("activity.type.admin_edited")
        case .adminNoteAdded: t.t("activity.type.admin_note_added")
        case .adminStatusChanged: t.t("activity.type.admin_status_changed")
        case .autoExpired: t.t("activity.type.auto_expired")
        case .autoDeactivated: t.t("activity.type.auto_deactivated")
        case .locationUpdated: t.t("activity.type.location_updated")
        case .imagesUpdated: t.t("activity.type.images_updated")
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .created: "plus.circle.fill"
        case .updated: "pencil.circle.fill"
        case .deleted: "trash.circle.fill"
        case .restored: "arrow.uturn.backward.circle.fill"
        case .activated: "checkmark.circle.fill"
        case .deactivated: "xmark.circle.fill"
        case .expired: "clock.fill"
        case .viewed: "eye.fill"
        case .contacted: "message.fill"
        case .arranged: "checkmark.seal.fill"
        case .arrangementCancelled: "xmark.seal.fill"
        case .collected: "shippingbox.fill"
        case .notCollected: "exclamationmark.triangle.fill"
        case .reported: "flag.fill"
        case .flagged: "exclamationmark.triangle.fill"
        case .unflagged: "checkmark.shield.fill"
        case .approved: "hand.thumbsup.fill"
        case .rejected: "hand.thumbsdown.fill"
        case .hidden: "eye.slash.fill"
        case .unhidden: "eye.fill"
        case .liked: "heart.fill"
        case .unliked: "heart"
        case .shared: "square.and.arrow.up.fill"
        case .bookmarked: "bookmark.fill"
        case .unbookmarked: "bookmark"
        case .adminEdited: "pencil.and.outline"
        case .adminNoteAdded: "doc.text.fill"
        case .adminStatusChanged: "gearshape.fill"
        case .autoExpired: "clock.badge.exclamationmark.fill"
        case .autoDeactivated: "power"
        case .locationUpdated: "mappin.circle.fill"
        case .imagesUpdated: "photo.fill"
        }
    }

    /// Color for the activity type
    var colorHex: String {
        switch self {
        case .created, .activated, .approved, .collected, .unflagged, .unhidden:
            "#22C55E" // Green
        case .deleted, .deactivated, .rejected, .notCollected, .arrangementCancelled:
            "#EF4444" // Red
        case .updated, .adminEdited, .locationUpdated, .imagesUpdated:
            "#3B82F6" // Blue
        case .expired, .autoExpired, .autoDeactivated:
            "#F59E0B" // Amber
        case .viewed:
            "#8B5CF6" // Purple
        case .contacted, .arranged:
            "#06B6D4" // Cyan
        case .reported, .flagged:
            "#F97316" // Orange
        case .liked, .unliked:
            "#EC4899" // Pink
        case .shared:
            "#14B8A6" // Teal
        case .bookmarked, .unbookmarked:
            "#6366F1" // Indigo
        case .hidden, .restored, .adminNoteAdded, .adminStatusChanged:
            "#6B7280" // Gray
        }
    }
}

// MARK: - Post Activity Item

/// A single activity item in the timeline
struct PostActivityItem: Codable, Identifiable, Sendable {
    let id: UUID
    let postId: Int?
    let actorId: UUID?
    let activityType: PostActivityType
    let previousState: [String: AnyCodable]?
    let newState: [String: AnyCodable]?
    let changes: [String: AnyCodable]?
    let metadata: [String: AnyCodable]?
    let reason: String?
    let notes: String?
    let createdAt: Date

    // Joined actor info
    let actorNickname: String?
    let actorAvatar: String?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case actorId = "actor_id"
        case activityType = "activity_type"
        case previousState = "previous_state"
        case newState = "new_state"
        case changes
        case metadata
        case reason
        case notes
        case createdAt = "created_at"
        case actorNickname = "actor_nickname"
        case actorAvatar = "actor_avatar"
    }
}

// MARK: - Post Activity Service

// TODO: Migrate to Edge Function when api-v1-activity endpoint is created.
// Activity log reads currently have no corresponding backend endpoint.

/// Actor-based service for fetching post activity timeline
actor PostActivityService {
    // MARK: - Singleton

    nonisolated static let shared: PostActivityService = {
        PostActivityService(supabase: MainActor.assumeIsolated { AuthenticationService.shared.supabase })
    }()

    // MARK: - Properties

    private let supabase: SupabaseClient
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "PostActivity")

    // MARK: - Initialization

    init(supabase: SupabaseClient) {
        self.supabase = supabase
        logger.info("[ACTIVITY] PostActivityService initialized")
    }

    // MARK: - Fetch Activities

    /// Get activity timeline for a post
    @MainActor
    func getActivities(for postId: Int, limit: Int = 50) async throws -> [PostActivityItem] {
        let activities: [PostActivityItem] = try await supabase
            .from("post_activity_logs")
            .select("""
                id,post_id,actor_id,activity_type,previous_state,new_state,
                changes,metadata,reason,notes,created_at,
                profiles:actor_id(nickname,avatar_url)
            """)
            .eq("post_id", value: postId)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return activities
    }

    /// Get recent activities for current user's posts
    @MainActor
    func getRecentActivitiesForMyPosts(limit: Int = 20) async throws -> [PostActivityItem] {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw PostActivityError.notAuthenticated
        }

        let posts: [[String: Int]] = try await supabase
            .from("posts")
            .select("id")
            .eq("profile_id", value: userId.uuidString)
            .execute()
            .value

        let postIds = posts.compactMap { $0["id"] }
        guard !postIds.isEmpty else { return [] }

        let activities: [PostActivityItem] = try await supabase
            .from("post_activity_logs")
            .select("""
                id,post_id,actor_id,activity_type,previous_state,new_state,
                changes,metadata,reason,notes,created_at
            """)
            .in("post_id", values: postIds)
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value

        return activities
    }

    /// Get activity stats for a post
    @MainActor
    func getActivityStats(for postId: Int) async throws -> PostActivityStats {
        let activities: [PostActivityItem] = try await supabase
            .from("post_activity_logs")
            .select("activity_type")
            .eq("post_id", value: postId)
            .execute()
            .value

        var viewCount = 0
        var likeCount = 0
        var shareCount = 0
        var contactCount = 0

        for activity in activities {
            switch activity.activityType {
            case .viewed: viewCount += 1
            case .liked: likeCount += 1
            case .unliked: likeCount -= 1
            case .shared: shareCount += 1
            case .contacted: contactCount += 1
            default: break
            }
        }

        return PostActivityStats(
            viewCount: max(0, viewCount),
            likeCount: max(0, likeCount),
            shareCount: shareCount,
            contactCount: contactCount,
            totalActivities: activities.count
        )
    }
}

// MARK: - Activity Stats

struct PostActivityStats: Sendable {
    let viewCount: Int
    let likeCount: Int
    let shareCount: Int
    let contactCount: Int
    let totalActivities: Int
}

// MARK: - Errors

enum PostActivityError: LocalizedError, Sendable {
    case notAuthenticated
    case notFound
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "Please sign in to view activity"
        case .notFound: "Activity not found"
        case let .networkError(message): "Network error: \(message)"
        }
    }
}
