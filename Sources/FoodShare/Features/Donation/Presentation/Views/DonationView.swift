//
//  DonationView.swift
//  Foodshare
//
//  Support Foodshare donation page with Liquid Glass design
//

import SwiftUI
import FoodShareDesignSystem



struct DonationView: View {
    
    @Environment(\.openURL) private var openURL
    @Environment(\.translationService) private var t

    // Force unwrap is safe for compile-time constant URL
    private let kofiURL = URL(string: "https://ko-fi.com/organicnz")!

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                heroSection
                impactStatsSection
                missionSection
                finalCTASection
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.backgroundGradient)
        .navigationTitle(t.t("donation.support_foodshare"))
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: Spacing.lg) {
            // Badge
            Text(t.t("donation.badge_impact"))
                .font(.DesignSystem.captionSmall)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundColor(.DesignSystem.accentPink)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Color.DesignSystem.accentPink.opacity(0.15))
                .clipShape(Capsule())

            // Hero Title
            Text(t.t("donation.hero_title"))
                .font(.DesignSystem.displayLarge)
                .fontWeight(.black)
                .multilineTextAlignment(.center)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.DesignSystem.accentPink, .DesignSystem.accentPurple, .DesignSystem.brandBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )

            // Subtitle
            Text(t.t("donation.hero_subtitle"))
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.md)

            // Ko-Fi CTA Card
            donateCard
        }
        .padding(.top, Spacing.lg)
    }

    // MARK: - Donate Card

    private var donateCard: some View {
        VStack(spacing: Spacing.lg) {
            // Heart Icon
            ZStack {
                Circle()
                    .fill(Color.DesignSystem.contrastSubtle)
                    .frame(width: 80, height: 80)

                Image(systemName: "heart.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.DesignSystem.contrastText)
            }
            .shadow(color: Color.DesignSystem.glassHighlight, radius: 20)

            // Title
            VStack(spacing: Spacing.sm) {
                Text(t.t("donation.buy_coffee"))
                    .font(.DesignSystem.headlineLarge)
                    .fontWeight(.black)
                    .foregroundColor(.DesignSystem.contrastText)

                Text(t.t("donation.card_description"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.contrastTextSecondary)
                .multilineTextAlignment(.center)
            }

            // Donate Button
            Button {
                HapticManager.medium()
                openURL(kofiURL)
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 20))
                    Text(t.t("donation.support_kofi"))
                        .font(.DesignSystem.labelLarge)
                        .fontWeight(.bold)
                }
                .foregroundColor(.DesignSystem.accentPink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(Color.DesignSystem.contrastText)
                .clipShape(Capsule())
                .shadow(color: Color.DesignSystem.contrastShadow, radius: 10, y: 5)
            }
            .pressAnimation()

            // Trust Indicators
            HStack(spacing: Spacing.lg) {
                trustBadge(t.t("donation.trust_secure"))
                trustBadge(t.t("donation.trust_food_rescue"))
                trustBadge(t.t("donation.trust_tax"))
            }
            .font(.DesignSystem.captionSmall)
        }
        .padding(Spacing.xl)
        .background(
            LinearGradient(
                colors: [.DesignSystem.accentPink, Color(hex: "FF6B9D"), .DesignSystem.accentPurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            ),
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.extraLarge))
        .shadow(color: Color.DesignSystem.accentPink.opacity(0.4), radius: 30, y: 15)
    }

    private func trustBadge(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
            Text(text)
        }
        .foregroundColor(.DesignSystem.contrastTextSecondary)
    }

    // MARK: - Impact Stats Section

    private var impactStatsSection: some View {
        VStack(spacing: Spacing.md) {
            ForEach(ImpactStat.localizedStats(using: t)) { stat in
                impactStatCard(stat)
            }
        }
    }

    private func impactStatCard(_ stat: ImpactStat) -> some View {
        HStack(spacing: Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(stat.color.opacity(0.15))
                    .frame(width: 60, height: 60)

                Image(systemName: stat.icon)
                    .font(.system(size: 24))
                    .foregroundColor(stat.color)
            }

            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(stat.value)
                    .font(.DesignSystem.displaySmall)
                    .fontWeight(.black)
                    .foregroundColor(.DesignSystem.text)

                Text(stat.title)
                    .font(.DesignSystem.labelLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.text)

                Text(stat.description)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .glassBackground(cornerRadius: CornerRadius.large)
    }

    // MARK: - Mission Section

    private var missionSection: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "quote.opening")
                .font(.system(size: 30))
                .foregroundColor(.DesignSystem.textTertiary)

            Text(t.t("donation.mission_description"))
            .font(.DesignSystem.bodyLarge)
            .foregroundColor(.DesignSystem.textSecondary)
            .multilineTextAlignment(.center)
            .lineSpacing(6)

            HStack(spacing: Spacing.sm) {
                Image(systemName: "star.fill")
                    .foregroundColor(.DesignSystem.accentPink)
                Text(t.t("donation.founder_name"))
                    .font(.DesignSystem.labelLarge)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.accentPink, .DesignSystem.accentPurple],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    )
                Image(systemName: "star.fill")
                    .foregroundColor(.DesignSystem.accentPink)
            }
        }
        .padding(Spacing.xl)
        .glassBackground(cornerRadius: CornerRadius.extraLarge)
    }

    // MARK: - Final CTA Section

    private var finalCTASection: some View {
        VStack(spacing: Spacing.lg) {
            Text(t.t("donation.cta_title"))
                .font(.DesignSystem.headlineLarge)
                .fontWeight(.black)
                .multilineTextAlignment(.center)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("donation.cta_subtitle"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)

            GlassButton(t.t("donation.support_kofi"), icon: "heart.fill", style: .primary) {
                HapticManager.medium()
                openURL(kofiURL)
            }
            .padding(.top, Spacing.sm)
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DonationView()
    }
}
