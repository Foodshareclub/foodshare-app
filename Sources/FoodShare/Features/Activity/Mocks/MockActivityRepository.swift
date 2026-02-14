//
//  MockActivityRepository.swift
//  Foodshare
//
//  Mock activity repository for testing and previews
//

import Foundation

#if DEBUG
    final class MockActivityRepository: ActivityRepository, @unchecked Sendable {
        nonisolated(unsafe) var mockActivities: [ActivityItem] = []
        nonisolated(unsafe) var cachedActivities: [ActivityItem] = []
        nonisolated(unsafe) var shouldFail = false

        init() {
            // Initialize with sample data
            mockActivities = ActivityItem.sampleActivities
        }

        func fetchActivities(offset: Int, limit: Int) async throws -> [ActivityItem] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            let startIndex = min(offset, mockActivities.count)
            let endIndex = min(offset + limit, mockActivities.count)
            return Array(mockActivities[startIndex ..< endIndex])
        }

        func fetchCachedActivities() async -> [ActivityItem] {
            cachedActivities
        }

        func cacheActivities(_ activities: [ActivityItem]) async throws {
            if shouldFail {
                throw AppError.databaseError("Mock cache error")
            }
            cachedActivities = activities
        }
    }

    // MARK: - Sample Data

    extension ActivityItem {
        static var sampleActivities: [ActivityItem] {
            [
                ActivityItem(
                    id: 1,
                    type: .listing,
                    title: "New listing posted",
                    subtitle: "Fresh vegetables available",
                    timestamp: Date().addingTimeInterval(-3600),
                    imageUrl: nil,
                    metadata: [:],
                ),
                ActivityItem(
                    id: 2,
                    type: .challenge,
                    title: "Challenge completed",
                    subtitle: "Zero Waste Week completed!",
                    timestamp: Date().addingTimeInterval(-7200),
                    imageUrl: nil,
                    metadata: [:],
                ),
                ActivityItem(
                    id: 3,
                    type: .message,
                    title: "New message",
                    subtitle: "You have a new message from FoodHero",
                    timestamp: Date().addingTimeInterval(-10800),
                    imageUrl: nil,
                    metadata: [:],
                )
            ]
        }
    }
#endif
