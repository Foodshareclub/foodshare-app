//
//  FeatureFlagsAPIService.swift
//  Foodshare
//

import Foundation

actor FeatureFlagsAPIService {
    nonisolated static let shared = FeatureFlagsAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func getFlags(userId: String? = nil) async throws -> [String: Bool] {
        var params: [String: String] = [:]
        if let userId = userId { params["userId"] = userId }
        return try await client.get("api-v1-feature-flags", params: params)
    }
    
    func isEnabled(flag: String, userId: String? = nil) async throws -> Bool {
        var params: [String: String] = ["flag": flag]
        if let userId = userId { params["userId"] = userId }
        let response: FeatureFlagResponse = try await client.get("api-v1-feature-flags/check", params: params)
        return response.enabled
    }
}

struct FeatureFlagResponse: Codable {
    let enabled: Bool
}
