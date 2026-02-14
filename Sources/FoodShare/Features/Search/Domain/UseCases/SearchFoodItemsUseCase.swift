//
//  SearchFoodItemsUseCase.swift
//  Foodshare
//
//  Use case for searching food items
//

#if !SKIP
import CoreLocation
#endif
import Foundation

@MainActor
final class SearchFoodItemsUseCase {
    private let repository: SearchRepository

    init(repository: SearchRepository) {
        self.repository = repository
    }

    func execute(query: SearchQuery) async throws -> [FoodItem] {
        // Validate radius
        guard query.radiusKm >= 1, query.radiusKm <= 800 else {
            throw SearchError.invalidRadius
        }

        var results = try await repository.searchFoodItems(query: query)

        // Filter to only available items
        results = results.filter(\.isAvailable)

        // Sort results
        results = sortResults(results, by: query.sortBy, location: query.location)

        return results
    }

    private func sortResults(
        _ items: [FoodItem],
        by sortOption: SearchSortOption,
        location: CLLocationCoordinate2D,
    ) -> [FoodItem] {
        switch sortOption {
        case .distance:
            items.sorted { item1, item2 in
                let dist1 = calculateDistance(from: location, to: item1)
                let dist2 = calculateDistance(from: location, to: item2)
                return dist1 < dist2
            }
        case .newest:
            items.sorted { $0.createdAt > $1.createdAt }
        case .expiringSoon:
            // Sort by created date since we don't have expiry date in new schema
            items.sorted { $0.createdAt < $1.createdAt }
        }
    }

    private func calculateDistance(from: CLLocationCoordinate2D, to item: FoodItem) -> Double {
        guard let latitude = item.latitude, let longitude = item.longitude else {
            return Double.greatestFiniteMagnitude // Items without location go to end
        }
        let location1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let location2 = CLLocation(latitude: latitude, longitude: longitude)
        return location1.distance(from: location2) / 1000.0 // Convert to km
    }
}

/// Errors that can occur during search operations.
///
/// Thread-safe for Swift 6 concurrency.
enum SearchError: LocalizedError, Sendable {
    /// Search radius is outside valid range
    case invalidRadius
    /// No matching results found
    case noResults

    var errorDescription: String? {
        switch self {
        case .invalidRadius:
            "Search radius must be between 1 and 800 km"
        case .noResults:
            "No results found"
        }
    }
}
