//
//  NotificationCenterViewModel.swift
//  Foodshare
//
//  Enterprise-grade ViewModel for the notification center dropdown
//  Features: Real-time sync, optimistic UI, retry logic, offline queue, analytics
//

import FoodShareArchitecture
import Foundation
import Observation
import OSLog
import SwiftUI

// MARK: - Notification Center State

/// Represents the current state of the notification center
enum NotificationCenterState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
    case offline
}

// MARK: - Pending Action

/// Actions queued for retry when offline
private enum PendingAction: Sendable {
    case markRead(UUID)
    case markAllRead
    case delete(UUID)
}

// MARK: - Notification Center ViewModel

/// Enterprise-grade ViewModel for the notification center dropdown
///
/// Features:
/// - Real-time updates via Supabase Realtime
/// - Optimistic UI with automatic rollback
/// - Exponential backoff retry for failed operations
/// - Offline action queue with sync on reconnect
/// - Debounced rapid actions
/// - Analytics integration
/// - Full accessibility support
@MainActor
@Observable
final class NotificationCenterViewModel {
    // MARK: - Published State

    /// Recent notifications for dropdown display
    private(set) var recentNotifications: [UserNotification] = []

    /// Total unread count
    private(set) var unreadCount = 0

    /// Whether the dropdown is visible
    var isDropdownVisible = false {
        didSet {
            if isDropdownVisible, oldValue != isDropdownVisible {
                trackAnalytics(.dropdownOpened)
            }
        }
    }

    /// Indicates a new notification just arrived (for bell shake)
    private(set) var hasNewNotification = false

    /// Current state
    private(set) var state: NotificationCenterState = .idle

    /// Error for alert presentation
    private(set) var error: AppError?
    var showError = false

    // MARK: - Configuration

    /// Maximum notifications to show in dropdown
    private let dropdownLimit = 10

    /// Debounce interval for rapid actions (ms)
    private let debounceInterval: UInt64 = 300_000_000 // 300ms

    /// Maximum retry attempts
    private let maxRetryAttempts = 3

    /// Base delay for exponential backoff (seconds)
    private let baseRetryDelay = 1.0

    // MARK: - Dependencies

