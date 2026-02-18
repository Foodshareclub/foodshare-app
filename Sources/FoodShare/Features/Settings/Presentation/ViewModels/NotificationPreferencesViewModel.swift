// MARK: - NotificationPreferencesViewModel.swift
// Enterprise Notification Preferences ViewModel
// FoodShare iOS - Clean Architecture Presentation Layer
// Version: 2.0 - 100x Pro Enterprise Grade



#if !SKIP
import Combine
import Foundation
import os.log
import SwiftUI

#if canImport(UIKit)
#if !SKIP
    import UIKit
#endif
#endif

// MARK: - Logging

private let logger = Logger(subsystem: "com.foodshare.app", category: "NotificationPreferences")

// MARK: - View State

/// Loading state for async operations
public enum SimpleLoadingState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case error(String)

    public var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    public var errorMessage: String? {
        if case let .error(message) = self { return message }
        return nil
    }
}

// MARK: - Analytics Event

/// Analytics events for notification preferences
public enum NotificationPreferencesAnalyticsEvent: Sendable {
    case preferencesLoaded(categoryCount: Int)
    case preferenceToggled(category: String, channel: String, enabled: Bool)
    case frequencyChanged(category: String, channel: String, frequency: String)
    case dndEnabled(durationHours: Int?)
    case dndDisabled
    case quietHoursUpdated(enabled: Bool)
    case phoneVerificationStarted
    case phoneVerificationCompleted(success: Bool)
    case errorOccurred(errorType: String, recoverable: Bool)
    case retryAttempted(operation: String, attemptNumber: Int)
    case undoPerformed(operation: String)
}

// MARK: - Undo Action

/// Represents an undoable action
private struct UndoAction {
    let description: String
    let timestamp: Date
    let undo: @MainActor () async -> Void

    init(description: String, undo: @escaping @MainActor () async -> Void) {
        self.description = description
        self.timestamp = Date()
        self.undo = undo
    }
}

// MARK: - ViewModel

/// Enterprise-grade ViewModel for notification preferences management
///
/// ## Features
/// - Optimistic updates with automatic rollback on failure
/// - Debounced batch saves to reduce API calls
/// - Automatic retry with exponential backoff
/// - Undo support for recent changes
/// - Accessibility announcements for VoiceOver
/// - Rate limiting to prevent API abuse
/// - Analytics event tracking
/// - Comprehensive error recovery
/// - Task lifecycle management
///
/// ## Usage
/// ```swift
/// let viewModel = NotificationPreferencesViewModel(repository: repository)
/// await viewModel.loadPreferences()
/// await viewModel.togglePreference(category: .posts, channel: .push)
/// ```
@MainActor
@Observable
public final class NotificationPreferencesViewModel {

    // MARK: - Configuration

    /// Configuration for retry behavior
    private enum RetryConfig {
        static let maxRetries = 3
        static let baseDelay: TimeInterval = 1.0
        static let maxDelay: TimeInterval = 10.0
    }

    /// Configuration for rate limiting
    private enum RateLimitConfig {
        static let maxOperationsPerSecond = 5
        static let windowDuration: TimeInterval = 1.0
    }

    /// Configuration for debouncing
    private enum DebounceConfig {
        static let delay: TimeInterval = 0.5
    }

    // MARK: - State

    /// Current preferences data
    public internal(set) var preferences: NotificationPreferences = NotificationPreferences()

    /// Loading state for initial fetch
    public private(set) var loadingState: SimpleLoadingState = .idle

    /// Individual preference update states (for showing spinners on toggles)
    public private(set) var updatingPreferences: Set<String> = []

    /// Last error encountered (for toast/alert display)
    public private(set) var lastError: NotificationPreferencesError?

    /// Whether DND sheet is showing
    public var showDNDSheet = false

    /// Whether quiet hours sheet is showing
    public var showQuietHoursSheet = false

    /// Whether phone verification sheet is showing
    public var showPhoneVerificationSheet = false

    /// Phone verification state
    public var phoneVerificationNumber = ""
    public var phoneVerificationCode = ""
    public var isVerifyingPhone = false

    /// Expanded sections (for collapsible UI)
    public var expandedSections: Set<NotificationChannel> = [.push]

