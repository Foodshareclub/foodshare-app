//
//  UnifiedNotificationService.swift
//  Foodshare
//
//  Unified notification service that routes all notifications through the api-v1-notifications Edge Function.
//  Supports email, push, SMS, and in-app notifications via a single API endpoint.
//
//  This replaces the legacy EdgeFunctionEmailService and direct email clients.
//
//  Usage:
//  ```swift
//  let service = UnifiedNotificationService(supabase: supabaseClient)
//  try await service.sendWelcomeEmail(to: "user@example.com", userId: userId, name: "John")
//  ```
//

import Foundation
import OSLog
import Supabase

// MARK: - Notification Types

/// Notification types supported by the unified API
enum NotificationType: String, Codable, Sendable {
    case newMessage = "new_message"
    case listingFavorited = "listing_favorited"
    case listingExpired = "listing_expired"
    case arrangementConfirmed = "arrangement_confirmed"
    case arrangementCancelled = "arrangement_cancelled"
    case arrangementCompleted = "arrangement_completed"
    case challengeComplete = "challenge_complete"
    case challengeReminder = "challenge_reminder"
    case reviewReceived = "review_received"
    case reviewReminder = "review_reminder"
    case systemAnnouncement = "system_announcement"
    case moderationWarning = "moderation_warning"
    case accountSecurity = "account_security"
    case welcome
    case verification
    case passwordReset = "password_reset"
    case digest
}

/// Notification channels
enum NotificationChannel: String, Codable, Sendable {
    case push
    case email
    case sms
    case inApp = "in_app"
}

/// Priority levels
enum NotificationPriority: String, Codable, Sendable {
    case critical
    case high
    case normal
    case low
}

// MARK: - Request/Response Types

/// Request payload for sending notifications
struct NotificationSendRequest: Encodable, Sendable {
    let userId: String
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: String]?
    let channels: [NotificationChannel]?
    let priority: NotificationPriority?

    enum CodingKeys: String, CodingKey {
        case userId
        case type, title, body, data, channels, priority
    }
}

/// Response from notification API
struct NotificationSendResponse: Decodable, Sendable {
    let success: Bool
    let data: NotificationDeliveryResult?
    let error: String?
}

/// Delivery result details
struct NotificationDeliveryResult: Decodable, Sendable {
    let success: Bool
    let notificationId: String
    let userId: String
    let channels: [ChannelDeliveryResult]?
    let scheduled: Bool?
    let scheduledFor: String?
    let blocked: Bool?
    let reason: String?
    let error: String?
    let timestamp: String
}

/// Per-channel delivery result
struct ChannelDeliveryResult: Decodable, Sendable {
    let channel: String
    let success: Bool
    let provider: String?
    let error: String?
    let attemptedAt: String
    let deliveredAt: String?
}

// MARK: - Service Errors

/// Errors from unified notification service
enum UnifiedNotificationError: LocalizedError, Sendable {
    case unauthorized
    case rateLimitExceeded
    case validationFailed(String)
    case sendFailed(String)
    case networkError(String)
    case serviceUnavailable
    case userNotFound

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Authentication required for notification operations"
        case .rateLimitExceeded:
            "Rate limit exceeded for notifications"
        case let .validationFailed(message):
            "Validation error: \(message)"
        case let .sendFailed(message):
            "Failed to send notification: \(message)"
        case let .networkError(message):
            "Network error: \(message)"
        case .serviceUnavailable:
            "Notification service is temporarily unavailable"
        case .userNotFound:
            "User not found"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .serviceUnavailable:
            true
        case .unauthorized, .rateLimitExceeded, .validationFailed, .sendFailed, .userNotFound:
            false
        }
    }
}

// MARK: - Unified Notification Service Protocol

/// Protocol for unified notification operations
protocol UnifiedNotificationServiceProtocol: Sendable {
    // Email notifications
    func sendWelcomeEmail(userId: String, name: String) async throws
    func sendVerificationEmail(userId: String, name: String) async throws
    func sendPasswordResetEmail(userId: String, name: String) async throws

