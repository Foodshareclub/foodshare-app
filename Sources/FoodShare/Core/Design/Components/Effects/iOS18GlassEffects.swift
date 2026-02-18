//
//  iOS18GlassEffects.swift
//  Foodshare
//
//  iOS 18+ Specific Visual Effects
//  Leverages new SwiftUI capabilities for enhanced Liquid Glass design
//


#if !SKIP
import SwiftUI

// MARK: - Animated Mesh Glass Background

/// Premium animated mesh gradient background
/// Uses iOS 18+ MeshGradient with morphing control points
@available(iOS 18.0, macOS 15.0, *)
struct AnimatedMeshGlassBackground: View {
    let style: MeshStyle
    @State private var phase: CGFloat = 0

    enum MeshStyle {
        case brand       // Foodshare brand colors (Pink/Teal)
        case eco         // Green/Cyan eco-friendly
        case ocean       // Deep blue ocean theme
        case sunset      // Warm orange/pink sunset
        case midnight    // Dark purple/blue night
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1/60)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            MeshGradient(
                width: 4,
                height: 4,
                points: meshPoints(time: time),
                colors: meshColors(time: time),
                smoothsColors: true,
                colorSpace: .perceptual
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Animated Mesh Points (Morphing Effect)

    private func meshPoints(time: Double) -> [SIMD2<Float>] {
        let speed: Float = 0.15
        let t = Float(time * Double(speed))
        let amplitude: Float = 0.08

        return [
            // Row 0
            SIMD2(0.0, 0.0),
            SIMD2(0.33 + sin(t * 1.1) * amplitude, 0.0 + cos(t * 0.9) * amplitude * 0.5),
            SIMD2(0.66 + cos(t * 0.8) * amplitude, 0.0 + sin(t * 1.2) * amplitude * 0.5),
            SIMD2(1.0, 0.0),

            // Row 1
            SIMD2(0.0 + sin(t * 0.7) * amplitude * 0.5, 0.33 + cos(t * 1.0) * amplitude),
            SIMD2(0.33 + sin(t * 0.9) * amplitude, 0.33 + sin(t * 1.1) * amplitude),
            SIMD2(0.66 + cos(t * 1.2) * amplitude, 0.33 + cos(t * 0.8) * amplitude),
            SIMD2(1.0 + cos(t * 0.6) * amplitude * 0.5, 0.33 + sin(t * 1.0) * amplitude),

            // Row 2
            SIMD2(0.0 + cos(t * 0.9) * amplitude * 0.5, 0.66 + sin(t * 1.1) * amplitude),
            SIMD2(0.33 + cos(t * 1.0) * amplitude, 0.66 + cos(t * 0.9) * amplitude),
            SIMD2(0.66 + sin(t * 0.8) * amplitude, 0.66 + sin(t * 1.2) * amplitude),
            SIMD2(1.0 + sin(t * 0.7) * amplitude * 0.5, 0.66 + cos(t * 1.0) * amplitude),

            // Row 3
            SIMD2(0.0, 1.0),
            SIMD2(0.33 + cos(t * 1.1) * amplitude, 1.0 + sin(t * 0.8) * amplitude * 0.5),
            SIMD2(0.66 + sin(t * 0.9) * amplitude, 1.0 + cos(t * 1.1) * amplitude * 0.5),
            SIMD2(1.0, 1.0)
        ]
    }

    // MARK: - Animated Colors

    private func meshColors(time: Double) -> [Color] {
        let t = time * 0.3

        switch style {
        case .brand:
            return brandColors(t: t)
        case .eco:
            return ecoColors(t: t)
        case .ocean:
            return oceanColors(t: t)
        case .sunset:
            return sunsetColors(t: t)
        case .midnight:
            return midnightColors(t: t)
        }
    }

    private func brandColors(t: Double) -> [Color] {
        let base = Color(red: 0.05, green: 0.05, blue: 0.08)

        return [
            // Row 0
            Color.DesignSystem.brandPink.opacity(0.35 + sin(t) * 0.1),
            Color.DesignSystem.brandTeal.opacity(0.25 + cos(t * 1.2) * 0.1),
            Color.DesignSystem.accentCyan.opacity(0.3 + sin(t * 0.8) * 0.1),
            Color.DesignSystem.brandPink.opacity(0.25 + cos(t) * 0.1),

            // Row 1
            base.opacity(0.95),
            Color.DesignSystem.brandPink.opacity(0.15 + sin(t * 1.1) * 0.05),
            Color.DesignSystem.brandTeal.opacity(0.15 + cos(t * 0.9) * 0.05),
            base.opacity(0.95),

            // Row 2
            base.opacity(0.95),
            Color.DesignSystem.accentCyan.opacity(0.12 + cos(t * 1.3) * 0.05),
            Color.DesignSystem.brandPink.opacity(0.12 + sin(t * 0.7) * 0.05),
            base.opacity(0.95),

            // Row 3
            Color.DesignSystem.brandTeal.opacity(0.25 + cos(t * 1.1) * 0.1),
            base.opacity(0.95),
            base.opacity(0.95),
            Color.DesignSystem.accentCyan.opacity(0.3 + sin(t * 0.9) * 0.1)
        ]
    }

    private func ecoColors(t: Double) -> [Color] {
        let base = Color(red: 0.03, green: 0.06, blue: 0.05)

        return [
            // Row 0
            Color.DesignSystem.brandGreen.opacity(0.4 + sin(t) * 0.1),
            Color.DesignSystem.accentCyan.opacity(0.25 + cos(t * 1.2) * 0.1),
            Color.DesignSystem.brandTeal.opacity(0.35 + sin(t * 0.8) * 0.1),
            Color.DesignSystem.brandGreen.opacity(0.3 + cos(t) * 0.1),

            // Row 1
            base,
            Color.DesignSystem.brandGreen.opacity(0.15 + sin(t * 1.1) * 0.05),
            Color.DesignSystem.accentCyan.opacity(0.12 + cos(t * 0.9) * 0.05),
            base,

            // Row 2
            base,
            Color.DesignSystem.brandTeal.opacity(0.1 + cos(t * 1.3) * 0.05),
            Color.DesignSystem.brandGreen.opacity(0.12 + sin(t * 0.7) * 0.05),
            base,

            // Row 3
            Color.DesignSystem.accentCyan.opacity(0.3 + cos(t * 1.1) * 0.1),
            base,
            base,
            Color.DesignSystem.brandGreen.opacity(0.35 + sin(t * 0.9) * 0.1)
        ]
    }

    private func oceanColors(t: Double) -> [Color] {
        let base = Color(red: 0.02, green: 0.04, blue: 0.08)

        return [
            Color.DesignSystem.accentBlue.opacity(0.4 + sin(t) * 0.1),
            Color.DesignSystem.accentCyan.opacity(0.3 + cos(t * 1.2) * 0.1),
            Color.DesignSystem.accentBlue.opacity(0.35 + sin(t * 0.8) * 0.1),
            Color.DesignSystem.accentCyan.opacity(0.25 + cos(t) * 0.1),

            base,
            Color.DesignSystem.accentBlue.opacity(0.18 + sin(t * 1.1) * 0.05),
            Color.DesignSystem.accentCyan.opacity(0.15 + cos(t * 0.9) * 0.05),
            base,

            base,
            Color.DesignSystem.accentCyan.opacity(0.12 + cos(t * 1.3) * 0.05),
            Color.DesignSystem.accentBlue.opacity(0.12 + sin(t * 0.7) * 0.05),
            base,

            Color.DesignSystem.accentCyan.opacity(0.28 + cos(t * 1.1) * 0.1),
            base,
            base,
            Color.DesignSystem.accentBlue.opacity(0.35 + sin(t * 0.9) * 0.1)
        ]
    }

    private func sunsetColors(t: Double) -> [Color] {
        let base = Color(red: 0.06, green: 0.03, blue: 0.05)

        return [
            Color.DesignSystem.brandOrange.opacity(0.4 + sin(t) * 0.1),
            Color.DesignSystem.brandPink.opacity(0.35 + cos(t * 1.2) * 0.1),
            Color.DesignSystem.accentYellow.opacity(0.3 + sin(t * 0.8) * 0.1),
            Color.DesignSystem.brandOrange.opacity(0.25 + cos(t) * 0.1),

            base,
            Color.DesignSystem.brandPink.opacity(0.18 + sin(t * 1.1) * 0.05),
            Color.DesignSystem.brandOrange.opacity(0.15 + cos(t * 0.9) * 0.05),
            base,

            base,
            Color.DesignSystem.accentYellow.opacity(0.12 + cos(t * 1.3) * 0.05),
            Color.DesignSystem.brandPink.opacity(0.12 + sin(t * 0.7) * 0.05),
            base,

            Color.DesignSystem.brandPink.opacity(0.28 + cos(t * 1.1) * 0.1),
            base,
            base,
            Color.DesignSystem.brandOrange.opacity(0.35 + sin(t * 0.9) * 0.1)
        ]
    }

    private func midnightColors(t: Double) -> [Color] {
        let base = Color(red: 0.03, green: 0.02, blue: 0.06)

        return [
            Color.DesignSystem.accentPurple.opacity(0.35 + sin(t) * 0.1),
            Color.DesignSystem.accentBlue.opacity(0.25 + cos(t * 1.2) * 0.1),
            Color.DesignSystem.accentPurple.opacity(0.3 + sin(t * 0.8) * 0.1),
            Color.DesignSystem.accentBlue.opacity(0.2 + cos(t) * 0.1),

            base,
            Color.DesignSystem.accentPurple.opacity(0.15 + sin(t * 1.1) * 0.05),
            Color.DesignSystem.accentBlue.opacity(0.12 + cos(t * 0.9) * 0.05),
            base,

            base,
            Color.DesignSystem.accentBlue.opacity(0.1 + cos(t * 1.3) * 0.05),
            Color.DesignSystem.accentPurple.opacity(0.1 + sin(t * 0.7) * 0.05),
            base,

            Color.DesignSystem.accentBlue.opacity(0.22 + cos(t * 1.1) * 0.1),
            base,
            base,
            Color.DesignSystem.accentPurple.opacity(0.3 + sin(t * 0.9) * 0.1)
        ]
    }
}

// MARK: - Liquid Glass Hero Container

/// Premium hero container with animated mesh background
/// For featured content, onboarding, and splash screens
@available(iOS 18.0, macOS 15.0, *)
struct LiquidGlassHeroContainer<Content: View>: View {
    let meshStyle: AnimatedMeshGlassBackground.MeshStyle
    let showOverlay: Bool
    let content: Content

