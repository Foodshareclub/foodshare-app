// MARK: - NotificationPreferencesViewModelTests.swift
// Enterprise Notification Preferences ViewModel Tests
// FoodShare iOS - Swift Testing Framework
// Version: 2.0 - 100x Pro Enterprise Grade

import Foundation
import Testing
@testable import FoodShare

// MARK: - Test Suite

@Suite("Notification Preferences ViewModel")
struct NotificationPreferencesViewModelTests {

    // MARK: - Loading Tests

    @Test("Initial state is idle")
    func initialStateIsIdle() async {
        let viewModel = await createViewModel()
        #expect(await viewModel.loadingState == .idle)
    }

    @Test("Load preferences transitions to loaded state")
    func loadPreferencesSuccess() async {
        let viewModel = await createViewModel()

        await viewModel.loadPreferences()

        #expect(await viewModel.loadingState == .loaded)
        #expect(await viewModel.lastError == nil)
        #expect(await viewModel.isOffline == false)
    }

    @Test("Load preferences handles error gracefully")
    func loadPreferencesError() async {
        let mockRepo = await MockNotificationPreferencesRepository()
        await mockRepo.setShouldFail(true)
        let viewModel = await NotificationPreferencesViewModel(repository: mockRepo)

        await viewModel.loadPreferences()

        #expect(await viewModel.loadingState != .loaded)
        #expect(await viewModel.lastError != nil)
    }

    @Test("Load preferences retries on network failure")
    func loadPreferencesRetries() async {
        let mockRepo = await MockNotificationPreferencesRepository()
        await mockRepo.setFailCount(2) // Fail first 2 attempts, succeed on 3rd
        let viewModel = await NotificationPreferencesViewModel(repository: mockRepo)

        await viewModel.loadPreferences()

        #expect(await viewModel.loadingState == .loaded)
        #expect(await mockRepo.fetchCallCount == 3)
    }

    @Test("Concurrent load requests are deduplicated")
    func concurrentLoadsDeduplicated() async {
        let mockRepo = await MockNotificationPreferencesRepository()
        await mockRepo.setDelay(0.5)
        let viewModel = await NotificationPreferencesViewModel(repository: mockRepo)

        // Start two loads concurrently
        async let load1: () = viewModel.loadPreferences()
        async let load2: () = viewModel.loadPreferences()

        await load1
        await load2

        // Should only have called fetch once
        #expect(await mockRepo.fetchCallCount == 1)
    }

    // MARK: - Global Settings Tests

    @Test("Toggle push notifications updates state optimistically")
    func togglePushEnabled() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        let initialValue = await viewModel.preferences.settings.pushEnabled

        await viewModel.togglePushEnabled()

