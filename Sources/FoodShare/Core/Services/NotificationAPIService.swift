//
//  NotificationAPIService.swift
//  Foodshare
//
//  API service for notifications via api-v1-notifications edge function.
//  The iOS client reads notifications from the user_notifications table via
//  Realtime, so this service is primarily for SENDING notifications and
//  managing notification preferences.
//

import Foundation

// MARK: - Notification API Service

actor NotificationAPIService {
    nonisolated static let shared = NotificationAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Send Notifications

    /// Send a notification via the edge function
    func send(
        type: String,
        recipientId: String,
        actorId: String? = nil,
        postId: Int? = nil,
        roomId: String? = nil,
        title: String,
        body: String,
        data: [String: String]? = nil
    ) async throws -> NotificationSendResponse {
        var requestBody: [String: Any] = [
            "type": type,
            "recipientId": recipientId,
            "title": title,
            "body": body,
        ]
        if let actorId { requestBody["actorId"] = actorId }
        if let postId { requestBody["postId"] = postId }
        if let roomId { requestBody["roomId"] = roomId }
        if let data { requestBody["data"] = data }

        return try await client.post("api-v1-notifications", body: requestBody)
    }

    /// Send push notification to specific device tokens
    func sendPush(
        deviceTokens: [String],
        title: String,
        body: String,
        type: String,
        data: [String: String]? = nil,
        silent: Bool = false
    ) async throws -> PushResponse {
        var requestBody: [String: Any] = [
            "deviceTokens": deviceTokens,
            "title": title,
            "body": body,
            "type": type,
            "silent": silent,
        ]
        if let data { requestBody["data"] = data }

        return try await client.post("api-v1-notifications", body: requestBody)
    }

    // MARK: - Preferences

    /// Get the current user's notification preferences
    func getPreferences() async throws -> NotificationPreferences {
        try await client.get("api-v1-notifications", params: ["action": "preferences"])
    }

    /// Update the current user's notification preferences
    func updatePreferences(_ prefs: NotificationPreferences) async throws {
        let _: EmptyResponse = try await client.put("api-v1-notifications", body: prefs, params: ["action": "preferences"])
    }

    // MARK: - Trigger Notifications

    /// Trigger a new-listing notification (notifies nearby users)
    func triggerNewListingNotification(postId: Int, latitude: Double, longitude: Double) async throws {
        try await client.postVoid("api-v1-notifications", body: [
            "action": "trigger_new_listing",
            "postId": postId,
            "latitude": latitude,
            "longitude": longitude,
        ])
    }
}

// MARK: - Response Types

struct NotificationSendResponse: Codable, Sendable {
    let success: Bool
    let messageId: String?
}

struct PushResponse: Codable, Sendable {
    let success: Bool
    let results: [PushResult]?
    let summary: PushSummary?

    struct PushResult: Codable, Sendable {
        let success: Bool
        let token: String
        let apnsId: String?
        let error: String?
        let shouldRemoveToken: Bool?
    }

    struct PushSummary: Codable, Sendable {
        let total: Int
        let succeeded: Int
        let failed: Int
        let invalidTokens: [String]
    }
}

struct NotificationPreferences: Codable, Sendable {
    let email: Bool
    let push: Bool
    let sms: Bool
}
