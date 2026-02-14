//
//  Report.swift
//  Foodshare
//
//  Report model for reporting posts
//

import Foundation

/// Reasons for reporting a post
enum ReportReason: String, CaseIterable, Codable, Sendable {
    case spam
    case inappropriate
    case misleading
    case expired
    case wrongLocation = "wrong_location"
    case safetyConcern = "safety_concern"
    case duplicate
    case other

    var displayName: String {
        switch self {
        case .spam: "Spam"
        case .inappropriate: "Inappropriate"
        case .misleading: "Misleading"
        case .expired: "Expired"
        case .wrongLocation: "Wrong Location"
        case .safetyConcern: "Safety Concern"
        case .duplicate: "Duplicate"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .spam: "nosign"
        case .inappropriate: "exclamationmark.triangle"
        case .misleading: "theatermasks"
        case .expired: "clock.badge.exclamationmark"
        case .wrongLocation: "location.slash"
        case .safetyConcern: "shield.slash"
        case .duplicate: "doc.on.doc"
        case .other: "questionmark.circle"
        }
    }
}

/// Report model
struct Report: Codable, Sendable, Identifiable {
    let id: Int?
    let postId: Int
    let reporterId: UUID
    let reason: ReportReason
    let description: String?
    let status: ReportStatus
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case reporterId = "reporter_id"
        case reason
        case description
        case status
        case createdAt = "created_at"
    }
}

enum ReportStatus: String, Codable, Sendable {
    case pending
    case reviewed
    case resolved
    case dismissed
}

/// Input for creating a report
struct CreateReportInput: Codable, Sendable {
    let postId: Int
    let reason: ReportReason
    let description: String?

    enum CodingKeys: String, CodingKey {
        case postId = "post_id"
        case reason
        case description
    }
}
