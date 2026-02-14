//
//  GlassModifiers.swift
//  Foodshare
//
//  Liquid Glass v26 View Modifiers
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Glass Effect Modifier

struct GlassEffectModifier: ViewModifier {
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    let shadowRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.glassHighlight,
                                    Color.DesignSystem.glassBorder,
                                    Color.clear,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: borderWidth,
                        )

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .center,
                            ),
                        )
                },
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, y: shadowRadius / 2)
    }
}

extension View {
    func glassEffect(
        cornerRadius: CGFloat = Spacing.radiusLG,
        borderWidth: CGFloat = 1,
        shadowRadius: CGFloat = 12,
    ) -> some View {
        modifier(GlassEffectModifier(
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            shadowRadius: shadowRadius,
        ))
    }
}

// MARK: - Shimmer Effect Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    let bounce: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [
                        Color.clear,
                        Color.white.opacity(0.3),
                        Color.clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing,
                )
                .rotationEffect(.degrees(30))
                .offset(x: phase)
                .mask(content),
            )
            .onAppear {
                withAnimation(
                    .linear(duration: duration)
                        .repeatForever(autoreverses: bounce),
                ) {
                    phase = 400
                }
            }
    }
}

extension View {
    func shimmer(duration: Double = 2.0, bounce: Bool = false) -> some View {
        modifier(ShimmerModifier(duration: duration, bounce: bounce))
    }
}

// MARK: - Glow Effect Modifier

struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
            .shadow(color: color.opacity(0.4), radius: radius * 1.5, x: 0, y: 0)
            .shadow(color: color.opacity(0.2), radius: radius * 2, x: 0, y: 0)
    }
}

extension View {
    func glow(color: Color = Color.DesignSystem.brandGreen, radius: CGFloat = 10) -> some View {
        modifier(GlowModifier(color: color, radius: radius))
    }
}

// MARK: - Press Animation Modifier

struct PressAnimationModifier: ViewModifier {
    @State private var isPressed = false
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .opacity(isPressed ? 0.95 : 1.0)
            // ProMotion 120Hz optimized: interpolating spring for instant response
            .animation(.interpolatingSpring(stiffness: 400, damping: 30), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false },
            )
    }
}

extension View {
    func pressAnimation(scale: CGFloat = 0.98) -> some View {
        modifier(PressAnimationModifier(scale: scale))
    }
}

// MARK: - Floating Animation Modifier

struct FloatingModifier: ViewModifier {
    @State private var offset: CGFloat = 0
    let distance: CGFloat
    let duration: Double

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true),
                ) {
                    offset = distance
                }
            }
    }
}

extension View {
    func floating(distance: CGFloat = 10, duration: Double = 2.0) -> some View {
        modifier(FloatingModifier(distance: distance, duration: duration))
    }
}

// MARK: - Gradient Text Modifier

struct GradientTextModifier: ViewModifier {
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint

    func body(content: Content) -> some View {
        content
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: startPoint,
                    endPoint: endPoint,
                ),
            )
    }
}

extension View {
    func gradientText(
        colors: [Color] = [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
        startPoint: UnitPoint = .leading,
        endPoint: UnitPoint = .trailing,
    ) -> some View {
        modifier(GradientTextModifier(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint,
        ))
    }
}

// MARK: - Pulse Animation Modifier

struct PulseModifier: ViewModifier {
    @State private var scale: CGFloat = 1.0
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true),
                ) {
                    scale = maxScale
                }
            }
    }
}

extension View {
    func pulse(
        minScale: CGFloat = 1.0,
        maxScale: CGFloat = 1.05,
        duration: Double = 1.0,
    ) -> some View {
        modifier(PulseModifier(
            minScale: minScale,
            maxScale: maxScale,
            duration: duration,
        ))
    }
}

// MARK: - Glass Background (Simple)

