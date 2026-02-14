//
//  GlassSkeletonCard.swift
//  FoodShare
//
//  Skeleton loading card for feed and forum items.
//  Features shimmer effect and respects accessibility settings.
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Skeleton Card

/// A skeleton loading card with shimmer effect
struct GlassSkeletonCard: View {
    let style: Style
    let lineCount: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum Style {
        case feedItem
        case forumPost
        case comment
        case profile
        case compact

        var height: CGFloat {
            switch self {
            case .feedItem: return 280
            case .forumPost: return 180
            case .comment: return 80
            case .profile: return 120
            case .compact: return 60
            }
        }

        var showsImage: Bool {
            switch self {
            case .feedItem: return true
            case .forumPost: return false
            case .comment: return false
            case .profile: return true
            case .compact: return true
            }
        }

        var imageHeight: CGFloat {
            switch self {
            case .feedItem: return 160
            case .profile: return 60
            case .compact: return 40
            default: return 0
            }
        }
    }

    init(style: Style = .feedItem, lineCount: Int = 3) {
        self.style = style
        self.lineCount = lineCount
    }

    var body: some View {
        Group {
            switch style {
            case .feedItem:
                feedItemSkeleton
            case .forumPost:
                forumPostSkeleton
            case .comment:
                commentSkeleton
            case .profile:
                profileSkeleton
            case .compact:
                compactSkeleton
            }
        }
        .glassShimmer(isActive: !reduceMotion)
    }

    // MARK: - Feed Item Skeleton

    private var feedItemSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image placeholder
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassBackground)
                .frame(height: style.imageHeight)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Title placeholder
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 40)

                // Subtitle placeholder
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 80)

                // Meta info row
                HStack(spacing: Spacing.md) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.DesignSystem.glassBackground)
                            .frame(width: 60, height: 14)
                    }
                    Spacer()
                }
            }
            .padding(Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Forum Post Skeleton

    private var forumPostSkeleton: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Author row
            HStack(spacing: Spacing.sm) {
                Circle()
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(width: 100, height: 14)

                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(width: 60, height: 12)
                }

                Spacer()
            }

            // Title placeholder
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(Color.DesignSystem.glassBackground)
                .frame(height: 18)
                .frame(maxWidth: .infinity)
                .padding(.trailing, 20)

            // Content lines
            VStack(alignment: .leading, spacing: Spacing.xs) {
                ForEach(0..<lineCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(height: 14)
                        .frame(maxWidth: .infinity)
                        .padding(.trailing, index == lineCount - 1 ? 100 : 0)
                }
            }

            // Action row
            HStack(spacing: Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: CornerRadius.small)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(width: 50, height: 14)
                }
                Spacer()
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Comment Skeleton

    private var commentSkeleton: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(Color.DesignSystem.glassBackground)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(width: 80, height: 14)

                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)

                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 60)
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassBackground.opacity(0.5))
        )
    }

    // MARK: - Profile Skeleton

    private var profileSkeleton: some View {
        HStack(spacing: Spacing.md) {
            Circle()
                .fill(Color.DesignSystem.glassBackground)
                .frame(width: style.imageHeight, height: style.imageHeight)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(width: 120, height: 18)

                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(width: 80, height: 14)

                HStack(spacing: Spacing.sm) {
                    ForEach(0..<2, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.DesignSystem.glassBackground)
                            .frame(width: 60, height: 14)
                    }
                }
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Compact Skeleton

    private var compactSkeleton: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(Color.DesignSystem.glassBackground)
                .frame(width: style.imageHeight, height: style.imageHeight)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                    .padding(.trailing, 40)

                RoundedRectangle(cornerRadius: CornerRadius.small)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(width: 80, height: 12)
            }

            Spacer()
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassBackground.opacity(0.5))
        )
    }
}

// MARK: - Skeleton List

/// A list of skeleton cards for loading states
struct GlassSkeletonList: View {
    let count: Int
    let style: GlassSkeletonCard.Style
    let spacing: CGFloat

    init(
        count: Int = 3,
        style: GlassSkeletonCard.Style = .feedItem,
        spacing: CGFloat = Spacing.md
    ) {
        self.count = count
        self.style = style
        self.spacing = spacing
    }

    var body: some View {
        LazyVStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { _ in
                GlassSkeletonCard(style: style)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("GlassSkeletonCard Styles") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            Text("Feed Item")
                .font(.DesignSystem.headlineMedium)
            GlassSkeletonCard(style: .feedItem)

            Text("Forum Post")
                .font(.DesignSystem.headlineMedium)
            GlassSkeletonCard(style: .forumPost)

            Text("Comment")
                .font(.DesignSystem.headlineMedium)
            GlassSkeletonCard(style: .comment)

            Text("Profile")
                .font(.DesignSystem.headlineMedium)
            GlassSkeletonCard(style: .profile)

            Text("Compact")
                .font(.DesignSystem.headlineMedium)
            GlassSkeletonCard(style: .compact)
        }
        .padding()
    }
    .background(Color.backgroundGradient)
}
#endif
