//
//  GlassSkeletonView.swift
//  Foodshare
//
//  Liquid Glass v26 Skeleton Loading Views
//  Premium shimmer loading states with staggered animations
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Skeleton Modifier

struct GlassSkeletonModifier: ViewModifier {
    let isLoading: Bool
    let cornerRadius: CGFloat

    @State private var shimmerOffset: CGFloat = -200

    func body(content: Content) -> some View {
        if isLoading {
            content
                .redacted(reason: .placeholder)
                .overlay(
                    shimmerOverlay
                        .mask(content)
                )
                .allowsHitTesting(false)
        } else {
            content
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.4),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 100)
            .offset(x: shimmerOffset)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerOffset = geometry.size.width + 100
                }
            }
        }
        .clipped()
    }
}

extension View {
    func glassSkeleton(isLoading: Bool, cornerRadius: CGFloat = CornerRadius.medium) -> some View {
        modifier(GlassSkeletonModifier(isLoading: isLoading, cornerRadius: cornerRadius))
    }
}

// MARK: - Skeleton Card

struct GlassSkeletonCard: View {
    let style: SkeletonStyle

    enum SkeletonStyle {
        case listingCard
        case profileCard
        case messageRow
        case activityItem
        case compact
    }

    @State private var shimmerPhase: CGFloat = 0

    var body: some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.glassBackground,
                                    Color.DesignSystem.glassBackground.opacity(0.5)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.DesignSystem.glassBorder.opacity(0.5), lineWidth: 1)
            )
            .overlay(shimmerOverlay)
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .listingCard, .profileCard:
            return CornerRadius.large
        case .messageRow, .activityItem:
            return CornerRadius.medium
        case .compact:
            return CornerRadius.small
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var content: some View {
        switch style {
        case .listingCard:
            listingCardSkeleton
        case .profileCard:
            profileCardSkeleton
        case .messageRow:
            messageRowSkeleton
        case .activityItem:
            activityItemSkeleton
        case .compact:
            compactSkeleton
        }
    }

    private var listingCardSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image placeholder
            Rectangle()
                .fill(skeletonGradient)
                .frame(height: 160)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title
                skeletonLine(width: 0.7)

                // Subtitle
                skeletonLine(width: 0.5, height: 14)

                HStack {
                    // Badge
                    skeletonPill(width: 60)

                    Spacer()

                    // Distance
                    skeletonLine(width: 40, height: 12)
                }
            }
            .padding(Spacing.md)
        }
    }

    private var profileCardSkeleton: some View {
        HStack(spacing: Spacing.md) {
            // Avatar
            Circle()
                .fill(skeletonGradient)
                .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                skeletonLine(width: 120)
                skeletonLine(width: 80, height: 14)
            }

            Spacer()

            // Stats
            VStack(spacing: Spacing.xxs) {
                skeletonLine(width: 30, height: 20)
                skeletonLine(width: 40, height: 12)
            }
        }
        .padding(Spacing.md)
    }

    private var messageRowSkeleton: some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            Circle()
                .fill(skeletonGradient)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                skeletonLine(width: 100)
                skeletonLine(width: 180, height: 14)
            }

            Spacer()

            // Time
            skeletonLine(width: 40, height: 12)
        }
        .padding(Spacing.md)
    }

    private var activityItemSkeleton: some View {
        HStack(spacing: Spacing.sm) {
            // Icon
            Circle()
                .fill(skeletonGradient)
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                skeletonLine(width: 150)
                skeletonLine(width: 100, height: 12)
            }

            Spacer()
        }
        .padding(Spacing.sm)
    }

    private var compactSkeleton: some View {
        HStack(spacing: Spacing.sm) {
            RoundedRectangle(cornerRadius: CornerRadius.small)
                .fill(skeletonGradient)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                skeletonLine(width: 80)
                skeletonLine(width: 60, height: 12)
            }
        }
        .padding(Spacing.sm)
    }

    // MARK: - Helper Views

    private func skeletonLine(width: CGFloat, height: CGFloat = 16) -> some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(skeletonGradient)
            .frame(width: width, height: height)
    }

    private func skeletonLine(width: Double, height: CGFloat = 16) -> some View {
        GeometryReader { geo in
            RoundedRectangle(cornerRadius: height / 2)
                .fill(skeletonGradient)
                .frame(width: geo.size.width * width, height: height)
        }
        .frame(height: height)
    }

    private func skeletonPill(width: CGFloat) -> some View {
        Capsule()
            .fill(skeletonGradient)
            .frame(width: width, height: 24)
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

    // MARK: - Shimmer Overlay

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.15),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 150)
            .offset(x: shimmerPhase)
            .onAppear {
                shimmerPhase = -150
                withAnimation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerPhase = geometry.size.width + 150
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

// MARK: - Skeleton List

struct GlassSkeletonList: View {
    let count: Int
    let style: GlassSkeletonCard.SkeletonStyle
    let spacing: CGFloat

    init(
        count: Int = 5,
        style: GlassSkeletonCard.SkeletonStyle = .listingCard,
        spacing: CGFloat = Spacing.md
    ) {
        self.count = count
        self.style = style
        self.spacing = spacing
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { index in
                GlassSkeletonCard(style: style)
                    .staggeredAppearance(index: index)
            }
        }
    }
}

