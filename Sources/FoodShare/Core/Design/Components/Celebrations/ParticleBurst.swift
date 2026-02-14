//
//  ParticleBurst.swift
//  FoodShare
//
//  Radial particle burst effect for tap feedback and celebrations.
//  GPU-accelerated Canvas rendering at 120fps for ProMotion displays.
//
//  Usage:
//  - Tap feedback on action buttons
//  - Success state confirmations
//  - Like/Save button responses
//  - Achievement unlocks
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Burst Configuration

public struct ParticleBurstConfiguration: Sendable {
    public let particleCount: Int
    public let colors: [Color]
    public let minSize: CGFloat
    public let maxSize: CGFloat
    public let minVelocity: CGFloat
    public let maxVelocity: CGFloat
    public let duration: TimeInterval
    public let fadeOutDuration: TimeInterval
    public let gravity: CGFloat
    public let spread: Double // Angle spread in radians (2π = full circle)

    public init(
        particleCount: Int = 12,
        colors: [Color] = [.DesignSystem.brandGreen, .DesignSystem.brandPink, .DesignSystem.brandTeal],
        minSize: CGFloat = 4,
        maxSize: CGFloat = 8,
        minVelocity: CGFloat = 150,
        maxVelocity: CGFloat = 300,
        duration: TimeInterval = 0.6,
        fadeOutDuration: TimeInterval = 0.3,
        gravity: CGFloat = 200,
        spread: Double = .pi * 2,
    ) {
        self.particleCount = particleCount
        self.colors = colors
        self.minSize = minSize
        self.maxSize = maxSize
        self.minVelocity = minVelocity
        self.maxVelocity = maxVelocity
        self.duration = duration
        self.fadeOutDuration = fadeOutDuration
        self.gravity = gravity
        self.spread = spread
    }

    // Preset configurations
    public static let `default` = ParticleBurstConfiguration()

    public static let subtle = ParticleBurstConfiguration(
        particleCount: 6,
        minSize: 3,
        maxSize: 5,
        minVelocity: 80,
        maxVelocity: 150,
        duration: 0.4,
    )

    public static let celebration = ParticleBurstConfiguration(
        particleCount: 24,
        minSize: 5,
        maxSize: 12,
        minVelocity: 200,
        maxVelocity: 400,
        duration: 0.8,
        fadeOutDuration: 0.4,
    )

    public static let heart = ParticleBurstConfiguration(
        particleCount: 8,
        colors: [.DesignSystem.brandPink, .red, .DesignSystem.brandPink.opacity(0.7)],
        minSize: 6,
        maxSize: 10,
        minVelocity: 100,
        maxVelocity: 200,
        duration: 0.5,
        gravity: 150,
        spread: .pi * 2,
    )

    public static let spark = ParticleBurstConfiguration(
        particleCount: 16,
        colors: [.yellow, .orange, .white],
        minSize: 2,
        maxSize: 4,
        minVelocity: 200,
        maxVelocity: 350,
        duration: 0.4,
        fadeOutDuration: 0.2,
        gravity: 50,
    )

    public static let confetti = ParticleBurstConfiguration(
        particleCount: 20,
        colors: [.red, .orange, .yellow, .green, .blue, .purple, .pink],
        minSize: 4,
        maxSize: 8,
        minVelocity: 150,
        maxVelocity: 300,
        duration: 1.0,
        fadeOutDuration: 0.5,
        gravity: 300,
    )
}

// MARK: - Burst Particle

struct BurstParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var velocityX: CGFloat
    var velocityY: CGFloat
    var size: CGFloat
    var opacity: Double
    var color: Color
    var rotation: Double
    var rotationVelocity: Double
}

// MARK: - Particle Burst View

public struct ParticleBurstView: View {
    let origin: CGPoint
    let config: ParticleBurstConfiguration
    let onComplete: (() -> Void)?

    @State private var particles: [BurstParticle] = []
    @State private var startTime: Date = .now
    @State private var isActive = false

