//
//  CacheStrategy.swift
//  Foodshare
//
//  Stale-while-revalidate caching strategy with TTL-based expiration,
//  memory pressure handling, and comprehensive statistics tracking.
//
//  This implementation provides:
//  - TTL-based cache with configurable durations
//  - Stale-while-revalidate pattern (return stale data, fetch fresh in background)
//  - Cache invalidation by key, prefix, or all entries
//  - Memory pressure handling with automatic eviction
//  - Statistics tracking (hits, misses, evictions, stale hits)
//
//  Usage:
//  ```swift
//  // Create a cache for any Codable type
//  let cache = GenericCache<String, MyModel>(maxSize: 100, defaultTTL: 300)
//
//  // Fetch with stale-while-revalidate
//  let data = try await cache.fetchWithStaleWhileRevalidate(key: "my-key") {
//      try await networkService.fetch()
//  }
//
//  // Use specialized cache managers
//  let profile = try await CacheManager.shared.userProfiles.fetchWithStaleWhileRevalidate {
//      try await profileService.fetch(userId: id)
//  }
//  ```
//

import Foundation
#if !SKIP
import UIKit
#endif

// MARK: - Cache Entry

/// Represents a single cache entry with value, metadata, and TTL
public struct CacheEntry<T: Sendable>: Sendable {
    /// The cached value
    public let value: T

    /// When the entry was created
    public let createdAt: Date

    /// Time-to-live in seconds
    public let ttl: TimeInterval

    /// When the entry expires
    public var expiresAt: Date {
        createdAt.addingTimeInterval(ttl)
    }

    /// Whether the entry is expired
    public var isExpired: Bool {
        Date() > expiresAt
    }

    /// Whether the entry is stale (past TTL but within grace period)
    public func isStale(gracePeriod: TimeInterval) -> Bool {
        let staleThreshold = expiresAt.addingTimeInterval(gracePeriod)
        return Date() > expiresAt && Date() <= staleThreshold
    }

    /// Age of the entry in seconds
    public var age: TimeInterval {
        Date().timeIntervalSince(createdAt)
    }

    public init(value: T, createdAt: Date = Date(), ttl: TimeInterval) {
        self.value = value
        self.createdAt = createdAt
        self.ttl = ttl
    }
}

// MARK: - Cache Policy

/// Cache policy determining fetch behavior
public enum CachePolicy: Sendable, Equatable {
    /// Only use network, never cache
    case networkOnly

    /// Try network first, fallback to cache on error
    case networkFirst

    /// Try cache first, fetch from network if missing
    case cacheFirst

    /// Use cache only, never fetch from network
    case cacheOnly

    /// Stale-while-revalidate: return stale data immediately, fetch fresh in background
    case staleWhileRevalidate(gracePeriod: TimeInterval = 300) // 5 min grace period
}

// MARK: - Cache Statistics

/// Comprehensive cache statistics
public struct CacheStatistics: Sendable {
    /// Number of cache hits (fresh data)
    public let hits: Int

    /// Number of cache misses
    public let misses: Int

    /// Number of stale hits (returned stale data)
    public let staleHits: Int

    /// Number of evictions (manual + automatic)
    public let evictions: Int

    /// Current cache size
    public let currentSize: Int

    /// Maximum cache size
    public let maxSize: Int

    /// Memory pressure events handled
    public let memoryPressureEvents: Int

    /// Cache hit rate (0.0 - 1.0)
    public var hitRate: Double {
        let total = hits + misses + staleHits
        guard total > 0 else { return 0.0 }
        return Double(hits) / Double(total)
    }

    /// Stale hit rate (0.0 - 1.0)
    public var staleHitRate: Double {
        let total = hits + misses + staleHits
        guard total > 0 else { return 0.0 }
        return Double(staleHits) / Double(total)
    }

