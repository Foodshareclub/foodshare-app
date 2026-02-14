//
//  FetchProfileUseCase.swift
//  Foodshare
//
//  Use case for fetching user profile
//

import Foundation

@MainActor
final class FetchProfileUseCase {
    private let repository: ProfileRepository

    init(repository: ProfileRepository) {
        self.repository = repository
    }

    func execute(userId: UUID) async throws -> UserProfile {
        try await repository.fetchProfile(userId: userId)
    }
}