    public init(
        origin: CGPoint,
        config: ParticleBurstConfiguration = .default,
        onComplete: (() -> Void)? = nil,
    ) {
        self.origin = origin
        self.config = config
        self.onComplete = onComplete
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, _ in
                let elapsed = timeline.date.timeIntervalSince(startTime)

                for particle in particles {
                    guard particle.opacity > 0 else { continue }

                    let rect = CGRect(
                        x: particle.x - particle.size / 2,
                        y: particle.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size,
                    )

                    context.opacity = particle.opacity
                    context.rotate(by: Angle(radians: particle.rotation))

                    // Draw as rounded rect for more interesting shapes
                    let path = RoundedRectangle(cornerRadius: particle.size / 4)
                        .path(in: rect)
                    context.fill(path, with: .color(particle.color))
                }
            }
            .onChange(of: timeline.date) { _, date in
                updateParticles(at: date)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            startBurst()
        }
    }

    private func startBurst() {
        startTime = .now
        isActive = true
        particles = createParticles()

        // Trigger haptic feedback
        HapticManager.light()

        // Schedule completion
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(config.duration + config.fadeOutDuration))
            isActive = false
            onComplete?()
        }
    }

    private func createParticles() -> [BurstParticle] {
        (0 ..< config.particleCount).map { i in
            // Calculate angle for this particle
            let baseAngle = config.spread == .pi * 2
                ? Double(i) / Double(config.particleCount) * .pi * 2
                : (Double(i) / Double(config.particleCount) - 0.5) * config.spread

            // Add some randomness to angle
            let angle = baseAngle + Double.random(in: -0.2 ... 0.2)

            // Random velocity
            let velocity = CGFloat.random(in: config.minVelocity ... config.maxVelocity)

            return BurstParticle(
                x: origin.x,
                y: origin.y,
                velocityX: cos(angle) * velocity,
                velocityY: sin(angle) * velocity,
                size: CGFloat.random(in: config.minSize ... config.maxSize),
                opacity: 1.0,
                color: config.colors.randomElement() ?? .white,
                rotation: Double.random(in: 0 ... (.pi * 2)),
                rotationVelocity: Double.random(in: -5 ... 5),
            )
        }
    }

    private func updateParticles(at date: Date) {
        let elapsed = date.timeIntervalSince(startTime)
        let dt: CGFloat = 1.0 / 120.0 // Assume 120fps

        // Check if animation is complete
        guard elapsed < config.duration + config.fadeOutDuration else {
            return
        }

        // Update each particle
        for i in particles.indices {
            // Apply velocity
            particles[i].x += particles[i].velocityX * dt
            particles[i].y += particles[i].velocityY * dt

            // Apply gravity
            particles[i].velocityY += config.gravity * dt

            // Apply air resistance
            particles[i].velocityX *= 0.99
            particles[i].velocityY *= 0.99

            // Apply rotation
            particles[i].rotation += particles[i].rotationVelocity * dt

            // Fade out
            if elapsed > config.duration {
                let fadeProgress = (elapsed - config.duration) / config.fadeOutDuration
                particles[i].opacity = max(0, 1 - fadeProgress)
            }
        }
    }
}

// MARK: - Burst Trigger View Modifier

struct ParticleBurstModifier: ViewModifier {
    @Binding var trigger: Bool
    let config: ParticleBurstConfiguration
    let position: BurstPosition

    @State private var burstOrigin: CGPoint = .zero
    @State private var showBurst = false

    enum BurstPosition {
        case center
        case custom(CGPoint)
        case tapLocation
    }

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(key: BurstFramePreferenceKey.self, value: geometry.frame(in: .global))
                },
            )
            .onPreferenceChange(BurstFramePreferenceKey.self) { frame in
                switch position {
                case .center:
                    burstOrigin = CGPoint(x: frame.midX, y: frame.midY)
                case let .custom(point):
                    burstOrigin = point
                case .tapLocation:
                    break // Will be set on tap
                }
            }
            .overlay {
                if showBurst {
                    ParticleBurstView(
                        origin: burstOrigin,
                        config: config,
                        onComplete: {
                            showBurst = false
                        },
                    )
                }
            }
            .onChange(of: trigger) { _, shouldTrigger in
                if shouldTrigger {
                    showBurst = true
                    // Reset trigger
                    Task { @MainActor in
                        trigger = false
                    }
                }
            }
    }
}

struct BurstFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

// MARK: - Tap Burst View Modifier

struct TapParticleBurstModifier: ViewModifier {
    let config: ParticleBurstConfiguration
    let action: () -> Void

    @State private var burstOrigin: CGPoint = .zero
    @State private var showBurst = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if showBurst {
                    ParticleBurstView(
                        origin: burstOrigin,
                        config: config,
                        onComplete: {
                            showBurst = false
                        },
                    )
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        burstOrigin = value.location
                        showBurst = true
                        action()
                    },
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Trigger a particle burst when the binding becomes true
    public func particleBurst(
        trigger: Binding<Bool>,
        config: ParticleBurstConfiguration = .default,
        position: ParticleBurstModifier.BurstPosition = .center,
    ) -> some View {
        modifier(ParticleBurstModifier(trigger: trigger, config: config, position: position))
    }