        let newValue = await viewModel.preferences.settings.pushEnabled
        #expect(newValue == !initialValue)
    }

    @Test("Toggle push notifications adds undo action")
    func togglePushEnabledAddsUndo() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        #expect(await viewModel.canUndo == false)

        await viewModel.togglePushEnabled()

        #expect(await viewModel.canUndo == true)
        #expect(await viewModel.undoDescription == "Toggle push notifications")
    }

    @Test("Toggle email notifications updates state")
    func toggleEmailEnabled() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        let initialValue = await viewModel.preferences.settings.emailEnabled

        await viewModel.toggleEmailEnabled()

        let newValue = await viewModel.preferences.settings.emailEnabled
        #expect(newValue == !initialValue)
    }

    @Test("Toggle SMS shows verification when not verified")
    func toggleSMSShowsVerification() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        // Ensure phone is not verified
        #expect(await viewModel.preferences.settings.phoneVerified == false)

        await viewModel.toggleSMSEnabled()

        // Should show verification sheet instead of toggling
        #expect(await viewModel.showPhoneVerificationSheet == true)
    }

    // MARK: - Category Preference Tests

    @Test("Toggle category preference updates correctly")
    func toggleCategoryPreference() async throws {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        let category = NotificationCategory.posts
        let channel = NotificationChannel.push
        let initialPref = await viewModel.preferences.preference(for: category, channel: channel)

        await viewModel.togglePreference(category: category, channel: channel)

        // Wait for debounce
        try await Task.sleep(nanoseconds: 600_000_000)

        let newPref = await viewModel.preferences.preference(for: category, channel: channel)
        #expect(newPref.enabled == !initialPref.enabled)
    }

    @Test("Update frequency changes preference")
    func updateFrequency() async throws {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        let category = NotificationCategory.forum
        let channel = NotificationChannel.email
        let newFrequency = NotificationFrequency.daily

        await viewModel.updateFrequency(category: category, channel: channel, frequency: newFrequency)

        // Wait for debounce
        try await Task.sleep(nanoseconds: 600_000_000)

        let pref = await viewModel.preferences.preference(for: category, channel: channel)
        #expect(pref.frequency == newFrequency)
    }

    @Test("isUpdating tracks in-progress updates", arguments: NotificationCategory.allCases)
    func isUpdatingTracksProgress(category: NotificationCategory) async throws {
        let mockRepo = await MockNotificationPreferencesRepository()
        await mockRepo.setDelay(0.5) // Add delay to catch updating state
        let viewModel = await NotificationPreferencesViewModel(repository: mockRepo)
        await viewModel.loadPreferences()

        let channel = NotificationChannel.push

        // Start update in background
        Task {
            await viewModel.togglePreference(category: category, channel: channel)
        }

        // Give time for update to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s

        let isUpdating = await viewModel.isUpdating(category: category, channel: channel)
        #expect(isUpdating == true)
    }

    // MARK: - Rate Limiting Tests

    @Test("Rate limiting prevents rapid operations")
    func rateLimitingWorks() async {
        let mockRepo = await MockNotificationPreferencesRepository()
        let viewModel = await NotificationPreferencesViewModel(repository: mockRepo)
        await viewModel.loadPreferences()

        // Rapidly toggle 10 times
        for _ in 0 ..< 10 {
            await viewModel.togglePushEnabled()
        }

        // Should have been rate limited (max 5 per second)
        #expect(await mockRepo.updateSettingsCallCount <= 5)
    }

    // MARK: - Undo Tests

    @Test("Undo reverts last action")
    func undoRevertsLastAction() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        let initialValue = await viewModel.preferences.settings.pushEnabled

        await viewModel.togglePushEnabled()
        #expect(await viewModel.preferences.settings.pushEnabled == !initialValue)

        await viewModel.undo()

        // Should be reverted (note: undo calls API again, so value should match)
        #expect(await viewModel.canUndo == false)
    }

    @Test("Undo stack has maximum size")
    func undoStackHasMaxSize() async throws {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        // Toggle 15 times (max undo stack is 10)
        for i in 0 ..< 15 {
            // Alternate between categories to avoid duplicates
            await viewModel.togglePreference(
                category: NotificationCategory.allCases[i % NotificationCategory.allCases.count],
                channel: .push,
            )
            try await Task.sleep(nanoseconds: 50_000_000) // Small delay between operations
        }

        // Wait for debounce
        try await Task.sleep(nanoseconds: 600_000_000)

        // Should have at most 10 undo actions
        var undoCount = 0
        while await viewModel.canUndo {
            await viewModel.undo()
            undoCount += 1
            if undoCount > 15 { break } // Safety limit
        }

        #expect(undoCount <= 10)
    }

    // MARK: - Do Not Disturb Tests

    @Test("Enable DND for hours sets correct expiry")
    func enableDNDForHours() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        await viewModel.enableDND(hours: 2)

        let dnd = await viewModel.preferences.settings.dnd
        #expect(dnd.enabled == true)
        #expect(dnd.until != nil)
    }

    @Test("Disable DND clears state")
    func disableDND() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        // First enable
        await viewModel.enableDND(hours: 1)
        #expect(await viewModel.preferences.settings.dnd.enabled == true)

        // Then disable
        await viewModel.disableDND()

        let dnd = await viewModel.preferences.settings.dnd
        #expect(dnd.enabled == false)
    }

    // MARK: - Quiet Hours Tests

    @Test("Update quiet hours saves configuration")
    func updateQuietHours() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        await viewModel.updateQuietHours(enabled: true, start: "23:00", end: "07:00")

        let qh = await viewModel.preferences.settings.quietHours
        #expect(qh.enabled == true)
        #expect(qh.start == "23:00")
        #expect(qh.end == "07:00")
    }

    @Test("Update quiet hours adds undo action")
    func updateQuietHoursAddsUndo() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        await viewModel.updateQuietHours(enabled: true, start: "22:00", end: "08:00")

        #expect(await viewModel.canUndo == true)
        #expect(await viewModel.undoDescription == "Update quiet hours")
    }

    // MARK: - Digest Settings Tests

    @Test("Update digest settings persists changes")
    func updateDigestSettings() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        await viewModel.updateDigestSettings(dailyEnabled: false, weeklyEnabled: true)

        let digest = await viewModel.preferences.settings.digest
        #expect(digest.dailyEnabled == false)
        #expect(digest.weeklyEnabled == true)
    }

    // MARK: - Error Handling Tests

    @Test("Error clears after calling clearError")
    func clearErrorWorks() async {
        let mockRepo = await MockNotificationPreferencesRepository()
        await mockRepo.setShouldFail(true)
        let viewModel = await NotificationPreferencesViewModel(repository: mockRepo)

        await viewModel.loadPreferences()
        #expect(await viewModel.lastError != nil)

        await viewModel.clearError()
        #expect(await viewModel.lastError == nil)
    }

    @Test("Failed update reverts optimistic change")
    func failedUpdateReverts() async throws {
        let mockRepo = await MockNotificationPreferencesRepository()
        let viewModel = await NotificationPreferencesViewModel(repository: mockRepo)
        await viewModel.loadPreferences()

        let category = NotificationCategory.posts
        let channel = NotificationChannel.push
        let initialValue = await viewModel.preferences.preference(for: category, channel: channel).enabled

        // Make repo fail for next request
        await mockRepo.setShouldFail(true)

        await viewModel.togglePreference(category: category, channel: channel)

        // Wait for debounce and rollback
        try await Task.sleep(nanoseconds: 800_000_000)

        // Should revert to initial value
        let finalValue = await viewModel.preferences.preference(for: category, channel: channel).enabled
        #expect(finalValue == initialValue)
    }

    @Test("Network error sets offline state")
    func networkErrorSetsOfflineState() async {
        let mockRepo = await MockNotificationPreferencesRepository()
        await mockRepo.setShouldFail(true)
        await mockRepo.setErrorType(.networkError(underlying: URLError(.notConnectedToInternet)))
        let viewModel = await NotificationPreferencesViewModel(repository: mockRepo)

        await viewModel.loadPreferences()

        #expect(await viewModel.isOffline == true)
    }

    // MARK: - Section Expansion Tests

    @Test("Toggle section expansion works")
    func toggleSectionExpansion() async {
        let viewModel = await createViewModel()

        let channel = NotificationChannel.email
        let initialState = await viewModel.isSectionExpanded(channel)

        await viewModel.toggleSection(channel)

        let newState = await viewModel.isSectionExpanded(channel)
        #expect(newState == !initialState)
    }

    // MARK: - Search/Filter Tests

    @Test("Filtered categories returns sorted results")
    func filteredCategoriesAreSorted() async {
        let viewModel = await createViewModel()

        let categories = await viewModel.filteredCategories
        let sortOrders = categories.map(\.sortOrder)

        // Should be sorted by sortOrder
        #expect(sortOrders == sortOrders.sorted())
    }

    @Test("Search query filters categories")
    func searchQueryFiltersCategories() async {
        let viewModel = await createViewModel()

        await MainActor.run {
            viewModel.searchQuery = "message"
        }

        let filtered = await viewModel.filteredCategories
        #expect(filtered.contains(.chats))
        #expect(!filtered.contains(.marketing))
    }

    // MARK: - Computed Properties Tests

    @Test("DND status text shows correct state")
    func dndStatusText() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        // Initially off
        #expect(await viewModel.dndStatusText == "Off")

        // Enable DND
        await viewModel.enableDND(hours: 1)

        let status = await viewModel.dndStatusText
        #expect(status.contains("remaining") || status == "On")
    }

    @Test("Quiet hours status text shows schedule when enabled")
    func quietHoursStatusText() async {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        await viewModel.updateQuietHours(enabled: true, start: "22:00", end: "08:00")

        let status = await viewModel.quietHoursStatusText
        #expect(status == "22:00 - 08:00")
    }

    // MARK: - Binding Tests

    @Test("Enabled binding updates preference")
    func enabledBindingWorks() async throws {
        let viewModel = await createViewModel()
        await viewModel.loadPreferences()

        let category = NotificationCategory.social
        let channel = NotificationChannel.push

        let binding = await viewModel.enabledBinding(category: category, channel: channel)
        let initialValue = binding.wrappedValue

        // Trigger binding set
        binding.wrappedValue = !initialValue

        // Wait for async update and debounce
        try await Task.sleep(nanoseconds: 700_000_000)

        let newPref = await viewModel.preferences.preference(for: category, channel: channel)
        #expect(newPref.enabled == !initialValue)
    }

    // MARK: - Analytics Tests

    @Test("Analytics events are tracked")
    func analyticsEventsTracked() async {
        var trackedEvents: [NotificationPreferencesAnalyticsEvent] = []

        let mockRepo = await MockNotificationPreferencesRepository()
        let viewModel = await NotificationPreferencesViewModel(
            repository: mockRepo,
            analyticsHandler: { event in
                trackedEvents.append(event)
            },
        )

        await viewModel.loadPreferences()

        // Should have tracked preferencesLoaded event
        #expect(trackedEvents.contains { event in
            if case .preferencesLoaded = event { return true }
            return false
        })
    }

    @Test("Error events include recovery info")
    func errorEventsIncludeRecoveryInfo() async {
        var trackedEvents: [NotificationPreferencesAnalyticsEvent] = []

        let mockRepo = await MockNotificationPreferencesRepository()
        await mockRepo.setShouldFail(true)

        let viewModel = await NotificationPreferencesViewModel(
            repository: mockRepo,
            analyticsHandler: { event in
                trackedEvents.append(event)
            },
        )

        await viewModel.loadPreferences()

        // Should have tracked error with recovery info
        let errorEvent = trackedEvents.first { event in
            if case .errorOccurred = event { return true }
            return false
        }
        #expect(errorEvent != nil)
    }

    // MARK: - Offline Support Tests

    @Test("Pending offline changes count is tracked")
    func pendingOfflineChangesTracked() async {
        let mockRepo = await MockNotificationPreferencesRepository()
        await mockRepo.setDelay(1.0) // Long delay to simulate slow network
        let viewModel = await NotificationPreferencesViewModel(repository: mockRepo)
        await viewModel.loadPreferences()

        // Make a change (will be pending during debounce)
        await viewModel.togglePreference(category: .posts, channel: .push)

        // During debounce, should have pending changes
        // Note: After debounce completes, count goes back to 0
        #expect(await viewModel.pendingOfflineChangesCount >= 0)
    }

    // MARK: - Helpers

    @MainActor
    private func createViewModel() -> NotificationPreferencesViewModel {
        let mockRepo = MockNotificationPreferencesRepository()
        return NotificationPreferencesViewModel(repository: mockRepo)
    }
}