    /// Search query for filtering categories
    public var searchQuery = ""

    /// Whether undo is available
    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Description of the last undoable action
    public var undoDescription: String? {
        undoStack.last?.description
    }

    /// Whether the device is currently offline
    public private(set) var isOffline = false

    /// Number of pending offline changes
    public var pendingOfflineChangesCount: Int {
        pendingChanges.count
    }

    // MARK: - Computed Properties

    /// Filtered categories based on search
    public var filteredCategories: [NotificationCategory] {
        let sorted = NotificationCategory.allCases.sorted { $0.sortOrder < $1.sortOrder }

        guard !searchQuery.isEmpty else { return sorted }

        let query = searchQuery.lowercased()
        return sorted.filter { category in
            category.displayName.lowercased().contains(query) ||
                category.description.lowercased().contains(query)
        }
    }

    /// Whether any save operation is in progress
    public var isSaving: Bool {
        !updatingPreferences.isEmpty
    }

    /// Whether push notifications are available (system level)
    public var isPushAvailable: Bool {
        preferences.settings.pushEnabled
    }

    /// Whether email notifications are available
    public var isEmailAvailable: Bool {
        preferences.settings.emailEnabled
    }

    /// Whether SMS notifications are available (requires verified phone)
    public var isSMSAvailable: Bool {
        preferences.settings.smsEnabled && preferences.settings.phoneVerified
    }

    /// Current DND status text
    public var dndStatusText: String {
        let dnd = preferences.settings.dnd
        if dnd.isActive {
            if let remaining = dnd.remainingTimeFormatted {
                return "On - \(remaining) remaining"
            }
            return "On"
        }
        return "Off"
    }

    /// Current quiet hours status text
    public var quietHoursStatusText: String {
        let qh = preferences.settings.quietHours
        if qh.enabled {
            return "\(qh.start) - \(qh.end)"
        }
        return "Off"
    }

    // MARK: - Dependencies

    private let repository: NotificationPreferencesRepository
    private let haptics: UIImpactFeedbackGenerator
    private let successHaptics: UINotificationFeedbackGenerator
    private let analyticsHandler: (@Sendable (NotificationPreferencesAnalyticsEvent) -> Void)?

    // MARK: - Task Management

    /// Active tasks that should be cancelled on deinit
    private var activeTasks: [Task<Void, Never>] = []

    /// Debounce timer for batch updates
    private var debounceTask: Task<Void, Never>?

    /// Pending preference changes (for batching)
    private var pendingChanges: [CategoryPreference] = []

    /// Undo stack for recent actions (max 10)
    private var undoStack: [UndoAction] = []
    private let maxUndoStackSize = 10

    // MARK: - Rate Limiting

    /// Timestamps of recent operations for rate limiting
    private var recentOperationTimestamps: [Date] = []

    // MARK: - Initialization

    /// Creates a new NotificationPreferencesViewModel
    /// - Parameters:
    ///   - repository: The repository for fetching and updating preferences
    ///   - analyticsHandler: Optional handler for analytics events
    public init(
        repository: NotificationPreferencesRepository,
        analyticsHandler: (@Sendable (NotificationPreferencesAnalyticsEvent) -> Void)? = nil,
    ) {
        self.repository = repository
        self.analyticsHandler = analyticsHandler
        self.haptics = UIImpactFeedbackGenerator(style: .light)
        self.successHaptics = UINotificationFeedbackGenerator()
        haptics.prepare()
        successHaptics.prepare()

        logger.info("NotificationPreferencesViewModel initialized")
    }

    nonisolated deinit {
        // Note: Cannot access MainActor-isolated properties in nonisolated deinit
        // Tasks will be cancelled automatically when their references are released
    }

    // MARK: - Lifecycle

