//
//  ConfettiView.swift
//  FoodShare
//
//  Canvas-based confetti particle system for celebrations.
//  GPU-accelerated rendering with physics simulation.
//
//  Features:
//  - High-performance Canvas rendering
//  - Realistic physics (gravity, air resistance, rotation)
//  - Multiple confetti shapes (rectangles, circles, triangles)
//  - Brand color schemes
//  - Configurable particle count and spread
//


#if !SKIP
#if !SKIP
import SwiftUI

// MARK: - Confetti Configuration

/// Configuration for confetti behavior
struct ConfettiConfiguration {
    /// Number of confetti particles
    let particleCount: Int

    /// Duration of the animation in seconds
    let duration: TimeInterval

    /// Colors to use for confetti
    let colors: [Color]

    /// Initial velocity range
    let velocityRange: ClosedRange<CGFloat>

    /// Gravity strength
    let gravity: CGFloat

    /// Air resistance (0 = none, 1 = full stop)
    let airResistance: CGFloat

    /// Whether to play haptic feedback
    let enableHaptics: Bool

    /// Spread angle in radians (centered upward)
    let spreadAngle: CGFloat

    static let `default` = ConfettiConfiguration(
        particleCount: 100,
        duration: 3.0,
        colors: [
            Color.DesignSystem.primary,
            Color.DesignSystem.brandTeal,
            Color.DesignSystem.success,
            Color.DesignSystem.warning,
            .yellow,
            .orange,
            .pink
        ],
        velocityRange: 400 ... 800,
        gravity: 400,
        airResistance: 0.02,
        enableHaptics: true,
        spreadAngle: .pi / 3,
    )

    static let celebration = ConfettiConfiguration(
        particleCount: 150,
        duration: 4.0,
        colors: [
            .yellow, .orange, .red, .pink, .purple, .blue, .green
        ],
        velocityRange: 500 ... 1000,
        gravity: 350,
        airResistance: 0.015,
        enableHaptics: true,
        spreadAngle: .pi / 2,
    )

    static let subtle = ConfettiConfiguration(
        particleCount: 50,
        duration: 2.5,
        colors: [
            Color.DesignSystem.primary.opacity(0.8),
            Color.DesignSystem.brandTeal.opacity(0.8)
        ],
        velocityRange: 300 ... 600,
        gravity: 450,
        airResistance: 0.03,
        enableHaptics: false,
        spreadAngle: .pi / 4,
    )

    static let gold = ConfettiConfiguration(
        particleCount: 80,
        duration: 3.5,
        colors: [
            Color(red: 1.0, green: 0.84, blue: 0),
            Color(red: 0.85, green: 0.65, blue: 0.13),
            Color(red: 1.0, green: 0.94, blue: 0.6),
            .orange
        ],
        velocityRange: 400 ... 700,
        gravity: 380,
        airResistance: 0.02,
        enableHaptics: true,
        spreadAngle: .pi / 3,
    )
}

// MARK: - Confetti Particle

/// Individual confetti particle with physics properties
struct ConfettiParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    var rotation: Double
    var rotationVelocity: Double
    var color: Color
    var shape: ConfettiShape
    var size: CGSize
    var opacity = 1.0

    enum ConfettiShape: CaseIterable {
        case rectangle
        case circle
        case triangle
        case star

        static var random: ConfettiShape {
            allCases.randomElement() ?? .rectangle
        }
    }
}

// MARK: - Confetti View

/// GPU-accelerated confetti celebration view
struct ConfettiView: View {
    let configuration: ConfettiConfiguration
    let origin: CGPoint?

    @State private var particles: [ConfettiParticle] = []
    @State private var isAnimating = false
    @State private var animationStartTime: Date?

