//
//  SyncAPIService.swift
//  Foodshare
//


#if !SKIP
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

    func pushChanges(changes: [String: AnyCodable]) async throws {
        let _: EmptyResponse = try await client.post("api-v1-sync/push", body: changes)
    }
}

struct SyncResponse: Decodable {
    let updates: [String: AnyCodable]
    let deletions: [String]
    let timestamp: Date
}

// AnyCodable is defined in Core/Utilities/AnyCodable.swift

#endif