    private let repository: NotificationRepository
    private let userId: UUID
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "NotificationCenterViewModel")

    // MARK: - Internal State

    /// Pending actions for offline queue
    private var pendingActions: [PendingAction] = []

    /// Debounce task for mark as read
    private var markAsReadDebounceTask: Task<Void, Never>?

    /// IDs currently being processed (prevents double-tap)
    private var processingIds: Set<UUID> = []

    /// Last refresh timestamp
    private var lastRefreshTime: Date?

    /// Minimum refresh interval (seconds)
    private let minRefreshInterval: TimeInterval = 5.0

    // MARK: - Computed Properties

    /// Whether there are any notifications
    var hasNotifications: Bool {
        !recentNotifications.isEmpty
    }

    /// Whether there are unread notifications
    var hasUnread: Bool {
        unreadCount > 0
    }

    /// Whether we can refresh (rate limiting)
    var canRefresh: Bool {
        guard let lastRefresh = lastRefreshTime else { return true }
        return Date().timeIntervalSince(lastRefresh) >= minRefreshInterval
    }

    /// Accessibility announcement for unread count
    var unreadCountAnnouncement: String {
        switch unreadCount {
        case 0: "No unread notifications"
        case 1: "1 unread notification"
        default: "\(unreadCount) unread notifications"
        }
    }

    // MARK: - Initialization

    init(repository: NotificationRepository, userId: UUID) {
        self.repository = repository
        self.userId = userId
    }

    deinit {
        // Task cleanup handled automatically by Swift's ARC
        // Note: MainActor isolation prevents direct access in deinit
    }

    // MARK: - Public Methods

    /// Load recent notifications for dropdown
    func loadRecent() async {
        guard state != .loading else { return }
        guard canRefresh else {
            logger.debug("Skipping refresh - rate limited")
            return
        }

        state = .loading

        do {
            let result = try await withRetry(maxAttempts: maxRetryAttempts) {
                try await self.repository.fetchPaginatedNotifications(
                    for: self.userId,
                    limit: self.dropdownLimit,
                    offset: 0,
                )
            }

            recentNotifications = result.notifications
            unreadCount = result.unreadCount
            lastRefreshTime = Date()
            state = .loaded

            logger.debug("Loaded \(result.notifications.count) notifications, \(result.unreadCount) unread")
            trackAnalytics(.notificationsLoaded(count: result.notifications.count))

        } catch {
            handleError(error)
            state = .error(error.localizedDescription)
        }
    }

    /// Refresh unread count only (lightweight)
    func refreshUnreadCount() async {
        do {
            unreadCount = try await repository.fetchUnreadCount(for: userId)
        } catch {
            logger.warning("Failed to refresh unread count: \(error.localizedDescription)")
        }
    }

    /// Mark a single notification as read with debouncing
    func markAsRead(_ notification: UserNotification) async {
        guard !notification.isRead else { return }
        guard !processingIds.contains(notification.id) else {
            logger.debug("Already processing notification: \(notification.id)")
            return
        }

        processingIds.insert(notification.id)
        defer { processingIds.remove(notification.id) }

        // Optimistic update
        let previousNotifications = recentNotifications
        let previousUnreadCount = unreadCount

        if let index = recentNotifications.firstIndex(where: { $0.id == notification.id }) {
            recentNotifications[index].isRead = true
        }
        unreadCount = max(0, unreadCount - 1)

        // Debounced network call
        markAsReadDebounceTask?.cancel()
        markAsReadDebounceTask = Task {
            try? await Task.sleep(nanoseconds: debounceInterval)
            guard !Task.isCancelled else { return }

            do {
                try await withRetry(maxAttempts: maxRetryAttempts) {
                    try await self.repository.markAsRead(notificationId: notification.id)
                }
                HapticManager.light()
                logger.debug("Marked notification as read: \(notification.id)")
                trackAnalytics(.notificationRead)

            } catch {
                // Rollback on failure
                await MainActor.run {
                    self.recentNotifications = previousNotifications
                    self.unreadCount = previousUnreadCount
                }

                // Queue for offline retry if network error
                if isNetworkError(error) {
                    queuePendingAction(.markRead(notification.id))
                } else {
                    handleError(error)
                }
            }
        }
    }

    /// Mark all notifications as read
    func markAllAsRead() async {
        guard unreadCount > 0 else { return }

        let previousNotifications = recentNotifications
        let previousUnreadCount = unreadCount

        // Optimistic update
        for index in recentNotifications.indices {
            recentNotifications[index].isRead = true
        }
        unreadCount = 0

        do {
            try await withRetry(maxAttempts: maxRetryAttempts) {
                try await self.repository.markAllAsRead(for: self.userId)
            }
            HapticManager.success()
            logger.info("Marked all notifications as read for user: \(self.userId)")
            trackAnalytics(.allNotificationsRead(count: previousUnreadCount))

        } catch {
            // Rollback on failure
            recentNotifications = previousNotifications
            unreadCount = previousUnreadCount

            if isNetworkError(error) {
                queuePendingAction(.markAllRead)
            } else {
                handleError(error)
            }
        }
    }

    /// Delete a notification
    func deleteNotification(_ notification: UserNotification) async {
        guard !processingIds.contains(notification.id) else { return }

        processingIds.insert(notification.id)
        defer { processingIds.remove(notification.id) }

        let previousNotifications = recentNotifications
        let wasUnread = !notification.isRead
        let previousUnreadCount = unreadCount

        // Optimistic removal with animation
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            recentNotifications.removeAll { $0.id == notification.id }
            if wasUnread {
                unreadCount = max(0, unreadCount - 1)
            }
        }

        do {
            try await withRetry(maxAttempts: maxRetryAttempts) {
                try await self.repository.deleteNotification(notificationId: notification.id)
            }
            HapticManager.light()
            logger.debug("Deleted notification: \(notification.id)")
            trackAnalytics(.notificationDeleted)

        } catch {
            // Rollback on failure
            withAnimation {
                recentNotifications = previousNotifications
                unreadCount = previousUnreadCount
            }

            if isNetworkError(error) {
                queuePendingAction(.delete(notification.id))
            } else {
                handleError(error)
            }
        }
    }

    /// Subscribe to real-time notification updates
    func subscribeToRealtime() async {
        await repository.subscribeToNotifications(for: userId) { [weak self] notification in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // Insert new notification at the beginning with animation
                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    self.recentNotifications.insert(notification, at: 0)

                    // Trim to dropdown limit
                    if self.recentNotifications.count > self.dropdownLimit {
                        self.recentNotifications = Array(self.recentNotifications.prefix(self.dropdownLimit))
                    }

                    // Update unread count
                    if !notification.isRead {
                        self.unreadCount += 1
                    }
                }

                // Trigger new notification indicator
                self.hasNewNotification = true

                // Reset after animation completes
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000) // 600ms
                    await MainActor.run {
                        self.hasNewNotification = false
                    }
                }

                HapticManager.success()
                self.logger.info("New notification received: \(notification.title)")
                self.trackAnalytics(.notificationReceived(type: notification.type.rawValue))

                // Announce for VoiceOver
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "New notification: \(notification.title)",
                )
            }
        }
    }

    /// Process pending offline actions
    func processPendingActions() async {
        guard !pendingActions.isEmpty else { return }

        let actions = pendingActions
        pendingActions.removeAll()

        for action in actions {
            switch action {
            case let .markRead(id):
                if let notification = recentNotifications.first(where: { $0.id == id }) {
                    await markAsRead(notification)
                }
            case .markAllRead:
                await markAllAsRead()
            case let .delete(id):
                if let notification = recentNotifications.first(where: { $0.id == id }) {
                    await deleteNotification(notification)
                }
            }
        }
    }

    /// Toggle dropdown visibility
    func toggleDropdown() {
        isDropdownVisible.toggle()

        if isDropdownVisible {
            Task {
                await loadRecent()
            }
        }

        HapticManager.selection()
    }

    /// Dismiss dropdown
    func dismissDropdown() {
        guard isDropdownVisible else { return }
        isDropdownVisible = false
        trackAnalytics(.dropdownClosed)
    }

    /// Clear error state
    func clearError() {
        error = nil
        showError = false
    }

    // MARK: - Private Methods

    /// Retry with exponential backoff
    private func withRetry<T>(
        maxAttempts: Int,
        operation: @escaping () async throws -> T,
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0 ..< maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error

                // Don't retry non-retryable errors
                guard isRetryableError(error) else { throw error }

                // Calculate delay with exponential backoff
                let delay = baseRetryDelay * pow(2.0, Double(attempt))
                let jitter = Double.random(in: 0 ... 0.5)
                let totalDelay = delay + jitter

                logger.debug("Retry attempt \(attempt + 1)/\(maxAttempts) after \(totalDelay)s")
                try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
            }
        }

        throw lastError ?? AppError.databaseError("Max retries exceeded")
    }

    private func isRetryableError(_ error: Error) -> Bool {
        // Network errors are retryable
        if isNetworkError(error) { return true }

        // Timeout errors are retryable
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }

        return false
    }

    private func isNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                return true
            default:
                return false
            }
        }
        return false
    }

    private func queuePendingAction(_ action: PendingAction) {
        pendingActions.append(action)
        state = .offline
        logger.info("Queued action for offline retry: \(String(describing: action))")
    }

    private func handleError(_ error: Error) {
        if let appError = error as? AppError {
            self.error = appError
        } else {
            self.error = AppError.databaseError(error.localizedDescription)
        }
        showError = true
        logger.error("NotificationCenter error: \(error.localizedDescription)")
    }

    // MARK: - Analytics

    private enum AnalyticsEvent {
        case dropdownOpened
        case dropdownClosed
        case notificationsLoaded(count: Int)
        case notificationRead
        case allNotificationsRead(count: Int)
        case notificationDeleted
        case notificationReceived(type: String)
    }

    private func trackAnalytics(_ event: AnalyticsEvent) {
        // Integration point for analytics (Mixpanel, Amplitude, etc.)
        switch event {
        case .dropdownOpened:
            logger.debug("[Analytics] Notification dropdown opened")
        case .dropdownClosed:
            logger.debug("[Analytics] Notification dropdown closed")
        case let .notificationsLoaded(count):
            logger.debug("[Analytics] Loaded \(count) notifications")
        case .notificationRead:
            logger.debug("[Analytics] Notification marked as read")
        case let .allNotificationsRead(count):
            logger.debug("[Analytics] All \(count) notifications marked as read")
        case .notificationDeleted:
            logger.debug("[Analytics] Notification deleted")
        case let .notificationReceived(type):
            logger.debug("[Analytics] New notification received: \(type)")
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
    extension NotificationCenterViewModel {
        /// Create a preview instance with sample data
        static func preview() -> NotificationCenterViewModel {
            let viewModel = NotificationCenterViewModel(
                repository: MockNotificationRepository(),
                userId: UUID(),
            )
            viewModel.recentNotifications = UserNotification.sampleNotifications
            viewModel.unreadCount = 3
            viewModel.state = .loaded
            return viewModel
        }

        /// Create an empty preview instance
        static func emptyPreview() -> NotificationCenterViewModel {
            let viewModel = NotificationCenterViewModel(
                repository: MockNotificationRepository(),
                userId: UUID(),
            )
            viewModel.state = .loaded
            return viewModel
        }

        /// Create a loading preview instance
        static func loadingPreview() -> NotificationCenterViewModel {
            let viewModel = NotificationCenterViewModel(
                repository: MockNotificationRepository(),
                userId: UUID(),
            )
            viewModel.state = .loading
            return viewModel
        }
    }
#endif
