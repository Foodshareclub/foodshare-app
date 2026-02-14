//
//  MapViewModel.swift
//  Foodshare
//
//  ViewModel for the food map view, managing location-based food item discovery.
//

#if !SKIP
import CoreLocation
#endif
import FoodShareNetworking
import FoodShareRepository
import Foundation
#if !SKIP
import MapKit
#endif
import OSLog

/// ViewModel for the map view that displays food items near the user's location.
@MainActor
@Observable
final class MapViewModel {
    // MARK: - Types

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "MapViewModel")

    // MARK: - Map State
    var region = MKCoordinateRegion(
        center: .defaultFallback,
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1),
    )

    var items: [FoodItem] = []
    var isLoading = false
    var userLocation: CLLocationCoordinate2D?
    var locationDenied = false
    var detailedLocationSource: DetailedLocationSource = .none
    var networkQuality: MapNetworkQuality = .medium
    var engagementStatuses: [Int: PostEngagementStatus] = [:]
    var selectedPostType: String?
    private var allItems: [FoodItem] = []

    // MARK: - Cache Configuration

    /// Engagement status cache with timestamps for TTL checking
    private var engagementCache: [Int: (status: PostEngagementStatus, timestamp: Date)] = [:]
    /// Engagement cache TTL: 2 minutes
    private let engagementCacheTTL: TimeInterval = 120
    /// Debouncer for region changes (500ms)
    private let regionChangeDebouncer = Debouncer(delay: 0.5)

    /// Equatable wrapper for location coordinates to enable proper `onChange` tracking with `@Observable`.
    struct LocationCoords: Equatable {
        let latitude: Double
        let longitude: Double
    }

    var userLocationCoords: LocationCoords? {
        guard let userLocation else { return nil }
        return LocationCoords(latitude: userLocation.latitude, longitude: userLocation.longitude)
    }

    // MARK: - Services
    private let locationManager = LocationManager()
    private let feedRepository: any FeedRepository

    // MARK: - Initialization

    init(feedRepository: any FeedRepository) {
        self.feedRepository = feedRepository
        Task {
            await initializeMapPreferences()
            await detectNetworkQuality()
        }
    }

    private func initializeMapPreferences() async {
        // MapPreferencesService not yet available
    }

    private func detectNetworkQuality() async {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            guard let url = URL(string: "https://httpbin.org/bytes/1024") else {
                networkQuality = .low
                logger.warning("Invalid URL for network quality detection")
                return
            }
            _ = try await URLSession.shared.data(from: url)
            let latency = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

            networkQuality = latency < 100 ? .high : latency < 300 ? .medium : .low
            logger.info("Network quality detected: \(self.networkQuality) (latency: \(latency)ms)")
        } catch {
            networkQuality = .low
            logger.warning("Network quality detection failed, defaulting to low")
        }
    }

    // MARK: - Map Preferences

    func onMapRegionChanged(_ newRegion: MKCoordinateRegion) {
        region = newRegion

        // Debounce item loading to prevent request storms during pan/zoom
        Task {
            await regionChangeDebouncer.debounce { [weak self] in
                guard let self else { return }
                await self.loadItems(near: newRegion.center)
            }
        }
    }

    private func loadSavedMapState() async {
        // MapPreferencesService not yet available
    }

    // MARK: - Data Loading

    func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }

        // Load user location
        await loadUserLocation()

        // Load items near user location or default location
        let center = userLocation ?? .defaultFallback
        await loadItems(near: center)
    }

    func loadItems(near coordinate: CLLocationCoordinate2D) async {
        let radius = detailedLocationSource.searchRadiusKm
        let location = Location(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let pagination = CursorPaginationParams(limit: networkQuality == .low ? 50 : 100, cursor: nil)

        do {
            allItems = try await feedRepository.fetchListings(
                near: location,
                radius: radius,
                pagination: pagination,
                excludeBlockedUsers: true,
            )
            applyPostTypeFilter()
            logger
                .info("✅ Loaded \(self.allItems.count) real items near \(coordinate.latitude), \(coordinate.longitude)")

            // Load engagement statuses after items are loaded
            await loadEngagementStatuses()
        } catch {
            logger.error("❌ Failed to load food items: \(error.localizedDescription)")
            // Show error to user instead of hiding it with mock data
            allItems = []
            applyPostTypeFilter()
        }
    }

    func filterByPostType(_ postType: String?) {
        selectedPostType = postType
        applyPostTypeFilter()
    }

    private func applyPostTypeFilter() {
        if let postType = selectedPostType {
            items = allItems.filter { $0.postType == postType }
        } else {
            items = allItems
        }
    }

    private func createMockItems(near coordinate: CLLocationCoordinate2D) -> [FoodItem] {
        // Mock items removed - app should only show real data
        []
    }

    // MARK: - Engagement Methods

    @MainActor
    func toggleLike(for item: FoodItem) async {
        do {
            let (isLiked, likeCount) = try await PostEngagementService.shared.toggleLike(postId: item.id)
            engagementStatuses[item.id] = PostEngagementStatus(
                isLiked: isLiked,
                isBookmarked: engagementStatuses[item.id]?.isBookmarked ?? false,
                likeCount: likeCount,
            )
        } catch {
            logger.error("Failed to toggle like: \(error)")
        }
    }

    @MainActor
    func toggleBookmark(for item: FoodItem) async {
        do {
            let isBookmarked = try await PostEngagementService.shared.toggleBookmark(postId: item.id)
            engagementStatuses[item.id] = PostEngagementStatus(
                isLiked: engagementStatuses[item.id]?.isLiked ?? false,
                isBookmarked: isBookmarked,
                likeCount: engagementStatuses[item.id]?.likeCount ?? 0,
            )
        } catch {
            logger.error("Failed to toggle bookmark: \(error)")
        }
    }

    @MainActor
    func loadEngagementStatuses() async {
        let postIds = items.map(\.id)
        guard !postIds.isEmpty else { return }

        // Filter out items that are already cached and still valid
        let now = Date()
        let uncachedIds = postIds.filter { id in
            guard let cached = engagementCache[id] else { return true }
            return now.timeIntervalSince(cached.timestamp) >= engagementCacheTTL
        }

        // Use cached values for items we already have
        for id in postIds {
            if let cached = engagementCache[id], now.timeIntervalSince(cached.timestamp) < engagementCacheTTL {
                engagementStatuses[id] = cached.status
            }
        }

        // Only fetch uncached items
        guard !uncachedIds.isEmpty else {
            logger.debug("All engagement statuses from cache")
            return
        }

        do {
            let statuses = try await PostEngagementService.shared.getBatchEngagementStatus(postIds: uncachedIds)

            // Update both the display statuses and the cache
            for (id, status) in statuses {
                engagementStatuses[id] = status
                engagementCache[id] = (status: status, timestamp: now)
            }

            logger
                .debug("Loaded \(statuses.count) engagement statuses, \(postIds.count - uncachedIds.count) from cache")
        } catch {
            logger.error("Failed to load engagement statuses: \(error)")
        }
    }

    private func loadUserLocation() async {
        do {
            let location = try await locationManager.getCurrentLocation()
            userLocation = location.coordinate
            detailedLocationSource = .gps(accuracy: 10.0) // Default accuracy since Location doesn't provide it
            locationDenied = false
            logger.info("User location loaded: \(location.latitude), \(location.longitude)")
        } catch {
            logger.error("Failed to get user location: \(error)")
            locationDenied = true
            detailedLocationSource = .none
        }
    }

    func recenterOnUser() async {
        await loadUserLocation()
    }

    func clearLocationOverride() async {
        // Implementation for clearing location override
        await loadUserLocation()
    }
}

