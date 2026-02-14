//
//  GlassCarousel.swift
//  Foodshare
//
//  Liquid Glass v27 - Paged Carousel with Parallax
//  ProMotion 120Hz optimized horizontal paging with parallax effects
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Carousel

/// A paged carousel with parallax effects and page indicators
///
/// Features:
/// - Smooth paging with spring physics
/// - Parallax effect on card content
/// - Glass-styled page indicators
/// - Auto-advance option
/// - Peek at adjacent cards
/// - Haptic feedback on page change
///
/// Example usage:
/// ```swift
/// GlassCarousel(items: featuredItems) { item in
///     FeaturedItemCard(item: item)
/// }
///
/// GlassCarousel(
///     items: promotions,
///     autoAdvanceInterval: 5.0,
///     showIndicators: true
/// ) { promo in
///     PromotionCard(promo: promo)
/// }
/// ```
struct GlassCarousel<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let spacing: CGFloat
    let peekAmount: CGFloat
    let autoAdvanceInterval: Double?
    let showIndicators: Bool
    let parallaxIntensity: CGFloat
    let onPageChange: ((Int) -> Void)?
    @ViewBuilder let content: (Item) -> Content

    @State private var currentPage: Int = 0
    @State private var dragOffset: CGFloat = 0
    @State private var autoAdvanceTimer: Timer?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initialization

    init(
        items: [Item],
        spacing: CGFloat = Spacing.md,
        peekAmount: CGFloat = 20,
        autoAdvanceInterval: Double? = nil,
        showIndicators: Bool = true,
        parallaxIntensity: CGFloat = 0.3,
        onPageChange: ((Int) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.spacing = spacing
        self.peekAmount = peekAmount
        self.autoAdvanceInterval = autoAdvanceInterval
        self.showIndicators = showIndicators
        self.parallaxIntensity = parallaxIntensity
        self.onPageChange = onPageChange
        self.content = content
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width - (peekAmount * 2) - spacing
            let cardHeight = geometry.size.height - (showIndicators ? 30 : 0)

            VStack(spacing: Spacing.sm) {
                // Carousel
                ZStack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        cardView(
                            for: item,
                            at: index,
                            cardWidth: cardWidth,
                            cardHeight: cardHeight,
                            totalWidth: geometry.size.width
                        )
                    }
                }
                .frame(height: cardHeight)
                .gesture(dragGesture(cardWidth: cardWidth))

                // Page indicators
                if showIndicators && items.count > 1 {
                    pageIndicators
                }
            }
        }
        .onAppear {
            startAutoAdvanceIfNeeded()
        }
        .onDisappear {
            stopAutoAdvance()
        }
    }

    // MARK: - Card View

    @ViewBuilder
    private func cardView(
        for item: Item,
        at index: Int,
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        totalWidth: CGFloat
    ) -> some View {
        let offset = calculateOffset(for: index, cardWidth: cardWidth)
        let scale = calculateScale(for: index, cardWidth: cardWidth)
        let parallaxOffset = calculateParallaxOffset(for: index, cardWidth: cardWidth)

        content(item)
            .frame(width: cardWidth, height: cardHeight)
            .offset(x: parallaxOffset * parallaxIntensity)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .scaleEffect(scale)
            .offset(x: offset)
            .zIndex(index == currentPage ? 1 : 0)
            .animation(
                reduceMotion ? nil : .interpolatingSpring(stiffness: 200, damping: 22),
                value: currentPage
            )
            .animation(
                reduceMotion ? nil : .interpolatingSpring(stiffness: 300, damping: 25),
                value: dragOffset
            )
    }

    // MARK: - Calculations

    private func calculateOffset(for index: Int, cardWidth: CGFloat) -> CGFloat {
        let baseOffset = CGFloat(index - currentPage) * (cardWidth + spacing)
        return baseOffset + dragOffset + peekAmount
    }

    private func calculateScale(for index: Int, cardWidth: CGFloat) -> CGFloat {
        let distance = abs(CGFloat(index - currentPage) + dragOffset / cardWidth)
        let scale = 1.0 - (distance * 0.05)
        return max(0.9, min(1.0, scale))
    }

    private func calculateParallaxOffset(for index: Int, cardWidth: CGFloat) -> CGFloat {
        let normalizedOffset = CGFloat(index - currentPage) + dragOffset / cardWidth
        return normalizedOffset * cardWidth * 0.5
    }

    // MARK: - Gestures

    private func dragGesture(cardWidth: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { value in
                stopAutoAdvance()
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let threshold = cardWidth * 0.3
                let predictedOffset = value.predictedEndTranslation.width

                var newPage = currentPage

                if predictedOffset < -threshold && currentPage < items.count - 1 {
                    newPage = currentPage + 1
                } else if predictedOffset > threshold && currentPage > 0 {
                    newPage = currentPage - 1
                }

                // Haptic feedback
                if newPage != currentPage {
                    #if os(iOS)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                }

                withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) {
                    currentPage = newPage
                    dragOffset = 0
                }

                onPageChange?(newPage)
                startAutoAdvanceIfNeeded()
            }
    }

    // MARK: - Page Indicators

    private var pageIndicators: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(0..<items.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.DesignSystem.brandGreen : Color.DesignSystem.glassBorder)
                    .frame(
                        width: index == currentPage ? 20 : 8,
                        height: 8
                    )
                    .animation(
                        reduceMotion ? nil : .interpolatingSpring(stiffness: 300, damping: 25),
                        value: currentPage
                    )
            }
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.md)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Auto Advance

    private func startAutoAdvanceIfNeeded() {
        guard let interval = autoAdvanceInterval, items.count > 1 else { return }

        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) {
                currentPage = (currentPage + 1) % items.count
            }
            onPageChange?(currentPage)
        }
    }

    private func stopAutoAdvance() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
    }
}

