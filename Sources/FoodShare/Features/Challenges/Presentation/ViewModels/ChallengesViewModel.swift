//
//  ChallengesViewModel.swift
//  Foodshare
//
//  ViewModel for challenges feature
//

import Foundation
import Observation

@MainActor
@Observable
final class ChallengesViewModel {
    // MARK: - State

    var publishedChallenges: [Challenge] = []
    var userChallenges: [ChallengeWithStatus] = []
    var selectedChallenge: ChallengeWithStatus?
    var leaderboard: [ChallengeLeaderboardEntry] = []

    var isLoading = false
    var isLoadingLeaderboard = false
    var isJoining = false
    var error: AppError?
    var showError = false

    // MARK: - Like State

    var likeStates: [Int: Bool] = [:] // challengeId -> isLiked
    var likeCounts: [Int: Int] = [:] // challengeId -> count

    // MARK: - Filters

    var selectedFilter: ChallengeFilter = .all

    enum ChallengeFilter: String, CaseIterable {
        case all = "All"
        case joined = "Joined"
        case completed = "Completed"

        @MainActor
        func localizedDisplayName(using t: EnhancedTranslationService) -> String {
            switch self {
            case .all: t.t("challenges.filter.all")
            case .joined: t.t("challenges.filter.joined")
            case .completed: t.t("challenges.filter.completed")
            }
        }
    }

    // MARK: - Dependencies

    private let repository: ChallengeRepository
    private let userId: UUID?

    /// Whether the user is authenticated (has a userId)
    var isAuthenticated: Bool {
        userId != nil
    }

    // MARK: - Computed Properties

    var filteredChallenges: [Challenge] {
        switch selectedFilter {
        case .all:
            publishedChallenges
        case .joined:
            userChallenges.filter { $0.hasAccepted && !$0.hasCompleted }.map(\.challenge)
        case .completed:
            userChallenges.filter(\.hasCompleted).map(\.challenge)
        }
    }

    // Server-computed counts (avoid client-side .count(where:))
    private(set) var joinedChallengesCount = 0
    private(set) var completedChallengesCount = 0

    var errorMessage: String {
        error?.localizedDescription ?? "Failed to load challenges"
    }

    func localizedErrorMessage(using t: EnhancedTranslationService) -> String {
        error?.localizedDescription ?? t.t("challenges.load_failed")
    }

    // MARK: - Initialization

    init(repository: ChallengeRepository, userId: UUID? = nil) {
        self.repository = repository
        self.userId = userId
    }

    // MARK: - Actions

