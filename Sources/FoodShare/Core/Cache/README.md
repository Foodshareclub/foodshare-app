# Cache Strategy Module

Production-quality caching system with stale-while-revalidate pattern, TTL-based expiration, and comprehensive statistics tracking.

## Overview

This module provides a flexible, actor-isolated caching system designed for iOS 17+ with Swift 6.2 concurrency features. It implements the stale-while-revalidate pattern for optimal user experience while maintaining data freshness.

## Features

- ✅ **TTL-Based Expiration** - Configurable time-to-live per cache entry
- ✅ **Stale-While-Revalidate** - Return stale data immediately, fetch fresh in background
- ✅ **Cache Policies** - Multiple fetch strategies (network-first, cache-first, etc.)
- ✅ **Memory Pressure Handling** - Automatic eviction on memory warnings
- ✅ **LRU Eviction** - Least-recently-created entries evicted when full
- ✅ **Statistics Tracking** - Hits, misses, stale hits, evictions, memory pressure events
- ✅ **Thread-Safe** - Actor isolation ensures safe concurrent access
- ✅ **Generic** - Works with any `Codable & Sendable` type
- ✅ **Type-Safe Keys** - String-based keys with helper functions

## Architecture

```
CacheStrategy.swift
├── CacheEntry<T>              # Value wrapper with metadata
├── CachePolicy                # Fetch strategy enum
├── CacheStatistics            # Comprehensive metrics
├── CacheError                 # Typed errors
├── CacheTTL                   # Default TTL constants
├── GenericCache<Key, Value>   # Core cache actor
├── LocationCacheKey           # Location-based key helper
└── TypedCacheManager          # Protocol for specialized caches
```

## Default TTL Values

| Data Type | TTL | Constant |
|-----------|-----|----------|
| User profiles | 5 minutes | `CacheTTL.userProfile` |
| Feed items | 2 minutes | `CacheTTL.feedItems` |
| Categories | 1 hour | `CacheTTL.categories` |
| Search results | 1 minute | `CacheTTL.searchResults` |
| Default | 5 minutes | `CacheTTL.default` |

## Cache Policies

### `.networkOnly`
Never use cache, always fetch from network.

```swift
let items = try await repository.fetch(policy: .networkOnly)
```

### `.cacheOnly`
Only use cache, never fetch from network. Throws `CacheError.notFound` if not cached.

```swift
let items = try await repository.fetch(policy: .cacheOnly)
```

### `.cacheFirst`
Try cache first, fetch from network if missing.

```swift
let items = try await repository.fetch(policy: .cacheFirst)
```

### `.networkFirst`
Try network first, fallback to cache on error.

```swift
let items = try await repository.fetch(policy: .networkFirst)
```

### `.staleWhileRevalidate(gracePeriod:)`
**Recommended for best UX** - Return stale data immediately (if available), fetch fresh in background.

```swift
let items = try await repository.fetch(
    policy: .staleWhileRevalidate(gracePeriod: 300) // 5 min grace period
)
```

## Usage

### Basic Usage

```swift
// Create a cache for any Codable type
let cache = GenericCache<String, [FoodItem]>(
    maxSize: 100,
    defaultTTL: CacheTTL.feedItems
)

// Get from cache
if let items = await cache.get("my-key") {
    print("Cache hit: \(items.count) items")
}

// Set to cache
await cache.set("my-key", value: items, ttl: 120)

// Remove from cache
await cache.remove("my-key")

// Clear all
await cache.clear()
```

### Stale-While-Revalidate

```swift
let items = try await cache.fetchWithStaleWhileRevalidate(
    key: "feed:nearby",
    gracePeriod: 300, // Accept stale data up to 5 minutes past TTL
    ttl: 120 // Cache fresh data for 2 minutes
) {
    // Fetcher closure - called when cache miss or revalidating
    try await networkService.fetchNearbyItems()
}
```

**Flow:**
1. Check cache - if fresh, return immediately
2. If stale (past TTL but within grace period):
   - Return stale data immediately (instant UI)
   - Start background task to fetch fresh data
   - Fresh data cached when ready
3. If expired or missing:
   - Fetch from network (blocks)
   - Cache and return fresh data

### Location-Based Caching

