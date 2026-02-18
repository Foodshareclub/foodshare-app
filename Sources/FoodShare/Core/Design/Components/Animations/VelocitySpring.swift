
#if !SKIP
import SwiftUI

// MARK: - Velocity Spring

/// Provides velocity-aware spring animations that adapt to gesture speed
/// Higher velocity = more bounce, lower velocity = smoother settle
public enum VelocitySpring {

    // MARK: - Presets

    /// Spring for high-velocity fling gestures (lots of bounce)
    public static let fling = Animation.interpolatingSpring(
        stiffness: 200,
        damping: 15,
    )

    /// Spring for medium-velocity drags
    public static let drag = Animation.interpolatingSpring(
        stiffness: 300,
        damping: 22,
    )

    /// Spring for low-velocity precise movements
    public static let precise = Animation.interpolatingSpring(
        stiffness: 400,
        damping: 30,
    )

    /// Spring for snap-to-position behaviors
    public static let snap = Animation.interpolatingSpring(
        stiffness: 500,
        damping: 25,
    )

    // MARK: - Dynamic Generation

    /// Generates a spring animation based on velocity magnitude
    /// - Parameters:
    ///   - velocity: Velocity in points per second
    ///   - baseStiffness: Starting stiffness (default: 350)
    ///   - baseDamping: Starting damping (default: 25)
    /// - Returns: An animation tuned to the velocity
    public static func fromVelocity(
        _ velocity: CGFloat,
        baseStiffness: CGFloat = 350,
        baseDamping: CGFloat = 25,
    ) -> Animation {
        // Normalize velocity (0-1 range, capped at 2000 pts/s)
        let normalizedVelocity = min(1.0, abs(velocity) / 2000.0)

        // Higher velocity = lower damping (more bounce)
        // Range: baseDamping - 10 to baseDamping
        let damping = baseDamping - (normalizedVelocity * 10)

        // Higher velocity = slightly lower stiffness (more follow-through)
        let stiffness = baseStiffness - (normalizedVelocity * 50)

        return .interpolatingSpring(stiffness: stiffness, damping: damping)
    }

    /// Generates a spring from a 2D velocity vector
    public static func fromVelocity(_ velocity: CGPoint) -> Animation {
        let magnitude = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
        return fromVelocity(magnitude)
    }

    /// Generates a spring animation for dismissal gestures
    /// Fast dismiss = quick animation, slow dismiss = smooth animation
    public static func forDismiss(velocity: CGFloat) -> Animation {
        let speed = min(1.0, abs(velocity) / 1500.0)

        // Faster dismissal = shorter duration, less bounce
        let stiffness = 300 + (speed * 200) // 300-500
        let damping = 30 - (speed * 5) // 25-30

        return .interpolatingSpring(stiffness: stiffness, damping: damping)
    }

    /// Generates a spring for bounce-back (rubber band) effects
    public static func rubberBand(
        overshoot: CGFloat,
        maxOvershoot: CGFloat = 100,
    ) -> Animation {
        let normalizedOvershoot = min(1.0, abs(overshoot) / maxOvershoot)

        // More overshoot = snappier bounce back
        let stiffness = 400 + (normalizedOvershoot * 200) // 400-600
        let damping = 20 - (normalizedOvershoot * 5) // 15-20

        return .interpolatingSpring(stiffness: stiffness, damping: damping)
    }
}

// MARK: - Animation Extensions

extension Animation {

    /// Creates a spring animation from velocity
    public static func springFromVelocity(_ velocity: CGFloat) -> Animation {
        VelocitySpring.fromVelocity(velocity)
    }

    /// Creates a spring animation from 2D velocity
    public static func springFromVelocity(_ velocity: CGPoint) -> Animation {
        VelocitySpring.fromVelocity(velocity)
    }

    /// Creates a dismissal spring based on swipe velocity
    public static func dismissSpring(velocity: CGFloat) -> Animation {
        VelocitySpring.forDismiss(velocity: velocity)
    }

