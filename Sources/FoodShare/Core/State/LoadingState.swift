//
//  LoadingState.swift
//  Foodshare
//
//  Unified loading state pattern for async operations
//

import Foundation

/// Unified loading state for all async data operations
///
/// This enum provides a consistent pattern for managing loading, loaded, and error states
/// across all ViewModels. It eliminates manual `isLoading`, `isRefreshing`, and `error` flags.
///
/// Usage:
/// ```swift
/// @Observable
/// final class MyViewModel {
///     var dataState: LoadingState<[Item]> = .idle
///
///     func loadData() async {
///         dataState = .loading
///         do {
///             let items = try await repository.fetch()
///             dataState = .loaded(items)
///         } catch {
///             dataState = .failed(AppError.from(error))
///         }
///     }
///
///     func refresh() async {
///         if let existing = dataState.value {
///             dataState = .refreshing(existing: existing)
///         }
///         // ... load and update
///     }
/// }
/// ```
enum LoadingState<T: Sendable>: Sendable {
    /// Initial state before any loading
    case idle

    /// Currently loading data (no prior data)
    case loading

    /// Data successfully loaded
    case loaded(T)

    /// Refreshing with existing data (pull-to-refresh)
    case refreshing(existing: T)

    /// Loading more data (pagination)
    case loadingMore(existing: T)

    /// Loading failed
    case failed(AppError)

    /// Retrying after failure
    case retrying(attempt: Int, previousError: AppError)

    // MARK: - Computed Properties

    /// Whether any loading is in progress
    var isLoading: Bool {
        switch self {
        case .loading, .retrying:
            true
        default:
            false
        }
    }

    /// Whether refreshing existing data
    var isRefreshing: Bool {
        if case .refreshing = self { return true }
        return false
    }

    /// Whether loading more data (pagination)
    var isLoadingMore: Bool {
        if case .loadingMore = self { return true }
        return false
    }

    /// Whether any loading operation is active
    var isActive: Bool {
        switch self {
        case .loading, .refreshing, .loadingMore, .retrying:
            true
        default:
            false
        }
    }

    /// The current value if available
    var value: T? {
        switch self {
        case let .loaded(v), let .refreshing(existing: v), let .loadingMore(existing: v):
            v
        default:
            nil
        }
    }

    /// The current error if any
    var error: AppError? {
        switch self {
        case let .failed(e), let .retrying(_, previousError: e):
            e
        default:
            nil
        }
    }

    /// Whether the state has an error
    var hasError: Bool { error != nil }

    /// Whether data has been loaded (regardless of current state)
    var hasData: Bool { value != nil }

    /// Whether in idle state (never loaded)
    var isIdle: Bool {
        if case .idle = self { return true }
        return false
    }

    // MARK: - State Transitions

    /// Transition to loading state, preserving existing data if available
    mutating func startLoading() {
        if let existing = value {
            self = .refreshing(existing: existing)
        } else {
            self = .loading
        }
    }

    /// Transition to loading more (pagination)
    mutating func startLoadingMore() {
        if let existing = value {
            self = .loadingMore(existing: existing)
        }
    }

    /// Transition to loaded state
    mutating func finishLoading(_ value: T) {
        self = .loaded(value)
    }

    /// Transition to failed state
    mutating func finishWithError(_ error: AppError) {
        self = .failed(error)
    }

    /// Transition to failed state from any Error
    mutating func finishWithError(_ error: Error) {
        let appError = (error as? AppError) ?? .unknown(error.localizedDescription)
        self = .failed(appError)
    }

    /// Transition to retry state
    mutating func retry(attempt: Int) {
        if let previousError = error {
            self = .retrying(attempt: attempt, previousError: previousError)
        } else {
            self = .loading
        }
    }

    /// Reset to idle state
    mutating func reset() {
        self = .idle
    }

    // MARK: - Mapping

    /// Map the loaded value to a new type
    func map<U: Sendable>(_ transform: (T) -> U) -> LoadingState<U> {
        switch self {
        case .idle:
            .idle
        case .loading:
            .loading
        case let .loaded(v):
            .loaded(transform(v))
        case let .refreshing(existing: v):
            .refreshing(existing: transform(v))
        case let .loadingMore(existing: v):
            .loadingMore(existing: transform(v))
        case let .failed(e):
            .failed(e)
        case let .retrying(attempt, previousError):
            .retrying(attempt: attempt, previousError: previousError)
        }
    }
}

// MARK: - Equatable Conformance

extension LoadingState: Equatable where T: Equatable {
    static func == (lhs: LoadingState<T>, rhs: LoadingState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            true
        case (.loading, .loading):
            true
        case let (.loaded(l), .loaded(r)):
            l == r
        case let (.refreshing(l), .refreshing(r)):
            l == r
        case let (.loadingMore(l), .loadingMore(r)):
            l == r
        case let (.failed(l), .failed(r)):
            l.localizedDescription == r.localizedDescription
        case let (.retrying(la, le), .retrying(ra, re)):
            la == ra && le.localizedDescription == re.localizedDescription
        default:
            false
        }
    }
}

// MARK: - View Helpers

extension LoadingState {
    /// Whether to show a loading indicator (no data yet)
    var showLoadingIndicator: Bool {
        switch self {
        case .loading, .retrying:
            true
        default:
            false
        }
    }

    /// Whether to show a refresh indicator (has data, refreshing)
    var showRefreshIndicator: Bool {
        isRefreshing
    }

    /// Whether to show an empty state
    var showEmptyState: Bool {
        if case let .loaded(value) = self {
            if let array = value as? (any Collection) {
                return array.isEmpty
            }
        }
        return false
    }

    /// Whether to show error state
    var showError: Bool {
        if case .failed = self { return true }
        return false
    }

    /// Whether to show content
    var showContent: Bool {
        hasData
    }
}

// MARK: - Pagination State

/// Extended state for paginated data
struct PaginatedLoadingState<T: Sendable>: Sendable {
    var state: LoadingState<[T]>
    var hasMorePages: Bool
    var currentPage: Int
    var pageSize: Int

    init(pageSize: Int = 20) {
        self.state = .idle
        self.hasMorePages = true
        self.currentPage = 0
        self.pageSize = pageSize
    }

    var items: [T] { state.value ?? [] }
    var isLoading: Bool { state.isLoading }
    var isLoadingMore: Bool { state.isLoadingMore }
    var error: AppError? { state.error }

    mutating func startLoading() {
        currentPage = 0
        hasMorePages = true
        state.startLoading()
    }

    mutating func startLoadingMore() {
        guard hasMorePages, !state.isActive else { return }
        state.startLoadingMore()
    }

    mutating func appendPage(_ newItems: [T]) {
        let existingItems = items
        let allItems = existingItems + newItems
        state = .loaded(allItems)
        currentPage += 1
        hasMorePages = newItems.count >= pageSize
    }

    mutating func replacePage(_ newItems: [T]) {
        state = .loaded(newItems)
        currentPage = 1
        hasMorePages = newItems.count >= pageSize
    }

    mutating func fail(_ error: AppError) {
        state = .failed(error)
    }

    mutating func reset() {
        state = .idle
        hasMorePages = true
        currentPage = 0
    }
}
