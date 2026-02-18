//
//  SupabaseDataFetching.swift
//  Foodshare
//
//  Comprehensive Supabase data fetching utilities with:
//  - Automatic retry with exponential backoff
//  - Batch operations for efficient bulk updates
//  - Connection state monitoring
//  - Optimistic UI updates with rollback
//  - Enhanced error recovery
//



#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - Supabase Fetch Configuration

/// Configuration for Supabase data fetching operations
struct SupabaseFetchConfiguration: Sendable {
    /// Maximum number of retry attempts
    let maxRetries: Int

    /// Base delay for exponential backoff (in seconds)
    let baseDelay: TimeInterval

    /// Maximum delay cap for backoff (in seconds)
    let maxDelay: TimeInterval

    /// Jitter factor (0.0 - 1.0) to randomize delays
    let jitterFactor: Double

    /// Timeout for individual requests (in seconds)
    let requestTimeout: TimeInterval

    /// Default configuration for most operations
    static let `default` = SupabaseFetchConfiguration(
        maxRetries: 3,
        baseDelay: 1.0,
        maxDelay: 30.0,
        jitterFactor: 0.25,
        requestTimeout: 30.0,
    )

    /// Aggressive retry for critical operations
    static let aggressive = SupabaseFetchConfiguration(
        maxRetries: 5,
        baseDelay: 0.5,
        maxDelay: 60.0,
        jitterFactor: 0.3,
        requestTimeout: 60.0,
    )

    /// Single attempt for non-critical operations
    static let noRetry = SupabaseFetchConfiguration(
        maxRetries: 0,
        baseDelay: 0,
        maxDelay: 0,
        jitterFactor: 0,
        requestTimeout: 15.0,
    )

    /// Fast retry for interactive operations
    static let fast = SupabaseFetchConfiguration(
        maxRetries: 2,
        baseDelay: 0.3,
        maxDelay: 5.0,
        jitterFactor: 0.2,
        requestTimeout: 10.0,
    )
}

// MARK: - Supabase Retry Error

/// Errors specific to retry operations
enum SupabaseRetryError: Error, LocalizedError, Sendable {
    case maxRetriesExceeded(attempts: Int, lastError: Error)
    case nonRetryableError(Error)
    case timeout
    case cancelled

    var errorDescription: String? {
        switch self {
        case let .maxRetriesExceeded(attempts, lastError):
            "Failed after \(attempts) attempts: \(lastError.localizedDescription)"
        case let .nonRetryableError(error):
            "Non-retryable error: \(error.localizedDescription)"
        case .timeout:
            "Request timed out"
        case .cancelled:
            "Request was cancelled"
        }
    }
}

// MARK: - Retryable Operation Executor

