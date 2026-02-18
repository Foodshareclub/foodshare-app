//
//  GlassDetailSkeleton.swift
//  Foodshare
//
//  Liquid Glass v26 skeleton loading view for detail screens
//  Provides premium loading states with staggered shimmer animations
//


#if !SKIP
import SwiftUI

struct GlassDetailSkeleton: View {
    var style: SkeletonStyle = .foodItem
    var showImage: Bool = true

    enum SkeletonStyle {
        case foodItem
        case communityFridge
        case forumPost
    }

    @State private var shimmerPhase: CGFloat = -200

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if showImage {
                    imagePlaceholder
                }

                VStack(alignment: .leading, spacing: Spacing.md) {
                    switch style {
                    case .foodItem:
                        foodItemSections
                    case .communityFridge:
                        fridgeSections
                    case .forumPost:
                        forumSections
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.lg)
            }
        }
    }

    // MARK: - Image Placeholder

    private var imagePlaceholder: some View {
        Rectangle()
            .fill(skeletonGradient)
            .frame(height: 320.0)
            .overlay(shimmerOverlay)
    }

    // MARK: - Food Item Sections

    private var foodItemSections: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Title section skeleton
            sectionSkeleton {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    skeletonLine(widthFraction: 0.7, height: 32)
                    skeletonLine(widthFraction: 0.9, height: 16)
                    skeletonLine(widthFraction: 0.6, height: 16)
                }
            }
            .staggeredAppearance(index: 0)

            // Stats row skeleton
            sectionSkeleton {
                HStack(spacing: Spacing.md) {
                    skeletonPill(width: 70)
                    skeletonPill(width: 60)
                    Spacer()
                    skeletonPill(width: 80)
                }
            }
            .staggeredAppearance(index: 1)

            // Details section skeleton
            sectionSkeleton {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    skeletonSectionHeader
                    detailRowsSkeleton(count: 4)
                }
            }
            .staggeredAppearance(index: 2)

            // Location section skeleton
            sectionSkeleton {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    skeletonSectionHeader
                    skeletonRect(height: 150)
                    HStack {
                        skeletonCircle(size: 44)
                        skeletonLine(widthFraction: 0.5, height: 14)
                        Spacer()
                        skeletonPill(width: 90)
                    }
                }
            }
            .staggeredAppearance(index: 3)
        }
    }

    // MARK: - Community Fridge Sections

    private var fridgeSections: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header section
            sectionSkeleton {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            skeletonLine(widthFraction: 0.6, height: 28)
                            skeletonLine(widthFraction: 0.4, height: 14)
                        }
                        Spacer()
                        skeletonPill(width: 70)
                    }
                }
            }
            .staggeredAppearance(index: 0)

            // Status cards skeleton
            sectionSkeleton {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    skeletonLine(widthFraction: 0.4, height: 20)
                    HStack(spacing: Spacing.md) {
                        statusCardSkeleton
                        statusCardSkeleton
                    }
                }
            }
            .staggeredAppearance(index: 1)

            // Location section skeleton
            sectionSkeleton {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    skeletonSectionHeader
                    skeletonRect(height: 150)
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        skeletonLine(widthFraction: 0.7, height: 16)
                        skeletonLine(widthFraction: 0.5, height: 14)
                    }
                }
            }
            .staggeredAppearance(index: 2)

            // Info section skeleton
            sectionSkeleton {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    skeletonSectionHeader
                    detailRowsSkeleton(count: 5)
                }
            }
            .staggeredAppearance(index: 3)
        }
    }

    // MARK: - Forum Post Sections

    private var forumSections: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Author section
            sectionSkeleton {
                HStack(spacing: Spacing.sm) {
                    skeletonCircle(size: 48)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        skeletonLine(widthFraction: 0.3, height: 16)
                        skeletonLine(widthFraction: 0.4, height: 12)
                    }
                    Spacer()
                    skeletonPill(width: 80)
                }
            }
            .staggeredAppearance(index: 0)

            // Title and content
            sectionSkeleton {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    skeletonLine(widthFraction: 0.8, height: 24)
                    skeletonLine(widthFraction: 1.0, height: 14)
                    skeletonLine(widthFraction: 0.9, height: 14)
                    skeletonLine(widthFraction: 0.7, height: 14)
                }
            }
            .staggeredAppearance(index: 1)

            // Actions skeleton
            sectionSkeleton {
                HStack(spacing: Spacing.sm) {
                    ForEach(0..<4, id: \.self) { _ in
                        skeletonPill(width: 50)
                    }
                    Spacer()
                }
            }
            .staggeredAppearance(index: 2)

            // Comments skeleton
            VStack(alignment: .leading, spacing: Spacing.sm) {
                skeletonLine(widthFraction: 0.3, height: 18)

                ForEach(0..<3, id: \.self) { index in
                    commentRowSkeleton
                        .staggeredAppearance(index: index + 3)
                }
            }
        }
    }

    // MARK: - Helper Components

    private var skeletonSectionHeader: some View {
        HStack(spacing: Spacing.sm) {
            skeletonCircle(size: 24)
            skeletonLine(widthFraction: 0.3, height: 20)
        }
    }

    private var statusCardSkeleton: some View {
        VStack(spacing: Spacing.xs) {
            skeletonCircle(size: 32)
            skeletonLine(widthFraction: 0.6, height: 14)
            skeletonLine(widthFraction: 0.4, height: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.md)
        .background(skeletonGradient.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    private var commentRowSkeleton: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            skeletonCircle(size: 36)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                skeletonLine(widthFraction: 0.4, height: 14)
                skeletonLine(widthFraction: 0.8, height: 12)
                skeletonLine(widthFraction: 0.6, height: 12)
            }
        }
        .padding(Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(Color.DesignSystem.glassBackground)
        )
    }

    private func detailRowsSkeleton(count: Int) -> some View {
        VStack(spacing: Spacing.sm) {
            ForEach(0..<count, id: \.self) { _ in
                HStack {
                    HStack(spacing: Spacing.sm) {
                        skeletonCircle(size: 32)
                        skeletonLine(widthFraction: 0.25, height: 14)
                    }
                    Spacer()
                    skeletonLine(widthFraction: 0.3, height: 14)
                }
            }
        }
    }

    private func sectionSkeleton<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                    )
            )
            .overlay(shimmerOverlay.clipShape(RoundedRectangle(cornerRadius: CornerRadius.large)))
    }

    // MARK: - Skeleton Shapes

    private func skeletonLine(widthFraction: CGFloat, height: CGFloat) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: height / 2)
                .fill(skeletonGradient)
                .frame(width: geo.size.width * widthFraction, height: height)
        }
        .frame(height: height)
    }

    private func skeletonPill(width: CGFloat) -> some View {
        Capsule()
            .fill(skeletonGradient)
            .frame(width: width, height: 28)
    }

    private func skeletonCircle(size: CGFloat) -> some View {
        Circle()
            .fill(skeletonGradient)
            .frame(width: size, height: size)
    }

    private func skeletonRect(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(skeletonGradient)
            .frame(height: height)
    }

    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.DesignSystem.textTertiary.opacity(0.3),
                Color.DesignSystem.textTertiary.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.1),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 150.0)
            .offset(x: shimmerPhase)
            .onAppear {
                shimmerPhase = -150
                withAnimation(
                    .linear(duration: 1.8)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerPhase = geometry.size.width + 150
                }
            }
        }
        .clipped()
    }
}

// MARK: - Preview

#Preview("Food Item Skeleton") {
    GlassDetailSkeleton(style: .foodItem)
        .background(Color.DesignSystem.background)
}

#Preview("Fridge Skeleton") {
    GlassDetailSkeleton(style: .communityFridge)
        .background(Color.DesignSystem.background)
}

#Preview("Forum Post Skeleton") {
    GlassDetailSkeleton(style: .forumPost, showImage: false)
        .background(Color.DesignSystem.background)
}

#endif