```swift
let key = LocationCacheKey.generate(
    prefix: "feed",
    lat: 37.7749,
    lng: -122.4194,
    radius: 5000 // meters
)
// Result: "feed:37774:-122419:5000"

await cache.set(key, value: nearbyItems)
```

### Creating a Specialized Cache Manager

```swift
// In your feature module (e.g., Features/Feed/Data/Cache/)
public actor FeedCacheManager: TypedCacheManager {
    public let cache = GenericCache<String, [FoodItem]>(
        maxSize: 100,
        defaultTTL: CacheTTL.feedItems
    )

    public init() {}

    public func fetchNearby(
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

    public func invalidateLocation(lat: Double, lng: Double, radius: Int) async {
        let key = LocationCacheKey.generate(
            prefix: "feed",
            lat: lat,
            lng: lng,
            radius: radius
        )
        await cache.remove(key)
    }
}
```

### Using in a Repository

```swift
actor FeedRepository {
    private let networkService: NetworkService
    private let cacheManager: FeedCacheManager

    func fetchNearbyListings(
        lat: Double,
        lng: Double,
        radius: Int
    ) async throws -> [FoodItem] {
        try await cacheManager.fetchNearby(
            lat: lat,
            lng: lng,
            radius: radius
        ) {
            try await networkService.fetchNearby(
                lat: lat,
                lng: lng,
                radius: radius
            )
        }
    }

    func invalidateCache(lat: Double, lng: Double, radius: Int) async {
        await cacheManager.invalidateLocation(
            lat: lat,
            lng: lng,
            radius: radius
        )
    }
}
```

### Using in a ViewModel

```swift
@MainActor
@Observable
final class FeedViewModel {
    private let repository: FeedRepository
    private(set) var listings: [FoodItem] = []
    private(set) var isLoading = false

    func loadListings(lat: Double, lng: Double) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Stale-while-revalidate provides instant UI updates
            listings = try await repository.fetchNearbyListings(
                lat: lat,
                lng: lng,
                radius: 5000
            )
        } catch {
            // Handle error
        }
    }
}
```

## Cache Statistics

Track cache performance with comprehensive metrics:

```swift
let stats = await cache.statistics()

print("Hit rate: \(stats.hitRate)")           // 0.0 - 1.0
print("Stale hit rate: \(stats.staleHitRate)") // 0.0 - 1.0
print("Effective hit rate: \(stats.effectiveHitRate)") // Includes stale hits
print("Utilization: \(stats.utilization)")     // 0.0 - 1.0

print("Hits: \(stats.hits)")
print("Misses: \(stats.misses)")
print("Stale hits: \(stats.staleHits)")
print("Evictions: \(stats.evictions)")
print("Current size: \(stats.currentSize) / \(stats.maxSize)")
print("Memory pressure events: \(stats.memoryPressureEvents)")
```

### Interpreting Metrics

- **Hit Rate** - Percentage of requests served from fresh cache
- **Stale Hit Rate** - Percentage served from stale cache (still useful!)
- **Effective Hit Rate** - Total cache hits (fresh + stale) - best UX metric
- **Utilization** - How full the cache is (1.0 = at capacity)
- **Evictions** - Number of entries removed (high = increase maxSize)
- **Memory Pressure Events** - Times iOS requested memory cleanup

## Memory Management

### Automatic Memory Pressure Handling

The cache automatically registers for `UIApplication.didReceiveMemoryWarningNotification` and evicts 50% of entries when iOS reports memory pressure.

```swift
// This happens automatically - no action needed
// Cache will evict half its entries when memory pressure occurs
```

### Manual Cleanup

```swift
// Remove expired entries
await cache.cleanupExpired()

// Clear all entries
await cache.clear()

// Remove by prefix (String keys only)
await cache.removeByPrefix("feed:")
```

### LRU Eviction

When cache reaches `maxSize`, the least-recently-created entry is evicted automatically.

```swift
let cache = GenericCache<String, String>(
    maxSize: 3,  // Only keep 3 entries
    defaultTTL: 60
)

await cache.set("key1", value: "value1")
await cache.set("key2", value: "value2")
await cache.set("key3", value: "value3")
await cache.set("key4", value: "value4") // Evicts key1

let stats = await cache.statistics()
print(stats.evictions) // 1
```

