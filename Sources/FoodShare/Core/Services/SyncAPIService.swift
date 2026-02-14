//
//  SyncAPIService.swift
//  Foodshare
//

import Foundation

actor SyncAPIService {
    nonisolated static let shared = SyncAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func sync(lastSyncTime: Date) async throws -> SyncResponse {
        try await client.post("api-v1-sync", body: ["lastSyncTime": ISO8601DateFormatter().string(from: lastSyncTime)])
    }
    
    func pushChanges(changes: [String: Any]) async throws {
        let _: EmptyResponse = try await client.post("api-v1-sync/push", body: changes)
    }
}

struct SyncResponse: Codable {
    let updates: [String: Any]
    let deletions: [String]
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case updates, deletions, timestamp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.updates = (try? container.decode([String: AnyCodable].self, forKey: .updates).mapValues { $0.value }) ?? [:]
        self.deletions = try container.decode([String].self, forKey: .deletions)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
}

struct AnyCodable: Codable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) { value = int }
        else if let string = try? container.decode(String.self) { value = string }
        else if let bool = try? container.decode(Bool.self) { value = bool }
        else { value = "" }
    }
    
    func encode(to encoder: Encoder) throws {}
}
