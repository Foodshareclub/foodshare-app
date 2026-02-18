//
//  ArrangementUseCases.swift
//  Foodshare
//
//  Use cases for post arrangement flow
//


#if !SKIP
import Foundation

// MARK: - Arrange Post Use Case

/// Use case for arranging a post pickup
@MainActor
final class ArrangePostUseCase {
    private let repository: ListingRepository

    init(repository: ListingRepository) {
        self.repository = repository
    }

    /// Arrange a post for pickup
    /// - Parameters:
    ///   - postId: ID of the post to arrange
    ///   - requesterId: ID of the user requesting the post
    /// - Returns: Updated food item
    func execute(postId: Int, requesterId: UUID) async throws -> FoodItem {
        // Fetch the post first to validate
        let post = try await repository.fetchListing(id: postId)

        // Validate post is available
        guard post.isActive else {
            throw ArrangementError.postNotAvailable
        }

        guard !post.isArranged else {
            throw ArrangementError.alreadyArranged
        }

        // Can't arrange your own post
        guard post.profileId != requesterId else {
            throw ArrangementError.cannotArrangeOwnPost
        }

        // Arrange the post
        return try await repository.arrangePost(postId: postId, requesterId: requesterId)
    }
}

// MARK: - Complete Arrangement Use Case

/// Use case for completing an arrangement (marking as done)
@MainActor
final class CompleteArrangementUseCase {
    private let repository: ListingRepository

    init(repository: ListingRepository) {
        self.repository = repository
    }

    /// Complete an arrangement (deactivate the post)
    /// - Parameters:
    ///   - postId: ID of the post
    ///   - userId: ID of the user completing (must be owner or requester)
    func execute(postId: Int, userId: UUID) async throws {
        let post = try await repository.fetchListing(id: postId)

        // Validate user is involved in the arrangement
        guard post.profileId == userId || post.postArrangedTo == userId else {
            throw ArrangementError.unauthorized
        }

        // Validate post is arranged
        guard post.isArranged else {
            throw ArrangementError.notArranged
        }

        // Deactivate the post
        try await repository.deactivatePost(postId: postId)
    }
}

// MARK: - Cancel Arrangement Use Case

/// Use case for canceling an arrangement
@MainActor
final class CancelArrangementUseCase {
    private let repository: ListingRepository

    init(repository: ListingRepository) {
        self.repository = repository
    }

    /// Cancel an arrangement
    /// - Parameters:
    ///   - postId: ID of the post
    ///   - userId: ID of the user canceling (must be owner or requester)
    func execute(postId: Int, userId: UUID) async throws {
        let post = try await repository.fetchListing(id: postId)

        // Validate user is involved in the arrangement
        guard post.profileId == userId || post.postArrangedTo == userId else {
            throw ArrangementError.unauthorized
        }

        // Validate post is arranged
        guard post.isArranged else {
            throw ArrangementError.notArranged
        }

        // Cancel the arrangement
        try await repository.cancelArrangement(postId: postId)
    }
}

// MARK: - Arrangement Errors

/// Errors that can occur during pickup arrangement operations.
///
/// Thread-safe for Swift 6 concurrency.
enum ArrangementError: LocalizedError, Sendable {
    /// Post is no longer available for pickup
    case postNotAvailable
    /// Post has already been arranged with someone
    case alreadyArranged
    /// User attempted to arrange their own post
    case cannotArrangeOwnPost
    /// No active arrangement exists for this post
    case notArranged
    /// User lacks permission for this action
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .postNotAvailable:
            "This post is no longer available"
        case .alreadyArranged:
            "This post has already been arranged"
        case .cannotArrangeOwnPost:
            "You cannot arrange your own post"
        case .notArranged:
            "This post has not been arranged"
        case .unauthorized:
            "You are not authorized to perform this action"
        }
    }
}

#endif
