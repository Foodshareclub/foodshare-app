//
//  AppConfiguration.swift
//  FoodShare
//
//  Remote configuration service that fetches app settings from Supabase.
//  Eliminates hardcoded values and enables server-side configuration changes.
//


#if !SKIP
import Foundation
import Observation
import OSLog
import Supabase

/// Remote configuration service that fetches settings from Supabase `app_config` table.
/// Settings are cached locally for 24 hours and refreshed in the background.
@MainActor
@Observable
final class AppConfiguration {
    // MARK: - Singleton

    static let shared = AppConfiguration()

    // MARK: - Private

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AppConfiguration")
    private let cacheKey = "app_config_cache"
    private let cacheTimestampKey = "app_config_timestamp"
    private let cacheDuration: TimeInterval = 86400 // 24 hours
    private var isLoaded = false

    // MARK: - Pagination

    var pageSize = 20
    var maxPageSize = 100
    var mapMaxItems = 100

    // MARK: - Cache TTLs (seconds)

    var listingsCacheTTL: TimeInterval = 300
    var categoriesCacheTTL: TimeInterval = 3600
    var profileCacheTTL: TimeInterval = 600
    var feedCacheTTL: TimeInterval = 180

    // MARK: - Image Uploads

    var maxImages = 5
    var maxImageSizeMB = 5
    var maxImageDimension = 1200
    var jpegQuality = 0.8

    /// Max image size in bytes (computed from MB)
    var maxImageSizeBytes: Int {
        maxImageSizeMB * 1_000_000
    }

    // MARK: - Impact Multipliers

    var foodKgPerItem = 0.5
    var co2KgPerItem = 2.5
    var waterLitersPerItem: Double = 100
    var moneyUsdPerItem = 5.0

    // MARK: - Gamification

    var xpPerShare = 15
    var xpPerReceive = 8
    var xpPerReview = 5
    var xpRatingBonus = 10

    // MARK: - Network

    var requestTimeoutSeconds = 30
    var resourceTimeoutSeconds = 60
    var maxRetries = 3

    // MARK: - Location

    var defaultSearchRadiusKm: Double = 5
    var extendedSearchRadiusKm: Double = 10
    var maxSearchRadiusKm: Double = 800
    var locationUpdateDistanceM: Double = 100

    // MARK: - Rate Limits

    var maxInvitationsPerRequest = 10
    var searchDebounceMs = 300

    /// Search debounce as TimeInterval (computed from ms)
    var searchDebounceInterval: TimeInterval {
        Double(searchDebounceMs) / 1000.0
    }

    // MARK: - Initialization

    private init() {
        // Load from cache immediately on init
        loadFromCache()
    }

    // MARK: - Public Methods

    /// Load configuration from server. Call this on app launch.
    /// Uses cached values if available and fresh, refreshes in background if stale.
    func loadFromServer(supabase: Supabase.SupabaseClient) async {
        // If cache is fresh, use it and refresh in background
        if isCacheFresh() {
            logger.info("Using cached config, refreshing in background")
            Task.detached { [weak self] in
                await self?.refreshFromServer(supabase: supabase)
            }
            return
        }

        // Cache is stale or missing, fetch synchronously
        await refreshFromServer(supabase: supabase)
    }

    /// Force refresh configuration from server
    func forceRefresh(supabase: Supabase.SupabaseClient) async {
        await refreshFromServer(supabase: supabase)
    }

    // MARK: - Private Methods

    private func refreshFromServer(supabase: Supabase.SupabaseClient) async {
        do {
            // Call the RPC function
            let response: AppConfigResponse = try await supabase
                .rpc("get_app_config", params: ["p_platform": "ios"])
                .execute()
                .value

            await MainActor.run {
                applyConfig(response)
                saveToCache(response)
                isLoaded = true
            }
            logger.info("Loaded config from server")
        } catch {
            logger.error("Failed to load config from server: \(error.localizedDescription)")
            // Keep using defaults/cached values
        }
    }

