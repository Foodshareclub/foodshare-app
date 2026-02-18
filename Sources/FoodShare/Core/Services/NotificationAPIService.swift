//
//  NotificationAPIService.swift
//  Foodshare
//
//  API service for notifications via api-v1-notifications edge function.
//  The iOS client reads notifications from the user_notifications table via
//  Realtime, so this service is primarily for SENDING notifications and
//  managing notification preferences.
//


#if !SKIP
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
        let requestBody = NotificationSendRequestBody(
            type: type,
            recipientId: recipientId,
            actorId: actorId,
            postId: postId,
            roomId: roomId,
            title: title,
            body: body,
            data: data
        )
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
        let requestBody = PushSendRequestBody(
            deviceTokens: deviceTokens,
            title: title,
            body: body,
            type: type,
            data: data,
            silent: silent
        )
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
        let requestBody = NewListingNotificationRequest(
            action: "trigger_new_listing",
            postId: postId,
            latitude: latitude,
            longitude: longitude
        )
        try await client.postVoid("api-v1-notifications", body: requestBody)
    }
}

// MARK: - Request Types

/// Encodable request body for sending a notification
private struct NotificationSendRequestBody: Encodable, Sendable {
    let type: String
    let recipientId: String
    let actorId: String?
    let postId: Int?
    let roomId: String?
    let title: String
    let body: String
    let data: [String: String]?
}

/// Encodable request body for sending push notifications
private struct PushSendRequestBody: Encodable, Sendable {
    let deviceTokens: [String]
    let title: String
    let body: String
    let type: String
    let data: [String: String]?
    let silent: Bool
}

/// Encodable request body for triggering a new-listing notification
private struct NewListingNotificationRequest: Encodable, Sendable {
    let action: String
    let postId: Int
    let latitude: Double
    let longitude: Double
}

// MARK: - Response Types

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

#endif
