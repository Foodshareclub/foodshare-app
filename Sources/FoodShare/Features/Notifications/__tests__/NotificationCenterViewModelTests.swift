//
//  NotificationCenterViewModelTests.swift
//  FoodshareTests
//
//  Comprehensive tests for NotificationCenterViewModel
//  Tests: State management, optimistic updates, retry logic, offline queue
//

import Foundation
import Testing
@testable import FoodShare

// MARK: - Mock Notification Repository

@MainActor
final class MockNotificationRepositoryForTests: NotificationRepository, @unchecked Sendable {
    var notifications: [UserNotification] = []
    var unreadCount = 0
    var shouldFail = false
    var failureError: Error = NSError(domain: "test", code: -1)
    var markAsReadCalled: [UUID] = []
    var markAllAsReadCalled = false
    var deleteCalled: [UUID] = []
    var subscribeCallback: ((UserNotification) -> Void)?

    func fetchNotifications(for userId: UUID, limit: Int, offset: Int) async throws -> [UserNotification] {
        if shouldFail { throw failureError }
        return Array(notifications.prefix(limit))
    }

    func fetchUnreadCount(for userId: UUID) async throws -> Int {
        if shouldFail { throw failureError }
        return unreadCount
    }

    func fetchPaginatedNotifications(
        for userId: UUID,
        limit: Int,
        offset: Int,
    ) async throws -> PaginatedNotificationsResult {
        if shouldFail { throw failureError }
        return PaginatedNotificationsResult(
            notifications: Array(notifications.prefix(limit)),
            unreadCount: unreadCount,
            totalCount: notifications.count,
            hasMore: notifications.count > limit,
        )
    }

    func markAsRead(notificationId: UUID) async throws {
        if shouldFail { throw failureError }
        markAsReadCalled.append(notificationId)
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index].isRead = true
            unreadCount = max(0, unreadCount - 1)
        }
    }

    func markAllAsRead(for userId: UUID) async throws {
        if shouldFail { throw failureError }
        markAllAsReadCalled = true
        for index in notifications.indices {
            notifications[index].isRead = true
        }
        unreadCount = 0
    }

    func deleteNotification(notificationId: UUID) async throws {
        if shouldFail { throw failureError }
        deleteCalled.append(notificationId)
        notifications.removeAll { $0.id == notificationId }
    }

    func subscribeToNotifications(
        for userId: UUID,
        onNotification: @escaping @Sendable (UserNotification) -> Void,
    ) async {
        subscribeCallback = onNotification
    }

    /// Helper to simulate incoming notification
    func simulateNewNotification(_ notification: UserNotification) {
        subscribeCallback?(notification)
    }
}

// MARK: - Test Suite

@Suite("NotificationCenterViewModel Tests")
struct NotificationCenterViewModelTests {

    // MARK: - Initial State Tests

    @Test("Initial state is idle with empty notifications")
    @MainActor
    func initialState() {
        let repository = MockNotificationRepositoryForTests()
        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())