    /// Creates a rubber band spring for overshoot bounce-back
    public static func rubberBandSpring(overshoot: CGFloat) -> Animation {
        VelocitySpring.rubberBand(overshoot: overshoot)
    }
}

// MARK: - Velocity-Aware Drag Modifier

/// Modifier that applies velocity-aware spring animation to drag gestures
public struct VelocityAwareDragModifier: ViewModifier {

    @State private var offset: CGSize = .zero
    @State private var lastVelocity: CGFloat = 0

    let axis: Axis.Set
    let resistance: CGFloat
    let onDragEnded: ((CGSize, CGFloat) -> Void)?

    public func body(content: Content) -> some View {
        content
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Calculate velocity from predicted end
                        let predictedOffset = value.predictedEndTranslation
                        let currentOffset = value.translation

                        lastVelocity = sqrt(
                            pow(predictedOffset.width - currentOffset.width, 2) +
                                pow(predictedOffset.height - currentOffset.height, 2),
                        )

                        // Apply resistance
                        let resistedOffset = CGSize(
                            width: axis.contains(.horizontal) ? value.translation.width * resistance : 0.0,
                            height: axis.contains(.vertical) ? value.translation.height * resistance : 0.0,
                        )

                        offset = resistedOffset
                    }
                    .onEnded { _ in
                        let finalVelocity = lastVelocity

                        onDragEnded?(offset, finalVelocity)

                        // Animate back with velocity-aware spring
                        withAnimation(.springFromVelocity(finalVelocity)) {
                            offset = .zero
                        }
                    },
            )
    }
}

extension View {
    /// Adds velocity-aware drag behavior that springs back
    public func velocityAwareDrag(
        axis: Axis.Set = [.horizontal, .vertical],
        resistance: CGFloat = 1.0,
        onDragEnded: ((CGSize, CGFloat) -> Void)? = nil,
    ) -> some View {
        modifier(VelocityAwareDragModifier(
            axis: axis,
            resistance: resistance,
            onDragEnded: onDragEnded,
        ))
    }
}

// MARK: - Swipe to Dismiss Modifier

/// Modifier for swipe-to-dismiss with velocity-aware animation
public struct SwipeToDismissModifier: ViewModifier {

    @Binding var isPresented: Bool
    let direction: SwipeDirection
    let threshold: CGFloat
    let velocityThreshold: CGFloat

    @State private var offset: CGSize = .zero
    @State private var isDragging = false

    public enum SwipeDirection {
        case down, up, left, right

        var axis: Axis { self == .down || self == .up ? .vertical : .horizontal }
        var isPositive: Bool { self == .down || self == .right }
    }

    public func body(content: Content) -> some View {
        content
            .offset(offset)
            .opacity(opacity)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        let translation = direction.axis == .vertical
                            ? value.translation.height
                            : value.translation.width

                        // Only allow movement in dismiss direction
                        let allowedTranslation = direction.isPositive
                            ? max(0.0, translation)
                            : min(0.0, translation)

                        if direction.axis == .vertical {
                            offset = CGSize(width: 0.0, height: allowedTranslation)
                        } else {
                            offset = CGSize(width: allowedTranslation, height: 0.0)
                        }
                    }
                    .onEnded { value in
                        isDragging = false

                        let translation = direction.axis == .vertical
                            ? value.translation.height
                            : value.translation.width

                        let velocity = direction.axis == .vertical
                            ? value.predictedEndTranslation.height - value.translation.height
                            : value.predictedEndTranslation.width - value.translation.width

                        let shouldDismiss = abs(translation) > threshold || abs(velocity) > velocityThreshold

                        if shouldDismiss,
                           (direction.isPositive && translation > 0) || (!direction.isPositive && translation < 0) {
                            dismiss(velocity: velocity)
                        } else {
                            // Bounce back
                            withAnimation(.springFromVelocity(velocity)) {
                                offset = .zero
                            }
                        }
                    },
            )
    }

    private var opacity: Double {
        let progress = abs(direction.axis == .vertical ? offset.height : offset.width) / (threshold * 2)
        return 1 - min(0.3, progress)
    }

    private func dismiss(velocity: CGFloat) {
        withAnimation(.dismissSpring(velocity: velocity)) {
            let dismissOffset: CGFloat = UIScreen.main.bounds.height
            switch direction {
            case .down:
                offset = CGSize(width: 0.0, height: dismissOffset)
            case .up:
                offset = CGSize(width: 0.0, height: -dismissOffset)
            case .right:
                offset = CGSize(width: dismissOffset, height: 0.0)
            case .left:
                offset = CGSize(width: -dismissOffset, height: 0.0)
            }
        }

        Task { @MainActor in
            #if !SKIP
            try? await Task.sleep(for: .milliseconds(300))
            #else
            try? await Task.sleep(nanoseconds: 300_000_000)
            #endif
            isPresented = false
        }
    }
}

