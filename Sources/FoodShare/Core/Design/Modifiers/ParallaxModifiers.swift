//
//  ParallaxModifiers.swift
//  FoodShare
//
//  Parallax scrolling effects for depth and visual interest.
//  Multi-layer parallax based on scroll offset for immersive UI.
//
//  Features:
//  - Scroll-coupled parallax movement
//  - Multi-layer depth system
//  - Configurable intensity and direction
//  - GPU-optimized transforms
//


#if !SKIP
import SwiftUI

// MARK: - Parallax Configuration

/// Configuration for parallax effect behavior
struct ParallaxConfiguration {
    /// How much the view moves relative to scroll (1.0 = full speed, 0.5 = half speed)
    let speed: CGFloat

    /// Direction of parallax movement
    let direction: ParallaxDirection

    /// Whether to apply subtle scale effect
    let enableScale: Bool

    /// Whether to apply opacity fade based on scroll
    let enableOpacityFade: Bool

    /// Maximum offset before clamping
    let maxOffset: CGFloat

    static let `default` = ParallaxConfiguration(
        speed: 0.5,
        direction: .vertical,
        enableScale: false,
        enableOpacityFade: false,
        maxOffset: 200,
    )

    static let background = ParallaxConfiguration(
        speed: 0.3,
        direction: .vertical,
        enableScale: true,
        enableOpacityFade: false,
        maxOffset: 300,
    )

    static let foreground = ParallaxConfiguration(
        speed: 0.7,
        direction: .vertical,
        enableScale: false,
        enableOpacityFade: true,
        maxOffset: 150,
    )

    static let subtle = ParallaxConfiguration(
        speed: 0.2,
        direction: .vertical,
        enableScale: false,
        enableOpacityFade: false,
        maxOffset: 100,
    )
}

/// Direction of parallax movement
enum ParallaxDirection {
    case vertical
    case horizontal
    case diagonal(angle: Angle)

    var offset: (x: CGFloat, y: CGFloat) {
        switch self {
        case .vertical:
            (0, 1)
        case .horizontal:
            (1, 0)
        case let .diagonal(angle):
            (cos(angle.radians), sin(angle.radians))
        }
    }
}

// MARK: - Parallax Layer

/// Represents a layer in a multi-layer parallax system
struct ParallaxLayer: Identifiable {
    let id = UUID()
    let speed: CGFloat
    let zIndex: Double
    let opacity: Double

    /// Background layer (moves slowest)
    static let background = ParallaxLayer(speed: 0.3, zIndex: 0, opacity: 0.6)

    /// Mid-ground layer
    static let midground = ParallaxLayer(speed: 0.5, zIndex: 1, opacity: 0.8)

    /// Foreground layer (moves fastest)
    static let foreground = ParallaxLayer(speed: 0.7, zIndex: 2, opacity: 1.0)

    /// Content layer (stationary)
    static let content = ParallaxLayer(speed: 1.0, zIndex: 3, opacity: 1.0)
}

// MARK: - Scroll Offset Preference Key

/// Preference key for tracking scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Parallax View Modifier

/// View modifier that applies parallax effect based on scroll position
struct ParallaxModifier: ViewModifier {
    let configuration: ParallaxConfiguration
    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(
                x: configuration.direction.offset.x * scrollOffset * configuration.speed,
                y: configuration.direction.offset.y * scrollOffset * configuration.speed,
            )
            .scaleEffect(configuration.enableScale ? scaleValue : 1.0)
            .opacity(configuration.enableOpacityFade ? opacityValue : 1.0)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .global).minY,
                    )
                },
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                let clamped = max(-configuration.maxOffset, min(configuration.maxOffset, value))
                scrollOffset = clamped
            }
    }

    private var scaleValue: CGFloat {
        let normalizedOffset = abs(scrollOffset) / configuration.maxOffset
        return 1.0 + (normalizedOffset * 0.1)
    }

    private var opacityValue: Double {
        let normalizedOffset = abs(scrollOffset) / configuration.maxOffset
        return max(0.3, 1.0 - (normalizedOffset * 0.5))
    }
}

// MARK: - Parallax Header Modifier

/// Creates a stretchy parallax header that expands when pulled down
struct ParallaxHeaderModifier: ViewModifier {
    let height: CGFloat
    let minHeight: CGFloat

    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        GeometryReader { geometry in
            let offset = geometry.frame(in: .global).minY
            let headerHeight = max(minHeight, height + (offset > 0 ? offset : 0))

            content
                .frame(width: geometry.size.width, height: headerHeight)
                .clipped()
                .offset(y: offset > 0 ? -offset : 0)
        }
        .frame(height: height)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply parallax effect to this view
    func parallax(configuration: ParallaxConfiguration = .default) -> some View {
        modifier(ParallaxModifier(configuration: configuration))
    }