    /// Load preferences from server with automatic retry
    public func loadPreferences() async {
        guard loadingState != .loading else {
            logger.debug("Load already in progress, skipping")
            return
        }

        loadingState = .loading
        lastError = nil

        logger.info("Loading notification preferences")

        do {
            preferences = try await withRetry(operation: "loadPreferences") {
                try await self.repository.fetchPreferences()
            }
            loadingState = .loaded
            isOffline = false

            // Process any pending offline changes
            await processPendingChanges()

            trackAnalytics(.preferencesLoaded(categoryCount: NotificationCategory.allCases.count))
            announceForAccessibility("Notification preferences loaded")
            logger.info("Preferences loaded successfully")

        } catch let error as NotificationPreferencesError {
            loadingState = .error(error.localizedDescription)
            lastError = error
            isOffline = isNetworkError(error)
            trackAnalytics(.errorOccurred(errorType: error.analyticsType, recoverable: error.isRecoverable))
            logger.error("Failed to load preferences: \(error.localizedDescription)")

        } catch {
            loadingState = .error(error.localizedDescription)
            lastError = .networkError(underlying: error)
            isOffline = true
            trackAnalytics(.errorOccurred(errorType: "network", recoverable: true))
            logger.error("Network error loading preferences: \(error.localizedDescription)")
        }
    }

    /// Refresh preferences (pull to refresh)
    public func refreshPreferences() async {
        logger.debug("Refreshing preferences")

        do {
            preferences = try await withRetry(operation: "refreshPreferences") {
                try await self.repository.fetchPreferences()
            }
            loadingState = .loaded
            lastError = nil
            isOffline = false

            await processPendingChanges()
            announceForAccessibility("Preferences refreshed")

        } catch let error as NotificationPreferencesError {
            lastError = error
            isOffline = isNetworkError(error)
        } catch {
            lastError = .networkError(underlying: error)
            isOffline = true
        }
    }

    // MARK: - Global Settings

    /// Toggle push notifications globally
    public func togglePushEnabled() async {
        guard checkRateLimit() else {
            logger.warning("Rate limit exceeded for togglePushEnabled")
            return
        }

        let newValue = !preferences.settings.pushEnabled
        let previousValue = preferences.settings.pushEnabled

        // Store undo action
        pushUndoAction(description: "Toggle push notifications") {
            await self.setPushEnabled(previousValue)
        }

        // Optimistic update
        preferences.settings.pushEnabled = newValue
        haptics.impactOccurred()
        announceForAccessibility("Push notifications \(newValue ? "enabled" : "disabled")")

        logger.info("Toggling push notifications to \(newValue)")

        do {
            var request = UpdateSettingsRequest()
            request.push_enabled = newValue
            _ = try await withRetry(operation: "togglePushEnabled") {
                try await self.repository.updateSettings(request)
            }
            successHaptics.notificationOccurred(.success)
            trackAnalytics(.preferenceToggled(category: "global", channel: "push", enabled: newValue))

        } catch {
            // Revert on error
            preferences.settings.pushEnabled = previousValue
            popUndoAction()
            handleError(error)
            announceForAccessibility("Failed to update push notifications")
        }
    }

    /// Set push enabled to specific value (for undo)
    private func setPushEnabled(_ value: Bool) async {
        preferences.settings.pushEnabled = value
        do {
            var request = UpdateSettingsRequest()
            request.push_enabled = value
            _ = try await repository.updateSettings(request)
        } catch {
            handleError(error)
        }
    }

    /// Toggle email notifications globally
    public func toggleEmailEnabled() async {
        guard checkRateLimit() else { return }

        let newValue = !preferences.settings.emailEnabled
        let previousValue = preferences.settings.emailEnabled

        pushUndoAction(description: "Toggle email notifications") {
            await self.setEmailEnabled(previousValue)
        }

        preferences.settings.emailEnabled = newValue
        haptics.impactOccurred()
        announceForAccessibility("Email notifications \(newValue ? "enabled" : "disabled")")

        logger.info("Toggling email notifications to \(newValue)")

        do {
            var request = UpdateSettingsRequest()
            request.email_enabled = newValue
            _ = try await withRetry(operation: "toggleEmailEnabled") {
                try await self.repository.updateSettings(request)
            }
            successHaptics.notificationOccurred(.success)
            trackAnalytics(.preferenceToggled(category: "global", channel: "email", enabled: newValue))

        } catch {
            preferences.settings.emailEnabled = previousValue
            popUndoAction()
            handleError(error)
        }
    }

