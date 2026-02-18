//
//  FeedbackViewModel.swift
//  Foodshare
//
//  ViewModel for feedback submission
//



#if !SKIP
import Foundation
import Observation

@MainActor
@Observable
final class FeedbackViewModel {
    // MARK: - State

    var name = ""
    var email = ""
    var subject = ""
    var message = ""
    var feedbackType: FeedbackType = .general
    var isSubmitting = false
    var isSuccess = false
    var error: AppError?
    var showError = false

    // MARK: - Properties

    private let repository: FeedbackRepository
    private let userId: UUID?

    // MARK: - Validation

    var isNameValid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    var isEmailValid: Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }

    var isSubjectValid: Bool {
        subject.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
    }

    var isMessageValid: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }

    var canSubmit: Bool {
        isNameValid && isEmailValid && isSubjectValid && isMessageValid && !isSubmitting
    }

    // MARK: - Init

    init(repository: FeedbackRepository, userId: UUID?, defaultName: String = "", defaultEmail: String = "") {
        self.repository = repository
        self.userId = userId
        name = defaultName
        email = defaultEmail
    }

    // MARK: - Actions

    func submitFeedback() async {
        guard canSubmit else { return }

        isSubmitting = true
        error = nil
        showError = false

        defer { isSubmitting = false }

        do {
            let input = CreateFeedbackInput(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                subject: subject.trimmingCharacters(in: .whitespacesAndNewlines),
                message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                feedbackType: feedbackType,
            )

            _ = try await repository.submitFeedback(input, userId: userId)
            isSuccess = true
            resetForm()
        } catch let appError as AppError {
            self.error = appError
            showError = true
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func resetForm() {
        subject = ""
        message = ""
        feedbackType = .general
    }

    func dismissSuccess() {
        isSuccess = false
    }
}


#endif
