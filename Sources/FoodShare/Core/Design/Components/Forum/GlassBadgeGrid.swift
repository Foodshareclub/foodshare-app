//
//  GlassBadgeGrid.swift
//  Foodshare
//
//  Liquid Glass badge display components for the forum gamification system
//  Part of the Forum Feature - Phase 3.4 Badges System
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Badge Grid

/// Displays a grid of badges with earned/locked states and rarity effects
struct GlassBadgeGrid: View {
    let badges: [ForumBadge]
    let earnedBadgeIds: Set<Int>
    let featuredBadgeIds: Set<Int>
    let userStats: ForumUserStats?
    let columns: Int
    let onBadgeTap: ((ForumBadge) -> Void)?

    init(
        badges: [ForumBadge],
        earnedBadgeIds: Set<Int> = [],
        featuredBadgeIds: Set<Int> = [],
        userStats: ForumUserStats? = nil,
        columns: Int = 4,
        onBadgeTap: ((ForumBadge) -> Void)? = nil,
    ) {
        self.badges = badges
        self.earnedBadgeIds = earnedBadgeIds
        self.featuredBadgeIds = featuredBadgeIds
        self.userStats = userStats
        self.columns = columns
        self.onBadgeTap = onBadgeTap
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Spacing.md), count: columns)
    }

    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: Spacing.md) {
            ForEach(badges) { badge in
                GlassBadgeItem(
                    badge: badge,
                    isEarned: earnedBadgeIds.contains(badge.id),
                    isFeatured: featuredBadgeIds.contains(badge.id),
                    progress: userStats.flatMap { badge.criteria?.progress(for: $0) },
                    onTap: { onBadgeTap?(badge) },
                )
            }
        }
    }
}

// MARK: - Glass Badge Item

/// Individual badge display with rarity glow and progress overlay
struct GlassBadgeItem: View {
    let badge: ForumBadge
    let isEarned: Bool
    let isFeatured: Bool
    let progress: Double?
    let onTap: (() -> Void)?
    var isNewlyEarned = false

    @State private var isPressed = false
    @State private var showGlow = false
    @State private var showCelebration = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            onTap?()
            if isNewlyEarned {
                HapticManager.success()
            }
        } label: {
            ZStack {
                // Rarity glow effect (for earned badges)
                if isEarned, badge.rarity.glowIntensity > 0 {
                    rarityGlow
                }

                // Badge container
                badgeContainer

                // Featured star indicator
                if isFeatured, isEarned {
                    featuredIndicator
                }

                // Progress overlay (for unearned badges with criteria)
                if !isEarned, let progress, progress > 0 {
                    progressOverlay(progress)
                }
            }
        }
        .buttonStyle(BadgePressStyle())
        .proMotionConfetti(trigger: $showCelebration, style: .stars)
        .onAppear {
            if isEarned, !reduceMotion {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    showGlow = true
                }
            }
            // Trigger celebration for newly earned badges
            if isNewlyEarned, !reduceMotion {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    showCelebration.toggle()
                    HapticManager.success()
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isEarned ? "Double tap to view details" : "Badge not yet earned")
    }

    // MARK: - Badge Container

    private var badgeContainer: some View {
        VStack(spacing: Spacing.xs) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(
                        isEarned
                            ? LinearGradient(
                                colors: [
                                    badge.swiftUIColor.opacity(0.3),
                                    badge.swiftUIColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            )
                            : LinearGradient(
                                colors: [
                                    Color.DesignSystem.accentGray.opacity(0.15),
                                    Color.DesignSystem.accentGray.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                    )

                Circle()
                    .stroke(
                        isEarned ? badge.swiftUIColor.opacity(0.5) : Color.DesignSystem.accentGray.opacity(0.3),
                        lineWidth: 2,
                    )

                Image(systemName: badge.sfSymbolName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isEarned ? badge.swiftUIColor : .gray.opacity(0.4))

                // Lock overlay for unearned
                if !isEarned {
                    Circle()
                        .fill(Color.black.opacity(0.3))

                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .frame(width: 48, height: 48)

            // Badge name
            Text(badge.name)
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
                .foregroundColor(isEarned ? .DesignSystem.text : .DesignSystem.textTertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 32)
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.xs)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .opacity(isEarned ? 1 : 0.5),
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    isEarned ? badge.swiftUIColor.opacity(0.3) : Color.DesignSystem.glassBorder.opacity(0.3),
                    lineWidth: 1,
                ),
        )
    }

    // MARK: - Rarity Glow

    private var rarityGlow: some View {
        RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(badge.rarity.color)
            .blur(radius: 12)
            .opacity(showGlow ? badge.rarity.glowIntensity : badge.rarity.glowIntensity * 0.5)
            .scaleEffect(showGlow ? 1.1 : 1.0)
    }

    // MARK: - Featured Indicator

    private var featuredIndicator: some View {
        VStack {
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.DesignSystem.accentYellow)
                        .frame(width: 18, height: 18)

                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: 4, y: -4)
            }
            Spacer()
        }
    }

    // MARK: - Progress Overlay

    private func progressOverlay(_ progress: Double) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(badge.swiftUIColor.opacity(0.8)),
                    )
                    .offset(x: 2, y: 4)
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = badge.name
        if isEarned {
            label += ", earned"
            if isFeatured {
                label += ", featured badge"
            }
            label += ", \(badge.rarity.displayName) rarity"
        } else {
            label += ", locked"
            if let progress {
                label += ", \(Int(progress * 100))% progress"
            }
        }
        return label
    }
}

