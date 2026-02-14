//
//  NotificationRepository.swift
//  Foodshare
//
//  Protocol for notification data access
//

import Foundation

// MARK: - Paginated Notifications Result

struct PaginatedNotificationsResult: Sendable {
    let notifications: [UserNotification]
    let unreadCount: Int
    let totalCount: Int
    let hasMore: Bool

    static let empty = PaginatedNotificationsResult(
        notifications: [],
        unreadCount: 0,
        totalCount: 0,
        hasMore: false,
    )
}

// MARK: - Notification Repository Protocol

protocol NotificationRepository: Sendable {
    /// Fetch all notifications for a user
    func fetchNotifications(for userId: UUID, limit: Int, offset: Int) async throws -> [UserNotification]

    /// Fetch unread notifications count
    func fetchUnreadCount(for userId: UUID) async throws -> Int

    /// Fetch paginated notifications with unread count in a single call (server-side)
    func fetchPaginatedNotifications(
        for userId: UUID,
        limit: Int,
        offset: Int,
    ) async throws -> PaginatedNotificationsResult

    /// Mark a notification as read
    func markAsRead(notificationId: UUID) async throws

    /// Mark all notifications as read
    func markAllAsRead(for userId: UUID) async throws

    /// Delete a notification
    func deleteNotification(notificationId: UUID) async throws

    /// Subscribe to real-time notification updates
    func subscribeToNotifications(
        for userId: UUID,
        onNotification: @escaping @Sendable (UserNotification) -> Void,
    ) async
}
