//
//  GlassSkeletonView.swift
//  Foodshare
//
//  Liquid Glass v26 Skeleton Loading Views
//  Premium shimmer loading states with staggered animations
//


#if !SKIP
import SwiftUI

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
            .frame(width: 100.0)
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
            GlassSkeletonCard(style: .feedItem)
            GlassSkeletonCard(style: .profile)
            GlassSkeletonCard(style: .comment)
            GlassSkeletonCard(style: .forumPost)
            GlassSkeletonCard(style: .compact)
        }
        .padding()
    }
    .background(Color.DesignSystem.background)
}

#Preview("Skeleton List") {
    ScrollView {
        GlassSkeletonList(count: 5, style: .feedItem)
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
            GlassSkeletonList(count: 3, style: .compact)
        }
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#endif
