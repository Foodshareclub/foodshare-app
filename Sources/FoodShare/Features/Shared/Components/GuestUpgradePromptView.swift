//
//  GuestUpgradePromptView.swift
//  Foodshare
//
//  Full-screen prompt shown when guests try to access restricted features
//  Following CareEcho pattern for feature lock UI
//

import SwiftUI
import FoodShareDesignSystem

struct GuestUpgradePromptView: View {
    @Environment(GuestManager.self) var guestManager
    @Environment(\.translationService) private var t

    let feature: GuestRestrictedFeature

    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Background
            AuthBackground(style: .nature)

            VStack(spacing: Spacing.xl) {
                Spacer()

                // Lock icon with glow
                lockIconSection

                // Feature info
                featureInfoSection

                // Benefits list
                benefitsSection

                // CTA buttons
                ctaSection

                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Lock Icon Section

    private var lockIconSection: some View {
        ZStack {
            // Radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.DesignSystem.accentBlue.opacity(0.3),
                            Color.DesignSystem.accentCyan.opacity(0.15),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(
                    .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )

            // Icon container
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 100, height: 100)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.accentBlue.opacity(0.5),
                                    Color.DesignSystem.accentCyan.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )

            // Feature icon
            Image(systemName: feature.icon)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
    }

    // MARK: - Feature Info Section

    private var featureInfoSection: some View {
        VStack(spacing: Spacing.sm) {
            Text(feature.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(feature.description)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.easeOut(duration: 0.8).delay(0.1), value: isAnimating)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(spacing: Spacing.md) {
            BenefitRow(
                icon: "checkmark.seal.fill",
                text: t.t("guest.benefit.full_access")
            )
            BenefitRow(
                icon: "bell.badge.fill",
                text: t.t("guest.benefit.notifications")
            )
            BenefitRow(
                icon: "message.fill",
                text: t.t("guest.benefit.messaging")
            )
            BenefitRow(
                icon: "trophy.fill",
                text: t.t("guest.benefit.challenges")
            )
        }
        .padding(Spacing.lg)
        .background(benefitsBackground)
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.easeOut(duration: 0.8).delay(0.2), value: isAnimating)
    }

    private var benefitsBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.2), Color.white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: Spacing.md) {
            // Primary CTA - Sign Up
            GlassButton(
                t.t("guest.create_free_account"),
                icon: "person.badge.plus",
                style: .primary
            ) {
                guestManager.disableGuestMode()
            }

            // Secondary - Continue browsing
            Button {
                guestManager.dismissSignUpPrompt()
            } label: {
                Text(t.t("guest.continue_browsing"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
        .animation(.easeOut(duration: 0.8).delay(0.3), value: isAnimating)
    }
}

// MARK: - Benefit Row Component

private struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(Color.DesignSystem.accentBlue.opacity(0.15))
                )

            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.9))

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    GuestUpgradePromptView(feature: .messaging)
        .environment(GuestManager())
}