/// Executes operations with automatic retry and exponential backoff
actor RetryableOperationExecutor {
    private let configuration: SupabaseFetchConfiguration
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "RetryableOperation")

    init(configuration: SupabaseFetchConfiguration = .default) {
        self.configuration = configuration
    }

    /// Execute an operation with automatic retry
    func execute<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?
        var attemptCount = 0

        while attemptCount <= configuration.maxRetries {
            do {
                // Check for cancellation
                try Task.checkCancellation()

                // Execute the operation
                let result = try await operation()

                // Log success on retry
                if attemptCount > 0 {
                    logger.info("✅ Operation succeeded on attempt \(attemptCount + 1)")
                }

                return result
            } catch {
                lastError = error
                attemptCount += 1

                // Check if error is retryable
                guard isRetryable(error) else {
                    throw SupabaseRetryError.nonRetryableError(error)
                }

                // Check if we've exhausted retries
                guard attemptCount <= configuration.maxRetries else {
                    break
                }

                // Calculate delay with exponential backoff and jitter
                let delay = calculateDelay(attempt: attemptCount)
                logger.warning("⚠️ Attempt \(attemptCount) failed, retrying in \(delay)s: \(error.localizedDescription)")

                // Wait before retry
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        throw SupabaseRetryError.maxRetriesExceeded(
            attempts: attemptCount,
            lastError: lastError ?? SupabaseRetryError.timeout,
        )
    }

    /// Execute an operation with timeout
    func executeWithTimeout<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await self.execute(operation)
            }

            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.configuration.requestTimeout * 1_000_000_000))
                throw SupabaseRetryError.timeout
            }

            // Return first completed (or throw first error)
            guard let result = try await group.next() else {
                throw SupabaseRetryError.timeout
            }

            // Cancel remaining tasks
            group.cancelAll()

            return result
        }
    }

    // MARK: - Private Helpers

    private func calculateDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: baseDelay * 2^(attempt-1)
        let exponentialDelay = configuration.baseDelay * pow(2.0, Double(attempt - 1))

        // Apply max delay cap
        let cappedDelay = min(exponentialDelay, configuration.maxDelay)

        // Apply jitter: delay * (1 + random(-jitter, +jitter))
        let jitterRange = cappedDelay * configuration.jitterFactor
        let jitter = Double.random(in: -jitterRange ... jitterRange)

        return max(0.0, cappedDelay + jitter)
    }

    private func isRetryable(_ error: Error) -> Bool {
        // Check for cancellation
        if error is CancellationError {
            return false
        }

        // Check for known non-retryable Supabase errors
        if let postgrestError = error as? PostgrestError {
            switch postgrestError.code {
            case "42501": // Permission denied
                return false
            case "23505": // Unique constraint violation
                return false
            case "23503": // Foreign key violation
                return false
            case "PGRST116": // Not found (single row expected)
                return false
            default:
                return true
            }
        }

        // Network errors are generally retryable
        let nsError = error as NSError
        let retryableCodes = [
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorTimedOut,
            NSURLErrorCannotConnectToHost,
            NSURLErrorDNSLookupFailed
        ]

        return retryableCodes.contains(nsError.code)
    }
}

// MARK: - Batch Operation Handler

