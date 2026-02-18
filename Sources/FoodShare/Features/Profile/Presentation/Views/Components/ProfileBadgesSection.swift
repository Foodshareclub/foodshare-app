//
//  ProfileBadgesSection.swift
//  FoodShare
//
//  Displays user badges and achievements in a horizontal scroll.
//


#if !SKIP
import SwiftUI

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
                .frame(width: 72.0)
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


#endif
