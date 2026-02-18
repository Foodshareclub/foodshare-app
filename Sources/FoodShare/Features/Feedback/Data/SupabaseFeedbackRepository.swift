//
//  SupabaseFeedbackRepository.swift
//  Foodshare
//
//  Supabase implementation of FeedbackRepository
//


#if !SKIP
import Foundation
import Supabase

final class SupabaseFeedbackRepository: FeedbackRepository, @unchecked Sendable {
    private let supabase: SupabaseClient

    init(supabase: Supabase.SupabaseClient) {
        self.supabase = supabase
    }

    func submitFeedback(_ input: CreateFeedbackInput, userId: UUID?) async throws -> Feedback {
        struct InsertFeedback: Encodable {
            let profile_id: UUID?
            let name: String
            let email: String
            let subject: String
            let message: String
            let feedback_type: String
        }

        let insertData = InsertFeedback(
            profile_id: userId,
            name: input.name,
            email: input.email,
            subject: input.subject,
            message: input.message,
            feedback_type: input.feedbackType.rawValue,
        )

        let response: Feedback = try await supabase
            .from("feedback")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value

        return response
    }
}

#endif
