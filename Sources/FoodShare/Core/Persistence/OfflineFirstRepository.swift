//
//  OfflineFirstRepository.swift
//  Foodshare
//
//  Protocol for offline-first data access pattern
//

#if !SKIP
import Foundation

// MARK: - Offline First Repository Protocol

/// Protocol for repositories that support offline-first data access
/// Implementations should fetch from cache first, then sync with remote
protocol OfflineFirstRepository {
    associatedtype LocalType
    associatedtype RemoteType

    /// Fetch data from local cache
    func fetchFromCache() async throws -> [LocalType]

    /// Fetch data from remote source
    func fetchFromRemote() async throws -> [RemoteType]

    /// Sync remote data to local cache
    func syncToCache(_ items: [RemoteType]) async throws

    /// Get pending changes that haven't been synced
    func pendingChanges() async throws -> [LocalType]

    /// Sync pending changes to remote
    func syncPendingChanges() async throws
}

// MARK: - Sync Status

/// Status of an item's sync state
enum SyncStatus: String, Sendable {
    case synced
    case pending
    case failed
    case conflict
}

// MARK: - Offline Data Result

/// Result type for offline-first data fetching
enum OfflineDataResult<T: Sendable>: Sendable {
    /// Data is fresh from remote
    case fresh([T])

    /// Data is from cache (offline or stale)
    case cached([T], lastSyncedAt: Date?)

    /// No data available (neither cache nor remote)
    case empty

    var items: [T] {
        switch self {
        case let .fresh(items), let .cached(items, _):
            items
        case .empty:
            []
        }
    }

    var isCached: Bool {
        if case .cached = self { return true }
        return false
    }
}

// MARK: - Offline Cache Policy

/// Policy for offline-first cache behavior
enum OfflineCachePolicy: Sendable {
    /// Always fetch from remote first
    case remoteFirst

    /// Always use cache, fetch remote in background
    case cacheFirst

    /// Use cache only if remote fails
    case cacheFallback

    /// Only use cache, never fetch remote
    case cacheOnly

    /// Never use cache, always remote
    case remoteOnly
}

// MARK: - Sync Error

/// Errors that can occur during sync operations
enum SyncError: Error, LocalizedError, Sendable {
    case networkUnavailable
    case cacheCorrupted
    case remoteFailed(underlying: Error)
    case conflictDetected(localVersion: Date, remoteVersion: Date)
    case quotaExceeded

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            "Network connection unavailable"
        case .cacheCorrupted:
            "Local cache is corrupted"
        case let .remoteFailed(error):
            "Remote sync failed: \(error.localizedDescription)"
        case .conflictDetected:
            "Sync conflict detected between local and remote data"
        case .quotaExceeded:
            "Storage quota exceeded"
        }
    }
}

// MARK: - Cache Configuration

/// Configuration for cache behavior
struct CacheConfiguration: Sendable {
    /// Maximum age of cached data before considered stale (in seconds)
    let maxAge: TimeInterval

    /// Maximum number of items to cache
    let maxItems: Int

    /// Whether to automatically sync on app launch
    let syncOnLaunch: Bool

    /// Whether to sync in background
    let backgroundSync: Bool

    static let `default` = CacheConfiguration(
        maxAge: 3600, // 1 hour
        maxItems: 1000,
        syncOnLaunch: true,
        backgroundSync: true,
    )

    static let aggressive = CacheConfiguration(
        maxAge: 300, // 5 minutes
        maxItems: 500,
        syncOnLaunch: true,
        backgroundSync: true,
    )

    static let conservative = CacheConfiguration(
        maxAge: 86400, // 24 hours
        maxItems: 2000,
        syncOnLaunch: false,
        backgroundSync: false,
    )
}

// MARK: - Optimistic Update Result

/// Result type for optimistic updates
struct OptimisticUpdateResult<T: Sendable>: Sendable {
    let optimisticItem: T
    let confirmationTask: Task<T, Error>

    /// Wait for server confirmation
    func confirm() async throws -> T {
        try await confirmationTask.value
    }
}

// MARK: - Offline First Data Source

/// A data source that implements offline-first pattern
@MainActor
final class OfflineFirstDataSource<Local, Remote>where Local: Sendable, Remote: Sendable {
    private let fetchLocal: @Sendable () async throws -> [Local]
    private let fetchRemote: @Sendable () async throws -> [Remote]
    private let saveToCache: @Sendable ([Remote]) async throws -> Void
    private let configuration: CacheConfiguration

