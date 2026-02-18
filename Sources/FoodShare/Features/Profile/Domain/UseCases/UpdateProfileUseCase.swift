//
//  UpdateProfileUseCase.swift
//  Foodshare
//
//  Use case for updating user profile
//


#if !SKIP
import Foundation

@MainActor
final class UpdateProfileUseCase {
    private let repository: ProfileRepository

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func execute(userId: UUID, request: UpdateProfileRequest) async throws -> UserProfile {
        // Validate nickname if provided
        if let nickname = request.nickname {
            guard nickname.count >= 2, nickname.count <= 50 else {
                throw ProfileError.invalidNickname
            }
        }

        // Validate bio if provided
        if let bio = request.bio {
            guard bio.count <= 500 else {
                throw ProfileError.bioTooLong
            }
        }

        return try await repository.updateProfile(userId: userId, request: request)
    }
}

/// Errors that can occur during profile operations.
///
/// Thread-safe for Swift 6 concurrency.
enum ProfileError: LocalizedError, Sendable {
    /// Nickname doesn't meet length requirements
    case invalidNickname
    /// Bio exceeds maximum length
    case bioTooLong
    /// Avatar image upload failed
    case uploadFailed
    /// Profile not found
    case notFound
    /// User is not authorized for this operation
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .invalidNickname:
            "Nickname must be 2-50 characters"
        case .bioTooLong:
            "Bio must be less than 500 characters"
        case .uploadFailed:
            "Failed to upload avatar"
        case .notFound:
            "Profile not found"
        case .unauthorized:
            "You don't have permission to modify this profile"
        }
    }
}

#endif
