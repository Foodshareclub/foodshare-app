//
//  MockNotificationRepository.swift
//  Foodshare
//
//  Mock implementation of NotificationRepository for testing
//

import Foundation

#if DEBUG
    /// Mock implementation of NotificationRepository for unit tests
    final class MockNotificationRepository: NotificationRepository, @unchecked Sendable {
        // MARK: - Test Configuration

        var shouldFail = false
        var delay: TimeInterval = 0

        // MARK: - Mock Data

        var mockNotifications: [UserNotification] = UserNotification.sampleNotifications
        var mockUnreadCount = 3

        // MARK: - Call Tracking

        private(set) var fetchNotificationsCallCount = 0
        private(set) var fetchUnreadCountCallCount = 0
        private(set) var markAsReadCallCount = 0
        private(set) var markAllAsReadCallCount = 0
        private(set) var deleteNotificationCallCount = 0
        private(set) var subscribeCallCount = 0

        // MARK: - Callback Storage

        var onNotificationReceived: (@Sendable (UserNotification) -> Void)?

        // MARK: - NotificationRepository Implementation

        func fetchNotifications(for userId: UUID, limit: Int, offset: Int) async throws -> [UserNotification] {
            fetchNotificationsCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Filter and paginate - enforce user ID filtering for realistic mock behavior
            let filtered = mockNotifications.filter { $0.recipientId == userId }
            let endIndex = min(offset + limit, filtered.count)
            guard offset < filtered.count else { return [] }
            return Array(filtered[offset ..< endIndex])
        }

        func fetchUnreadCount(for userId: UUID) async throws -> Int {
            fetchUnreadCountCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            return mockUnreadCount
        }

        func fetchPaginatedNotifications(
            for userId: UUID,
            limit: Int,
            offset: Int,
        ) async throws -> PaginatedNotificationsResult {
            fetchNotificationsCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Filter and paginate
            let filtered = mockNotifications.filter { $0.recipientId == userId }
            let endIndex = min(offset + limit, filtered.count)
            let notifications = offset < filtered.count ? Array(filtered[offset ..< endIndex]) : []

            return PaginatedNotificationsResult(
                notifications: notifications,
                unreadCount: mockUnreadCount,
                totalCount: filtered.count,
                hasMore: endIndex < filtered.count,
            )
        }

        func markAsRead(notificationId: UUID) async throws {
            markAsReadCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Find and update the notification
            if let index = mockNotifications.firstIndex(where: { $0.id == notificationId }) {
                let old = mockNotifications[index]
                mockNotifications[index] = UserNotification(
                    id: old.id,
                    recipientId: old.recipientId,
                    actorId: old.actorId,
                    type: old.type,
                    title: old.title,
                    body: old.body,
                    postId: old.postId,
                    roomId: old.roomId,
                    reviewId: old.reviewId,
                    data: old.data,
                    isRead: true,
                    readAt: Date(),
                    createdAt: old.createdAt,
                    updatedAt: Date(),
                    actorProfile: old.actorProfile,
                )
                mockUnreadCount = max(0, mockUnreadCount - 1)
            } else {
                throw AppError.notFound(resource: "Notification")
            }
        }

        func markAllAsRead(for userId: UUID) async throws {
            markAllAsReadCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Mark all as read
            mockNotifications = mockNotifications.map { notification in
                UserNotification(
                    id: notification.id,
                    recipientId: notification.recipientId,
                    actorId: notification.actorId,
                    type: notification.type,
                    title: notification.title,
                    body: notification.body,
                    postId: notification.postId,
                    roomId: notification.roomId,
                    reviewId: notification.reviewId,
                    data: notification.data,
                    isRead: true,
                    readAt: Date(),
                    createdAt: notification.createdAt,
                    updatedAt: Date(),
                    actorProfile: notification.actorProfile,
                )
            }
            mockUnreadCount = 0
        }

        func deleteNotification(notificationId: UUID) async throws {
            deleteNotificationCallCount += 1

            if delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            guard let index = mockNotifications.firstIndex(where: { $0.id == notificationId }) else {
                throw AppError.notFound(resource: "Notification")
            }

            let notification = mockNotifications[index]
            if !notification.isRead {
                mockUnreadCount = max(0, mockUnreadCount - 1)
            }
            mockNotifications.remove(at: index)
        }

        func subscribeToNotifications(
            for userId: UUID,
            onNotification: @escaping @Sendable (UserNotification) -> Void,
        ) async {
            subscribeCallCount += 1
            onNotificationReceived = onNotification
        }

        // MARK: - Test Helpers

        func reset() {
            shouldFail = false
            delay = 0
            mockNotifications = UserNotification.sampleNotifications
            mockUnreadCount = 3
            fetchNotificationsCallCount = 0
            fetchUnreadCountCallCount = 0
            markAsReadCallCount = 0
            markAllAsReadCallCount = 0
            deleteNotificationCallCount = 0
            subscribeCallCount = 0
            onNotificationReceived = nil
        }

        /// Simulate receiving a new notification (for testing real-time updates)
        func simulateNewNotification(_ notification: UserNotification) {
            mockNotifications.insert(notification, at: 0)
            if !notification.isRead {
                mockUnreadCount += 1
            }
            onNotificationReceived?(notification)
        }

        /// Add a notification without triggering subscription
        func addNotification(_ notification: UserNotification) {
            mockNotifications.insert(notification, at: 0)
            if !notification.isRead {
                mockUnreadCount += 1
            }
        }
    }
#endif
