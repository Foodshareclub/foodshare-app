//
//  GlassRatingStars.swift
//  Foodshare
//
//  Liquid Glass v27 - Interactive Star Rating
//  ProMotion 120Hz optimized star rating with fluid fill animations
//


#if !SKIP
import SwiftUI

// MARK: - Glass Rating Stars

/// An interactive star rating component with fluid fill animations
///
/// Features:
/// - Smooth fill animation on tap/drag
/// - Half-star support
/// - Custom star count and size
/// - Read-only display mode
/// - Haptic feedback on selection
/// - Accessibility support
///
/// Example usage:
/// ```swift
/// // Interactive rating
/// GlassRatingStars(rating: $userRating)
///
/// // Read-only display
/// GlassRatingStars(rating: .constant(4.5), isInteractive: false)
///
/// // Custom styling
/// GlassRatingStars(
///     rating: $rating,
///     maxStars: 5,
///     starSize: 32,
///     fillColor: .DesignSystem.brandGreen,
///     allowHalfStars: true
/// )
/// ```
struct GlassRatingStars: View {
    @Binding var rating: Double
    let maxStars: Int
    let starSize: CGFloat
    let spacing: CGFloat
    let fillColor: Color
    let emptyColor: Color
    let isInteractive: Bool
    let allowHalfStars: Bool
    let showLabel: Bool

    @State private var highlightedRating: Double?
    @State private var animatingStars: Set<Int> = []

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    // MARK: - Initialization

