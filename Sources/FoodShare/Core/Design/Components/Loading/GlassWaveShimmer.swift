import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Wave Shimmer

/// Premium skeleton loading effect with a coordinated wave sweep animation
/// Uses Canvas and TimelineView for 120Hz ProMotion performance
public struct GlassWaveShimmer: View {

    // MARK: - Properties

    let isActive: Bool
    let waveSpeed: Double
    let waveWidth: CGFloat
    let baseColor: Color
    let highlightColor: Color
    let cornerRadius: CGFloat

    @State private var waveOffset: CGFloat = -1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Initialization

    public init(
        isActive: Bool = true,
        waveSpeed: Double = 1.5,
        waveWidth: CGFloat = 0.3,
        baseColor: Color = Color.DesignSystem.glassBackground,
        highlightColor: Color = Color.white.opacity(0.4),
        cornerRadius: CGFloat = CornerRadius.medium,
    ) {
        self.isActive = isActive
        self.waveSpeed = waveSpeed
        self.waveWidth = waveWidth
        self.baseColor = baseColor
        self.highlightColor = highlightColor
        self.cornerRadius = cornerRadius
    }

    // MARK: - Body

    public var body: some View {
        GeometryReader { _ in
            if reduceMotion {
                // Fallback for reduced motion
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(baseColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(highlightColor.opacity(isActive ? 0.3 : 0)),
                    )
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: !isActive)) { timeline in
                    Canvas { context, size in
                        drawWaveShimmer(
                            context: context,
                            size: size,
                            date: timeline.date,
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
        }
    }

    // MARK: - Drawing

    private func drawWaveShimmer(
        context: GraphicsContext,
        size: CGSize,
        date: Date,
    ) {
        // Calculate wave position based on time
        let timeInterval = date.timeIntervalSinceReferenceDate
        let normalizedTime = (timeInterval * waveSpeed).truncatingRemainder(dividingBy: 2.0)
        let wavePosition = (normalizedTime - 0.5) * 2.0 // Range: -1 to 1

        // Draw base color
        let baseRect = CGRect(origin: .zero, size: size)
        context.fill(
            Path(roundedRect: baseRect, cornerRadius: cornerRadius),
            with: .color(baseColor),
        )

        // Calculate gradient positions
        let startX = (wavePosition - waveWidth) * size.width
        let endX = (wavePosition + waveWidth) * size.width

        // Create wave gradient
        let gradient = Gradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: highlightColor.opacity(0.1), location: 0.2),
            .init(color: highlightColor, location: 0.5),
            .init(color: highlightColor.opacity(0.1), location: 0.8),
            .init(color: .clear, location: 1)
        ])

        // Draw wave
        let waveRect = CGRect(
            x: startX,
            y: 0,
            width: endX - startX,
            height: size.height,
        )

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: startX, y: 0),
                endPoint: CGPoint(x: endX, y: 0),
            ),
        )
    }
}

// MARK: - Wave Shimmer Modifier

/// Modifier to apply wave shimmer effect to any view
public struct GlassWaveShimmerModifier: ViewModifier {
    let isActive: Bool
    let waveSpeed: Double
    let waveWidth: CGFloat

    public func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    GlassWaveShimmer(
                        isActive: isActive,
                        waveSpeed: waveSpeed,
                        waveWidth: waveWidth,
                    )
                }
            }
    }
}

extension View {
    /// Applies a wave shimmer effect overlay
    public func glassWaveShimmer(
        isActive: Bool = true,
        waveSpeed: Double = 1.5,
        waveWidth: CGFloat = 0.3,
    ) -> some View {
        modifier(GlassWaveShimmerModifier(
            isActive: isActive,
            waveSpeed: waveSpeed,
            waveWidth: waveWidth,
        ))
    }
}

// MARK: - Skeleton Wave Components

/// Skeleton line with wave shimmer
public struct SkeletonWaveLine: View {
    let width: CGFloat?
    let height: CGFloat

    public init(width: CGFloat? = nil, height: CGFloat = 16) {
        self.width = width
        self.height = height
    }

    public var body: some View {
        GlassWaveShimmer(cornerRadius: height / 2)
            .frame(width: width, height: height)
    }
}

