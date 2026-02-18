//
//  Feedback.swift
//  Foodshare
//
//  Feedback model for user feedback submissions
//  Matches database schema: public.feedback table
//


#if !SKIP
import Foundation
import SwiftUI

/// Types of feedback
enum FeedbackType: String, CaseIterable, Codable, Sendable {
    case general
    case bug
    case feature
    case complaint

    var displayName: String {
        switch self {
        case .general: "General Feedback"
        case .bug: "Bug Report"
        case .feature: "Feature Request"
        case .complaint: "Complaint"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .general: t.t("feedback.type.general")
        case .bug: t.t("feedback.type.bug")
        case .feature: t.t("feedback.type.feature")
        case .complaint: t.t("feedback.type.complaint")
        }
    }

    var icon: String {
        switch self {
        case .general: "bubble.left.and.bubble.right"
        case .bug: "ladybug"
        case .feature: "lightbulb"
        case .complaint: "exclamationmark.bubble"
        }
    }
}

/// Feedback status
enum FeedbackStatus: String, Codable, Sendable {
    case new
    case inProgress = "in_progress"
    case resolved
    case closed
}

/// Feedback model matching database schema
struct Feedback: Codable, Sendable, Identifiable {
    let id: UUID
    let profileId: UUID?
    let name: String
    let email: String
    let subject: String
    let message: String
    let feedbackType: FeedbackType
    let status: FeedbackStatus
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case name
        case email
        case subject
        case message
        case feedbackType = "feedback_type"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Input for creating feedback
struct CreateFeedbackInput: Codable, Sendable {
    let name: String
    let email: String
    let subject: String
    let message: String
    let feedbackType: FeedbackType

    enum CodingKeys: String, CodingKey {
        case name
        case email
        case subject
        case message
        case feedbackType = "feedback_type"
    }
}

#endif
