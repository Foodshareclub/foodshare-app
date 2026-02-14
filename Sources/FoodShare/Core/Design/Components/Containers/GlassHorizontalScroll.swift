//
//  GlassHorizontalScroll.swift
//  Foodshare
//
//  Reusable horizontal scroll component with snap behavior and scroll tracking
//  Replaces 20+ duplicate ScrollView(.horizontal) + HStack patterns
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - GlassHorizontalScroll

/// A unified horizontal scroll component with optional snap behavior and scroll offset tracking
/// Designed for 120fps ProMotion animations and accessibility support
struct GlassHorizontalScroll<Content: View>: View {
    let spacing: CGFloat
    let padding: CGFloat
    let showsIndicators: Bool
    let enableSnapBehavior: Bool
    let snapAlignment: Alignment
    let onScrollOffsetChange: ((CGFloat) -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var scrollOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initialization

    /// Creates a new GlassHorizontalScroll
    /// - Parameters:
    ///   - spacing: Spacing between items (default: Spacing.md)
    ///   - padding: Horizontal padding (default: Spacing.md)
    ///   - showsIndicators: Whether to show scroll indicators (default: false)
    ///   - enableSnapBehavior: Whether items snap to position (default: false)
    ///   - snapAlignment: Alignment for snap behavior (default: .center)
    ///   - onScrollOffsetChange: Callback when scroll offset changes
    ///   - content: The content builder
    init(
        spacing: CGFloat = Spacing.md,
        padding: CGFloat = Spacing.md,
        showsIndicators: Bool = false,
        enableSnapBehavior: Bool = false,
        snapAlignment: Alignment = .center,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.padding = padding
        self.showsIndicators = showsIndicators
        self.enableSnapBehavior = enableSnapBehavior
        self.snapAlignment = snapAlignment
        self.onScrollOffsetChange = onScrollOffsetChange
        self.content = content
    }

    var body: some View {
        if enableSnapBehavior {
            snapScrollView
        } else {
            standardScrollView
        }
    }

    // MARK: - Standard Scroll View

    private var standardScrollView: some View {
        ScrollView(.horizontal, showsIndicators: showsIndicators) {
            HStack(spacing: spacing) {
                content()
            }
            .padding(.horizontal, padding)
            .background(scrollOffsetReader)
        }
        .onChange(of: scrollOffset) { _, newValue in
            onScrollOffsetChange?(newValue)
        }
    }

    // MARK: - Snap Scroll View

    private var snapScrollView: some View {
        ScrollView(.horizontal, showsIndicators: showsIndicators) {
            HStack(spacing: spacing) {
                content()
            }
            .padding(.horizontal, padding)
            .scrollTargetLayout()
            .background(scrollOffsetReader)
        }
        .scrollTargetBehavior(.viewAligned)
        .onChange(of: scrollOffset) { _, newValue in
            onScrollOffsetChange?(newValue)
        }
    }

    // MARK: - Scroll Offset Reader

    private var scrollOffsetReader: some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: ScrollOffsetPreferenceKey.self,
                value: proxy.frame(in: .named("scroll")).minX
            )
        }
        .frame(height: 0)
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = -value
        }
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Convenience Initializers

extension GlassHorizontalScroll {
    /// Creates a compact horizontal scroll (smaller spacing and padding)
    static func compact(
        showsIndicators: Bool = false,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> GlassHorizontalScroll {
        GlassHorizontalScroll(
            spacing: Spacing.sm,
            padding: Spacing.sm,
            showsIndicators: showsIndicators,
            onScrollOffsetChange: onScrollOffsetChange,
            content: content
        )
    }

    /// Creates a snapping horizontal scroll for card carousels
    static func carousel(
        spacing: CGFloat = Spacing.md,
        padding: CGFloat = Spacing.md,
        onScrollOffsetChange: ((CGFloat) -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> GlassHorizontalScroll {
        GlassHorizontalScroll(
            spacing: spacing,
            padding: padding,
            showsIndicators: false,
            enableSnapBehavior: true,
            onScrollOffsetChange: onScrollOffsetChange,
            content: content
        )
    }
}

// MARK: - GlassHorizontalScroll with Header

/// A horizontal scroll section with a header
struct GlassHorizontalScrollSection<Header: View, Content: View>: View {
    let spacing: CGFloat
    let padding: CGFloat
    let showsIndicators: Bool
    let enableSnapBehavior: Bool
    @ViewBuilder let header: () -> Header
    @ViewBuilder let content: () -> Content

    init(
        spacing: CGFloat = Spacing.md,
        padding: CGFloat = Spacing.md,
        showsIndicators: Bool = false,
        enableSnapBehavior: Bool = false,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.spacing = spacing
        self.padding = padding
        self.showsIndicators = showsIndicators
        self.enableSnapBehavior = enableSnapBehavior
        self.header = header
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header()
                .padding(.horizontal, padding)

            GlassHorizontalScroll(
                spacing: spacing,
                padding: padding,
                showsIndicators: showsIndicators,
                enableSnapBehavior: enableSnapBehavior,
                content: content
            )
        }
    }
}

// MARK: - Preview

#Preview("GlassHorizontalScroll") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            // Standard horizontal scroll
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Standard Scroll")
                    .font(.DesignSystem.labelLarge)
                    .foregroundColor(.DesignSystem.text)
                    .padding(.horizontal, Spacing.md)

                GlassHorizontalScroll {
                    ForEach(0..<10) { index in
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .fill(Color.DesignSystem.brandGreen.opacity(0.3))
                            .frame(width: 120, height: 80)
                            .overlay(
                                Text("Item \(index)")
                                    .font(.DesignSystem.labelMedium)
                                    .foregroundColor(.DesignSystem.text)
                            )
                    }
                }
            }

            // Compact scroll
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Compact Scroll")
                    .font(.DesignSystem.labelLarge)
                    .foregroundColor(.DesignSystem.text)
                    .padding(.horizontal, Spacing.md)

                GlassHorizontalScroll.compact {
                    ForEach(0..<10) { index in
                        Capsule()
                            .fill(Color.DesignSystem.brandBlue.opacity(0.3))
                            .frame(width: 80, height: 32)
                            .overlay(
                                Text("Tag \(index)")
                                    .font(.DesignSystem.caption)
                                    .foregroundColor(.DesignSystem.text)
                            )
                    }
                }
            }

            // Carousel scroll with snap
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Carousel (Snap)")
                    .font(.DesignSystem.labelLarge)
                    .foregroundColor(.DesignSystem.text)
                    .padding(.horizontal, Spacing.md)

                GlassHorizontalScroll.carousel {
                    ForEach(0..<5) { index in
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 280, height: 160)
                            .overlay(
                                Text("Card \(index)")
                                    .font(.DesignSystem.headlineMedium)
                                    .foregroundColor(.white)
                            )
                    }
                }
            }

            // Section with header
            GlassHorizontalScrollSection {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("Trending")
                        .font(.DesignSystem.labelLarge)
                        .foregroundColor(.DesignSystem.text)
                    Spacer()
                    Text("See All")
                        .font(.DesignSystem.labelSmall)
                        .foregroundColor(.DesignSystem.brandGreen)
                }
            } content: {
                ForEach(0..<8) { index in
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.orange.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay(
                            VStack {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                Text("\(index + 1)")
                                    .font(.DesignSystem.labelMedium)
                                    .foregroundColor(.DesignSystem.text)
                            }
                        )
                }
            }
        }
        .padding(.vertical, Spacing.md)
    }
    .background(Color.DesignSystem.background)
}
