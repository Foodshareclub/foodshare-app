//
//  DonationView.swift
//  Foodshare
//
//  Donation/Support page with Liquid Glass v26 design
//  iOS equivalent of web app's donation page with Ko-fi integration
//

import SwiftUI
import FoodShareDesignSystem

struct DonationView: View {
    @Environment(\.translationService) private var t
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    // Force unwrap is safe for compile-time constant URL
    private let kofiURL = URL(string: "https://ko-fi.com/organicnz")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Hero Section
                    heroSection

                    // Impact Statistics
                    impactStatsSection

                    // Mission Statement
                    missionSection

                    // Final CTA
                    finalCTASection
                }
                .padding(.vertical, Spacing.lg)
            }
            .background(backgroundGradient)
            .navigationTitle(t.t("support.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            Color.DesignSystem.background

            // Decorative gradient orbs
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.DesignSystem.accentPink.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300,
                    ),
                )
                .frame(width: 600, height: 600)
                .offset(x: 150, y: -200)
                .blur(radius: 80)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.DesignSystem.brandPurple.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 350,
                    ),
                )
                .frame(width: 700, height: 700)
                .offset(x: -200, y: 400)
                .blur(radius: 100)
        }
        .ignoresSafeArea()
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Spacing.lg) {
            // Badge
            HStack(spacing: Spacing.xs) {
                Circle()
                    .fill(Color.DesignSystem.accentPink)
                    .frame(width: 8, height: 8)

                Text(t.t("donation.badge_text"))
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(.bold)
                    .tracking(1.5)
                    .foregroundColor(Color.DesignSystem.accentPink)

                Circle()
                    .fill(Color.DesignSystem.accentPink)
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(Color.DesignSystem.accentPink.opacity(0.15)),
            )

            // Title
            Text(t.t("support.coffee_saves_meal"))
                .font(.DesignSystem.displayLarge)
                .fontWeight(.black)
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "FF2D55"),
                            Color(hex: "FF6B9D"),
                            Color(hex: "F093FB"),
                            Color(hex: "667EEA")
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )

            // Subtitle
            Text(t.t("donation.hero_subtitle"))
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.lg)

            // Main CTA Card
            donationCTACard
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Donation CTA Card

    private var donationCTACard: some View {
        VStack(spacing: Spacing.lg) {
            // Heart Icon
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: "heart.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }

            // Text
            VStack(spacing: Spacing.sm) {
                Text(t.t("support.buy_coffee"))
                    .font(.DesignSystem.displaySmall)
                    .fontWeight(.black)
                    .foregroundColor(.white)

                Text(t.t("donation.card_description"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
            }

            // Donate Button
            Button {
                openURL(kofiURL)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.title3)

                    Text(t.t("donation.support_kofi"))
                        .font(.DesignSystem.bodyLarge)
                        .fontWeight(.bold)
                }
                .foregroundColor(Color(hex: "FF2D55"))
                .padding(.horizontal, Spacing.xl)
                .padding(.vertical, Spacing.md)
                .background(
                    Capsule()
                        .fill(.white)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5),
                )
            }

            // Trust Indicators
            HStack(spacing: Spacing.lg) {
                trustIndicator(icon: "checkmark.shield.fill", text: t.t("donation.trust_secure"))
                trustIndicator(icon: "checkmark.circle.fill", text: t.t("donation.trust_funds"))
            }
            .padding(.top, Spacing.sm)
        }
        .padding(Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: 40)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FF2D55"),
                            Color(hex: "FF6B9D"),
                            Color(hex: "F093FB")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .shadow(color: Color(hex: "FF2D55").opacity(0.4), radius: 30, y: 15),
        )
    }

    private func trustIndicator(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
        }
        .foregroundColor(.white.opacity(0.9))
    }

    // MARK: - Impact Stats Section

    private var impactStatsSection: some View {
        VStack(spacing: Spacing.md) {
            impactStatCard(
                icon: "hand.raised.fill",
                iconColor: Color.DesignSystem.accentPink,
                value: "100%",
                title: t.t("donation.impact.direct_title"),
                description: t.t("donation.impact.direct_desc"),
            )

            impactStatCard(
                icon: "person.2.fill",
                iconColor: Color.DesignSystem.accentBlue,
                value: "1,000+",
                title: t.t("donation.impact.lives_title"),
                description: t.t("donation.impact.lives_desc"),
            )

            impactStatCard(
                icon: "leaf.fill",
                iconColor: Color.DesignSystem.success,
                value: t.t("donation.impact.zero_value"),
                title: t.t("donation.impact.zero_title"),
                description: t.t("donation.impact.zero_desc"),
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    private func impactStatCard(
        icon: String,
        iconColor: Color,
        value: String,
        title: String,
        description: String,
    ) -> some View {
        GlassCard(cornerRadius: 24, shadow: .medium) {
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(iconColor)
                }

                // Content
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(value)
                        .font(.DesignSystem.displaySmall)
                        .fontWeight(.black)
                        .foregroundColor(.DesignSystem.text)

                    Text(title)
                        .font(.DesignSystem.bodyLarge)
                        .fontWeight(.bold)
                        .foregroundColor(.DesignSystem.text)

                    Text(description)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Mission Section

    private var missionSection: some View {
        GlassCard(cornerRadius: 32, shadow: .strong) {
            VStack(spacing: Spacing.lg) {
                // Quote marks
                Image(systemName: "quote.opening")
                    .font(.system(size: 32))
                    .foregroundColor(.DesignSystem.textTertiary)

                Text(t.t("donation.mission_statement"))
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)

                // Founder
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "star.fill")
                        .foregroundColor(Color.DesignSystem.accentPink)

                    Text(t.t("donation.founder"))
                        .font(.DesignSystem.headlineMedium)
                        .fontWeight(.black)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "FF2D55"), Color(hex: "F093FB")],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )

                    Image(systemName: "star.fill")
                        .foregroundColor(Color.DesignSystem.accentPink)
                }
            }
            .padding(Spacing.xl)
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Final CTA Section

    private var finalCTASection: some View {
        VStack(spacing: Spacing.lg) {
            Text(t.t("donation.cta_title"))
                .font(.DesignSystem.displaySmall)
                .fontWeight(.black)
                .foregroundColor(.DesignSystem.text)
                .multilineTextAlignment(.center)

            Text(t.t("donation.cta_subtitle"))
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)

            VStack(spacing: Spacing.md) {
                // Primary CTA
                Button {
                    openURL(kofiURL)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "heart.fill")
                        Text(t.t("support.donate_now"))
                            .fontWeight(.bold)
                    }
                    .font(.DesignSystem.bodyLarge)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "FF2D55"), Color(hex: "F093FB")],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color(hex: "FF2D55").opacity(0.4), radius: 15, y: 8)
                }

                // Secondary CTA
                Button {
                    dismiss()
                } label: {
                    Text(t.t("donation.learn_more"))
                        .font(.DesignSystem.bodyLarge)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "FF2D55"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            Capsule()
                                .stroke(Color(hex: "FF2D55"), lineWidth: 3),
                        )
                }
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.bottom, Spacing.xl)
    }
}

// MARK: - Preview

#Preview {
    DonationView()
}
