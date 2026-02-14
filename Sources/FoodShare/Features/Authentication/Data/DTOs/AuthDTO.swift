//
//  AuthDTO.swift
//  Foodshare
//
//  Data Transfer Objects for authentication
//

import Foundation

/// DTO for Supabase auth user response
struct AuthUserDTO: Codable {
    let id: String
    let email: String
    let emailConfirmedAt: String?
    let createdAt: String
    let lastSignInAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case emailConfirmedAt = "email_confirmed_at"
        case createdAt = "created_at"
        case lastSignInAt = "last_sign_in_at"
    }

    /// Convert DTO to domain model
    func toDomain() throws -> AuthUser {
        guard let userId = UUID(uuidString: id) else {
            throw AuthError.unknown("Invalid user ID format")
        }

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let createdDate = dateFormatter.date(from: createdAt) else {
            throw AuthError.unknown("Invalid date format")
        }

        let emailConfirmedDate = emailConfirmedAt.flatMap { dateFormatter.date(from: $0) }
        let lastSignInDate = lastSignInAt.flatMap { dateFormatter.date(from: $0) }

        return AuthUser(
            id: userId,
            email: email,
            emailConfirmedAt: emailConfirmedDate,
            createdAt: createdDate,
            lastSignInAt: lastSignInDate,
        )
    }
}

/// DTO for sign up request
struct SignUpRequestDTO: Codable {
    let email: String
    let password: String
    let data: [String: String]?

    init(email: String, password: String, nickname: String? = nil) {
        self.email = email
        self.password = password
        data = nickname.map { ["nickname": $0] }
    }
}

/// DTO for sign in request
struct SignInRequestDTO: Codable {
    let email: String
    let password: String
}

/// DTO for password reset request
struct PasswordResetRequestDTO: Codable {
    let email: String
}