    /// Create a particle burst at tap location
    public func tapBurst(
        config: ParticleBurstConfiguration = .subtle,
        action: @escaping () -> Void = {},
    ) -> some View {
        modifier(TapParticleBurstModifier(config: config, action: action))
    }

    /// Quick celebration burst (for like/save buttons)
    public func celebrationBurst(trigger: Binding<Bool>) -> some View {
        particleBurst(trigger: trigger, config: .celebration)
    }

    /// Heart burst (for like buttons specifically)
    public func heartBurst(trigger: Binding<Bool>) -> some View {
        particleBurst(trigger: trigger, config: .heart)
    }
}

// MARK: - Standalone Burst Controller

/// Controller for manually triggering bursts at specific locations
@MainActor @Observable
public final class ParticleBurstController {
    public struct ActiveBurst: Identifiable {
        public let id = UUID()
        public let origin: CGPoint
        public let config: ParticleBurstConfiguration
        public let startTime: Date
    }

    public var activeBursts: [ActiveBurst] = []

    public init() {}

    public func trigger(at origin: CGPoint, config: ParticleBurstConfiguration = .default) {
        let burst = ActiveBurst(origin: origin, config: config, startTime: .now)
        activeBursts.append(burst)

        // Auto-remove after animation completes
        let totalDuration = config.duration + config.fadeOutDuration + 0.1
        Task {
            try? await Task.sleep(for: .seconds(totalDuration))
            removeBurst(id: burst.id)
        }
    }

    public func removeBurst(id: UUID) {
        activeBursts.removeAll { $0.id == id }
    }
}

/// View that renders all active bursts from a controller
public struct ParticleBurstOverlay: View {
    let controller: ParticleBurstController

    public init(controller: ParticleBurstController) {
        self.controller = controller
    }

    public var body: some View {
        ZStack {
            ForEach(controller.activeBursts) { burst in
                ParticleBurstView(
                    origin: burst.origin,
                    config: burst.config,
                    onComplete: {
                        controller.removeBurst(id: burst.id)
                    },
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Particle Bursts") {
        struct PreviewContent: View {
            @State private var trigger1 = false
            @State private var trigger2 = false
            @State private var trigger3 = false
            @State private var trigger4 = false
            @State private var burstController = ParticleBurstController()

            var body: some View {
                ZStack {
                    Color.DesignSystem.background.ignoresSafeArea()

                    VStack(spacing: Spacing.xl) {
                        Text("Particle Bursts")
                            .font(.LiquidGlass.displayMedium)
                            .foregroundStyle(Color.DesignSystem.text)

                        // Tap anywhere burst
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(Color.DesignSystem.brandGreen.opacity(0.2))
                            .frame(height: 100)
                            .overlay(
                                Text("Tap anywhere")
                                    .foregroundStyle(Color.DesignSystem.text),
                            )
                            .tapBurst(config: .default)

                        // Button bursts
                        HStack(spacing: Spacing.lg) {
                            Button {
                                trigger1 = true
                            } label: {
                                Text("Default")
                                    .padding()
                                    .background(Color.DesignSystem.brandGreen)
                                    .clipShape(Capsule())
                            }
                            .particleBurst(trigger: $trigger1, config: .default)

                            Button {
                                trigger2 = true
                            } label: {
                                Text("Heart")
                                    .padding()
                                    .background(Color.DesignSystem.brandPink)
                                    .clipShape(Capsule())
                            }
                            .heartBurst(trigger: $trigger2)

                            Button {
                                trigger3 = true
                            } label: {
                                Text("Spark")
                                    .padding()
                                    .background(.orange)
                                    .clipShape(Capsule())
                            }
                            .particleBurst(trigger: $trigger3, config: .spark)
                        }
                        .foregroundStyle(.white)

                        Button {
                            trigger4 = true
                        } label: {
                            Text("Celebration Burst!")
                                .font(.LiquidGlass.headlineMedium)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(
                                    LinearGradient(
                                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                                        startPoint: .leading,
                                        endPoint: .trailing,
                                    ),
                                )
                                .clipShape(Capsule())
                        }
                        .celebrationBurst(trigger: $trigger4)
                        .foregroundStyle(.white)
                        .padding(.horizontal)
                    }
                    .padding()

                    ParticleBurstOverlay(controller: burstController)
                }
            }
        }

        return PreviewContent()
            .preferredColorScheme(.dark)
    }
#endif