    /// Message notifications
    func sendNewMessageNotification(
        userId: String,
        senderName: String,
        messagePreview: String,
        conversationId: String,
    ) async throws

    // Listing notifications
    func sendListingFavoritedNotification(userId: String, listingTitle: String, favoritedBy: String) async throws
    func sendListingExpiredNotification(userId: String, listingTitle: String, listingId: String) async throws

    /// Arrangement notifications
    func sendArrangementConfirmedNotification(
        userId: String,
        itemTitle: String,
        pickupTime: String,
        partnerName: String,
    ) async throws

    // Review notifications
    func sendReviewReceivedNotification(userId: String, reviewerName: String, rating: Int) async throws
    func sendReviewReminderNotification(userId: String, partnerName: String, itemTitle: String) async throws

    /// Generic send
    func send(
        userId: String,
        type: NotificationType,
        title: String,
        body: String,
        data: [String: String]?,
        channels: [NotificationChannel]?,
        priority: NotificationPriority?,
    ) async throws -> NotificationDeliveryResult
}

// MARK: - Unified Notification Service Implementation

/// Production notification service that routes all operations through api-v1-notifications
actor UnifiedNotificationService: UnifiedNotificationServiceProtocol {
    private let supabase: SupabaseClient
    private let logger: Logger

    // Retry configuration
    private let maxRetries: Int
    private let initialBackoff: TimeInterval

    /// Singleton for convenience
    static let shared = UnifiedNotificationService(supabase: AuthenticationService.shared.supabase)

    init(
        supabase: SupabaseClient,
        maxRetries: Int = 3,
        initialBackoff: TimeInterval = 0.5,
        logger: Logger = Logger(subsystem: "com.flutterflow.foodshare", category: "notifications"),
    ) {
        self.supabase = supabase
        self.maxRetries = maxRetries
        self.initialBackoff = initialBackoff
        self.logger = logger

        logger.debug("UnifiedNotificationService initialized")
    }

    // MARK: - Email Notifications

    func sendWelcomeEmail(userId: String, name: String) async throws {
        _ = try await send(
            userId: userId,
            type: .welcome,
            title: "Welcome to FoodShare! 🎉",
            body: "Hey \(name)! We're thrilled to have you join our community. Start sharing food and reducing waste today!",
            data: ["name": name],
            channels: [.email],
            priority: .normal,
        )
    }

    func sendVerificationEmail(userId: String, name: String) async throws {
        _ = try await send(
            userId: userId,
            type: .verification,
            title: "Verify your email",
            body: "Please verify your email address to complete your FoodShare registration.",
            data: ["name": name],
            channels: [.email],
            priority: .high,
        )
    }

    func sendPasswordResetEmail(userId: String, name: String) async throws {
        _ = try await send(
            userId: userId,
            type: .passwordReset,
            title: "Reset your password",
            body: "We received a request to reset your FoodShare password.",
            data: ["name": name],
            channels: [.email],
            priority: .high,
        )
    }

    // MARK: - Message Notifications

    func sendNewMessageNotification(
        userId: String,
        senderName: String,
        messagePreview: String,
        conversationId: String,
    ) async throws {
        _ = try await send(
            userId: userId,
            type: .newMessage,
            title: "New message from \(senderName)",
            body: messagePreview,
            data: [
                "sender_name": senderName,
                "conversation_id": conversationId,
            ],
            channels: nil, // Let backend decide based on preferences
            priority: .normal,
        )
    }

    // MARK: - Listing Notifications

    func sendListingFavoritedNotification(
        userId: String,
        listingTitle: String,
        favoritedBy: String,
    ) async throws {
        _ = try await send(
            userId: userId,
            type: .listingFavorited,
            title: "\(favoritedBy) saved your listing",
            body: "Your listing \"\(listingTitle)\" was saved by \(favoritedBy)",
            data: [
                "listing_title": listingTitle,
                "favorited_by": favoritedBy,
            ],
            channels: nil,
            priority: .low,
        )
    }

    func sendListingExpiredNotification(
        userId: String,
        listingTitle: String,
        listingId: String,
    ) async throws {
        _ = try await send(
            userId: userId,
            type: .listingExpired,
            title: "Listing expired",
            body: "Your listing \"\(listingTitle)\" has expired. Would you like to renew it?",
            data: [
                "listing_id": listingId,
                "listing_title": listingTitle,
            ],
            channels: nil,
            priority: .normal,
        )
    }

    // MARK: - Arrangement Notifications

    func sendArrangementConfirmedNotification(
        userId: String,
        itemTitle: String,
        pickupTime: String,
        partnerName: String,
    ) async throws {
        _ = try await send(
            userId: userId,
            type: .arrangementConfirmed,
            title: "Pickup confirmed! 🎉",
            body: "Your pickup for \"\(itemTitle)\" with \(partnerName) is confirmed for \(pickupTime)",
            data: [
                "item_title": itemTitle,
                "pickup_time": pickupTime,
                "partner_name": partnerName,
            ],
            channels: nil,
            priority: .high,
        )
    }

    // MARK: - Review Notifications

    func sendReviewReceivedNotification(
        userId: String,
        reviewerName: String,
        rating: Int,
    ) async throws {
        let stars = String(repeating: "⭐", count: rating)
        _ = try await send(
            userId: userId,
            type: .reviewReceived,
            title: "New review received",
            body: "\(reviewerName) left you a \(rating)-star review \(stars)",
            data: [
                "reviewer_name": reviewerName,
                "rating": String(rating),
            ],
            channels: nil,
            priority: .normal,
        )
    }

    func sendReviewReminderNotification(
        userId: String,
        partnerName: String,
        itemTitle: String,
    ) async throws {
        _ = try await send(
            userId: userId,
            type: .reviewReminder,
            title: "How was your experience?",
            body: "Please take a moment to review your exchange with \(partnerName) for \"\(itemTitle)\"",
            data: [
                "partner_name": partnerName,
                "item_title": itemTitle,
            ],
            channels: nil,
            priority: .low,
        )
    }

    // MARK: - Generic Send

    func send(
        userId: String,
        type: NotificationType,
        title: String,
        body: String,
        data: [String: String]? = nil,
        channels: [NotificationChannel]? = nil,
        priority: NotificationPriority? = nil,
    ) async throws -> NotificationDeliveryResult {
        let request = NotificationSendRequest(
            userId: userId,
            type: type,
            title: title,
            body: body,
            data: data,
            channels: channels,
            priority: priority,
        )

        return try await executeWithRetry {
            try await self.performSend(request)
        }
    }

    // MARK: - Private Implementation

    private func performSend(_ request: NotificationSendRequest) async throws -> NotificationDeliveryResult {
        logger.debug("Sending notification: type=\(request.type.rawValue), userId=\(request.userId.prefix(8))...")

        do {
            let response: NotificationSendResponse = try await NotificationAPIService.shared.send(
                type: type.rawValue,
                userId: userId,
                data: [
                    "title": title,
                    "body": body,
                    "data": data ?? [:]
                ]
            )
                options: FunctionInvokeOptions(body: request),
            )

            if response.success, let result = response.data {
                logger.debug("Notification sent successfully: \(result.notificationId)")
                return result
            } else {
                throw UnifiedNotificationError.sendFailed(response.error ?? "Unknown error")
            }
        } catch let error as FunctionsError {
            throw mapFunctionsError(error)
        } catch let error as UnifiedNotificationError {
            throw error
        } catch let error as DecodingError {
            logger.error("Failed to decode notification response: \(error.localizedDescription)")
            throw UnifiedNotificationError.sendFailed("Invalid response format")
        } catch {
            logger.error("Notification request failed: \(error.localizedDescription)")
            throw UnifiedNotificationError.networkError(error.localizedDescription)
        }
    }

    private func mapFunctionsError(_ error: FunctionsError) -> UnifiedNotificationError {
        switch error {
        case let .httpError(code, data):
            if code == 401 {
                return .unauthorized
            } else if code == 429 {
                return .rateLimitExceeded
            } else if code == 400 {
                let message = String(data: data, encoding: .utf8) ?? "Bad request"
                return .validationFailed(message)
            } else {
                let message = String(data: data, encoding: .utf8) ?? "HTTP \(code)"
                return .sendFailed(message)
            }
        case .relayError:
            return .serviceUnavailable
        }
    }

    private func executeWithRetry<T>(
        operation: @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?
        var backoff = initialBackoff

        for attempt in 0 ... maxRetries {
            do {
                return try await operation()
            } catch let error as UnifiedNotificationError {
                if !error.isRetryable {
                    throw error
                }
                lastError = error
            } catch {
                lastError = error
            }

            if attempt < maxRetries {
                logger.debug("Notification retry attempt \(attempt + 1)/\(self.maxRetries)")
                try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                backoff *= 2
            }
        }

        throw lastError ?? UnifiedNotificationError.networkError("Unknown error")
    }
}