// MARK: - Skeleton Grid

struct GlassSkeletonGrid: View {
    let columns: Int
    let rows: Int
    let spacing: CGFloat

    init(columns: Int = 2, rows: Int = 3, spacing: CGFloat = Spacing.md) {
        self.columns = columns
        self.rows = rows
        self.spacing = spacing
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            ForEach(0..<(columns * rows), id: \.self) { index in
                GlassSkeletonCard(style: .compact)
                    .staggeredAppearance(index: index)
            }
        }
    }
}

// MARK: - Conditional Skeleton

struct GlassConditionalSkeleton<Content: View, Skeleton: View>: View {
    let isLoading: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let skeleton: () -> Skeleton

    var body: some View {
        if isLoading {
            skeleton()
        } else {
            content()
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
        }
    }
}

// MARK: - Previews

#Preview("Skeleton Cards") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            GlassSkeletonCard(style: .listingCard)
            GlassSkeletonCard(style: .profileCard)
            GlassSkeletonCard(style: .messageRow)
            GlassSkeletonCard(style: .activityItem)
            GlassSkeletonCard(style: .compact)
        }
        .padding()
    }
    .background(Color.DesignSystem.background)
}

#Preview("Skeleton List") {
    ScrollView {
        GlassSkeletonList(count: 5, style: .listingCard)
            .padding()
    }
    .background(
        LinearGradient(
            colors: [Color.DesignSystem.accentBlue.opacity(0.2), Color.DesignSystem.background],
            startPoint: .top,
            endPoint: .bottom
        )
    )
}

#Preview("Skeleton Grid") {
    ScrollView {
        GlassSkeletonGrid(columns: 2, rows: 4)
            .padding()
    }
    .background(Color.DesignSystem.background)
}

#Preview("Loading State Transition") {
    @Previewable @State var isLoading = true

    VStack(spacing: Spacing.lg) {
        Button(isLoading ? "Show Content" : "Show Loading") {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                isLoading.toggle()
            }
        }
        .buttonStyle(.borderedProminent)

        GlassConditionalSkeleton(isLoading: isLoading) {
            VStack(spacing: Spacing.md) {
                ForEach(0..<3, id: \.self) { index in
                    GlassInfoCard(
                        icon: "star.fill",
                        title: "Item \(index + 1)",
                        subtitle: "Real content loaded"
                    )
                }
            }
        } skeleton: {
            GlassSkeletonList(count: 3, style: .activityItem)
        }
    }
    .padding()
    .background(Color.DesignSystem.background)
}
