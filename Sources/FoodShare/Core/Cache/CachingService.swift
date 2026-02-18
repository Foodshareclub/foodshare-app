//
//  CachingService.swift
//  Foodshare
//
//  High-level caching service using Upstash Redis
//  Provides cache-first loading strategy for app data
//


#if !SKIP
import Foundation

// MARK: - Cache Keys

enum CacheKey {
    static let nearbyListings = "listings:nearby"
    static let categories = "categories:all"
    static let userProfile = "profile"
    static let communityFridges = "fridges:nearby"

    static func listings(lat: Double, lng: Double, radius: Int) -> String {
        "\(nearbyListings):\(Int(lat * 1000)):\(Int(lng * 1000)):\(radius)"
    }

    static func profile(userId: UUID) -> String {
        "\(userProfile):\(userId.uuidString)"
    }

    static func fridges(lat: Double, lng: Double, radius: Int) -> String {
        "\(communityFridges):\(Int(lat * 1000)):\(Int(lng * 1000)):\(radius)"
    }
}

// MARK: - Cache TTL

enum CacheTTL {
    static let listings = 300 // 5 minutes
    static let categories = 3600 // 1 hour
    static let profile = 600 // 10 minutes
    static let fridges = 600 // 10 minutes
}

// MARK: - Caching Service

actor CachingService {
    private let redis: UpstashRedisClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // Cache hit/miss tracking
    private var hits = 0
    private var misses = 0

    init(redis: UpstashRedisClient) {
        self.redis = redis
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Generic Cache Operations

    /// Get cached value with type safety
    func get<T: Decodable>(_ key: String) async throws -> T? {
        guard let jsonString = try await redis.get(key) else {
            misses += 1
            return nil
        }

        guard let data = jsonString.data(using: .utf8) else {
            return nil
        }

        hits += 1
        return try decoder.decode(T.self, from: data)
    }

    /// Set cached value with TTL
    func set(_ key: String, value: some Encodable, ttl: Int) async throws {
        let data = try encoder.encode(value)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            return
        }
        try await redis.setex(key, value: jsonString, ttl: ttl)
    }

    /// Invalidate cache key
    func invalidate(_ key: String) async throws {
        try await redis.delete(key)
    }

    /// Invalidate all keys matching pattern (prefix)
    func invalidatePattern(_ prefix: String) async throws {
        // Note: Upstash REST API doesn't support SCAN/KEYS
        // For pattern invalidation, we'd need to track keys separately
        // For now, this is a no-op - individual keys should be invalidated
        await AppLogger.shared.warning("Pattern invalidation not supported: \(prefix)")
    }

    // MARK: - Listings Cache

    /// Get cached listings
    func getListings(lat: Double, lng: Double, radius: Int) async throws -> [FoodItem]? {
        let key = CacheKey.listings(lat: lat, lng: lng, radius: radius)
        return try await get(key)
    }

    /// Cache listings
    func setListings(_ listings: [FoodItem], lat: Double, lng: Double, radius: Int) async throws {
        let key = CacheKey.listings(lat: lat, lng: lng, radius: radius)
        try await set(key, value: listings, ttl: CacheTTL.listings)
    }

    /// Invalidate listings cache for location
    func invalidateListings(lat: Double, lng: Double, radius: Int) async throws {
        let key = CacheKey.listings(lat: lat, lng: lng, radius: radius)
        try await invalidate(key)
    }

    // MARK: - Categories Cache

    /// Get cached categories
    func getCategories() async throws -> [Category]? {
        try await get(CacheKey.categories)
    }

    /// Cache categories
    func setCategories(_ categories: [Category]) async throws {
        try await set(CacheKey.categories, value: categories, ttl: CacheTTL.categories)
    }

    /// Invalidate categories cache
    func invalidateCategories() async throws {
        try await invalidate(CacheKey.categories)
    }

    // MARK: - Profile Cache

    /// Get cached user profile
    func getProfile(userId: UUID) async throws -> UserProfile? {
        let key = CacheKey.profile(userId: userId)
        return try await get(key)
    }

    /// Cache user profile
    func setProfile(_ profile: UserProfile) async throws {
        let key = CacheKey.profile(userId: profile.id)
        try await set(key, value: profile, ttl: CacheTTL.profile)
    }

    /// Invalidate user profile cache
    func invalidateProfile(userId: UUID) async throws {
        let key = CacheKey.profile(userId: userId)
        try await invalidate(key)
    }

    // MARK: - Community Fridges Cache

    /// Get cached community fridges
    func getFridges(lat: Double, lng: Double, radius: Int) async throws -> [CommunityFridge]? {
        let key = CacheKey.fridges(lat: lat, lng: lng, radius: radius)
        return try await get(key)
    }

    /// Cache community fridges
    func setFridges(_ fridges: [CommunityFridge], lat: Double, lng: Double, radius: Int) async throws {
        let key = CacheKey.fridges(lat: lat, lng: lng, radius: radius)
        try await set(key, value: fridges, ttl: CacheTTL.fridges)
    }

    // MARK: - Cache Stats

    /// Get cache hit rate
    var hitRate: Double {
        let total = hits + misses
        guard total > 0 else { return 0 }
        return Double(hits) / Double(total)
    }

    /// Get cache statistics
    func getStats() -> CacheStats {
        CacheStats(hits: hits, misses: misses, hitRate: hitRate)
    }

    /// Reset cache statistics
    func resetStats() {
        hits = 0
        misses = 0
    }
}

