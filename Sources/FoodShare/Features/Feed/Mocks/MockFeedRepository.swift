//
//  MockFeedRepository.swift
//  Foodshare
//
//  Mock feed repository for testing and previews
//

import Foundation

#if DEBUG
    final class MockFeedRepository: FeedRepository, @unchecked Sendable {
        nonisolated(unsafe) var mockListings: [FoodItem] = []
        nonisolated(unsafe) var mockCategories: [Category] = Category.defaultCategories
        nonisolated(unsafe) var mockFridges: [CommunityFridge] = []
        nonisolated(unsafe) var shouldFail = false
        nonisolated(unsafe) var fetchCallCount = 0

        init() {
            // Initialize with sample data
            mockListings = FoodItem.sampleListings
            mockFridges = CommunityFridge.sampleFridges
        }

        // MARK: - Cursor-Based Pagination

        func fetchListings(
            near location: Location,
            radius: Double,
            pagination: CursorPaginationParams,
            excludeBlockedUsers: Bool = true,
        ) async throws -> [FoodItem] {
            fetchCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000)

            return Array(mockListings.prefix(pagination.limit))
        }

        func fetchListings(
            categoryId: Int,
            near location: Location,
            radius: Double,
            pagination: CursorPaginationParams,
            excludeBlockedUsers: Bool = true,
        ) async throws -> [FoodItem] {
            fetchCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000)

            return mockListings.filter { $0.categoryId == categoryId }
        }

        // MARK: - Offset-Based Pagination (Legacy)

        func fetchListings(
            near location: Location,
            radius: Double,
            limit: Int,
            offset: Int,
            excludeBlockedUsers: Bool = true,
        ) async throws -> [FoodItem] {
            fetchCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            return Array(mockListings.prefix(limit))
        }

        func fetchListings(
            categoryId: Int,
            near location: Location,
            radius: Double,
            limit: Int,
            offset: Int,
            excludeBlockedUsers: Bool = true,
        ) async throws -> [FoodItem] {
            fetchCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000)

            return mockListings.filter { $0.categoryId == categoryId }
        }

        func fetchListing(id: Int) async throws -> FoodItem {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            guard let listing = mockListings.first(where: { $0.id == id }) else {
                throw AppError.notFound(resource: "FoodListing")
            }

            return listing
        }

        func fetchCategories() async throws -> [Category] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 300_000_000)

            return mockCategories
        }

        func incrementViewCount(listingId: Int) async throws {
            // No-op for mock
        }

        func fetchCommunityFridges(
            near location: Location,
            radius: Double,
            limit: Int,
        ) async throws -> [CommunityFridge] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 300_000_000)

            return Array(mockFridges.prefix(limit))
        }

        func fetchInitialData(
            location: Location,
            radius: Double,
            feedLimit: Int,
            trendingLimit: Int,
            postType: String?,
            categoryId: Int?,
        ) async throws -> FeedInitialData {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 300_000_000)

            return FeedInitialData(
                categories: mockCategories,
                feedItems: Array(mockListings.prefix(feedLimit)),
                trendingItems: Array(mockListings.prefix(trendingLimit)),
                stats: FeedStats(
                    totalItems: mockListings.count,
                    availableItems: mockListings.count,
                    expiringSoonItems: 0,
                    categoryBreakdown: [:],
                    lastUpdated: Date(),
                ),
            )
        }
    }
#endif
