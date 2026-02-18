
#if !SKIP
#if !SKIP
import QuartzCore
#endif
import SwiftUI

// MARK: - Gesture Momentum

/// Observable class for physics-based momentum calculations on drag gestures
/// Provides smooth velocity tracking, deceleration, and spring handoff
@MainActor
@Observable
public final class GestureMomentum {

    // MARK: - Properties

    /// Current velocity in points per second
    public private(set) var velocity: CGPoint = .zero

    /// Current position
    public private(set) var position: CGPoint = .zero

    /// Whether momentum animation is currently active
    public private(set) var isAnimating = false

    /// Friction coefficient (0-1, higher = more friction)
    public var friction: CGFloat = 0.92

    /// Minimum velocity to continue animation (points per second)
    public var minimumVelocity: CGFloat = 10

    /// Maximum velocity cap (points per second)
    public var maximumVelocity: CGFloat = 5000

    // Private
    nonisolated(unsafe) private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var lastPosition: CGPoint = .zero
    private var velocityHistory: [(CGPoint, CFTimeInterval)] = []
    private let velocityHistorySize = 5
    private var onPositionUpdate: ((CGPoint) -> Void)?

    // MARK: - Initialization

    public init(friction: CGFloat = 0.92) {
        self.friction = friction
    }

    deinit {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Gesture Tracking

    /// Call at the start of a drag gesture
    public func startTracking(at position: CGPoint) {
        stopAnimation()
        self.position = position
        self.lastPosition = position
        self.velocity = .zero
        self.velocityHistory.removeAll()
        self.lastTimestamp = CACurrentMediaTime()
    }

    /// Call during drag gesture updates
    public func updateTracking(to position: CGPoint) {
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastTimestamp

        guard deltaTime > 0 else { return }

        // Calculate instantaneous velocity
        let deltaPosition = CGPoint(
            x: position.x - lastPosition.x,
            y: position.y - lastPosition.y,
        )

        let instantVelocity = CGPoint(
            x: deltaPosition.x / deltaTime,
            y: deltaPosition.y / deltaTime,
        )

        // Add to history for smoothing
        velocityHistory.append((instantVelocity, currentTime))
        if velocityHistory.count > velocityHistorySize {
            velocityHistory.removeFirst()
        }

        // Update state
        self.position = position
        self.lastPosition = position
        self.lastTimestamp = currentTime

        // Calculate smoothed velocity
        self.velocity = smoothedVelocity()
    }

    /// Call at the end of a drag gesture to start momentum
    public func endTracking(onUpdate: @escaping (CGPoint) -> Void) {
        // Clamp velocity
        velocity = clampVelocity(velocity)

        // Check if velocity is significant
        guard velocityMagnitude(velocity) > minimumVelocity else {
            onUpdate(position)
            return
        }

        // Start momentum animation
        onPositionUpdate = onUpdate
        startAnimation()
    }

    /// Cancel any ongoing momentum animation
    public func cancelMomentum() {
        stopAnimation()
    }

    // MARK: - Animation

    private func startAnimation() {
        guard !isAnimating else { return }

        isAnimating = true
        lastTimestamp = CACurrentMediaTime()

        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopAnimation() {
        displayLink?.invalidate()
        displayLink = nil
        isAnimating = false
    }

    @objc private func handleDisplayLink(_ displayLink: CADisplayLink) {
        let currentTime = displayLink.timestamp
        let deltaTime = currentTime - lastTimestamp
        lastTimestamp = currentTime

        // Apply friction
        velocity = CGPoint(
            x: velocity.x * friction,
            y: velocity.y * friction,
        )

        // Update position
        position = CGPoint(
            x: position.x + velocity.x * deltaTime,
            y: position.y + velocity.y * deltaTime,
        )

        // Notify listener
        onPositionUpdate?(position)

        // Stop if velocity is too low
        if velocityMagnitude(velocity) < minimumVelocity {
            stopAnimation()
        }
    }

    // MARK: - Helpers

    private func smoothedVelocity() -> CGPoint {
        guard !velocityHistory.isEmpty else { return .zero }

        // Weight recent samples more heavily
        var totalWeight: CGFloat = 0
        var weightedVelocity = CGPoint.zero

        for (index, (vel, _)) in velocityHistory.enumerated() {
            let weight = CGFloat(index + 1) // More recent = higher weight
            weightedVelocity.x += vel.x * weight
            weightedVelocity.y += vel.y * weight
            totalWeight += weight
        }

        return CGPoint(
            x: weightedVelocity.x / totalWeight,
            y: weightedVelocity.y / totalWeight,
        )
    }

    private func clampVelocity(_ vel: CGPoint) -> CGPoint {
        let magnitude = velocityMagnitude(vel)
        guard magnitude > maximumVelocity else { return vel }

        let scale = maximumVelocity / magnitude
        return CGPoint(x: vel.x * scale, y: vel.y * scale)
    }

    private func velocityMagnitude(_ vel: CGPoint) -> CGFloat {
        sqrt(vel.x * vel.x + vel.y * vel.y)
    }

    // MARK: - Spring Conversion

    /// Converts current velocity to a spring animation
    /// Higher velocity = less damping (more bounce)
    public func springAnimation(for targetPosition: CGPoint) -> Animation {
        let speed = velocityMagnitude(velocity)
        let normalizedSpeed = min(1.0, speed / 2000.0)

        // Map velocity to spring parameters
        let damping = 0.9 - (normalizedSpeed * 0.3) // 0.6 to 0.9
        let response = 0.3 + (normalizedSpeed * 0.2) // 0.3 to 0.5

        return .spring(response: response, dampingFraction: damping)
    }

    /// Returns predicted final position based on current velocity
    public func predictedEndPosition() -> CGPoint {
        // Sum of geometric series: v * friction / (1 - friction)
        let frictionFactor = friction / (1 - friction)

        return CGPoint(
            x: position.x + velocity.x * frictionFactor / 60, // Approximate for 60fps
            y: position.y + velocity.y * frictionFactor / 60,
        )
    }
}

// MARK: - Momentum Drag Modifier

/// View modifier that adds momentum-based drag behavior
public struct MomentumDragModifier: ViewModifier {

    @State private var momentum = GestureMomentum()
    @State private var offset: CGSize = .zero

    let axis: Axis.Set
    let friction: CGFloat
    let bounds: ClosedRange<CGFloat>?
    let onDragEnded: ((CGPoint) -> Void)?

    public func body(content: Content) -> some View {
        content
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        momentum.updateTracking(to: CGPoint(
                            x: axis.contains(.horizontal) ? value.translation.width : 0,
                            y: axis.contains(.vertical) ? value.translation.height : 0,
                        ))

                        offset = CGSize(
                            width: axis.contains(.horizontal) ? value.translation.width : 0,
                            height: axis.contains(.vertical) ? value.translation.height : 0,
                        )
                    }
                    .onEnded { _ in
                        momentum.endTracking { position in
                            var clampedPosition = position

                            // Apply bounds if specified
                            if let bounds {
                                if axis.contains(.horizontal) {
                                    clampedPosition.x = max(bounds.lowerBound, min(bounds.upperBound, position.x))
                                }
                                if axis.contains(.vertical) {
                                    clampedPosition.y = max(bounds.lowerBound, min(bounds.upperBound, position.y))
                                }
                            }

                            offset = CGSize(width: clampedPosition.x, height: clampedPosition.y)
                        }

                        onDragEnded?(momentum.predictedEndPosition())
                    },
            )
            .onAppear {
                momentum.friction = friction
                momentum.startTracking(at: .zero)
            }
    }
}

