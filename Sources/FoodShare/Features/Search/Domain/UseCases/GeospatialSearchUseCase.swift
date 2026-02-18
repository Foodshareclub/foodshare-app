//
//  GeospatialSearchUseCase.swift
//  Foodshare
//
//  Use case for geospatial search operations
//


#if !SKIP
#if !SKIP
import CoreLocation
#endif
import Foundation

// MARK: - Search Parameters

struct GeospatialSearchParams: Sendable {
    let center: Location
    let radiusKm: Double
    let categoryId: Int?
    let postType: String?
    let limit: Int
    let offset: Int

    init(
        center: Location,
        radiusKm: Double = 5.0,
        categoryId: Int? = nil,
        postType: String? = nil,
        limit: Int = 50,
        offset: Int = 0,
    ) {
        self.center = center
        self.radiusKm = radiusKm
        self.categoryId = categoryId
        self.postType = postType
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - Search Result

struct SearchResult: Sendable {
    let items: [FoodItem]
    let totalCount: Int
    let searchCenter: Location
    let searchRadiusKm: Double
}

// MARK: - Geospatial Search Use Case

@MainActor
final class GeospatialSearchUseCase {
    private let repository: FeedRepository

    init(repository: FeedRepository) {
        self.repository = repository
    }

    /// Search for food items within radius
    func execute(params: GeospatialSearchParams) async throws -> SearchResult {
        let items: [FoodItem] = if let categoryId = params.categoryId {
            try await repository.fetchListings(
                categoryId: categoryId,
                near: params.center,
                radius: params.radiusKm,
                limit: params.limit,
                offset: params.offset,
                excludeBlockedUsers: true,
            )
        } else {
            try await repository.fetchListings(
                near: params.center,
                radius: params.radiusKm,
                limit: params.limit,
                offset: params.offset,
                excludeBlockedUsers: true,
            )
        }

        return SearchResult(
            items: items,
            totalCount: items.count,
            searchCenter: params.center,
            searchRadiusKm: params.radiusKm,
        )
    }

    /// Search in a specific map region
    func searchInRegion(
        center: Location,
        spanLatitude: Double,
        spanLongitude: Double,
        categoryId: Int? = nil,
    ) async throws -> [FoodItem] {
        // Calculate approximate radius from span
        let radiusKm = max(spanLatitude, spanLongitude) * 111.0 / 2.0 // ~111km per degree

        let params = GeospatialSearchParams(
            center: center,
            radiusKm: min(radiusKm, 50.0), // Cap at 50km
            categoryId: categoryId,
            limit: 100,
        )

        let result = try await execute(params: params)
        return result.items
    }
}

// MARK: - Distance Calculator

enum DistanceCalculator {
    /// Calculate distance between two coordinates using Haversine formula
    static func distance(from: Location, to: Location) -> Double {
        let earthRadiusKm = 6371.0

        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLat = (to.latitude - from.latitude) * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180

        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
            cos(lat1) * cos(lat2) *
            sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusKm * c
    }

    /// Format distance for display
    static func formatDistance(_ distanceKm: Double) -> String {
        if distanceKm < 1.0 {
            "\(Int(distanceKm * 1000))m"
        } else if distanceKm < 10.0 {
            String(format: "%.1fkm", distanceKm)
        } else {
            "\(Int(distanceKm))km"
        }
    }

    /// Format distance from meters
    static func formatMeters(_ meters: Double) -> String {
        if meters < 1000 {
            "\(Int(meters))m"
        } else {
            String(format: "%.1fkm", meters / 1000)
        }
    }
}

#endif