    init(
        rating: Binding<Double>,
        maxStars: Int = 5,
        starSize: CGFloat = 24,
        spacing: CGFloat = 4,
        fillColor: Color = .yellow,
        emptyColor: Color = .DesignSystem.glassBorder,
        isInteractive: Bool = true,
        allowHalfStars: Bool = true,
        showLabel: Bool = false
    ) {
        self._rating = rating
        self.maxStars = maxStars
        self.starSize = starSize
        self.spacing = spacing
        self.fillColor = fillColor
        self.emptyColor = emptyColor
        self.isInteractive = isInteractive
        self.allowHalfStars = allowHalfStars
        self.showLabel = showLabel
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: spacing) {
            starsView

            if showLabel {
                Text(String(format: "%.1f", rating))
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.textPrimary)
                    #if !SKIP
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    #endif
            }
        }
        #if !SKIP
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                rating = min(Double(maxStars), rating + (allowHalfStars ? 0.5 : 1))
            case .decrement:
                rating = max(0.0, rating - (allowHalfStars ? 0.5 : 1))
            @unknown default:
                break
            }
        }
        #endif
    }

    // MARK: - Stars View

    @ViewBuilder
    private var starsView: some View {
        if isInteractive {
            interactiveStars
        } else {
            staticStars
        }
    }

    private var interactiveStars: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxStars, id: \.self) { index in
                starView(for: index)
                    .onTapGesture {
                        selectRating(Double(index))
                    }
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let starWidth = starSize + spacing
                    let newRating = calculateRating(from: value.location.x, starWidth: starWidth)
                    highlightedRating = newRating
                }
                .onEnded { value in
                    if let highlighted = highlightedRating {
                        selectRating(highlighted)
                    }
                    highlightedRating = nil
                }
        )
    }

    private var staticStars: some View {
        HStack(spacing: spacing) {
            ForEach(1...maxStars, id: \.self) { index in
                starView(for: index)
            }
        }
    }

    @ViewBuilder
    private func starView(for index: Int) -> some View {
        let displayRating = highlightedRating ?? rating
        let fillAmount = calculateFillAmount(for: index, rating: displayRating)
        let isAnimating = animatingStars.contains(index)

        ZStack {
            // Empty star background
            Image(systemName: "star.fill")
                .font(.system(size: starSize))
                .foregroundStyle(emptyColor)

            // Filled star with mask
            Image(systemName: "star.fill")
                .font(.system(size: starSize))
                .foregroundStyle(
                    LinearGradient(
                        colors: [fillColor, fillColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .mask(
                    GeometryReader { geometry in
                        Rectangle()
                            .frame(width: geometry.size.width * fillAmount)
                    }
                )
                .shadow(color: fillColor.opacity(fillAmount > 0 ? 0.4 : 0), radius: 4)
        }
        .scaleEffect(isAnimating ? 1.2 : 1.0)
        .animation(
            reduceMotion ? nil : .interpolatingSpring(stiffness: 400, damping: 15),
            value: isAnimating
        )
        .animation(
            reduceMotion ? nil : .interpolatingSpring(stiffness: 300, damping: 20),
            value: fillAmount
        )
    }

    // MARK: - Helpers

    private func calculateFillAmount(for index: Int, rating: Double) -> CGFloat {
        let starValue = Double(index)

        if rating >= starValue {
            return 1.0
        } else if rating > starValue - 1 {
            let partial = rating - (starValue - 1)
            return allowHalfStars ? min(1.0, partial) : (partial >= 0.5 ? 1.0 : 0.0)
        } else {
            return 0.0
        }
    }

    private func calculateRating(from xPosition: CGFloat, starWidth: CGFloat) -> Double {
        let rawIndex = xPosition / starWidth
        let starIndex = Int(rawIndex) + 1
        let fractionalPart = rawIndex.truncatingRemainder(dividingBy: 1)

        let clampedIndex = max(1, min(maxStars, starIndex))

        if allowHalfStars {
            let halfValue = fractionalPart < 0.5 ? 0.5 : 1.0
            return Double(clampedIndex - 1) + halfValue
        } else {
            return Double(clampedIndex)
        }
    }

    private func selectRating(_ newRating: Double) {
        // Haptic feedback
        #if !SKIP
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif

        // Animate the selected star
        let starIndex = Int(ceil(newRating))
        if !reduceMotion {
            animatingStars.insert(starIndex)

            Task { @MainActor in
                #if SKIP
                try? await Task.sleep(nanoseconds: UInt64(150 * 1_000_000))
                #else
                try? await Task.sleep(for: .milliseconds(150))
                #endif
                animatingStars.remove(starIndex)
            }
        }

        // Update rating with animation
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            rating = newRating
        }
    }

    private var accessibilityLabel: String {
        isInteractive ? "Rating, adjustable" : "Rating"
    }

    private var accessibilityValue: String {
        if allowHalfStars {
            return String(format: "%.1f out of %d stars", rating, maxStars)
        } else {
            return "\(Int(rating)) out of \(maxStars) stars"
        }
    }
}

// MARK: - Compact Rating Display

/// A compact rating display with star icon and number
struct GlassRatingBadge: View {
    let rating: Double
    let reviewCount: Int?
    let size: Size

    enum Size {
        case small
        case medium
        case large

        var iconSize: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 14
            case .large: return 18
            }
        }

        var font: Font {
            switch self {
            case .small: return .DesignSystem.captionSmall
            case .medium: return .DesignSystem.caption
            case .large: return .DesignSystem.bodyMedium
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return Spacing.xxxs
            case .medium: return Spacing.xxs
            case .large: return Spacing.xs
            }
        }
    }

    init(rating: Double, reviewCount: Int? = nil, size: Size = .medium) {
        self.rating = rating
        self.reviewCount = reviewCount
        self.size = size
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .font(.system(size: size.iconSize))
                .foregroundStyle(.yellow)

            Text(String(format: "%.1f", rating))
                .font(size.font)
                .fontWeight(.medium)
                .foregroundStyle(Color.DesignSystem.textPrimary)

            if let count = reviewCount {
                Text("(\(count))")
                    .font(size.font)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
        .padding(.horizontal, size.padding * 2)
        .padding(.vertical, size.padding)
        .background(
            Capsule()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }
}

// MARK: - Rating Summary View

/// A comprehensive rating summary with average, distribution bars, and count
struct GlassRatingSummary: View {
    let averageRating: Double
    let totalReviews: Int
    let distribution: [Int: Int] // Star level (1-5) -> count

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.lg) {
            // Left: Average rating
            VStack(spacing: Spacing.xs) {
                Text(String(format: "%.1f", averageRating))
                    .font(.DesignSystem.displayLarge)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                GlassRatingStars(
                    rating: .constant(averageRating),
                    starSize: 16,
                    spacing: 2,
                    isInteractive: false,
                    showLabel: false
                )

                Text("\(totalReviews) reviews")
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            // Right: Distribution bars
            VStack(spacing: Spacing.xxs) {
                ForEach((1...5).reversed(), id: \.self) { stars in
                    distributionBar(for: stars)
                }
            }
        }
        .padding(Spacing.md)
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
    }

    @ViewBuilder
    private func distributionBar(for stars: Int) -> some View {
        let count = distribution[stars] ?? 0
        let percentage = totalReviews > 0 ? Double(count) / Double(totalReviews) : 0

        HStack(spacing: Spacing.xs) {
            Text("\(stars)")
                .font(.DesignSystem.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .frame(width: 12.0)

            Image(systemName: "star.fill")
                .font(.system(size: 10))
                .foregroundStyle(.yellow.opacity(0.7))

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.DesignSystem.glassBorder)

                    // Fill bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * percentage)
                }
            }
            .frame(height: 8.0)

            Text("\(count)")
                .font(.DesignSystem.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .frame(width: 30.0, alignment: .trailing)
        }
    }
}

