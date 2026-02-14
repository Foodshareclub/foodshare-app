//
//  ProMotionAnimations.swift
//  Foodshare
//
//  Liquid Glass v27 - ProMotion 120Hz Animation Optimizations
//  Frame-perfect animations using TimelineView, interpolating springs,
//  and GPU-accelerated rendering for silky smooth 120fps performance
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - ProMotion Animation Presets

/// Optimized animation presets for 120Hz ProMotion displays
/// Uses interpolating springs for instantaneous response
public enum ProMotionAnimation {
    /// Ultra-responsive spring for micro-interactions (buttons, toggles)
    /// Response time: ~150ms, feels instant on ProMotion
    public static let instant = Animation.interpolatingSpring(stiffness: 400, damping: 30)

    /// Quick spring for small UI changes (expand/collapse, selection)
    /// Response time: ~200ms
    public static let quick = Animation.interpolatingSpring(stiffness: 300, damping: 25)

    /// Smooth spring for medium transitions (cards, modals)
    /// Response time: ~300ms
    public static let smooth = Animation.interpolatingSpring(stiffness: 200, damping: 22)

    /// Fluid spring for larger animations (page transitions, reveals)
    /// Response time: ~400ms
    public static let fluid = Animation.interpolatingSpring(stiffness: 150, damping: 20)

    /// Bouncy spring for playful interactions (success states, celebrations)
    /// Response time: ~500ms with overshoot
    public static let bouncy = Animation.interpolatingSpring(stiffness: 250, damping: 15)

    /// Gentle spring for ambient animations (breathing, floating)
    /// Response time: ~600ms, very smooth
    public static let gentle = Animation.interpolatingSpring(stiffness: 100, damping: 18)

    /// Critical path animation - maximum responsiveness
    /// Use for tap feedback on critical actions
    public static let critical = Animation.interpolatingSpring(stiffness: 500, damping: 35)

    /// Glass material animation - optimized for blur transitions
    public static let glass = Animation.interpolatingSpring(stiffness: 180, damping: 24)

    // MARK: - New Animation Presets (v27)

    /// Celebration animation - bouncy with overshoot for success moments
    /// Use for badge unlocks, achievements, celebrations
    public static let celebration = Animation.interpolatingSpring(stiffness: 350, damping: 10)

    /// Counter animation - smooth number transitions
    /// Use for animated stat counters, like counts, message badges
    public static let counter = Animation.interpolatingSpring(stiffness: 280, damping: 25)

    /// Radius animation - smooth circular expansion
    /// Use for search radius, ripple effects, circular reveals
    public static let radius = Animation.interpolatingSpring(stiffness: 150, damping: 18)

    /// Shake animation - quick back-and-forth for validation errors
    /// Use for form validation errors, invalid input feedback
    public static let shake = Animation.interpolatingSpring(stiffness: 600, damping: 10)

    /// Entrance animation - optimized for content appearing
    /// Use for staggered list items, modal presentations
    public static let entrance = Animation.interpolatingSpring(stiffness: 200, damping: 22)

    /// Exit animation - quick fade out
    /// Use for dismissing content, removal transitions
    public static let exit = Animation.interpolatingSpring(stiffness: 350, damping: 28)
}

// MARK: - TimelineView Animation Controller

/// Frame-perfect animation controller using TimelineView
/// Runs at display refresh rate (120Hz on ProMotion)
struct ProMotionAnimationController<Content: View>: View {
    let minimumInterval: Double
    let paused: Bool
    @ViewBuilder let content: (TimelineViewDefaultContext) -> Content

    init(
        fps: Double = 120,
        paused: Bool = false,
        @ViewBuilder content: @escaping (TimelineViewDefaultContext) -> Content,
    ) {
        self.minimumInterval = 1.0 / fps
        self.paused = paused
        self.content = content
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: minimumInterval, paused: paused)) { context in
            content(context)
        }
    }
}

// MARK: - GPU-Accelerated Glass View

/// A wrapper that enables GPU rasterization for complex glass effects
/// Use this for views with multiple blur/shadow layers
struct GPUAcceleratedGlassView<Content: View>: View {
    let content: Content
    let isOpaque: Bool
    let colorMode: ColorRenderingMode

