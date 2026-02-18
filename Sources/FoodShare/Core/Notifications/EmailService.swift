//
//  EmailService.swift
//  Foodshare
//
//  Email notification service using Resend API
//



#if !SKIP
import Foundation
import Supabase

enum EmailType: String, Sendable {
    case welcome
    case newMessage
    case arrangementConfirmation
    case reviewReminder
}

/// Internal email request for direct Resend API calls
private struct DirectEmailRequest: Encodable, Sendable {
    let from: String
    let to: String
    let subject: String
    let html: String
}

private struct EmailResponse: Decodable { let id: String? }

actor EmailService {
    private let apiKey: String
    private let fromEmail: String
    private let session: URLSession
    // Force unwrap is safe for compile-time constant URL
    private let baseURL = URL(string: "https://api.resend.com")! // Safe: static URL

    init(apiKey: String, fromEmail: String = "Foodshare <noreply@foodshare.club>") {
        self.apiKey = apiKey
        self.fromEmail = fromEmail
        session = URLSession.shared
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
    static func fromEnvironment() throws -> EmailService {
        guard let apiKey = ProcessInfo.processInfo.environment["RESEND_API_KEY"] else {
            throw NSError(
                domain: "EmailService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "RESEND_API_KEY not set in environment"],
            )
        }
        return EmailService(apiKey: apiKey)
    }

    func send(to: String, subject: String, html: String) async throws -> String {
        let request = DirectEmailRequest(from: fromEmail, to: to, subject: subject, html: html)
        return try await sendRequest(request)
    }

    func sendWelcome(to: String, userName: String) async throws -> String {
        let html = """
        <h1>Welcome to Foodshare, \(userName)!</h1>
        <p>Thank you for joining our community of food sharers.</p>
        """
        return try await send(to: to, subject: "Welcome to Foodshare!", html: html)
    }

    func sendNewMessage(to: String, senderName: String, postTitle: String) async throws -> String {
        let html = """
        <h2>New message from \(senderName)</h2>
        <p>About: <strong>\(postTitle)</strong></p>
        <p>Open Foodshare to reply.</p>
        """
        return try await send(to: to, subject: "New message about \(postTitle)", html: html)
    }

    func sendArrangementConfirmation(to: String, postTitle: String, otherUserName: String) async throws -> String {
        let html = """
        <h2>Pickup Arranged!</h2>
        <p><strong>\(postTitle)</strong> has been arranged with \(otherUserName).</p>
        """
        return try await send(to: to, subject: "Pickup arranged for \(postTitle)", html: html)
    }

    private func sendRequest(_ emailRequest: DirectEmailRequest) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("emails"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(emailRequest)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode) else {
            throw NSError(
                domain: "EmailService",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to send email"],
            )
        }

        let emailResponse = try JSONDecoder().decode(EmailResponse.self, from: data)
        return emailResponse.id ?? "unknown"
    }
}


#endif
