//
//  ReviewAPIService.swift
//  Foodshare
//
//  API service for reviews via api-v1-reviews edge function
//


#if !SKIP
import Foundation

// MARK: - Review API Service

actor ReviewAPIService {
    nonisolated static let shared = ReviewAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - GET Operations

    /// Fetch reviews for a specific user (reviews they received)
    func getReviews(userId: String, limit: Int = 20, cursor: String? = nil) async throws -> [ReviewDTO] {
        var params: [String: String] = ["userId": userId, "limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await client.get("api-v1-reviews", params: params)
    }

    /// Fetch reviews for a specific post
    func getReviews(postId: Int, limit: Int = 20, cursor: String? = nil) async throws -> [ReviewDTO] {
        var params: [String: String] = ["postId": "\(postId)", "limit": "\(limit)"]
        if let cursor { params["cursor"] = cursor }
        return try await client.get("api-v1-reviews", params: params)
    }

    // MARK: - POST Operations

    /// Submit a new review
    func submitReview(_ request: SubmitReviewRequest) async throws -> ReviewDTO {
        try await client.post("api-v1-reviews", body: request)
    }

    // MARK: - DELETE Operations

    /// Delete a review by ID
    func deleteReview(id: Int) async throws {
        try await client.deleteVoid("api-v1-reviews", params: ["id": "\(id)"])
    }
}

// MARK: - DTOs

/// DTO for review data returned from the API.
/// Decoded by APIClient which uses `.convertFromSnakeCase` key decoding,
/// so no explicit CodingKeys needed for standard snake_case fields.
struct ReviewDTO: Codable, Identifiable, Sendable {
    let id: Int
    let profileId: UUID?
    let postId: Int?
    let reviewedRating: Int
    let feedback: String?
    let createdAt: Date?
}

/// Request body for submitting a review
struct SubmitReviewRequest: Encodable, Sendable {
    let revieweeId: String
    let postId: Int
    let rating: Int
    let feedback: String?
}

#endif