    /// Apply background parallax (slower movement)
    func parallaxBackground() -> some View {
        modifier(ParallaxModifier(configuration: .background))
    }

    /// Apply foreground parallax (faster movement)
    func parallaxForeground() -> some View {
        modifier(ParallaxModifier(configuration: .foreground))
    }

    /// Apply subtle parallax effect
    func parallaxSubtle() -> some View {
        modifier(ParallaxModifier(configuration: .subtle))
    }

    /// Make this a stretchy parallax header
    func parallaxHeader(height: CGFloat, minHeight: CGFloat = 0) -> some View {
        modifier(ParallaxHeaderModifier(height: height, minHeight: minHeight))
    }

    /// Apply custom parallax with speed
    func parallax(speed: CGFloat) -> some View {
        modifier(ParallaxModifier(configuration: ParallaxConfiguration(
            speed: speed,
            direction: .vertical,
            enableScale: false,
            enableOpacityFade: false,
            maxOffset: 200,
        )))
    }
}

// MARK: - Parallax Scroll View

/// A scroll view with built-in parallax layer support
struct ParallaxScrollView<Background: View, Content: View>: View {
    let backgroundSpeed: CGFloat
    @ViewBuilder let background: () -> Background
    @ViewBuilder let content: () -> Content

    @State private var scrollOffset: CGFloat = 0

    init(
        backgroundSpeed: CGFloat = 0.3,
        @ViewBuilder background: @escaping () -> Background,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.backgroundSpeed = backgroundSpeed
        self.background = background
        self.content = content
    }

    var body: some View {
        ZStack {
            // Background layer with parallax
            background()
                .offset(y: scrollOffset * backgroundSpeed)
                .ignoresSafeArea()

            // Content with scroll tracking
            ScrollView {
                content()
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ScrollOffsetPreferenceKey.self,
                                value: -geometry.frame(in: .named("scroll")).minY,
                            )
                        },
                    )
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
        }
    }
}

// MARK: - Multi-Layer Parallax Container

/// Container for creating multi-layer parallax effects
struct MultiLayerParallax<Content: View>: View {
    let layers: [ParallaxLayer]
    @ViewBuilder let content: (ParallaxLayer, CGFloat) -> Content

    @State private var scrollOffset: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(layers.sorted(by: { $0.zIndex < $1.zIndex })) { layer in
                content(layer, scrollOffset * layer.speed)
                    .opacity(layer.opacity)
                    .zIndex(layer.zIndex)
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .global).minY,
                )
            },
        )
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            scrollOffset = max(-300, min(300, value))
        }
    }
}

// MARK: - Depth Blur Parallax

/// Applies depth-based blur that intensifies with scroll
struct DepthBlurParallaxModifier: ViewModifier {
    let maxBlur: CGFloat
    let scrollThreshold: CGFloat

    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .blur(radius: blurAmount)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: ScrollOffsetPreferenceKey.self,
                        value: geometry.frame(in: .global).minY,
                    )
                },
            )
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
    }

    private var blurAmount: CGFloat {
        let normalizedOffset = abs(scrollOffset) / scrollThreshold
        return min(maxBlur, normalizedOffset * maxBlur)
    }
}

extension View {
    /// Apply depth blur that increases with scroll distance
    func depthBlurParallax(maxBlur: CGFloat = 10, threshold: CGFloat = 200) -> some View {
        modifier(DepthBlurParallaxModifier(maxBlur: maxBlur, scrollThreshold: threshold))
    }
}

// MARK: - Preview

#if DEBUG
    private struct ParallaxPreviewContent: View {
        var body: some View {
            ParallaxScrollView(backgroundSpeed: 0.3) {
                // Background
                let colors: [Color] = [
                    Color.DesignSystem.primary.opacity(0.3),
                    Color.DesignSystem.brandGreen.opacity(0.2)
                ]
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } content: {
                VStack(spacing: Spacing.lg) {
                    parallaxHeader
                    parallaxCards
                    Spacer(minLength: 200)
                }
            }
        }

        private var parallaxHeader: some View {
            ZStack {
                Color.DesignSystem.primary.opacity(0.5)
                Text("Pull Down")
                    .font(Font.DesignSystem.displayMedium)
                    .foregroundStyle(.white)
            }
            .parallaxHeader(height: 200, minHeight: 100)
        }

        private var parallaxCards: some View {
            ForEach(0 ..< 10, id: \.self) { index in
                let speed: CGFloat = 0.1 * CGFloat(index % 3 + 1)
                HStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.DesignSystem.primary.opacity(0.2))
                        .frame(height: 100.0)
                        .overlay(
                            Text("Card \(index + 1)")
                                .font(Font.DesignSystem.headlineSmall)
                        )
                }
                .padding(.horizontal, Spacing.lg)
                .parallax(speed: speed)
            }
        }
    }

    #Preview("Parallax Effects") {
        ParallaxPreviewContent()
    }
#endif

#endif