    init(
        isOpaque: Bool = false,
        colorMode: ColorRenderingMode = .nonLinear,
        @ViewBuilder content: () -> Content,
    ) {
        self.content = content()
        self.isOpaque = isOpaque
        self.colorMode = colorMode
    }

    var body: some View {
        content
            .drawingGroup(opaque: isOpaque, colorMode: colorMode)
    }
}

// MARK: - ProMotion Pulse Animation

/// Smooth pulsing animation optimized for 120Hz
/// Uses TimelineView for frame-perfect timing
struct ProMotionPulse: View {
    let color: Color
    let baseSize: CGFloat
    let amplitude: CGFloat
    let duration: Double

    init(
        color: Color = .DesignSystem.brandGreen,
        baseSize: CGFloat = 100,
        amplitude: CGFloat = 10,
        duration: Double = 2.0,
    ) {
        self.color = color
        self.baseSize = baseSize
        self.amplitude = amplitude
        self.duration = duration
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = time / duration
            let scale = 1.0 + (sin(phase * .pi * 2) * (amplitude / baseSize))
            let opacity = 0.6 + (sin(phase * .pi * 2) * 0.3)

            Circle()
                .fill(color.opacity(opacity))
                .frame(width: baseSize * scale, height: baseSize * scale)
                .blur(radius: 4)
        }
    }
}

// MARK: - ProMotion Glow Ring

/// Animated glowing ring optimized for 120Hz
struct ProMotionGlowRing: View {
    let color: Color
    let size: CGFloat
    let lineWidth: CGFloat
    let rotationSpeed: Double

    init(
        color: Color = .DesignSystem.brandGreen,
        size: CGFloat = 80,
        lineWidth: CGFloat = 3,
        rotationSpeed: Double = 2.0,
    ) {
        self.color = color
        self.size = size
        self.lineWidth = lineWidth
        self.rotationSpeed = rotationSpeed
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let rotation = Angle(degrees: (time / rotationSpeed) * 360)

            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    AngularGradient(
                        colors: [
                            color.opacity(0),
                            color.opacity(0.5),
                            color,
                        ],
                        center: .center,
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round),
                )
                .frame(width: size, height: size)
                .rotationEffect(rotation)
                .blur(radius: 1)
                .overlay(
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(color, style: StrokeStyle(lineWidth: lineWidth * 0.5, lineCap: .round))
                        .frame(width: size, height: size)
                        .rotationEffect(rotation),
                )
        }
    }
}

// MARK: - ProMotion Shimmer

/// Ultra-smooth shimmer effect for loading states
/// Renders at full 120fps on ProMotion displays
struct ProMotionShimmer: ViewModifier {
    let isActive: Bool
    let color: Color
    let speed: Double

    init(isActive: Bool = true, color: Color = .white, speed: Double = 1.5) {
        self.isActive = isActive
        self.color = color
        self.speed = speed
    }

    func body(content: Content) -> some View {
        if isActive {
            content
                .overlay(
                    GeometryReader { geometry in
                        TimelineView(.animation) { timeline in
                            let time = timeline.date.timeIntervalSinceReferenceDate
                            let phase = (time / speed).truncatingRemainder(dividingBy: 1.0)
                            let offset = (phase * 2 - 0.5) * geometry.size.width

                            LinearGradient(
                                colors: [
                                    color.opacity(0),
                                    color.opacity(0.3),
                                    color.opacity(0.5),
                                    color.opacity(0.3),
                                    color.opacity(0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            )
                            .frame(width: geometry.size.width * 0.6)
                            .offset(x: offset)
                            .blur(radius: 2)
                        }
                    }
                    .clipped()
                    .allowsHitTesting(false),
                )
        } else {
            content
        }
    }
}

// MARK: - ProMotion Float

/// Smooth floating animation at 120fps
struct ProMotionFloat: ViewModifier {
    let isActive: Bool
    let amplitude: CGFloat
    let period: Double

    init(isActive: Bool = true, amplitude: CGFloat = 6, period: Double = 3.0) {
        self.isActive = isActive
        self.amplitude = amplitude
        self.period = period
    }

    func body(content: Content) -> some View {
        if isActive {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let offset = sin(time / period * .pi * 2) * amplitude

                content
                    .offset(y: offset)
            }
        } else {
            content
        }
    }
}

// MARK: - ProMotion Breathing

/// Subtle breathing animation for ambient elements
struct ProMotionBreathing: ViewModifier {
    let isActive: Bool
    let scaleRange: ClosedRange<CGFloat>
    let opacityRange: ClosedRange<Double>
    let period: Double

