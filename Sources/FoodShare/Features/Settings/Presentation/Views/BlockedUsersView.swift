//
//  BlockedUsersView.swift
//  Foodshare
//
//  Manage blocked users - Apple App Review requirement
//


#if !SKIP
import SwiftUI

struct BlockedUsersView: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState

    @State private var blockedUsers: [BlockedUser] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var userToUnblock: BlockedUser?
    @State private var showUnblockConfirmation = false

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if blockedUsers.isEmpty {
                emptyStateView
            } else {
                blockedUsersList
            }
        }
        .navigationTitle(t.t("settings.blocked_users"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadBlockedUsers()
        }
        .alert(t.t("settings.unblock_user"), isPresented: $showUnblockConfirmation) {
            Button(t.t("common.cancel"), role: .cancel) {}
            Button(t.t("settings.unblock"), role: .destructive) {
                if let user = userToUnblock {
                    Task { await unblockUser(user) }
                }
            }
        } message: {
            if let user = userToUnblock {
                Text(t.t("settings.unblock_confirm", args: ["name": user.blockedUserName]))
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.DesignSystem.themed.primary)

            Text(t.t("common.loading"))
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.DesignSystem.error)

            Text(t.t("common.error.title"))
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Text(message)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button {
                Task { await loadBlockedUsers() }
            } label: {
                Text(t.t("common.retry"))
                    .font(.DesignSystem.labelLarge)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.md)
                    .background(Color.DesignSystem.themed.primary)
                    .cornerRadius(CornerRadius.medium)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )

            Text(t.t("settings.no_blocked_users"))
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Text(t.t("settings.no_blocked_users_description"))
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
    }

    private var blockedUsersList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(blockedUsers) { user in
                    BlockedUserRow(user: user) {
                        userToUnblock = user
                        showUnblockConfirmation = true
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(Color.DesignSystem.background)
    }

    private func loadBlockedUsers() async {
        guard let userId = appState.currentUser?.id else {
            errorMessage = t.t("common.error.not_authenticated")
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            blockedUsers = try await appState.dependencies.profileRepository.getBlockedUsers(userId: userId)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func unblockUser(_ user: BlockedUser) async {
        guard let userId = appState.currentUser?.id else { return }

        do {
            try await appState.dependencies.profileRepository.unblockUser(
                userId: userId,
                blockedUserId: user.blockedUserId,
            )

            // Remove from local list with animation
            withAnimation {
                blockedUsers.removeAll { $0.id == user.id }
            }

            HapticManager.success()

            // Notify app to refresh feed and show unblocked user's content
            NotificationCenter.default.post(name: .userUnblocked, object: user.blockedUserId)
        } catch let error as AppError {
            // Provide user-friendly error messages
            switch error {
            case let .validationError(message):
                errorMessage = message
            case .networkError:
                errorMessage = t.t("common.error.network")
            default:
                errorMessage = t.t("common.error.generic")
            }
            HapticManager.error()
        } catch {
            errorMessage = t.t("common.error.generic")
            HapticManager.error()
        }
    }
}

// MARK: - Blocked User Row

struct BlockedUserRow: View {
    let user: BlockedUser
    let onUnblock: () -> Void

    @Environment(\.translationService) private var t

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            if let avatarUrl = user.blockedUserAvatar, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.DesignSystem.textTertiary.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(Color.DesignSystem.textTertiary),
                        )
                }
                .frame(width: 48.0, height: 48)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.DesignSystem.textTertiary.opacity(0.3))
                    .frame(width: 48.0, height: 48)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.DesignSystem.textTertiary),
                    )
            }

            // User info
            VStack(alignment: .leading, spacing: 4) {
                Text(user.blockedUserName)
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("settings.blocked_on", args: ["date": user.blockedAt.formatted(date: .abbreviated, time: .omitted)]))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                if let reason = user.reason {
                    Text(reason)
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Unblock button
            Button {
                onUnblock()
                HapticManager.light()
            } label: {
                Text(t.t("settings.unblock"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.brandBlue)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.DesignSystem.brandBlue.opacity(0.1))
                    .cornerRadius(CornerRadius.small)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }
}

#Preview {
    NavigationStack {
        BlockedUsersView()
            .environment(AppState.preview)
    }
}

#endif
