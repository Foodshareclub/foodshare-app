//
//  NotificationsViewModel.swift
//  Foodshare
//
//  ViewModel for notifications list with real-time updates
//

import Foundation
import FoodShareArchitecture
import Observation

@MainActor
@Observable
final class NotificationsViewModel: PaginatedViewModel<UserNotification> {
    // MARK: - State

    private(set) var unreadCount = 0

    // MARK: - Dependencies

    private let repository: NotificationRepository
    private let userId: UUID

    // MARK: - Computed Properties

    var hasNotifications: Bool {
        !items.isEmpty
    }

    /// Unread notifications - uses unreadCount from server instead of client-side filtering
    var unreadNotifications: [UserNotification] {
        items.filter { !$0.isRead }
    }

    /// Total count of notifications (from server)
    private(set) var totalCount = 0

    // MARK: - Initialization

    init(repository: NotificationRepository, userId: UUID) {
        self.repository = repository
        self.userId = userId
        super.init()
    }

    // MARK: - Override Pagination

    override func fetchPage() async throws -> [UserNotification] {
        let result = try await repository.fetchPaginatedNotifications(
            for: userId,
            limit: AppConfiguration.shared.pageSize,
            offset: currentPage * AppConfiguration.shared.pageSize
        )

        unreadCount = result.unreadCount
        totalCount = result.totalCount
        hasMore = result.hasMore

        return result.notifications
    }

    // MARK: - Mark as Read

    func markAsRead(_ notification: UserNotification) async {
        guard !notification.isRead else { return }

        // Optimistic update
        if let index = items.firstIndex(where: { $0.id == notification.id }) {
            items[index].isRead = true
            unreadCount = max(0, unreadCount - 1)
        }

        await safely {
            try await repository.markAsRead(notificationId: notification.id)
        }
    }

    func markAllAsRead() async {
        let previousUnreadCount = unreadCount
        let previousNotifications = items

        // Optimistic update
        for index in items.indices {
            items[index].isRead = true
        }
        unreadCount = 0

        do {
            try await repository.markAllAsRead(for: userId)
            HapticManager.success()
        } catch {
            // Revert on failure
            items = previousNotifications
            unreadCount = previousUnreadCount
            handleError(error)
        }
    }

    // MARK: - Delete Notification

    func deleteNotification(_ notification: UserNotification) async {
        let previousNotifications = items
        let wasUnread = !notification.isRead

        // Optimistic removal
        items.removeAll { $0.id == notification.id }
        if wasUnread {
            unreadCount = max(0, unreadCount - 1)
        }

        do {
            try await repository.deleteNotification(notificationId: notification.id)
            HapticManager.light()
        } catch {
            // Revert on failure
            items = previousNotifications
            if wasUnread {
                unreadCount += 1
            }
            handleError(error)
        }
    }

    // MARK: - Real-time Subscription

    func subscribeToUpdates() async {
        await repository.subscribeToNotifications(for: userId) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Insert at the beginning
                items.insert(notification, at: 0)
                if !notification.isRead {
                    unreadCount += 1
                }

                HapticManager.light()
            }
        }
    }

    // MARK: - Refresh Unread Count

    func refreshUnreadCount() async {
        await safely {
            unreadCount = try await repository.fetchUnreadCount(for: userId)
        }
    }
}