extension View {
    /// Adds swipe-to-dismiss behavior with velocity-aware animation
    public func swipeToDismiss(
        isPresented: Binding<Bool>,
        direction: SwipeToDismissModifier.SwipeDirection = .down,
        threshold: CGFloat = 100,
        velocityThreshold: CGFloat = 500,
    ) -> some View {
        modifier(SwipeToDismissModifier(
            isPresented: isPresented,
            direction: direction,
            threshold: threshold,
            velocityThreshold: velocityThreshold,
        ))
    }
}

// MARK: - Rubber Band Modifier

/// Modifier that creates rubber-band effect at boundaries
public struct RubberBandModifier: ViewModifier {

    @State private var offset: CGSize = .zero
    @State private var isOverstretched = false

    let axis: Axis.Set
    let limit: CGFloat
    let resistance: CGFloat

    public func body(content: Content) -> some View {
        content
            .offset(offset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let rawOffset = CGSize(
                            width: axis.contains(.horizontal) ? value.translation.width : 0.0,
                            height: axis.contains(.vertical) ? value.translation.height : 0.0,
                        )

                        // Apply rubber band effect past limit
                        offset = rubberBandOffset(rawOffset)

                        let magnitude = sqrt(offset.width * offset.width + offset.height * offset.height)
                        isOverstretched = magnitude > limit * 0.5
                    }
                    .onEnded { _ in
                        let magnitude = sqrt(offset.width * offset.width + offset.height * offset.height)

                        withAnimation(.rubberBandSpring(overshoot: magnitude)) {
                            offset = .zero
                            isOverstretched = false
                        }
                    },
            )
    }

    private func rubberBandOffset(_ rawOffset: CGSize) -> CGSize {
        func rubberBand(_ x: CGFloat) -> CGFloat {
            let sign: CGFloat = x >= 0 ? 1.0 : -1.0
            let absX = abs(x)

            if absX <= limit {
                return x
            }

            // Logarithmic resistance past limit
            let overflow = absX - limit
            let dampedOverflow = limit + overflow * resistance / (1 + overflow / limit)
            return sign * dampedOverflow
        }

        return CGSize(
            width: rubberBand(rawOffset.width),
            height: rubberBand(rawOffset.height),
        )
    }
}

extension View {
    /// Adds rubber band effect at boundaries
    public func rubberBand(
        axis: Axis.Set = [.horizontal, .vertical],
        limit: CGFloat = 50,
        resistance: CGFloat = 0.3,
    ) -> some View {
        modifier(RubberBandModifier(axis: axis, limit: limit, resistance: resistance))
    }
}

// MARK: - Preview

#Preview("Velocity Spring") {
    struct VelocityDemo: View {
        @State private var offset: CGSize = .zero

        var body: some View {
            VStack(spacing: 40) {
                Text("Drag and release")
                    .font(.headline)

                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.DesignSystem.brandGreen)
                    .frame(width: 100.0, height: 100)
                    .velocityAwareDrag()

                Text("Swipe left to dismiss")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.DesignSystem.background)
        }
    }

    return VelocityDemo()
}

#Preview("Rubber Band") {
    RoundedRectangle(cornerRadius: 20)
        .fill(Color.DesignSystem.brandGreen)
        .frame(width: 100.0, height: 100)
        .rubberBand()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
}

#endif