    private func setEmailEnabled(_ value: Bool) async {
        preferences.settings.emailEnabled = value
        do {
            var request = UpdateSettingsRequest()
            request.email_enabled = value
            _ = try await repository.updateSettings(request)
        } catch {
            handleError(error)
        }
    }

    /// Toggle SMS notifications globally
    public func toggleSMSEnabled() async {
        // If not verified, show verification sheet
        if !preferences.settings.phoneVerified {
            showPhoneVerificationSheet = true
            trackAnalytics(.phoneVerificationStarted)
            return
        }

        guard checkRateLimit() else { return }

        let newValue = !preferences.settings.smsEnabled
        let previousValue = preferences.settings.smsEnabled

        pushUndoAction(description: "Toggle SMS notifications") {
            await self.setSMSEnabled(previousValue)
        }

        preferences.settings.smsEnabled = newValue
        haptics.impactOccurred()
        announceForAccessibility("SMS notifications \(newValue ? "enabled" : "disabled")")

        logger.info("Toggling SMS notifications to \(newValue)")

        do {
            var request = UpdateSettingsRequest()
            request.sms_enabled = newValue
            _ = try await withRetry(operation: "toggleSMSEnabled") {
                try await self.repository.updateSettings(request)
            }
            successHaptics.notificationOccurred(.success)
            trackAnalytics(.preferenceToggled(category: "global", channel: "sms", enabled: newValue))

        } catch {
            preferences.settings.smsEnabled = previousValue
            popUndoAction()
            handleError(error)
        }
    }

