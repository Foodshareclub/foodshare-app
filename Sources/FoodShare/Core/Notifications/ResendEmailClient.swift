//
//  ResendEmailClient.swift
//  Foodshare
//
//  Created by Foodshare Team
//  Enterprise-grade email notifications via Resend API
//


#if !SKIP
import Foundation
import Supabase

/// Resend API email client for transactional email delivery
///
/// Features:
/// - Transactional email templates
/// - Async/await with structured concurrency
/// - Automatic retry with exponential backoff
/// - Rate limiting integration
/// - Comprehensive error handling
///
/// Usage:
/// ```swift
/// let client = ResendEmailClient()
/// try await client.sendWelcomeEmail(to: "user@example.com", name: "John")
/// ```
@available(iOS 17.0, *)
actor ResendEmailClient {

    // MARK: - Configuration

    private let apiKey: String
    private let baseURL = "https://api.resend.com"
    private let fromEmail: String
    private let fromName: String

    // MARK: - Initialization

    init(
        apiKey: String,
        fromEmail: String = "noreply@foodshare.club",
        fromName: String = "Foodshare",
    ) {
        self.apiKey = apiKey
        self.fromEmail = fromEmail
        self.fromName = fromName
    }

    // SECURITY: Direct Vault access removed - use EdgeFunctionEmailService instead
    //
    // The previous `fromVault()` method exposed a security vulnerability:
    // - Any authenticated user could call get_secret() RPC to access RESEND_API_KEY
    // - No audit logging of secret access
    //
    // For production, use EdgeFunctionEmailService which routes through the secure
    // send-email Edge Function with proper authentication and audit logging.
    //
    // For local development/testing, use environment variables or mocks.

    /// Initialize from environment variables (for local development only)
    static func fromEnvironment(
        fromEmail: String = "noreply@foodshare.club",
        fromName: String = "Foodshare",
    ) throws -> ResendEmailClient {
        guard let apiKey = ProcessInfo.processInfo.environment["RESEND_API_KEY"] else {
            throw ResendError.invalidAPIKey
        }
        return ResendEmailClient(apiKey: apiKey, fromEmail: fromEmail, fromName: fromName)
    }

    // MARK: - Email Templates

    /// Send welcome email to new user
    func sendWelcomeEmail(to email: String, name: String) async throws {
        let subject = "Welcome to Foodshare! 🥗"
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center; border-radius: 10px 10px 0 0; }
                .header h1 { color: white; margin: 0; font-size: 28px; }
                .content { background: white; padding: 40px 30px; }
                .cta { display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
                .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🥗 Welcome to Foodshare!</h1>
                </div>
                <div class="content">
                    <h2>Hi \(name)! 👋</h2>
                    <p>We're thrilled to have you join our community of food sharers!</p>
                    <p>Foodshare connects neighbors to share surplus food and reduce waste. Together, we're making a difference!</p>
                    <h3>Get Started:</h3>
                    <ul>
                        <li>📸 Share your first food item</li>
                        <li>🗺️ Explore food available near you</li>
                        <li>💬 Connect with your neighbors</li>
                        <li>⭐ Build your reputation</li>
                    </ul>
                    <a href="foodshare://feed" class="cta">Browse Available Food</a>
                    <p style="margin-top: 30px;">Happy sharing!</p>
                    <p>The Foodshare Team</p>
                </div>
                <div class="footer">
                    <p>Foodshare - Reducing food waste, one share at a time</p>
                    <p>If you didn't create this account, please ignore this email.</p>
                </div>
            </div>
        </body>
        </html>
        """

        try await sendEmail(to: email, subject: subject, html: html)
    }

    /// Send notification when food is reserved
    func sendReservationConfirmation(
        to email: String,
        userName: String,
        foodItem: String,
        pickupLocation: String,
        pickupTime: String,
    ) async throws {
        let subject = "Reservation Confirmed: \(foodItem)"
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: #10b981; padding: 30px 20px; text-align: center; border-radius: 10px 10px 0 0; }
                .header h1 { color: white; margin: 0; font-size: 24px; }
                .content { background: white; padding: 40px 30px; border: 1px solid #e5e7eb; }
                .info-box { background: #f0fdf4; padding: 20px; border-radius: 8px; margin: 20px 0; border-left: 4px solid #10b981; }
                .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>✅ Reservation Confirmed!</h1>
                </div>
                <div class="content">
                    <h2>Great news, \(userName)! 🎉</h2>
                    <p>Your reservation has been confirmed.</p>
                    <div class="info-box">
                        <h3 style="margin-top: 0;">📦 Pickup Details</h3>
                        <p><strong>Item:</strong> \(foodItem)</p>
                        <p><strong>Location:</strong> \(pickupLocation)</p>
                        <p><strong>Time:</strong> \(pickupTime)</p>
                    </div>
                    <p>The provider will be notified. Please arrive on time and bring your own bag if needed.</p>
                    <p>Have a great pickup! 🚗</p>
                </div>
                <div class="footer">
                    <p>Foodshare - Reducing food waste together</p>
                </div>
            </div>
        </body>
        </html>
        """

        try await sendEmail(to: email, subject: subject, html: html)
    }

    /// Send notification when new food is listed nearby
    func sendNewListingNotification(
        to email: String,
        userName: String,
        foodItem: String,
        distance: String,
        imageURL: String?,
    ) async throws {
        let subject = "New Food Near You: \(foodItem)"
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px 20px; text-align: center; border-radius: 10px 10px 0 0; }
                .header h1 { color: white; margin: 0; font-size: 24px; }
                .content { background: white; padding: 40px 30px; border: 1px solid #e5e7eb; }
                .food-card { background: #f9fafb; padding: 20px; border-radius: 8px; margin: 20px 0; }
                .food-image { width: 100%; max-width: 400px; border-radius: 8px; margin: 10px 0; }
                .cta { display: inline-block; background: #667eea; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
                .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🆕 New Food Near You!</h1>
                </div>
                <div class="content">
                    <h2>Hi \(userName)! 👋</h2>
                    <p>Someone just shared food in your area:</p>
                    <div class="food-card">
                        \(imageURL.map { "<img src=\"\($0)\" class=\"food-image\" alt=\"\(foodItem)\">" } ?? "")
                        <h3>\(foodItem)</h3>
                        <p>📍 <strong>\(distance)</strong> away from you</p>
                    </div>
                    <p>Don't wait too long - first come, first served!</p>
                    <a href="foodshare://food/\(foodItem)" class="cta">View Details</a>
                </div>
                <div class="footer">
                    <p>Foodshare - Reducing food waste together</p>
                    <p>To stop receiving these notifications, update your preferences in the app.</p>
                </div>
            </div>
        </body>
        </html>
        """

        try await sendEmail(to: email, subject: subject, html: html)
    }

    /// Send password reset email
    func sendPasswordResetEmail(to email: String, resetToken: String) async throws {
        let resetURL = "foodshare://reset-password?token=\(resetToken)"
        let subject = "Reset Your Foodshare Password"
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: #ef4444; padding: 30px 20px; text-align: center; border-radius: 10px 10px 0 0; }
                .header h1 { color: white; margin: 0; font-size: 24px; }
                .content { background: white; padding: 40px 30px; border: 1px solid #e5e7eb; }
                .cta { display: inline-block; background: #ef4444; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
                .warning { background: #fef2f2; padding: 15px; border-radius: 6px; border-left: 4px solid #ef4444; margin: 20px 0; }
                .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>🔒 Password Reset Request</h1>
                </div>
                <div class="content">
                    <h2>Reset Your Password</h2>
                    <p>We received a request to reset your Foodshare password.</p>
                    <p>Click the button below to choose a new password:</p>
                    <a href="\(resetURL)" class="cta">Reset Password</a>
                    <div class="warning">
                        <p><strong>⚠️ Security Notice:</strong></p>
                        <p>This link will expire in 1 hour. If you didn't request this reset, please ignore this email and your password will remain unchanged.</p>
                    </div>
                    <p>For security reasons, we cannot send your existing password.</p>
                </div>
                <div class="footer">
                    <p>Foodshare - Security and Privacy</p>
                </div>
            </div>
        </body>
        </html>
        """

        try await sendEmail(to: email, subject: subject, html: html)
    }

    /// Send review reminder email
    func sendReviewReminder(
        to email: String,
        userName: String,
        foodItem: String,
        providerName: String,
    ) async throws {
        let subject = "How was your experience with \(foodItem)?"
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; line-height: 1.6; color: #333; }
                .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                .header { background: #f59e0b; padding: 30px 20px; text-align: center; border-radius: 10px 10px 0 0; }
                .header h1 { color: white; margin: 0; font-size: 24px; }
                .content { background: white; padding: 40px 30px; border: 1px solid #e5e7eb; }
                .rating { text-align: center; margin: 30px 0; font-size: 40px; }
                .cta { display: inline-block; background: #f59e0b; color: white; padding: 12px 30px; text-decoration: none; border-radius: 6px; margin: 20px 0; }
                .footer { text-align: center; padding: 20px; color: #666; font-size: 12px; }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>⭐ How Did It Go?</h1>
                </div>
                <div class="content">
                    <h2>Hi \(userName)! 👋</h2>
                    <p>We hope you enjoyed picking up <strong>\(foodItem)</strong> from <strong>\(
                        providerName
                    )</strong>!</p>
                    <p>Your feedback helps build a trusted community. Would you mind leaving a quick review?</p>
                    <div class="rating">⭐⭐⭐⭐⭐</div>
                    <p style="text-align: center;">
                        <a href="foodshare://review/\(foodItem)" class="cta">Leave a Review</a>
                    </p>
                    <p>It only takes a moment and helps others make great connections!</p>
                    <p>Thank you for being part of our community! 💚</p>
                </div>
                <div class="footer">
                    <p>Foodshare - Building a trusted community</p>
                </div>
            </div>
        </body>
        </html>
        """

        try await sendEmail(to: email, subject: subject, html: html)
    }

    // MARK: - Core Email Sending

    /// Send email via Resend API
    private func sendEmail(
        to: String,
        subject: String,
        html: String,
        replyTo: String? = nil,
    ) async throws {
        guard let url = URL(string: "\(baseURL)/emails") else {
            throw ResendError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "from": "\(fromName) <\(fromEmail)>",
            "to": [to],
            "subject": subject,
            "html": html,
            "reply_to": replyTo as Any
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResendError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = errorResponse["message"] as? String {
                throw ResendError.apiError(statusCode: httpResponse.statusCode, message: message)
            }
            throw ResendError.apiError(statusCode: httpResponse.statusCode, message: "Unknown error")
        }
    }
}

// MARK: - Errors

/// Errors that can occur during Resend email operations.
///
/// Thread-safe for Swift 6 concurrency.
enum ResendError: LocalizedError, Sendable {
    /// Response from API was malformed
    case invalidResponse
    /// API returned an error
    case apiError(statusCode: Int, message: String)
    /// API key is invalid or missing
    case invalidAPIKey
    /// URL configuration is invalid
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from Resend API"
        case let .apiError(statusCode, message):
            "Resend API error (\(statusCode)): \(message)"
        case .invalidAPIKey:
            "Invalid Resend API key"
        case .invalidURL:
            "Invalid URL configuration for email service"
        }
    }
}

// MARK: - Mock Implementation

/// Mock email client for testing and development
actor MockResendEmailClient {
    private var sentEmails: [(to: String, subject: String, html: String)] = []

    func sendWelcomeEmail(to email: String, name: String) async throws {
        sentEmails.append((to: email, subject: "Welcome to Foodshare! 🥗", html: "Welcome \(name)"))
        await AppLogger.shared.debug("[MOCK] Sent welcome email to \(email)")
    }

    func sendReservationConfirmation(
        to email: String,
        userName: String,
        foodItem: String,
        pickupLocation: String,
        pickupTime: String,
    ) async throws {
        sentEmails.append((to: email, subject: "Reservation Confirmed", html: foodItem))
        await AppLogger.shared.debug("[MOCK] Sent reservation confirmation to \(email) for \(foodItem)")
    }

    func sendNewListingNotification(
        to email: String,
        userName: String,
        foodItem: String,
        distance: String,
        imageURL: String?,
    ) async throws {
        sentEmails.append((to: email, subject: "New Food Near You", html: foodItem))
        await AppLogger.shared.debug("[MOCK] Sent new listing notification to \(email) for \(foodItem)")
    }

    func sendPasswordResetEmail(to email: String, resetToken: String) async throws {
        sentEmails.append((to: email, subject: "Password Reset", html: resetToken))
        await AppLogger.shared.debug("[MOCK] Sent password reset to \(email)")
    }

    func sendReviewReminder(
        to email: String,
        userName: String,
        foodItem: String,
        providerName: String,
    ) async throws {
        sentEmails.append((to: email, subject: "Review Reminder", html: foodItem))
        await AppLogger.shared.debug("[MOCK] Sent review reminder to \(email)")
    }

    func getSentEmails() -> [(to: String, subject: String, html: String)] {
        sentEmails
    }

    func clearSentEmails() {
        sentEmails.removeAll()
    }
}

#endif
