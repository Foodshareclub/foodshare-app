

#if !SKIP
import Foundation
import SwiftUI

// MARK: - Restoration Pending Operation

/// Represents an operation that was interrupted and needs to be retried
public struct RestorationPendingOperation: Codable, Identifiable, Sendable {
    public let id: UUID
    public let type: OperationType
    public let payload: Data
    public let createdAt: Date
    public var retryCount: Int
    public let maxRetries: Int

    public enum OperationType: String, Codable, Sendable {
        case createListing
        case updateListing
        case deleteListing
        case sendMessage
        case updateProfile
        case createReview
        case savePost
        case reportContent
    }

    public init(
        id: UUID = UUID(),
        type: OperationType,
        payload: Data,
        maxRetries: Int = 3,
    ) {
        self.id = id
        self.type = type
        self.payload = payload
        self.createdAt = Date()
        self.retryCount = 0
        self.maxRetries = maxRetries
    }

    public var canRetry: Bool {
        retryCount < maxRetries
    }
}

// MARK: - Screen State

/// Represents the state of a specific screen for restoration
public struct ScreenState: Codable, Sendable {
    public let screenId: String
    public let scrollOffset: CGFloat
    public let selectedTab: Int?
    public let expandedSections: [String]
    public let filterState: Data?
    public let timestamp: Date

    public init(
        screenId: String,
        scrollOffset: CGFloat = 0,
        selectedTab: Int? = nil,
        expandedSections: [String] = [],
        filterState: Data? = nil,
    ) {
        self.screenId = screenId
        self.scrollOffset = scrollOffset
        self.selectedTab = selectedTab
        self.expandedSections = expandedSections
        self.filterState = filterState
        self.timestamp = Date()
    }
}

// MARK: - App State Restoration