// MARK: - Default Coordinates

extension CLLocationCoordinate2D {
    /// Default fallback location (San Francisco)
    static let defaultFallback = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
}

// MARK: - Supporting Types

enum DetailedLocationSource {
    case gps(accuracy: Double)
    case ipGeolocation(confidence: IPLocationConfidence, city: String?)
    case userOverride(city: String?)
    case none

    var shouldShowBanner: Bool {
        switch self {
        case let .gps(accuracy):
            accuracy > 1000 // Show banner for poor GPS accuracy
        case .ipGeolocation:
            true // Always show for IP-based location
        case .userOverride:
            true // Show for manual override
        case .none:
            true // Show when no location available
        }
    }

    var searchRadiusKm: Double {
        switch self {
        case let .gps(accuracy):
            accuracy < 100 ? 10.0 : 25.0
        case let .ipGeolocation(confidence, _):
            confidence.suggestedSearchRadiusKm
        case .userOverride:
            15.0
        case .none:
            50.0
        }
    }
}

enum IPLocationConfidence {
    case high, medium, low, veryLow

    var suggestedSearchRadiusKm: Double {
        switch self {
        case .high: 15.0
        case .medium: 25.0
        case .low: 50.0
        case .veryLow: 100.0
        }
    }
}

enum MapNetworkQuality: CustomStringConvertible {
    case high, medium, low

    var description: String {
        switch self {
        case .high: "high"
        case .medium: "medium"
        case .low: "low"
        }
    }
}
