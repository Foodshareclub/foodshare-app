//
//  ResendService.swift
//  Foodshare
//
//  Resend email service wrapper via EmailAPIService
//



#if !SKIP
import Foundation
import OSLog

// MARK: - Email Errors

enum EmailError: Error, LocalizedError {
    case notAuthenticated
    case invalidRecipient
    case sendFailed(String)
    case networkError(Error)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "User must be authenticated to send emails"
        case .invalidRecipient:
            "Invalid email recipient"
        case let .sendFailed(message):
            "Failed to send email: \(message)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .decodingError:
            "Failed to decode email response"
        }
    }
}

// MARK: - Resend Service

final class ResendService: Sendable {
    static let shared = ResendService()

    private let api: EmailAPIService
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ResendService")

    private init(api: EmailAPIService = .shared) {
        self.api = api
    }

    // MARK: - Public API

    func sendEmail(to: String, subject: String, html: String) async throws {
        guard isValidEmail(to) else {
            throw EmailError.invalidRecipient
        }

        try await api.sendEmail(to: to, subject: subject, body: html)
        logger.info("✅ [EMAIL] Sent email to: \(to, privacy: .private(mask: .hash))")
    }

    func sendTemplateEmail(
        to: String,
        template: String,
        data: [String: String] = [:],
    ) async throws {
        guard isValidEmail(to) else {
            throw EmailError.invalidRecipient
        }

        try await api.sendTemplateEmail(to: to, template: template, data: data)
        logger.info("✅ [EMAIL] Sent \(template) template email to: \(to, privacy: .private(mask: .hash))")
    }

    // MARK: - Convenience Methods

    func sendWelcomeEmail(to: String, userName: String) async throws {
        try await api.sendWelcome(to: to, name: userName)
    }

    func sendReservationConfirmedEmail(
        to: String,
        itemName: String,
        pickupLocation: String,
        pickupTime: String,
    ) async throws {
        try await api.sendReservationConfirmed(
            to: to,
            name: "",
            itemTitle: itemName,
            pickupTime: pickupTime,
            pickupAddress: pickupLocation,
            ownerName: ""
        )
    }

    func sendNewMessageEmail(
        to: String,
        senderName: String,
        messagePreview: String,
        itemName: String,
    ) async throws {
        try await api.sendNewMessage(
            to: to,
            name: "",
            senderName: senderName,
            itemTitle: itemName,
            message: messagePreview,
            conversationLink: ""
        )
    }

    func sendItemReservedEmail(
        to: String,
        requesterName: String,
        itemName: String,
    ) async throws {
        try await api.sendItemReserved(
            to: to,
            name: "",
            requesterName: requesterName,
            itemTitle: itemName,
            pickupTime: "",
            reservationLink: ""
        )
    }

    func sendReviewReminderEmail(
        to: String,
        itemName: String,
        partnerName: String,
    ) async throws {
        try await api.sendReviewReminder(
            to: to,
            name: "",
            otherUserName: partnerName,
            reviewLink: ""
        )
    }

    func sendVerificationEmail(to: String, verificationLink: String) async throws {
        guard isValidEmail(to) else {
            throw EmailError.invalidRecipient
        }

        let html = """
        <div style="font-family: system-ui, -apple-system, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <h1 style="color: #2ECC71;">Verify Your Email</h1>
            <p>Thank you for joining Foodshare! Please verify your email address to start sharing food with your community.</p>
            <a href="\(
                verificationLink
            )" style="display: inline-block; background: linear-gradient(135deg, #2ECC71, #3498DB); color: white; padding: 12px 24px; border-radius: 8px; text-decoration: none; margin: 20px 0;">Verify Email</a>
            <p style="color: #666; font-size: 14px;">If you didn't create an account, you can safely ignore this email.</p>
        </div>
        """

        try await sendEmail(to: to, subject: "Verify your Foodshare email", html: html)
    }

    // MARK: - Private Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}


#endif