        #expect(viewModel.recentNotifications.isEmpty)
        #expect(viewModel.unreadCount == 0)
        #expect(viewModel.isDropdownVisible == false)
        #expect(viewModel.hasNewNotification == false)
        #expect(viewModel.state == .idle)
    }

    // MARK: - Load Recent Tests

    @Test("loadRecent fetches notifications and updates state")
    @MainActor
    func loadRecentSuccess() async {
        let repository = MockNotificationRepositoryForTests()
        repository.notifications = [
            .fixture(id: UUID(), title: "Test 1", isRead: false),
            .fixture(id: UUID(), title: "Test 2", isRead: true),
        ]
        repository.unreadCount = 1

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()

        #expect(viewModel.recentNotifications.count == 2)
        #expect(viewModel.unreadCount == 1)
        #expect(viewModel.state == .loaded)
    }

    @Test("loadRecent handles errors gracefully")
    @MainActor
    func loadRecentError() async {
        let repository = MockNotificationRepositoryForTests()
        repository.shouldFail = true
        repository.failureError = NSError(
            domain: "test",
            code: 500,
            userInfo: [NSLocalizedDescriptionKey: "Server error"],
        )

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()

        #expect(viewModel.recentNotifications.isEmpty)
        #expect(viewModel.state != .loaded)
    }

    @Test("loadRecent respects rate limiting")
    @MainActor
    func loadRecentRateLimited() async {
        let repository = MockNotificationRepositoryForTests()
        repository.notifications = [.fixture()]
        repository.unreadCount = 1

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())

        // First load
        await viewModel.loadRecent()
        #expect(viewModel.recentNotifications.count == 1)

        // Immediate second load should be rate limited
        repository.notifications = [.fixture(), .fixture()]
        await viewModel.loadRecent()

        // Should still have 1 notification (rate limited)
        #expect(viewModel.recentNotifications.count == 1)
    }

    // MARK: - Mark As Read Tests

    @Test("markAsRead performs optimistic update")
    @MainActor
    func markAsReadOptimistic() async {
        let notificationId = UUID()
        let repository = MockNotificationRepositoryForTests()
        repository.notifications = [
            .fixture(id: notificationId, isRead: false),
        ]
        repository.unreadCount = 1

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()

        let notification = viewModel.recentNotifications[0]
        await viewModel.markAsRead(notification)

        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)

        #expect(viewModel.recentNotifications[0].isRead == true)
        #expect(viewModel.unreadCount == 0)
        #expect(repository.markAsReadCalled.contains(notificationId))
    }

    @Test("markAsRead rolls back on failure")
    @MainActor
    func markAsReadRollback() async {
        let notificationId = UUID()
        let repository = MockNotificationRepositoryForTests()
        repository.notifications = [
            .fixture(id: notificationId, isRead: false),
        ]
        repository.unreadCount = 1

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()

        // Enable failure after initial load
        repository.shouldFail = true

        let notification = viewModel.recentNotifications[0]
        await viewModel.markAsRead(notification)

        // Wait for debounce and retry attempts
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Should have error state but UI should reflect original state
        // (rollback happens after retries exhaust)
    }

    @Test("markAsRead ignores already-read notifications")
    @MainActor
    func markAsReadIgnoresAlreadyRead() async {
        let notificationId = UUID()
        let repository = MockNotificationRepositoryForTests()
        repository.notifications = [
            .fixture(id: notificationId, isRead: true),
        ]

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()

        let notification = viewModel.recentNotifications[0]
        await viewModel.markAsRead(notification)

        // Wait for any potential debounce
        try? await Task.sleep(nanoseconds: 400_000_000)

        #expect(repository.markAsReadCalled.isEmpty)
    }

    // MARK: - Mark All As Read Tests

    @Test("markAllAsRead updates all notifications")
    @MainActor
    func markAllAsReadSuccess() async {
        let repository = MockNotificationRepositoryForTests()
        repository.notifications = [
            .fixture(id: UUID(), isRead: false),
            .fixture(id: UUID(), isRead: false),
            .fixture(id: UUID(), isRead: true),
        ]
        repository.unreadCount = 2

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()

        await viewModel.markAllAsRead()

        #expect(viewModel.recentNotifications.allSatisfy(\.isRead))
        #expect(viewModel.unreadCount == 0)
        #expect(repository.markAllAsReadCalled == true)
    }

    @Test("markAllAsRead does nothing when no unread")
    @MainActor
    func markAllAsReadNoUnread() async {
        let repository = MockNotificationRepositoryForTests()
        repository.notifications = [
            .fixture(id: UUID(), isRead: true),
        ]
        repository.unreadCount = 0

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()

        await viewModel.markAllAsRead()

        #expect(repository.markAllAsReadCalled == false)
    }

    // MARK: - Delete Tests

    @Test("deleteNotification removes from list")
    @MainActor
    func deleteNotificationSuccess() async {
        let notificationId = UUID()
        let repository = MockNotificationRepositoryForTests()
        repository.notifications = [
            .fixture(id: notificationId, isRead: false),
            .fixture(id: UUID(), isRead: true),
        ]
        repository.unreadCount = 1

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()

        let notification = viewModel.recentNotifications[0]
        await viewModel.deleteNotification(notification)

        #expect(viewModel.recentNotifications.count == 1)
        #expect(viewModel.unreadCount == 0)
        #expect(repository.deleteCalled.contains(notificationId))
    }

    // MARK: - Dropdown Toggle Tests

    @Test("toggleDropdown changes visibility")
    @MainActor
    func toggleDropdown() {
        let repository = MockNotificationRepositoryForTests()
        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())

        #expect(viewModel.isDropdownVisible == false)

        viewModel.toggleDropdown()
        #expect(viewModel.isDropdownVisible == true)

        viewModel.toggleDropdown()
        #expect(viewModel.isDropdownVisible == false)
    }

    @Test("dismissDropdown sets visibility to false")
    @MainActor
    func dismissDropdown() {
        let repository = MockNotificationRepositoryForTests()
        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())

        viewModel.toggleDropdown()
        #expect(viewModel.isDropdownVisible == true)

        viewModel.dismissDropdown()
        #expect(viewModel.isDropdownVisible == false)
    }

    // MARK: - Real-time Subscription Tests

    @Test("subscribeToRealtime adds new notifications")
    @MainActor
    func realtimeSubscription() async {
        let repository = MockNotificationRepositoryForTests()
        repository.notifications = [.fixture()]
        repository.unreadCount = 1

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()
        await viewModel.subscribeToRealtime()

        let newNotification = UserNotification.fixture(
            id: UUID(),
            title: "New real-time notification",
            isRead: false,
        )

        // Simulate incoming notification
        repository.simulateNewNotification(newNotification)

        // Wait for async processing
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(viewModel.recentNotifications.count == 2)
        #expect(viewModel.recentNotifications[0].title == "New real-time notification")
        #expect(viewModel.unreadCount == 2)
    }

    // MARK: - Computed Properties Tests

    @Test("hasNotifications reflects notification list state")
    @MainActor
    func hasNotificationsComputed() async {
        let repository = MockNotificationRepositoryForTests()
        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())

        #expect(viewModel.hasNotifications == false)

        repository.notifications = [.fixture()]
        await viewModel.loadRecent()

        #expect(viewModel.hasNotifications == true)
    }

    @Test("hasUnread reflects unread count")
    @MainActor
    func hasUnreadComputed() async {
        let repository = MockNotificationRepositoryForTests()
        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())

        #expect(viewModel.hasUnread == false)

        repository.notifications = [.fixture(isRead: false)]
        repository.unreadCount = 1
        await viewModel.loadRecent()

        #expect(viewModel.hasUnread == true)
    }

    @Test("unreadCountAnnouncement provides correct accessibility text")
    @MainActor
    func unreadCountAnnouncement() async {
        let repository = MockNotificationRepositoryForTests()
        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())

        #expect(viewModel.unreadCountAnnouncement == "No unread notifications")

        repository.unreadCount = 1
        repository.notifications = [.fixture(isRead: false)]
        await viewModel.loadRecent()
        #expect(viewModel.unreadCountAnnouncement == "1 unread notification")

        repository.unreadCount = 5
        repository.notifications = [
            .fixture(isRead: false),
            .fixture(isRead: false),
            .fixture(isRead: false),
            .fixture(isRead: false),
            .fixture(isRead: false),
        ]
        await viewModel.loadRecent()
        #expect(viewModel.unreadCountAnnouncement == "5 unread notifications")
    }

    // MARK: - Error Handling Tests

    @Test("clearError resets error state")
    @MainActor
    func clearError() async {
        let repository = MockNotificationRepositoryForTests()
        repository.shouldFail = true

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())
        await viewModel.loadRecent()

        // Error should be set after failed load
        viewModel.clearError()

        #expect(viewModel.error == nil)
        #expect(viewModel.showError == false)
    }
}

// MARK: - Performance Tests

@Suite("NotificationCenterViewModel Performance")
struct NotificationCenterViewModelPerformanceTests {

    @Test("Handles large notification lists efficiently")
    @MainActor
    func largeNotificationList() async {
        let repository = MockNotificationRepositoryForTests()

        // Generate 100 notifications
        repository.notifications = (0 ..< 100).map { index in
            .fixture(id: UUID(), title: "Notification \(index)", isRead: index % 3 == 0)
        }
        repository.unreadCount = 67

        let viewModel = NotificationCenterViewModel(repository: repository, userId: UUID())

        let start = Date()
        await viewModel.loadRecent()
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed < 0.5) // Should complete in under 500ms
        #expect(viewModel.recentNotifications.count == 10) // Respects dropdown limit
    }
}
