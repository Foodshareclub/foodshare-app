//
//  SupabaseReportRepository.swift
//  Foodshare
//
//  Supabase implementation of ReportRepository
//


#if !SKIP
import Foundation
import Supabase

final class SupabaseReportRepository: ReportRepository, @unchecked Sendable {
    private let supabase: SupabaseClient

    init(supabase: Supabase.SupabaseClient) {
        self.supabase = supabase
    }

    // TODO: Route through api-v1-forum?action=report when endpoint supports post reports
    func submitReport(_ input: CreateReportInput, reporterId: UUID) async throws -> Report {
        struct InsertReport: Encodable {
            let post_id: Int
            let reporter_id: UUID
            let reason: String
            let description: String?
            let status: String
        }

        let insertData = InsertReport(
            post_id: input.postId,
            reporter_id: reporterId,
            reason: input.reason.rawValue,
            description: input.description,
            status: ReportStatus.pending.rawValue,
        )

        let response: Report = try await supabase
            .from("post_reports")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value

        return response
    }

    func hasUserReportedPost(postId: Int, userId: UUID) async throws -> Bool {
        let response: [Report] = try await supabase
            .from("post_reports")
            .select()
            .eq("post_id", value: postId)
            .eq("reporter_id", value: userId)
            .execute()
            .value

        return !response.isEmpty
    }
}

#endif
