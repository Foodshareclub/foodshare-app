//
//  FetchNearbyFridgesUseCase.swift
//  Foodshare
//
//  Use case for fetching nearby community fridges
//


#if !SKIP
import Foundation

/// Use case for fetching community fridges near a location
@MainActor
final class FetchNearbyFridgesUseCase {
    private let repository: FeedRepository

    init(repository: FeedRepository) {
        self.repository = repository
    }

    /// Fetch community fridges within radius of location
    /// - Parameters:
    ///   - location: Center point for search
    ///   - radius: Search radius in kilometers (default 10km)
    ///   - limit: Maximum results (default 50)
    /// - Returns: Array of community fridges sorted by distance
    func execute(
        near location: Location,
        radius: Double = 10.0,
        limit: Int = 50,
    ) async throws -> [CommunityFridge] {
        try await repository.fetchCommunityFridges(
            near: location,
            radius: radius,
            limit: limit,
        )
    }
}

#endif