/// Actor-based service for persisting and restoring app state after crashes or force quits
public actor AppStateRestoration {

    // MARK: - Properties

    public static let shared = AppStateRestoration()

    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // Keys
    private let navigationPathKey = "com.foodshare.state.navigationPath"
    private let screenStatesKey = "com.foodshare.state.screenStates"
    private let pendingOperationsKey = "com.foodshare.state.pendingOperations"
    private let lastActiveTabKey = "com.foodshare.state.lastActiveTab"
    private let sessionRestoredKey = "com.foodshare.state.sessionRestored"
    private let lastSessionTimestampKey = "com.foodshare.state.lastSessionTimestamp"

    // State
    private var screenStates: [String: ScreenState] = [:]
    private var pendingOperations: [RestorationPendingOperation] = []
    private var hasRestoredSession = false

    // Configuration
    private let stateExpirationInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let maxRestorationPendingOperations = 50

    // MARK: - Initialization

    private init() {
        Task {
            await loadPersistedState()
        }
    }

    // MARK: - Navigation State

    /// Saves the current navigation path for restoration
    public func saveNavigationPath(_ pathData: Data) {
        userDefaults.set(pathData, forKey: navigationPathKey)
        updateSessionTimestamp()
    }

    /// Restores the previously saved navigation path
    public func restoreNavigationPath() -> Data? {
        guard isSessionValid() else {
            clearNavigationState()
            return nil
        }
        return userDefaults.data(forKey: navigationPathKey)
    }

    /// Clears the saved navigation state
    public func clearNavigationState() {
        userDefaults.removeObject(forKey: navigationPathKey)
    }

    // MARK: - Tab State

    /// Saves the last active tab index
    public func saveActiveTab(_ index: Int) {
        userDefaults.set(index, forKey: lastActiveTabKey)
        updateSessionTimestamp()
    }

    /// Restores the last active tab index
    public func restoreActiveTab() -> Int? {
        guard isSessionValid() else { return nil }
        let index = userDefaults.integer(forKey: lastActiveTabKey)
        return index > 0 ? index : nil
    }

    // MARK: - Screen State

    /// Saves the state of a specific screen
    public func saveScreenState(_ state: ScreenState) {
        screenStates[state.screenId] = state
        persistScreenStates()
        updateSessionTimestamp()
    }

    /// Restores the state of a specific screen
    public func restoreScreenState(for screenId: String) -> ScreenState? {
        guard isSessionValid() else { return nil }
        return screenStates[screenId]
    }

    /// Clears the state of a specific screen
    public func clearScreenState(for screenId: String) {
        screenStates.removeValue(forKey: screenId)
        persistScreenStates()
    }

    // MARK: - Pending Operations

    /// Queues an operation for retry after restoration
    public func saveRestorationPendingOperation(_ operation: RestorationPendingOperation) {
        // Limit pending operations to prevent unbounded growth
        if pendingOperations.count >= maxRestorationPendingOperations {
            // Remove oldest operations
            pendingOperations.removeFirst(pendingOperations.count - maxRestorationPendingOperations + 1)
        }

        pendingOperations.append(operation)
        persistRestorationPendingOperations()
    }

    /// Returns all pending operations that can be retried
    public func getRestorationPendingOperations() -> [RestorationPendingOperation] {
        pendingOperations.filter(\.canRetry)
    }

    /// Marks an operation as completed and removes it
    public func completeRestorationPendingOperation(_ id: UUID) {
        pendingOperations.removeAll { $0.id == id }
        persistRestorationPendingOperations()
    }

    /// Increments the retry count for an operation
    public func incrementRetryCount(for id: UUID) {
        if let index = pendingOperations.firstIndex(where: { $0.id == id }) {
            pendingOperations[index].retryCount += 1
            persistRestorationPendingOperations()
        }
    }

    /// Processes all pending operations with the provided handler
    public func processRestorationPendingOperations(
        handler: @Sendable (RestorationPendingOperation) async throws -> Bool,
    ) async {
        let operations = getRestorationPendingOperations()

        for operation in operations {
            do {
                let success = try await handler(operation)
                if success {
                    completeRestorationPendingOperation(operation.id)
                } else {
                    incrementRetryCount(for: operation.id)
                }
            } catch {
                incrementRetryCount(for: operation.id)
            }
        }
    }

    // MARK: - Session Management

    /// Checks if a session restoration is available
    public func hasSessionToRestore() -> Bool {
        guard !hasRestoredSession else { return false }
        guard isSessionValid() else { return false }

        let hasNavigation = userDefaults.data(forKey: navigationPathKey) != nil
        let hasScreenStates = !screenStates.isEmpty
        let hasPendingOps = !pendingOperations.isEmpty

        return hasNavigation || hasScreenStates || hasPendingOps
    }

    /// Marks the session as restored (prevents duplicate restoration)
    public func markSessionRestored() {
        hasRestoredSession = true
        userDefaults.set(true, forKey: sessionRestoredKey)
    }

    /// Clears all saved state
    public func clearAllState() {
        userDefaults.removeObject(forKey: navigationPathKey)
        userDefaults.removeObject(forKey: screenStatesKey)
        userDefaults.removeObject(forKey: pendingOperationsKey)
        userDefaults.removeObject(forKey: lastActiveTabKey)
        userDefaults.removeObject(forKey: sessionRestoredKey)
        userDefaults.removeObject(forKey: lastSessionTimestampKey)

        screenStates.removeAll()
        pendingOperations.removeAll()
        hasRestoredSession = false
    }

    // MARK: - Private Helpers

    private func loadPersistedState() {
        // Load screen states
        if let data = userDefaults.data(forKey: screenStatesKey),
           let states = try? decoder.decode([String: ScreenState].self, from: data) {
            screenStates = states
        }

        // Load pending operations
        if let data = userDefaults.data(forKey: pendingOperationsKey),
           let operations = try? decoder.decode([RestorationPendingOperation].self, from: data) {
            pendingOperations = operations
        }

        // Check if session was already restored in a previous launch
        hasRestoredSession = userDefaults.bool(forKey: sessionRestoredKey)
    }

    private func persistScreenStates() {
        if let data = try? encoder.encode(screenStates) {
            userDefaults.set(data, forKey: screenStatesKey)
        }
    }

    private func persistRestorationPendingOperations() {
        if let data = try? encoder.encode(pendingOperations) {
            userDefaults.set(data, forKey: pendingOperationsKey)
        }
    }

    private func updateSessionTimestamp() {
        userDefaults.set(Date().timeIntervalSince1970, forKey: lastSessionTimestampKey)
        // Reset the restored flag when new state is saved
        userDefaults.set(false, forKey: sessionRestoredKey)
        hasRestoredSession = false
    }

    private func isSessionValid() -> Bool {
        let timestamp = userDefaults.double(forKey: lastSessionTimestampKey)
        guard timestamp > 0 else { return false }

        let sessionDate = Date(timeIntervalSince1970: timestamp)
        return Date().timeIntervalSince(sessionDate) < stateExpirationInterval
    }
}

// MARK: - SwiftUI Environment

/// Environment key for accessing state restoration
private struct AppStateRestorationKey: EnvironmentKey {
    static let defaultValue: AppStateRestoration = .shared
}

extension EnvironmentValues {
    public var stateRestoration: AppStateRestoration {
        get { self[AppStateRestorationKey.self] }
        set { self[AppStateRestorationKey.self] = newValue }
    }
}

// MARK: - View Modifier for Screen State

/// Modifier that automatically saves and restores screen state
public struct ScreenStateRestorationModifier: ViewModifier {
    let screenId: String
    @State private var scrollOffset: CGFloat = 0
    @State private var hasRestored = false

    public func body(content: Content) -> some View {
        content
            .task {
                guard !hasRestored else { return }
                hasRestored = true

                if let state = await AppStateRestoration.shared.restoreScreenState(for: screenId) {
                    scrollOffset = state.scrollOffset
                }
            }
            .onDisappear {
                Task {
                    let state = ScreenState(
                        screenId: screenId,
                        scrollOffset: scrollOffset,
                    )
                    await AppStateRestoration.shared.saveScreenState(state)
                }
            }
    }
}

extension View {
    /// Enables automatic state restoration for this screen
    public func restorable(screenId: String) -> some View {
        modifier(ScreenStateRestorationModifier(screenId: screenId))
    }
}


#endif
