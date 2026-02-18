//
//  AlertsAPIService.swift
//  Foodshare
//


#if !SKIP
import Foundation

actor AlertsAPIService {
    nonisolated static let shared = AlertsAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func getAlerts(userId: String) async throws -> [Alert] {
        try await client.get("api-v1-alerts", params: ["userId": userId])
    }
    
    func createAlert(type: String, data: [String: String]) async throws -> Alert {
        try await client.post("api-v1-alerts", body: CreateAlertBody(type: type, data: data))
    }
    
    func dismissAlert(id: String) async throws {
        let _: EmptyResponse = try await client.delete("api-v1-alerts", params: ["id": id])
    }
}

private struct CreateAlertBody: Encodable {
    let type: String
    let data: [String: String]
}

struct Alert: Codable, Identifiable {
    let id: String
    let type: String
    let message: String
    let createdAt: Date
}

#endif
