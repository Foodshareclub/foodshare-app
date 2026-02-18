//
//  ReviewRepository.swift
//  Foodshare
//
//  Repository protocol for review operations
//


#if !SKIP
import Foundation

// MARK: - Reviews with Average Result

struct ReviewsWithAverageResult: Sendable {
    let reviews: [Review]
    let averageRating: Double
    let totalCount: Int

    static let empty = ReviewsWithAverageResult(
        reviews: [],
        averageRating: 0,
        totalCount: 0,
    )
}

// MARK: - Review Repository Protocol

/// Repository for managing reviews
protocol ReviewRepository: Sendable {
    /// Fetch reviews for a post
    func fetchReviews(forPostId postId: Int) async throws -> [Review]

    /// Fetch reviews by a user
    func fetchReviews(byUserId userId: UUID) async throws -> [Review]

    /// Fetch reviews for a user (reviews they received)
    func fetchReviews(forUserId userId: UUID) async throws -> [Review]

    /// Fetch reviews for a post with server-computed average rating
    func fetchReviewsWithAverage(forPostId postId: Int) async throws -> ReviewsWithAverageResult

    /// Fetch reviews for a user with server-computed average rating
    func fetchReviewsWithAverage(forUserId userId: UUID) async throws -> ReviewsWithAverageResult

    /// Create a new review
    func createReview(_ request: CreateReviewRequest) async throws -> Review

    /// Delete a review (only by owner)
    func deleteReview(id: Int, userId: UUID) async throws

    /// Check if user has already reviewed a post
    func hasReviewed(postId: Int, userId: UUID) async throws -> Bool
}

#endif