// MARK: - Mock Service for Testing

#if DEBUG
    actor MockUnifiedNotificationService: UnifiedNotificationServiceProtocol {
        private(set) var sentNotifications: [(userId: String, type: NotificationType, title: String)] = []

        func sendWelcomeEmail(userId: String, name: String) async throws {
            sentNotifications.append((userId, .welcome, "Welcome \(name)"))
        }

        func sendVerificationEmail(userId: String, name: String) async throws {
            sentNotifications.append((userId, .verification, "Verify \(name)"))
        }

        func sendPasswordResetEmail(userId: String, name: String) async throws {
            sentNotifications.append((userId, .passwordReset, "Reset for \(name)"))
        }

        func sendNewMessageNotification(
            userId: String,
            senderName: String,
            messagePreview: String,
            conversationId: String,
        ) async throws {
            sentNotifications.append((userId, .newMessage, "Message from \(senderName)"))
        }

        func sendListingFavoritedNotification(userId: String, listingTitle: String, favoritedBy: String) async throws {
            sentNotifications.append((userId, .listingFavorited, "\(favoritedBy) saved \(listingTitle)"))
        }

        func sendListingExpiredNotification(userId: String, listingTitle: String, listingId: String) async throws {
            sentNotifications.append((userId, .listingExpired, "Expired: \(listingTitle)"))
        }

        func sendArrangementConfirmedNotification(
            userId: String,
            itemTitle: String,
            pickupTime: String,
            partnerName: String,
        ) async throws {
            sentNotifications.append((userId, .arrangementConfirmed, "Confirmed: \(itemTitle)"))
        }

        func sendReviewReceivedNotification(userId: String, reviewerName: String, rating: Int) async throws {
            sentNotifications.append((userId, .reviewReceived, "Review from \(reviewerName)"))
        }

        func sendReviewReminderNotification(userId: String, partnerName: String, itemTitle: String) async throws {
            sentNotifications.append((userId, .reviewReminder, "Review \(partnerName)"))
        }

        func send(
            userId: String,
            type: NotificationType,
            title: String,
            body: String,
            data: [String: String]?,
            channels: [NotificationChannel]?,
            priority: NotificationPriority?,
        ) async throws -> NotificationDeliveryResult {
            sentNotifications.append((userId, type, title))
            return NotificationDeliveryResult(
                success: true,
                notificationId: UUID().uuidString,
                userId: userId,
                channels: nil,
                scheduled: nil,
                scheduledFor: nil,
                blocked: nil,
                reason: nil,
                error: nil,
                timestamp: ISO8601DateFormatter().string(from: Date()),
            )
        }

        func reset() {
            sentNotifications.removeAll()
        }
    }
#endif
