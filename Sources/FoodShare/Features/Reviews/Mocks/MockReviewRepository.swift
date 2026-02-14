//
//  MockReviewRepository.swift
//  Foodshare
//
//  Mock review repository for testing and previews
//

import Foundation

#if DEBUG
    final class MockReviewRepository: ReviewRepository, @unchecked Sendable {
        nonisolated(unsafe) var mockReviews: [Review] = Review.sampleReviews
        nonisolated(unsafe) var reviewedPosts: Set<Int> = []
        nonisolated(unsafe) var shouldFail = false
        nonisolated(unsafe) var nextId = 100

        func fetchReviews(forPostId postId: Int) async throws -> [Review] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            return mockReviews.filter { $0.postId == postId }
        }

        func fetchReviews(byUserId userId: UUID) async throws -> [Review] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            return mockReviews.filter { $0.profileId == userId }
        }

        func fetchReviews(forUserId userId: UUID) async throws -> [Review] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            // Return reviews where the reviewed item belongs to the user
            return mockReviews
        }

        func createReview(_ request: CreateReviewRequest) async throws -> Review {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            let review = Review(
                id: nextId,
                profileId: request.profileId,
                postId: request.postId,
                forumId: request.forumId,
                challengeId: request.challengeId,
                reviewedRating: request.reviewedRating,
                feedback: request.feedback,
                notes: request.notes,
                createdAt: Date(),
                reviewer: ReviewerProfile.fixture(),
            )

            nextId += 1
            mockReviews.append(review)

            if let postId = request.postId {
                reviewedPosts.insert(postId)
            }

            return review
        }

        func deleteReview(id: Int, userId: UUID) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            guard let index = mockReviews.firstIndex(where: { $0.id == id && $0.profileId == userId }) else {
                throw AppError.forbidden(action: "delete this review")
            }

            mockReviews.remove(at: index)
        }

        func hasReviewed(postId: Int, userId: UUID) async throws -> Bool {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return reviewedPosts.contains(postId) ||
                mockReviews.contains { $0.postId == postId && $0.profileId == userId }
        }

        func fetchReviewsWithAverage(forPostId postId: Int) async throws -> ReviewsWithAverageResult {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            let reviews = mockReviews.filter { $0.postId == postId }
            let averageRating = reviews.isEmpty
                ? 0
                : Double(reviews.reduce(0) { $0 + $1.reviewedRating }) / Double(reviews.count)

            return ReviewsWithAverageResult(
                reviews: reviews,
                averageRating: averageRating,
                totalCount: reviews.count,
            )
        }

        func fetchReviewsWithAverage(forUserId userId: UUID) async throws -> ReviewsWithAverageResult {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            let reviews = mockReviews
            let averageRating = reviews.isEmpty
                ? 0
                : Double(reviews.reduce(0) { $0 + $1.reviewedRating }) / Double(reviews.count)

            return ReviewsWithAverageResult(
                reviews: reviews,
                averageRating: averageRating,
                totalCount: reviews.count,
            )
        }
    }
#endif
