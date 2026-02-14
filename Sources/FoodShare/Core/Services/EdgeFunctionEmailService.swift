//
//  EdgeFunctionEmailService.swift
//  Foodshare
//
//  Secure email service that routes all email operations through EmailAPIService
//

import Foundation
import OSLog

// MARK: - Email Service Error

enum EmailServiceError: LocalizedError, Sendable {
    case unauthorized
    case rateLimitExceeded
    case invalidTemplate
    case sendFailed(String)
    case networkError(String)
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Authentication required for email operations"
        case .rateLimitExceeded:
            "Rate limit exceeded for email operations"
        case .invalidTemplate:
            "Invalid email template specified"
        case let .sendFailed(message):
            "Failed to send email: \(message)"
        case let .networkError(message):
            "Network error: \(message)"
        case .serviceUnavailable:
            "Email service is temporarily unavailable"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .serviceUnavailable:
            true
        case .unauthorized, .rateLimitExceeded, .invalidTemplate, .sendFailed:
            false
        }
    }
}

// MARK: - Edge Function Email Service Protocol

protocol EdgeFunctionEmailServiceProtocol: Sendable {
    func sendWelcomeEmail(to email: String, name: String) async throws
    func sendReservationConfirmation(
        to email: String,
        name: String,
        itemTitle: String,
        pickupTime: String,
        pickupAddress: String,
        ownerName: String,
    ) async throws
    func sendNewMessageNotification(
        to email: String,
        name: String,
        senderName: String,
        itemTitle: String,
        message: String,
        conversationLink: String,
    ) async throws
    func sendItemReservedNotification(
        to email: String,
        name: String,
        requesterName: String,
        itemTitle: String,
        pickupTime: String,
        reservationLink: String,
    ) async throws
    func sendReviewReminder(to email: String, name: String, otherUserName: String, reviewLink: String) async throws
    func sendCustomEmail(to email: String, subject: String, html: String) async throws
}

// MARK: - Edge Function Email Service Implementation

actor EdgeFunctionEmailService: EdgeFunctionEmailServiceProtocol {
    private let api: EmailAPIService
    private let logger: Logger

    init(
        api: EmailAPIService = .shared,
        logger: Logger = Logger(subsystem: "com.flutterflow.foodshare", category: "email"),
    ) {
        self.api = api
        self.logger = logger
        logger.debug("EdgeFunctionEmailService initialized")
    }

    // MARK: - Public API

    func sendWelcomeEmail(to email: String, name: String) async throws {
        try await api.sendWelcome(to: email, name: name)
    }

    func sendReservationConfirmation(
        to email: String,
        name: String,
        itemTitle: String,
        pickupTime: String,
        pickupAddress: String,
        ownerName: String,
    ) async throws {
        try await api.sendReservationConfirmed(
            to: email,
            name: name,
            itemTitle: itemTitle,
            pickupTime: pickupTime,
            pickupAddress: pickupAddress,
            ownerName: ownerName
        )
    }

    func sendNewMessageNotification(
        to email: String,
        name: String,
        senderName: String,
        itemTitle: String,
        message: String,
        conversationLink: String,
    ) async throws {
        try await api.sendNewMessage(
            to: email,
            name: name,
            senderName: senderName,
            itemTitle: itemTitle,
            message: message,
            conversationLink: conversationLink
        )
    }

    func sendItemReservedNotification(
        to email: String,
        name: String,
        requesterName: String,
        itemTitle: String,
        pickupTime: String,
        reservationLink: String,
    ) async throws {
        try await api.sendItemReserved(
            to: email,
            name: name,
            requesterName: requesterName,
            itemTitle: itemTitle,
            pickupTime: pickupTime,
            reservationLink: reservationLink
        )
    }

    func sendReviewReminder(
        to email: String,
        name: String,
        otherUserName: String,
        reviewLink: String,
    ) async throws {
        try await api.sendReviewReminder(
            to: email,
            name: name,
            otherUserName: otherUserName,
            reviewLink: reviewLink
        )
    }

    func sendCustomEmail(to email: String, subject: String, html: String) async throws {
        try await api.sendEmail(to: email, subject: subject, body: html)
    }
}

// MARK: - Mock Client for Testing

#if DEBUG
    actor MockEdgeFunctionEmailService: EdgeFunctionEmailServiceProtocol {
        private(set) var sentEmails: [(to: String, template: String, data: [String: String])] = []

        func sendWelcomeEmail(to email: String, name: String) async throws {
            sentEmails.append((to: email, template: "welcome", data: ["name": name]))
        }

        func sendReservationConfirmation(
            to email: String,
            name: String,
            itemTitle: String,
            pickupTime: String,
            pickupAddress: String,
            ownerName: String,
        ) async throws {
            sentEmails.append((
                to: email,
                template: "reservation_confirmed",
                data: ["name": name, "item_title": itemTitle],
            ))
        }

        func sendNewMessageNotification(
            to email: String,
            name: String,
            senderName: String,
            itemTitle: String,
            message: String,
            conversationLink: String,
        ) async throws {
            sentEmails.append((to: email, template: "new_message", data: ["name": name, "sender_name": senderName]))
        }

        func sendItemReservedNotification(
            to email: String,
            name: String,
            requesterName: String,
            itemTitle: String,
            pickupTime: String,
            reservationLink: String,
        ) async throws {
            sentEmails.append((
                to: email,
                template: "item_reserved",
                data: ["name": name, "requester_name": requesterName],
            ))
        }

        func sendReviewReminder(
            to email: String,
            name: String,
            otherUserName: String,
            reviewLink: String,
        ) async throws {
            sentEmails.append((
                to: email,
                template: "review_reminder",
                data: ["name": name, "other_user_name": otherUserName],
            ))
        }

        func sendCustomEmail(to email: String, subject: String, html: String) async throws {
            sentEmails.append((to: email, template: "custom", data: ["subject": subject]))
        }

        func reset() {
            sentEmails.removeAll()
        }
    }
#endif
