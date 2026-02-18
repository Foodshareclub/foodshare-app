//
//  AIAPIService.swift
//  Foodshare
//


#if !SKIP
import Foundation

actor AIAPIService {
    nonisolated static let shared = AIAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func generateText(prompt: String) async throws -> AIResponse {
        try await client.post("api-v1-ai/generate", body: ["prompt": prompt])
    }
    
    func moderateContent(text: String) async throws -> ModerationResponse {
        try await client.post("api-v1-ai/moderate", body: ["text": text])
    }
}

struct AIResponse: Codable {
    let text: String
}

struct ModerationResponse: Codable {
    let safe: Bool
    let categories: [String]
}

#endif