    /// Track pending optimistic updates
    private var pendingOptimisticUpdates: [UUID: any Sendable] = [:]

    /// Last successful sync timestamp
    private(set) var lastSyncTimestamp: Date?

    /// Whether a background sync is in progress
    private(set) var isSyncing = false

    init(
        configuration: CacheConfiguration = .default,
        fetchLocal: @escaping @Sendable () async throws -> [Local],
        fetchRemote: @escaping @Sendable () async throws -> [Remote],
        saveToCache: @escaping @Sendable ([Remote]) async throws -> Void,
    ) {
        self.configuration = configuration
        self.fetchLocal = fetchLocal
        self.fetchRemote = fetchRemote
        self.saveToCache = saveToCache
    }

    /// Fetch data using the specified cache policy
    func fetch(policy: OfflineCachePolicy) async throws -> OfflineDataResult<Local> {
        switch policy {
        case .remoteFirst:
            try await fetchRemoteFirst()
        case .cacheFirst:
            try await fetchCacheFirst()
        case .cacheFallback:
            try await fetchWithFallback()
        case .cacheOnly:
            try await fetchCacheOnly()
        case .remoteOnly:
            try await fetchRemoteOnly()
        }
    }

    private func fetchRemoteFirst() async throws -> OfflineDataResult<Local> {
        do {
            let remoteData = try await fetchRemote()
            try await saveToCache(remoteData)
            let localData = try await fetchLocal()
            return .fresh(localData)
        } catch {
            // Fallback to cache on remote failure
            let cachedData = try await fetchLocal()
            if cachedData.isEmpty {
                throw error
            }
            return .cached(cachedData, lastSyncedAt: nil)
        }
    }

    private func fetchCacheFirst() async throws -> OfflineDataResult<Local> {
        let cachedData = try await fetchLocal()

        // Start background sync if cache isn't empty
        if !cachedData.isEmpty {
            Task.detached { [fetchRemote, saveToCache] in
                do {
                    let remoteData = try await fetchRemote()
                    try await saveToCache(remoteData)
                } catch {
                    // Silently fail background sync
                }
            }
            return .cached(cachedData, lastSyncedAt: Date())
        }

        // Cache empty, must fetch from remote
        let remoteData = try await fetchRemote()
        try await saveToCache(remoteData)
        let freshData = try await fetchLocal()
        return .fresh(freshData)
    }

    private func fetchWithFallback() async throws -> OfflineDataResult<Local> {
        do {
            let remoteData = try await fetchRemote()
            try await saveToCache(remoteData)
            let localData = try await fetchLocal()
            return .fresh(localData)
        } catch {
            let cachedData = try await fetchLocal()
            return cachedData.isEmpty ? .empty : .cached(cachedData, lastSyncedAt: nil)
        }
    }

    private func fetchCacheOnly() async throws -> OfflineDataResult<Local> {
        let cachedData = try await fetchLocal()
        return cachedData.isEmpty ? .empty : .cached(cachedData, lastSyncedAt: nil)
    }

    private func fetchRemoteOnly() async throws -> OfflineDataResult<Local> {
        let remoteData = try await fetchRemote()
        try await saveToCache(remoteData)
        let localData = try await fetchLocal()
        return .fresh(localData)
    }

    // MARK: - Background Sync

    /// Perform a background sync without blocking the UI
    func backgroundSync() {
        guard !isSyncing else { return }

        Task.detached(priority: .utility) { [weak self, fetchRemote, saveToCache] in
            await MainActor.run { [weak self] in
                self?.isSyncing = true
            }

            defer {
                Task { @MainActor [weak self] in
                    self?.isSyncing = false
                }
            }

            do {
                let remoteData = try await fetchRemote()
                try await saveToCache(remoteData)

                await MainActor.run { [weak self] in
                    self?.lastSyncTimestamp = Date()
                }
            } catch {
                // Silently fail background sync, log error
                await AppLogger.shared.warning("Background sync failed: \(error.localizedDescription)")
            }
        }
    }

    /// Check if cache is stale based on configuration
    var isCacheStale: Bool {
        guard let lastSync = lastSyncTimestamp else { return true }
        return Date().timeIntervalSince(lastSync) > configuration.maxAge
    }
}

// MARK: - Batch Sync Operations

