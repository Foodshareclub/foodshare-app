//
//  InsightsView.swift
//  Foodshare
//
//  User insights and analytics dashboard
//


#if !SKIP
import SwiftUI



struct InsightsView: View {
    
    @Environment(\.translationService) private var t
    let insights: UserInsights
    @State private var selectedPeriod: InsightsPeriod = .month

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Period selector
                periodSelector

                // Impact summary
                impactSummary

                // Stats grid
                statsGrid

                // Streak section
                streakSection

                // Environmental impact
                environmentalImpact
            }
            .padding()
        }
        .navigationTitle(t.t("insights.title"))
        .background(Color.backgroundGradient)
    }

    private var periodSelector: some View {
        Picker(t.t("common.period"), selection: $selectedPeriod) {
            ForEach(InsightsPeriod.allCases, id: \.self) { period in
                Text(period.displayName(t)).tag(period)
            }
        }
        .pickerStyle(.segmented)
    }

    private var impactSummary: some View {
        VStack(spacing: Spacing.md) {
            Text("🌍 \(t.t("insights.impact_score"))")
                .font(.DesignSystem.headlineSmall)
                .fontWeight(.semibold)

            ZStack {
                Circle()
                    .stroke(Color.DesignSystem.glassBackground, lineWidth: 12)
                    .frame(width: 120.0, height: 120)

                Circle()
                    .trim(from: 0, to: CGFloat(insights.impactScore) / 100)
                    .stroke(
                        LinearGradient(
                            colors: [.green, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round),
                    )
                    .frame(width: 120.0, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(insights.impactScore)")
                        .font(.system(size: 36, weight: .bold))
                    Text(t.t("insights.points"))
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
            }

            Text(t.t("insights.making_difference"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        #if !SKIP
        .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
        #else
        .background(Color.DesignSystem.glassSurface.opacity(0.15))
        #endif
        .cornerRadius(Spacing.md)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.md) {
            InsightsStatCard(
                title: t.t("insights.shared"),
                value: "\(insights.itemsShared)",
                icon: "arrow.up.heart.fill",
                color: .orange,
            )

            InsightsStatCard(
                title: t.t("insights.received"),
                value: "\(insights.itemsReceived)",
                icon: "arrow.down.heart.fill",
                color: .green,
            )

            InsightsStatCard(
                title: t.t("insights.views"),
                value: "\(insights.totalViews)",
                icon: "eye.fill",
                color: .blue,
            )

            InsightsStatCard(
                title: t.t("insights.likes"),
                value: "\(insights.totalLikes)",
                icon: "heart.fill",
                color: .red,
            )

            InsightsStatCard(
                title: t.t("insights.messages"),
                value: "\(insights.messagesExchanged)",
                icon: "message.fill",
                color: .purple,
            )

            InsightsStatCard(
                title: t.t("insights.success_rate"),
                value: String(format: "%.0f%%", insights.successRate),
                icon: "checkmark.circle.fill",
                color: .green,
            )
        }
    }

    private var streakSection: some View {
        HStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.orange)

                Text("\(insights.currentStreak)")
                    .font(.DesignSystem.displaySmall)
                    .fontWeight(.bold)

                Text(t.t("insights.current_streak"))
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 60.0)

            VStack(spacing: Spacing.xs) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.yellow)

                Text("\(insights.longestStreak)")
                    .font(.DesignSystem.displaySmall)
                    .fontWeight(.bold)

                Text(t.t("insights.best_streak"))
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Spacing.lg)
        #if !SKIP
        .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
        #else
        .background(Color.DesignSystem.glassSurface.opacity(0.15))
        #endif
        .cornerRadius(Spacing.md)
    }

    private var environmentalImpact: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(t.t("insights.environmental_impact"))
                .font(.DesignSystem.headlineSmall)
                .fontWeight(.semibold)

            VStack(spacing: Spacing.sm) {
                ImpactRow(
                    icon: "leaf.fill",
                    title: t.t("insights.food_saved"),
                    value: String(format: "%.1f kg", insights.foodSavedKg),
                    color: .green,
                )

                ImpactRow(
                    icon: "cloud.fill",
                    title: t.t("insights.co2_prevented"),
                    value: String(format: "%.1f kg", insights.co2SavedKg),
                    color: .blue,
                )

                ImpactRow(
                    icon: "drop.fill",
                    title: t.t("insights.water_saved"),
                    value: String(format: "%.0f L", insights.waterSavedLiters),
                    color: .cyan,
                )

                ImpactRow(
                    icon: "dollarsign.circle.fill",
                    title: t.t("insights.money_saved"),
                    value: String(format: "$%.0f", insights.moneySavedEstimate),
                    color: .yellow,
                )
            }
        }
        .padding(Spacing.md)
        #if !SKIP
        .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
        #else
        .background(Color.DesignSystem.glassSurface.opacity(0.15))
        #endif
        .cornerRadius(Spacing.md)
    }
}

// MARK: - Insights Stat Card (local to InsightsView)

private struct InsightsStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.DesignSystem.headlineLarge)
                .fontWeight(.bold)

            Text(title)
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        #if !SKIP
        .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
        #else
        .background(Color.DesignSystem.glassSurface.opacity(0.15))
        #endif
        .cornerRadius(Spacing.md)
    }
}

// MARK: - Impact Row

struct ImpactRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
                .frame(width: 30.0)

            Text(title)
                .font(.DesignSystem.bodyMedium)

            Spacer()

            Text(value)
                .font(.DesignSystem.bodyMedium)
                .fontWeight(.semibold)
        }
        .padding(.vertical, Spacing.xs)
    }
}

#if DEBUG
    #Preview {
        NavigationStack {
            InsightsView(insights: .fixture())
        }
    }
#endif

#endif
