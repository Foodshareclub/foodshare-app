//
//  GlassCelebration.swift
//  Foodshare
//
//  Liquid Glass v27 - Celebration Effects
//  GPU-accelerated particle systems for success bursts, confetti,
//  badge unlocks, and gamification celebrations
//


#if !SKIP
import SwiftUI

#if !SKIP

// MARK: - Glass Celebration

/// A GPU-accelerated celebration effect with multiple particle styles
///
/// Use for success moments like badge unlocks, achievement completions,
/// arrangement confirmations, and milestone celebrations.
///
/// Example usage:
/// ```swift
/// GlassCelebration(isActive: $showCelebration, style: .confetti)
/// GlassCelebration(isActive: $showSuccess, style: .burst(color: .DesignSystem.brandGreen))
/// GlassCelebration(isActive: $showStars, style: .stars)
/// ```
struct GlassCelebration: View {
    @Binding var isActive: Bool
    let style: CelebrationStyle
    let duration: Double
    let onComplete: (() -> Void)?

    @State private var particles: [CelebrationParticle] = []
    @State private var animationStartTime: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    // MARK: - Initialization

    init(
        isActive: Binding<Bool>,
        style: CelebrationStyle = .confetti,
        duration: Double = 2.0,
        onComplete: (() -> Void)? = nil,
    ) {
        self._isActive = isActive
        self.style = style
        self.duration = duration
        self.onComplete = onComplete
    }

    // MARK: - Body