extension View {
    /// Simple glass background with material and rounded corners
    /// Use glassEffect() for more advanced styling with gradients
    func glassBackground(cornerRadius: CGFloat = Spacing.radiusMD) -> some View {
        background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.glassBorder, lineWidth: 1),
            )
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
    }
}

// MARK: - Glass Navigation Bar Modifier

struct GlassNavigationBarModifier: ViewModifier {
    let tintColor: Color
    let showDivider: Bool

    func body(content: Content) -> some View {
        content
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(tintColor)
            .overlay(alignment: .top) {
                if showDivider {
                    VStack {
                        Spacer()
                            .frame(height: 44) // Approximate nav bar height
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.1),
                                        Color.DesignSystem.glassBorder,
                                        Color.white.opacity(0.05),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing,
                                ),
                            )
                            .frame(height: 0.5)
                    }
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    /// Apply glass styling to navigation bar
    func glassNavigationBar(
        tintColor: Color = .DesignSystem.brandGreen,
        showDivider: Bool = true,
    ) -> some View {
        modifier(GlassNavigationBarModifier(tintColor: tintColor, showDivider: showDivider))
    }
}

// MARK: - Glass Toolbar Button Style

struct GlassToolbarButtonStyle: ButtonStyle {
    let size: CGFloat
    let isAccented: Bool

    init(size: CGFloat = 32, isAccented: Bool = false) {
        self.size = size
        self.isAccented = isAccented
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.45, weight: .medium))
            .foregroundColor(isAccented ? .DesignSystem.brandGreen : .DesignSystem.text)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .stroke(
                                isAccented
                                    ? Color.DesignSystem.brandGreen.opacity(0.3)
                                    : Color.DesignSystem.glassBorder,
                                lineWidth: 1,
                            ),
                    ),
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            // ProMotion 120Hz optimized: interpolating spring for instant response
            .animation(.interpolatingSpring(stiffness: 400, damping: 30), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GlassToolbarButtonStyle {
    static var glassToolbar: GlassToolbarButtonStyle {
        GlassToolbarButtonStyle()
    }

    static func glassToolbar(size: CGFloat = 32, isAccented: Bool = false) -> GlassToolbarButtonStyle {
        GlassToolbarButtonStyle(size: size, isAccented: isAccented)
    }
}

// MARK: - Glass Sheet Presentation Modifier

struct GlassSheetModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .presentationCornerRadius(CornerRadius.xl)
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
    }
}

extension View {
    /// Apply glass styling to sheet presentation
    func glassSheet() -> some View {
        modifier(GlassSheetModifier())
    }
}

// MARK: - Glass Card Modifier (Reusable)

struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let padding: CGFloat
    let shadowIntensity: Double
    let accentColor: Color?

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // Base material
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    // Accent gradient (if provided)
                    if let accent = accentColor {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        accent.opacity(0.05),
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom,
                                ),
                            )
                    }

                    // Top light reflection
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.02),
                                    Color.clear,
                                ],
                                startPoint: .top,
                                endPoint: .center,
                            ),
                        )
                },
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.25),
                                Color.DesignSystem.glassBorder,
                                Color.white.opacity(0.1),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        lineWidth: 1,
                    ),
            )
            .shadow(color: (accentColor ?? .black).opacity(shadowIntensity * 0.3), radius: 20, y: 10)
            .shadow(color: .black.opacity(shadowIntensity * 0.15), radius: 10, y: 5)
    }
}

extension View {
    /// Apply comprehensive glass card styling
    func glassCard(
        cornerRadius: CGFloat = CornerRadius.large,
        padding: CGFloat = Spacing.md,
        shadowIntensity: Double = 0.5,
        accentColor: Color? = nil,
    ) -> some View {
        modifier(GlassCardModifier(
            cornerRadius: cornerRadius,
            padding: padding,
            shadowIntensity: shadowIntensity,
            accentColor: accentColor,
        ))
    }
}

// MARK: - Glass Inset Modifier

