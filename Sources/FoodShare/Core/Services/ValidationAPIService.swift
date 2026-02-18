//
//  ValidationAPIService.swift
//  Foodshare
//


#if !SKIP
import Foundation

actor ValidationAPIService {
    nonisolated static let shared = ValidationAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func validateEmail(email: String) async throws -> ValidationResponse {
        try await client.post("api-v1-validation/email", body: ["email": email])
    }
    
    func validatePhone(phone: String) async throws -> ValidationResponse {
        try await client.post("api-v1-validation/phone", body: ["phone": phone])
    }
    
    func validateUsername(username: String) async throws -> ValidationResponse {
        try await client.post("api-v1-validation/username", body: ["username": username])
    }
}

struct ValidationResponse: Codable {
    let valid: Bool
    let message: String?
}

#endif
