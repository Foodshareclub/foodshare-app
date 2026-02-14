//
//  MetricsAPIService.swift
//  Foodshare
//

import Foundation

actor MetricsAPIService {
    nonisolated static let shared = MetricsAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func recordMetric(name: String, value: Double, tags: [String: String] = [:]) async throws {
        let _: EmptyResponse = try await client.post("api-v1-metrics/record", body: ["name": name, "value": value, "tags": tags])
    }
    
    func recordRequest(endpoint: String, method: String, responseTimeMs: Int, statusCode: Int?, cacheHit: Bool) async throws {
        let _: EmptyResponse = try await client.post("api-v1-metrics/request", body: [
            "endpoint": endpoint,
            "method": method,
            "response_time_ms": responseTimeMs,
            "status_code": statusCode as Any,
            "cache_hit": cacheHit
        ])
    }
    
    func recordCircuitEvent(circuitName: String, state: String, failureCount: Int) async throws {
        let _: EmptyResponse = try await client.post("api-v1-metrics/circuit", body: [
            "circuit_name": circuitName,
            "state": state,
            "failure_count": failureCount
        ])
    }
    
    func recordAudit(operation: String, userId: String?, resourceType: String?, resourceId: String?, success: Bool) async throws {
        let _: EmptyResponse = try await client.post("api-v1-metrics/audit", body: [
            "operation": operation,
            "user_id": userId as Any,
            "resource_type": resourceType as Any,
            "resource_id": resourceId as Any,
            "success": success
        ])
    }
    
    func getMetrics(name: String, from: Date, to: Date) async throws -> [Metric] {
        try await client.get("api-v1-metrics", params: [
            "name": name,
            "from": ISO8601DateFormatter().string(from: from),
            "to": ISO8601DateFormatter().string(from: to)
        ])
    }
}

struct Metric: Codable {
    let name: String
    let value: Double
    let timestamp: Date
    let tags: [String: String]
}
