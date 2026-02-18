//
//  GlassReputationCard.swift
//  Foodshare
//
//  Liquid Glass reputation card with trust level badge and progress indicator
//  Part of the Forum Feature - Phase 3.3 Reputation System
//


#if !SKIP
import SwiftUI

// MARK: - Glass Reputation Card

/// Displays user reputation with trust level badge and progress towards next level
struct GlassReputationCard: View {
    let stats: ForumUserStats
    let currentTrustLevel: ForumTrustLevel
    let nextTrustLevel: ForumTrustLevel?
    let showDetails: Bool
    let onTap: (() -> Void)?

    init(
        stats: ForumUserStats,
        currentTrustLevel: ForumTrustLevel? = nil,
        nextTrustLevel: ForumTrustLevel? = nil,
        showDetails: Bool = true,
        onTap: (() -> Void)? = nil,
    ) {
        self.stats = stats
        self.currentTrustLevel = currentTrustLevel ?? ForumTrustLevel.all[min(stats.trustLevel, 4)]
        self.nextTrustLevel = nextTrustLevel ?? (stats.trustLevel < 4 ? ForumTrustLevel.all[stats.trustLevel + 1] : nil)
        self.showDetails = showDetails
        self.onTap = onTap
    }

    #if !SKIP
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    #endif

    var body: some View {
        Button {
            onTap?()
        } label: {
            VStack(spacing: Spacing.md) {
                // Header with reputation score and trust level
                headerSection

                if showDetails {
                    // Progress towards next level
                    if let nextLevel = nextTrustLevel {
                        progressSection(nextLevel: nextLevel)
                    } else {
                        maxLevelBadge
                    }

                    // Stats summary
                    statsRow
                }
            }
            .padding(Spacing.lg)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl)
                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
            )
            .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
        }
        .buttonStyle(CardPressStyle())
        #if !SKIP
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        #endif
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: Spacing.md) {
            // Trust level badge
            trustLevelBadge

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(currentTrustLevel.name)
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(.DesignSystem.text)

                HStack(spacing: Spacing.xs) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)

                    Text("\(stats.reputationScore) reputation")
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
            }

            Spacer()

            // Activity indicator
            activityBadge
        }
    }

    // MARK: - Trust Level Badge

    private var trustLevelBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            currentTrustLevel.swiftUIColor.opacity(0.3),
                            currentTrustLevel.swiftUIColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(width: 56.0, height: 56)

            Circle()
                .stroke(currentTrustLevel.swiftUIColor, lineWidth: 2)
                .frame(width: 56.0, height: 56)

            Image(systemName: currentTrustLevel.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(currentTrustLevel.swiftUIColor)
        }
    }

    // MARK: - Activity Badge

    private var activityBadge: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: stats.activityLevel.icon)
                .font(.system(size: 10))
            Text(stats.activityLevel.rawValue)
                .font(.DesignSystem.captionSmall)
        }
        .foregroundColor(stats.activityLevel.color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(stats.activityLevel.color.opacity(0.15)),
        )
    }

    // MARK: - Progress Section

    private func progressSection(nextLevel: ForumTrustLevel) -> some View {
        let progress = nextLevel.progressForUser(stats)

        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Progress to \(nextLevel.name)")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Spacer()

                Text("\(Int(progress.overallProgress * 100))%")
                    .font(.DesignSystem.bodySmall)
                    .fontWeight(.semibold)
                    .foregroundColor(nextLevel.swiftUIColor)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(height: 8.0)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    currentTrustLevel.swiftUIColor,
                                    nextLevel.swiftUIColor
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .frame(width: geometry.size.width * progress.overallProgress, height: 8)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress.overallProgress)
                }
            }
            .frame(height: 8.0)

            // Incomplete requirements preview
            if !progress.incompleteRequirements.isEmpty {
                let previewRequirements = Array(progress.incompleteRequirements.prefix(2))
                HStack(spacing: Spacing.sm) {
                    ForEach(previewRequirements) { requirement in
                        requirementChip(requirement)
                    }

                    if progress.incompleteRequirements.count > 2 {
                        Text("+\(progress.incompleteRequirements.count - 2) more")
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textTertiary)
                    }
                }
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
                        .stroke(Color.DesignSystem.glassBorder.opacity(0.5), lineWidth: 1),
                ),
        )
    }

    // MARK: - Requirement Chip

    private func requirementChip(_ requirement: RequirementProgress) -> some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: requirement.icon)
                .font(.system(size: 10))
            Text(requirement.displayText)
                .font(.DesignSystem.captionSmall)
        }
        .foregroundColor(requirement.isMet ? .green : .DesignSystem.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(Color.DesignSystem.glassBackground),
        )
    }

    // MARK: - Max Level Badge

    private var maxLevelBadge: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)

            Text("Maximum trust level achieved!")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.text)

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.accentYellow.opacity(0.15),
                            Color.DesignSystem.warning.opacity(0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.accentYellow.opacity(0.3), lineWidth: 1),
                ),
        )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 0) {
            ReputationStatItem(
                value: "\(stats.postsCount)",
                label: "Posts",
                icon: "square.and.pencil",
                color: .DesignSystem.brandGreen,
            )

            Divider()
                .frame(height: 32.0)

            ReputationStatItem(
                value: "\(stats.commentsCount)",
                label: "Comments",
                icon: "text.bubble.fill",
                color: .DesignSystem.brandBlue,
            )

            Divider()
                .frame(height: 32.0)

            ReputationStatItem(
                value: "\(stats.likesReceived)",
                label: "Likes",
                icon: "heart.fill",
                color: .red,
            )

            Divider()
                .frame(height: 32.0)

            ReputationStatItem(
                value: stats.formattedTimeSpent,
                label: "Time",
                icon: "clock.fill",
                color: .purple,
            )
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var cardBackground: some View {
        #if !SKIP
        if reduceTransparency {
            Color(uiColor: .systemBackground)
                .opacity(0.95)
        } else {
            Color.clear
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        }
        #else
        Color.clear
            #if !SKIP
            .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
            #else
            .background(Color.DesignSystem.glassSurface.opacity(0.15))
            #endif
        #endif
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = "\(currentTrustLevel.name), \(stats.reputationScore) reputation points"
        label += ", \(stats.activityLevel.rawValue)"
        if let nextLevel = nextTrustLevel {
            let progress = nextLevel.progressForUser(stats)
            label += ", \(Int(progress.overallProgress * 100))% progress to \(nextLevel.name)"
        }
        return label
    }
}

