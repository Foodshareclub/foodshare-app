//
//  LiquidGlassEffects.swift
//  Foodshare
//
//  Premium iOS 18+ Liquid Glass Visual Effects
//  Advanced glassmorphism with ProMotion 120Hz optimization
//


#if !SKIP
import SwiftUI

#if !SKIP

// MARK: - Premium Glass Card Style

/// Premium glass card with enhanced iOS 18+ visual effects
/// Supports multiple styles: frosted, aurora, neon, crystal
struct PremiumGlassCard<Content: View>: View {
    let style: PremiumGlassStyle
    let cornerRadius: CGFloat
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var phase: CGFloat = 0

    enum PremiumGlassStyle {
        case frosted       // Classic frosted glass
        case aurora        // Animated aurora borealis effect
        case neon          // Glowing neon border
        case crystal       // Crystal-clear with refraction
        case holographic   // Iridescent holographic shimmer
    }

    init(
        style: PremiumGlassStyle = .frosted,
        cornerRadius: CGFloat = CornerRadius.large,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(backgroundForStyle)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(borderOverlay)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowOffset)
            .drawingGroup()
            .onAppear {
                if !reduceMotion && style.isAnimated {
                    startAnimation()
                }
            }
    }

    // MARK: - Background Styles

    @ViewBuilder
    private var backgroundForStyle: some View {
        switch style {
        case .frosted:
            frostedBackground

        case .aurora:
            auroraBackground

        case .neon:
            neonBackground

        case .crystal:
            crystalBackground

        case .holographic:
            holographicBackground
        }
    }

    private var frostedBackground: some View {
        ZStack {
            if reduceTransparency {
                Color(.systemBackground).opacity(0.95)
            } else {
                Color.clear.background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
            }

            // Top highlight
            LinearGradient(
                colors: [
                    Color.white.opacity(0.12),
                    Color.white.opacity(0.02),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
        }
    }

    private var auroraBackground: some View {
        ZStack {
            Color.clear.background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)

            // Animated aurora colors
            TimelineView(.animation(minimumInterval: 1/60)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                LinearGradient(
                    colors: [
                        Color.DesignSystem.brandGreen.opacity(0.15 + sin(time * 0.5) * 0.05),
                        Color.DesignSystem.brandTeal.opacity(0.1 + cos(time * 0.7) * 0.05),
                        Color.DesignSystem.accentCyan.opacity(0.12 + sin(time * 0.3) * 0.05),
                        Color.clear
                    ],
                    startPoint: UnitPoint(
                        x: 0.5 + sin(time * 0.4) * 0.3,
                        y: 0
                    ),
                    endPoint: UnitPoint(
                        x: 0.5 + cos(time * 0.5) * 0.3,
                        y: 1
                    )
                )
            }
        }
    }

    private var neonBackground: some View {
        ZStack {
            Color.clear.background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)

            // Inner glow
            RoundedRectangle(cornerRadius: cornerRadius - 2)
                .stroke(
                    Color.DesignSystem.brandGreen.opacity(0.3),
                    lineWidth: 2
                )
                .blur(radius: 4)
                .padding(2)
        }
    }

    private var crystalBackground: some View {
        ZStack {
            Color.clear.background(.thinMaterial)

            // Prismatic refraction effect
            LinearGradient(
                colors: [
                    Color.white.opacity(0.15),
                    Color.DesignSystem.accentCyan.opacity(0.05),
                    Color.white.opacity(0.08),
                    Color.DesignSystem.brandPink.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Crystal facet highlight
            LinearGradient(
                colors: [
                    Color.white.opacity(0.2),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: UnitPoint(x: 0.3, y: 0.3)
            )
        }
    }

    private var holographicBackground: some View {
        ZStack {
            Color.clear.background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)

            // Animated holographic shimmer
            TimelineView(.animation(minimumInterval: 1/60)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                AngularGradient(
                    colors: [
                        Color.DesignSystem.brandPink.opacity(0.1),
                        Color.DesignSystem.accentCyan.opacity(0.1),
                        Color.DesignSystem.brandGreen.opacity(0.1),
                        Color.DesignSystem.brandTeal.opacity(0.1),
                        Color.DesignSystem.accentPurple.opacity(0.1),
                        Color.DesignSystem.brandPink.opacity(0.1)
                    ],
                    center: .center,
                    angle: .degrees(time * 20)
                )
                .opacity(0.5)
            }
        }
    }

    // MARK: - Border Overlay

    @ViewBuilder
    private var borderOverlay: some View {
        switch style {
        case .neon:
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.brandGreen,
                            Color.DesignSystem.accentCyan
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .shadow(color: Color.DesignSystem.brandGreen.opacity(0.6), radius: 8)

        case .holographic:
            TimelineView(.animation(minimumInterval: 1/60)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color.DesignSystem.brandPink.opacity(0.6),
                                Color.DesignSystem.accentCyan.opacity(0.6),
                                Color.DesignSystem.brandGreen.opacity(0.6),
                                Color.DesignSystem.accentPurple.opacity(0.6),
                                Color.DesignSystem.brandPink.opacity(0.6)
                            ],
                            center: .center,
                            angle: .degrees(time * 30)
                        ),
                        lineWidth: 1.5
                    )
            }

        default:
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.glassHighlight,
                            Color.DesignSystem.glassBorder,
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Shadow Properties

    private var shadowColor: Color {
        switch style {
        case .neon:
            Color.DesignSystem.brandGreen.opacity(0.4)
        case .holographic:
            Color.DesignSystem.accentPurple.opacity(0.3)
        case .aurora:
            Color.DesignSystem.brandTeal.opacity(0.25)
        default:
            Color.black.opacity(0.15)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .neon: 16
        case .holographic: 12
        default: 10
        }
    }

    private var shadowOffset: CGFloat {
        switch style {
        case .neon: 0
        default: 6
        }
    }

    // MARK: - Animation

    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
        ) {
            phase = 1.0
        }
    }
}