struct GlassInsetModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.black.opacity(0.1), lineWidth: 1),
                    ),
            )
    }
}

extension View {
    /// Apply an inset glass style (for input fields, etc.)
    func glassInset(cornerRadius: CGFloat = CornerRadius.medium) -> some View {
        modifier(GlassInsetModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Animated Appearance Modifier

struct AnimatedAppearanceModifier: ViewModifier {
    @State private var hasAppeared = false
    let animation: Animation
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .scaleEffect(hasAppeared ? 1 : 0.95)
            .onAppear {
                withAnimation(animation.delay(delay)) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    /// Animate view appearance with fade, slide, and scale
    func animatedAppearance(
        animation: Animation = .spring(response: 0.5, dampingFraction: 0.8),
        delay: Double = 0,
    ) -> some View {
        modifier(AnimatedAppearanceModifier(animation: animation, delay: delay))
    }
}

// MARK: - Staggered Animation Modifier

struct StaggeredAnimationModifier: ViewModifier {
    let index: Int
    let baseDelay: Double
    let staggerDelay: Double

    @State private var hasAppeared = false

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 15)
            .scaleEffect(hasAppeared ? 1 : 0.95)
            .onAppear {
                // ProMotion 120Hz optimized: interpolating spring for smooth entrance
                withAnimation(
                    .interpolatingSpring(stiffness: 200, damping: 22)
                        .delay(baseDelay + (Double(index) * staggerDelay)),
                ) {
                    hasAppeared = true
                }
            }
    }
}

extension View {
    /// Apply staggered animation based on index (for lists)
    func staggeredAppearance(
        index: Int,
        baseDelay: Double = 0.1,
        staggerDelay: Double = 0.05,
    ) -> some View {
        modifier(StaggeredAnimationModifier(
            index: index,
            baseDelay: baseDelay,
            staggerDelay: staggerDelay,
        ))
    }
}

// MARK: - GPU Rasterization Modifier (Performance)

/// Wraps complex glass views in drawingGroup() for GPU rasterization
/// Use on complex card hierarchies with multiple blur/shadow effects
struct GPURasterizedModifier: ViewModifier {
    let opaque: Bool
    let colorMode: ColorRenderingMode

    func body(content: Content) -> some View {
        content
            .drawingGroup(opaque: opaque, colorMode: colorMode)
    }
}

extension View {
    /// Apply GPU rasterization for complex glass views
    /// Use on cards with multiple blur/shadow effects for 120Hz ProMotion performance
    ///
    /// Example:
    /// ```swift
    /// GlassListingCard(item: item)
    ///     .gpuRasterized()
    /// ```
    func gpuRasterized(
        opaque: Bool = false,
        colorMode: ColorRenderingMode = .nonLinear,
    ) -> some View {
        modifier(GPURasterizedModifier(opaque: opaque, colorMode: colorMode))
    }
}

// MARK: - High Performance Glass Effect

/// Optimized glass effect with optional GPU rasterization
/// Use for complex views that need 120Hz ProMotion smoothness
struct HighPerformanceGlassModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let useGPURasterization: Bool

    func body(content: Content) -> some View {
        let glassContent = content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.glassHighlight,
                                    Color.DesignSystem.glassBorder,
                                    Color.clear,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 1,
                        )
                },
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.1), radius: shadowRadius, y: shadowRadius / 2)

        if useGPURasterization {
            glassContent
                .drawingGroup()
        } else {
            glassContent
        }
    }
}

extension View {
    /// High-performance glass effect optimized for 120Hz ProMotion
    /// Enable GPU rasterization for cards in scrolling lists
    func highPerformanceGlass(
        cornerRadius: CGFloat = Spacing.radiusLG,
        shadowRadius: CGFloat = 12,
        useGPURasterization: Bool = false,
    ) -> some View {
        modifier(HighPerformanceGlassModifier(
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius,
            useGPURasterization: useGPURasterization,
        ))
    }
}

