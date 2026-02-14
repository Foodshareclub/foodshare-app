//
//  NewsletterService.swift
//  Foodshare
//
//  Newsletter subscription management
//  Actor-based, thread-safe implementation
//

import Foundation
import OSLog
import Supabase

// MARK: - Newsletter Subscriber Model

/// Newsletter subscriber record
struct NewsletterSubscriber: Codable, Sendable {
    let id: UUID?
    let email: String
    let firstName: String?
    let status: SubscriptionStatus
    let source: SubscriptionSource
    let subscribedAt: Date?
    let unsubscribedAt: Date?
    let unsubscribeReason: String?
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case status
        case source
        case subscribedAt = "subscribed_at"
        case unsubscribedAt = "unsubscribed_at"
        case unsubscribeReason = "unsubscribe_reason"
        case metadata
    }
}

// MARK: - Subscription Status

enum SubscriptionStatus: String, Codable, Sendable {
    case active
    case unsubscribed
    case bounced
    case complained

    var displayName: String {
        switch self {
        case .active: "Subscribed"
        case .unsubscribed: "Unsubscribed"
        case .bounced: "Bounced"
        case .complained: "Complained"
        }
    }

    /// Localized display name using translation service
    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .active: t.t("newsletter.status.active")
        case .unsubscribed: t.t("newsletter.status.unsubscribed")
        case .bounced: t.t("newsletter.status.bounced")
        case .complained: t.t("newsletter.status.complained")
        }
    }

    var isActive: Bool {
        self == .active
    }
}

// MARK: - Subscription Source

enum SubscriptionSource: String, Codable, Sendable {
    case website
    case app = "ios_app"
    case `import`
    case api
    case referral

    var displayName: String {
        switch self {
        case .website: "Website"
        case .app: "iOS App"
        case .import: "Import"
        case .api: "API"
        case .referral: "Referral"
        }
    }

    /// Localized display name using translation service
    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .website: t.t("newsletter.source.website")
        case .app: t.t("newsletter.source.app")
        case .import: t.t("newsletter.source.import")
        case .api: t.t("newsletter.source.api")
        case .referral: t.t("newsletter.source.referral")
        }
    }
}

// MARK: - Newsletter Service

/// Actor-based service for newsletter subscription management
actor NewsletterService {
    // MARK: - Singleton

    static let shared = NewsletterService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "Newsletter")

    // MARK: - Initialization

    private init() {
        logger.info("📰 [NEWSLETTER] NewsletterService initialized")
    }

    // MARK: - Subscribe

    /// Subscribe to newsletter
    /// - Parameters:
    ///   - email: Email address to subscribe
    ///   - firstName: Optional first name
    /// - Returns: Subscriber record
    @MainActor
    func subscribe(email: String, firstName: String? = nil) async throws -> NewsletterSubscriber {
        logger.info("📰 [NEWSLETTER] Subscribing: \(email.prefix(3))***")

        // Validate email
        guard await isValidEmail(email) else {
            throw NewsletterError.invalidEmail
        }

        let supabase = SupabaseManager.shared.client

        // Check if already subscribed
        let existing: [NewsletterSubscriber] = try await supabase
            .from("newsletter_subscribers")
            .select()
            .eq("email", value: email.lowercased())
            .execute()
            .value

        if let subscriber = existing.first {
            if subscriber.status == .active {
                logger.info("ℹ️ [NEWSLETTER] Already subscribed")
                return subscriber
            }

            // Reactivate if previously unsubscribed
            struct ReactivateUpdate: Encodable {
                let status: String
                let updatedAt: String

                enum CodingKeys: String, CodingKey {
                    case status
                    case updatedAt = "updated_at"
                }
            }

            let updated: NewsletterSubscriber = try await supabase
                .from("newsletter_subscribers")
                .update(ReactivateUpdate(
                    status: "active",
                    updatedAt: ISO8601DateFormatter().string(from: Date()),
                ))
                .eq("email", value: email.lowercased())
                .select()
                .single()
                .execute()
                .value

            HapticManager.success()
            logger.info("✅ [NEWSLETTER] Reactivated subscription")
            return updated
        }

        // Create new subscription
        struct NewSubscriber: Encodable {
            let email: String
            let firstName: String?
            let status: String
            let source: String

            enum CodingKeys: String, CodingKey {
                case email
                case firstName = "first_name"
                case status
                case source
            }
        }

        let newSubscriber: NewsletterSubscriber = try await supabase
            .from("newsletter_subscribers")
            .insert(NewSubscriber(
                email: email.lowercased(),
                firstName: firstName,
                status: "active",
                source: SubscriptionSource.app.rawValue,
            ))
            .select()
            .single()
            .execute()
            .value

        HapticManager.success()
        logger.info("✅ [NEWSLETTER] Subscribed successfully")

        return newSubscriber
    }

    // MARK: - Unsubscribe

    /// Unsubscribe from newsletter
    /// - Parameters:
    ///   - email: Email address to unsubscribe
    ///   - reason: Optional reason for unsubscribing
    @MainActor
    func unsubscribe(email: String, reason: String? = nil) async throws {
        logger.info("📰 [NEWSLETTER] Unsubscribing: \(email.prefix(3))***")

        let supabase = SupabaseManager.shared.client

        struct UnsubscribeUpdate: Encodable {
            let status: String
            let unsubscribedAt: String
            let unsubscribeReason: String?
            let updatedAt: String

            enum CodingKeys: String, CodingKey {
                case status
                case unsubscribedAt = "unsubscribed_at"
                case unsubscribeReason = "unsubscribe_reason"
                case updatedAt = "updated_at"
            }
        }

        try await supabase
            .from("newsletter_subscribers")
            .update(UnsubscribeUpdate(
                status: "unsubscribed",
                unsubscribedAt: ISO8601DateFormatter().string(from: Date()),
                unsubscribeReason: reason,
                updatedAt: ISO8601DateFormatter().string(from: Date()),
            ))
            .eq("email", value: email.lowercased())
            .execute()

        HapticManager.light()
        logger.info("✅ [NEWSLETTER] Unsubscribed successfully")
    }

    // MARK: - Check Status

    /// Check if email is subscribed
    @MainActor
    func isSubscribed(email: String) async throws -> Bool {
        let supabase = SupabaseManager.shared.client

        let subscribers: [NewsletterSubscriber] = try await supabase
            .from("newsletter_subscribers")
            .select("status")
            .eq("email", value: email.lowercased())
            .execute()
            .value

        return subscribers.first?.status == .active
    }

    /// Get subscription status for current user
    @MainActor
    func getCurrentUserSubscriptionStatus() async throws -> SubscriptionStatus? {
        let supabase = SupabaseManager.shared.client

        guard let session = try? await supabase.auth.session,
              let email = session.user.email else {
            return nil
        }

        let subscribers: [NewsletterSubscriber] = try await supabase
            .from("newsletter_subscribers")
            .select("status")
            .eq("email", value: email.lowercased())
            .execute()
            .value

        return subscribers.first?.status
    }

    // MARK: - Validation

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
}

// MARK: - Errors

/// Errors that can occur during newsletter operations.
///
/// Thread-safe for Swift 6 concurrency.
enum NewsletterError: LocalizedError, Sendable {
    /// Email format is invalid
    case invalidEmail
    /// Email is already subscribed
    case alreadySubscribed
    /// Subscription not found
    case notFound
    /// Network request failed
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "Please enter a valid email address"
        case .alreadySubscribed:
            "This email is already subscribed"
        case .notFound:
            "Subscription not found"
        case let .networkError(message):
            "Network error: \(message)"
        }
    }
}