    init(
        meshStyle: AnimatedMeshGlassBackground.MeshStyle = .brand,
        showOverlay: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.meshStyle = meshStyle
        self.showOverlay = showOverlay
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Animated mesh background
            AnimatedMeshGlassBackground(style: meshStyle)

            // Optional dark overlay for better text contrast
            if showOverlay {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
            }

            // Content
            content
        }
    }
}

// MARK: - Floating Glass Panel

/// Floating glass panel with depth and shadow effects
struct FloatingGlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let elevation: PanelElevation
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @State private var floatOffset: CGFloat = 0

    enum PanelElevation {
        case low
        case medium
        case high

        var shadowRadius: CGFloat {
            switch self {
            case .low: 8
            case .medium: 16
            case .high: 32
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .low: 0.1
            case .medium: 0.15
            case .high: 0.25
            }
        }

        var floatAmplitude: CGFloat {
            switch self {
            case .low: 2
            case .medium: 4
            case .high: 6
            }
        }
    }

    init(
        cornerRadius: CGFloat = CornerRadius.large,
        elevation: PanelElevation = .medium,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.elevation = elevation
        self.content = content()
    }

    var body: some View {
        content
            .background(
                ZStack {
                    // Base glass material
                    RoundedRectangle(cornerRadius: cornerRadius)
                        #if !SKIP
                        .fill(.ultraThinMaterial)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif

                    // Top highlight
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.03),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
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
            .shadow(
                color: .black.opacity(elevation.shadowOpacity),
                radius: elevation.shadowRadius,
                y: elevation.shadowRadius / 2
            )
            .offset(y: floatOffset)
            .onAppear {
                if !reduceMotion {
                    startFloating()
                }
            }
    }

    private func startFloating() {
        withAnimation(
            .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
        ) {
            floatOffset = elevation.floatAmplitude
        }
    }
}

