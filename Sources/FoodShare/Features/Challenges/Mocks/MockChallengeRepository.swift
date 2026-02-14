//
//  MockChallengeRepository.swift
//  Foodshare
//
//  Mock challenge repository for testing and previews
//

import Foundation

#if DEBUG
    final class MockChallengeRepository: ChallengeRepository, @unchecked Sendable {
        nonisolated(unsafe) var mockChallenges: [Challenge] = []
        nonisolated(unsafe) var mockUserChallenges: [ChallengeWithStatus] = []
        nonisolated(unsafe) var mockLeaderboard: [ChallengeLeaderboardEntry] = []
        nonisolated(unsafe) var likedChallenges: Set<Int> = []
        nonisolated(unsafe) var shouldFail = false

        init() {
            // Initialize with sample data
            mockChallenges = Challenge.sampleChallenges
            mockLeaderboard = [
                ChallengeLeaderboardEntry.fixture(rank: 1, nickname: "EcoChampion"),
                ChallengeLeaderboardEntry.fixture(rank: 2, nickname: "FoodSaver"),
                ChallengeLeaderboardEntry.fixture(rank: 3, nickname: "GreenHero")
            ]
        }

        func fetchPublishedChallenges() async throws -> [Challenge] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            return mockChallenges
        }

        func fetchUserChallenges(userId: UUID) async throws -> [ChallengeWithStatus] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)
            return mockUserChallenges
        }

        func fetchUserChallengesWithCounts(userId: UUID) async throws -> UserChallengesWithCountsResult {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            let joinedCount = mockUserChallenges.count { $0.hasAccepted }
            let completedCount = mockUserChallenges.count { $0.hasCompleted }

            return UserChallengesWithCountsResult(
                challenges: mockUserChallenges,
                joinedCount: joinedCount,
                completedCount: completedCount,
            )
        }

        func fetchChallenge(id: Int, userId: UUID) async throws -> ChallengeWithStatus {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            guard let challenge = mockChallenges.first(where: { $0.id == id }) else {
                throw AppError.notFound(resource: "Challenge")
            }
            return ChallengeWithStatus(challenge: challenge, status: .inProgress)
        }

        func acceptChallenge(challengeId: Int, userId: UUID) async throws -> ChallengeActivity {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return ChallengeActivity(
                id: 1,
                challengeId: challengeId,
                profileId: userId,
                status: .inProgress,
                createdAt: Date(),
                updatedAt: Date(),
            )
        }

        func completeChallenge(challengeId: Int, userId: UUID) async throws -> ChallengeActivity {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return ChallengeActivity(
                id: 1,
                challengeId: challengeId,
                profileId: userId,
                status: .completed,
                createdAt: Date(),
                updatedAt: Date(),
            )
        }

        func rejectChallenge(challengeId: Int, userId: UUID) async throws -> ChallengeActivity {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return ChallengeActivity(
                id: 1,
                challengeId: challengeId,
                profileId: userId,
                status: .rejected,
                createdAt: Date(),
                updatedAt: Date(),
            )
        }

        func fetchLeaderboard(challengeId: Int, limit: Int) async throws -> [ChallengeLeaderboardEntry] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 200_000_000)
            return Array(mockLeaderboard.prefix(limit))
        }

        func toggleChallengeLike(challengeId: Int, profileId: UUID) async throws -> (isLiked: Bool, likeCount: Int) {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            if likedChallenges.contains(challengeId) {
                likedChallenges.remove(challengeId)
                return (false, max(0, 10 - 1))
            } else {
                likedChallenges.insert(challengeId)
                return (true, 10 + 1)
            }
        }

        func hasLikedChallenge(challengeId: Int, profileId: UUID) async throws -> Bool {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return likedChallenges.contains(challengeId)
        }
    }
#endif