// MARK: - Optimized Shadow Modifier

/// Performance-optimized shadow for glass cards
/// Uses single shadow instead of multiple stacked shadows
struct OptimizedShadowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let y: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.15), radius: radius, y: y)
    }
}

extension View {
    /// Apply a single optimized shadow for better performance
    /// Use instead of multiple stacked shadows on frequently redrawn views
    func optimizedShadow(
        color: Color = .black,
        radius: CGFloat = 12,
        y: CGFloat = 6,
    ) -> some View {
        modifier(OptimizedShadowModifier(color: color, radius: radius, y: y))
    }
}

// MARK: - ProMotion Pulse Modifier (New in v27)

/// Smooth pulsing indicator animation at 120Hz
/// Use for online status indicators, activity indicators
struct ProMotionPulseModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    let intensity: Double
    let period: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if isActive, !reduceMotion {
            content
                .overlay(
                    TimelineView(.animation) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let pulse = (sin(time / period * .pi * 2) + 1) / 2

                        Circle()
                            .fill(color.opacity(pulse * intensity))
                            .scaleEffect(1 + pulse * 0.3)
                    },
                )
        } else {
            content
        }
    }
}

extension View {
    /// Apply a pulsing glow effect for status indicators
    func proMotionPulse(
        isActive: Bool = true,
        color: Color = .DesignSystem.brandGreen,
        intensity: Double = 0.6,
        period: Double = 1.5,
    ) -> some View {
        modifier(ProMotionPulseModifier(
            isActive: isActive,
            color: color,
            intensity: intensity,
            period: period,
        ))
    }
}

// MARK: - ProMotion Shake Modifier (New in v27)

/// Shake animation for validation errors
/// Triggers when the trigger value changes
struct ProMotionShakeModifier: ViewModifier {
    let trigger: Int
    let intensity: CGFloat

    @State private var shakeOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(x: shakeOffset)
            .onChange(of: trigger) { _, _ in
                guard !reduceMotion else { return }

                Task { @MainActor in
                    withAnimation(ProMotionAnimation.shake) {
                        shakeOffset = intensity
                    }
                    try? await Task.sleep(for: .milliseconds(80))
                    withAnimation(ProMotionAnimation.shake) {
                        shakeOffset = -intensity
                    }
                    try? await Task.sleep(for: .milliseconds(80))
                    withAnimation(ProMotionAnimation.shake) {
                        shakeOffset = intensity * 0.5
                    }
                    try? await Task.sleep(for: .milliseconds(80))
                    withAnimation(ProMotionAnimation.shake) {
                        shakeOffset = 0
                    }
                }
            }
    }
}

extension View {
    /// Apply shake animation when trigger value changes
    /// Use for validation errors, invalid input feedback
    func proMotionShake(trigger: Int, intensity: CGFloat = 10) -> some View {
        modifier(ProMotionShakeModifier(trigger: trigger, intensity: intensity))
    }
}

// MARK: - ProMotion Count Up Modifier (New in v27)

/// Animated number counter using ContentTransition
struct ProMotionCountUpModifier: ViewModifier {
    let countsDown: Bool

    func body(content: Content) -> some View {
        content
            .contentTransition(.numericText(countsDown: countsDown))
            .animation(ProMotionAnimation.counter, value: UUID())
    }
}

extension View {
    /// Apply animated numeric text transition
    /// Use for stat counters, like counts, badges
    func proMotionCountUp(countsDown: Bool = false) -> some View {
        modifier(ProMotionCountUpModifier(countsDown: countsDown))
    }
}

// MARK: - ProMotion Confetti Modifier (New in v27)

/// Triggers confetti celebration effect
struct ProMotionConfettiModifier: ViewModifier {
    @Binding var trigger: Bool
    let style: ConfettiStyle
    let duration: Double