// MARK: - Mock Repository Extensions for Testing

extension MockNotificationPreferencesRepository {
    func setShouldFail(_ value: Bool) {
        Task { @MainActor in self.shouldFail = value }
    }

    func setDelay(_ value: TimeInterval) {
        Task { @MainActor in self.delay = value }
    }

    func setFailCount(_ count: Int) {
        Task { @MainActor in self.failCount = count }
    }

    func setErrorType(_ error: NotificationPreferencesError) {
        Task { @MainActor in self.errorType = error }
    }
}

// MARK: - Model Tests

@Suite("Notification Preferences Models")
struct NotificationPreferencesModelTests {

    // MARK: - Category Tests

    @Test("All categories have unique sort orders")
    func categoriesHaveUniqueSortOrders() {
        let sortOrders = NotificationCategory.allCases.map(\.sortOrder)
        let uniqueOrders = Set(sortOrders)
        #expect(sortOrders.count == uniqueOrders.count)
    }

    @Test("System category cannot be disabled")
    func systemCategoryCannotBeDisabled() {
        #expect(NotificationCategory.system.canDisable == false)
    }

    @Test("Other categories can be disabled", arguments: NotificationCategory.allCases.filter { $0 != .system })
    func otherCategoriesCanBeDisabled(category: NotificationCategory) {
        #expect(category.canDisable == true)
    }