    private func applyConfig(_ config: AppConfigResponse) {
        // Pagination
        if let pagination = config.pagination {
            pageSize = pagination.pageSize ?? pageSize
            maxPageSize = pagination.maxPageSize ?? maxPageSize
            mapMaxItems = pagination.mapMaxItems ?? mapMaxItems
        }

        // Cache
        if let cache = config.cache {
            listingsCacheTTL = cache.listingsTTL ?? listingsCacheTTL
            categoriesCacheTTL = cache.categoriesTTL ?? categoriesCacheTTL
            profileCacheTTL = cache.profileTTL ?? profileCacheTTL
            feedCacheTTL = cache.feedTTL ?? feedCacheTTL
        }

        // Uploads
        if let uploads = config.uploads {
            maxImages = uploads.maxImages ?? maxImages
            maxImageSizeMB = uploads.maxImageSizeMB ?? maxImageSizeMB
            maxImageDimension = uploads.maxImageDimension ?? maxImageDimension
            jpegQuality = uploads.jpegQuality ?? jpegQuality
        }

        // Impact
        if let impact = config.impact {
            foodKgPerItem = impact.foodKgPerItem ?? foodKgPerItem
            co2KgPerItem = impact.co2KgPerItem ?? co2KgPerItem
            waterLitersPerItem = impact.waterLitersPerItem ?? waterLitersPerItem
            moneyUsdPerItem = impact.moneyUsdPerItem ?? moneyUsdPerItem
        }

        // Gamification
        if let gamification = config.gamification {
            xpPerShare = gamification.xpPerShare ?? xpPerShare
            xpPerReceive = gamification.xpPerReceive ?? xpPerReceive
            xpPerReview = gamification.xpPerReview ?? xpPerReview
            xpRatingBonus = gamification.xpRatingBonus ?? xpRatingBonus
        }

        // Network
        if let network = config.network {
            requestTimeoutSeconds = network.requestTimeoutSeconds ?? requestTimeoutSeconds
            resourceTimeoutSeconds = network.resourceTimeoutSeconds ?? resourceTimeoutSeconds
            maxRetries = network.maxRetries ?? maxRetries
        }

        // Location
        if let location = config.location {
            defaultSearchRadiusKm = location.defaultSearchRadiusKm ?? defaultSearchRadiusKm
            extendedSearchRadiusKm = location.extendedSearchRadiusKm ?? extendedSearchRadiusKm
            maxSearchRadiusKm = location.maxSearchRadiusKm ?? maxSearchRadiusKm
            locationUpdateDistanceM = location.locationUpdateDistanceM ?? locationUpdateDistanceM
        }

        // Rate limits
        if let rateLimits = config.rateLimits {
            maxInvitationsPerRequest = rateLimits.maxInvitationsPerRequest ?? maxInvitationsPerRequest
            searchDebounceMs = rateLimits.searchDebounceMs ?? searchDebounceMs
        }
    }

    // MARK: - Cache Management

    private func isCacheFresh() -> Bool {
        let defaults = UserDefaults.standard
        let timestamp = defaults.double(forKey: cacheTimestampKey)
        guard timestamp > 0 else { return false }
        return Date().timeIntervalSince1970 - timestamp < cacheDuration
    }

    private func loadFromCache() {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: cacheKey) else { return }

        do {
            let config = try JSONDecoder().decode(AppConfigResponse.self, from: data)
            applyConfig(config)
            isLoaded = true
            logger.debug("Loaded config from cache")
        } catch {
            logger.warning("Failed to decode cached config: \(error.localizedDescription)")
        }
    }

    private func saveToCache(_ config: AppConfigResponse) {
        do {
            let data = try JSONEncoder().encode(config)
            let defaults = UserDefaults.standard
            defaults.set(data, forKey: cacheKey)
            defaults.set(Date().timeIntervalSince1970, forKey: cacheTimestampKey)
            logger.debug("Saved config to cache")
        } catch {
            logger.warning("Failed to cache config: \(error.localizedDescription)")
        }
    }
}

