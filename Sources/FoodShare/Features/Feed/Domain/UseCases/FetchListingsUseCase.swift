//
//  FetchListingsUseCase.swift
//  Foodshare
//
//  Use case for fetching food listings with pagination support
//


#if !SKIP
import Foundation

/// Use case protocol for fetching food listings
protocol FetchListingsUseCase: Sendable {
    /// Execute fetch listings with pagination support
    /// - Parameters:
    ///   - location: User's current location
    ///   - radius: Search radius in kilometers
    ///   - categoryId: Optional category filter
    ///   - limit: Maximum results per page
    ///   - offset: Number of items to skip (for pagination)
    /// - Returns: Array of available food listings
    func execute(
        near location: Location,
        radius: Double,
        categoryId: Int?,
        limit: Int,
        offset: Int,
    ) async throws -> [FoodListing]
}

/// Default implementation of FetchListingsUseCase
final class DefaultFetchListingsUseCase: FetchListingsUseCase {
    private let repository: FeedRepository

    init(repository: FeedRepository) {
        self.repository = repository
    }

    func execute(
        near location: Location,
        radius: Double = 5.0,
        categoryId: Int? = nil,
        limit: Int = 50,
        offset: Int = 0,
    ) async throws -> [FoodListing] {
        // Validate radius (1-800 km)
        guard radius > 0, radius <= 800 else {
            throw AppError.validation(.outOfRange(field: "Search radius", min: 1, max: 800))
        }

        // Validate pagination parameters
        guard offset >= 0 else {
            throw AppError.validation(.custom("Offset must be non-negative"))
        }

        guard limit > 0, limit <= 100 else {
            throw AppError.validation(.outOfRange(field: "Limit", min: 1, max: 100))
        }

        // Fetch listings
        let listings: [FoodListing] = if let categoryId {
            try await repository.fetchListings(
                categoryId: categoryId,
                near: location,
                radius: radius,
                limit: limit,
                offset: offset,
                excludeBlockedUsers: true, // Filter blocked users from feed
            )
        } else {
            try await repository.fetchListings(
                near: location,
                radius: radius,
                limit: limit,
                offset: offset,
                excludeBlockedUsers: true, // Filter blocked users from feed
            )
        }

        // Filter out expired and unavailable items
        return listings.filter(\.isAvailable)
    }
}

#endif
