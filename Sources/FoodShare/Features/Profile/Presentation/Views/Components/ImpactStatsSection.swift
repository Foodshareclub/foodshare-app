//
//  ImpactStatsSection.swift
//  FoodShare
//
//  Displays environmental impact statistics with real-world comparisons.
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Impact Stats Section

struct ImpactStatsSection: View {
    @Environment(\.translationService) private var t
    let stats: ImpactStats
    let memberSince: String
    let memberDuration: String

    @State private var showImpactDetail = false

    // Real-world comparisons
    private var treesEquivalent: Int {
        max(1, Int(stats.co2SavedKg / 22)) // 1 tree absorbs ~22kg CO2/year
    }

    private var showerMinutes: Int {
        max(1, Int(stats.waterSavedLiters / 9)) // ~9 liters/minute
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            headerRow

            metricsRow

            memberInfoRow

            shareButton
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .drawingGroup() // GPU acceleration for glass effects
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Image(systemName: "leaf.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.DesignSystem.brandGreen)

            Text(t.t("profile.impact.title"))
                .font(.LiquidGlass.headlineSmall)
                .foregroundStyle(Color.DesignSystem.text)

            Spacer()

            Text(stats.communityRank)
                .font(.LiquidGlass.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.themed.gradientStart,
                                Color.DesignSystem.themed.gradientEnd
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                )
        }
    }

    // MARK: - Metrics Row

    private var metricsRow: some View {
        HStack(spacing: Spacing.md) {
            ImpactMetricView(
                icon: "cloud.fill",
                value: stats.formattedCO2,
                label: t.t("profile.impact.co2_saved"),
                comparison: t.t("profile.impact.trees_equivalent", args: ["count": "\(treesEquivalent)"]),
                color: .DesignSystem.brandBlue
            )
            ImpactMetricView(
                icon: "drop.fill",
                value: stats.formattedWater,
                label: t.t("profile.impact.water_saved"),
                comparison: t.t("profile.impact.shower_equivalent", args: ["minutes": "\(showerMinutes)"]),
                color: .DesignSystem.brandTeal
            )
            ImpactMetricView(
                icon: "fork.knife",
                value: "\(stats.mealsShared + stats.mealsReceived)",
                label: t.t("profile.impact.meals"),
                comparison: t.t("profile.impact.meals_shared", args: ["count": "\(stats.mealsShared)"]),
                color: .DesignSystem.brandOrange
            )
        }
    }

    // MARK: - Member Info Row

    private var memberInfoRow: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "calendar")
                .font(.system(size: 12))
                .foregroundStyle(Color.DesignSystem.textSecondary)

            Text(memberSince)
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            Text("•")
                .foregroundStyle(Color.DesignSystem.textTertiary)

            Text(memberDuration)
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            showImpactDetail = true
            HapticManager.light()
        } label: {
            HStack {
                Image(systemName: "square.and.arrow.up")
                Text(t.t("profile.impact.share"))
            }
            .font(.LiquidGlass.labelSmall)
            .foregroundStyle(Color.DesignSystem.themed.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(Color.DesignSystem.themed.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        }
    }
}

// MARK: - Impact Metric View

struct ImpactMetricView: View {
    let icon: String
    let value: String
    let label: String
    let comparison: String
    let color: Color

    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, options: .repeating, value: isAnimating)
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }

            Text(value)
                .font(.LiquidGlass.headlineSmall)
                .fontWeight(.bold)
                .foregroundStyle(Color.DesignSystem.text)
                .contentTransition(.numericText())

            Text(label)
                .font(.LiquidGlass.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .lineLimit(1)

            Text(comparison)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Simple Impact Metric View (without comparison)

struct SimpleImpactMetricView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.LiquidGlass.headlineSmall)
                .fontWeight(.bold)
                .foregroundStyle(Color.DesignSystem.text)
                .contentTransition(.numericText())

            Text(label)
                .font(.LiquidGlass.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}