    init(
        configuration: ConfettiConfiguration = .default,
        origin: CGPoint? = nil,
    ) {
        self.configuration = configuration
        self.origin = origin
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 120)) { timeline in
                Canvas { context, _ in
                    guard isAnimating else { return }

                    for particle in particles {
                        drawParticle(particle, in: context)
                    }
                }
                .onChange(of: timeline.date) { _, _ in
                    updateParticles(in: geometry.size)
                }
            }
            .onAppear {
                startAnimation(in: geometry.size)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Particle Drawing

    private func drawParticle(_ particle: ConfettiParticle, in context: GraphicsContext) {
        var ctx = context

        // Apply transforms
        ctx.translateBy(x: particle.position.x, y: particle.position.y)
        ctx.rotate(by: .radians(particle.rotation))

        // Draw shape
        let rect = CGRect(
            x: -particle.size.width / 2,
            y: -particle.size.height / 2,
            width: particle.size.width,
            height: particle.size.height,
        )

        ctx.opacity = particle.opacity

        switch particle.shape {
        case .rectangle:
            ctx.fill(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(particle.color),
            )

        case .circle:
            ctx.fill(
                Path(ellipseIn: rect),
                with: .color(particle.color),
            )

        case .triangle:
            var path = Path()
            path.move(to: CGPoint(x: 0, y: -particle.size.height / 2))
            path.addLine(to: CGPoint(x: particle.size.width / 2, y: particle.size.height / 2))
            path.addLine(to: CGPoint(x: -particle.size.width / 2, y: particle.size.height / 2))
            path.closeSubpath()
            ctx.fill(path, with: .color(particle.color))

        case .star:
            let path = starPath(size: particle.size)
            ctx.fill(path, with: .color(particle.color))
        }
    }

    private func starPath(size: CGSize) -> Path {
        var path = Path()
        let center = CGPoint.zero
        let outerRadius = min(size.width, size.height) / 2
        let innerRadius = outerRadius * 0.4
        let points = 5

        for i in 0 ..< (points * 2) {
            let radius = i.isMultiple(of: 2) ? outerRadius : innerRadius
            let angle = (Double(i) / Double(points * 2)) * .pi * 2 - .pi / 2

            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius,
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

    // MARK: - Animation

    private func startAnimation(in size: CGSize) {
        let spawnPoint = origin ?? CGPoint(x: size.width / 2, y: size.height)

        // Create particles
        particles = (0 ..< configuration.particleCount).map { _ in
            createParticle(at: spawnPoint)
        }

        animationStartTime = Date()
        isAnimating = true

        // Play haptic
        if configuration.enableHaptics {
            AdvancedHapticEngine.shared.play(.confettiBurst)
        }

        // Schedule end
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(configuration.duration))
            isAnimating = false
            particles.removeAll()
        }
    }

    private func createParticle(at origin: CGPoint) -> ConfettiParticle {
        // Random angle within spread
        let baseAngle = -CGFloat.pi / 2 // Upward
        let angleOffset = CGFloat.random(in: -configuration.spreadAngle / 2 ... configuration.spreadAngle / 2)
        let angle = baseAngle + angleOffset

        // Random velocity within range
        let speed = CGFloat.random(in: configuration.velocityRange)

        // Random size
        let width = CGFloat.random(in: 6 ... 14)
        let height = CGFloat.random(in: 8 ... 18)

        return ConfettiParticle(
            position: origin,
            velocity: CGPoint(
                x: cos(angle) * speed,
                y: sin(angle) * speed,
            ),
            rotation: Double.random(in: 0 ... (.pi * 2)),
            rotationVelocity: Double.random(in: -8 ... 8),
            color: configuration.colors.randomElement() ?? .yellow,
            shape: .random,
            size: CGSize(width: width, height: height),
        )
    }

    private func updateParticles(in size: CGSize) {
        guard isAnimating, let startTime = animationStartTime else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let deltaTime: CGFloat = 1.0 / 120.0 // 120Hz updates

        for i in particles.indices {
            // Apply gravity
            particles[i].velocity.y += configuration.gravity * deltaTime

            // Apply air resistance
            particles[i].velocity.x *= (1.0 - configuration.airResistance)
            particles[i].velocity.y *= (1.0 - configuration.airResistance)

            // Update position
            particles[i].position.x += particles[i].velocity.x * deltaTime
            particles[i].position.y += particles[i].velocity.y * deltaTime

            // Update rotation
            particles[i].rotation += particles[i].rotationVelocity * deltaTime

            // Fade out near end
            let fadeStart = configuration.duration * 0.7
            if elapsed > fadeStart {
                let fadeProgress = (elapsed - fadeStart) / (configuration.duration - fadeStart)
                particles[i].opacity = max(0.0, 1.0 - fadeProgress)
            }
        }
    }
}

// MARK: - Confetti Trigger View Modifier

/// View modifier to trigger confetti on a condition
struct ConfettiModifier: ViewModifier {
    @Binding var isActive: Bool
    let configuration: ConfettiConfiguration
    let onComplete: (() -> Void)?

    func body(content: Content) -> some View {
        ZStack {
            content

            if isActive {
                ConfettiView(configuration: configuration)
                    .ignoresSafeArea()
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(configuration.duration))
                            isActive = false
                            onComplete?()
                        }
                    }
            }
        }
    }
}

extension View {
    /// Show confetti when condition is true
    func confetti(
        isActive: Binding<Bool>,
        configuration: ConfettiConfiguration = .default,
        onComplete: (() -> Void)? = nil,
    ) -> some View {
        modifier(ConfettiModifier(
            isActive: isActive,
            configuration: configuration,
            onComplete: onComplete,
        ))
    }

    /// Show celebration confetti
    func celebrationConfetti(isActive: Binding<Bool>) -> some View {
        confetti(isActive: isActive, configuration: .celebration)
    }

    /// Show gold confetti (for achievements)
    func goldConfetti(isActive: Binding<Bool>) -> some View {
        confetti(isActive: isActive, configuration: .gold)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Confetti") {
        struct ConfettiPreview: View {
            @State private var showDefault = false
            @State private var showCelebration = false
            @State private var showGold = false

            var body: some View {
                ZStack {
                    Color.DesignSystem.background.ignoresSafeArea()

                    VStack(spacing: Spacing.lg) {
                        Text("Confetti Effects")
                            .font(Font.DesignSystem.displaySmall)

                        Button("Default Confetti") {
                            showDefault = true
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Celebration") {
                            showCelebration = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)

                        Button("Gold (Achievement)") {
                            showGold = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .confetti(isActive: $showDefault)
                    .celebrationConfetti(isActive: $showCelebration)
                    .goldConfetti(isActive: $showGold)
                }
            }
        }

        return ConfettiPreview()
    }
#endif
#endif // !SKIP

#endif