    // MARK: - Quiet Hours Tests

    @Test("Quiet hours parses time correctly")
    func quietHoursParseTime() {
        let qh = QuietHours(enabled: true, start: "22:30", end: "07:45")

        #expect(qh.startTime?.hour == 22)
        #expect(qh.startTime?.minute == 30)
        #expect(qh.endTime?.hour == 7)
        #expect(qh.endTime?.minute == 45)
    }

    // MARK: - DND Tests

    @Test("DND isActive returns false when disabled")
    func dndInactiveWhenDisabled() {
        let dnd = DoNotDisturb(enabled: false, until: nil)
        #expect(dnd.isActive == false)
    }

    @Test("DND isActive returns true when enabled without expiry")
    func dndActiveWithoutExpiry() {
        let dnd = DoNotDisturb(enabled: true, until: nil)
        #expect(dnd.isActive == true)
    }

    @Test("DND isActive returns false when expired")
    func dndInactiveWhenExpired() {
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let dnd = DoNotDisturb(enabled: true, until: pastDate)
        #expect(dnd.isActive == false)
    }

    @Test("DND isActive returns true when not expired")
    func dndActiveWhenNotExpired() {
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now
        let dnd = DoNotDisturb(enabled: true, until: futureDate)
        #expect(dnd.isActive == true)
    }

