//
//  AnalyticsAPIService.swift
//  Foodshare
//
//  Centralized API service for analytics
//

import Foundation

actor AnalyticsAPIService {
    nonisolated static let shared = AnalyticsAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func track(event: String, properties: [String: Any] = [:]) async throws {
        let _: EmptyResponse = try await client.post("api-v1-analytics/track", body: [
            "event": event,
            "properties": properties
        ])
    }
    
    func getStats(userId: String) async throws -> UserStats {
        try await client.get("api-v1-analytics/stats", params: ["userId": userId])
    }
}

struct UserStats: Codable {
    let totalPosts: Int
    let totalViews: Int
    let totalLikes: Int
}