    private func setSMSEnabled(_ value: Bool) async {
        preferences.settings.smsEnabled = value
        do {
            var request = UpdateSettingsRequest()
            request.sms_enabled = value
            _ = try await repository.updateSettings(request)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Category Preferences

    /// Toggle a specific category/channel preference
    public func togglePreference(category: NotificationCategory, channel: NotificationChannel) async {
        let currentPref = preferences.preference(for: category, channel: channel)
        let newPref = CategoryPreference(
            category: category,
            channel: channel,
            enabled: !currentPref.enabled,
            frequency: currentPref.frequency,
        )

        await updatePreference(newPref)
    }

    /// Update frequency for a category/channel
    public func updateFrequency(
        category: NotificationCategory,
        channel: NotificationChannel,
        frequency: NotificationFrequency,
    ) async {
        let currentPref = preferences.preference(for: category, channel: channel)
        let newPref = CategoryPreference(
            category: category,
            channel: channel,
            enabled: currentPref.enabled,
            frequency: frequency,
        )

        await updatePreference(newPref, isFrequencyChange: true)
    }

    /// Internal: Update a single preference with optimistic update and debouncing
    private func updatePreference(_ preference: CategoryPreference, isFrequencyChange: Bool = false) async {
        guard checkRateLimit() else {
            logger.warning("Rate limit exceeded for updatePreference")
            return
        }

        let prefId = preference.id

        // Mark as updating
        updatingPreferences.insert(prefId)
        haptics.impactOccurred()

        // Store previous value for rollback
        let previousPref = preferences.preference(for: preference.category, channel: preference.channel)

        // Push undo action
        let description = isFrequencyChange
            ? "Change \(preference.category.displayName) frequency"
            : "Toggle \(preference.category.displayName) \(preference.channel.displayName)"

        pushUndoAction(description: description) {
            await self.updatePreferenceDirectly(previousPref)
        }

        // Optimistic update
        applyPreferenceToCache(preference)

        let announcement = isFrequencyChange
            ? "\(preference.category.displayName) frequency set to \(preference.frequency.displayName)"
            : "\(preference.category.displayName) \(preference.channel.displayName) \(preference.enabled ? "enabled" : "disabled")"
        announceForAccessibility(announcement)

        logger.info("Updating preference: \(preference.category.rawValue)/\(preference.channel.rawValue)")

        // Add to pending changes for batching
        pendingChanges.removeAll { $0.id == prefId }
        pendingChanges.append(preference)

        // Debounce the actual save
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(DebounceConfig.delay * 1_000_000_000))

            guard !Task.isCancelled else { return }
            await self?.flushPendingChanges()
        }

        // Track pending task
        if let task = debounceTask {
            activeTasks.append(task)
        }

        // Remove updating state after a short delay (UI feedback)
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
            updatingPreferences.remove(prefId)
        }
    }

    /// Flush all pending changes to the server
    private func flushPendingChanges() async {
        guard !pendingChanges.isEmpty else { return }

        let changesToFlush = pendingChanges
        pendingChanges.removeAll()

        logger.info("Flushing \(changesToFlush.count) pending changes")

        for preference in changesToFlush {
            do {
                try await withRetry(operation: "updatePreference") {
                    try await self.repository.updatePreference(preference)
                }
                successHaptics.notificationOccurred(.success)
                trackAnalytics(.preferenceToggled(
                    category: preference.category.rawValue,
                    channel: preference.channel.rawValue,
                    enabled: preference.enabled,
                ))

            } catch {
                // Rollback this specific change
                let previousPref = CategoryPreference(
                    category: preference.category,
                    channel: preference.channel,
                    enabled: !preference.enabled,
                    frequency: preference.frequency,
                )
                applyPreferenceToCache(previousPref)
                popUndoAction()
                handleError(error)
                logger.error("Failed to update preference: \(error.localizedDescription)")
            }
        }
    }

    /// Update preference directly without debouncing (for undo)
    private func updatePreferenceDirectly(_ preference: CategoryPreference) async {
        applyPreferenceToCache(preference)
        do {
            try await repository.updatePreference(preference)
        } catch {
            handleError(error)
        }
    }

    /// Process any pending offline changes when coming back online
    private func processPendingChanges() async {
        guard !pendingChanges.isEmpty else { return }

        logger.info("Processing \(self.pendingChanges.count) offline changes")
        await flushPendingChanges()
    }

    /// Apply preference to local cache
    private func applyPreferenceToCache(_ preference: CategoryPreference) {
        var categoryPrefs = preferences.preferences[preference.category.rawValue] ?? [:]
        categoryPrefs[preference.channel.rawValue] = NotificationPreferences.CategoryPreferenceData(
            enabled: preference.enabled,
            frequency: preference.frequency.rawValue,
        )
        preferences.preferences[preference.category.rawValue] = categoryPrefs
    }

    // MARK: - Do Not Disturb

    /// Enable DND for specified hours
    public func enableDND(hours: Int) async {
        guard checkRateLimit() else { return }

        haptics.impactOccurred()
        logger.info("Enabling DND for \(hours) hours")

        do {
            let request = EnableDNDRequest(durationHours: hours)
            let dnd = try await withRetry(operation: "enableDND") {
                try await self.repository.enableDND(request)
            }
            preferences.settings.dnd = dnd
            showDNDSheet = false
            successHaptics.notificationOccurred(.success)
            trackAnalytics(.dndEnabled(durationHours: hours))
            announceForAccessibility("Do not disturb enabled for \(hours) hours")

        } catch {
            handleError(error)
        }
    }

    /// Enable DND until specific time
    public func enableDND(until: Date) async {
        guard checkRateLimit() else { return }

        haptics.impactOccurred()
        logger.info("Enabling DND until \(until)")

        do {
            let request = EnableDNDRequest(until: until)
            let dnd = try await withRetry(operation: "enableDND") {
                try await self.repository.enableDND(request)
            }
            preferences.settings.dnd = dnd
            showDNDSheet = false
            successHaptics.notificationOccurred(.success)
            trackAnalytics(.dndEnabled(durationHours: nil))
            announceForAccessibility("Do not disturb enabled")

        } catch {
            handleError(error)
        }
    }

    /// Disable DND
    public func disableDND() async {
        guard checkRateLimit() else { return }

        haptics.impactOccurred()
        logger.info("Disabling DND")

        do {
            try await withRetry(operation: "disableDND") {
                try await self.repository.disableDND()
            }
            preferences.settings.dnd = DoNotDisturb(enabled: false, until: nil)
            successHaptics.notificationOccurred(.success)
            trackAnalytics(.dndDisabled)
            announceForAccessibility("Do not disturb disabled")

        } catch {
            handleError(error)
        }
    }

    // MARK: - Quiet Hours

    /// Update quiet hours settings
    public func updateQuietHours(enabled: Bool, start: String, end: String) async {
        guard checkRateLimit() else { return }

        let previous = preferences.settings.quietHours

        pushUndoAction(description: "Update quiet hours") {
            await self.setQuietHours(previous)
        }

        preferences.settings.quietHours = QuietHours(
            enabled: enabled,
            start: start,
            end: end,
            timezone: TimeZone.current.identifier,
        )
        haptics.impactOccurred()

        logger.info("Updating quiet hours: enabled=\(enabled), \(start)-\(end)")

        do {
            var request = UpdateSettingsRequest()
            request.quiet_hours = UpdateSettingsRequest.QuietHoursRequest(
                enabled: enabled,
                start: start,
                end: end,
                timezone: TimeZone.current.identifier,
            )
            _ = try await withRetry(operation: "updateQuietHours") {
                try await self.repository.updateSettings(request)
            }
            showQuietHoursSheet = false
            successHaptics.notificationOccurred(.success)
            trackAnalytics(.quietHoursUpdated(enabled: enabled))

            let announcement = enabled
                ? "Quiet hours set from \(start) to \(end)"
                : "Quiet hours disabled"
            announceForAccessibility(announcement)

        } catch {
            preferences.settings.quietHours = previous
            popUndoAction()
            handleError(error)
        }
    }

    private func setQuietHours(_ quietHours: QuietHours) async {
        preferences.settings.quietHours = quietHours
        do {
            var request = UpdateSettingsRequest()
            request.quiet_hours = UpdateSettingsRequest.QuietHoursRequest(
                enabled: quietHours.enabled,
                start: quietHours.start,
                end: quietHours.end,
                timezone: quietHours.timezone,
            )
            _ = try await repository.updateSettings(request)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Phone Verification

    /// Start phone verification flow
    public func initiatePhoneVerification() async {
        guard !phoneVerificationNumber.isEmpty else { return }

        isVerifyingPhone = true
        logger.info("Initiating phone verification")

        do {
            try await withRetry(operation: "initiatePhoneVerification") {
                try await self.repository.initiatePhoneVerification(phoneNumber: self.phoneVerificationNumber)
            }
            announceForAccessibility("Verification code sent")

        } catch {
            handleError(error)
            trackAnalytics(.phoneVerificationCompleted(success: false))
        }

        isVerifyingPhone = false
    }

    /// Verify phone with code
    public func verifyPhoneCode() async {
        guard phoneVerificationCode.count == 6 else { return }

        isVerifyingPhone = true
        logger.info("Verifying phone code")

        do {
            let verified = try await withRetry(operation: "verifyPhone") {
                try await self.repository.verifyPhone(
                    phoneNumber: self.phoneVerificationNumber,
                    code: self.phoneVerificationCode,
                )
            }

            if verified {
                preferences.settings.phoneVerified = true
                preferences.settings.phoneNumber = phoneVerificationNumber
                preferences.settings.smsEnabled = true
                showPhoneVerificationSheet = false
                phoneVerificationNumber = ""
                phoneVerificationCode = ""
                successHaptics.notificationOccurred(.success)
                trackAnalytics(.phoneVerificationCompleted(success: true))
                announceForAccessibility("Phone verified successfully")
                logger.info("Phone verification successful")
            }
        } catch {
            handleError(error)
            trackAnalytics(.phoneVerificationCompleted(success: false))
        }

        isVerifyingPhone = false
    }

    // MARK: - Digest Settings

    /// Update digest delivery settings
    public func updateDigestSettings(
        dailyEnabled: Bool? = nil,
        dailyTime: String? = nil,
        weeklyEnabled: Bool? = nil,
        weeklyDay: Int? = nil,
    ) async {
        guard checkRateLimit() else { return }

        let previous = preferences.settings.digest

        pushUndoAction(description: "Update digest settings") {
            await self.setDigestSettings(previous)
        }

        if let daily = dailyEnabled {
            preferences.settings.digest.dailyEnabled = daily
        }
        if let time = dailyTime {
            preferences.settings.digest.dailyTime = time
        }
        if let weekly = weeklyEnabled {
            preferences.settings.digest.weeklyEnabled = weekly
        }
        if let day = weeklyDay {
            preferences.settings.digest.weeklyDay = day
        }

        haptics.impactOccurred()
        logger.info("Updating digest settings")

        do {
            var request = UpdateSettingsRequest()
            request.digest = UpdateSettingsRequest.DigestRequest(
                daily_enabled: dailyEnabled,
                daily_time: dailyTime,
                weekly_enabled: weeklyEnabled,
                weekly_day: weeklyDay,
            )
            _ = try await withRetry(operation: "updateDigestSettings") {
                try await self.repository.updateSettings(request)
            }
            successHaptics.notificationOccurred(.success)
            announceForAccessibility("Digest settings updated")

        } catch {
            preferences.settings.digest = previous
            popUndoAction()
            handleError(error)
        }
    }

    private func setDigestSettings(_ digest: DigestSettings) async {
        preferences.settings.digest = digest
        do {
            var request = UpdateSettingsRequest()
            request.digest = UpdateSettingsRequest.DigestRequest(
                daily_enabled: digest.dailyEnabled,
                daily_time: digest.dailyTime,
                weekly_enabled: digest.weeklyEnabled,
                weekly_day: digest.weeklyDay,
            )
            _ = try await repository.updateSettings(request)
        } catch {
            handleError(error)
        }
    }

    // MARK: - Undo Support

    /// Undo the last action
    public func undo() async {
        guard let action = undoStack.popLast() else { return }

        logger.info("Undoing: \(action.description)")
        trackAnalytics(.undoPerformed(operation: action.description))

        await action.undo()
        haptics.impactOccurred()
        announceForAccessibility("Undone: \(action.description)")
    }

    private func pushUndoAction(description: String, undo: @escaping @MainActor () async -> Void) {
        undoStack.append(UndoAction(description: description, undo: undo))

        // Trim old actions
        if undoStack.count > maxUndoStackSize {
            undoStack.removeFirst(undoStack.count - maxUndoStackSize)
        }
    }

    private func popUndoAction() {
        _ = undoStack.popLast()
    }

    // MARK: - Retry Logic

    /// Execute an operation with automatic retry and exponential backoff
    private func withRetry<T>(
        operation: String,
        maxRetries: Int = RetryConfig.maxRetries,
        block: () async throws -> T,
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0 ..< maxRetries {
            do {
                return try await block()
            } catch {
                lastError = error

                // Don't retry for non-recoverable errors
                if let prefError = error as? NotificationPreferencesError, !prefError.isRecoverable {
                    throw error
                }

                if attempt < maxRetries - 1 {
                    let delay = min(
                        RetryConfig.baseDelay * pow(2, Double(attempt)),
                        RetryConfig.maxDelay,
                    )

                    logger.warning("Retry \(attempt + 1)/\(maxRetries) for \(operation) after \(delay)s")
                    trackAnalytics(.retryAttempted(operation: operation, attemptNumber: attempt + 1))

                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NotificationPreferencesError.networkError(underlying: URLError(.unknown))
    }

    // MARK: - Rate Limiting

    /// Check if operation is within rate limit
    private func checkRateLimit() -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-RateLimitConfig.windowDuration)

        // Remove old timestamps
        recentOperationTimestamps.removeAll { $0 < windowStart }

        if recentOperationTimestamps.count >= RateLimitConfig.maxOperationsPerSecond {
            logger.warning("Rate limit exceeded: \(self.recentOperationTimestamps.count) operations in window")
            return false
        }

        recentOperationTimestamps.append(now)
        return true
    }

    // MARK: - Helpers

    /// Check if a specific preference is currently updating
    public func isUpdating(category: NotificationCategory, channel: NotificationChannel) -> Bool {
        let id = "\(category.rawValue)-\(channel.rawValue)"
        return updatingPreferences.contains(id)
    }

    /// Get binding for a category preference enabled state
    public func enabledBinding(category: NotificationCategory, channel: NotificationChannel) -> Binding<Bool> {
        Binding(
            get: {
                self.preferences.preference(for: category, channel: channel).enabled
            },
            set: { _ in
                Task { await self.togglePreference(category: category, channel: channel) }
            },
        )
    }

    /// Get binding for a category preference frequency
    public func frequencyBinding(
        category: NotificationCategory,
        channel: NotificationChannel,
    ) -> Binding<NotificationFrequency> {
        Binding(
            get: {
                self.preferences.preference(for: category, channel: channel).frequency
            },
            set: { newValue in
                Task { await self.updateFrequency(category: category, channel: channel, frequency: newValue) }
            },
        )
    }

    /// Clear last error
    public func clearError() {
        lastError = nil
    }

    /// Handle errors with appropriate user feedback
    private func handleError(_ error: Error) {
        if let prefError = error as? NotificationPreferencesError {
            lastError = prefError
            trackAnalytics(.errorOccurred(errorType: prefError.analyticsType, recoverable: prefError.isRecoverable))
        } else {
            lastError = .networkError(underlying: error)
            trackAnalytics(.errorOccurred(errorType: "network", recoverable: true))
        }

        // Haptic feedback for error
        let errorHaptic = UINotificationFeedbackGenerator()
        errorHaptic.notificationOccurred(.error)

        logger.error("Error occurred: \(error.localizedDescription)")
    }

    /// Check if error is a network error
    private func isNetworkError(_ error: NotificationPreferencesError) -> Bool {
        if case .networkError = error { return true }
        return false
    }

    // MARK: - Section Expansion

    /// Toggle section expansion
    public func toggleSection(_ channel: NotificationChannel) {
        if expandedSections.contains(channel) {
            expandedSections.remove(channel)
        } else {
            expandedSections.insert(channel)
        }
        haptics.impactOccurred()
    }

    /// Check if section is expanded
    public func isSectionExpanded(_ channel: NotificationChannel) -> Bool {
        expandedSections.contains(channel)
    }

    // MARK: - Accessibility

    /// Announce a message for VoiceOver users
    private func announceForAccessibility(_ message: String) {
        #if canImport(UIKit)
            UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }

    // MARK: - Analytics

    /// Track an analytics event
    private func trackAnalytics(_ event: NotificationPreferencesAnalyticsEvent) {
        analyticsHandler?(event)
    }
}

// MARK: - Error Extensions

extension NotificationPreferencesError {
    /// Analytics type string for the error
    var analyticsType: String {
        switch self {
        case .notAuthenticated: "auth"
        case .networkError: "network"
        case .invalidResponse: "invalid_response"
        case .serverError: "server"
        case .validationError: "validation"
        case .phoneVerificationFailed: "phone_verification"
        case .phoneVerificationExpired: "phone_expired"
        case .rateLimited: "rate_limited"
        }
    }

    /// Whether this error type is recoverable through retry
    var isRecoverable: Bool {
        switch self {
        case .networkError, .serverError, .rateLimited:
            true
        case .notAuthenticated, .invalidResponse, .validationError,
             .phoneVerificationFailed, .phoneVerificationExpired:
            false
        }
    }
}

// MARK: - Preview Support

#if DEBUG
    extension NotificationPreferencesViewModel {
        /// Create a preview instance with mock data
        static var preview: NotificationPreferencesViewModel {
            let mockRepo = MockNotificationPreferencesRepository()
            let viewModel = NotificationPreferencesViewModel(repository: mockRepo)
            viewModel.preferences = .mock
            viewModel.loadingState = .loaded
            return viewModel
        }

        /// Create a loading preview instance
        static var loadingPreview: NotificationPreferencesViewModel {
            let mockRepo = MockNotificationPreferencesRepository()
            let viewModel = NotificationPreferencesViewModel(repository: mockRepo)
            viewModel.loadingState = .loading
            return viewModel
        }

        /// Create an error preview instance
        static var errorPreview: NotificationPreferencesViewModel {
            let mockRepo = MockNotificationPreferencesRepository()
            let viewModel = NotificationPreferencesViewModel(repository: mockRepo)
            viewModel.loadingState = .error("Failed to load preferences")
            viewModel.lastError = .networkError(underlying: URLError(.notConnectedToInternet))
            return viewModel
        }

        /// Create an offline preview instance
        static var offlinePreview: NotificationPreferencesViewModel {
            let mockRepo = MockNotificationPreferencesRepository()
            let viewModel = NotificationPreferencesViewModel(repository: mockRepo)
            viewModel.preferences = .mock
            viewModel.loadingState = .loaded
            viewModel.isOffline = true
            return viewModel
        }
    }

#endif

#endif