/// Utility for performing batch sync operations efficiently
actor BatchSyncCoordinator {
    private var pendingOperations: [UUID: @Sendable () async throws -> Void] = [:]
    private var isProcessing = false

    /// Add an operation to the batch queue
    func enqueue(id: UUID, operation: @escaping @Sendable () async throws -> Void) {
        pendingOperations[id] = operation
    }

    /// Process all pending operations
    func processBatch() async {
        guard !isProcessing, !pendingOperations.isEmpty else { return }

        isProcessing = true
        defer { isProcessing = false }

        let operations = pendingOperations
        pendingOperations.removeAll()

        // Process operations sequentially to avoid data race issues
        for (_, operation) in operations {
            try? await operation()
        }
    }

    /// Number of pending operations
    var pendingCount: Int {
        pendingOperations.count
    }
}

// MARK: - Optimistic Update Handler

/// Handles optimistic UI updates with rollback support
@MainActor
final class OptimisticUpdateHandler<T: Identifiable & Sendable> {
    typealias UpdateCallback = (T) -> Void

    private var pendingUpdates: [T.ID: T] = [:]
    private var rollbackValues: [T.ID: T] = [:]
    private let onUpdate: UpdateCallback

    init(onUpdate: @escaping UpdateCallback) {
        self.onUpdate = onUpdate
    }

    /// Perform an optimistic update with automatic rollback on failure
    func performOptimisticUpdate(
        item: T,
        originalValue: T,
        serverOperation: @escaping @Sendable () async throws -> T,
    ) async -> OptimisticUpdateResult<T> {
        // Store rollback value
        rollbackValues[item.id] = originalValue
        pendingUpdates[item.id] = item

        // Immediately update UI
        onUpdate(item)

        // Create background task for server confirmation
        let confirmationTask = Task<T, Error> { [weak self] in
            do {
                let confirmedItem = try await serverOperation()

                await MainActor.run {
                    self?.pendingUpdates.removeValue(forKey: item.id)
                    self?.rollbackValues.removeValue(forKey: item.id)
                    self?.onUpdate(confirmedItem)
                }

                return confirmedItem
            } catch {
                // Rollback on failure
                await MainActor.run {
                    if let originalValue = self?.rollbackValues[item.id] {
                        self?.onUpdate(originalValue)
                    }
                    self?.pendingUpdates.removeValue(forKey: item.id)
                    self?.rollbackValues.removeValue(forKey: item.id)
                }

                throw error
            }
        }

        return OptimisticUpdateResult(
            optimisticItem: item,
            confirmationTask: confirmationTask,
        )
    }

    /// Check if an item has a pending update
    func hasPendingUpdate(for id: T.ID) -> Bool {
        pendingUpdates[id] != nil
    }

    /// Cancel a pending update and rollback
    func cancelUpdate(for id: T.ID) {
        if let originalValue = rollbackValues[id] {
            onUpdate(originalValue)
        }
        pendingUpdates.removeValue(forKey: id)
        rollbackValues.removeValue(forKey: id)
    }

    /// Number of pending updates
    var pendingCount: Int {
        pendingUpdates.count
    }
}

// MARK: - Sync Queue

/// Priority-based sync queue for managing sync operations
actor SyncQueue {
    enum Priority: Int, Comparable {
        case low = 0
        case normal = 1
        case high = 2
        case critical = 3

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    struct QueuedOperation: Identifiable {
        let id: UUID
        let priority: Priority
        let operation: @Sendable () async throws -> Void
        let enqueuedAt: Date
    }

    private var queue: [QueuedOperation] = []
    private var isProcessing = false

    /// Add an operation to the queue
    func enqueue(
        id: UUID = UUID(),
        priority: Priority = .normal,
        operation: @escaping @Sendable () async throws -> Void,
    ) {
        let op = QueuedOperation(
            id: id,
            priority: priority,
            operation: operation,
            enqueuedAt: Date(),
        )

        // Insert maintaining priority order (highest first)
        if let insertIndex = queue.firstIndex(where: { $0.priority < priority }) {
            queue.insert(op, at: insertIndex)
        } else {
            queue.append(op)
        }
    }

    /// Process the next operation in the queue
    func processNext() async throws {
        guard !isProcessing, !queue.isEmpty else { return }

        isProcessing = true
        defer { isProcessing = false }

        let operation = queue.removeFirst()
        try await operation.operation()
    }

    /// Process all operations in the queue
    func processAll() async {
        while !queue.isEmpty {
            try? await processNext()
        }
    }

    /// Number of queued operations
    var count: Int {
        queue.count
    }

    /// Clear all pending operations
    func clear() {
        queue.removeAll()
    }
}
#endif