    /// Effective hit rate (includes stale hits)
    public var effectiveHitRate: Double {
        let total = hits + misses + staleHits
        guard total > 0 else { return 0.0 }
        return Double(hits + staleHits) / Double(total)
    }

    /// Cache utilization (0.0 - 1.0)
    public var utilization: Double {
        guard maxSize > 0 else { return 0.0 }
        return Double(currentSize) / Double(maxSize)
    }

    public init(
        hits: Int = 0,
        misses: Int = 0,
        staleHits: Int = 0,
        evictions: Int = 0,
        currentSize: Int = 0,
        maxSize: Int,
        memoryPressureEvents: Int = 0,
    ) {
        self.hits = hits
        self.misses = misses
        self.staleHits = staleHits
        self.evictions = evictions
        self.currentSize = currentSize
        self.maxSize = maxSize
        self.memoryPressureEvents = memoryPressureEvents
    }
}

// MARK: - Cache Error

/// Errors that can occur during cache operations
public enum CacheError: LocalizedError, Sendable {
    case notFound
    case expired
    case invalidData
    case encodingFailed
    case decodingFailed
    case networkRequired

    public var errorDescription: String? {
        switch self {
        case .notFound:
            "Cache entry not found"
        case .expired:
            "Cache entry expired"
        case .invalidData:
            "Invalid cache data"
        case .encodingFailed:
            "Failed to encode cache value"
        case .decodingFailed:
            "Failed to decode cache value"
        case .networkRequired:
            "Network fetch required but unavailable"
        }
    }
}

// MARK: - Cache Configuration

/// Default TTL values per data type
public enum CacheTTL {
    /// User profile: 5 minutes
    public static let userProfile: TimeInterval = 300

    /// Feed items: 2 minutes
    public static let feedItems: TimeInterval = 120

    /// Categories: 1 hour
    public static let categories: TimeInterval = 3600

    /// Search results: 1 minute
    public static let searchResults: TimeInterval = 60

    /// Default TTL for unspecified types
    public static let `default`: TimeInterval = 300
}

// MARK: - Generic Cache Actor

