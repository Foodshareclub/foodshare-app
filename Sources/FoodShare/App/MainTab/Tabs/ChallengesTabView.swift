//
//  ChallengesTabView.swift
//  Foodshare
//
//  Challenges tab with gamification features
//


#if !SKIP
import SwiftUI

// MARK: - Challenges Tab View

struct ChallengesTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t
    @Binding var deepLinkChallengeId: Int?

    @State private var challengesViewModel: ChallengesViewModel?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                // Show challenges to all users (auth is handled inside ChallengesView)
                if let viewModel = challengesViewModel {
                    ChallengesView(viewModel: viewModel)
                } else {
                    loadingView
                }
            }
            .navigationDestination(for: DeepLinkRoute.self) { route in
                switch route {
                case let .challenge(id):
                    DeepLinkChallengeView(challengeId: id)
                default:
                    EmptyView()
                }
            }
        }
        .task {
            await setupChallengesViewModel()
        }
        .onChange(of: appState.currentUser?.id) { _, _ in
            // Recreate ViewModel when auth state changes to update user-specific data
            Task { await setupChallengesViewModel() }
        }
        .onChange(of: deepLinkChallengeId) { _, newValue in
            if let challengeId = newValue {
                navigationPath.append(DeepLinkRoute.challenge(challengeId))
                deepLinkChallengeId = nil // Clear after handling
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            // Animated loading icon with glass effect
            ZStack {
                Circle()
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    .frame(width: 80.0, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .DesignSystem.medalGold.opacity(0.5),
                                        .DesignSystem.accentOrange.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 2,
                            ),
                    )

                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.medalGold, .DesignSystem.accentOrange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }

            Text(t.t("status.loading_challenges"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("tabs.challenges"))
        #if !SKIP
        .toolbarBackground(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */, for: .navigationBar)
        #endif
    }

    private func setupChallengesViewModel() async {
        // Create ViewModel with optional userId - allows viewing challenges without auth
        let userId = appState.currentUser?.id
        challengesViewModel = ChallengesViewModel(
            repository: appState.dependencies.challengeRepository,
            userId: userId,
        )
    }
}

#endif
