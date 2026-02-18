//
//  SupabaseNotificationRepository.swift
//  Foodshare
//
//  Supabase implementation of NotificationRepository
//  Uses RealtimeChannelManager for proper channel lifecycle management
//



#if !SKIP
import Foundation
import OSLog
import Supabase

@MainActor
final class SupabaseNotificationRepository: BaseSupabaseRepository, NotificationRepository {
    private let channelManager: RealtimeChannelManager

    /// Current user ID for subscription tracking
    private var currentSubscriptionUserId: UUID?

    init(
        supabase: Supabase.SupabaseClient,
        channelManager: RealtimeChannelManager = .shared,
    ) {
        self.channelManager = channelManager
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "NotificationRepository")
    }

    // MARK: - Fetch Notifications

    func fetchNotifications(for userId: UUID, limit: Int, offset: Int) async throws -> [UserNotification] {
        let response: [UserNotification] = try await supabase
            .from("user_notifications")
            .select(
                """
                id,
                recipient_id,
                actor_id,
                type,
                title,
                body,
                post_id,
                room_id,
                review_id,
                data,
                is_read,
                read_at,
                created_at,
                updated_at,
                actor_profile:profiles!actor_id(id, nickname, avatar_url)
                """,
            )
            .eq("recipient_id", value: userId.uuidString)
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        // Client-side blocking filter (defense-in-depth, backend also filters)
        var filteredResponse: [UserNotification] = []
        for notification in response {
            guard let actorId = notification.actorId else {
                filteredResponse.append(notification)
                continue
            }
            // Quick check - if actor is blocked, exclude notification
            let isBlocked = await (try? isUserBlocked(userId: userId, actorId: actorId)) ?? false
            if !isBlocked {
                filteredResponse.append(notification)
            }
        }
        return filteredResponse
    }

    // MARK: - Blocking Helper

    /// Check if user has blocked actor (client-side defense-in-depth)
    private func isUserBlocked(userId: UUID, actorId: UUID) async throws -> Bool {
        let result: [BlockedUserCheck] = try await supabase
            .from("blocked_users")
            .select("id")
            .or("user_id.eq.\(userId.uuidString),user_id.eq.\(actorId.uuidString)")
            .or("blocked_user_id.eq.\(userId.uuidString),blocked_user_id.eq.\(actorId.uuidString)")
            .limit(1)
            .execute()
            .value

        return !result.isEmpty
    }

    // MARK: - Unread Count

    func fetchUnreadCount(for userId: UUID) async throws -> Int {
        let response = try await supabase
            .from("user_notifications")
            .select("id", head: true, count: CountOption.exact)
            .eq("recipient_id", value: userId.uuidString)
            .eq("is_read", value: false)
            .execute()

        return response.count ?? 0
    }

    // MARK: - Paginated Notifications (Server-Side Combined)

    func fetchPaginatedNotifications(
        for userId: UUID,
        limit: Int,
        offset: Int,
    ) async throws -> PaginatedNotificationsResult {
        logger.debug("📡 Fetching paginated notifications via RPC: limit=\(limit), offset=\(offset)")

        let params = PaginatedNotificationsParams(
            pUserId: userId,
            pLimit: limit,
            pOffset: offset,
        )

        do {
            let dto: PaginatedNotificationsDTO = try await executeRPC("get_paginated_notifications", params: params)

            logger.debug("✅ Fetched \(dto.notifications.count) notifications, unread=\(dto.unreadCount)")

            return PaginatedNotificationsResult(
                notifications: dto.notifications,
                unreadCount: dto.unreadCount,
                totalCount: dto.totalCount,
                hasMore: dto.hasMore,
            )
        } catch {
            logger
                .warning(
                    "⚠️ get_paginated_notifications RPC failed, falling back to direct query: \(error.localizedDescription)",
                )
            return try await fetchPaginatedNotificationsDirect(for: userId, limit: limit, offset: offset)
        }
    }

    /// Direct query fallback for paginated notifications when RPC is unavailable
    private func fetchPaginatedNotificationsDirect(
        for userId: UUID,
        limit: Int,
        offset: Int,
    ) async throws -> PaginatedNotificationsResult {
        let notifications = try await fetchNotifications(for: userId, limit: limit, offset: offset)
        let unreadCount = try await fetchUnreadCount(for: userId)

        let totalResponse = try await supabase
            .from("user_notifications")
            .select("id", head: true, count: CountOption.exact)
            .eq("recipient_id", value: userId.uuidString)
            .execute()

        let totalCount = totalResponse.count ?? notifications.count

        logger.info("✅ Notifications fallback returned \(notifications.count) notifications, unread=\(unreadCount)")

        return PaginatedNotificationsResult(
            notifications: notifications,
            unreadCount: unreadCount,
            totalCount: totalCount,
            hasMore: offset + limit < totalCount,
        )
    }

    // MARK: - Mark as Read

    func markAsRead(notificationId: UUID) async throws {
        try await supabase
            .from("user_notifications")
            .update([
                "is_read": AnyJSON.bool(true),
                "read_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date())),
            ])
            .eq("id", value: notificationId.uuidString)
            .execute()
    }

    func markAllAsRead(for userId: UUID) async throws {
        try await supabase
            .from("user_notifications")
            .update([
                "is_read": AnyJSON.bool(true),
                "read_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date())),
            ])
            .eq("recipient_id", value: userId.uuidString)
            .eq("is_read", value: false)
            .execute()
    }

    // MARK: - Delete Notification

    func deleteNotification(notificationId: UUID) async throws {
        try await supabase
            .from("user_notifications")
            .delete()
            .eq("id", value: notificationId.uuidString)
            .execute()
    }

    // MARK: - Real-time Subscription

    func subscribeToNotifications(
        for userId: UUID,
        onNotification: @escaping @Sendable (UserNotification) -> Void,
    ) async {
        let table = "user_notifications"
        let filter = "recipient_id=eq.\(userId.uuidString)"
        let channelName = "notifications:\(userId.uuidString)"

        // Check if already subscribed to same user's notifications
        if let existingChannel = await channelManager.existingChannel(table: table, filter: filter) {
            logger.debug("Already subscribed to notifications for user: \(userId.uuidString)")
            return
        }

        // Clean up any previous subscription for different user
        if let previousUserId = currentSubscriptionUserId, previousUserId != userId {
            await unsubscribeFromNotifications(for: previousUserId)
        }

        let channel = supabase.realtimeV2.channel(channelName)

        let insertions = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: table,
            filter: filter,
        )

        do {
            try await channel.subscribeWithError()
        } catch {
            logger.error("Failed to subscribe to notifications channel: \(error.localizedDescription)")
        }

        // Register with centralized manager
        await channelManager.register(channel: channel, table: table, filter: filter)
        currentSubscriptionUserId = userId

        logger.info("Subscribed to notifications for user: \(userId.uuidString)")

        Task { [weak self] in
            for await insertion in insertions {
                do {
                    let notification = try insertion.decodeRecord(as: UserNotification.self, decoder: JSONDecoder.isoDecoder)
                    onNotification(notification)
                } catch {
                    self?.logger.error("Failed to decode notification: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Unsubscribe from notifications for a specific user
    func unsubscribeFromNotifications(for userId: UUID) async {
        let filter = "recipient_id=eq.\(userId.uuidString)"
        await channelManager.unregister(table: "user_notifications", filter: filter)

        if currentSubscriptionUserId == userId {
            currentSubscriptionUserId = nil
        }

        logger.info("Unsubscribed from notifications for user: \(userId.uuidString)")
    }

    /// Cleanup all notification subscriptions
    func cleanup() async {
        if let userId = currentSubscriptionUserId {
            await unsubscribeFromNotifications(for: userId)
        }
    }
}

// MARK: - DTOs

/// Blocking check DTO
private struct BlockedUserCheck: Decodable {
    let id: UUID
}

/// Parameters for the get_paginated_notifications RPC call
private struct PaginatedNotificationsParams: Encodable, Sendable {
    let pUserId: UUID
    let pLimit: Int
    let pOffset: Int

    enum CodingKeys: String, CodingKey {
        case pUserId = "p_user_id"
        case pLimit = "p_limit"
        case pOffset = "p_offset"
    }
}

/// DTO for decoding the get_paginated_notifications RPC response
private struct PaginatedNotificationsDTO: Decodable {
    let notifications: [UserNotification]
    let unreadCount: Int
    let totalCount: Int
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case notifications
        case unreadCount = "unread_count"
        case totalCount = "total_count"
        case hasMore = "has_more"
    }
}

// MARK: - JSON Decoder Extension

extension JSONDecoder {
    fileprivate static var isoDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}


#endif