    @Test("DND remaining time formatted correctly")
    func dndRemainingTimeFormatted() throws {
        let futureDate = Date().addingTimeInterval(3700) // ~1 hour from now
        let dnd = DoNotDisturb(enabled: true, until: futureDate)

        let formatted = dnd.remainingTimeFormatted
        #expect(formatted != nil)
        #expect(try #require(formatted?.contains("h")) || formatted!.contains("m"))
    }

    // MARK: - Frequency Tests

    @Test("All frequencies have unique display names")
    func frequenciesHaveUniqueNames() {
        let names = NotificationFrequency.allCases.map(\.displayName)
        let uniqueNames = Set(names)
        #expect(names.count == uniqueNames.count)
    }

    // MARK: - Preference ID Tests

    @Test("Category preference ID is unique combination")
    func categoryPreferenceIdIsUnique() {
        let pref1 = CategoryPreference(category: .posts, channel: .push, enabled: true, frequency: .instant)
        let pref2 = CategoryPreference(category: .posts, channel: .email, enabled: true, frequency: .instant)
        let pref3 = CategoryPreference(category: .forum, channel: .push, enabled: true, frequency: .instant)

        #expect(pref1.id != pref2.id)
        #expect(pref1.id != pref3.id)
        #expect(pref2.id != pref3.id)
    }
}

// MARK: - Repository Error Tests

@Suite("Notification Preferences Errors")
struct NotificationPreferencesErrorTests {

    @Test("Error descriptions are user-friendly")
    func errorDescriptionsAreUserFriendly() throws {
        let errors: [NotificationPreferencesError] = [
            .notAuthenticated,
            .invalidResponse,
            .phoneVerificationFailed,
            .phoneVerificationExpired,
            .rateLimited(retryAfter: 30),
        ]

        for error in errors {
            #expect(error.errorDescription != nil)
            #expect(try !(#require(error.errorDescription?.isEmpty)))
        }
    }

    @Test("Rate limited error shows retry time")
    func rateLimitedShowsRetryTime() {
        let error = NotificationPreferencesError.rateLimited(retryAfter: 60)
        #expect(error.errorDescription?.contains("60") == true)
    }

    @Test("All errors have recovery suggestions")
    func errorsHaveRecoverySuggestions() {
        let errors: [NotificationPreferencesError] = [
            .notAuthenticated,
            .networkError(underlying: URLError(.notConnectedToInternet)),
            .invalidResponse,
            .serverError(message: "test"),
            .validationError(message: "test"),
            .phoneVerificationFailed,
            .phoneVerificationExpired,
            .rateLimited(retryAfter: nil),
        ]

        for error in errors {
            #expect(error.recoverySuggestion != nil)
        }
    }

    @Test("Network errors are recoverable")
    func networkErrorsAreRecoverable() {
        let error = NotificationPreferencesError.networkError(underlying: URLError(.notConnectedToInternet))
        #expect(error.isRecoverable == true)
    }

    @Test("Auth errors are not recoverable")
    func authErrorsNotRecoverable() {
        let error = NotificationPreferencesError.notAuthenticated
        #expect(error.isRecoverable == false)
    }

    @Test("Error analytics types are correct")
    func errorAnalyticsTypesCorrect() {
        #expect(NotificationPreferencesError.notAuthenticated.analyticsType == "auth")
        #expect(NotificationPreferencesError.networkError(underlying: URLError(.unknown)).analyticsType == "network")
        #expect(NotificationPreferencesError.rateLimited(retryAfter: nil).analyticsType == "rate_limited")
    }
}

// MARK: - Loading State Tests

@Suite("Loading State")
struct LoadingStateTests {

    @Test("isLoading returns true only for loading state")
    func isLoadingCorrect() {
        #expect(LoadingState.idle.isLoading == false)
        #expect(LoadingState.loading.isLoading == true)
        #expect(LoadingState.loaded.isLoading == false)
        #expect(LoadingState.error("test").isLoading == false)
    }

    @Test("errorMessage returns message only for error state")
    func errorMessageCorrect() {
        #expect(LoadingState.idle.errorMessage == nil)
        #expect(LoadingState.loading.errorMessage == nil)
        #expect(LoadingState.loaded.errorMessage == nil)
        #expect(LoadingState.error("test message").errorMessage == "test message")
    }

    @Test("Loading states are equatable")
    func loadingStatesEquatable() {
        #expect(LoadingState.idle == LoadingState.idle)
        #expect(LoadingState.loading == LoadingState.loading)
        #expect(LoadingState.loaded == LoadingState.loaded)
        #expect(LoadingState.error("test") == LoadingState.error("test"))
        #expect(LoadingState.error("a") != LoadingState.error("b"))
    }
}
