//
//  AnalyticsAPIService.swift
//  Foodshare
//
//  Centralized API service for analytics
//


#if !SKIP
import Foundation

actor AnalyticsAPIService {
    nonisolated static let shared = AnalyticsAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func track(event: String, properties: [String: String] = [:]) async throws {
        let _: EmptyResponse = try await client.post("api-v1-analytics/track", body: TrackEventBody(event: event, properties: properties))
    }
    
    func getStats(userId: String) async throws -> UserStats {
        try await client.get("api-v1-analytics/stats", params: ["userId": userId])
    }
}

private struct TrackEventBody: Encodable {
    let event: String
    let properties: [String: String]
}

#endif