    func loadChallenges() async {
        guard !isLoading else { return }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Always load published challenges for all users
            publishedChallenges = try await repository.fetchPublishedChallenges()

            // Only load user-specific challenges if authenticated
            if let userId {
                // Use server-computed counts instead of client-side .count(where:)
                let result = try await repository.fetchUserChallengesWithCounts(userId: userId)
                userChallenges = result.challenges
                joinedChallengesCount = result.joinedCount
                completedChallengesCount = result.completedCount
            } else {
                userChallenges = []
                joinedChallengesCount = 0
                completedChallengesCount = 0
            }

            // Fetch translations for loaded challenges
            await fetchTranslationsForChallenges()

            await AppLogger.shared.info("Loaded \(publishedChallenges.count) challenges")
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
            await AppLogger.shared.error("Failed to load challenges", error: error)
        }
    }

    /// Fetch translations for current challenges from localization service
    private func fetchTranslationsForChallenges() async {
        let t = EnhancedTranslationService.shared

        // Skip if locale is English or no challenges
        guard t.currentLocale != "en", !publishedChallenges.isEmpty else { return }

        let challengeIds = publishedChallenges.map { Int64($0.id) }
        let translations = await t.fetchChallengeTranslations(challengeIds: challengeIds)

        guard !translations.isEmpty else { return }

        // Apply translations to published challenges
        for (index, challenge) in publishedChallenges.enumerated() {
            let challengeId = String(challenge.id)
            if let trans = translations[challengeId] {
                var updatedChallenge = challenge
                if let title = trans["title"] ?? nil {
                    updatedChallenge.titleTranslated = title
                }
                if let desc = trans["description"] ?? nil {
                    updatedChallenge.descriptionTranslated = desc
                }
                if updatedChallenge.titleTranslated != nil || updatedChallenge.descriptionTranslated != nil {
                    updatedChallenge.translationLocale = t.currentLocale
                    publishedChallenges[index] = updatedChallenge
                }
            }
        }

        // Also update challenges in userChallenges
        for (index, challengeWithStatus) in userChallenges.enumerated() {
            let challengeId = String(challengeWithStatus.challenge.id)
            if let trans = translations[challengeId] {
                var updatedChallenge = challengeWithStatus.challenge
                if let title = trans["title"] ?? nil {
                    updatedChallenge.titleTranslated = title
                }
                if let desc = trans["description"] ?? nil {
                    updatedChallenge.descriptionTranslated = desc
                }
                if updatedChallenge.titleTranslated != nil || updatedChallenge.descriptionTranslated != nil {
                    updatedChallenge.translationLocale = t.currentLocale
                    userChallenges[index] = ChallengeWithStatus(
                        challenge: updatedChallenge,
                        activity: challengeWithStatus.activity,
                        userId: challengeWithStatus.userId,
                    )
                }
            }
        }

        await AppLogger.shared.debug("Applied translations to \(translations.count) challenges")
    }

    func selectChallenge(_ challenge: Challenge) async {
        // For unauthenticated users, create a basic ChallengeWithStatus without activity
        guard let userId else {
            selectedChallenge = ChallengeWithStatus(challenge: challenge, activity: nil, userId: nil)
            await loadLeaderboard(for: challenge.id)
            return
        }

        do {
            selectedChallenge = try await repository.fetchChallenge(id: challenge.id, userId: userId)
            await loadLeaderboard(for: challenge.id)
        } catch {
            await AppLogger.shared.error("Failed to fetch challenge details", error: error)
        }
    }

    func acceptChallenge(_ challengeId: Int) async {
        guard let userId else {
            await AppLogger.shared.warning("Cannot accept challenge: user not authenticated")
            return
        }
        guard !isJoining else { return }

        isJoining = true
        defer { isJoining = false }

        do {
            _ = try await repository.acceptChallenge(challengeId: challengeId, userId: userId)
            HapticManager.success()

            // Refresh challenges
            await loadChallenges()

            // Update selected challenge if viewing
            if let challenge = selectedChallenge, challenge.challenge.id == challengeId {
                await selectChallenge(challenge.challenge)
            }

            await AppLogger.shared.info("Accepted challenge \(challengeId)")
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
            HapticManager.error()
            await AppLogger.shared.error("Failed to accept challenge", error: error)
        }
    }

    func completeChallenge(_ challengeId: Int) async {
        guard let userId else {
            await AppLogger.shared.warning("Cannot complete challenge: user not authenticated")
            return
        }

        do {
            _ = try await repository.completeChallenge(challengeId: challengeId, userId: userId)
            HapticManager.success()

            // Refresh challenges
            await loadChallenges()

            // Update selected challenge if viewing
            if let selected = selectedChallenge, selected.challenge.id == challengeId {
                await selectChallenge(selected.challenge)
            }

            await AppLogger.shared.info("Completed challenge \(challengeId)")
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
            HapticManager.error()
            await AppLogger.shared.error("Failed to complete challenge", error: error)
        }
    }

    func rejectChallenge(_ challengeId: Int) async {
        guard let userId else {
            await AppLogger.shared.warning("Cannot reject challenge: user not authenticated")
            return
        }

        do {
            _ = try await repository.rejectChallenge(challengeId: challengeId, userId: userId)
            HapticManager.light()

            // Refresh challenges
            await loadChallenges()

            await AppLogger.shared.info("Rejected challenge \(challengeId)")
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
            await AppLogger.shared.error("Failed to reject challenge", error: error)
        }
    }

    func loadLeaderboard(for challengeId: Int) async {
        guard !isLoadingLeaderboard else { return }

        isLoadingLeaderboard = true
        defer { isLoadingLeaderboard = false }

        do {
            leaderboard = try await repository.fetchLeaderboard(challengeId: challengeId, limit: 10)
        } catch {
            await AppLogger.shared.error("Failed to load leaderboard", error: error)
        }
    }

    func userStatus(for challenge: Challenge) -> ChallengeUserStatus {
        if let userChallenge = userChallenges.first(where: { $0.challenge.id == challenge.id }) {
            return userChallenge.status
        }
        return .notJoined
    }

    func dismissError() {
        error = nil
        showError = false
    }

    func refresh() async {
        await loadChallenges()
        HapticManager.light()
    }

    // MARK: - Like Actions
    // Note: Like toggling is now handled by ChallengeLikeButton component
    // using ChallengeEngagementService for consistency with Feed feature

    /// Check like status for a challenge using the centralized service
    func checkLikeStatus(for challengeId: Int) async {
        guard userId != nil else { return }

        do {
            let result = try await ChallengeEngagementService.shared.checkLiked(challengeId: challengeId)
            likeStates[challengeId] = result.isLiked
            likeCounts[challengeId] = result.likeCount
        } catch {
            // Silently fail - not critical
            await AppLogger.shared.debug("Failed to check like status for challenge \(challengeId)")
        }
    }

    func isLiked(challengeId: Int) -> Bool {
        likeStates[challengeId] ?? false
    }

    func likeCount(for challengeId: Int) -> Int {
        // Return cached count or fall back to challenge model count
        if let cached = likeCounts[challengeId] {
            return cached
        }
        return publishedChallenges.first(where: { $0.id == challengeId })?.challengeLikesCounter ?? 0
    }
}
