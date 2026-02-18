//
//  CreateListingUseCase.swift
//  Foodshare
//
//  Use case for creating a food listing
//


#if !SKIP
import Foundation

/// Use case for creating a new food listing
@MainActor
final class CreateListingUseCase {
    private let repository: ListingRepository

    init(repository: ListingRepository) {
        self.repository = repository
    }

    /// Execute create listing
    /// - Parameters:
    ///   - request: Create listing request
    ///   - userId: User ID
    /// - Returns: Created food listing
    func execute(_ request: CreateListingRequest, userId: UUID) async throws -> FoodItem {
        // Validate request
        try request.validate()

        // Create request with user ID using helper method
        let fullRequest = request.with(userId: userId)

        // Create listing
        return try await repository.createListing(fullRequest)
    }
}

#endif
