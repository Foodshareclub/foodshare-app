//
//  DeleteListingUseCase.swift
//  Foodshare
//
//  Use case for deleting a food listing
//


#if !SKIP
import Foundation

/// Use case for deleting a food listing
@MainActor
final class DeleteListingUseCase {
    private let repository: ListingRepository

    init(repository: ListingRepository) {
        self.repository = repository
    }

    /// Execute delete listing
    /// - Parameter listingId: ID of the listing to delete
    func execute(listingId: Int) async throws {
        try await repository.deleteListing(listingId)
    }
}

#endif
