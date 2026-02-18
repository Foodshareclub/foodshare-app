//
//  BlockUserSheet.swift
//  Foodshare
//
//  Block user with reason - Apple App Review requirement
//


#if !SKIP
import SwiftUI

struct BlockUserSheet: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState

    let userId: UUID
    let userName: String
    let userAvatar: String?

    @State private var selectedReason: BlockReason?
    @State private var customReason = ""
    @State private var isBlocking = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // User info header
                    userHeader

                    // Warning message
                    warningCard

                    // Reason selection
                    reasonSection

                    // Custom reason (if Other selected)
                    if selectedReason == .other {
                        customReasonField
                    }

                    // Block button
                    blockButton
                }
                .padding(Spacing.lg)
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("profile.block_user"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t.t("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .alert(t.t("common.error.title"), isPresented: .constant(errorMessage != nil)) {
                Button(t.t("common.ok"), role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .alert(t.t("profile.user_blocked"), isPresented: $showSuccess) {
                Button(t.t("common.ok"), role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(t.t("profile.user_blocked_message", args: ["name": userName]))
            }
        }
    }

    private var userHeader: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            if let avatarUrl = userAvatar, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.DesignSystem.textTertiary.opacity(0.3))
                }
                .frame(width: 56.0, height: 56)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.DesignSystem.textTertiary.opacity(0.3))
                    .frame(width: 56.0, height: 56)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.DesignSystem.textTertiary),
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(userName)
                    .font(.DesignSystem.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("profile.will_be_blocked"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Spacer()
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

    private var warningCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.DesignSystem.accentOrange)

                Text(t.t("profile.blocking_will"))
                    .font(.DesignSystem.labelLarge)
                    .foregroundStyle(Color.DesignSystem.text)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                bulletPoint(t.t("profile.block_effect_1"))
                bulletPoint(t.t("profile.block_effect_2"))
                bulletPoint(t.t("profile.block_effect_3"))
                bulletPoint(t.t("profile.block_effect_4"))
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.DesignSystem.accentOrange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.accentOrange.opacity(0.3), lineWidth: 1),
                ),
        )
    }

    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Text("•")
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            Text(text)
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
    }

    private var reasonSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(t.t("profile.reason_for_blocking"))
                .font(.DesignSystem.labelLarge)
                .foregroundStyle(Color.DesignSystem.text)

            VStack(spacing: Spacing.xs) {
                ForEach(BlockReason.allCases, id: \.self) { reason in
                    reasonButton(reason)
                }
            }
        }
    }

    private func reasonButton(_ reason: BlockReason) -> some View {
        Button {
            selectedReason = reason
            HapticManager.light()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: reason.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(reason.color)
                    .frame(width: 28.0)

                Text(t.t(reason.titleKey))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                if selectedReason == reason {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.DesignSystem.brandGreen)
                } else {
                    Circle()
                        .stroke(Color.DesignSystem.textTertiary, lineWidth: 2)
                        .frame(width: 20.0, height: 20)
                }
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(selectedReason == reason ? Color.DesignSystem.brandGreen.opacity(0.1) : .clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(
                                selectedReason == reason
                                    ? Color.DesignSystem.brandGreen
                                    : Color.DesignSystem.glassBorder,
                                lineWidth: 1,
                            ),
                    ),
            )
        }
        .buttonStyle(.plain)
    }

    private var customReasonField: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(t.t("profile.describe_issue"))
                .font(.DesignSystem.labelMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            #if !SKIP
            TextField(t.t("profile.optional_details"), text: $customReason, axis: .vertical)
                .lineLimit(3 ... 6)
                .textFieldStyle(.plain)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                        ),
                )
            #else
            TextField(t.t("profile.optional_details"), text: $customReason)
                .lineLimit(6)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.DesignSystem.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                        ),
                )
            #endif
        }
    }

    private var blockButton: some View {
        Button {
            Task { await blockUser() }
        } label: {
            HStack {
                if isBlocking {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "hand.raised.fill")
                    Text(t.t("profile.block_user_action"))
                }
            }
            .font(.DesignSystem.labelLarge)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(selectedReason == nil ? Color.DesignSystem.textTertiary : Color.DesignSystem.error),
            )
        }
        .disabled(selectedReason == nil || isBlocking)
        #if !SKIP
        .sensoryFeedback(.success, trigger: showSuccess)
        #endif
    }

    private func blockUser() async {
        guard let currentUserId = appState.currentUser?.id else { return }
        guard let reason = selectedReason else { return }

        // Safety check: Prevent self-blocking
        guard currentUserId != userId else {
            errorMessage = t.t("profile.cannot_block_yourself")
            HapticManager.error()
            return
        }

        isBlocking = true
        errorMessage = nil

        do {
            let reasonText = reason == .other && !customReason.isEmpty
                ? customReason
                : t.t(reason.titleKey)

            try await appState.dependencies.profileRepository.blockUser(
                userId: currentUserId,
                blockedUserId: userId,
                reason: reasonText,
            )

            HapticManager.success()
            showSuccess = true

            // Notify app to refresh feed and remove blocked user's content
            NotificationCenter.default.post(name: .userBlocked, object: userId)
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
            isBlocking = false
        } catch {
            errorMessage = t.t("common.error.generic")
            HapticManager.error()
            isBlocking = false
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let userBlocked = Notification.Name("userBlocked")
    static let userUnblocked = Notification.Name("userUnblocked")
}

// MARK: - Block Reason

enum BlockReason: String, CaseIterable {
    case spam
    case harassment
    case inappropriate
    case scam
    case impersonation
    case other

    var titleKey: String {
        switch self {
        case .spam: "profile.block_reason_spam"
        case .harassment: "profile.block_reason_harassment"
        case .inappropriate: "profile.block_reason_inappropriate"
        case .scam: "profile.block_reason_scam"
        case .impersonation: "profile.block_reason_impersonation"
        case .other: "profile.block_reason_other"
        }
    }

    var icon: String {
        switch self {
        case .spam: "envelope.badge.fill"
        case .harassment: "exclamationmark.bubble.fill"
        case .inappropriate: "eye.slash.fill"
        case .scam: "exclamationmark.triangle.fill"
        case .impersonation: "person.crop.circle.badge.exclamationmark"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .spam: .DesignSystem.accentOrange
        case .harassment: .DesignSystem.error
        case .inappropriate: .DesignSystem.accentPurple
        case .scam: .DesignSystem.error
        case .impersonation: .DesignSystem.accentOrange
        case .other: .DesignSystem.textSecondary
        }
    }
}

#Preview {
    BlockUserSheet(
        userId: UUID(),
        userName: "John Doe",
        userAvatar: nil,
    )
    .environment(AppState.preview)
}

#endif
