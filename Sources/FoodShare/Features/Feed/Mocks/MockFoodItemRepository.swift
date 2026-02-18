//
//  MockFoodItemRepository.swift
//  Foodshare
//
//  Mock food item repository for testing and previews
//


#if !SKIP
import CoreLocation
import Foundation

#if DEBUG
    final class MockFoodItemRepository: FoodItemRepository, @unchecked Sendable {
        nonisolated(unsafe) var mockItems: [FoodItem] = FoodItem.sampleListings
        nonisolated(unsafe) var shouldFail = false

        func fetchNearbyItems(location: CLLocationCoordinate2D, radiusKm: Double) async throws -> [FoodItem] {
            try await fetchNearbyItems(
                location: location,
                radiusKm: radiusKm,
                limit: 50,
                offset: 0,
                postType: nil,
            )
        }

        func fetchNearbyItems(
            location: CLLocationCoordinate2D,
            radiusKm: Double,
            limit: Int,
            offset: Int,
            postType: String?,
        ) async throws -> [FoodItem] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            var items = mockItems

            // Filter by post type if provided
            if let postType {
                items = items.filter { $0.postType == postType }
            }

            // Apply pagination
            let startIndex = min(offset, items.count)
            let endIndex = min(offset + limit, items.count)
            return Array(items[startIndex ..< endIndex])
        }

        func fetchItemById(_ id: Int) async throws -> FoodItem {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 200_000_000)

            guard let item = mockItems.first(where: { $0.id == id }) else {
                throw AppError.notFound(resource: "FoodItem")
            }
            return item
        }

        func fetchTrendingItems(
            location: CLLocationCoordinate2D,
            radiusKm: Double,
            limit: Int,
        ) async throws -> [FoodItem] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 200_000_000)

            // Mock trending: sort by engagement (views + likes*2)
            let sorted = mockItems.sorted { first, second in
                let firstEngagement = first.postViews + (first.postLikeCounter ?? 0) * 2
                let secondEngagement = second.postViews + (second.postLikeCounter ?? 0) * 2
                return firstEngagement > secondEngagement
            }
            return Array(sorted.prefix(limit))
        }

        func fetchFilteredFeed(
            location: CLLocationCoordinate2D,
            radiusKm: Double,
            limit: Int,
            offset: Int,
            postType: String?,
            categoryId: Int?,
            sortOption: String,
        ) async throws -> [FoodItem] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 200_000_000)

            var items = mockItems

            // Filter by post type
            if let postType {
                items = items.filter { $0.postType == postType }
            }

            // Filter by category
            if let categoryId {
                items = items.filter { $0.categoryId == categoryId }
            }

            // Apply sorting
            switch sortOption {
            case "newest":
                items.sort { $0.createdAt > $1.createdAt }
            case "expiring_soon":
                items.sort { $0.createdAt < $1.createdAt }
            case "popular":
                items.sort { $0.postViews > $1.postViews }
            default: // nearest - default order
                break
            }

            // Apply pagination
            let startIndex = min(offset, items.count)
            let endIndex = min(offset + limit, items.count)
            return Array(items[startIndex ..< endIndex])
        }
    }
#endif

#endif
