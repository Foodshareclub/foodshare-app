//
//  ReviewViewModel.swift
//  Foodshare
//
//  ViewModel for reviews
//


#if !SKIP
import Foundation
import Observation

@MainActor
@Observable
final class ReviewViewModel {
    // MARK: - State

    var reviews: [Review] = []
    var isLoading = false
    var isSubmitting = false
    var error: AppError?
    var showError = false
    var showSuccessMessage = false

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
        isLoading = true
        error = nil
        showError = false
        defer { isLoading = false }

        do {
            reviews = try await fetchReviewsUseCase.execute(forPostId: postId)
        } catch let appError as AppError {
            self.error = appError
            showError = true
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func loadUserReviews() async {
        isLoading = true
        error = nil
        showError = false
        defer { isLoading = false }

        do {
            reviews = try await fetchReviewsUseCase.execute(forUserId: currentUserId)
        } catch let appError as AppError {
            self.error = appError
            showError = true
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func submitReview(forPostId postId: Int) async {
        guard canSubmit else { return }

        isSubmitting = true
        error = nil
        showError = false
        defer { isSubmitting = false }

        do {
            let review = try await submitReviewUseCase.execute(
                postId: postId,
                userId: currentUserId,
                rating: rating,
                feedback: feedback
            )
            reviews.insert(review, at: 0)
            resetForm()
            showSuccessMessage = true
        } catch let appError as AppError {
            self.error = appError
            showError = true
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func resetForm() {
        rating = 5
        feedback = ""
    }

    func clearError() {
        error = nil
        showError = false
    }
}

#endif