extension View {
    /// Adds momentum-based drag behavior to the view
    public func momentumDrag(
        axis: Axis.Set = [.horizontal, .vertical],
        friction: CGFloat = 0.92,
        bounds: ClosedRange<CGFloat>? = nil,
        onDragEnded: ((CGPoint) -> Void)? = nil,
    ) -> some View {
        modifier(MomentumDragModifier(
            axis: axis,
            friction: friction,
            bounds: bounds,
            onDragEnded: onDragEnded,
        ))
    }
}

// MARK: - Fling Gesture

/// Gesture that detects fling (fast swipe) in a direction
public struct FlingGesture: Gesture {

    public enum Direction {
        case left, right, up, down
    }

    let minimumVelocity: CGFloat
    let onFling: (Direction, CGFloat) -> Void

    public init(
        minimumVelocity: CGFloat = 500,
        onFling: @escaping (Direction, CGFloat) -> Void,
    ) {
        self.minimumVelocity = minimumVelocity
        self.onFling = onFling
    }

    public var body: some Gesture {
        DragGesture()
            .onEnded { value in
                let velocity = CGPoint(
                    x: value.predictedEndLocation.x - value.location.x,
                    y: value.predictedEndLocation.y - value.location.y,
                )

                let horizontalVelocity = abs(velocity.x)
                let verticalVelocity = abs(velocity.y)

                if horizontalVelocity > verticalVelocity, horizontalVelocity > minimumVelocity {
                    let direction: Direction = velocity.x > 0 ? .right : .left
                    onFling(direction, horizontalVelocity)
                } else if verticalVelocity > horizontalVelocity, verticalVelocity > minimumVelocity {
                    let direction: Direction = velocity.y > 0 ? .down : .up
                    onFling(direction, verticalVelocity)
                }
            }
    }
}

// MARK: - Preview

#Preview {
    struct MomentumDemo: View {
        @State private var offset: CGSize = .zero

        var body: some View {
            ZStack {
                Color.DesignSystem.background
                    .ignoresSafeArea()

                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.DesignSystem.brandGreen)
                    .frame(width: 100.0, height: 100)
                    .momentumDrag(friction: 0.95)
            }
        }
    }

    return MomentumDemo()
}

#endif
