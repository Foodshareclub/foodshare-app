//
//  EmailVerificationView.swift
//  Foodshare
//
//  Email verification screen with Liquid Glass design
//  Following CareEcho pattern exactly
//


#if !SKIP
import Supabase
import SwiftUI

#if DEBUG
    import Inject
#endif

struct EmailVerificationView: View {
    
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(\.translationService) private var t

    // We assume the user is present because this view is only shown when `authViewModel.user` is not nil
    private var userEmail: String {
        authViewModel.user?.email ?? "your email"
    }

    // MARK: - Liquid Glass Background

    private var backgroundGradient: some View {
        ZStack {
            // Base gradient - using design tokens
            Color.DesignSystem.darkAuthGradient

            // Accent gradient overlay (Nature Green/Blue theme)
            Color.DesignSystem.natureAccentGradient
        }
    }

    var body: some View {
        ZStack {
            // Background
            backgroundGradient
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    Spacer()
                        .frame(height: Spacing.xxxl + Spacing.sm)

                    // Icon with glow
                    iconSection

                    // Title and description
                    contentSection

                    // Action buttons
                    actionButtonsSection

                    Spacer()
                        .frame(height: Spacing.xxl + Spacing.xs)
                }
                .padding(.horizontal, Spacing.lg)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Logo Section

    private var iconSection: some View {
        // Logo icon (Nature Green/Blue theme)
        ZStack {
            // Animated glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.DesignSystem.brandGreen.opacity(0.5),
                            Color.DesignSystem.brandGreen.opacity(0.25),
                            Color.DesignSystem.brandBlue.opacity(0.1),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 35,
                        endRadius: 95,
                    ),
                )
                .frame(width: 150.0, height: 150)
                .blur(radius: Spacing.lg)

            Circle()
                .fill(Color.DesignSystem.brandGreen.opacity(0.15))
                .frame(width: 100.0, height: 100)
                .overlay(
                    Circle()
                        .stroke(Color.DesignSystem.brandGreen, lineWidth: 4),
                )

            Image(systemName: "envelope.badge.fill")
                .font(.DesignSystem.displayLarge)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
        }
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                Text(t.t("auth.verify_email"))
                    .font(.DesignSystem.headlineLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Color.DesignSystem.brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .shadow(color: Color.DesignSystem.brandGreen.opacity(0.4), radius: Spacing.xxxs, x: 0, y: 2)

                Text(t.t("auth.confirmation_sent"))
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.white.opacity(0.75))
            }

            VStack(spacing: Spacing.sm) {
                Text(userEmail)
                    .font(.DesignSystem.labelLarge)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )

                Text(t.t("auth.click_link_to_activate"))
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: Spacing.sm) {
            // Resend Email Button - Primary Glass Button (Foodshare Pink brand)
            GlassButton(
                t.t("auth.resend_confirmation"),
                icon: "arrow.clockwise.circle.fill",
                style: .nature,
            ) {
                Task {
                    await authViewModel.resendConfirmationEmail(email: userEmail)
                }
            }

            // Sign Out Button - Glass Outline
            GlassButton(
                t.t("auth.sign_out"),
                icon: "rectangle.portrait.and.arrow.right",
                style: .destructive,
            ) {
                Task { await authViewModel.signOut() }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EmailVerificationView()
        .environment(AuthViewModel(supabase: .init(
            supabaseURL: URL(string: "https://api.foodshare.club")!,
            supabaseKey: "example-key",
        )))
}

#else
// MARK: - Android EmailVerificationView Stub (Skip)

import SwiftUI

struct EmailVerificationView: View {
    @Environment(AppState.self) var appState

    var body: some View {
        VStack(spacing: 24.0) {
            Spacer()

            Text("Check Your Email")
                .font(.system(size: 28.0, weight: .bold))
                .foregroundStyle(Color.white)

            Text("We sent a verification link to your email. Please check your inbox and click the link to verify your account.")
                .font(.system(size: 16.0))
                .foregroundStyle(Color.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32.0)

            Button(action: {
                Task {
                    await AuthenticationService.shared.checkCurrentSession()
                }
            }) {
                Text("I've Verified My Email")
                    .font(.system(size: 16.0, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.vertical, 12.0)
                    .frame(maxWidth: .infinity)
            }
            .background(Color(red: 0.2, green: 0.7, blue: 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 12.0))
            .padding(.horizontal, 32.0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
    }
}

#endif
