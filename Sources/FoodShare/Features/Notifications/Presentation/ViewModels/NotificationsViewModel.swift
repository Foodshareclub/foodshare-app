//
//  NotificationsViewModel.swift
//  Foodshare
//
//  ViewModel for notifications list with real-time updates
//



#if !SKIP
import Foundation
import Observation

@MainActor
@Observable
final class NotificationsViewModel {
    // MARK: - State

    var notifications: [UserNotification] = []
    var isLoading = false
    var error: AppError?
    var showError = false
    var currentPage = 0
    var hasMore = true
    private(set) var unreadCount = 0

    // MARK: - Dependencies

    private let repository: NotificationRepository
    private let userId: UUID

    // MARK: - Computed Properties

    var hasNotifications: Bool {
        !notifications.isEmpty
    }

    /// Unread notifications - uses unreadCount from server instead of client-side filtering
    var unreadNotifications: [UserNotification] {
        notifications.filter { !$0.isRead }
    }

    /// Total count of notifications (from server)
    private(set) var totalCount = 0

    // MARK: - Initialization

    init(repository: NotificationRepository, userId: UUID) {
        self.repository = repository
        self.userId = userId
    }

    // MARK: - Public API (called by views)

    func loadInitial() async {
        await fetchInitial()
    }

    func refresh() async {
        await fetchInitial()
    }

    func loadMore() async {
        await fetchPage()
    }

    func clearError() {
        error = nil
        showError = false
    }

    // MARK: - Fetch

    private func fetchInitial() async {
        currentPage = 0
        hasMore = true
        isLoading = true
        error = nil
        showError = false
        defer { isLoading = false }

        do {
            let result = try await repository.fetchPaginatedNotifications(
                for: userId,
                limit: AppConfiguration.shared.pageSize,
                offset: 0
            )

            notifications = result.notifications
            unreadCount = result.unreadCount
            totalCount = result.totalCount
            hasMore = result.hasMore
        } catch {
            handleError(error)
        }
    }

    private func fetchPage() async {
        guard hasMore, !isLoading else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let result = try await repository.fetchPaginatedNotifications(
                for: userId,
                limit: AppConfiguration.shared.pageSize,
                offset: currentPage * AppConfiguration.shared.pageSize
            )

            unreadCount = result.unreadCount
            totalCount = result.totalCount
            hasMore = result.hasMore
            notifications.append(contentsOf: result.notifications)
            currentPage += 1
        } catch {
            handleError(error)
        }
    }

    // MARK: - Mark as Read

    func markAsRead(_ notification: UserNotification) async {
        guard !notification.isRead else { return }

        // Optimistic update
        if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
            notifications[index].isRead = true
            unreadCount = max(0, unreadCount - 1)
        }

        do {
            try await repository.markAsRead(notificationId: notification.id)
        } catch {
            handleError(error)
        }
    }

    func markAllAsRead() async {
        let previousUnreadCount = unreadCount
        let previousNotifications = notifications

        // Optimistic update
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        unreadCount = 0

        do {
            try await repository.markAllAsRead(for: userId)
            HapticManager.success()
        } catch {
            // Revert on failure
            notifications = previousNotifications
            unreadCount = previousUnreadCount
            handleError(error)
        }
    }

    // MARK: - Delete Notification

    func deleteNotification(_ notification: UserNotification) async {
        let previousNotifications = notifications
        let wasUnread = !notification.isRead

        // Optimistic removal
        notifications.removeAll { $0.id == notification.id }
        if wasUnread {
            unreadCount = max(0, unreadCount - 1)
        }

        do {
            try await repository.deleteNotification(notificationId: notification.id)
            HapticManager.light()
        } catch {
            // Revert on failure
            notifications = previousNotifications
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
                notifications.insert(notification, at: 0)
                if !notification.isRead {
                    unreadCount += 1
                }

                HapticManager.light()
            }
        }
    }

    // MARK: - Refresh Unread Count

    func refreshUnreadCount() async {
        do {
            unreadCount = try await repository.fetchUnreadCount(for: userId)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            self.error = appError
        } else {
            self.error = AppError.databaseError(error.localizedDescription)
        }
        showError = true
    }
}


#endif
