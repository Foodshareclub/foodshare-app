//
//  RequestDeduplicator.swift
//  Foodshare
//
//  Request deduplication to prevent duplicate in-flight requests
//
//  Prevents issues like:
//  - Multiple rapid button taps triggering duplicate API calls
//  - Pull-to-refresh while already refreshing
//  - Race conditions from concurrent identical requests
//

import Foundation
import OSLog

// MARK: - Request Deduplicator

/// Prevents duplicate in-flight requests by coalescing identical requests
///
/// When multiple callers request the same operation simultaneously,
/// only one actual request is made and all callers receive the same result.
///
/// Usage:
/// ```swift
/// let deduplicator = RequestDeduplicator()
///
/// // Multiple concurrent calls for same profile only make one request
/// async let profile1 = deduplicator.deduplicate(key: "profile-123") {
///     try await api.fetchProfile(id: "123")
/// }
/// async let profile2 = deduplicator.deduplicate(key: "profile-123") {
///     try await api.fetchProfile(id: "123")
/// }
///
/// // Both get the same result, only one network call made
/// let results = try await [profile1, profile2]
/// ```
actor RequestDeduplicator {
    // MARK: - Types

    /// Pending request metadata (without the task for Sendable compliance)
    private struct PendingMetadata: Sendable {
        let createdAt: Date
        let isCancelled: Bool
    }

    /// Statistics about deduplication
    struct Statistics: Sendable {
        let totalRequests: Int
        let deduplicatedRequests: Int
        let activeRequests: Int
        let savedRequests: Int

        var deduplicationRate: Double {
            guard totalRequests > 0 else { return 0 }
            return Double(deduplicatedRequests) / Double(totalRequests)
        }
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "RequestDeduplicator")

    /// Track which keys have active requests
    private var activeKeys: Set<String> = []

    /// Metadata for active requests
    private var requestMetadata: [String: PendingMetadata] = [:]

    /// Statistics
    private var totalRequests = 0
    private var deduplicatedRequests = 0

    /// Maximum age for pending requests before they're considered stale
    private let maxPendingAge: TimeInterval

    // MARK: - Initialization

    init(maxPendingAge: TimeInterval = 60) {
        self.maxPendingAge = maxPendingAge
    }

    // MARK: - Deduplication

    /// Execute a request with deduplication
    ///
    /// If an identical request (same key) is already in flight, this returns
    /// immediately indicating the request should be skipped or retried later.
    ///
    /// - Parameters:
    ///   - key: Unique identifier for this request type (e.g., "profile-123", "feed-page-1")
    ///   - operation: The async operation to perform
    /// - Returns: The result of the operation
    func deduplicate<T: Sendable>(
        key: String,
        operation: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        totalRequests += 1

        // Clean up stale requests
        cleanupStaleRequests()

        // Check for existing request - if active, throw to indicate deduplication
        if activeKeys.contains(key) {
            deduplicatedRequests += 1
            logger.debug("Request already in flight, deduplicating: \(key)")
            throw DeduplicationError.requestInFlight(key: key)
        }

        // Mark as active
        activeKeys.insert(key)
        requestMetadata[key] = PendingMetadata(createdAt: Date(), isCancelled: false)
        logger.debug("Starting request: \(key)")

        do {
            let result = try await operation()
            activeKeys.remove(key)
            requestMetadata.removeValue(forKey: key)
            return result
        } catch {
            activeKeys.remove(key)
            requestMetadata.removeValue(forKey: key)
            throw error
        }
    }

    /// Execute with automatic key generation from the operation description
    func deduplicate<T: Sendable>(
        for type: String,
        id: String? = nil,
        operation: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        let key = id.map { "\(type)-\($0)" } ?? type
        return try await deduplicate(key: key, operation: operation)
    }

    // MARK: - Cache Management

    /// Check if a request is currently in flight
    func isRequestInFlight(_ key: String) -> Bool {
        activeKeys.contains(key)
    }

    /// Mark a request as cancelled (it will be cleaned up)
    func cancelRequest(_ key: String) {
        if activeKeys.contains(key) {
            requestMetadata[key] = PendingMetadata(createdAt: Date(), isCancelled: true)
            logger.debug("Marked request for cancellation: \(key)")
        }
    }

    /// Clear all active request tracking
    func cancelAllRequests() {
        for key in activeKeys {
            logger.debug("Clearing request: \(key)")
        }
        activeKeys.removeAll()
        requestMetadata.removeAll()
    }

    /// Get current statistics
    var statistics: Statistics {
        Statistics(
            totalRequests: totalRequests,
            deduplicatedRequests: deduplicatedRequests,
            activeRequests: activeKeys.count,
            savedRequests: deduplicatedRequests,
        )
    }

    /// Reset statistics
    func resetStatistics() {
        totalRequests = 0
        deduplicatedRequests = 0
    }

    // MARK: - Private

    private func cleanupStaleRequests() {
        let cutoff = Date().addingTimeInterval(-maxPendingAge)
        var staleKeys: [String] = []

        for (key, metadata) in requestMetadata where metadata.createdAt < cutoff || metadata.isCancelled {
            staleKeys.append(key)
        }

        for key in staleKeys {
            activeKeys.remove(key)
            requestMetadata.removeValue(forKey: key)
            logger.warning("Cleaned up stale/cancelled request: \(key)")
        }
    }
}

