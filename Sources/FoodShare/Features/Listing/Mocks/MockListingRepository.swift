//
//  MockListingRepository.swift
//  Foodshare
//
//  Mock listing repository for previews
//


#if !SKIP
import Foundation

#if DEBUG
    /// Mock implementation of ListingRepository for previews
    final class MockListingRepository: ListingRepository, @unchecked Sendable {
        nonisolated(unsafe) var mockItem: FoodItem?
        nonisolated(unsafe) var mockArrangementHistory: [ArrangementRecord] = []
        nonisolated(unsafe) var shouldFail = false
        nonisolated(unsafe) var createCallCount = 0
        nonisolated(unsafe) var mockValidationResult = ListingValidationResult(
            valid: true,
            errors: [],
            sanitized: nil,
        )

        func validateListing(
            _ request: CreateListingRequest,
            imageUrls: [String],
        ) async throws -> ListingValidationResult {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return mockValidationResult
        }

        func createListing(_ request: CreateListingRequest) async throws -> FoodItem {
            createCallCount += 1
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 500_000_000)
            return mockItem ?? FoodItem.fixture(postName: request.title)
        }

        func updateListing(_ request: UpdateListingRequest) async throws -> FoodItem {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return mockItem ?? FoodItem.fixture()
        }

        func deleteListing(_ id: Int) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
        }

        func fetchListing(id: Int) async throws -> FoodItem {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return mockItem ?? FoodItem.fixture(id: id)
        }

        func fetchUserListings(userId: UUID) async throws -> [FoodItem] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return [mockItem ?? FoodItem.fixture()]
        }

        func uploadImages(_ imageData: [Data]) async throws -> [String] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return imageData.map { _ in "https://example.com/image.jpg" }
        }

        func arrangePost(postId: Int, requesterId: UUID) async throws -> FoodItem {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            var item = mockItem ?? FoodItem.fixture(id: postId)
            item.isArranged = true
            item.postArrangedTo = requesterId
            item.postArrangedAt = Date()
            return item
        }

        func cancelArrangement(postId: Int) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
        }

        func deactivatePost(postId: Int) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
        }

        func fetchArrangementHistory(userId: UUID) async throws -> [ArrangementRecord] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return mockArrangementHistory
        }

        func incrementViewCount(listingId: Int) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            // Mock: no-op
        }
    }
#endif

#endif
