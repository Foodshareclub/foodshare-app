//
//  BadgesDetailView.swift
//  Foodshare
//
//  Full badge collection view with Liquid Glass design
//  Shows all badges organized by type with progress tracking
//


#if !SKIP
import SwiftUI

#if DEBUG
    import Inject
#endif

// MARK: - Badge Filter Type

enum BadgeFilterType: String, CaseIterable, Sendable {
    case all
    case milestone
    case achievement
    case special

    var titleKey: String {
        switch self {
        case .all: "badges.filter.all"
        case .milestone: "badges.filter.milestones"
        case .achievement: "badges.filter.achievements"
        case .special: "badges.filter.special"
        }
    }

    var badgeType: BadgeType? {
        switch self {
        case .all: nil
        case .milestone: BadgeType.milestone
        case .achievement: BadgeType.achievement
        case .special: BadgeType.special
        }
    }
}

struct BadgesDetailView: View {
    
    @Environment(\.translationService) private var t
    let collection: BadgeCollection
    let userStats: ForumUserStats

    @State private var selectedBadge: ForumBadge?
    @State private var showBadgeDetail = false
    @State private var selectedFilter: BadgeFilterType = .all
    @State private var showUnlockCelebration = false
    @State private var celebrationBadge: ForumBadge?

    private var filteredBadgeTypes: [BadgeType] {
        if let type = selectedFilter.badgeType {
            return [type]
        }
        return BadgeType.allCases.sorted(by: { $0.sortOrder < $1.sortOrder })
    }

    var body: some View {
        ZStack {
            Color.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Summary header
                    summaryCard

                    // Filter bar
                    filterBar

                    // Featured badges (only show when "All" is selected)
                    if selectedFilter == .all, !collection.featuredBadges.isEmpty {
                        featuredSection
                    }

                    // Badges by type
                    ForEach(filteredBadgeTypes, id: \.self) { type in
                        if let badges = collection.badgesByType[type], !badges.isEmpty {
                            badgeTypeSection(type: type, badges: badges)
                        }
                    }
                }
                .padding(Spacing.md)
            }