    @State private var particles: [ConfettiParticle] = []
    @State private var animationStartTime: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum ConfettiStyle {
        case confetti
        case burst
        case stars
    }

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        let startX: CGFloat
        let startY: CGFloat
        let velocityX: CGFloat
        let velocityY: CGFloat
        let color: Color
        let size: CGFloat
        let rotation: Double
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if trigger, !reduceMotion {
                    GeometryReader { geometry in
                        TimelineView(.animation(minimumInterval: 1.0 / 120.0)) { timeline in
                            Canvas { context, _ in
                                guard let startTime = animationStartTime else { return }

                                let elapsed = timeline.date.timeIntervalSince(startTime)
                                let progress = min(elapsed / duration, 1.0)

                                for particle in particles {
                                    let x = particle.startX + particle.velocityX * elapsed
                                    let y = particle.startY + particle.velocityY * elapsed + 200 * elapsed * elapsed
                                    let opacity = 1.0 - progress

                                    guard opacity > 0 else { continue }

                                    var context = context
                                    context.opacity = opacity

                                    let rect = CGRect(
                                        x: x - particle.size / 2,
                                        y: y - particle.size / 2,
                                        width: particle.size,
                                        height: particle.size,
                                    )
                                    context.fill(Circle().path(in: rect), with: .color(particle.color))
                                }
                            }
                        }
                        .onAppear {
                            startConfetti(in: geometry.size)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    private func startConfetti(in size: CGSize) {
        animationStartTime = Date()

        let colors: [Color] = [
            .DesignSystem.brandPink,
            .DesignSystem.brandTeal,
            .DesignSystem.brandGreen,
            .DesignSystem.brandOrange,
            .yellow,
        ]

        particles = (0 ..< 50).map { _ in
            ConfettiParticle(
                startX: size.width / 2,
                startY: size.height / 2,
                velocityX: CGFloat.random(in: -200 ... 200),
                velocityY: CGFloat.random(in: -400 ... -100),
                color: colors.randomElement() ?? .DesignSystem.brandPink,
                size: CGFloat.random(in: 4 ... 10),
                rotation: Double.random(in: 0 ... 360),
            )
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            trigger = false
            particles = []
        }
    }
}

extension View {
    /// Trigger confetti celebration when binding becomes true
    func proMotionConfetti(
        trigger: Binding<Bool>,
        style: ProMotionConfettiModifier.ConfettiStyle = .confetti,
        duration: Double = 1.5,
    ) -> some View {
        modifier(ProMotionConfettiModifier(trigger: trigger, style: style, duration: duration))
    }
}

// Note: GlassBorderGlowModifier is defined in GlassAnimations.swift

// MARK: - Detail Section Modifier

/// Unified styling for detail view sections with staggered entrance animations
/// Use on sections within FoodItemDetailView, CommunityFridgeDetailView, etc.
struct DetailSectionModifier: ViewModifier {
    let index: Int
    @Binding var sectionsAppeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .padding(Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
            .opacity(sectionsAppeared ? 1 : 0)
            .offset(y: sectionsAppeared ? 0 : (reduceMotion ? 0 : 20))
            .animation(
                reduceMotion
                    ? .none
                    : .spring(response: 0.5, dampingFraction: 0.8)
                        .delay(0.1 + Double(index) * 0.05),
                value: sectionsAppeared,
            )
    }
}

extension View {
    /// Apply unified detail section styling with staggered entrance animation
    /// - Parameters:
    ///   - index: Section index for staggered animation delay
    ///   - sectionsAppeared: Binding to trigger entrance animation
    func detailSection(index: Int, sectionsAppeared: Binding<Bool>) -> some View {
        modifier(DetailSectionModifier(index: index, sectionsAppeared: sectionsAppeared))
    }

    /// Apply consistent navigation bar styling for detail views
    /// Uses ultraThinMaterial for glass effect consistency
    func detailNavigationBar() -> some View {
        self.navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
