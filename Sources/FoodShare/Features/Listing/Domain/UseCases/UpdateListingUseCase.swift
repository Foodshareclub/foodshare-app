//
//  UpdateListingUseCase.swift
//  Foodshare
//
//  Use case for updating a food listing
//


#if !SKIP
import Foundation

/// Use case for updating an existing food listing
@MainActor
final class UpdateListingUseCase {
    private let repository: ListingRepository

    init(repository: ListingRepository) {
        self.repository = repository
    }

    /// Execute update listing
    /// - Parameter request: Update listing request
    /// - Returns: Updated food listing
    func execute(_ request: UpdateListingRequest) async throws -> FoodListing {
        // Validate request
        try request.validate()

        // Update listing
        return try await repository.updateListing(request)
    }
}

#endif
