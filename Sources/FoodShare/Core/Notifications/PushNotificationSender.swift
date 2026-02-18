//
//  PushNotificationSender.swift
//  Foodshare
//
//  Service for sending push notifications via NotificationAPIService
//


#if !SKIP
import Foundation
import OSLog
import Supabase

private struct TokenRow: Codable {
    let token: String
}

// MARK: - Push Notification Sender

@MainActor
final class PushNotificationSender {
    // MARK: - Dependencies

    private let api: NotificationAPIService
    private let supabase: SupabaseClient
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.flutterflow.foodshare",
        category: "PushSender",
    )

    // MARK: - Initialization

    init(api: NotificationAPIService = .shared, supabase: Supabase.SupabaseClient) {
        self.api = api
        self.supabase = supabase
    }

    // MARK: - Public API

    /// Send push notification to specific users
    func sendNotification(
        to userIds: [UUID],
        title: String,
        body: String,
        type: PushNotificationType,
        data: [String: String]? = nil,
    ) async throws {
        guard !userIds.isEmpty else {
            logger.debug("No user IDs provided, skipping push")
            return
        }

        let tokens = try await fetchDeviceTokens(for: userIds)
        guard !tokens.isEmpty else {
            logger.debug("No device tokens found for users: \(userIds)")
            return
        }

        logger.info("Sending push to \(tokens.count) device(s)")

        let response = try await api.sendPush(
            deviceTokens: tokens,
            title: title,
            body: body,
            type: type.rawValue,
            data: data
        )

        if let invalidTokens = response.summary?.invalidTokens, !invalidTokens.isEmpty {
            try await cleanupInvalidTokens(invalidTokens)
        }
    }

    /// Send push notification using a pre-built payload
    func sendNotification(
        to userIds: [UUID],
        payload: PushNotificationPayload,
    ) async throws {
        try await sendNotification(
            to: userIds,
            title: payload.title,
            body: payload.body,
            type: payload.type,
            data: payload.data,
        )
    }

    /// Send silent push for background refresh
    func sendSilentPush(
        to userIds: [UUID],
        type: PushNotificationType,
        data: [String: String],
    ) async throws {
        guard !userIds.isEmpty else { return }

        let tokens = try await fetchDeviceTokens(for: userIds)
        guard !tokens.isEmpty else { return }

        logger.info("Sending silent push to \(tokens.count) device(s)")

        let response = try await api.sendPush(
            deviceTokens: tokens,
            title: "",
            body: "",
            type: type.rawValue,
            data: data,
            silent: true
        )

        if let invalidTokens = response.summary?.invalidTokens, !invalidTokens.isEmpty {
            try await cleanupInvalidTokens(invalidTokens)
        }
    }

    // MARK: - Private Helpers

    private func fetchDeviceTokens(for userIds: [UUID]) async throws -> [String] {
        let rows: [TokenRow] = try await supabase
            .from("device_tokens")
            .select("token")
            .in("profile_id", values: userIds.map(\.uuidString))
            .eq("platform", value: "ios")
            .execute()
            .value

        return rows.map(\.token)
    }

    private func cleanupInvalidTokens(_ tokens: [String]) async throws {
        guard !tokens.isEmpty else { return }

        logger.info("Cleaning up \(tokens.count) invalid token(s)")

        try await supabase
            .from("device_tokens")
            .delete()
            .in("token", values: tokens)
            .execute()

        logger.info("Invalid tokens removed from database")
    }
}

// MARK: - Shared Instance

extension PushNotificationSender {
    static let shared = PushNotificationSender(supabase: SupabaseManager.shared.client)
}

#endif