// MARK: - Preview

#Preview("Glass Rating Stars") {
    struct PreviewWrapper: View {
        @State private var rating1: Double = 3.5
        @State private var rating2: Double = 4.0
        @State private var rating3: Double = 2.5

        var body: some View {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Text("Glass Rating Stars")
                        .font(.DesignSystem.displayMedium)
                        .foregroundStyle(Color.DesignSystem.textPrimary)

                    // Interactive rating
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Interactive Rating")
                            .font(.DesignSystem.headlineSmall)

                        GlassRatingStars(rating: $rating1, showLabel: true)

                        Text("Drag or tap to rate")
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    // Static ratings
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Read-Only Ratings")
                            .font(.DesignSystem.headlineSmall)

                        HStack(spacing: Spacing.lg) {
                            GlassRatingStars(
                                rating: .constant(5.0),
                                starSize: 16,
                                isInteractive: false
                            )

                            GlassRatingStars(
                                rating: .constant(4.5),
                                starSize: 16,
                                isInteractive: false
                            )

                            GlassRatingStars(
                                rating: .constant(3.0),
                                starSize: 16,
                                isInteractive: false
                            )
                        }
                    }

                    // Rating badges
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Rating Badges")
                            .font(.DesignSystem.headlineSmall)

                        HStack(spacing: Spacing.md) {
                            GlassRatingBadge(rating: 4.8, reviewCount: 156, size: .small)
                            GlassRatingBadge(rating: 4.2, reviewCount: 42, size: .medium)
                            GlassRatingBadge(rating: 3.9, size: .large)
                        }
                    }

                    // Custom colors
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Custom Colors")
                            .font(.DesignSystem.headlineSmall)

                        GlassRatingStars(
                            rating: $rating2,
                            fillColor: .DesignSystem.brandGreen,
                            showLabel: true
                        )

                        GlassRatingStars(
                            rating: $rating3,
                            fillColor: .DesignSystem.brandPink,
                            showLabel: true
                        )
                    }

                    // Rating summary
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Rating Summary")
                            .font(.DesignSystem.headlineSmall)

                        GlassRatingSummary(
                            averageRating: 4.3,
                            totalReviews: 1247,
                            distribution: [
                                5: 782,
                                4: 312,
                                3: 98,
                                2: 35,
                                1: 20
                            ]
                        )
                    }
                }
                .padding()
            }
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewWrapper()
}

#endif
