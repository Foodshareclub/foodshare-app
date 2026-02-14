//
//  ReportRepository.swift
//  Foodshare
//
//  Repository protocol for reports
//

import Foundation

/// Repository protocol for report operations
protocol ReportRepository: Sendable {
    /// Submit a report for a post
    func submitReport(_ input: CreateReportInput, reporterId: UUID) async throws -> Report

    /// Check if user has already reported a post
    func hasUserReportedPost(postId: Int, userId: UUID) async throws -> Bool
}
