//
//  PushNotificationService.swift
//  Foodshare
//
//  Push notification service for real-time alerts
//


#if !SKIP
import Foundation
import Observation
import Supabase
#if !SKIP
import UserNotifications
#endif

// MARK: - Push Notification Types

enum PushNotificationType: String, Codable, Sendable {
    case newMessage = "new_message"
    case arrangementRequest = "arrangement_request"
    case arrangementConfirmed = "arrangement_confirmed"
    case arrangementCancelled = "arrangement_cancelled"
    case newListingNearby = "new_listing_nearby"
    case reviewReminder = "review_reminder"
    case fridgeUpdate = "fridge_update"
}

struct PushNotificationPayload: Codable, Sendable {
    let type: PushNotificationType
    let title: String
    let body: String
    let data: [String: String]?
}

// MARK: - Device Token

struct DeviceToken: Codable, Sendable {
    let profileId: UUID
    let token: String
    let platform: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case token
        case platform
        case createdAt = "created_at"
    }
}

// MARK: - Push Notification Service

@MainActor
@Observable
final class PushNotificationService: NSObject {
    // MARK: - State

    var isAuthorized = false
    var deviceToken: String?
    var pendingNotifications: [PushNotificationPayload] = []

    // MARK: - Dependencies

    private let supabase: SupabaseClient
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Initialization

    init(supabase: Supabase.SupabaseClient) {
        self.supabase = supabase
        super.init()
    }

    // MARK: - Authorization

    /// Request push notification authorization
    func requestAuthorization() async throws -> Bool {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]

        do {
            let granted = try await notificationCenter.requestAuthorization(options: options)
            isAuthorized = granted

            if granted {
                await AppLogger.shared.info("Push notifications authorized")
            } else {
                await AppLogger.shared.warning("Push notifications denied")
            }

            return granted
        } catch {
            await AppLogger.shared.error("Failed to request push authorization", error: error)
            throw error
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        return settings.authorizationStatus
    }

    // MARK: - Device Token Registration

    /// Register device token with backend
    func registerDeviceToken(_ tokenData: Data, for userId: UUID) async throws {
        let tokenString = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = tokenString

        let deviceTokenRecord = DeviceToken(
            profileId: userId,
            token: tokenString,
            platform: "ios",
            createdAt: Date(),
        )

        // Upsert device token (insert or update if exists)
        try await supabase
            .from("device_tokens")
            .upsert(deviceTokenRecord, onConflict: "profile_id,platform")
            .execute()

        await AppLogger.shared.info("Device token registered for user \(userId)")
    }

    /// Unregister device token (on logout)
    func unregisterDeviceToken(for userId: UUID) async throws {
        try await supabase
            .from("device_tokens")
            .delete()
            .eq("profile_id", value: userId.uuidString)
            .eq("platform", value: "ios")
            .execute()

        deviceToken = nil
        await AppLogger.shared.info("Device token unregistered for user \(userId)")
    }

    // MARK: - Local Notifications

    /// Schedule a local notification
    func scheduleLocalNotification(
        title: String,
        body: String,
        identifier: String,
        delay: TimeInterval = 0,
        data: [String: String]? = nil,
    ) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let data {
            content.userInfo = data
        }

        let trigger: UNNotificationTrigger? = if delay > 0 {
            UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        } else {
            nil
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger,
        )

        try await notificationCenter.add(request)
        await AppLogger.shared.debug("Local notification scheduled: \(identifier)")
    }

    /// Cancel a scheduled notification
    func cancelNotification(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
    }

    // MARK: - Badge Management

    /// Update app badge count
    func updateBadgeCount(_ count: Int) async {
        do {
            try await notificationCenter.setBadgeCount(count)
        } catch {
            await AppLogger.shared.error("Failed to update badge count", error: error)
        }
    }

    /// Clear app badge
    func clearBadge() async {
        await updateBadgeCount(0)
    }
}

// MARK: - Notification Templates

extension PushNotificationService {
    /// Create new message notification
    static func newMessagePayload(
        senderName: String,
        messagePreview: String,
        roomId: UUID,
    ) -> PushNotificationPayload {
        PushNotificationPayload(
            type: .newMessage,
            title: "New message from \(senderName)",
            body: messagePreview,
            data: ["room_id": roomId.uuidString],
        )
    }

    /// Create arrangement request notification
    static func arrangementRequestPayload(
        requesterName: String,
        postName: String,
        postId: Int,
    ) -> PushNotificationPayload {
        PushNotificationPayload(
            type: .arrangementRequest,
            title: "Arrangement Request",
            body: "\(requesterName) wants to pick up \"\(postName)\"",
            data: ["post_id": String(postId)],
        )
    }

    /// Create arrangement confirmed notification
    static func arrangementConfirmedPayload(
        postName: String,
        postId: Int,
    ) -> PushNotificationPayload {
        PushNotificationPayload(
            type: .arrangementConfirmed,
            title: "Arrangement Confirmed! 🎉",
            body: "Your request for \"\(postName)\" has been confirmed",
            data: ["post_id": String(postId)],
        )
    }

    /// Create new listing nearby notification
    static func newListingNearbyPayload(
        postName: String,
        distance: String,
        postId: Int,
    ) -> PushNotificationPayload {
        PushNotificationPayload(
            type: .newListingNearby,
            title: "New Food Nearby! 🍎",
            body: "\"\(postName)\" is available \(distance) away",
            data: ["post_id": String(postId)],
        )
    }

    /// Create review reminder notification
    static func reviewReminderPayload(
        postName: String,
        postId: Int,
    ) -> PushNotificationPayload {
        PushNotificationPayload(
            type: .reviewReminder,
            title: "How was your pickup?",
            body: "Leave a review for \"\(postName)\"",
            data: ["post_id": String(postId)],
        )
    }
}

#endif