// MARK: - Cache Stats

struct CacheStats: Sendable {
    let hits: Int
    let misses: Int
    let hitRate: Double
}

// MARK: - Cache-First Repository Wrapper

/// Wrapper that adds caching to any repository
actor CachedFeedRepository {
    private let repository: FeedRepository
    private let cache: CachingService

    init(repository: FeedRepository, cache: CachingService) {
        self.repository = repository
        self.cache = cache
    }

    /// Fetch listings with cache-first strategy
    func fetchListings(
        near location: Location,
        radius: Double,
        limit: Int,
        offset: Int,
    ) async throws -> [FoodItem] {
        // Only cache first page
        if offset == 0 {
            // Try cache first
            if let cached: [FoodItem] = try await cache.getListings(
                lat: location.latitude,
                lng: location.longitude,
                radius: Int(radius * 1000),
            ) {
                return cached
            }
        }

        // Fetch from database
        let listings = try await repository.fetchListings(
            near: location,
            radius: radius,
            limit: limit,
            offset: offset,
            excludeBlockedUsers: true,
        )

        // Cache first page results
        if offset == 0 {
            try await cache.setListings(
                listings,
                lat: location.latitude,
                lng: location.longitude,
                radius: Int(radius * 1000),
            )
        }

        return listings
    }

    /// Fetch categories with cache-first strategy
    func fetchCategories() async throws -> [Category] {
        // Try cache first
        if let cached: [Category] = try await cache.getCategories() {
            return cached
        }

        // Fetch from database
        let categories = try await repository.fetchCategories()

        // Cache results
        try await cache.setCategories(categories)

        return categories
    }

    /// Fetch community fridges with cache-first strategy
    func fetchCommunityFridges(
        near location: Location,
        radius: Double,
        limit: Int,
    ) async throws -> [CommunityFridge] {
        // Try cache first
        if let cached: [CommunityFridge] = try await cache.getFridges(
            lat: location.latitude,
            lng: location.longitude,
            radius: Int(radius * 1000),
        ) {
            return cached
        }

        // Fetch from database
        let fridges = try await repository.fetchCommunityFridges(
            near: location,
            radius: radius,
            limit: limit,
        )

        // Cache results
        try await cache.setFridges(
            fridges,
            lat: location.latitude,
            lng: location.longitude,
            radius: Int(radius * 1000),
        )

        return fridges
    }
}

#endif