extension PremiumGlassCard.PremiumGlassStyle {
    var isAnimated: Bool {
        switch self {
        case .aurora, .holographic: true
        default: false
        }
    }
}

// MARK: - Glass Blur Intensity Modifier

/// Dynamic blur intensity with accessibility support
struct DynamicGlassBlurModifier: ViewModifier {
    let intensity: BlurIntensity
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    enum BlurIntensity {
        case subtle     // Ultra thin material
        case standard   // Thin material
        case intense    // Regular material
        case heavy      // Thick material

        var material: Material {
            switch self {
            case .subtle: .ultraThinMaterial
            case .standard: .thinMaterial
            case .intense: .regularMaterial
            case .heavy: .thickMaterial
            }
        }
    }

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .background(Color(.systemBackground).opacity(0.95))
        } else {
            content
                .background(intensity.material)
        }
    }
}

extension View {
    func dynamicGlassBlur(_ intensity: DynamicGlassBlurModifier.BlurIntensity = .standard) -> some View {
        modifier(DynamicGlassBlurModifier(intensity: intensity))
    }
}

// MARK: - Morphing Glass Border

/// Animated morphing border effect for premium glass elements
struct MorphingGlassBorderModifier: ViewModifier {
    let cornerRadius: CGFloat
    let colors: [Color]
    let lineWidth: CGFloat

    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            colors: colors,
                            center: .center,
                            angle: .degrees(rotation)
                        ),
                        lineWidth: lineWidth
                    )
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 4.0)
                        .repeatForever(autoreverses: false)
                ) {
                    rotation = 360
                }
            }
    }
}

extension View {
    func morphingGlassBorder(
        cornerRadius: CGFloat = CornerRadius.large,
        colors: [Color] = [
            Color.DesignSystem.brandPink,
            Color.DesignSystem.brandTeal,
            Color.DesignSystem.accentCyan,
            Color.DesignSystem.brandGreen,
            Color.DesignSystem.brandPink
        ],
        lineWidth: CGFloat = 2
    ) -> some View {
        modifier(MorphingGlassBorderModifier(
            cornerRadius: cornerRadius,
            colors: colors,
            lineWidth: lineWidth
        ))
    }
}

// MARK: - Glass Depth Effect

/// Creates a 3D depth illusion for glass cards
struct GlassDepthModifier: ViewModifier {
    let depth: DepthLevel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    enum DepthLevel {
        case flat
        case raised
        case floating
        case elevated

        var yOffset: CGFloat {
            switch self {
            case .flat: 0
            case .raised: 4
            case .floating: 8
            case .elevated: 16
            }
        }

        var shadowOpacity: Double {
            switch self {
            case .flat: 0
            case .raised: 0.1
            case .floating: 0.15
            case .elevated: 0.2
            }
        }

        var scale: CGFloat {
            switch self {
            case .flat: 1.0
            case .raised: 1.0
            case .floating: 1.0
            case .elevated: 1.02
            }
        }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : depth.scale)
            .shadow(
                color: .black.opacity(depth.shadowOpacity),
                radius: depth.yOffset * 1.5,
                y: depth.yOffset
            )
    }
}

extension View {
    func glassDepth(_ level: GlassDepthModifier.DepthLevel) -> some View {
        modifier(GlassDepthModifier(depth: level))
    }
}