// MARK: - Glass Carousel Card

/// A styled card wrapper for carousel items
struct GlassCarouselCard<Content: View>: View {
    let gradient: Gradient?
    @ViewBuilder let content: () -> Content

    init(
        gradient: Gradient? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.gradient = gradient
        self.content = content
    }

    var body: some View {
        ZStack {
            // Background
            if let gradient {
                LinearGradient(
                    gradient: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.DesignSystem.glassBackground
                    .background(.ultraThinMaterial)
            }

            // Content
            content()
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.DesignSystem.glassBorder,
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 15, y: 8)
    }
}

// MARK: - Featured Card Example

/// Example featured card for carousel
struct GlassFeaturedCard: View {
    let title: String
    let subtitle: String
    let imageURL: URL?
    let gradient: Gradient

    var body: some View {
        GlassCarouselCard(gradient: gradient) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Spacer()

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.DesignSystem.headlineLarge)
                        .foregroundStyle(.white)

                    Text(subtitle)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(Spacing.lg)
            }
        }
    }
}

// MARK: - Preview

#Preview("Glass Carousel") {
    struct PreviewItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let gradient: Gradient
    }

    struct PreviewWrapper: View {
        let items: [PreviewItem] = [
            PreviewItem(
                title: "Fresh Produce",
                subtitle: "Organic vegetables available now",
                gradient: Gradient(colors: [.green.opacity(0.8), .teal.opacity(0.8)])
            ),
            PreviewItem(
                title: "Bakery Items",
                subtitle: "Fresh bread and pastries",
                gradient: Gradient(colors: [.orange.opacity(0.8), .red.opacity(0.8)])
            ),
            PreviewItem(
                title: "Dairy Products",
                subtitle: "Milk, cheese, and more",
                gradient: Gradient(colors: [.blue.opacity(0.8), .purple.opacity(0.8)])
            ),
            PreviewItem(
                title: "Prepared Meals",
                subtitle: "Ready-to-eat dishes",
                gradient: Gradient(colors: [.pink.opacity(0.8), .orange.opacity(0.8)])
            )
        ]

        var body: some View {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Text("Glass Carousel")
                        .font(.DesignSystem.displayMedium)
                        .foregroundStyle(Color.DesignSystem.textPrimary)

                    // Standard carousel
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Featured")
                            .font(.DesignSystem.headlineSmall)
                            .padding(.horizontal, Spacing.md)

                        GlassCarousel(items: items) { item in
                            GlassFeaturedCard(
                                title: item.title,
                                subtitle: item.subtitle,
                                imageURL: nil,
                                gradient: item.gradient
                            )
                        }
                        .frame(height: 200)
                    }

                    // Auto-advancing carousel
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Promotions (Auto-Advance)")
                            .font(.DesignSystem.headlineSmall)
                            .padding(.horizontal, Spacing.md)

                        GlassCarousel(
                            items: items,
                            autoAdvanceInterval: 4.0,
                            parallaxIntensity: 0.5
                        ) { item in
                            GlassFeaturedCard(
                                title: item.title,
                                subtitle: item.subtitle,
                                imageURL: nil,
                                gradient: item.gradient
                            )
                        }
                        .frame(height: 180)
                    }

                    // No indicators
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Without Indicators")
                            .font(.DesignSystem.headlineSmall)
                            .padding(.horizontal, Spacing.md)

                        GlassCarousel(
                            items: items,
                            peekAmount: 40,
                            showIndicators: false
                        ) { item in
                            GlassFeaturedCard(
                                title: item.title,
                                subtitle: item.subtitle,
                                imageURL: nil,
                                gradient: item.gradient
                            )
                        }
                        .frame(height: 150)
                    }
                }
                .padding(.vertical, Spacing.lg)
            }
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewWrapper()
}
