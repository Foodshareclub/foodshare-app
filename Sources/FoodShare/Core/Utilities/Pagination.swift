import Foundation

// MARK: - Cursor Direction

/// Direction for cursor-based pagination
enum CursorDirection: String, Sendable, Codable {
    case forward // Load newer items
    case backward // Load older items
}

// MARK: - Cursor Pagination Parameters

/// Parameters for cursor-based pagination (more efficient than offset)
/// Used for infinite scroll and real-time data where items may be added/removed
struct CursorPaginationParams: Sendable, Equatable {
    let limit: Int
    let cursor: String?
    let cursorColumn: String
    let direction: CursorDirection

    init(
        limit: Int = 20,
        cursor: String? = nil,
        cursorColumn: String = "created_at",
        direction: CursorDirection = .backward,
    ) {
        self.limit = limit
        self.cursor = cursor
        self.cursorColumn = cursorColumn
        self.direction = direction
    }

    /// Create params for loading next page
    func next(after cursor: String) -> CursorPaginationParams {
        CursorPaginationParams(
            limit: limit,
            cursor: cursor,
            cursorColumn: cursorColumn,
            direction: direction,
        )
    }

    /// Create params for loading previous page (for bidirectional scroll)
    func previous(before cursor: String) -> CursorPaginationParams {
        CursorPaginationParams(
            limit: limit,
            cursor: cursor,
            cursorColumn: cursorColumn,
            direction: direction == .forward ? .backward : .forward,
        )
    }

    static let `default` = CursorPaginationParams()
}

// MARK: - Cursor Pagination State

/// Cursor-based pagination state manager for efficient infinite scroll
/// More efficient than offset pagination for large datasets
@Observable
final class CursorPaginationState<T: Identifiable & Sendable>: @unchecked Sendable {
    // MARK: - Cursor Extraction Protocol

    typealias CursorExtractor = @Sendable (T) -> String

    // MARK: - Properties

    private(set) var items: [T] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true
    private(set) var hasPreviousPages = false
    private(set) var error: Error?

    private var nextCursor: String?
    private var previousCursor: String?
    private let extractCursor: CursorExtractor
    let pageSize: Int
    let cursorColumn: String

    // MARK: - Computed Properties

    var isEmpty: Bool { items.isEmpty && !isLoading }
    var canLoadMore: Bool { hasMorePages && !isLoadingMore && !isLoading }
    var canLoadPrevious: Bool { hasPreviousPages && !isLoadingMore && !isLoading }
    var totalCount: Int { items.count }

    // MARK: - Initialization

    init(
        pageSize: Int = 20,
        cursorColumn: String = "created_at",
        extractCursor: @escaping CursorExtractor,
    ) {
        self.pageSize = pageSize
        self.cursorColumn = cursorColumn
        self.extractCursor = extractCursor
    }

    // MARK: - Actions

    /// Reset pagination state
    func reset() {
        items = []
        nextCursor = nil
        previousCursor = nil
        hasMorePages = true
        hasPreviousPages = false
        error = nil
    }

    /// Load initial page using cursor-based pagination
    @MainActor
    func loadInitial(
        using loader: @escaping (CursorPaginationParams) async throws -> [T],
    ) async {
        guard !isLoading else { return }

        isLoading = true
        error = nil

        defer { isLoading = false }

        do {
            let params = CursorPaginationParams(
                limit: pageSize,
                cursor: nil,
                cursorColumn: cursorColumn,
                direction: .backward,
            )
            let newItems = try await loader(params)
            items = newItems
            hasMorePages = newItems.count >= pageSize

            // Store cursor from last item for next page
            if let lastItem = newItems.last {
                nextCursor = extractCursor(lastItem)
            }
            // Store cursor from first item for previous page
            if let firstItem = newItems.first {
                previousCursor = extractCursor(firstItem)
            }
        } catch {
            self.error = error
        }
    }

