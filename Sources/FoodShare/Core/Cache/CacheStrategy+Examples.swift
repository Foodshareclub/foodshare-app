//
//  CacheStrategy+Examples.swift
//  Foodshare
//
//  Example implementations and usage patterns for CacheStrategy
//  This file demonstrates how to use the caching system in practice
//

import Foundation

// MARK: - Example: Repository with Stale-While-Revalidate

/*
 Example: Add caching to a repository

 ```swift
 actor FeedRepository {
     private let networkService: NetworkService
     private let cache = GenericCache<String, [FoodItem]>(
         maxSize: 100,
         defaultTTL: CacheTTL.feedItems
     )

     func fetchNearbyListings(
         lat: Double,
         lng: Double,
         radius: Int,
         policy: CachePolicy = .staleWhileRevalidate()
     ) async throws -> [FoodItem] {
         let key = LocationCacheKey.generate(
             prefix: "feed",
             lat: lat,
             lng: lng,
             radius: radius
         )

         switch policy {
         case .networkOnly:
             return try await fetchFromNetwork(lat: lat, lng: lng, radius: radius)

         case .cacheOnly:
             guard let cached = await cache.get(key) else {
                 throw CacheError.notFound
             }
             return cached

         case .cacheFirst:
             if let cached = await cache.get(key) {
                 return cached
             }
             let items = try await fetchFromNetwork(lat: lat, lng: lng, radius: radius)
             await cache.set(key, value: items)
             return items

         case .networkFirst:
             do {
                 let items = try await fetchFromNetwork(lat: lat, lng: lng, radius: radius)
                 await cache.set(key, value: items)
                 return items
             } catch {
                 if let cached = await cache.get(key) {
                     return cached
                 }
                 throw error
             }

         case .staleWhileRevalidate(let gracePeriod):
             return try await cache.fetchWithStaleWhileRevalidate(
                 key: key,
                 gracePeriod: gracePeriod
             ) {
                 try await fetchFromNetwork(lat: lat, lng: lng, radius: radius)
             }
         }
     }

     private func fetchFromNetwork(lat: Double, lng: Double, radius: Int) async throws -> [FoodItem] {
         // Network fetch implementation
         try await networkService.fetchNearby(lat: lat, lng: lng, radius: radius)
     }

     func invalidateCache(lat: Double, lng: Double, radius: Int) async {
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
 */

// MARK: - Example: ViewModel with Caching

/*
 Example: Use cache in a ViewModel

 ```swift
 @MainActor
 @Observable
 final class FeedViewModel {
     private let repository: FeedRepository
     private(set) var listings: [FoodItem] = []
     private(set) var isLoading = false
     private(set) var isLoadingStale = false // Indicates using stale data

     func loadListings(lat: Double, lng: Double, radius: Int) async {
         isLoading = true
         defer { isLoading = false }

         do {
             // Use stale-while-revalidate for instant UI updates
             listings = try await repository.fetchNearbyListings(
                 lat: lat,
                 lng: lng,
                 radius: radius,
                 policy: .staleWhileRevalidate(gracePeriod: 300)
             )

             // Check cache statistics for debugging
             let stats = await repository.cacheStatistics()
             print("Cache hit rate: \(stats.hitRate)")
             print("Stale hit rate: \(stats.staleHitRate)")
         } catch {
             // Handle error
             print("Failed to load listings: \(error)")
         }
     }

     func refreshListings(lat: Double, lng: Double, radius: Int) async {
         // Force network fetch
         isLoading = true
         defer { isLoading = false }

         do {
             listings = try await repository.fetchNearbyListings(
                 lat: lat,
                 lng: lng,
                 radius: radius,
                 policy: .networkFirst
             )
         } catch {
             print("Failed to refresh listings: \(error)")
         }
     }
 }
 ```
 */

// MARK: - Example: Custom Cache Manager

/*
 Example: Create a specialized cache manager for your feature

 ```swift
 // In Features/Profile/Data/Cache/ProfileCacheManager.swift

 public actor ProfileCacheManager {
     private let cache = GenericCache<String, UserProfile>(
         maxSize: 50,
         defaultTTL: CacheTTL.userProfile
     )

     public init() {}

     // MARK: - Basic Operations

     public func get(userId: UUID) async -> UserProfile? {
         await cache.get(userId.uuidString)
     }

     public func set(_ profile: UserProfile) async {
         await cache.set(profile.id.uuidString, value: profile)
     }

     public func remove(userId: UUID) async {
         await cache.remove(userId.uuidString)
     }

     // MARK: - Stale-While-Revalidate

     public func fetchWithStaleWhileRevalidate(
         userId: UUID,
         fetcher: @escaping @Sendable () async throws -> UserProfile
     ) async throws -> UserProfile {
         try await cache.fetchWithStaleWhileRevalidate(
             key: userId.uuidString,
             gracePeriod: 300, // 5 minutes
             fetcher: fetcher
         )
     }

     // MARK: - Utilities

     public func clear() async {
         await cache.clear()
     }

     public func statistics() async -> CacheStatistics {
         await cache.statistics()
     }

     public func cleanupExpired() async {
         await cache.cleanupExpired()
     }
 }
 ```
 */

// MARK: - Example: Testing Cache Behavior

