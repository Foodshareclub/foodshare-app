//
//  ReportViewModel.swift
//  Foodshare
//
//  ViewModel for reporting posts
//


#if !SKIP
import Foundation
import Observation

@MainActor
@Observable
final class ReportViewModel {
    // MARK: - State

    var selectedReason: ReportReason?
    var description = ""
    var isSubmitting = false
    var isSuccess = false
    var error: AppError?
    var showError = false
    var hasAlreadyReported = false

    // MARK: - Properties

    let postId: Int
    let postName: String
    private let repository: ReportRepository
    private let userId: UUID

    // MARK: - Computed

    var canSubmit: Bool {
        selectedReason != nil && !isSubmitting && !hasAlreadyReported
    }

    var descriptionCharacterCount: Int {
        description.count
    }

    let maxDescriptionLength = 1000

    // MARK: - Init

    init(postId: Int, postName: String, repository: ReportRepository, userId: UUID) {
        self.postId = postId
        self.postName = postName
        self.repository = repository
        self.userId = userId
    }

    // MARK: - Actions

    func checkIfAlreadyReported() async {
        do {
            hasAlreadyReported = try await repository.hasUserReportedPost(postId: postId, userId: userId)
        } catch {
            // Silently fail - allow reporting attempt
            hasAlreadyReported = false
        }
    }

    func submitReport() async {
        guard let reason = selectedReason else { return }

        isSubmitting = true
        error = nil
        showError = false

        defer { isSubmitting = false }

        do {
            let input = CreateReportInput(
                postId: postId,
                reason: reason,
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
            )

            _ = try await repository.submitReport(input, reporterId: userId)
            isSuccess = true
        } catch let appError as AppError {
            self.error = appError
            showError = true
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func reset() {
        selectedReason = nil
        description = ""
        isSuccess = false
        error = nil
        showError = false
    }
}

#endif