    var body: some View {
        if reduceMotion {
            // Simple flash for reduced motion
            if isActive {
                Color.white.opacity(0.3)
                    .ignoresSafeArea()
                    .onAppear {
                        Task { @MainActor in
                            #if SKIP
                            try? await Task.sleep(nanoseconds: UInt64(300 * 1_000_000))
                            #else
                            try? await Task.sleep(for: .milliseconds(300))
                            #endif
                            isActive = false
                            onComplete?()
                        }
                    }
            }
        } else {
            GeometryReader { geometry in
                TimelineView(.animation(minimumInterval: 1.0 / 120.0, paused: !isActive)) { timeline in
                    Canvas { context, size in
                        guard isActive else { return }

                        let elapsed = timeline.date.timeIntervalSince(animationStartTime ?? timeline.date)
                        let progress = min(elapsed / duration, 1.0)

                        for particle in particles {
                            drawParticle(particle, context: context, size: size, progress: progress)
                        }
                    }
                }
                .onChange(of: isActive) { _, newValue in
                    if newValue {
                        startCelebration(in: geometry.size)
                    } else {
                        particles = []
                        animationStartTime = nil
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }

    // MARK: - Particle Generation

    private func startCelebration(in size: CGSize) {
        animationStartTime = Date()
        particles = generateParticles(for: style, in: size)

        // Auto-dismiss after duration
        Task { @MainActor in
            #if SKIP
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            #else
            try? await Task.sleep(for: .seconds(duration))
            #endif
            isActive = false
            onComplete?()
        }
    }

    private func generateParticles(for style: CelebrationStyle, in size: CGSize) -> [CelebrationParticle] {
        switch style {
        case .confetti:
            generateConfetti(in: size)
        case let .burst(color):
            generateBurst(color: color, in: size)
        case .stars:
            generateStars(in: size)
        case .hearts:
            generateHearts(in: size)
        case .sparkles:
            generateSparkles(in: size)
        case .fireworks:
            generateFireworks(in: size)
        }
    }

    private func generateConfetti(in size: CGSize) -> [CelebrationParticle] {
        let colors: [Color] = [
            .DesignSystem.brandPink,
            .DesignSystem.brandTeal,
            .DesignSystem.brandGreen,
            .DesignSystem.brandOrange,
            .DesignSystem.brandBlue,
            .yellow,
        ]

        return (0 ..< 80).map { _ in
            CelebrationParticle(
                x: CGFloat.random(in: 0 ... size.width),
                y: -20,
                velocityX: CGFloat.random(in: -100 ... 100),
                velocityY: CGFloat.random(in: 200 ... 600),
                rotation: CGFloat.random(in: 0 ... 360),
                rotationSpeed: CGFloat.random(in: -720 ... 720),
                size: CGFloat.random(in: 6 ... 12),
                color: colors.randomElement() ?? .DesignSystem.brandPink,
                shape: [.rectangle, .circle, .triangle].randomElement() ?? .circle,
                gravity: 400,
                drag: 0.99,
            )
        }
    }

    private func generateBurst(color: Color, in size: CGSize) -> [CelebrationParticle] {
        let centerX = size.width / 2
        let centerY = size.height / 2

        return (0 ..< 60).map { i in
            let angle = (Double(i) / 60.0) * 2 * .pi + Double.random(in: -0.2 ... 0.2)
            let speed = CGFloat.random(in: 200 ... 500)

            return CelebrationParticle(
                x: centerX,
                y: centerY,
                velocityX: cos(angle) * speed,
                velocityY: sin(angle) * speed,
                rotation: 0,
                rotationSpeed: CGFloat.random(in: -360 ... 360),
                size: CGFloat.random(in: 4 ... 10),
                color: color.opacity(Double.random(in: 0.6 ... 1.0)),
                shape: .circle,
                gravity: 200,
                drag: 0.96,
            )
        }
    }

    private func generateStars(in size: CGSize) -> [CelebrationParticle] {
        (0 ..< 40).map { _ in
            CelebrationParticle(
                x: CGFloat.random(in: 0 ... size.width),
                y: CGFloat.random(in: 0 ... size.height),
                velocityX: CGFloat.random(in: -50 ... 50),
                velocityY: CGFloat.random(in: -100 ... 100),
                rotation: CGFloat.random(in: 0 ... 360),
                rotationSpeed: CGFloat.random(in: -180 ... 180),
                size: CGFloat.random(in: 8 ... 16),
                color: .yellow.opacity(Double.random(in: 0.7 ... 1.0)),
                shape: .star,
                gravity: 0,
                drag: 0.98,
            )
        }
    }

    private func generateHearts(in size: CGSize) -> [CelebrationParticle] {
        let colors: [Color] = [
            .DesignSystem.brandPink,
            .DesignSystem.error,
            .pink,
        ]

        return (0 ..< 30).map { _ in
            CelebrationParticle(
                x: CGFloat.random(in: 0 ... size.width),
                y: size.height + 20,
                velocityX: CGFloat.random(in: -80 ... 80),
                velocityY: CGFloat.random(in: -400 ... -200),
                rotation: CGFloat.random(in: -20 ... 20),
                rotationSpeed: CGFloat.random(in: -90 ... 90),
                size: CGFloat.random(in: 12 ... 24),
                color: colors.randomElement() ?? .DesignSystem.brandPink,
                shape: .heart,
                gravity: 150,
                drag: 0.98,
            )
        }
    }

    private func generateSparkles(in size: CGSize) -> [CelebrationParticle] {
        (0 ..< 50).map { _ in
            CelebrationParticle(
                x: CGFloat.random(in: 0 ... size.width),
                y: CGFloat.random(in: 0 ... size.height),
                velocityX: 0,
                velocityY: 0,
                rotation: 0,
                rotationSpeed: 0,
                size: CGFloat.random(in: 2 ... 8),
                color: .white,
                shape: .sparkle,
                gravity: 0,
                drag: 1.0,
            )
        }
    }

    private func generateFireworks(in size: CGSize) -> [CelebrationParticle] {
        let colors: [Color] = [.DesignSystem.brandPink, .DesignSystem.brandTeal, .DesignSystem.brandGreen]
        var particles: [CelebrationParticle] = []

        // Generate 3 firework bursts at random positions
        for _ in 0 ..< 3 {
            let centerX = CGFloat.random(in: size.width * 0.2 ... size.width * 0.8)
            let centerY = CGFloat.random(in: size.height * 0.2 ... size.height * 0.5)
            let color = colors.randomElement() ?? .DesignSystem.brandPink

            for i in 0 ..< 20 {
                let angle = (Double(i) / 20.0) * 2 * .pi
                let speed = CGFloat.random(in: 150 ... 300)

                particles.append(CelebrationParticle(
                    x: centerX,
                    y: centerY,
                    velocityX: cos(angle) * speed,
                    velocityY: sin(angle) * speed,
                    rotation: 0,
                    rotationSpeed: 0,
                    size: CGFloat.random(in: 3 ... 6),
                    color: color,
                    shape: .circle,
                    gravity: 100,
                    drag: 0.97,
                ))
            }
        }

        return particles
    }

    // MARK: - Particle Drawing

    private func drawParticle(
        _ particle: CelebrationParticle,
        context: GraphicsContext,
        size: CGSize,
        progress: Double,
    ) {
        let elapsed = progress * duration

        // Calculate position with physics
        var x = particle.x + particle.velocityX * elapsed - 0.5 * particle.drag * particle.velocityX * elapsed * elapsed
        var y = particle.y + particle.velocityY * elapsed + 0.5 * particle.gravity * elapsed * elapsed

        // Apply drag to velocity effect
        let dragFactor = pow(particle.drag, elapsed * 60) // 60 fps equivalent

        // Rotation
        let rotation = Angle(degrees: particle.rotation + particle.rotationSpeed * elapsed)

        // Fade out in last 30% of animation
        let opacity = progress > 0.7 ? (1.0 - progress) / 0.3 : 1.0

        // Scale down slightly at the end
        let scale = progress > 0.8 ? 1.0 - (progress - 0.8) / 0.2 * 0.5 : 1.0

        guard opacity > 0, x > -50, x < size.width + 50, y > -50, y < size.height + 50 else { return }

        var context = context
        context.opacity = opacity

        let particleSize = particle.size * scale
        let rect = CGRect(
            x: x - particleSize / 2,
            y: y - particleSize / 2,
            width: particleSize,
            height: particleSize,
        )

        // Transform for rotation
        context.translateBy(x: x, y: y)
        context.rotate(by: rotation)
        context.translateBy(x: -x, y: -y)

        switch particle.shape {
        case .circle:
            context.fill(Circle().path(in: rect), with: .color(particle.color))

        case .rectangle:
            let aspectRatio = CGFloat.random(in: 0.3 ... 0.7)
            let adjustedRect = CGRect(
                x: rect.minX,
                y: rect.minY,
                width: rect.width,
                height: rect.height * aspectRatio,
            )
            context.fill(Rectangle().path(in: adjustedRect), with: .color(particle.color))

        case .triangle:
            let path = Path { p in
                p.move(to: CGPoint(x: x, y: y - particleSize / 2))
                p.addLine(to: CGPoint(x: x - particleSize / 2, y: y + particleSize / 2))
                p.addLine(to: CGPoint(x: x + particleSize / 2, y: y + particleSize / 2))
                p.closeSubpath()
            }
            context.fill(path, with: .color(particle.color))

        case .star:
            let path = starPath(center: CGPoint(x: x, y: y), size: particleSize)
            context.fill(path, with: .color(particle.color))

        case .heart:
            let path = heartPath(center: CGPoint(x: x, y: y), size: particleSize)
            context.fill(path, with: .color(particle.color))

        case .sparkle:
            // Sparkle is a twinkling effect
            let twinkle = sin(elapsed * 10 + Double(particle.x)) * 0.5 + 0.5
            context.opacity = opacity * twinkle
            context.fill(Circle().path(in: rect), with: .color(particle.color))
        }
    }

    private func starPath(center: CGPoint, size: CGFloat) -> Path {
        let points = 5
        var path = Path()
        let outerRadius = size / 2
        let innerRadius = size / 4

        for i in 0 ..< points * 2 {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = Double(i) / Double(points * 2) * 2 * .pi - .pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius,
            )
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func heartPath(center: CGPoint, size: CGFloat) -> Path {
        let width = size
        let height = size

        return Path { path in
            path.move(to: CGPoint(x: center.x, y: center.y + height * 0.3))

            path.addCurve(
                to: CGPoint(x: center.x - width * 0.5, y: center.y - height * 0.1),
                control1: CGPoint(x: center.x - width * 0.2, y: center.y + height * 0.1),
                control2: CGPoint(x: center.x - width * 0.5, y: center.y + height * 0.1),
            )

            path.addCurve(
                to: CGPoint(x: center.x, y: center.y - height * 0.35),
                control1: CGPoint(x: center.x - width * 0.5, y: center.y - height * 0.3),
                control2: CGPoint(x: center.x - width * 0.2, y: center.y - height * 0.35),
            )

            path.addCurve(
                to: CGPoint(x: center.x + width * 0.5, y: center.y - height * 0.1),
                control1: CGPoint(x: center.x + width * 0.2, y: center.y - height * 0.35),
                control2: CGPoint(x: center.x + width * 0.5, y: center.y - height * 0.3),
            )

            path.addCurve(
                to: CGPoint(x: center.x, y: center.y + height * 0.3),
                control1: CGPoint(x: center.x + width * 0.5, y: center.y + height * 0.1),
                control2: CGPoint(x: center.x + width * 0.2, y: center.y + height * 0.1),
            )
        }
    }
}

// MARK: - Celebration Particle

private struct CelebrationParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let velocityX: CGFloat
    let velocityY: CGFloat
    let rotation: CGFloat
    let rotationSpeed: CGFloat
    let size: CGFloat
    let color: Color
    let shape: ParticleShape
    let gravity: CGFloat
    let drag: CGFloat
}

// MARK: - Particle Shape

private enum ParticleShape {
    case circle
    case rectangle
    case triangle
    case star
    case heart
    case sparkle
}

// MARK: - Celebration Style

extension GlassCelebration {
    /// Celebration effect styles
    enum CelebrationStyle {
        /// Classic confetti falling from top
        case confetti

        /// Radial burst from center with custom color
        case burst(color: Color)

        /// Floating stars
        case stars

        /// Rising hearts
        case hearts

        /// Twinkling sparkles
        case sparkles

        /// Multiple firework bursts
        case fireworks
    }
}

// MARK: - Celebration Trigger Modifier

/// View modifier for easily adding celebration effects
struct CelebrationModifier: ViewModifier {
    @Binding var isActive: Bool
    let style: GlassCelebration.CelebrationStyle
    let duration: Double

    func body(content: Content) -> some View {
        content
            .overlay {
                GlassCelebration(
                    isActive: $isActive,
                    style: style,
                    duration: duration,
                )
            }
    }
}

extension View {
    /// Add a celebration overlay that triggers when binding becomes true
    func celebration(
        isActive: Binding<Bool>,
        style: GlassCelebration.CelebrationStyle = .confetti,
        duration: Double = 2.0,
    ) -> some View {
        modifier(CelebrationModifier(isActive: isActive, style: style, duration: duration))
    }
}

// MARK: - Preview

#Preview("Glass Celebration") {
    struct PreviewWrapper: View {
        @State private var showConfetti = false
        @State private var showBurst = false
        @State private var showStars = false
        @State private var showHearts = false
        @State private var showSparkles = false
        @State private var showFireworks = false

        var body: some View {
            ZStack {
                Color.DesignSystem.background
                    .ignoresSafeArea()

                VStack(spacing: Spacing.lg) {
                    Text("Glass Celebration")
                        .font(.DesignSystem.displayMedium)
                        .foregroundStyle(Color.DesignSystem.textPrimary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: Spacing.md) {
                        CelebrationButton(title: "Confetti", isActive: $showConfetti)
                        CelebrationButton(title: "Burst", isActive: $showBurst)
                        CelebrationButton(title: "Stars", isActive: $showStars)
                        CelebrationButton(title: "Hearts", isActive: $showHearts)
                        CelebrationButton(title: "Sparkles", isActive: $showSparkles)
                        CelebrationButton(title: "Fireworks", isActive: $showFireworks)
                    }
                    .padding()
                }

                // Celebration overlays
                GlassCelebration(isActive: $showConfetti, style: .confetti)
                GlassCelebration(isActive: $showBurst, style: .burst(color: .DesignSystem.brandGreen))
                GlassCelebration(isActive: $showStars, style: .stars)
                GlassCelebration(isActive: $showHearts, style: .hearts)
                GlassCelebration(isActive: $showSparkles, style: .sparkles)
                GlassCelebration(isActive: $showFireworks, style: .fireworks)
            }
        }
    }

    struct CelebrationButton: View {
        let title: String
        @Binding var isActive: Bool

        var body: some View {
            Button {
                isActive = true
            } label: {
                Text(title)
                    .font(.DesignSystem.bodyLarge)
                    .foregroundStyle(Color.DesignSystem.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    #if !SKIP
                    .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .background(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
        }
    }

    return PreviewWrapper()
}
#endif

#endif
