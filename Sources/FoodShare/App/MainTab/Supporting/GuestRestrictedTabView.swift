//
//  GuestRestrictedTabView.swift
//  Foodshare
//
//  Inline view shown in tabs when guests try to access restricted features
//


#if !SKIP
import SwiftUI

/// Inline view shown in tabs when guests try to access restricted features
struct GuestRestrictedTabView: View {
    @Environment(GuestManager.self) private var guestManager
    @Environment(\.translationService) private var t

    let feature: GuestRestrictedFeature

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Feature icon with animated glow
            featureIconSection

            // Feature info
            featureInfoSection

            // CTA buttons
            ctaSection

            Spacer()
            Spacer()
        }
        .padding(.horizontal, Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
            }
        }
    }

    // MARK: - Feature Icon Section

    private var featureIconSection: some View {
        ZStack {
            // Radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.DesignSystem.brandGreen.opacity(0.25),
                            Color.DesignSystem.brandBlue.opacity(0.12),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 100,
                    ),
                )
                .frame(width: 180.0, height: 180)
                .scaleEffect(isAnimating ? 1.1 : 0.9)
                .animation(
                    .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                    value: isAnimating,
                )

            // Icon container
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
                                    Color.DesignSystem.brandGreen.opacity(0.5),
                                    Color.DesignSystem.brandBlue.opacity(0.3)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 2,
                        ),
                )

            // Feature icon
            Image(systemName: feature.icon)
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 20)
    }

    // MARK: - Feature Info Section

    private var featureInfoSection: some View {
        VStack(spacing: Spacing.sm) {
            Text(feature.localizedTitle(using: t))
                .font(.DesignSystem.displayMedium)
                .foregroundColor(.DesignSystem.text)
                .multilineTextAlignment(.center)

            Text(feature.localizedDescription(using: t))
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                #if !SKIP
                .fixedSize(horizontal: false, vertical: true)
                #endif

            Text(t.t("guest.restricted.message"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.top, Spacing.xs)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.easeOut(duration: 0.6).delay(0.1), value: isAnimating)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: Spacing.md) {
            // Primary CTA - Sign Up
            GlassButton(
                t.t("guest.restricted.action"),
                icon: "person.badge.plus",
                style: .primary,
            ) {
                guestManager.disableGuestMode()
            }

            // Secondary - Continue exploring
            Text(t.t("guest.restricted.secondary"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .opacity(isAnimating ? 1 : 0)
        .offset(y: isAnimating ? 0 : 15)
        .animation(.easeOut(duration: 0.6).delay(0.2), value: isAnimating)
    }
}

#endif
