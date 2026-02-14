//
//  AuthUser.swift
//  Foodshare
//
//  Domain model for authenticated user
//

import Foundation

struct AuthUser: Identifiable, Codable, Sendable {
    let id: UUID
    let email: String
    let emailConfirmedAt: Date?
    let createdAt: Date
    let lastSignInAt: Date?

    var isEmailConfirmed: Bool {
        emailConfirmedAt != nil
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case emailConfirmedAt = "email_confirmed_at"
        case createdAt = "created_at"
        case lastSignInAt = "last_sign_in_at"
    }
}

// MARK: - Auth Credentials

struct SignInCredentials: Sendable {
    let email: String
    let password: String

    func validate() throws {
        guard email.isValidEmail else {
            throw AuthError.invalidEmail
        }

        guard password.count >= 8 else {
            throw AuthError.passwordTooShort
        }
    }
}

struct SignUpCredentials: Sendable {
    let email: String
    let password: String
    let confirmPassword: String
    let nickname: String?

    func validate() throws {
        guard email.isValidEmail else {
            throw AuthError.invalidEmail
        }

        guard password.count >= 8 else {
            throw AuthError.passwordTooShort
        }

        guard password == confirmPassword else {
            throw AuthError.passwordMismatch
        }

        // Password strength validation
        guard password.containsUppercase, password.containsLowercase, password.containsNumber else {
            throw AuthError.weakPassword
        }
    }
}

struct PasswordResetRequest: Sendable {
    let email: String

    func validate() throws {
        guard email.isValidEmail else {
            throw AuthError.invalidEmail
        }
    }
}

// MARK: - Auth Error

enum AuthError: LocalizedError, Sendable {
    case invalidEmail
    case passwordTooShort
    case passwordMismatch
    case weakPassword
    case userNotFound
    case wrongPassword
    case emailAlreadyInUse
    case networkError
    case sessionExpired
    case unauthorized
    case oauthCancelled
    case oauthFailed(String)
    case emailConfirmationRequired(String)
    case invalidSession(String)
    case profileCreationFailed(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            "Please enter a valid email address"
        case .passwordTooShort:
            "Password must be at least 8 characters"
        case .passwordMismatch:
            "Passwords do not match"
        case .weakPassword:
            "Password must contain uppercase, lowercase, and numbers"
        case .userNotFound:
            "No account found with this email"
        case .wrongPassword:
            "Incorrect password"
        case .emailAlreadyInUse:
            "An account with this email already exists"
        case .networkError:
            "Network connection failed. Please try again"
        case .sessionExpired:
            "Your session has expired. Please sign in again"
        case .unauthorized:
            "You are not authorized to perform this action"
        case .oauthCancelled:
            "Sign in was cancelled"
        case let .oauthFailed(message):
            "Sign in failed: \(message)"
        case let .emailConfirmationRequired(message):
            message
        case let .invalidSession(message):
            "Session error: \(message)"
        case let .profileCreationFailed(message):
            message
        case let .unknown(message):
            message
        }
    }
}

// MARK: - String Extensions

extension String {
    fileprivate var isValidEmail: Bool {
        let emailRegex = "^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Z|a-z]{2,}$"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: self)
    }

    fileprivate var containsUppercase: Bool {
        range(of: "[A-Z]", options: .regularExpression) != nil
    }

    fileprivate var containsLowercase: Bool {
        range(of: "[a-z]", options: .regularExpression) != nil
    }

    fileprivate var containsNumber: Bool {
        range(of: "[0-9]", options: .regularExpression) != nil
    }
}

// MARK: - Test Fixtures

extension AuthUser {
    /// Create a fixture for testing
    static func fixture(
        id: UUID = UUID(),
        email: String = "test@example.com",
        emailConfirmedAt: Date? = Date(),
        createdAt: Date = Date(),
        lastSignInAt: Date? = Date(),
    ) -> AuthUser {
        AuthUser(
            id: id,
            email: email,
            emailConfirmedAt: emailConfirmedAt,
            createdAt: createdAt,
            lastSignInAt: lastSignInAt,
        )
    }
}

extension SignInCredentials {
    /// Create a fixture for testing
    static func fixture(
        email: String = "test@example.com",
        password: String = "Password123",
    ) -> SignInCredentials {
        SignInCredentials(email: email, password: password)
    }
}

extension SignUpCredentials {
    /// Create a fixture for testing
    static func fixture(
        email: String = "test@example.com",
        password: String = "Password123",
        confirmPassword: String = "Password123",
        nickname: String? = "TestUser",
    ) -> SignUpCredentials {
        SignUpCredentials(
            email: email,
            password: password,
            confirmPassword: confirmPassword,
            nickname: nickname,
        )
    }
}
