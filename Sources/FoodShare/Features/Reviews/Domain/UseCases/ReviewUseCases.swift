//
//  ReviewUseCases.swift
//  Foodshare
//
//  Use cases for review operations
//


#if !SKIP
import Foundation

// MARK: - Submit Review Use Case

/// Use case for submitting a review
@MainActor
final class SubmitReviewUseCase {
    private let repository: ReviewRepository

    init(repository: ReviewRepository) {
        self.repository = repository
    }

    /// Submit a review for a post
    func execute(
        postId: Int,
        userId: UUID,
        rating: Int,
        feedback: String,
    ) async throws -> Review {
        // Validate rating
        guard (1 ... 5).contains(rating) else {
            throw ReviewError.invalidRating
        }

        // Validate feedback
        let trimmedFeedback = feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFeedback.isEmpty else {
            throw ReviewError.emptyFeedback
        }

        guard trimmedFeedback.count <= 1000 else {
            throw ReviewError.feedbackTooLong
        }

        // Check if already reviewed
        let hasReviewed = try await repository.hasReviewed(postId: postId, userId: userId)
        guard !hasReviewed else {
            throw ReviewError.alreadyReviewed
        }

        // Create review
        let request = CreateReviewRequest.forPost(
            profileId: userId,
            postId: postId,
            rating: rating,
            feedback: trimmedFeedback,
        )

        return try await repository.createReview(request)
    }
}

// MARK: - Fetch Reviews Use Case

/// Use case for fetching reviews
@MainActor
final class FetchReviewsUseCase {
    private let repository: ReviewRepository

    init(repository: ReviewRepository) {
        self.repository = repository
    }

    /// Fetch reviews for a post
    func execute(forPostId postId: Int) async throws -> [Review] {
        try await repository.fetchReviews(forPostId: postId)
    }

    /// Fetch reviews by a user
    func execute(byUserId userId: UUID) async throws -> [Review] {
        try await repository.fetchReviews(byUserId: userId)
    }

    /// Fetch reviews received by a user
    func execute(forUserId userId: UUID) async throws -> [Review] {
        try await repository.fetchReviews(forUserId: userId)
    }
}

// MARK: - Delete Review Use Case

/// Use case for deleting a review
@MainActor
final class DeleteReviewUseCase {
    private let repository: ReviewRepository

    init(repository: ReviewRepository) {
        self.repository = repository
    }

    /// Delete a review (only owner can delete)
    func execute(reviewId: Int, userId: UUID) async throws {
        try await repository.deleteReview(id: reviewId, userId: userId)
    }
}

// MARK: - Review Errors

/// Errors that can occur during review operations.
///
/// Thread-safe for Swift 6 concurrency.
enum ReviewError: LocalizedError, Sendable {
    /// Rating value is outside valid range (1-5)
    case invalidRating
    /// Review feedback is empty
    case emptyFeedback
    /// Review feedback exceeds maximum length
    case feedbackTooLong
    /// User has already submitted a review
    case alreadyReviewed
    /// User lacks permission for this action
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidRating:
            "Rating must be between 1 and 5"
        case .emptyFeedback:
            "Please provide feedback"
        case .feedbackTooLong:
            "Feedback is too long (max 1000 characters)"
        case .alreadyReviewed:
            "You have already reviewed this item"
        case .unauthorized:
            "You are not authorized to perform this action"
        }
    }
}

#endif