// MARK: - Interactive Press Glass Effect

/// Press-responsive glass effect with visual feedback
struct InteractiveGlassModifier: ViewModifier {
    @State private var isPressed = false
    let cornerRadius: CGFloat
    let hapticFeedback: Bool

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        #if !SKIP
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                        #else
                        .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                        #endif

                    // Press highlight
                    if isPressed {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.white.opacity(0.08))
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        Color.DesignSystem.glassBorder,
                        lineWidth: isPressed ? 1.5 : 1
                    )
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.interpolatingSpring(stiffness: 400, damping: 20), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            if hapticFeedback {
                                HapticManager.light()
                            }
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    func interactiveGlass(
        cornerRadius: CGFloat = CornerRadius.large,
        hapticFeedback: Bool = true
    ) -> some View {
        modifier(InteractiveGlassModifier(
            cornerRadius: cornerRadius,
            hapticFeedback: hapticFeedback
        ))
    }
}

// MARK: - Glass Spotlight Effect

/// Animated spotlight/lens flare effect for hero elements
struct GlassSpotlightModifier: ViewModifier {
    let color: Color
    let size: CGFloat

    @State private var offset: CGSize = CGSize(width: -100, height: -100)

    func body(content: Content) -> some View {
        content
            .overlay(
                RadialGradient(
                    colors: [
                        color.opacity(0.3),
                        color.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size
                )
                .offset(offset)
                .blendMode(.overlay)
            )
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 4.0)
                        .repeatForever(autoreverses: true)
                ) {
                    offset = CGSize(width: 100.0, height: 100.0)
                }
            }
    }
}

extension View {
    func glassSpotlight(
        color: Color = Color.white,
        size: CGFloat = 150
    ) -> some View {
        modifier(GlassSpotlightModifier(color: color, size: size))
    }
}

// MARK: - Premium Glass View Extension

extension View {
    /// Apply premium glass card styling
    func premiumGlassCard(
        style: PremiumGlassCard<Self>.PremiumGlassStyle = .frosted,
        cornerRadius: CGFloat = CornerRadius.large
    ) -> some View {
        PremiumGlassCard(style: style, cornerRadius: cornerRadius) {
            self
        }
    }
}

// MARK: - Previews

#Preview("Premium Glass Cards") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            PremiumGlassCard(style: .frosted) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Frosted Glass")
                        .font(.DesignSystem.headlineMedium)
                    Text("Classic frosted glass effect with subtle highlights")
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.md)
            }

            PremiumGlassCard(style: .aurora) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Aurora Glass")
                        .font(.DesignSystem.headlineMedium)
                    Text("Animated aurora borealis color waves")
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.md)
            }

            PremiumGlassCard(style: .neon) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Neon Glass")
                        .font(.DesignSystem.headlineMedium)
                    Text("Glowing neon border effect")
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.md)
            }

            PremiumGlassCard(style: .crystal) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Crystal Glass")
                        .font(.DesignSystem.headlineMedium)
                    Text("Prismatic refraction with crystal facets")
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.md)
            }

            PremiumGlassCard(style: .holographic) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Holographic Glass")
                        .font(.DesignSystem.headlineMedium)
                    Text("Iridescent animated border shimmer")
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.md)
            }
        }
        .padding(Spacing.md)
    }
    .background(
        LinearGradient(
            colors: [
                Color.DesignSystem.brandGreen.opacity(0.3),
                Color.DesignSystem.brandBlue.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    )
    .preferredColorScheme(.dark)
}

#Preview("Interactive Glass") {
    VStack(spacing: Spacing.lg) {
        Text("Tap the cards")
            .font(.DesignSystem.headlineSmall)
            .foregroundStyle(.secondary)

        HStack(spacing: Spacing.md) {
            Text("Flat")
                .padding(Spacing.md)
                .frame(width: 100.0)
                .interactiveGlass()
                .glassDepth(.flat)

            Text("Raised")
                .padding(Spacing.md)
                .frame(width: 100.0)
                .interactiveGlass()
                .glassDepth(.raised)

            Text("Floating")
                .padding(Spacing.md)
                .frame(width: 100.0)
                .interactiveGlass()
                .glassDepth(.floating)
        }

        Text("With Spotlight")
            .font(.DesignSystem.headlineSmall)
            .padding(Spacing.xl)
            .frame(maxWidth: .infinity)
            .premiumGlassCard(style: .frosted)
            .glassSpotlight(color: .white, size: 120)
    }
    .padding(Spacing.lg)
    .background(Color.DesignSystem.background)
    .preferredColorScheme(.dark)
}
#endif

#endif
