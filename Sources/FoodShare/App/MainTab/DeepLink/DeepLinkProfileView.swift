//
//  DeepLinkProfileView.swift
//  Foodshare
//
//  Wrapper view for deep-linking to a specific user profile
//


#if !SKIP
import SwiftUI

/// Wrapper view for deep-linking to a specific user profile
struct DeepLinkProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t
    let profileId: UUID
    @State private var profileViewModel: ProfileViewModel?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        Group {
            if let viewModel = profileViewModel {
                ProfileView(viewModel: viewModel, navigationPath: $navigationPath)
            } else if isLoading {
                ProgressView(t.t("status.loading_profile"))
            } else if error != nil {
                ContentUnavailableView(
                    t.t("errors.not_found.profile"),
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(t.t("errors.not_found.profile_desc")),
                )
            }
        }
        .task {
            await loadProfile()
        }
    }

    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }

        // Create a profile view model for viewing another user's profile
        profileViewModel = ProfileViewModel(
            repository: appState.dependencies.profileRepository,
            forumRepository: appState.dependencies.forumRepository,
            reviewRepository: appState.dependencies.reviewRepository,
            userId: profileId,
        )
    }
}

#endif