/// Handles batch operations for efficient bulk database updates
actor BatchOperationHandler {
    private let client: SupabaseClient
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "BatchOperation")

    /// Maximum items per batch (Supabase recommends < 1000)
    private let maxBatchSize: Int

    /// Concurrent batch limit
    private let maxConcurrentBatches: Int

    init(
        client: SupabaseClient,
        maxBatchSize: Int = 500,
        maxConcurrentBatches: Int = 3,
    ) {
        self.client = client
        self.maxBatchSize = maxBatchSize
        self.maxConcurrentBatches = maxConcurrentBatches
    }

    // MARK: - Batch Insert

    /// Insert items in batches
    func batchInsert(
        table: String,
        items: [some Encodable],
        onProgress: (@Sendable (BatchProgress) -> Void)? = nil,
    ) async throws -> BatchResult {
        let batches = items.chunked(into: maxBatchSize)
        var successCount = 0
        var failedCount = 0
        var errors: [Error] = []

        logger.info("📦 Starting batch insert: \(items.count) items in \(batches.count) batches")

        for (index, batch) in batches.enumerated() {
            do {
                try await client
                    .from(table)
                    .insert(batch)
                    .execute()

                successCount += batch.count

                // Report progress
                onProgress?(BatchProgress(
                    completedBatches: index + 1,
                    totalBatches: batches.count,
                    processedItems: successCount + failedCount,
                    totalItems: items.count,
                ))

            } catch {
                failedCount += batch.count
                errors.append(error)
                logger.error("❌ Batch \(index + 1) failed: \(error.localizedDescription)")
            }
        }

        let result = BatchResult(
            successCount: successCount,
            failedCount: failedCount,
            errors: errors,
        )

        logger.info("✅ Batch insert complete: \(successCount) succeeded, \(failedCount) failed")
        return result
    }

    // MARK: - Batch Upsert

    /// Upsert items in batches (insert or update)
    func batchUpsert(
        table: String,
        items: [some Encodable],
        onConflict: String = "id",
        onProgress: (@Sendable (BatchProgress) -> Void)? = nil,
    ) async throws -> BatchResult {
        let batches = items.chunked(into: maxBatchSize)
        var successCount = 0
        var failedCount = 0
        var errors: [Error] = []

        logger.info("📦 Starting batch upsert: \(items.count) items in \(batches.count) batches")

        for (index, batch) in batches.enumerated() {
            do {
                try await client
                    .from(table)
                    .upsert(batch, onConflict: onConflict)
                    .execute()

                successCount += batch.count

                onProgress?(BatchProgress(
                    completedBatches: index + 1,
                    totalBatches: batches.count,
                    processedItems: successCount + failedCount,
                    totalItems: items.count,
                ))

            } catch {
                failedCount += batch.count
                errors.append(error)
                logger.error("❌ Batch \(index + 1) failed: \(error.localizedDescription)")
            }
        }

        let result = BatchResult(
            successCount: successCount,
            failedCount: failedCount,
            errors: errors,
        )

        logger.info("✅ Batch upsert complete: \(successCount) succeeded, \(failedCount) failed")
        return result
    }

    // MARK: - Batch Delete

    /// Delete items in batches by IDs
    func batchDelete(
        table: String,
        ids: [UUID],
        idColumn: String = "id",
        onProgress: (@Sendable (BatchProgress) -> Void)? = nil,
    ) async throws -> BatchResult {
        let batches = ids.chunked(into: maxBatchSize)
        var successCount = 0
        var failedCount = 0
        var errors: [Error] = []

        logger.info("📦 Starting batch delete: \(ids.count) items in \(batches.count) batches")

        for (index, batch) in batches.enumerated() {
            do {
                let idStrings = batch.map(\.uuidString)
                try await client
                    .from(table)
                    .delete()
                    .in(idColumn, values: idStrings)
                    .execute()

                successCount += batch.count

                onProgress?(BatchProgress(
                    completedBatches: index + 1,
                    totalBatches: batches.count,
                    processedItems: successCount + failedCount,
                    totalItems: ids.count,
                ))

            } catch {
                failedCount += batch.count
                errors.append(error)
                logger.error("❌ Batch \(index + 1) failed: \(error.localizedDescription)")
            }
        }

        let result = BatchResult(
            successCount: successCount,
            failedCount: failedCount,
            errors: errors,
        )

        logger.info("✅ Batch delete complete: \(successCount) succeeded, \(failedCount) failed")
        return result
    }

    // MARK: - Parallel Batch Processing

    /// Process batches in parallel with concurrency limit
    func parallelBatchProcess<T: Sendable, R: Sendable>(
        items: [T],
        process: @escaping @Sendable ([T]) async throws -> [R],
    ) async throws -> [R] {
        let batches = items.chunked(into: maxBatchSize)

        return try await withThrowingTaskGroup(of: [R].self) { group in
            var results: [R] = []
            var activeTasks = 0
            var batchIndex = 0

            // Start initial batch of tasks up to concurrency limit
            while activeTasks < maxConcurrentBatches, batchIndex < batches.count {
                let batch = batches[batchIndex]
                group.addTask {
                    try await process(batch)
                }
                activeTasks += 1
                batchIndex += 1
            }

            // Process results and add new tasks as others complete
            for try await batchResult in group {
                results.append(contentsOf: batchResult)
                activeTasks -= 1

                // Add next batch if available
                if batchIndex < batches.count {
                    let batch = batches[batchIndex]
                    group.addTask {
                        try await process(batch)
                    }
                    activeTasks += 1
                    batchIndex += 1
                }
            }

            return results
        }
    }
}

/// Progress information for batch operations
struct BatchProgress: Sendable {
    let completedBatches: Int
    let totalBatches: Int
    let processedItems: Int
    let totalItems: Int

    var percentComplete: Double {
        guard totalItems > 0 else { return 0 }
        return Double(processedItems) / Double(totalItems)
    }
}

/// Result of a batch operation
struct BatchResult: Sendable {
    let successCount: Int
    let failedCount: Int
    let errors: [Error]