    init(
        isActive: Bool = true,
        scaleRange: ClosedRange<CGFloat> = 0.98 ... 1.02,
        opacityRange: ClosedRange<Double> = 0.8 ... 1.0,
        period: Double = 4.0,
    ) {
        self.isActive = isActive
        self.scaleRange = scaleRange
        self.opacityRange = opacityRange
        self.period = period
    }

    func body(content: Content) -> some View {
        if isActive {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let phase = (sin(time / period * .pi * 2) + 1) / 2 // 0...1
                let scale = scaleRange.lowerBound + (scaleRange.upperBound - scaleRange.lowerBound) * phase
                let opacity = opacityRange.lowerBound + (opacityRange.upperBound - opacityRange.lowerBound) * phase

                content
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        } else {
            content
        }
    }
}

// MARK: - ProMotion Color Cycle

/// Smooth color cycling for dynamic backgrounds
struct ProMotionColorCycle: ViewModifier {
    let colors: [Color]
    let duration: Double

    init(colors: [Color], duration: Double = 5.0) {
        self.colors = colors.isEmpty ? [.clear] : colors
        self.duration = duration
    }

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = (time / duration).truncatingRemainder(dividingBy: 1.0)
            let colorIndex = Int(phase * Double(colors.count))
            let nextIndex = (colorIndex + 1) % colors.count
            let localPhase = (phase * Double(colors.count)).truncatingRemainder(dividingBy: 1.0)

            let currentColor = colors[colorIndex]
            let nextColor = colors[nextIndex]

            content
                .foregroundStyle(
                    currentColor.interpolate(to: nextColor, fraction: localPhase),
                )
        }
    }
}

// MARK: - ProMotion Morphing Border

/// Animated morphing glass border at 120fps
struct ProMotionMorphingBorder: ViewModifier {
    let colors: [Color]
    let lineWidth: CGFloat
    let cornerRadius: CGFloat
    let speed: Double

    init(
        colors: [Color] = [.DesignSystem.brandPink, .DesignSystem.brandTeal, .DesignSystem.brandGreen],
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = CornerRadius.large,
        speed: Double = 3.0,
    ) {
        self.colors = colors
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
        self.speed = speed
    }

    func body(content: Content) -> some View {
        content
            .overlay(
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let rotation = Angle(degrees: (time / speed) * 360)

                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            AngularGradient(
                                colors: colors.isEmpty ? [.clear] : colors + [colors[0]],
                                center: .center,
                                angle: rotation,
                            ),
                            lineWidth: lineWidth,
                        )
                        .blur(radius: 1)
                },
            )
    }
}

// MARK: - Canvas-Based Particle System

/// GPU-accelerated particle system using Canvas
struct ProMotionParticleSystem: View {
    let particleCount: Int
    let color: Color
    let size: CGFloat