// MARK: - Reputation Stat Item

private struct ReputationStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xxs) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(value)
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.text)
            }

            Text(label)
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Compact Reputation Badge

/// A compact badge showing just the trust level for use in post author headers
struct GlassTrustLevelBadge: View {
    let trustLevel: ForumTrustLevel

    init(level: Int) {
        trustLevel = ForumTrustLevel.all[min(level, 4)]
    }

    init(trustLevel: ForumTrustLevel) {
        self.trustLevel = trustLevel
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: trustLevel.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(trustLevel.shortName)
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
        }
        .foregroundColor(trustLevel.swiftUIColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(trustLevel.swiftUIColor.opacity(0.15))
                .overlay(
                    Capsule()
                        .stroke(trustLevel.swiftUIColor.opacity(0.3), lineWidth: 1),
                ),
        )
        .accessibilityLabel("\(trustLevel.name) trust level")
    }
}

// MARK: - Reputation Progress Ring

/// A circular progress indicator for reputation/trust level
struct GlassReputationRing: View {
    let progress: Double
    let currentLevel: ForumTrustLevel
    let nextLevel: ForumTrustLevel?
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.DesignSystem.glassBackground, lineWidth: size / 10)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        colors: [
                            currentLevel.swiftUIColor,
                            nextLevel?.swiftUIColor ?? currentLevel.swiftUIColor
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                    style: StrokeStyle(
                        lineWidth: size / 10,
                        lineCap: .round,
                    ),
                )
                .rotationEffect(Angle.degrees(-90))

            // Center content
            VStack(spacing: 2) {
                Image(systemName: currentLevel.icon)
                    .font(.system(size: size / 3, weight: .semibold))
                    .foregroundColor(currentLevel.swiftUIColor)

                Text("L\(currentLevel.level)")
                    .font(.system(size: size / 5, weight: .bold))
                    .foregroundColor(.DesignSystem.text)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Reputation Card - Full") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            GlassReputationCard(
                stats: ForumUserStats.fixture(reputationScore: 250, trustLevel: 2),
                onTap: {},
            )

            GlassReputationCard(
                stats: ForumUserStats.fixture(reputationScore: 1500, trustLevel: 4),
                onTap: {},
            )
        }
        .padding()
    }
    .background(Color.DesignSystem.background)
}

#Preview("Trust Level Badges") {
    HStack(spacing: Spacing.md) {
        ForEach(0 ..< 5) { level in
            GlassTrustLevelBadge(level: level)
        }
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#Preview("Reputation Ring") {
    HStack(spacing: Spacing.xl) {
        GlassReputationRing(
            progress: 0.65,
            currentLevel: .member,
            nextLevel: .regular,
            size: 80,
        )

        GlassReputationRing(
            progress: 1.0,
            currentLevel: .leader,
            nextLevel: nil,
            size: 80,
        )
    }
    .padding()
    .background(Color.DesignSystem.background)
}
#endif

#endif
