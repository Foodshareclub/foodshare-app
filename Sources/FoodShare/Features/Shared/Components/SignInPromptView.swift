//
//  SignInPromptView.swift
//  Foodshare
//
//  Reusable Liquid Glass sign-in prompt for unauthenticated users
//


#if !SKIP
import SwiftUI

struct SignInPromptView: View {
    let feature: String
    let icon: String
    let description: String
    var onSignIn: (() -> Void)?

    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t

    init(
        feature: String,
        icon: String = "person.circle.fill",
        description: String? = nil,
        onSignIn: (() -> Void)? = nil,
    ) {
        self.feature = feature
        self.icon = icon
        self.description = description ?? "sign_in.prompt.default_desc".localized(with: ["feature": feature.lowercased()])
        self.onSignIn = onSignIn
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Icon with shimmer effect
            iconView

            // Title
            Text(t.t("guest.prompt.title", args: ["feature": feature]))
                .font(.LiquidGlass.displayMedium)
                .foregroundColor(.DesignSystem.text)
                .multilineTextAlignment(.center)

            // Description
            Text(description)
                .font(.LiquidGlass.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            // Sign in button
            signInButton
                .padding(.top, Spacing.md)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundGradient)
    }

    // MARK: - Icon View

    private var iconView: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.DesignSystem.brandGreen.opacity(0.3),
                            Color.DesignSystem.brandBlue.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80,
                    ),
                )
                .frame(width: 160.0, height: 160)

            // Glass circle background
            Circle()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .frame(width: 100.0, height: 100)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 1,
                        ),
                )
                .shadow(color: Color.DesignSystem.brandGreen.opacity(0.2), radius: 20)

            // Icon
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .shimmer(duration: 3.0)
        }
    }

    // MARK: - Sign In Button

    private var signInButton: some View {
        Button {
            HapticManager.medium()
            if let onSignIn {
                onSignIn()
            } else {
                appState.showAuthentication = true
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 20))

                Text(t.t("guest.prompt.action"))
                    .font(.LiquidGlass.labelLarge)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: 200)
            .padding(.vertical, Spacing.md)
            .background(
                LinearGradient(
                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                    startPoint: .leading,
                    endPoint: .trailing,
                ),
            )
            .clipShape(Capsule())
            .shadow(color: .DesignSystem.brandGreen.opacity(0.4), radius: 12, y: 6)
        }
        .pressAnimation()
    }
}

// MARK: - Convenience Initializers

extension SignInPromptView {
    static func challenges() -> SignInPromptView {
        SignInPromptView(
            feature: "tabs.challenges".localized,
            icon: "trophy.fill",
            description: "sign_in.prompt.challenges_desc".localized,
        )
    }

    static func messaging() -> SignInPromptView {
        SignInPromptView(
            feature: "tabs.chats".localized,
            icon: "message.fill",
            description: "sign_in.prompt.messages_desc".localized,
        )
    }

    static func profile() -> SignInPromptView {
        SignInPromptView(
            feature: "tabs.profile".localized,
            icon: "person.circle.fill",
            description: "sign_in.prompt.profile_desc".localized,
        )
    }

    static func forum() -> SignInPromptView {
        SignInPromptView(
            feature: "tabs.forum".localized,
            icon: "bubble.left.and.bubble.right.fill",
            description: "sign_in.prompt.forum_desc".localized,
        )
    }
}

// MARK: - Preview

#Preview("Challenges") {
    SignInPromptView.challenges()
        .environment(AppState())
}

#Preview("Messaging") {
    SignInPromptView.messaging()
        .environment(AppState())
}

#endif