/// Skeleton circle with wave shimmer
public struct SkeletonWaveCircle: View {
    let size: CGFloat

    public init(size: CGFloat = 48) {
        self.size = size
    }

    public var body: some View {
        GlassWaveShimmer(cornerRadius: size / 2)
            .frame(width: size, height: size)
    }
}

/// Skeleton rectangle with wave shimmer
public struct SkeletonWaveRect: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat

    public init(
        width: CGFloat? = nil,
        height: CGFloat = 100,
        cornerRadius: CGFloat = CornerRadius.medium,
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        GlassWaveShimmer(cornerRadius: cornerRadius)
            .frame(width: width, height: height)
    }
}

// MARK: - Coordinated Wave Shimmer Group

/// Container that coordinates wave shimmer timing across child elements
public struct CoordinatedWaveShimmerGroup<Content: View>: View {

    let waveSpeed: Double
    let waveWidth: CGFloat
    let staggerDelay: Double
    @ViewBuilder let content: () -> Content

    @State private var startTime = Date()

    public init(
        waveSpeed: Double = 1.5,
        waveWidth: CGFloat = 0.3,
        staggerDelay: Double = 0.1,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.waveSpeed = waveSpeed
        self.waveWidth = waveWidth
        self.staggerDelay = staggerDelay
        self.content = content
    }

    public var body: some View {
        content()
            .environment(\.shimmerStartTime, startTime)
    }
}

// MARK: - Environment Key

private struct ShimmerStartTimeKey: EnvironmentKey {
    static let defaultValue = Date()
}

extension EnvironmentValues {
    var shimmerStartTime: Date {
        get { self[ShimmerStartTimeKey.self] }
        set { self[ShimmerStartTimeKey.self] = newValue }
    }
}

// MARK: - Skeleton Card Presets

/// Skeleton for food item card with wave shimmer
public struct SkeletonWaveFoodCard: View {

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Image placeholder
            SkeletonWaveRect(height: 180, cornerRadius: CornerRadius.large)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Title
                SkeletonWaveLine(width: 150, height: 18)

                // Subtitle
                SkeletonWaveLine(width: 100, height: 14)

                // Bottom row
                HStack {
                    SkeletonWaveCircle(size: 24)
                    SkeletonWaveLine(width: 80, height: 12)
                    Spacer()
                    SkeletonWaveLine(width: 60, height: 14)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.bottom, Spacing.sm)
        }
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}

/// Skeleton for profile header with wave shimmer
public struct SkeletonWaveProfileHeader: View {

    public init() {}

    public var body: some View {
        VStack(spacing: Spacing.md) {
            // Avatar
            SkeletonWaveCircle(size: 80)

            // Name
            SkeletonWaveLine(width: 120, height: 20)

            // Bio
            VStack(spacing: Spacing.xs) {
                SkeletonWaveLine(height: 14)
                SkeletonWaveLine(width: 200, height: 14)
            }

            // Stats row
            HStack(spacing: Spacing.xl) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    VStack(spacing: Spacing.xs) {
                        SkeletonWaveLine(width: 40, height: 18)
                        SkeletonWaveLine(width: 50, height: 12)
                    }
                }
            }
        }
        .padding(Spacing.lg)
    }
}

/// Skeleton for message row with wave shimmer
public struct SkeletonWaveMessageRow: View {

    public init() {}

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            // Avatar
            SkeletonWaveCircle(size: 50)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                // Name and time
                HStack {
                    SkeletonWaveLine(width: 100, height: 16)
                    Spacer()
                    SkeletonWaveLine(width: 40, height: 12)
                }

                // Message preview
                SkeletonWaveLine(height: 14)
            }
        }
        .padding(Spacing.md)
    }
}

// MARK: - Preview

#Preview("Wave Shimmer") {
    VStack(spacing: Spacing.lg) {
        GlassWaveShimmer()
            .frame(height: 100)

        SkeletonWaveLine(width: 200)

        SkeletonWaveCircle()
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#Preview("Food Card Skeleton") {
    SkeletonWaveFoodCard()
        .padding()
        .background(Color.DesignSystem.background)
}

#Preview("Profile Header Skeleton") {
    SkeletonWaveProfileHeader()
        .background(Color.DesignSystem.background)
}
