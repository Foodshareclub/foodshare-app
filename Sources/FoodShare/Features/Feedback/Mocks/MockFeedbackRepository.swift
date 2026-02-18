//
//  MockFeedbackRepository.swift
//  Foodshare
//
//  Mock feedback repository for testing and previews
//


#if !SKIP
import Foundation

#if DEBUG
    final class MockFeedbackRepository: FeedbackRepository, @unchecked Sendable {
        nonisolated(unsafe) var submittedFeedback: [Feedback] = []
        nonisolated(unsafe) var shouldFail = false
        nonisolated(unsafe) var nextId = UUID()

        func submitFeedback(_ input: CreateFeedbackInput, userId: UUID?) async throws -> Feedback {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            let feedback = Feedback(
                id: nextId,
                profileId: userId,
                name: input.name,
                email: input.email,
                subject: input.subject,
                message: input.message,
                feedbackType: input.feedbackType,
                status: .new,
                createdAt: Date(),
                updatedAt: Date(),
            )

            submittedFeedback.append(feedback)
            nextId = UUID()

            return feedback
        }
    }

    // MARK: - Test Fixtures

    extension Feedback {
        static func fixture(
            id: UUID = UUID(),
            profileId: UUID? = nil,
            name: String = "Test User",
            email: String = "test@example.com",
            subject: String = "Test Feedback",
            message: String = "This is a test feedback message.",
            feedbackType: FeedbackType = .general,
            status: FeedbackStatus = .new,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
        ) -> Feedback {
            Feedback(
                id: id,
                profileId: profileId,
                name: name,
                email: email,
                subject: subject,
                message: message,
                feedbackType: feedbackType,
                status: status,
                createdAt: createdAt,
                updatedAt: updatedAt,
            )
        }
    }

    extension CreateFeedbackInput {
        static func fixture(
            name: String = "Test User",
            email: String = "test@example.com",
            subject: String = "Test Feedback",
            message: String = "This is a test feedback message.",
            feedbackType: FeedbackType = .general,
        ) -> CreateFeedbackInput {
            CreateFeedbackInput(
                name: name,
                email: email,
                subject: subject,
                message: message,
                feedbackType: feedbackType,
            )
        }
    }
#endif

#endif