/*
 Example: Unit tests for caching

 ```swift
 import Testing
 @testable import Foodshare

 @Suite("Cache Strategy Tests")
 struct CacheStrategyTests {
     @Test("Cache stores and retrieves values")
     func testBasicCaching() async throws {
         let cache = GenericCache<String, String>(maxSize: 10, defaultTTL: 60)

         // Set value
         await cache.set("key1", value: "value1")

         // Get value
         let retrieved = await cache.get("key1")
         #expect(retrieved == "value1")
     }

     @Test("Cache expires old values")
     func testExpiration() async throws {
         let cache = GenericCache<String, String>(maxSize: 10, defaultTTL: 0.1)

         await cache.set("key1", value: "value1")

         // Wait for expiration
         try await Task.sleep(for: .milliseconds(150))

         let retrieved = await cache.get("key1")
         #expect(retrieved == nil)
     }

     @Test("Stale-while-revalidate returns stale data")
     func testStaleWhileRevalidate() async throws {
         let cache = GenericCache<String, String>(maxSize: 10, defaultTTL: 0.1)

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

     @Test("Cache statistics track hits and misses")
     func testStatistics() async throws {
         let cache = GenericCache<String, String>(maxSize: 10, defaultTTL: 60)

         await cache.set("key1", value: "value1")

         // Hit
         _ = await cache.get("key1")

         // Miss
         _ = await cache.get("key2")

         let stats = await cache.statistics()
         #expect(stats.hits == 1)
         #expect(stats.misses == 1)
         #expect(stats.hitRate == 0.5)
     }

     @Test("Cache evicts LRU entries when full")
     func testEviction() async throws {
         let cache = GenericCache<String, String>(maxSize: 3, defaultTTL: 60)

         await cache.set("key1", value: "value1")
         try await Task.sleep(for: .milliseconds(10))
         await cache.set("key2", value: "value2")
         try await Task.sleep(for: .milliseconds(10))
         await cache.set("key3", value: "value3")
         try await Task.sleep(for: .milliseconds(10))

         // Adding 4th item should evict oldest (key1)
         await cache.set("key4", value: "value4")

         let stats = await cache.statistics()
         #expect(stats.currentSize == 3)
         #expect(stats.evictions == 1)

         let evicted = await cache.get("key1")
         #expect(evicted == nil)
     }
 }
 ```
 */

// MARK: - Example: Cache Monitoring Dashboard

/*
 Example: Create a cache monitoring view for debugging

 ```swift
 import SwiftUI

 struct CacheMonitorView: View {
     @State private var userProfileStats: CacheStatistics?
     @State private var feedItemStats: CacheStatistics?

     var body: some View {
         List {
             Section("User Profile Cache") {
                 if let stats = userProfileStats {
                     CacheStatsRow(stats: stats)
                 }
             }

             Section("Feed Item Cache") {
                 if let stats = feedItemStats {
                     CacheStatsRow(stats: stats)
                 }
             }

             Section("Actions") {
                 Button("Clear All Caches") {
                     Task {
                         // Clear implementation
                     }
                 }

                 Button("Cleanup Expired") {
                     Task {
                         // Cleanup implementation
                     }
                 }
             }
         }
         .navigationTitle("Cache Monitor")
         .task {
             await loadStatistics()
         }
     }

     func loadStatistics() async {
         // Load stats from your cache managers
     }
 }

 struct CacheStatsRow: View {
     let stats: CacheStatistics

     var body: some View {
         VStack(alignment: .leading, spacing: 8) {
             HStack {
                 Text("Hit Rate")
                 Spacer()
                 Text("\(Int(stats.hitRate * 100))%")
                     .foregroundStyle(.secondary)
             }

             HStack {
                 Text("Effective Hit Rate")
                 Spacer()
                 Text("\(Int(stats.effectiveHitRate * 100))%")
                     .foregroundStyle(.secondary)
             }

             HStack {
                 Text("Size")
                 Spacer()
                 Text("\(stats.currentSize) / \(stats.maxSize)")
                     .foregroundStyle(.secondary)
             }

             HStack {
                 Text("Evictions")
                 Spacer()
                 Text("\(stats.evictions)")
                     .foregroundStyle(.secondary)
             }

             HStack {
                 Text("Memory Pressure Events")
                 Spacer()
                 Text("\(stats.memoryPressureEvents)")
                     .foregroundStyle(.secondary)
             }
         }
         .font(.body)
     }
 }
 ```
 */

// MARK: - Best Practices

/*
 Best Practices for Using CacheStrategy:

 1. **Choose the right TTL**
    - User profiles: 5 minutes (CacheTTL.userProfile)
    - Feed items: 2 minutes (CacheTTL.feedItems)
    - Categories: 1 hour (CacheTTL.categories)
    - Search results: 1 minute (CacheTTL.searchResults)

 2. **Use stale-while-revalidate for better UX**
    - Instantly show data to users
    - Update in background for freshness
    - Perfect for lists and feeds

 3. **Monitor cache statistics**
    - Track hit rates to optimize TTLs
    - Watch eviction counts to tune cache sizes
    - Monitor memory pressure events

 4. **Invalidate strategically**
    - After creating/updating resources
    - On user actions that modify data
    - Don't over-invalidate (wastes cache benefits)

 5. **Handle errors gracefully**
    - Use .networkFirst for critical data
    - Use .cacheFirst for offline support
    - Provide fallback UI for cache misses

 6. **Test cache behavior**
    - Unit test expiration logic
    - Test stale-while-revalidate flow
    - Verify statistics accuracy
    - Test memory pressure handling

 7. **Clean up periodically**
    - Call cleanupExpired() on app backgrounding
    - Consider scheduled cleanup for long-running sessions
    - Monitor cache size growth

 8. **Use location-based keys correctly**
    - Round coordinates appropriately
    - Use consistent radius units (meters)
    - Consider cache key collisions
 */