// MARK: - Glass Orb Indicator

/// Animated glass orb for loading/status indicators
struct GlassOrbIndicator: View {
    let color: Color
    let size: CGFloat
    let isPulsing: Bool

    @State private var scale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.5

    init(
        color: Color = Color.DesignSystem.brandGreen,
        size: CGFloat = 12,
        isPulsing: Bool = true
    ) {
        self.color = color
        self.size = size
        self.isPulsing = isPulsing
    }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(color.opacity(glowOpacity * 0.4))
                .frame(width: size * 2, height: size * 2)
                .blur(radius: size / 3)

            // Main orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            color.opacity(0.9),
                            color
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .frame(width: size, height: size)

            // Highlight
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.6),
                            Color.clear
                        ],
                        center: UnitPoint(x: 0.3, y: 0.3),
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .frame(width: size, height: size)
        }
        .scaleEffect(scale)
        .onAppear {
            if isPulsing {
                withAnimation(
                    .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true)
                ) {
                    scale = 1.15
                    glowOpacity = 0.8
                }
            }
        }
    }
}

// MARK: - Glass Status Bar

/// Animated glass status/progress bar
struct GlassStatusBar: View {
    let progress: Double
    let color: Color
    let height: CGFloat
    let showShimmer: Bool

    @State private var shimmerOffset: CGFloat = -200