// MARK: - Response Models

/// Root response from get_app_config RPC
struct AppConfigResponse: Codable, Sendable {
    let pagination: PaginationConfig?
    let cache: CacheConfig?
    let uploads: UploadsConfig?
    let impact: ImpactConfig?
    let gamification: GamificationConfig?
    let network: NetworkConfig?
    let location: LocationConfig?
    let rateLimits: RateLimitsConfig?

    enum CodingKeys: String, CodingKey {
        case pagination, cache, uploads, impact, gamification, network, location
        case rateLimits = "rate_limits"
    }
}

struct PaginationConfig: Codable, Sendable {
    let pageSize: Int?
    let maxPageSize: Int?
    let mapMaxItems: Int?

    enum CodingKeys: String, CodingKey {
        case pageSize = "page_size"
        case maxPageSize = "max_page_size"
        case mapMaxItems = "map_max_items"
    }
}

struct CacheConfig: Codable, Sendable {
    let listingsTTL: TimeInterval?
    let categoriesTTL: TimeInterval?
    let profileTTL: TimeInterval?
    let feedTTL: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case listingsTTL = "cache_listings_ttl"
        case categoriesTTL = "cache_categories_ttl"
        case profileTTL = "cache_profile_ttl"
        case feedTTL = "cache_feed_ttl"
    }
}

struct UploadsConfig: Codable, Sendable {
    let maxImages: Int?
    let maxImageSizeMB: Int?
    let maxImageDimension: Int?
    let jpegQuality: Double?

    enum CodingKeys: String, CodingKey {
        case maxImages = "max_images"
        case maxImageSizeMB = "max_image_size_mb"
        case maxImageDimension = "max_image_dimension"
        case jpegQuality = "jpeg_quality"
    }
}

struct ImpactConfig: Codable, Sendable {
    let foodKgPerItem: Double?
    let co2KgPerItem: Double?
    let waterLitersPerItem: Double?
    let moneyUsdPerItem: Double?

    enum CodingKeys: String, CodingKey {
        case foodKgPerItem = "food_kg_per_item"
        case co2KgPerItem = "co2_kg_per_item"
        case waterLitersPerItem = "water_liters_per_item"
        case moneyUsdPerItem = "money_usd_per_item"
    }
}

struct GamificationConfig: Codable, Sendable {
    let xpPerShare: Int?
    let xpPerReceive: Int?
    let xpPerReview: Int?
    let xpRatingBonus: Int?

    enum CodingKeys: String, CodingKey {
        case xpPerShare = "xp_per_share"
        case xpPerReceive = "xp_per_receive"
        case xpPerReview = "xp_per_review"
        case xpRatingBonus = "xp_rating_bonus"
    }
}

struct NetworkConfig: Codable, Sendable {
    let requestTimeoutSeconds: Int?
    let resourceTimeoutSeconds: Int?
    let maxRetries: Int?

    enum CodingKeys: String, CodingKey {
        case requestTimeoutSeconds = "request_timeout_seconds"
        case resourceTimeoutSeconds = "resource_timeout_seconds"
        case maxRetries = "max_retries"
    }
}

struct LocationConfig: Codable, Sendable {
    let defaultSearchRadiusKm: Double?
    let extendedSearchRadiusKm: Double?
    let maxSearchRadiusKm: Double?
    let locationUpdateDistanceM: Double?

    enum CodingKeys: String, CodingKey {
        case defaultSearchRadiusKm = "default_search_radius_km"
        case extendedSearchRadiusKm = "extended_search_radius_km"
        case maxSearchRadiusKm = "max_search_radius_km"
        case locationUpdateDistanceM = "location_update_distance_m"
    }
}

struct RateLimitsConfig: Codable, Sendable {
    let maxInvitationsPerRequest: Int?
    let searchDebounceMs: Int?

    enum CodingKeys: String, CodingKey {
        case maxInvitationsPerRequest = "max_invitations_per_request"
        case searchDebounceMs = "search_debounce_ms"
    }
}

#endif
