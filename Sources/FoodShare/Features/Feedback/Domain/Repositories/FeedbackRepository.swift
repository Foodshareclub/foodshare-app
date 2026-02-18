//
//  FeedbackRepository.swift
//  Foodshare
//
//  Repository protocol for feedback
//


#if !SKIP
import Foundation

/// Repository protocol for feedback operations
protocol FeedbackRepository: Sendable {
    /// Submit feedback
    func submitFeedback(_ input: CreateFeedbackInput, userId: UUID?) async throws -> Feedback
}

#endif
