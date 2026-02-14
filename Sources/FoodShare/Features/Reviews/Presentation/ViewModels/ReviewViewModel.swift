//
//  ReviewViewModel.swift
//  Foodshare
//
//  ViewModel for reviews
//

import Foundation
import FoodShareArchitecture
import Observation

@MainActor
@Observable
final class ReviewViewModel: AsyncViewModel {
    // MARK: - State

    var reviews: [Review] = []

    // MARK: - Form State

    var rating = 5
    var feedback = ""

    // MARK: - Dependencies

    private let fetchReviewsUseCase: FetchReviewsUseCase
    private let submitReviewUseCase: SubmitReviewUseCase
    private let currentUserId: UUID

    // MARK: - Initialization

    init(
        fetchReviewsUseCase: FetchReviewsUseCase,
        submitReviewUseCase: SubmitReviewUseCase,
        currentUserId: UUID
    ) {
        self.fetchReviewsUseCase = fetchReviewsUseCase
        self.submitReviewUseCase = submitReviewUseCase
        self.currentUserId = currentUserId
        super.init()
    }

    // MARK: - Computed Properties

    var hasReviews: Bool {
        !reviews.isEmpty
    }

    var averageRating: Double {
        guard !reviews.isEmpty else { return 0 }
        let total = reviews.reduce(0) { $0 + $1.reviewedRating }
        return Double(total) / Double(reviews.count)
    }

    var canSubmit: Bool {
        !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    // MARK: - Actions

    func loadReviews(forPostId postId: Int) async {
        await safely {
            reviews = try await withLoading {
                try await fetchReviewsUseCase.execute(forPostId: postId)
            }
        }
    }

    func loadUserReviews() async {
        await safely {
            reviews = try await withLoading {
                try await fetchReviewsUseCase.execute(forUserId: currentUserId)
            }
        }
    }

    func submitReview(forPostId postId: Int) async {
        guard canSubmit else { return }

        await safely {
            let review = try await withSubmitting {
                try await submitReviewUseCase.execute(
                    postId: postId,
                    userId: currentUserId,
                    rating: rating,
                    feedback: feedback
                )
            }
            reviews.insert(review, at: 0)
            resetForm()
            showSuccess(message: "Review submitted successfully")
        }
    }

    func resetForm() {
        rating = 5
        feedback = ""
    }
}
