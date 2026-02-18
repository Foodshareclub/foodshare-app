//
//  MetricsAPIService.swift
//  Foodshare
//


#if !SKIP
import Foundation

// MARK: - Request Bodies

private struct RecordMetricBody: Encodable {
    let name: String
    let value: Double
    let tags: [String: String]
}

private struct RecordRequestBody: Encodable {
    let endpoint: String
    let method: String
    let responseTimeMs: Int
    let statusCode: Int?
    let cacheHit: Bool

    enum CodingKeys: String, CodingKey {
        case endpoint, method
        case responseTimeMs = "response_time_ms"
        case statusCode = "status_code"
        case cacheHit = "cache_hit"
    }
}

private struct RecordCircuitBody: Encodable {
    let circuitName: String
    let state: String
    let failureCount: Int

    enum CodingKeys: String, CodingKey {
        case circuitName = "circuit_name"
        case state
        case failureCount = "failure_count"
    }
}

private struct RecordAuditBody: Encodable {
    let operation: String
    let userId: String?
    let resourceType: String?
    let resourceId: String?
    let success: Bool

    enum CodingKeys: String, CodingKey {
        case operation
        case userId = "user_id"
        case resourceType = "resource_type"
        case resourceId = "resource_id"
        case success
    }
}

// MARK: - Service

actor MetricsAPIService {
    nonisolated static let shared = MetricsAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func recordMetric(name: String, value: Double, tags: [String: String] = [:]) async throws {
        let payload = RecordMetricBody(name: name, value: value, tags: tags)
        let _: EmptyResponse = try await client.post("api-v1-metrics/record", body: payload)
    }

    func recordRequest(endpoint: String, method: String, responseTimeMs: Int, statusCode: Int?, cacheHit: Bool) async throws {
        let payload = RecordRequestBody(endpoint: endpoint, method: method, responseTimeMs: responseTimeMs, statusCode: statusCode, cacheHit: cacheHit)
        let _: EmptyResponse = try await client.post("api-v1-metrics/request", body: payload)
    }

    func recordCircuitEvent(circuitName: String, state: String, failureCount: Int) async throws {
        let payload = RecordCircuitBody(circuitName: circuitName, state: state, failureCount: failureCount)
        let _: EmptyResponse = try await client.post("api-v1-metrics/circuit", body: payload)
    }

    func recordAudit(operation: String, userId: String?, resourceType: String?, resourceId: String?, success: Bool) async throws {
        let payload = RecordAuditBody(operation: operation, userId: userId, resourceType: resourceType, resourceId: resourceId, success: success)
        let _: EmptyResponse = try await client.post("api-v1-metrics/audit", body: payload)
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

#endif
