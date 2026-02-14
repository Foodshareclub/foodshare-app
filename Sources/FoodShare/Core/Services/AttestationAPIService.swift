//
//  AttestationAPIService.swift
//  Foodshare
//

import Foundation

actor AttestationAPIService {
    nonisolated static let shared = AttestationAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func attestDevice(keyId: String, attestation: String) async throws -> AttestationResponse {
        try await client.post("api-v1-attestation/attest", body: ["keyId": keyId, "attestation": attestation])
    }
    
    func verifyAssertion(keyId: String, assertion: String, challenge: String) async throws -> VerificationResponse {
        try await client.post("api-v1-attestation/verify", body: ["keyId": keyId, "assertion": assertion, "challenge": challenge])
    }
}

struct AttestationResponse: Codable {
    let success: Bool
    let deviceId: String
}

struct VerificationResponse: Codable {
    let valid: Bool
}
