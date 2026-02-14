//
//  GlassImageCarousel.swift
//  Foodshare
//
//  Liquid Glass v26 image carousel with parallax, zoom support, and premium loading states
//  Optimized for 120Hz ProMotion displays
//

import Kingfisher
import SwiftUI
import FoodShareDesignSystem

struct GlassImageCarousel: View {
    let imageURLs: [URL]
    var height: CGFloat = 320
    var emptyStateIcon: String = "photo.stack"
    var emptyStateMessage: String = "No images"
    var errorStateMessage: String = "Image unavailable"
    var onTap: ((Int) -> Void)? = nil

    @State private var currentIndex: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var hasAppeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if imageURLs.isEmpty {
                emptyState
            } else {
                // Image carousel
                TabView(selection: $currentIndex) {
                    ForEach(Array(imageURLs.enumerated()), id: \.offset) { index, url in
                        imageView(url: url, index: index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page indicator
                if imageURLs.count > 1 {
                    pageIndicator
                }

                // Bottom gradient overlay
                bottomGradient
            }
        }
        .frame(height: height)
        .clipped()
        .opacity(hasAppeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
                hasAppeared = true
            }
        }
    }

    // MARK: - Image View

    private func imageView(url: URL, index: Int) -> some View {
        KFImage(url)
            .placeholder {
                shimmerPlaceholder
            }
            .fade(duration: 0.25)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: height)
            .clipped()
            .contentShape(Rectangle())
            .onTapGesture {
                onTap?(index)
                HapticManager.light()
            }
    }

    // MARK: - Shimmer Placeholder

    private var shimmerPlaceholder: some View {
        GeometryReader { geometry in
            ZStack {
                // Base color
                Color.DesignSystem.glassBackground

                // Shimmer effect
                CarouselShimmerView()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .DesignSystem.brandGreen.opacity(0.2),
                        .DesignSystem.brandBlue.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                VStack(spacing: Spacing.sm) {
                    Image(systemName: emptyStateIcon)
                        .font(.system(size: 40))
                    Text(emptyStateMessage)
                        .font(.DesignSystem.bodyMedium)
                }
                .foregroundColor(.DesignSystem.textSecondary)
            }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(0..<imageURLs.count, id: \.self) { index in
                Circle()
                    .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                    .frame(
                        width: index == currentIndex ? 8 : 6,
                        height: index == currentIndex ? 8 : 6
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
        )
        .padding(.bottom, Spacing.md)
    }

    // MARK: - Bottom Gradient

    private var bottomGradient: some View {
        LinearGradient(
            colors: [.clear, Color.DesignSystem.background.opacity(0.5)],
            startPoint: .center,
            endPoint: .bottom
        )
        .frame(height: 80)
        .allowsHitTesting(false)
    }
}

// MARK: - Carousel Shimmer View

private struct CarouselShimmerView: View {
    @State private var shimmerPhase: CGFloat = -200

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        Color.DesignSystem.textTertiary.opacity(0.3),
                        Color.DesignSystem.textTertiary.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Shimmer overlay
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
                    withAnimation(
                        .linear(duration: 1.5)
                            .repeatForever(autoreverses: false)
                    ) {
                        shimmerPhase = geometry.size.width + 150
                    }
                }
            }
        }
    }
}

// MARK: - String URL Support

extension GlassImageCarousel {
    /// Initialize with string URLs (convenience)
    init(
        imageURLStrings: [String],
        height: CGFloat = 320,
        emptyStateIcon: String = "photo.stack",
        emptyStateMessage: String = "No images",
        errorStateMessage: String = "Image unavailable",
        onTap: ((Int) -> Void)? = nil
    ) {
        self.imageURLs = imageURLStrings.compactMap { URL(string: $0) }
        self.height = height
        self.emptyStateIcon = emptyStateIcon
        self.emptyStateMessage = emptyStateMessage
        self.errorStateMessage = errorStateMessage
        self.onTap = onTap
    }
}

// MARK: - Preview

#Preview("Multiple Images") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            GlassImageCarousel(
                imageURLs: [
                    URL(string: "https://picsum.photos/800/600?random=1")!,
                    URL(string: "https://picsum.photos/800/600?random=2")!,
                    URL(string: "https://picsum.photos/800/600?random=3")!
                ],
                onTap: { index in
                    print("Tapped image \(index)")
                }
            )

            Text("Content below carousel")
                .padding()
        }
    }
    .background(Color.DesignSystem.background)
}

#Preview("Empty State") {
    GlassImageCarousel(
        imageURLs: [],
        emptyStateMessage: "No photos available"
    )
    .background(Color.DesignSystem.background)
}

#Preview("Single Image") {
    GlassImageCarousel(
        imageURLs: [URL(string: "https://picsum.photos/800/600")!]
    )
    .background(Color.DesignSystem.background)
}