/// High-performance actor-isolated cache with stale-while-revalidate support
public actor GenericCache<Key: Hashable & Sendable, Value: Sendable & Codable> {
    // MARK: - Storage

    private var storage: [Key: CacheEntry<Value>] = [:]
    private let maxSize: Int
    private let defaultTTL: TimeInterval

    // MARK: - Statistics

    private var hits = 0
    private var misses = 0
    private var staleHits = 0
    private var evictions = 0
    private var memoryPressureEvents = 0

    // MARK: - Background Revalidation

    private var revalidationTasks: [Key: Task<Void, Never>] = [:]

    // MARK: - Initialization

    public init(maxSize: Int = 100, defaultTTL: TimeInterval = CacheTTL.default) {
        self.maxSize = maxSize
        self.defaultTTL = defaultTTL

        // Register for memory warnings
        Task { @MainActor in
            NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main,
            ) { [weak self] _ in
                Task {
                    await self?.handleMemoryPressure()
                }
            }
        }
    }

    deinit {
        // Cancel all revalidation tasks
        for task in revalidationTasks.values {
            task.cancel()
        }
    }

    // MARK: - Core Operations

    /// Get value from cache
    /// - Parameter key: The cache key
    /// - Returns: The cached value if available and not expired, nil otherwise
    public func get(_ key: Key) -> Value? {
        guard let entry = storage[key] else {
            misses += 1
            return nil
        }

        if entry.isExpired {
            storage.removeValue(forKey: key)
            evictions += 1
            misses += 1
            return nil
        }

        hits += 1
        return entry.value
    }

    /// Get value from cache with stale support
    /// - Parameters:
    ///   - key: The cache key
    ///   - gracePeriod: How long to accept stale data (default: 5 minutes)
    /// - Returns: Tuple of (value, isStale)
    public func getWithStale(_ key: Key, gracePeriod: TimeInterval = 300) -> (value: Value, isStale: Bool)? {
        guard let entry = storage[key] else {
            misses += 1
            return nil
        }

        if entry.isExpired {
            if entry.isStale(gracePeriod: gracePeriod) {
                // Return stale data
                staleHits += 1
                return (entry.value, true)
            } else {
                // Too stale, remove it
                storage.removeValue(forKey: key)
                evictions += 1
                misses += 1
                return nil
            }
        }

        hits += 1
        return (entry.value, false)
    }

    /// Set value in cache
    /// - Parameters:
    ///   - key: The cache key
    ///   - value: The value to cache
    ///   - ttl: Time-to-live in seconds (optional, uses default if nil)
    public func set(_ key: Key, value: Value, ttl: TimeInterval? = nil) {
        let entry = CacheEntry(value: value, ttl: ttl ?? defaultTTL)
        storage[key] = entry

        // Evict if over capacity
        if storage.count > maxSize {
            evictLRU()
        }
    }

    /// Remove value from cache
    /// - Parameter key: The cache key
    public func remove(_ key: Key) {
        storage.removeValue(forKey: key)
    }

    /// Remove all values matching a key prefix
    /// - Parameter prefix: The key prefix to match
    public func removeByPrefix(_ prefix: String) where Key == String {
        let keysToRemove = storage.keys.filter { $0.hasPrefix(prefix) }
        for key in keysToRemove {
            storage.removeValue(forKey: key)
            evictions += 1
        }
    }

    /// Clear all cached values
    public func clear() {
        let count = storage.count
        storage.removeAll()
        evictions += count
    }

    /// Get cache statistics
    public func statistics() -> CacheStatistics {
        CacheStatistics(
            hits: hits,
            misses: misses,
            staleHits: staleHits,
            evictions: evictions,
            currentSize: storage.count,
            maxSize: maxSize,
            memoryPressureEvents: memoryPressureEvents,
        )
    }

    /// Reset statistics counters
    public func resetStatistics() {
        hits = 0
        misses = 0
        staleHits = 0
        evictions = 0
        memoryPressureEvents = 0
    }

    // MARK: - Stale-While-Revalidate

    /// Fetch with stale-while-revalidate pattern
    /// - Parameters:
    ///   - key: The cache key
    ///   - gracePeriod: How long to accept stale data
    ///   - ttl: TTL for newly fetched data
    ///   - fetcher: Async closure to fetch fresh data
    /// - Returns: The cached or fetched value
    public func fetchWithStaleWhileRevalidate(
        key: Key,
        gracePeriod: TimeInterval = 300,
        ttl: TimeInterval? = nil,
        fetcher: @escaping @Sendable () async throws -> Value,
    ) async throws -> Value {
        // Check cache first
        if let result = getWithStale(key, gracePeriod: gracePeriod) {
            if result.isStale {
                // Return stale data and revalidate in background
                scheduleRevalidation(key: key, ttl: ttl, fetcher: fetcher)
            }
            return result.value
        }

        // No cache hit, fetch fresh data
        let value = try await fetcher()
        set(key, value: value, ttl: ttl)
        return value
    }

    /// Schedule background revalidation
    private func scheduleRevalidation(
        key: Key,
        ttl: TimeInterval?,
        fetcher: @escaping @Sendable () async throws -> Value,
    ) {
        // Cancel existing revalidation task if any
        revalidationTasks[key]?.cancel()

        // Create new revalidation task
        let task = Task {
            do {
                let value = try await fetcher()
                await set(key, value: value, ttl: ttl)
            } catch {
                // Silently fail - stale data is already returned
            }
            await removeRevalidationTask(key: key)
        }

        revalidationTasks[key] = task
    }

    /// Remove completed revalidation task
    private func removeRevalidationTask(key: Key) {
        revalidationTasks.removeValue(forKey: key)
    }

    // MARK: - Memory Management

    /// Handle memory pressure by evicting entries
    private func handleMemoryPressure() {
        memoryPressureEvents += 1

        // Evict 50% of cache on memory pressure
        let targetSize = maxSize / 2
        while storage.count > targetSize {
            evictLRU()
        }
    }

    /// Evict least recently created entry
    private func evictLRU() {
        guard let oldestKey = storage.min(by: { $0.value.createdAt < $1.value.createdAt })?.key else {
            return
        }
        storage.removeValue(forKey: oldestKey)
        evictions += 1
    }

    // MARK: - Cleanup

    /// Remove expired entries
    public func cleanupExpired() {
        let expiredKeys = storage.filter(\.value.isExpired).map(\.key)
        for key in expiredKeys {
            storage.removeValue(forKey: key)
            evictions += 1
        }
    }
}