    /// Load next page (older items) using cursor
    @MainActor
    func loadMore(
        using loader: @escaping (CursorPaginationParams) async throws -> [T],
    ) async {
        guard canLoadMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let params = CursorPaginationParams(
                limit: pageSize,
                cursor: nextCursor,
                cursorColumn: cursorColumn,
                direction: .backward,
            )
            let newItems = try await loader(params)

            items.append(contentsOf: newItems)
            hasMorePages = newItems.count >= pageSize

            if let lastItem = newItems.last {
                nextCursor = extractCursor(lastItem)
            }
        } catch {
            // Silently fail for pagination
        }
    }

    /// Load previous page (newer items) using cursor - for bidirectional scroll
    @MainActor
    func loadPrevious(
        using loader: @escaping (CursorPaginationParams) async throws -> [T],
    ) async {
        guard canLoadPrevious else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let params = CursorPaginationParams(
                limit: pageSize,
                cursor: previousCursor,
                cursorColumn: cursorColumn,
                direction: .forward,
            )
            let newItems = try await loader(params)

            items.insert(contentsOf: newItems, at: 0)
            hasPreviousPages = newItems.count >= pageSize

            if let firstItem = newItems.first {
                previousCursor = extractCursor(firstItem)
            }
        } catch {
            // Silently fail for pagination
        }
    }

    /// Refresh (reload from beginning)
    @MainActor
    func refresh(
        using loader: @escaping (CursorPaginationParams) async throws -> [T],
    ) async {
        reset()
        await loadInitial(using: loader)
    }

    /// Check if item is last (for triggering load more)
    func isLastItem(_ item: T) -> Bool {
        guard let lastItem = items.last else { return false }
        return lastItem.id == item.id
    }

    /// Check if item is first (for triggering load previous)
    func isFirstItem(_ item: T) -> Bool {
        guard let firstItem = items.first else { return false }
        return firstItem.id == item.id
    }

    /// Prepend item (for real-time additions)
    @MainActor
    func prepend(_ item: T) {
        items.insert(item, at: 0)
        previousCursor = extractCursor(item)
    }

    /// Append item (for real-time additions at end)
    @MainActor
    func append(_ item: T) {
        items.append(item)
        nextCursor = extractCursor(item)
    }

    /// Remove item
    @MainActor
    func remove(where predicate: (T) -> Bool) {
        items.removeAll(where: predicate)
    }

    /// Update item
    @MainActor
    func update(_ item: T) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
}

// MARK: - Legacy Offset Pagination (kept for backward compatibility)

/// Generic pagination state manager (offset-based)
/// @deprecated Use CursorPaginationState for better performance with large datasets
@Observable
final class PaginationState<T: Identifiable & Sendable>: @unchecked Sendable {
    // MARK: - Properties

    private(set) var items: [T] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true
    private(set) var error: Error?

    private var currentPage = 0
    let pageSize: Int

    // MARK: - Computed Properties

    var isEmpty: Bool {
        items.isEmpty && !isLoading
    }

    var canLoadMore: Bool {
        hasMorePages && !isLoadingMore && !isLoading
    }

    var totalCount: Int {
        items.count
    }

    // MARK: - Initialization

    init(pageSize: Int = 20) {
        self.pageSize = pageSize
    }

    // MARK: - Actions

    /// Reset pagination state
    func reset() {
        items = []
        currentPage = 0
        hasMorePages = true
        error = nil
    }

    /// Load initial page
    @MainActor
    func loadInitial(
        using loader: @escaping (Int, Int) async throws -> [T],
    ) async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        currentPage = 0

        defer { isLoading = false }

        do {
            let newItems = try await loader(pageSize, 0)
            items = newItems
            hasMorePages = newItems.count >= pageSize
        } catch {
            self.error = error
        }
    }

    /// Load next page
    @MainActor
    func loadMore(
        using loader: @escaping (Int, Int) async throws -> [T],
    ) async {
        guard canLoadMore else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let nextPage = currentPage + 1
            let offset = nextPage * pageSize
            let newItems = try await loader(pageSize, offset)

            items.append(contentsOf: newItems)
            currentPage = nextPage
            hasMorePages = newItems.count >= pageSize
        } catch {
            // Silently fail for pagination
        }
    }

    /// Refresh (reload from beginning)
    @MainActor
    func refresh(
        using loader: @escaping (Int, Int) async throws -> [T],
    ) async {
        reset()
        await loadInitial(using: loader)
    }

    /// Check if item is last (for triggering load more)
    func isLastItem(_ item: T) -> Bool {
        guard let lastItem = items.last else { return false }
        return lastItem.id == item.id
    }

    /// Prepend item (for real-time additions)
    @MainActor
    func prepend(_ item: T) {
        items.insert(item, at: 0)
    }

    /// Remove item
    @MainActor
    func remove(where predicate: (T) -> Bool) {
        items.removeAll(where: predicate)
    }

    /// Update item
    @MainActor
    func update(_ item: T) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
}

// MARK: - Paginated Response

/// Generic paginated response from API
struct PaginatedResponse<T: Codable>: Codable {
    let items: [T]
    let totalCount: Int
    let page: Int
    let pageSize: Int
    let hasMore: Bool

    var nextPage: Int? {
        hasMore ? page + 1 : nil
    }
}

// MARK: - Pagination Parameters

struct PaginationParams: Sendable {
    let limit: Int
    let offset: Int

    init(page: Int, pageSize: Int) {
        limit = pageSize
        offset = page * pageSize
    }

    init(limit: Int, offset: Int) {
        self.limit = limit
        self.offset = offset
    }

    static let `default` = PaginationParams(page: 0, pageSize: 20)
}

// MARK: - Infinite Scroll Modifier

import SwiftUI

struct InfiniteScrollModifier: ViewModifier {
    let isLoading: Bool
    let hasMore: Bool
    let loadMore: () async -> Void

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isLoading {
                    ProgressView()
                        .padding()
                }
            }
    }
}

extension View {
    func infiniteScroll(
        isLoading: Bool,
        hasMore: Bool,
        loadMore: @escaping () async -> Void,
    ) -> some View {
        modifier(InfiniteScrollModifier(
            isLoading: isLoading,
            hasMore: hasMore,
            loadMore: loadMore,
        ))
    }
}
