# CacheStrategy Integration Guide

This guide shows how to integrate the new `CacheStrategy` module into existing FoodShare features.

## Quick Start

### 1. Create a Feature-Specific Cache Manager

Create a cache manager in your feature's Data layer:

```swift
// File: Features/Feed/Data/Cache/FeedCacheManager.swift
import Foundation

public actor FeedCacheManager {
    private let cache = GenericCache<String, [FoodItem]>(
        maxSize: 100,
        defaultTTL: CacheTTL.feedItems
    )

    public init() {}

    // Fetch nearby listings with stale-while-revalidate
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
            gracePeriod: 300, // 5 minutes
            fetcher: fetcher
        )
    }

    public func invalidate(lat: Double, lng: Double, radius: Int) async {
        let key = LocationCacheKey.generate(
            prefix: "feed",
            lat: lat,
            lng: lng,
            radius: radius
        )
        await cache.remove(key)
    }

    public func clear() async {
        await cache.clear()
    }

    public func statistics() async -> CacheStatistics {
        await cache.statistics()
    }
}
```

### 2. Update Repository to Use Cache

Modify your repository to integrate caching:

```swift
// File: Features/Feed/Data/Repositories/SupabaseFeedRepository.swift
actor SupabaseFeedRepository: FeedRepository {
    private let supabase: SupabaseClient
    private let cacheManager: FeedCacheManager

    init(supabase: SupabaseClient, cacheManager: FeedCacheManager = FeedCacheManager()) {
        self.supabase = supabase
        self.cacheManager = cacheManager
    }

    func fetchListings(
        near location: Location,
        radius: Double,
        limit: Int,
        offset: Int
    ) async throws -> [FoodItem] {
        // Only cache first page
        if offset == 0 {
            return try await cacheManager.fetchNearby(
                lat: location.latitude,
                lng: location.longitude,
                radius: Int(radius * 1000)
            ) {
                try await self.fetchFromSupabase(
                    location: location,
                    radius: radius,
                    limit: limit,
                    offset: offset
                )
            }
        } else {
            // Don't cache pagination
            return try await fetchFromSupabase(
                location: location,
                radius: radius,
                limit: limit,
                offset: offset
            )
        }
    }

    private func fetchFromSupabase(
        location: Location,
        radius: Double,
        limit: Int,
        offset: Int
    ) async throws -> [FoodItem] {
        // Existing Supabase fetch logic
        let response = try await supabase
            .from("posts")
            .select()
            .eq("is_active", value: true)
            // ... rest of query
            .execute()

        return try response.value
    }

    func invalidateCache(location: Location, radius: Double) async {
        await cacheManager.invalidate(
            lat: location.latitude,
            lng: location.longitude,
            radius: Int(radius * 1000)
        )
    }
}
```

### 3. Update ViewModel (No Changes Needed!)

Your ViewModel can stay the same - caching happens transparently:

```swift
@MainActor
@Observable
final class FeedViewModel {
    private let repository: FeedRepository
    private(set) var listings: [FoodItem] = []
    private(set) var isLoading = false

    func loadListings(location: Location, radius: Double) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Cache automatically provides:
            // 1. Instant results from stale data (if available)
            // 2. Background refresh for freshness
            listings = try await repository.fetchListings(
                near: location,
                radius: radius,
                limit: 20,
                offset: 0
            )
        } catch {
            // Handle error
        }
    }

    func refreshListings(location: Location, radius: Double) async {
        // Pull-to-refresh: invalidate and fetch
        await repository.invalidateCache(location: location, radius: radius)
        await loadListings(location: location, radius: radius)
    }
}
```

## Example Migrations

### Profile Repository

```swift
// File: Features/Profile/Data/Cache/ProfileCacheManager.swift
public actor ProfileCacheManager {
    private let cache = GenericCache<String, UserProfile>(
        maxSize: 50,
        defaultTTL: CacheTTL.userProfile
    )

    public func fetch(
        userId: UUID,
        fetcher: @escaping @Sendable () async throws -> UserProfile
    ) async throws -> UserProfile {
        try await cache.fetchWithStaleWhileRevalidate(
            key: userId.uuidString,
            fetcher: fetcher
        )
    }

    public func invalidate(userId: UUID) async {
        await cache.remove(userId.uuidString)
    }
}

// File: Features/Profile/Data/Repositories/SupabaseProfileRepository.swift
actor SupabaseProfileRepository: ProfileRepository {
    private let supabase: SupabaseClient
    private let cacheManager: ProfileCacheManager

    func getProfile(userId: UUID) async throws -> UserProfile {
        try await cacheManager.fetch(userId: userId) {
            try await self.fetchFromSupabase(userId: userId)
        }
    }

    func updateProfile(_ profile: UserProfile) async throws {
        try await supabase.from("profiles").update(profile).execute()

        // Invalidate cache after mutation
        await cacheManager.invalidate(userId: profile.id)
    }

    private func fetchFromSupabase(userId: UUID) async throws -> UserProfile {
        let response = try await supabase
            .from("profiles")
            .select()
            .eq("id", value: userId.uuidString)
            .single()
            .execute()

        return try response.value
    }
}
```

