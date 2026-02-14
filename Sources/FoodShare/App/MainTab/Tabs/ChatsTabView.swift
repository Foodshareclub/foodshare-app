//
//  ChatsTabView.swift
//  Foodshare
//
//  Messaging tab for user conversations
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Chats Tab View

struct ChatsTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(GuestManager.self) private var guestManager
    @Environment(\.translationService) private var t
    @State private var messagingViewModel: MessagingViewModel?
    @State private var unreadCount = 0

    var body: some View {
        // Note: MessagingView has its own NavigationStack, so we only wrap
        // loading/sign-in states in a NavigationStack for consistent nav bar
        Group {
            // Guest mode: Show guest-specific upgrade prompt
            if guestManager.isGuestMode {
                NavigationStack {
                    GuestRestrictedTabView(feature: .messaging)
                        .navigationTitle(t.t("tabs.chats"))
                        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                }
            } else if appState.currentUser?.id != nil {
                if let viewModel = messagingViewModel {
                    // MessagingView provides its own NavigationStack
                    MessagingView(viewModel: viewModel)
                } else {
                    NavigationStack {
                        loadingView
                            .navigationTitle(t.t("tabs.chats"))
                            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                    }
                }
            } else {
                NavigationStack {
                    SignInPromptView.messaging()
                        .navigationTitle(t.t("tabs.chats"))
                        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                }
            }
        }
        .task {
            await setupMessagingViewModel()
        }
        .onChange(of: appState.currentUser?.id) { _, newValue in
            if newValue != nil {
                Task { await setupMessagingViewModel() }
            } else {
                messagingViewModel = nil
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
                                        .DesignSystem.brandBlue.opacity(0.3)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 2,
                            ),
                    )

                Image(systemName: "message.fill")
                    .font(.title)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }

            Text(t.t("chats.loading"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
    }

    private func setupMessagingViewModel() async {
        guard let userId = appState.currentUser?.id else {
            messagingViewModel = nil
            return
        }

        messagingViewModel = MessagingViewModel(
            repository: appState.dependencies.messagingRepository,
            currentUserId: userId,
        )
    }
}
