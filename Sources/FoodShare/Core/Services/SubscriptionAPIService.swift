//
//  SubscriptionAPIService.swift
//  Foodshare
//
//  Centralized API service for subscription/payment operations
//

import Foundation

actor SubscriptionAPIService {
    nonisolated static let shared = SubscriptionAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func createSubscription(userId: String, plan: String) async throws -> SubscriptionResponse {
        try await client.post("api-v1-subscription/create", body: ["userId": userId, "plan": plan])
    }
    
    func cancelSubscription(subscriptionId: String) async throws {
        let _: EmptyResponse = try await client.post("api-v1-subscription/cancel", body: ["subscriptionId": subscriptionId])
    }
    
    func getSubscription(userId: String) async throws -> SubscriptionResponse {
        try await client.get("api-v1-subscription", params: ["userId": userId])
    }
    
    func verifyReceipt(receiptData: String) async throws -> SyncSubscriptionResponse {
        try await client.post("api-v1-subscription/verify", body: ["receiptData": receiptData])
    }
}

struct SyncSubscriptionResponse: Codable {
    let success: Bool
    let subscription: SubscriptionResponse?
}

struct SubscriptionResponse: Codable {
    let id: String
    let userId: String
    let plan: String
    let status: String
    let expiresAt: Date?
}

struct ReceiptVerificationResponse: Codable {
    let valid: Bool
    let subscription: SubscriptionResponse?
}
