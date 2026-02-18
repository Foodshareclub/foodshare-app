//
//  MockProfileRepository.swift
//  Foodshare
//
//  Mock profile repository for previews and testing
//


#if !SKIP
import Foundation

#if DEBUG
    /// Mock implementation of ProfileRepository for previews
    final class MockProfileRepository: ProfileRepository {
        nonisolated(unsafe) var mockProfile: UserProfile?
        nonisolated(unsafe) var mockAddress: Address?
        nonisolated(unsafe) var shouldFail = false
        nonisolated(unsafe) var fetchCallCount = 0
        nonisolated(unsafe) var updateCallCount = 0
        nonisolated(unsafe) var updateSearchRadiusCallCount = 0
        nonisolated(unsafe) var fetchAddressCallCount = 0
        nonisolated(unsafe) var upsertAddressCallCount = 0
        nonisolated(unsafe) var deleteAddressCallCount = 0

        func fetchProfile(userId: UUID) async throws -> UserProfile {
            fetchCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            return mockProfile ?? UserProfile.fixture()
        }

        func updateProfile(userId: UUID, request: UpdateProfileRequest) async throws -> UserProfile {
            updateCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            // Update mock profile with new values
            if let current = mockProfile {
                mockProfile = UserProfile(
                    id: current.id,
                    nickname: request.nickname ?? current.nickname,
                    avatarUrl: current.avatarUrl,
                    bio: request.bio ?? current.bio,
                    aboutMe: request.aboutMe ?? current.aboutMe,
                    ratingAverage: current.ratingAverage,
                    itemsShared: current.itemsShared,
                    itemsReceived: current.itemsReceived,
                    ratingCount: current.ratingCount,
                    createdTime: current.createdTime,
                    searchRadiusKm: current.searchRadiusKm,
                    preferredLocale: current.preferredLocale,
                )
            }

            return mockProfile ?? UserProfile.fixture()
        }

        func updateSearchRadius(userId: UUID, radiusKm: Int) async throws {
            updateSearchRadiusCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            // Simulate network delay
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            // Update mock profile with new search radius
            if let current = mockProfile {
                mockProfile = UserProfile(
                    id: current.id,
                    nickname: current.nickname,
                    avatarUrl: current.avatarUrl,
                    bio: current.bio,
                    aboutMe: current.aboutMe,
                    ratingAverage: current.ratingAverage,
                    itemsShared: current.itemsShared,
                    itemsReceived: current.itemsReceived,
                    ratingCount: current.ratingCount,
                    createdTime: current.createdTime,
                    searchRadiusKm: radiusKm,
                    preferredLocale: current.preferredLocale,
                )
            }
        }

        func fetchProfileAnalytics(userId: UUID) async throws -> ProfileAnalytics {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            let profile = mockProfile ?? UserProfile.fixture()
            return ProfileAnalytics(
                success: true,
                userId: userId,
                completion: ProfileCompletionData(
                    percentage: 80,
                    completedCount: 4,
                    totalFields: 5,
                    completedFields: ["Display name", "Profile photo", "Bio", "Location"],
                    missingFields: ["First food share"],
                    isComplete: false,
                    nextStep: "First food share",
                ),
                rank: CommunityRankData(
                    tier: "Community Helper",
                    nextTier: "Sharing Champion",
                    progressToNextTier: 50,
                    totalExchanges: profile.itemsShared + profile.itemsReceived,
                ),
                impact: ImpactMetricsData(
                    mealsShared: profile.itemsShared,
                    mealsReceived: profile.itemsReceived,
                    foodSavedKg: Double(profile.itemsShared) * 0.5,
                    co2SavedKg: Double(profile.itemsShared) * 2.5,
                    waterSavedLiters: Double(profile.itemsShared) * 100,
                    moneySavedUsd: Double(profile.itemsShared) * 5.0,
                    equivalentTrees: Double(profile.itemsShared) * 2.5 / 21,
                    equivalentCarMiles: Double(profile.itemsShared) * 2.5 / 0.404,
                ),
                ratingAverage: profile.ratingAverage,
                ratingCount: profile.ratingCount,
                calculatedAt: Date(),
            )
        }

        // MARK: - Address Methods

        func fetchAddress(profileId: UUID) async throws -> Address? {
            fetchAddressCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            return mockAddress
        }

        func upsertAddress(profileId: UUID, address: EditableAddress) async throws -> Address {
            upsertAddressCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            let newAddress = Address(
                id: mockAddress?.id ?? UUID(),
                profileId: profileId,
                addressLine1: address.addressLine1.isEmpty ? nil : address.addressLine1,
                addressLine2: address.addressLine2.isEmpty ? nil : address.addressLine2,
                city: address.city.isEmpty ? nil : address.city,
                stateProvince: address.stateProvince.isEmpty ? nil : address.stateProvince,
                postalCode: address.postalCode.isEmpty ? nil : address.postalCode,
                country: address.country.isEmpty ? nil : address.country,
                latitude: address.latitude,
                longitude: address.longitude,
                createdAt: mockAddress?.createdAt ?? Date(),
                updatedAt: Date(),
            )
            mockAddress = newAddress
            return newAddress
        }

        func deleteAddress(profileId: UUID) async throws {
            deleteAddressCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds

            mockAddress = nil
        }

        // MARK: - Blocking

        nonisolated(unsafe) var blockedUserIds: Set<UUID> = []
        nonisolated(unsafe) var blockCallCount = 0
        nonisolated(unsafe) var unblockCallCount = 0

        func blockUser(userId: UUID, blockedUserId: UUID, reason: String?) async throws {
            blockCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            try await Task.sleep(nanoseconds: 200_000_000)

            blockedUserIds.insert(blockedUserId)
        }

        func unblockUser(userId: UUID, blockedUserId: UUID) async throws {
            unblockCallCount += 1

            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            try await Task.sleep(nanoseconds: 200_000_000)

            blockedUserIds.remove(blockedUserId)
        }

        func getBlockedUsers(userId: UUID) async throws -> [BlockedUser] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            try await Task.sleep(nanoseconds: 200_000_000)

            // Return empty array for mock - tests can override if needed
            return []
        }

        func isUserBlocked(userId: UUID, targetUserId: UUID) async throws -> Bool {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            return blockedUserIds.contains(targetUserId)
        }

        // MARK: - Test Helpers

        func reset() {
            mockProfile = nil
            mockAddress = nil
            shouldFail = false
            fetchCallCount = 0
            updateCallCount = 0
            updateSearchRadiusCallCount = 0
            fetchAddressCallCount = 0
            upsertAddressCallCount = 0
            deleteAddressCallCount = 0
            blockedUserIds = []
            blockCallCount = 0
            unblockCallCount = 0
        }
    }
#endif

#endif
