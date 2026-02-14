//
//  ListingRepository.swift
//  Foodshare
//
//  Repository protocol for listing operations
//

import Foundation

// MARK: - Arrangement Record

/// Represents a completed or pending arrangement between users
struct ArrangementRecord: Codable, Identifiable, Sendable {
    let id: Int
    let postId: Int
    let postName: String
    let postImage: String?
    let otherUserId: UUID
    let otherUserName: String
    let otherUserAvatar: String?
    let arrangedAt: Date
    let completedAt: Date?
    let isSharer: Bool
    let status: ArrangementStatus

    enum ArrangementStatus: String, Codable, Sendable {
        case pending
        case completed
        case cancelled
    }

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case postName = "post_name"
        case postImage = "post_image"
        case otherUserId = "other_user_id"
        case otherUserName = "other_user_name"
        case otherUserAvatar = "other_user_avatar"
        case arrangedAt = "arranged_at"
        case completedAt = "completed_at"
        case isSharer = "is_sharer"
        case status
    }
}

// MARK: - Server Validation Types

/// Result from server-side listing validation
struct ListingValidationResult: Codable, Sendable {
    let valid: Bool
    let errors: [ListingValidationError]
    let sanitized: SanitizedListing?
}

/// Individual validation error from server
struct ListingValidationError: Codable, Sendable, Identifiable {
    let field: String
    let code: String
    let message: String

    var id: String { "\(field)-\(code)" }
}

/// Sanitized listing data from server validation
struct SanitizedListing: Codable, Sendable {
    let title: String
    let description: String?
    let images: [String]?
    let postType: String
    let latitude: Double
    let longitude: Double
    let pickupAddress: String?
    let pickupTime: String?
}

// MARK: - Listing Repository Protocol

protocol ListingRepository: Sendable {
    // MARK: - Validation

    /// Validate listing data against server-side rules
    /// This is the authoritative validation - client-side is optimistic only
    func validateListing(_ request: CreateListingRequest, imageUrls: [String]) async throws -> ListingValidationResult

    // MARK: - CRUD Operations

    func createListing(_ request: CreateListingRequest) async throws -> FoodItem
    func updateListing(_ request: UpdateListingRequest) async throws -> FoodItem
    func deleteListing(_ id: Int) async throws
    func fetchListing(id: Int) async throws -> FoodItem
    func fetchUserListings(userId: UUID) async throws -> [FoodItem]
    func uploadImages(_ imageData: [Data]) async throws -> [String]

    // MARK: - Arrangement Operations

    /// Arrange a post for pickup
    func arrangePost(postId: Int, requesterId: UUID) async throws -> FoodItem

    /// Cancel an arrangement
    func cancelArrangement(postId: Int) async throws

    /// Deactivate a post (mark as completed)
    func deactivatePost(postId: Int) async throws

    // MARK: - History

    /// Fetch arrangement history for a user
    func fetchArrangementHistory(userId: UUID) async throws -> [ArrangementRecord]

    // MARK: - Analytics

    /// Increment view count for a listing
    func incrementViewCount(listingId: Int) async throws
}
