//
//  EmailAPIService.swift
//  Foodshare
//
//  Centralized API service for email operations
//


#if !SKIP
import Foundation

// MARK: - Request Bodies

private struct EmailSendBody: Encodable {
    let to: String
    let subject: String
    let body: String
    let template: String?
}

private struct EmailSendTemplateBody: Encodable {
    let to: String
    let template: String
    let data: [String: String]
}

// MARK: - Service

actor EmailAPIService {
    nonisolated static let shared = EmailAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    func sendEmail(to: String, subject: String, body: String, template: String? = nil) async throws {
        let payload = EmailSendBody(to: to, subject: subject, body: body, template: template)
        let _: EmptyResponse = try await client.post("api-v1-email/send", body: payload)
    }

    func sendTemplateEmail(to: String, template: String, data: [String: String]) async throws {
        let payload = EmailSendTemplateBody(to: to, template: template, data: data)
        let _: EmptyResponse = try await client.post("api-v1-email/send-template", body: payload)
    }

    func sendWelcome(to: String, name: String) async throws {
        try await sendTemplateEmail(to: to, template: "welcome", data: ["name": name])
    }

    func sendReservationConfirmed(to: String, name: String, itemTitle: String, pickupTime: String, pickupAddress: String, ownerName: String) async throws {
        try await sendTemplateEmail(to: to, template: "reservation_confirmed", data: [
            "name": name,
            "item_title": itemTitle,
            "pickup_time": pickupTime,
            "pickup_address": pickupAddress,
            "owner_name": ownerName
        ])
    }

    func sendNewMessage(to: String, name: String, senderName: String, itemTitle: String, message: String, conversationLink: String) async throws {
        try await sendTemplateEmail(to: to, template: "new_message", data: [
            "name": name,
            "sender_name": senderName,
            "item_title": itemTitle,
            "message": message,
            "conversation_link": conversationLink
        ])
    }

    func sendItemReserved(to: String, name: String, requesterName: String, itemTitle: String, pickupTime: String, reservationLink: String) async throws {
        try await sendTemplateEmail(to: to, template: "item_reserved", data: [
            "name": name,
            "requester_name": requesterName,
            "item_title": itemTitle,
            "pickup_time": pickupTime,
            "reservation_link": reservationLink
        ])
    }

    func sendReviewReminder(to: String, name: String, otherUserName: String, reviewLink: String) async throws {
        try await sendTemplateEmail(to: to, template: "review_reminder", data: [
            "name": name,
            "other_user_name": otherUserName,
            "review_link": reviewLink
        ])
    }

    func sendInvitation(to: String, fromName: String, fromEmail: String) async throws {
        try await sendTemplateEmail(to: to, template: "invitation", data: [
            "from_name": fromName,
            "from_email": fromEmail
        ])
    }
}

#endif