### Search Repository

```swift
// File: Features/Search/Data/Cache/SearchCacheManager.swift
public actor SearchCacheManager {
    private let cache = GenericCache<String, [FoodItem]>(
        maxSize: 50,
        defaultTTL: CacheTTL.searchResults
    )

    public func search(
        query: String,
        filters: SearchFilters?,
        fetcher: @escaping @Sendable () async throws -> [FoodItem]
    ) async throws -> [FoodItem] {
        let key = cacheKey(query: query, filters: filters)
        return try await cache.fetchWithStaleWhileRevalidate(
            key: key,
            gracePeriod: 120, // 2 minutes grace for search
            fetcher: fetcher
        )
    }

    public func invalidateQuery(_ query: String) async {
        await cache.removeByPrefix("search:\(query)")
    }

    private func cacheKey(query: String, filters: SearchFilters?) -> String {
        if let filters = filters {
            let filtersHash = "\(filters.hashValue)"
            return "search:\(query):\(filtersHash)"
        }
        return "search:\(query)"
    }
}
```

### Category Repository

```swift
// File: Features/Feed/Data/Cache/CategoryCacheManager.swift
public actor CategoryCacheManager {
    private let cache = GenericCache<String, [Category]>(
        maxSize: 10,
        defaultTTL: CacheTTL.categories
    )

    private let cacheKey = "categories:all"

    public func fetchAll(
        fetcher: @escaping @Sendable () async throws -> [Category]
    ) async throws -> [Category] {
        try await cache.fetchWithStaleWhileRevalidate(
            key: cacheKey,
            gracePeriod: 1800, // 30 minutes grace (categories change rarely)
            fetcher: fetcher
        )
    }

    public func clear() async {
        await cache.clear()
    }
}
```

## Cache Invalidation Strategies

### After Mutations

Always invalidate cache after create/update/delete operations:

```swift
func createListing(_ listing: FoodItem) async throws {
    // Create in database
    try await supabase.from("posts").insert(listing).execute()

    // Invalidate nearby cache
    await cacheManager.invalidate(
        lat: listing.latitude,
        lng: listing.longitude,
        radius: 5000
    )
}

func updateListing(_ listing: FoodItem) async throws {
    try await supabase.from("posts").update(listing).execute()

    // Invalidate specific location
    await cacheManager.invalidate(
        lat: listing.latitude,
        lng: listing.longitude,
        radius: 5000
    )
}

func deleteListing(id: Int) async throws {
    // Fetch location first for cache invalidation
    let listing = try await fetchListing(id: id)

    try await supabase.from("posts").delete().eq("id", value: id).execute()

    await cacheManager.invalidate(
        lat: listing.latitude,
        lng: listing.longitude,
        radius: 5000
    )
}
```

### On Pull-to-Refresh

```swift
func refreshListings() async {
    // Invalidate cache
    await repository.invalidateCache(location: currentLocation, radius: currentRadius)

    // Fetch fresh data (will skip cache)
    await loadListings()
}
```

### On App Launch

```swift
// In AppDelegate or App init
func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) {
    Task {
        // Cleanup expired entries on launch
        await feedCacheManager.cleanupExpired()
        await profileCacheManager.cleanupExpired()
        await categoryCacheManager.cleanupExpired()
    }
}
```

### On Background/Foreground

```swift
// In AppDelegate
func applicationDidEnterBackground(_ application: UIApplication) {
    Task {
        // Cleanup on backgrounding
        await feedCacheManager.cleanupExpired()
    }
}

func applicationWillEnterForeground(_ application: UIApplication) {
    Task {
        // Optionally invalidate stale data on foregrounding
        // This forces a refresh when user returns to app
        await feedCacheManager.clear()
    }
}
```

## Testing Integration

### Repository Tests

