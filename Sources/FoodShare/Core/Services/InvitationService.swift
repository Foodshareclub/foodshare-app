//
//  InvitationService.swift
//  Foodshare
//
//  Service for inviting friends to Foodshare via email.
//  Uses Resend API through Supabase Edge Function for email delivery.
//
//  Usage:
//  ```swift
//  let result = try await InvitationService.shared.sendInvitations(emails: ["friend@example.com"])
//  if result.allSucceeded {
//      // Show success message
//  }
//  ```
//



#if !SKIP
import Foundation
import OSLog
import Supabase
#if !SKIP
import UIKit
#endif

// MARK: - Invitation Result

/// Result of a batch invitation operation.
///
/// Contains the count of successfully sent invitations and any emails that failed.
struct InvitationResult: Sendable {
    /// Number of invitations successfully sent
    let successCount: Int

    /// Email addresses that failed to receive invitations
    let failedEmails: [String]

    /// Returns `true` if all invitations were sent successfully
    var allSucceeded: Bool {
        failedEmails.isEmpty
    }
}

// MARK: - Invitation Service

/// Service for sending friend invitations to Foodshare.
///
/// Handles email invitations via Resend API (through Edge Function) and native share sheet
/// for sharing invite links. Includes rate limiting, validation, and analytics tracking.
///
/// - Note: This service is `@MainActor` isolated for UI interactions (share sheet, haptics).
/// - Important: Requires authenticated user session to send email invitations.
@MainActor
final class InvitationService {
    // MARK: - Singleton

    /// Shared singleton instance
    static let shared = InvitationService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "Invitation")

    /// Maximum invitations allowed per request (rate limiting)
    private let maxInvitationsPerRequest = 10

    // MARK: - Initialization

    private init() {
        logger.info("📨 [INVITATION] InvitationService initialized")
    }

    // MARK: - Send Invitations

    /// Send invitations to multiple email addresses
    /// - Parameter emails: Array of email addresses to invite
    /// - Returns: Result with success count and failed emails
    func sendInvitations(emails: [String]) async throws -> InvitationResult {
        logger.info("📨 [INVITATION] Sending \(emails.count) invitations")

        let supabase = SupabaseManager.shared.client

        // Verify authentication
        guard let session = try? await supabase.auth.session else {
            throw InvitationError.notAuthenticated
        }

        // Validate and filter emails
        let validEmails = emails
            .map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { isValidEmail($0) }
            .prefix(maxInvitationsPerRequest)

        guard !validEmails.isEmpty else {
            throw InvitationError.noValidEmails
        }

        // Get sender info
        let senderName = session.user.userMetadata["first_name"] as? String ?? "A Foodshare User"
        let senderEmail = session.user.email ?? "unknown"

        var successCount = 0
        var failedEmails: [String] = []

        // Send invitations via EmailAPIService
        for email in validEmails {
            do {
                try await EmailAPIService.shared.sendInvitation(
                    to: email,
                    fromName: senderName,
                    fromEmail: senderEmail
                )
                successCount += 1
                logger.debug("✅ [INVITATION] Sent to: \(email.prefix(3))***")
            } catch {
                failedEmails.append(email)
                logger.warning("⚠️ [INVITATION] Failed for: \(email.prefix(3))*** - \(error.localizedDescription)")
            }
        }

        // Log analytics
        await logInvitationAnalytics(
            count: successCount,
            userId: session.user.id,
        )

        if successCount > 0 {
            HapticManager.success()
        }

        logger.info("📨 [INVITATION] Completed: \(successCount) sent, \(failedEmails.count) failed")

        return InvitationResult(
            successCount: successCount,
            failedEmails: failedEmails,
        )
    }

    // MARK: - Single Invitation

    // Removed - now handled by EmailAPIService

    // MARK: - Share Invite Link

    /// Returns the shareable Foodshare invite URL.
    ///
    /// - Returns: The invite link URL for sharing
    func getInviteLink() -> URL {
        // Force unwrap is safe for compile-time constant URL
        URL(string: "https://foodshare.club/invite")!
    }

    #if !SKIP
    /// Presents the native iOS share sheet with the Foodshare invite link.
    ///
    /// - Parameter sourceView: Optional source view for iPad popover positioning.
    ///   If `nil`, the share sheet will be presented from the center on iPad.
    func shareInviteLink(from sourceView: UIView? = nil) {
        let url = getInviteLink()
        let message = "Join me on Foodshare - share food, reduce waste, and help your community!"

        let items: [Any] = [message, url]
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil,
        )

        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]

        // Configure for iPad
        if let sourceView {
            activityVC.popoverPresentationController?.sourceView = sourceView
            activityVC.popoverPresentationController?.sourceRect = sourceView.bounds
        }

        // Present
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        topVC.present(activityVC, animated: true)
    }
    #endif

    // MARK: - Analytics

    private struct ActivityLog: Encodable {
        let actorId: String
        let activityType: String
        let notes: String

        enum CodingKeys: String, CodingKey {
            case actorId = "actor_id"
            case activityType = "activity_type"
            case notes
        }
    }

    private func logInvitationAnalytics(count: Int, userId: UUID) async {
        let supabase = SupabaseManager.shared.client

        do {
            try await supabase
                .from("post_activity_logs")
                .insert(ActivityLog(
                    actorId: userId.uuidString,
                    activityType: "shared",
                    notes: "invitation:count=\(count):platform=ios",
                ))
                .execute()
        } catch {
            logger.debug("⚠️ [INVITATION] Failed to log analytics: \(error.localizedDescription)")
        }
    }

    // MARK: - Validation

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

// MARK: - Errors

/// Errors that can occur during invitation operations.
///
/// Thread-safe for Swift 6 concurrency.
enum InvitationError: LocalizedError, Sendable {
    /// User is not authenticated (no valid session)
    case notAuthenticated

    /// No valid email addresses were provided
    case noValidEmails

    /// Email send operation failed with the given reason
    case sendFailed(String)

    /// Too many invitations sent in a short period
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "Please sign in to send invitations"
        case .noValidEmails:
            "No valid email addresses provided"
        case let .sendFailed(message):
            "Failed to send invitation: \(message)"
        case .rateLimited:
            "Too many invitations sent. Please try again later."
        }
    }
}


#endif
