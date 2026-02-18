//
//  FetchNearbyItemsUseCase.swift
//  Foodshare
//
//  Fetch nearby food items use case
//



#if !SKIP
#if !SKIP
import CoreLocation
#endif
import Foundation

protocol FetchNearbyItemsUseCase: Sendable {
    func execute(location: CLLocationCoordinate2D, radiusKm: Double) async throws -> [FoodItem]
    func execute(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
        offset: Int,
        postType: String?,
    ) async throws -> [FoodItem]

    /// Fetch trending items via server-side engagement scoring
    func fetchTrending(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
    ) async throws -> [FoodItem]
}

final class DefaultFetchNearbyItemsUseCase: FetchNearbyItemsUseCase {
    private let repository: FoodItemRepository

    init(repository: FoodItemRepository) {
        self.repository = repository
    }

    func execute(location: CLLocationCoordinate2D, radiusKm: Double) async throws -> [FoodItem] {
        try await execute(location: location, radiusKm: radiusKm, limit: 50, offset: 0, postType: nil)
    }

    func execute(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
        offset: Int,
        postType: String? = nil,
    ) async throws -> [FoodItem] {
        await AppLogger.shared
            .debug("execute() called with radius=\(radiusKm)km limit=\(limit) postType=\(postType ?? "all")")

        // Validate radius
        guard radiusKm > 0, radiusKm <= 800 else {
            await AppLogger.shared.warning("Invalid radius: \(radiusKm)")
            throw FeedError.invalidRadius
        }

        // Validate pagination
        guard limit > 0, limit <= 100 else {
            await AppLogger.shared.warning("Invalid pagination limit: \(limit)")
            throw FeedError.invalidPagination
        }

        // Fetch items with pagination
        await AppLogger.shared.debug("Fetching nearby items from repository...")
        let items = try await repository.fetchNearbyItems(
            location: location,
            radiusKm: radiusKm,
            limit: limit,
            offset: offset,
            postType: postType,
        )
        await AppLogger.shared.debug("Repository returned \(items.count) items")

        // Filter out expired items
        let available = items.filter(\.isAvailable)
        await AppLogger.shared.debug("After filtering: \(available.count) available items")
        return available
    }

    func fetchTrending(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
    ) async throws -> [FoodItem] {
        await AppLogger.shared.debug("fetchTrending() called with radius=\(radiusKm)km limit=\(limit)")

        // Validate radius
        guard radiusKm > 0, radiusKm <= 800 else {
            await AppLogger.shared.warning("Invalid radius: \(radiusKm)")
            throw FeedError.invalidRadius
        }

        // Fetch trending items from repository (server-side scoring)
        let items = try await repository.fetchTrendingItems(
            location: location,
            radiusKm: radiusKm,
            limit: limit,
        )
        await AppLogger.shared.debug("fetchTrending returned \(items.count) items")

        // Filter out unavailable items
        return items.filter(\.isAvailable)
    }
}

/// Errors that can occur during feed operations.
///
/// Thread-safe for Swift 6 concurrency.
enum FeedError: LocalizedError, Sendable {
    /// Search radius is outside valid range (1-800 km)
    case invalidRadius
    /// Pagination parameters are invalid
    case invalidPagination
    /// Network request failed
    case networkError(String)
    /// Data fetch operation failed
    case fetchFailed(String)
    /// Requested item was not found
    case notFound
    /// User is not authorized for this operation
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidRadius:
            "Search radius must be between 1 and 800 km"
        case .invalidPagination:
            "Invalid pagination parameters"
        case let .networkError(message):
            message
        case let .fetchFailed(message):
            message
        case .notFound:
            "The requested item could not be found"
        case .unauthorized:
            "You don't have permission to perform this action"
        }
    }
}


#endif