            // Celebration overlay
            if showUnlockCelebration, let badge = celebrationBadge {
                badgeCelebrationOverlay(badge)
            }
        }
        .navigationTitle(t.t("profile.badges"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBadgeDetail) {
            if let badge = selectedBadge {
                BadgeDetailSheet(
                    badge: badge,
                    userBadge: collection.userBadge(for: badge.id),
                    userStats: userStats,
                )
            }
        }
    }

    // MARK: - Filter Bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(BadgeFilterType.allCases, id: \.self) { filter in
                    filterChip(filter)
                }
            }
            .padding(.horizontal, Spacing.xxs)
        }
        #if !SKIP
        .scrollBounceBehavior(.basedOnSize)
        .fixedSize(horizontal: false, vertical: true)
        #endif
    }

    private func filterChip(_ filter: BadgeFilterType) -> some View {
        let isSelected = selectedFilter == filter
        let count = filter.badgeType.map { type in
            collection.badgesByType[type]?.count ?? 0
        } ?? collection.allBadges.count

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedFilter = filter
            }
            HapticManager.light()
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(t.t(filter.titleKey))
                    .font(.DesignSystem.labelMedium)

                Text("\(count)")
                    .font(.DesignSystem.captionSmall)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.2) : Color.DesignSystem.glassBackground),
                    )
            }
            .foregroundColor(isSelected ? .white : Color.DesignSystem.textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Capsule()
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ))
                            : AnyShapeStyle(Color.DesignSystem.glassBackground),
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isSelected ? Color.white.opacity(0.3) : Color.DesignSystem.glassBorder,
                                lineWidth: 1,
                            ),
                    ),
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Badge Celebration Overlay

    private func badgeCelebrationOverlay(_ badge: ForumBadge) -> some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showUnlockCelebration = false }
                }

            VStack(spacing: Spacing.lg) {
                // Animated badge icon
                ZStack {
                    // Pulsing glow
                    Circle()
                        .fill(badge.rarity.color)
                        .blur(radius: 40)
                        .opacity(0.6)
                        .frame(width: 150.0, height: 150)
                        .scaleEffect(showUnlockCelebration ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                            value: showUnlockCelebration,
                        )

                    // Badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        badge.swiftUIColor.opacity(0.4),
                                        badge.swiftUIColor.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )

                        Circle()
                            .stroke(badge.swiftUIColor.opacity(0.8), lineWidth: 4)

                        Image(systemName: badge.sfSymbolName)
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundColor(badge.swiftUIColor)
                    }
                    .frame(width: 120.0, height: 120)
                    .scaleEffect(showUnlockCelebration ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showUnlockCelebration)
                }

                VStack(spacing: Spacing.sm) {
                    Text(t.t("badges.unlocked"))
                        .font(.DesignSystem.displayMedium)
                        .foregroundColor(.white)

                    Text(badge.name)
                        .font(.DesignSystem.headlineLarge)
                        .foregroundColor(badge.swiftUIColor)

                    Text(badge.description)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(Color.DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)

                    HStack(spacing: Spacing.md) {
                        // Points earned
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(t.t("badges.points_earned", args: ["points": "\(badge.points)"]))
                                .font(.DesignSystem.titleMedium)
                                .foregroundColor(.yellow)
                        }

                        // Rarity
                        Text(badge.rarity.localizedDisplayName(using: t))
                            .font(.DesignSystem.labelMedium)
                            .foregroundColor(badge.rarity.color)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(badge.rarity.color.opacity(0.2)),
                            )
                    }
                    .padding(.top, Spacing.sm)
                }
                .opacity(showUnlockCelebration ? 1 : 0)
                .animation(.easeIn(duration: 0.5).delay(0.3), value: showUnlockCelebration)

                Button {
                    withAnimation { showUnlockCelebration = false }
                } label: {
                    Text(t.t("badges.awesome"))
                        .font(.DesignSystem.titleMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.xxl)
                        .padding(.vertical, Spacing.md)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                                        startPoint: .leading,
                                        endPoint: .trailing,
                                    ),
                                ),
                        )
                }
                .padding(.top, Spacing.lg)
                .opacity(showUnlockCelebration ? 1 : 0)
                .animation(.easeIn(duration: 0.3).delay(0.6), value: showUnlockCelebration)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: Spacing.lg) {
            // Earned count
            VStack(spacing: Spacing.xs) {
                Text("\(collection.earnedBadges.count)")
                    .font(.LiquidGlass.displayLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.brandGreen)

                Text(t.t("badges.summary.of_total", args: ["total": "\(collection.allBadges.count)"]))
                    .font(.LiquidGlass.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Text(t.t("profile.badges"))
                    .font(.LiquidGlass.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }

            Divider()
                .frame(height: 60.0)

            // Total points
            VStack(spacing: Spacing.xs) {
                Text("\(collection.totalPoints)")
                    .font(.LiquidGlass.displayLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.yellow)

                Text(t.t("badges.summary.points"))
                    .font(.LiquidGlass.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Text(t.t("badges.summary.earned"))
                    .font(.LiquidGlass.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }

            Divider()
                .frame(height: 60.0)

            // Completion percentage
            VStack(spacing: Spacing.xs) {
                let percentage = collection.allBadges.isEmpty
                    ? 0
                    : Int((Double(collection.earnedBadges.count) / Double(collection.allBadges.count)) * 100)
                Text("\(percentage)%")
                    .font(.LiquidGlass.displayLarge)
                    .fontWeight(.bold)
                    .foregroundColor(.DesignSystem.brandBlue)

                Text(t.t("badges.summary.complete"))
                    .font(.LiquidGlass.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Text(t.t("badges.summary.collection"))
                    .font(.LiquidGlass.caption)
                    .foregroundColor(.DesignSystem.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .glassEffect(cornerRadius: CornerRadius.xl)
    }

    // MARK: - Featured Section

    private var featuredSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text(t.t("badges.featured"))
                    .font(.LiquidGlass.headlineSmall)
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
                            onTap: {
                                selectedBadge = userBadge.badge
                                showBadgeDetail = true
                            },
                        )
                        .frame(width: 80.0)
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
                Text(t.t("badges.type_section", args: ["type": type.localizedDisplayName(using: t)]))
                    .font(.LiquidGlass.headlineSmall)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                let earnedCount = badges.count(where: { collection.earnedBadgeIds.contains($0.id) })
                Text("\(earnedCount)/\(badges.count)")
                    .font(.LiquidGlass.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            GlassBadgeGrid(
                badges: badges.sorted(by: { $0.points < $1.points }),
                earnedBadgeIds: collection.earnedBadgeIds,
                featuredBadgeIds: Set(collection.featuredBadges.map(\.badge.id)),
                userStats: userStats,
                onBadgeTap: { badge in
                    selectedBadge = badge
                    showBadgeDetail = true
                },
            )
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

// MARK: - Badge Detail Sheet

struct BadgeDetailSheet: View {
    @Environment(\.translationService) private var t
    let badge: ForumBadge
    let userBadge: UserBadgeWithDetails?
    let userStats: ForumUserStats

    @Environment(\.dismiss) private var dismiss: DismissAction
    @State private var showShareSheet = false

    private var isEarned: Bool { userBadge != nil }
    private var progress: Double? {
        guard let criteria = badge.criteria else { return nil }
        return criteria.progress(for: userStats)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Badge icon
                        badgeIcon

                        // Badge info
                        VStack(spacing: Spacing.md) {
                            Text(badge.name)
                                .font(.LiquidGlass.headlineLarge)
                                .foregroundColor(.DesignSystem.text)

                            Text(badge.description)
                                .font(.LiquidGlass.bodyMedium)
                                .foregroundColor(.DesignSystem.textSecondary)
                                .multilineTextAlignment(.center)

                            // Tags
                            HStack(spacing: Spacing.sm) {
                                typeTag
                                rarityTag
                                pointsTag
                            }
                        }

                        // Status section
                        if isEarned {
                            earnedSection
                        } else if let progress, badge.hasAutoCriteria {
                            progressSection(progress)
                        } else {
                            lockedSection
                        }

                        // Share button (only for earned badges)
                        if isEarned {
                            shareButton
                        }
                    }
                    .padding(Spacing.lg)
                }
            }
            .navigationTitle(t.t("badges.detail.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) { dismiss() }
                        .foregroundColor(.DesignSystem.brandGreen)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareBadgeSheet(badge: badge, earnedDate: userBadge?.userBadge.awardedAt)
            }
        }
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button {
            showShareSheet = true
            HapticManager.light()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.DesignSystem.bodyLarge)
                Text(t.t("badges.share._title"))
                    .font(.DesignSystem.titleMedium)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52.0)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(
                        LinearGradient(
                            colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1),
                    ),
            )
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Badge Icon

    private var badgeIcon: some View {
        ZStack {
            // Glow for earned badges
            if isEarned, badge.rarity.glowIntensity > 0 {
                Circle()
                    .fill(badge.rarity.color)
                    .blur(radius: 30)
                    .opacity(badge.rarity.glowIntensity)
                    .frame(width: 120.0, height: 120)
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
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(isEarned ? badge.swiftUIColor : badge.swiftUIColor.opacity(0.3))
            }
            .frame(width: 100.0, height: 100)

            // Lock overlay
            if !isEarned {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: 100.0, height: 100)

                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - Tags

    private var typeTag: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: badge.badgeType.icon)
                .font(.system(size: 10))
            Text(badge.badgeType.localizedDisplayName(using: t))
                .font(.LiquidGlass.captionSmall)
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
        Text(badge.rarity.localizedDisplayName(using: t))
            .font(.LiquidGlass.captionSmall)
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
            Text(t.t("badges.detail.points", args: ["points": "\(badge.points)"]))
                .font(.LiquidGlass.captionSmall)
        }
        .foregroundColor(Color.DesignSystem.accentYellow)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(Color.DesignSystem.accentYellow.opacity(0.15)),
        )
    }

    // MARK: - Status Sections

    private var earnedSection: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.DesignSystem.brandGreen)
                Text(t.t("badges.detail.earned"))
                    .font(.LiquidGlass.headlineSmall)
                    .foregroundColor(.DesignSystem.brandGreen)
            }

            if let awardedAt = userBadge?.userBadge.awardedAt {
                Text(t.t("badges.detail.earned_on", args: ["date": awardedAt.formatted(date: .abbreviated, time: .omitted)]))
                    .font(.LiquidGlass.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassEffect(cornerRadius: CornerRadius.large)
    }

    private func progressSection(_ progress: Double) -> some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(badge.swiftUIColor)
                Text(t.t("badges.detail.progress"))
                    .font(.LiquidGlass.headlineSmall)
                    .foregroundColor(.DesignSystem.text)
            }

            // Progress bar using GlassProgressBar
            GlassProgressBar(
                progress: progress,
                height: 10,
                accentColor: badge.swiftUIColor,
                showPercentage: false,
                animated: true,
            )

            HStack {
                Text(t.t("badges.detail.percent_complete", args: ["percent": "\(Int(progress * 100))"]))
                    .font(.LiquidGlass.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)

                Spacer()

                if let requirement = badge.criteria?.requirementDescription {
                    Text(requirement)
                        .font(.LiquidGlass.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassEffect(cornerRadius: CornerRadius.large)
    }

    private var lockedSection: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "lock.fill")
                    .foregroundColor(.DesignSystem.textSecondary)
                Text(t.t("badges.detail.locked"))
                    .font(.LiquidGlass.headlineSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Text(t.t("badges.detail.locked_description"))
                .font(.LiquidGlass.bodySmall)
                .foregroundColor(.DesignSystem.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

// MARK: - Share Badge Sheet

struct ShareBadgeSheet: View {
    @Environment(\.translationService) private var t
    let badge: ForumBadge
    let earnedDate: Date?

    @Environment(\.dismiss) private var dismiss: DismissAction

    private var shareText: String {
        // Note: Share text uses English for social media compatibility
        var text = "I just earned the \"\(badge.name)\" badge on Foodshare! "
        text += badge.description
        text += " #Foodshare #FoodWasteReduction"
        return text
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    // Badge preview
                    badgePreview

                    // Share options
                    VStack(spacing: Spacing.md) {
                        Text(t.t("badges.share.title"))
                            .font(.DesignSystem.headlineSmall)
                            .foregroundColor(.DesignSystem.text)

                        // Share button - uses system share sheet
                        #if !SKIP
                        ShareLink(item: shareText) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "square.and.arrow.up")
                                Text(t.t("common.share"))
                            }
                            .font(.DesignSystem.titleMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52.0)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.large)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                                            startPoint: .leading,
                                            endPoint: .trailing,
                                        ),
                                    ),
                            )
                        }
                        #else
                        Button(action: {}) {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "square.and.arrow.up")
                                Text(t.t("common.share"))
                            }
                            .font(.DesignSystem.titleMedium)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52.0)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.large)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                                            startPoint: .leading,
                                            endPoint: .trailing,
                                        ),
                                    ),
                            )
                        }
                        #endif

                        // Copy text button
                        Button {
                            UIPasteboard.general.string = shareText
                            HapticManager.success()
                        } label: {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "doc.on.doc")
                                Text(t.t("badges.share.copy_text"))
                            }
                            .font(.DesignSystem.bodyLarge)
                            .foregroundColor(.DesignSystem.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48.0)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(Color.DesignSystem.glassBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                    ),
                            )
                        }
                    }
                    .padding(.horizontal, Spacing.lg)

                    Spacer()
                }
                .padding(.top, Spacing.xl)
            }
            .navigationTitle(t.t("badges.share.nav_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) { dismiss() }
                        .foregroundColor(.DesignSystem.brandGreen)
                }
            }
        }
        .presentationDetents([PresentationDetent.medium])
    }

    private var badgePreview: some View {
        VStack(spacing: Spacing.md) {
            // Badge icon with glow
            ZStack {
                Circle()
                    .fill(badge.rarity.color)
                    .blur(radius: 25)
                    .opacity(badge.rarity.glowIntensity)
                    .frame(width: 100.0, height: 100)

                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    badge.swiftUIColor.opacity(0.3),
                                    badge.swiftUIColor.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )

                    Circle()
                        .stroke(badge.swiftUIColor.opacity(0.6), lineWidth: 3)

                    Image(systemName: badge.sfSymbolName)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(badge.swiftUIColor)
                }
                .frame(width: 80.0, height: 80)
            }

            Text(badge.name)
                .font(.DesignSystem.headlineMedium)
                .foregroundColor(.DesignSystem.text)

            if let date = earnedDate {
                Text(t.t("badges.detail.earned_on", args: ["date": date.formatted(date: .abbreviated, time: .omitted)]))
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            // Rarity badge
            Text(badge.rarity.localizedDisplayName(using: t))
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
                .foregroundColor(badge.rarity.color)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(badge.rarity.color.opacity(0.2)),
                )
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassEffect(cornerRadius: CornerRadius.xl)
        .padding(.horizontal, Spacing.lg)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview {
        NavigationStack {
            BadgesDetailView(
                collection: .fixture,
                userStats: ForumUserStats.fixture(),
            )
        }
    }

    #Preview("Badge Detail") {
        BadgeDetailSheet(
            badge: ForumBadge.fixture,
            userBadge: nil,
            userStats: ForumUserStats.fixture(),
        )
    }

    #Preview("Share Badge") {
        ShareBadgeSheet(
            badge: ForumBadge.fixture,
            earnedDate: Date(),
        )
    }
#endif

#endif