// MARK: - Badge Press Style

private struct BadgePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Glass Badge Card

/// A larger badge display card with full details
struct GlassBadgeCard: View {
    let badge: ForumBadge
    let userBadge: UserBadge?
    let userStats: ForumUserStats?
    let onToggleFeatured: (() -> Void)?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var isEarned: Bool { userBadge != nil }
    private var isFeatured: Bool { userBadge?.isFeatured ?? false }
    private var progress: Double? {
        guard let stats = userStats, let criteria = badge.criteria else { return nil }
        return criteria.progress(for: stats)
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            // Badge icon with rarity effect
            badgeIcon

            // Badge info
            VStack(spacing: Spacing.sm) {
                Text(badge.name)
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(.DesignSystem.text)

                Text(badge.description)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)

                // Type and rarity tags
                HStack(spacing: Spacing.sm) {
                    badgeTypeTag
                    rarityTag
                    pointsTag
                }
            }

            // Progress or earned info
            if isEarned {
                earnedSection
            } else if let progress, badge.hasAutoCriteria {
                progressSection(progress)
            }
        }
        .padding(Spacing.lg)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(
                    isEarned ? badge.swiftUIColor.opacity(0.3) : Color.DesignSystem.glassBorder,
                    lineWidth: 1,
                ),
        )
        .shadow(color: isEarned ? badge.rarity.color.opacity(0.2) : .black.opacity(0.1), radius: 20, y: 10)
    }

    // MARK: - Badge Icon

    private var badgeIcon: some View {
        ZStack {
            // Outer glow for earned badges
            if isEarned, badge.rarity.glowIntensity > 0 {
                Circle()
                    .fill(badge.rarity.color)
                    .blur(radius: 20)
                    .opacity(badge.rarity.glowIntensity)
                    .frame(width: 100, height: 100)
            }

            // Icon circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                badge.swiftUIColor.opacity(isEarned ? 0.3 : 0.1),
                                badge.swiftUIColor.opacity(isEarned ? 0.1 : 0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )

                Circle()
                    .stroke(
                        badge.swiftUIColor.opacity(isEarned ? 0.6 : 0.2),
                        lineWidth: 3,
                    )

                Image(systemName: badge.sfSymbolName)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(isEarned ? badge.swiftUIColor : badge.swiftUIColor.opacity(0.3))
            }
            .frame(width: 80, height: 80)

            // Lock for unearned
            if !isEarned {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 80, height: 80)

                Image(systemName: "lock.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Tags

    private var badgeTypeTag: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: badge.badgeType.icon)
                .font(.system(size: 10))
            Text(badge.badgeType.displayName)
                .font(.DesignSystem.captionSmall)
        }
        .foregroundColor(.DesignSystem.textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(Color.DesignSystem.glassBackground),
        )
    }

    private var rarityTag: some View {
        Text(badge.rarity.displayName)
            .font(.DesignSystem.captionSmall)
            .fontWeight(.medium)
            .foregroundColor(badge.rarity.color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                Capsule()
                    .fill(badge.rarity.color.opacity(0.15)),
            )
    }

    private var pointsTag: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "star.fill")
                .font(.system(size: 10))
            Text("\(badge.points) pts")
                .font(.DesignSystem.captionSmall)
        }
        .foregroundColor(Color.DesignSystem.accentYellow)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(Color.DesignSystem.accentYellow.opacity(0.15)),
        )
    }

    // MARK: - Earned Section

    private var earnedSection: some View {
        VStack(spacing: Spacing.sm) {
            // Earned date
            if let awardedAt = userBadge?.awardedAt {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text("Earned \(awardedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.DesignSystem.bodySmall)
                }
                .foregroundColor(.DesignSystem.textSecondary)
            }

            // Feature toggle button
            if let onToggle = onToggleFeatured {
                Button {
                    onToggle()
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: isFeatured ? "star.fill" : "star")
                            .font(.system(size: 14))
                        Text(isFeatured ? "Featured" : "Feature on Profile")
                            .font(.DesignSystem.bodySmall)
                    }
                    .foregroundColor(isFeatured ? Color.DesignSystem.accentYellow : .DesignSystem.text)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(isFeatured
                                ? Color.DesignSystem.accentYellow.opacity(0.2)
                                : Color.DesignSystem.glassBackground)
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            isFeatured
                                                ? Color.DesignSystem.accentYellow.opacity(0.4)
                                                : Color.DesignSystem.glassBorder,
                                            lineWidth: 1,
                                        ),
                                ),
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Progress Section

    private func progressSection(_ progress: Double) -> some View {
        VStack(spacing: Spacing.sm) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(badge.swiftUIColor)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(progress * 100))% progress")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Spacer()

                if let requirement = badge.criteria?.requirementDescription {
                    Text(requirement)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }
            }
        }
        .padding(.top, Spacing.sm)
    }

    // MARK: - Background

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            Color(uiColor: .systemBackground)
                .opacity(0.95)
        } else {
            Color.clear
                .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Glass Badge Collection View

/// A complete badge collection view with sections by type
struct GlassBadgeCollectionView: View {
    @Environment(\.translationService) private var t
    let collection: BadgeCollection
    let userStats: ForumUserStats
    let onBadgeTap: ((ForumBadge) -> Void)?
    let onToggleFeatured: ((UserBadgeWithDetails) -> Void)?

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                // Summary header
                collectionSummary

                // Featured badges
                if !collection.featuredBadges.isEmpty {
                    featuredSection
                }

                // Badges by type
                ForEach(BadgeType.allCases.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.self) { type in
                    if let badges = collection.badgesByType[type], !badges.isEmpty {
                        badgeTypeSection(type: type, badges: badges)
                    }
                }
            }
            .padding(Spacing.lg)
        }
    }

    // MARK: - Collection Summary

    private var collectionSummary: some View {
        HStack(spacing: Spacing.lg) {
            // Earned count
            VStack(spacing: Spacing.xs) {
                Text("\(collection.earnedBadges.count)")
                    .font(.DesignSystem.displayLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.brandGreen)

                Text("of \(collection.allBadges.count)")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Text(t.t("profile.badges"))
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }

            Divider()
                .frame(height: 60)

            // Total points
            VStack(spacing: Spacing.xs) {
                Text("\(collection.totalPoints)")
                    .font(.DesignSystem.displayLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)

                Text(t.t("profile.points"))
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Text(t.t("profile.earned"))
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }

            Divider()
                .frame(height: 60)

            // Completion percentage
            VStack(spacing: Spacing.xs) {
                let percentage = collection.allBadges.isEmpty
                    ? 0
                    : Int((Double(collection.earnedBadges.count) / Double(collection.allBadges.count)) * 100)
                Text("\(percentage)%")
                    .font(.DesignSystem.displayLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.brandBlue)

                Text(t.t("common.complete"))
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Text(t.t("profile.collection"))
                    .font(.DesignSystem.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    // MARK: - Featured Section

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text(t.t("profile.featured_badges"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(collection.featuredBadges) { userBadge in
                        GlassBadgeItem(
                            badge: userBadge.badge,
                            isEarned: true,
                            isFeatured: true,
                            progress: nil,
                            onTap: { onBadgeTap?(userBadge.badge) },
                        )
                        .frame(width: 80)
                    }
                }
            }
        }
    }

    // MARK: - Badge Type Section

    private func badgeTypeSection(type: BadgeType, badges: [ForumBadge]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: type.icon)
                    .foregroundColor(.DesignSystem.brandGreen)
                Text("\(type.displayName) Badges")
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                let earnedCount = badges.count(where: { collection.earnedBadgeIds.contains($0.id) })
                Text("\(earnedCount)/\(badges.count)")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            GlassBadgeGrid(
                badges: badges.sorted(by: { $0.points < $1.points }),
                earnedBadgeIds: collection.earnedBadgeIds,
                featuredBadgeIds: Set(collection.featuredBadges.map(\.badge.id)),
                userStats: userStats,
                onBadgeTap: onBadgeTap,
            )
        }
    }
}

