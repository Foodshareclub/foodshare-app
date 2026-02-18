//
//  MockActivityRepository.swift
//  Foodshare
//
//  Mock activity repository for testing and previews
//


#if !SKIP
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
#endif

#endif