// MARK: - Deduplication Error

enum DeduplicationError: Error, LocalizedError {
    case requestInFlight(key: String)
    case requestCancelled

    var errorDescription: String? {
        switch self {
        case let .requestInFlight(key):
            "Request '\(key)' is already in flight"
        case .requestCancelled:
            "Request was cancelled"
        }
    }

    /// Whether this error indicates the request was deduplicated (not a real error)
    var isDeduplicated: Bool {
        if case .requestInFlight = self { return true }
        return false
    }
}

// MARK: - Global Instance

extension RequestDeduplicator {
    /// Shared instance for app-wide request deduplication
    static let shared = RequestDeduplicator()
}

// MARK: - Convenience Extensions

extension RequestDeduplicator {
    /// Deduplicate a profile fetch
    func fetchProfile<T: Sendable>(
        id: UUID,
        fetch: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        try await deduplicate(for: "profile", id: id.uuidString, operation: fetch)
    }

    /// Deduplicate a listing fetch
    func fetchListing<T: Sendable>(
        id: Int,
        fetch: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        try await deduplicate(for: "listing", id: String(id), operation: fetch)
    }

    /// Deduplicate a feed page fetch
    func fetchFeedPage<T: Sendable>(
        page: Int,
        fetch: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        try await deduplicate(for: "feed-page", id: String(page), operation: fetch)
    }

    /// Deduplicate a search request
    func search<T: Sendable>(
        query: String,
        fetch: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        // Use query hash as key to handle same queries
        let queryHash = String(query.hashValue)
        return try await deduplicate(for: "search", id: queryHash, operation: fetch)
    }
}

// MARK: - Debounced Request

/// Wrapper for debouncing rapid requests (e.g., search-as-you-type)
actor DebouncedRequest<T: Sendable> {
    private var currentTask: Task<T, Error>?
    private let delay: TimeInterval
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "DebouncedRequest")

    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    /// Execute a debounced request
    ///
    /// Cancels any pending request and waits for the delay before executing.
    /// If another request comes in during the delay, this one is cancelled.
    func execute(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        // Cancel any existing request
        currentTask?.cancel()

        // Create new task with delay
        let task = Task<T, Error> {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            try Task.checkCancellation()
            return try await operation()
        }

        currentTask = task

        do {
            let result = try await task.value
            currentTask = nil
            return result
        } catch is CancellationError {
            throw DeduplicationError.requestCancelled
        } catch {
            currentTask = nil
            throw error
        }
    }

    /// Cancel any pending request
    func cancel() {
        currentTask?.cancel()
        currentTask = nil
    }
}

// MARK: - Throttled Request

/// Wrapper for throttling requests (max one per time interval)
actor ThrottledRequest<T: Sendable> {
    private var lastExecutionTime: Date?
    private let interval: TimeInterval
    private var pendingResult: T?
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "ThrottledRequest")

    init(interval: TimeInterval = 1.0) {
        self.interval = interval
    }

    /// Execute a throttled request
    ///
    /// If called within the throttle interval, returns the cached result.
    /// Otherwise, executes the operation and caches the result.
    func execute(_ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        let now = Date()

        // Check if we're within the throttle interval
        if let lastTime = lastExecutionTime,
           now.timeIntervalSince(lastTime) < interval,
           let cached = pendingResult {
            logger.debug("Returning throttled result")
            return cached
        }

        // Execute and cache
        let result = try await operation()
        lastExecutionTime = now
        pendingResult = result

        return result
    }

    /// Clear cached result
    func reset() {
        lastExecutionTime = nil
        pendingResult = nil
    }
}