// MARK: - Typed Cache Manager Protocol

/// Protocol for creating specialized cache managers
/// Implement this in your feature layer to create domain-specific caches
public protocol TypedCacheManager {
    associatedtype Value: Sendable & Codable

    var cache: GenericCache<String, Value> { get }

    func statistics() async -> CacheStatistics
    func clear() async
}

extension TypedCacheManager {
    public func statistics() async -> CacheStatistics {
        await cache.statistics()
    }

    public func clear() async {
        await cache.clear()
    }
}

// MARK: - Location-Based Cache Key Helper

/// Helper for generating location-based cache keys
public enum LocationCacheKey {
    /// Generate cache key for location-based queries
    /// - Parameters:
    ///   - prefix: Key prefix (e.g., "feed", "fridges")
    ///   - lat: Latitude
    ///   - lng: Longitude
    ///   - radius: Radius in meters
    /// - Returns: Cache key string
    public static func generate(prefix: String, lat: Double, lng: Double, radius: Int) -> String {
        "\(prefix):\(Int(lat * 1000)):\(Int(lng * 1000)):\(radius)"
    }
}

// MARK: - Example Implementations

/*
 Example: Create a specialized cache manager in your feature module

 ```swift
 // In Features/Profile/Data/Cache/
 import Core

 public actor UserProfileCacheManager: TypedCacheManager {
     public let cache = GenericCache<String, UserProfile>(
         maxSize: 50,
         defaultTTL: CacheTTL.userProfile
     )

     public init() {}

     public func get(userId: UUID) async -> UserProfile? {
         await cache.get(userId.uuidString)
     }

     public func set(_ profile: UserProfile) async {
         await cache.set(profile.id.uuidString, value: profile)
     }

     public func fetchWithStaleWhileRevalidate(
         userId: UUID,
         fetcher: @escaping @Sendable () async throws -> UserProfile
     ) async throws -> UserProfile {
         try await cache.fetchWithStaleWhileRevalidate(
             key: userId.uuidString,
             fetcher: fetcher
         )
     }
 }
 ```

 ```swift
 // In Features/Feed/Data/Cache/
 import Core

 public actor FeedItemCacheManager: TypedCacheManager {
     public let cache = GenericCache<String, [FoodItem]>(
         maxSize: 100,
         defaultTTL: CacheTTL.feedItems
     )

     public init() {}

     public func get(lat: Double, lng: Double, radius: Int) async -> [FoodItem]? {
         let key = LocationCacheKey.generate(
             prefix: "feed",
             lat: lat,
             lng: lng,
             radius: radius
         )
         return await cache.get(key)
     }

     public func fetchWithStaleWhileRevalidate(
         lat: Double,
         lng: Double,
         radius: Int,
         fetcher: @escaping @Sendable () async throws -> [FoodItem]
     ) async throws -> [FoodItem] {
         let key = LocationCacheKey.generate(
             prefix: "feed",
             lat: lat,
             lng: lng,
             radius: radius
         )
         return try await cache.fetchWithStaleWhileRevalidate(
             key: key,
             fetcher: fetcher
         )
     }
 }
 ```
 */