    init(
        progress: Double,
        color: Color = Color.DesignSystem.brandGreen,
        height: CGFloat = 8,
        showShimmer: Bool = true
    ) {
        self.progress = min(max(progress, 0), 1)
        self.color = color
        self.height = height
        self.showShimmer = showShimmer
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: height)

                // Progress fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: height)
                    .overlay(
                        // Shimmer effect
                        shimmerOverlay
                            .opacity(showShimmer && progress > 0 ? 1 : 0)
                    )
                    .clipShape(Capsule())
                    .shadow(color: color.opacity(0.5), radius: 4, y: 2)
            }
        }
        .frame(height: height)
        .onAppear {
            if showShimmer {
                startShimmer()
            }
        }
    }

    private var shimmerOverlay: some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(0.4),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 60.0)
        .offset(x: shimmerOffset)
    }

    private func startShimmer() {
        withAnimation(
            .linear(duration: 1.5)
                .repeatForever(autoreverses: false)
        ) {
            shimmerOffset = 300
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply liquid glass hero container background
    @available(iOS 18.0, macOS 15.0, *)
    func liquidGlassHero(
        style: AnimatedMeshGlassBackground.MeshStyle = .brand,
        showOverlay: Bool = true
    ) -> some View {
        LiquidGlassHeroContainer(meshStyle: style, showOverlay: showOverlay) {
            self
        }
    }

    /// Wrap in floating glass panel
    func floatingGlassPanel(
        cornerRadius: CGFloat = CornerRadius.large,
        elevation: FloatingGlassPanel<Self>.PanelElevation = .medium
    ) -> some View {
        FloatingGlassPanel(cornerRadius: cornerRadius, elevation: elevation) {
            self
        }
    }
}

// MARK: - Previews

@available(iOS 18.0, macOS 15.0, *)
#Preview("Animated Mesh Backgrounds") {
    TabView {
        AnimatedMeshGlassBackground(style: .brand)
            .tabItem { Text("Brand") }

        AnimatedMeshGlassBackground(style: .eco)
            .tabItem { Text("Eco") }

        AnimatedMeshGlassBackground(style: .ocean)
            .tabItem { Text("Ocean") }

        AnimatedMeshGlassBackground(style: .sunset)
            .tabItem { Text("Sunset") }

        AnimatedMeshGlassBackground(style: .midnight)
            .tabItem { Text("Midnight") }
    }
    .ignoresSafeArea()
}

@available(iOS 18.0, macOS 15.0, *)
#Preview("Floating Glass Panel") {
    ZStack {
        AnimatedMeshGlassBackground(style: .brand)

        VStack(spacing: Spacing.lg) {
            FloatingGlassPanel(elevation: .low) {
                Text("Low Elevation")
                    .padding(Spacing.md)
            }

            FloatingGlassPanel(elevation: .medium) {
                Text("Medium Elevation")
                    .padding(Spacing.md)
            }

            FloatingGlassPanel(elevation: .high) {
                Text("High Elevation")
                    .padding(Spacing.lg)
            }
        }
        .padding(Spacing.lg)
    }
}

#Preview("Glass Status Elements") {
    VStack(spacing: Spacing.xl) {
        HStack(spacing: Spacing.lg) {
            GlassOrbIndicator(color: .DesignSystem.success)
            GlassOrbIndicator(color: .DesignSystem.brandPink, size: 16)
            GlassOrbIndicator(color: .DesignSystem.accentBlue, size: 20)
        }

        VStack(spacing: Spacing.md) {
            GlassStatusBar(progress: 0.3, color: .DesignSystem.brandGreen)
            GlassStatusBar(progress: 0.6, color: .DesignSystem.brandPink)
            GlassStatusBar(progress: 0.9, color: .DesignSystem.accentBlue)
        }
        .padding(.horizontal, Spacing.lg)
    }
    .padding(Spacing.xl)
    .background(Color.DesignSystem.background)
    .preferredColorScheme(.dark)
}

#endif