    var isFullSuccess: Bool { failedCount == 0 }
    var isPartialSuccess: Bool { successCount > 0 && failedCount > 0 }
    var isFullFailure: Bool { successCount == 0 && failedCount > 0 }
}

// MARK: - Connection State Monitor

/// Monitors Supabase connection state and provides connectivity info
@MainActor
@Observable
final class SupabaseConnectionMonitor {
    /// Current connection state
    private(set) var connectionState: ConnectionState = .unknown

    /// Last successful connection timestamp
    private(set) var lastConnectedAt: Date?

    /// Number of consecutive failures
    private(set) var consecutiveFailures = 0

    /// Estimated connection quality
    var connectionQuality: ConnectionQuality {
        switch consecutiveFailures {
        case 0:
            .excellent
        case 1:
            .good
        case 2 ... 3:
            .fair
        default:
            .poor
        }
    }

    private let client: SupabaseClient
    private let networkMonitor: NetworkMonitor
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ConnectionMonitor")
    private var healthCheckTask: Task<Void, Never>?

    enum ConnectionState: String, Sendable {
        case connected
        case disconnected
        case connecting
        case unknown
    }

    enum ConnectionQuality: String, Sendable {
        case excellent
        case good
        case fair
        case poor
    }

    init(client: SupabaseClient, networkMonitor: NetworkMonitor = .shared) {
        self.client = client
        self.networkMonitor = networkMonitor
    }

    /// Start monitoring connection health
    func startMonitoring(interval: TimeInterval = 30) {
        stopMonitoring()

        healthCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.performHealthCheck()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }

        logger.info("🔍 Started connection monitoring with \(interval)s interval")
    }

    /// Stop monitoring
    func stopMonitoring() {
        healthCheckTask?.cancel()
        healthCheckTask = nil
    }

    /// Perform a health check
    func performHealthCheck() async {
        // Skip if network is offline
        guard !networkMonitor.isOffline else {
            connectionState = .disconnected
            return
        }

        connectionState = .connecting

        do {
            // Simple health check query
            _ = try await client
                .from("categories")
                .select("id")
                .limit(1)
                .execute()

            connectionState = .connected
            lastConnectedAt = Date()
            consecutiveFailures = 0

        } catch {
            self.consecutiveFailures += 1
            connectionState = .disconnected
            logger.warning("⚠️ Health check failed (\(self.consecutiveFailures) consecutive): \(error.localizedDescription)")
        }
    }

    /// Force an immediate health check
    func checkNow() async {
        await performHealthCheck()
    }
}

#if !SKIP
// MARK: - Optimistic Update Manager

/// Manages optimistic UI updates with automatic rollback on failure
@MainActor
final class SupabaseOptimisticUpdateManager<Item: Identifiable & Sendable> where Item.ID: Hashable {
    typealias ItemID = Item.ID
    typealias RollbackHandler = @Sendable (Item) -> Void
    typealias SuccessHandler = @Sendable (Item) -> Void
    typealias ErrorHandler = @Sendable (Error, Item) -> Void

    /// Pending optimistic updates awaiting server confirmation
    private var pendingUpdates: [ItemID: PendingUpdate] = [:]

    /// Handler called when rollback occurs
    var onRollback: RollbackHandler?

    /// Handler called when update is confirmed
    var onSuccess: SuccessHandler?