```swift
import Testing
@testable import Foodshare

@Suite("Feed Repository Cache Tests")
struct FeedRepositoryCacheTests {
    @Test("Repository returns cached data on second fetch")
    func testCaching() async throws {
        let mockSupabase = MockSupabaseClient()
        let cacheManager = FeedCacheManager()
        let repository = SupabaseFeedRepository(
            supabase: mockSupabase,
            cacheManager: cacheManager
        )

        let location = Location(latitude: 37.7749, longitude: -122.4194)

        // First fetch - hits network
        let items1 = try await repository.fetchListings(
            near: location,
            radius: 5.0,
            limit: 20,
            offset: 0
        )
        #expect(mockSupabase.fetchCount == 1)

        // Second fetch - hits cache
        let items2 = try await repository.fetchListings(
            near: location,
            radius: 5.0,
            limit: 20,
            offset: 0
        )
        #expect(mockSupabase.fetchCount == 1) // Still 1 (cache hit)
        #expect(items1 == items2)
    }

    @Test("Repository invalidates cache after mutation")
    func testInvalidation() async throws {
        let mockSupabase = MockSupabaseClient()
        let cacheManager = FeedCacheManager()
        let repository = SupabaseFeedRepository(
            supabase: mockSupabase,
            cacheManager: cacheManager
        )

        let location = Location(latitude: 37.7749, longitude: -122.4194)

        // Fetch and cache
        _ = try await repository.fetchListings(
            near: location,
            radius: 5.0,
            limit: 20,
            offset: 0
        )

        // Invalidate
        await repository.invalidateCache(location: location, radius: 5.0)

        // Fetch again - should hit network
        _ = try await repository.fetchListings(
            near: location,
            radius: 5.0,
            limit: 20,
            offset: 0
        )
        #expect(mockSupabase.fetchCount == 2)
    }
}
```

## Monitoring Cache Performance

### Add Debug View

```swift
// File: Features/Settings/Presentation/Views/CacheDebugView.swift
import SwiftUI

struct CacheDebugView: View {
    @State private var feedStats: CacheStatistics?
    @State private var profileStats: CacheStatistics?
    @State private var categoryStats: CacheStatistics?

    var body: some View {
        List {
            Section("Feed Cache") {
                if let stats = feedStats {
                    StatisticsView(stats: stats)
                }
            }

            Section("Profile Cache") {
                if let stats = profileStats {
                    StatisticsView(stats: stats)
                }
            }

            Section("Category Cache") {
                if let stats = categoryStats {
                    StatisticsView(stats: stats)
                }
            }

            Section("Actions") {
                Button("Clear All Caches", role: .destructive) {
                    Task {
                        // Clear implementation
                    }
                }
            }
        }
        .navigationTitle("Cache Statistics")
        .task {
            await loadStatistics()
        }
        .refreshable {
            await loadStatistics()
        }
    }

    func loadStatistics() async {
        // Load from your cache managers
    }
}

struct StatisticsView: View {
    let stats: CacheStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            StatRow(label: "Hit Rate", value: "\(Int(stats.hitRate * 100))%")
            StatRow(label: "Effective Hit Rate", value: "\(Int(stats.effectiveHitRate * 100))%")
            StatRow(label: "Size", value: "\(stats.currentSize) / \(stats.maxSize)")
            StatRow(label: "Utilization", value: "\(Int(stats.utilization * 100))%")
            StatRow(label: "Evictions", value: "\(stats.evictions)")
            StatRow(label: "Memory Pressure", value: "\(stats.memoryPressureEvents)")
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
```

### Add to Settings Menu

```swift
// In SettingsView.swift
NavigationLink("Cache Statistics") {
    CacheDebugView()
}
#if DEBUG
// Only show in debug builds
#endif
```

## Migration Checklist

- [ ] Create feature-specific cache manager
- [ ] Update repository to use cache manager
- [ ] Add cache invalidation after mutations
- [ ] Add cleanup on app lifecycle events
- [ ] Write unit tests for caching behavior
- [ ] Add cache statistics monitoring (debug builds)
- [ ] Test memory pressure handling
- [ ] Verify stale-while-revalidate UX improvements
- [ ] Update documentation

## Common Pitfalls

### ❌ Don't cache paginated results

```swift
// BAD - Caches incomplete results
func fetchListings(offset: Int) async throws -> [FoodItem] {
    return try await cache.fetch(key: "listings") {
        try await api.fetch(offset: offset)
    }
}

// GOOD - Only cache first page
func fetchListings(offset: Int) async throws -> [FoodItem] {
    if offset == 0 {
        return try await cache.fetch(key: "listings") {
            try await api.fetch(offset: 0)
        }
    } else {
        return try await api.fetch(offset: offset)
    }
}
```

### ❌ Don't forget to invalidate after mutations

```swift
// BAD - Cache becomes stale
func updateProfile(_ profile: UserProfile) async throws {
    try await api.update(profile)
    // Missing: await cache.invalidate()
}

// GOOD - Cache stays fresh
func updateProfile(_ profile: UserProfile) async throws {
    try await api.update(profile)
    await cache.invalidate(userId: profile.id)
}
```

### ❌ Don't use same key for different data

```swift
// BAD - Collisions
let key = "listings"  // Too generic

// GOOD - Specific keys
let key = LocationCacheKey.generate(
    prefix: "feed",
    lat: lat,
    lng: lng,
    radius: radius
)
```

## Support

For questions or issues:
1. Check `README.md` for detailed documentation
2. Review `CacheStrategy+Examples.swift` for code examples
3. See existing implementations in `CachingService.swift`
4. Contact the architecture team

---

**Last Updated**: 2026-01-31