    @State private var particles: [Particle] = []

    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var velocityX: CGFloat
        var velocityY: CGFloat
        var size: CGFloat
        var opacity: Double
    }

    init(particleCount: Int = 20, color: Color = .white, size: CGFloat = 4) {
        self.particleCount = particleCount
        self.color = color
        self.size = size
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    for particle in particles {
                        let rect = CGRect(
                            x: particle.x - particle.size / 2,
                            y: particle.y - particle.size / 2,
                            width: particle.size,
                            height: particle.size,
                        )
                        context.opacity = particle.opacity
                        context.fill(
                            Circle().path(in: rect),
                            with: .color(color),
                        )
                    }
                }
                .onChange(of: timeline.date) { _, _ in
                    updateParticles(in: geometry.size)
                }
            }
            .onAppear {
                initializeParticles(in: geometry.size)
            }
        }
    }

    private func initializeParticles(in size: CGSize) {
        particles = (0 ..< particleCount).map { _ in
            Particle(
                x: CGFloat.random(in: 0 ... size.width),
                y: CGFloat.random(in: 0 ... size.height),
                velocityX: CGFloat.random(in: -0.5 ... 0.5),
                velocityY: CGFloat.random(in: -0.3 ... 0.3),
                size: CGFloat.random(in: 2 ... self.size),
                opacity: Double.random(in: 0.3 ... 0.7),
            )
        }
    }

    private func updateParticles(in size: CGSize) {
        for i in particles.indices {
            particles[i].x += particles[i].velocityX
            particles[i].y += particles[i].velocityY

            // Wrap around edges
            if particles[i].x < 0 { particles[i].x = size.width }
            if particles[i].x > size.width { particles[i].x = 0 }
            if particles[i].y < 0 { particles[i].y = size.height }
            if particles[i].y > size.height { particles[i].y = 0 }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply ProMotion-optimized shimmer effect
    func proMotionShimmer(isActive: Bool = true, color: Color = .white, speed: Double = 1.5) -> some View {
        modifier(ProMotionShimmer(isActive: isActive, color: color, speed: speed))
    }

    /// Apply ProMotion-optimized floating animation
    func proMotionFloat(isActive: Bool = true, amplitude: CGFloat = 6, period: Double = 3.0) -> some View {
        modifier(ProMotionFloat(isActive: isActive, amplitude: amplitude, period: period))
    }

    /// Apply ProMotion-optimized breathing animation
    func proMotionBreathing(
        isActive: Bool = true,
        scaleRange: ClosedRange<CGFloat> = 0.98 ... 1.02,
        opacityRange: ClosedRange<Double> = 0.8 ... 1.0,
        period: Double = 4.0,
    ) -> some View {
        modifier(ProMotionBreathing(
            isActive: isActive,
            scaleRange: scaleRange,
            opacityRange: opacityRange,
            period: period,
        ))
    }

    /// Apply ProMotion-optimized morphing border
    func proMotionMorphingBorder(
        colors: [Color] = [.DesignSystem.brandPink, .DesignSystem.brandTeal, .DesignSystem.brandGreen],
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = CornerRadius.large,
        speed: Double = 3.0,
    ) -> some View {
        modifier(ProMotionMorphingBorder(
            colors: colors,
            lineWidth: lineWidth,
            cornerRadius: cornerRadius,
            speed: speed,
        ))
    }

    /// Wrap view in GPU-accelerated rendering group
    func gpuAccelerated(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear) -> some View {
        GPUAcceleratedGlassView(isOpaque: opaque, colorMode: colorMode) {
            self
        }
    }

    /// Apply instant ProMotion spring animation
    func instantAnimation() -> some View {
        animation(ProMotionAnimation.instant, value: UUID())
    }

    /// Apply quick ProMotion spring animation with explicit value
    func proMotionAnimation(_ animation: Animation = ProMotionAnimation.smooth, value: some Equatable) -> some View {
        self.animation(animation, value: value)
    }
}

// MARK: - Color Interpolation Helper

extension Color {
    /// Interpolate between two colors
    func interpolate(to other: Color, fraction: Double) -> Color {
        let clampedFraction = max(0, min(1, fraction))

        // Use UIColor for component extraction
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        UIColor(self).getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        UIColor(other).getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let r = r1 + (r2 - r1) * clampedFraction
        let g = g1 + (g2 - g1) * clampedFraction
        let b = b1 + (b2 - b1) * clampedFraction
        let a = a1 + (a2 - a1) * clampedFraction

        return Color(red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - ProMotion Button Style

/// Button style optimized for 120Hz with instant feedback
struct ProMotionButtonStyle: ButtonStyle {
    let scaleEffect: CGFloat
    let opacityEffect: Double

    init(scaleEffect: CGFloat = 0.96, opacityEffect: Double = 0.9) {
        self.scaleEffect = scaleEffect
        self.opacityEffect = opacityEffect
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : 1.0)
            .opacity(configuration.isPressed ? opacityEffect : 1.0)
            .animation(ProMotionAnimation.instant, value: configuration.isPressed)
    }
}

// MARK: - Legacy Animation Migration Helpers

extension Animation {
    /// ProMotion replacement for .easeInOut(duration:)
    /// Maps durations to appropriate spring animations for 120Hz smoothness
    static func proMotion(duration: Double) -> Animation {
        switch duration {
        case ..<0.15:
            ProMotionAnimation.critical
        case 0.15 ..< 0.25:
            ProMotionAnimation.instant
        case 0.25 ..< 0.35:
            ProMotionAnimation.quick
        case 0.35 ..< 0.5:
            ProMotionAnimation.smooth
        case 0.5 ..< 0.7:
            ProMotionAnimation.fluid
        default:
            ProMotionAnimation.gentle
        }
    }

    /// ProMotion replacement for .easeOut(duration:)
    static func proMotionOut(duration: Double) -> Animation {
        switch duration {
        case ..<0.2:
            ProMotionAnimation.exit
        case 0.2 ..< 0.4:
            ProMotionAnimation.quick
        default:
            ProMotionAnimation.smooth
        }
    }

    /// ProMotion replacement for .easeIn(duration:)
    static func proMotionIn(duration: Double) -> Animation {
        switch duration {
        case ..<0.3:
            ProMotionAnimation.instant
        case 0.3 ..< 0.5:
            ProMotionAnimation.entrance
        default:
            ProMotionAnimation.fluid
        }
    }

    /// ProMotion replacement for repeating animations
    /// Returns a TimelineView-based continuous animation duration
    static func proMotionContinuous(duration: Double) -> Double {
        // For continuous animations, return the period for TimelineView
        duration
    }
}

// MARK: - ProMotion Animation Wrappers

/// Wrapper for withAnimation that uses ProMotion presets
@MainActor
public func withProMotion<Result>(
    _ animation: Animation = ProMotionAnimation.smooth,
    _ body: () throws -> Result,
) rethrows -> Result {
    try withAnimation(animation, body)
}

/// Async version of withProMotion
/// Note: SwiftUI's withAnimation doesn't support async closures directly,
/// so we apply animation before awaiting the result
@MainActor
public func withProMotion<Result>(
    _ animation: Animation = ProMotionAnimation.smooth,
    _ body: () async throws -> Result,
) async rethrows -> Result {
    // For async operations, we can't use withAnimation directly
    // The animation should be applied to state changes after the async work
    try await body()
}

// MARK: - Animation Context

/// Provides animation context based on user preferences and device capabilities
@MainActor @Observable
public final class AnimationContext {
    public static let shared = AnimationContext()

    /// Whether to use reduced motion (respects user accessibility settings)
    public var prefersReducedMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    /// Whether the device supports ProMotion (120Hz)
    public var supportsProMotion: Bool {
        UIScreen.main.maximumFramesPerSecond >= 120
    }

    /// Whether animations should be GPU accelerated (complex effects)
    public var shouldUseGPUAcceleration: Bool {
        !prefersReducedMotion && supportsProMotion
    }

    /// Recommended animation for the current context
    public func animation(for intent: AnimationIntent) -> Animation {
        guard !prefersReducedMotion else {
            return .linear(duration: 0.01) // Near-instant for reduced motion
        }

        switch intent {
        case .microInteraction:
            return ProMotionAnimation.instant
        case .stateChange:
            return ProMotionAnimation.quick
        case .transition:
            return ProMotionAnimation.smooth
        case .presentation:
            return ProMotionAnimation.fluid
        case .celebration:
            return ProMotionAnimation.celebration
        case .feedback:
            return ProMotionAnimation.critical
        }
    }

    public enum AnimationIntent {
        case microInteraction // Button presses, toggles
        case stateChange // Expand/collapse, selection
        case transition // Card reveals, modals
        case presentation // Page transitions
        case celebration // Success states, achievements
        case feedback // Error shakes, validation
    }

    private init() {}
}

// MARK: - Preview
// Preview disabled due to Swift 6.2 compilation issues
// #Preview("ProMotion Animations") { ... }