// MARK: - Previews

#if DEBUG
    #Preview("Badge Grid") {
        GlassBadgeGrid(
            badges: ForumBadge.fixtures,
            earnedBadgeIds: [1, 17],
            featuredBadgeIds: [1],
            userStats: ForumUserStats.fixture(),
        )
        .padding()
        .background(Color.DesignSystem.background)
    }

    #Preview("Badge Item - States") {
        HStack(spacing: Spacing.lg) {
            // Earned + Featured
            GlassBadgeItem(
                badge: ForumBadge.fixtures[0],
                isEarned: true,
                isFeatured: true,
                progress: nil,
                onTap: {},
            )
            .frame(width: 80)

            // Earned
            GlassBadgeItem(
                badge: ForumBadge.fixtures[1],
                isEarned: true,
                isFeatured: false,
                progress: nil,
                onTap: {},
            )
            .frame(width: 80)

            // Locked with progress
            GlassBadgeItem(
                badge: ForumBadge.fixtures[1],
                isEarned: false,
                isFeatured: false,
                progress: 0.65,
                onTap: {},
            )
            .frame(width: 80)

            // Locked
            GlassBadgeItem(
                badge: ForumBadge.fixtures[2],
                isEarned: false,
                isFeatured: false,
                progress: nil,
                onTap: {},
            )
            .frame(width: 80)
        }
        .padding()
        .background(Color.DesignSystem.background)
    }

    #Preview("Badge Card - Earned") {
        GlassBadgeCard(
            badge: ForumBadge.fixtures[0],
            userBadge: UserBadge.fixture(badgeId: 1),
            userStats: ForumUserStats.fixture(),
            onToggleFeatured: {},
        )
        .padding()
        .background(Color.DesignSystem.background)
    }

    #Preview("Badge Card - Locked") {
        GlassBadgeCard(
            badge: ForumBadge.fixtures[1],
            userBadge: nil,
            userStats: ForumUserStats.fixture(postsCount: 5),
            onToggleFeatured: nil,
        )
        .padding()
        .background(Color.DesignSystem.background)
    }

    #Preview("Badge Collection") {
        GlassBadgeCollectionView(
            collection: .fixture,
            userStats: ForumUserStats.fixture(),
            onBadgeTap: { _ in },
            onToggleFeatured: { _ in },
        )
        .background(Color.DesignSystem.background)
    }
#endif
