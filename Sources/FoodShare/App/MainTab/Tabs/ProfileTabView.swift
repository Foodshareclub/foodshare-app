//
//  ProfileTabView.swift
//  Foodshare
//
//  Profile tab for user account management
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Profile Tab View

struct ProfileTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(GuestManager.self) private var guestManager
    @Environment(\.translationService) private var t
    @Binding var deepLinkProfileId: UUID?

    @State private var profileViewModel: ProfileViewModel?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                // Guest mode: Show guest-specific upgrade prompt
                if guestManager.isGuestMode {
                    GuestRestrictedTabView(feature: .profile)
                        .navigationTitle(t.t("tabs.profile"))
                } else if appState.currentUser?.id != nil {
                    if let viewModel = profileViewModel {
                        ProfileView(viewModel: viewModel, navigationPath: $navigationPath)
                    } else {
                        loadingView
                    }
                } else {
                    SignInPromptView.profile()
                }
            }
            .navigationDestination(for: DeepLinkRoute.self) { route in
                switch route {
                case let .profile(id):
                    DeepLinkProfileView(profileId: id)
                default:
                    EmptyView()
                }
            }
            .navigationDestination(for: ProfileDestination.self) { destination in
                switch destination {
                case let .listings(userId, repository):
                    UserListingsView(userId: userId, repository: repository)
                case let .history(userId, repository):
                    ArrangementHistoryView(userId: userId, repository: repository)
                case let .badges(collection, stats):
                    BadgesDetailView(collection: collection, userStats: stats)
                case let .reviews(reviews, userName, rating):
                    UserReviewsView(reviews: reviews, userName: userName, averageRating: rating)
                case .forum:
                    ForumContainerView()
                case .settings:
                    SettingsView(appState: appState) // ✅ Fixed: Pass appState to prevent iPad crash
                case .notifications:
                    NotificationsSettingsView()
                case .help:
                    HelpView()
                }
            }
        }
        .task {
            await setupProfileViewModel()
        }
        .onChange(of: appState.currentUser?.id) { _, newValue in
            if newValue != nil {
                Task { await setupProfileViewModel() }
            } else {
                profileViewModel = nil
            }
        }
        .onChange(of: deepLinkProfileId) { _, newValue in
            if let profileId = newValue {
                navigationPath.append(DeepLinkRoute.profile(profileId))
                deepLinkProfileId = nil // Clear after handling
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            // Animated loading icon with glass effect
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .DesignSystem.brandGreen.opacity(0.5),
                                        .DesignSystem.brandBlue.opacity(0.3),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 2,
                            ),
                    )

                Image(systemName: "person.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }

            Text(t.t("status.loading_profile"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("tabs.profile"))
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }

    private func setupProfileViewModel() async {
        guard let userId = appState.currentUser?.id else {
            profileViewModel = nil
            return
        }

        profileViewModel = ProfileViewModel(
            repository: appState.dependencies.profileRepository,
            forumRepository: appState.dependencies.forumRepository,
            reviewRepository: appState.dependencies.reviewRepository,
            userId: userId,
        )
    }
}
