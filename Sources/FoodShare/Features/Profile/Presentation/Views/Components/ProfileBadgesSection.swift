//
//  ProfileBadgesSection.swift
//  FoodShare
//
//  Displays user badges and achievements in a horizontal scroll.
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Badges Section

struct ProfileBadgesSection: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            headerRow

            if viewModel.isLoadingBadges {
                loadingState
            } else if let collection = viewModel.badgeCollection {
                BadgesContent(collection: collection)
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Label(t.t("profile.badges"), systemImage: "medal.fill")
                .font(.LiquidGlass.headlineSmall)
                .foregroundStyle(Color.DesignSystem.text)

            Spacer()

            if let collection = viewModel.badgeCollection {
                Text("\(collection.earnedBadges.count)/\(collection.allBadges.count)")
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            NavigationLink(value: ProfileDestination.badges(
                collection: viewModel.badgeCollection ?? .empty,
                stats: viewModel.userStats ?? .empty
            )) {
                Image(systemName: "chevron.right")
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        HStack {
            Spacer()
            ProgressView().scaleEffect(0.8)
            Spacer()
        }
        .padding(.vertical, Spacing.md)
    }
}

// MARK: - Badges Content

struct BadgesContent: View {
    @Environment(\.translationService) private var t
    let collection: BadgeCollection

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !collection.featuredBadges.isEmpty {
                featuredBadgesScroll
            } else if !collection.earnedBadges.isEmpty {
                earnedBadgesGrid
            }

            if collection.totalPoints > 0 {
                pointsRow
            }
        }
    }

    // MARK: - Featured Badges Scroll

    private var featuredBadgesScroll: some View {
        GlassHorizontalScroll.compact {
            ForEach(collection.featuredBadges) { userBadge in
                GlassBadgeItem(
                    badge: userBadge.badge,
                    isEarned: true,
                    isFeatured: true,
                    progress: nil,
                    onTap: nil
                )
                .frame(width: 72)
            }
        }
    }

    // MARK: - Earned Badges Grid

    private var earnedBadgesGrid: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(Array(collection.earnedBadges.prefix(4))) { userBadge in
                GlassBadgeItem(
                    badge: userBadge.badge,
                    isEarned: true,
                    isFeatured: false,
                    progress: nil,
                    onTap: nil
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Points Row

    private var pointsRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "star.fill")
                .font(.system(size: 14))
                .foregroundStyle(.yellow)

            Text(t.t("profile.badge_points_earned", args: ["count": "\(collection.totalPoints)"]))
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            Spacer()
        }
        .padding(.top, Spacing.xs)
    }
}

// MARK: - Glass Badge Item

struct GlassBadgeItem: View {
    let badge: Badge
    let isEarned: Bool
    let isFeatured: Bool
    let progress: Double?
    let onTap: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: { onTap?() }) {
            VStack(spacing: Spacing.xs) {
                badgeIcon

                Text(badge.name)
                    .font(.LiquidGlass.captionSmall)
                    .foregroundStyle(isEarned ? Color.DesignSystem.text : Color.DesignSystem.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(.plain)
        .opacity(isEarned ? 1.0 : 0.5)
        .accessibilityLabel("\(badge.name), \(isEarned ? "earned" : "locked")")
    }

    // MARK: - Badge Icon

    private var badgeIcon: some View {
        ZStack {
            Circle()
                .fill(
                    isEarned
                        ? LinearGradient(
                            colors: [badge.color.opacity(0.3), badge.color.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.DesignSystem.glassBackground, Color.DesignSystem.glassBackground.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                )
                .frame(width: 48, height: 48)

            if isEarned {
                Image(systemName: badge.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(badge.color)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }

            if isFeatured && isEarned {
                featuredIndicator
            }
        }
    }

    // MARK: - Featured Indicator

    private var featuredIndicator: some View {
        VStack {
            HStack {
                Spacer()
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                    .padding(3)
                    .background(Color.DesignSystem.surface)
                    .clipShape(Circle())
            }
            Spacer()
        }
        .frame(width: 48, height: 48)
    }
}

// MARK: - Badge Model Extensions

extension Badge {
    /// Returns the appropriate color for the badge type
    var color: Color {
        switch category {
        case "sharing": return .DesignSystem.brandOrange
        case "receiving": return .DesignSystem.success
        case "community": return .DesignSystem.brandBlue
        case "special": return .DesignSystem.brandPink
        default: return .DesignSystem.themed.primary
        }
    }
}