## Testing

### Unit Test Example

```swift
import Testing
@testable import Foodshare

@Test("Stale-while-revalidate returns stale data immediately")
func testStaleWhileRevalidate() async throws {
    let cache = GenericCache<String, String>(
        maxSize: 10,
        defaultTTL: 0.1 // 100ms TTL
    )

    // Set initial value
    await cache.set("key1", value: "stale-value")

    // Wait for expiration
    try await Task.sleep(for: .milliseconds(150))

    var fetchCount = 0
    let result = try await cache.fetchWithStaleWhileRevalidate(
        key: "key1",
        gracePeriod: 300
    ) {
        fetchCount += 1
        return "fresh-value"
    }

    // Should return stale value immediately
    #expect(result == "stale-value")

    // Background fetch should occur
    try await Task.sleep(for: .milliseconds(100))
    #expect(fetchCount == 1)

    // Next fetch should return fresh value
    let fresh = await cache.get("key1")
    #expect(fresh == "fresh-value")
}
```

See `CacheStrategy+Examples.swift` for more test examples.

## Performance Characteristics

| Operation | Time Complexity | Notes |
|-----------|----------------|-------|
| `get()` | O(1) | Dictionary lookup |
| `set()` | O(1) - O(n) | O(n) only when evicting at capacity |
| `remove()` | O(1) | Dictionary removal |
| `removeByPrefix()` | O(n) | Must check all keys |
| `clear()` | O(n) | Removes all entries |
| `cleanupExpired()` | O(n) | Must check all entries |

**Memory**: O(n) where n is number of cached entries (up to `maxSize`)

## Thread Safety

All operations are thread-safe via Swift actor isolation. The cache can be safely accessed from any context:

```swift
// Safe from any context
Task {
    await cache.set("key", value: data)
}

Task.detached {
    let data = await cache.get("key")
}

await MainActor.run {
    let data = await cache.get("key")
}
```

## Best Practices

### ✅ DO

- Use `staleWhileRevalidate` for lists and feeds (best UX)
- Monitor cache statistics in development
- Set appropriate TTLs based on data volatility
- Invalidate cache after mutations (create, update, delete)
- Use location-based keys for geospatial queries
- Create specialized cache managers per feature
- Test cache behavior with unit tests

### ❌ DON'T

- Don't cache sensitive data (passwords, tokens) - use Keychain
- Don't set TTL too high (stale data) or too low (cache thrashing)
- Don't ignore memory pressure - let automatic handling work
- Don't over-invalidate (wastes cache benefits)
- Don't cache very large objects (images) - use dedicated image cache
- Don't forget to cleanup on app backgrounding

## Integration with Existing Code

This module complements the existing `CachingService.swift` (Upstash Redis-based) and `MemoryCache.swift` (Package):

- **CachingService** - For distributed caching across devices (Redis)
- **MemoryCache** - For simple in-memory caching (Package)
- **CacheStrategy** - For advanced local caching with stale-while-revalidate (this module)

Use cases:
- Remote API responses → `CacheStrategy` (stale-while-revalidate UX)
- Cross-device sync → `CachingService` (Redis)
- Simple in-app state → `MemoryCache` (Package)

## Files

```
FoodShare/Core/Cache/
├── CacheStrategy.swift          # Core implementation
├── CacheStrategy+Examples.swift # Usage examples
├── CachingService.swift         # Redis-based caching (existing)
├── UpstashRedisClient.swift     # Redis client (existing)
└── README.md                    # This file
```

## References

- [HTTP Caching: Stale-While-Revalidate RFC](https://tools.ietf.org/html/rfc5861)
- [Swift Concurrency: Actors](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html#ID645)
- [iOS Memory Management](https://developer.apple.com/documentation/uikit/app_and_environment/managing_your_app_s_life_cycle)

## Future Enhancements

- [ ] Disk persistence for offline support
- [ ] Cache size limits by byte size (not just count)
- [ ] Compression for large values
- [ ] Cache warming strategies
- [ ] Metrics export (Prometheus, StatsD)
- [ ] Cache sync across devices (Upstash integration)
- [ ] Background refresh scheduling

---

**Version**: 1.0.0
**Swift**: 6.2
**iOS**: 17.0+
**Updated**: 2026-01-31
