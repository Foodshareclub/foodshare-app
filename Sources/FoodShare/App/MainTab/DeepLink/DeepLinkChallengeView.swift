//
//  DeepLinkChallengeView.swift
//  Foodshare
//
//  Wrapper view for deep-linking to a specific challenge
//


#if !SKIP
import SwiftUI

/// Wrapper view for deep-linking to a specific challenge
struct DeepLinkChallengeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t
    let challengeId: Int
    @State private var challengeWithStatus: ChallengeWithStatus?
    @State private var challengesViewModel: ChallengesViewModel?
    @State private var isLoading = true
    @State private var error: Error?

    var body: some View {
        Group {
            if let challengeWithStatus, let viewModel = challengesViewModel {
                ChallengeDetailView(challenge: challengeWithStatus.challenge, viewModel: viewModel)
            } else if isLoading {
                ProgressView(t.t("status.loading_challenge"))
            } else if error != nil {
                ContentUnavailableView(
                    t.t("errors.not_found.challenge"),
                    systemImage: "exclamationmark.triangle",
                    description: Text(t.t("errors.not_found.challenge_desc")),
                )
            }
        }
        .task {
            await loadChallenge()
        }
    }

    private func loadChallenge() async {
        isLoading = true
        defer { isLoading = false }

        let userId = appState.currentUser?.id

        do {
            // Fetch the challenge - works with or without auth
            let challenge = try await appState.dependencies.challengeRepository.fetchPublishedChallenges()
                .first { $0.id == challengeId }

            guard let challenge else {
                error = AppError.notFound(resource: "challenge")
                return
            }

            // Create challenge with status (activity will be nil for unauthenticated)
            challengeWithStatus = ChallengeWithStatus(challenge: challenge, activity: nil, userId: userId)

            // Create a view model for the challenge detail interactions
            challengesViewModel = ChallengesViewModel(
                repository: appState.dependencies.challengeRepository,
                userId: userId,
            )
            // Set the selected challenge in the view model
            challengesViewModel?.selectedChallenge = challengeWithStatus
        } catch {
            self.error = error
        }
    }
}

#endif
