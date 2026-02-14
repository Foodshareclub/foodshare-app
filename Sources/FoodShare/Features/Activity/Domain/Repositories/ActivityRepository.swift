//
//  ActivityRepository.swift
//  Foodshare
//
//  Repository protocol for activity feed operations
//

import Foundation

/// Repository for managing activity feed data
protocol ActivityRepository: Sendable {
    /// Fetch recent activities with pagination
    /// - Parameters:
    ///   - offset: Starting position for pagination
    ///   - limit: Number of items to fetch
    /// - Returns: Array of activity items
    func fetchActivities(offset: Int, limit: Int) async throws -> [ActivityItem]

    /// Fetch cached activities if available
    /// - Returns: Cached activities or empty array
    func fetchCachedActivities() async -> [ActivityItem]

    /// Cache activities for offline access
    /// - Parameter activities: Activities to cache
    func cacheActivities(_ activities: [ActivityItem]) async throws
}