    /// Handler called when update fails
    var onError: ErrorHandler?

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "OptimisticUpdate")

    struct PendingUpdate {
        let optimisticItem: Item
        let originalItem: Item
        let task: Task<Item, Error>
        let startedAt: Date
    }

    /// Perform an optimistic update
    /// - Parameters:
    ///   - optimisticItem: The item with optimistic changes applied
    ///   - originalItem: The original item before changes (for rollback)
    ///   - serverOperation: The async operation to persist changes to server
    /// - Returns: The optimistic item immediately, server result eventually via handlers
    @discardableResult
    func performUpdate(
        optimisticItem: Item,
        originalItem: Item,
        serverOperation: @escaping @Sendable () async throws -> Item,
    ) -> Item {
        // Create confirmation task
        let confirmationTask = Task<Item, Error> { [weak self] in
            do {
                let confirmedItem = try await serverOperation()

                await MainActor.run {
                    self?.pendingUpdates.removeValue(forKey: optimisticItem.id)
                    self?.onSuccess?(confirmedItem)
                }

                return confirmedItem
            } catch {
                await MainActor.run {
                    self?.pendingUpdates.removeValue(forKey: optimisticItem.id)
                    self?.onRollback?(originalItem)
                    self?.onError?(error, originalItem)
                }

                throw error
            }
        }

        // Store pending update
        pendingUpdates[optimisticItem.id] = PendingUpdate(
            optimisticItem: optimisticItem,
            originalItem: originalItem,
            task: confirmationTask,
            startedAt: Date(),
        )

        logger.debug("📝 Optimistic update started for item: \(String(describing: optimisticItem.id))")

        return optimisticItem
    }

    /// Check if an item has a pending update
    func hasPendingUpdate(for id: ItemID) -> Bool {
        pendingUpdates[id] != nil
    }

    /// Cancel a pending update and rollback
    func cancelUpdate(for id: ItemID) {
        guard let pending = pendingUpdates[id] else { return }

        pending.task.cancel()
        pendingUpdates.removeValue(forKey: id)
        onRollback?(pending.originalItem)

        logger.debug("🔄 Cancelled and rolled back update for item: \(String(describing: id))")
    }

    /// Cancel all pending updates
    func cancelAllUpdates() {
        for (id, pending) in pendingUpdates {
            pending.task.cancel()
            onRollback?(pending.originalItem)
            logger.debug("🔄 Cancelled update for item: \(String(describing: id))")
        }
        pendingUpdates.removeAll()
    }

    /// Wait for a specific update to complete
    func waitForUpdate(id: ItemID) async throws -> Item? {
        guard let pending = pendingUpdates[id] else { return nil }
        return try await pending.task.value
    }

    /// Number of pending updates
    var pendingCount: Int { pendingUpdates.count }

    /// Get all pending item IDs
    var pendingItemIDs: [ItemID] { Array(pendingUpdates.keys) }
}
#endif

// MARK: - Array Extension for Chunking

extension Array {
    /// Split array into chunks of specified size
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: - Supabase Query Extensions

extension PostgrestFilterBuilder {
    /// Apply cursor-based pagination with direction support
    func cursorPaginate(
        cursor: String?,
        cursorColumn: String,
        direction: CursorDirection,
        limit: Int,
    ) -> PostgrestTransformBuilder {
        var query = self

        if let cursor {
            let comparison = direction == .backward ? "lt" : "gt"
            query = query.filter(cursorColumn, operator: comparison, value: cursor)
        }

        let ascending = direction == .forward

        return query
            .order(cursorColumn, ascending: ascending)
            .limit(limit)
    }
}

// MARK: - Supabase Response Decoder

/// Centralized decoder configuration for Supabase responses
enum SupabaseResponseDecoder {
    /// Standard decoder with ISO8601 dates and snake_case conversion
    static let standard: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    /// Decoder that preserves snake_case keys (for manual CodingKeys)
    static let preservingKeys: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Decode with automatic error context
    static func decode<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        using decoder: JSONDecoder = standard,
    ) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch let DecodingError.keyNotFound(key, context) {
            throw AppError
                .decodingError(
                    "Missing key '\(key.stringValue)' at \(context.codingPath.map(\.stringValue).joined(separator: "."))",
                )
        } catch let DecodingError.typeMismatch(type, context) {
            throw AppError
                .decodingError(
                    "Type mismatch for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))",
                )
        } catch let DecodingError.valueNotFound(type, context) {
            throw AppError
                .decodingError(
                    "Value not found for \(type) at \(context.codingPath.map(\.stringValue).joined(separator: "."))",
                )
        } catch {
            throw AppError.decodingError(error.localizedDescription)
        }
    }
}


#endif
