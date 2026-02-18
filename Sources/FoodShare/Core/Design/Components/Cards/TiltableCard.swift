//
//  TiltableCard.swift
//  FoodShare
//
//  3D tiltable card component with perspective transforms.
//  Responds to drag gestures with realistic 3D rotation and shadow movement.
//
//  Features:
//  - Gesture-based 3D rotation
//  - Dynamic shadow that follows tilt direction
//  - Configurable tilt intensity and perspective
//  - Smooth spring animations
//  - Haptic feedback on interaction
//


#if !SKIP
import SwiftUI

// MARK: - Tilt Configuration

/// Configuration for tilt behavior
struct TiltConfiguration {
    /// Maximum rotation angle in degrees
    let maxRotation: Double

    /// Perspective depth (lower = more pronounced 3D effect)
    let perspective: CGFloat

    /// Shadow offset multiplier
    let shadowMultiplier: CGFloat

    /// Shadow radius range (min, max)
    let shadowRadiusRange: ClosedRange<CGFloat>

    /// Whether to provide haptic feedback
    let enableHaptics: Bool

    /// Reset animation
    let resetAnimation: Animation

    static let `default` = TiltConfiguration(
        maxRotation: 15,
        perspective: 0.5,
        shadowMultiplier: 0.5,
        shadowRadiusRange: 5 ... 20,
        enableHaptics: true,
        resetAnimation: ProMotionAnimation.bouncy,
    )

    static let subtle = TiltConfiguration(
        maxRotation: 8,
        perspective: 0.7,
        shadowMultiplier: 0.3,
        shadowRadiusRange: 3 ... 12,
        enableHaptics: false,
        resetAnimation: ProMotionAnimation.smooth,
    )

    static let dramatic = TiltConfiguration(
        maxRotation: 25,
        perspective: 0.3,
        shadowMultiplier: 0.8,
        shadowRadiusRange: 8 ... 30,
        enableHaptics: true,
        resetAnimation: ProMotionAnimation.bouncy,
    )
}

// MARK: - Tilt State

/// Current tilt state
struct TiltState: Equatable {
    var rotationX: Double = 0
    var rotationY: Double = 0
    var isDragging = false

    static let identity = TiltState()

    var shadowOffset: CGSize {
        CGSize(
            width: -rotationY * 0.5,
            height: rotationX * 0.5,
        )
    }
}

// MARK: - Tiltable Card View

/// A card that tilts in 3D space based on drag gestures
struct TiltableCard<Content: View>: View {
    let configuration: TiltConfiguration
    @ViewBuilder let content: () -> Content

    @State private var tiltState = TiltState.identity
    @GestureState private var dragOffset: CGSize = .zero

    init(
        configuration: TiltConfiguration = .default,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.configuration = configuration
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            content()
                .rotation3DEffect(
                    .degrees(tiltState.rotationX),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: configuration.perspective,
                )
                .rotation3DEffect(
                    .degrees(tiltState.rotationY),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: configuration.perspective,
                )
                .shadow(
                    color: Color.black.opacity(tiltState.isDragging ? 0.3 : 0.15),
                    radius: shadowRadius,
                    x: tiltState.shadowOffset.width * configuration.shadowMultiplier,
                    y: tiltState.shadowOffset.height * configuration.shadowMultiplier,
                )
                .scaleEffect(tiltState.isDragging ? 1.02 : 1.0)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onChanged { value in
                            updateTilt(with: value.location, in: geometry.size)
                        }
                        .onEnded { _ in
                            resetTilt()
                        },
                )
                .onAppear {
                    if configuration.enableHaptics {
                        HapticManager.prepare(.light)
                    }
                }
        }
    }

    private var shadowRadius: CGFloat {
        let base = configuration.shadowRadiusRange.lowerBound
        let range = configuration.shadowRadiusRange.upperBound - base
        let intensity = abs(tiltState.rotationX) + abs(tiltState.rotationY)
        let normalizedIntensity = min(intensity / (configuration.maxRotation * 2), 1.0)
        return base + range * normalizedIntensity
    }

    private func updateTilt(with location: CGPoint, in size: CGSize) {
        // Calculate normalized position (-1 to 1)
        let normalizedX = (location.x / size.width - 0.5) * 2
        let normalizedY = (location.y / size.height - 0.5) * 2

        // Apply rotation (inverted for natural feel)
        let newRotationX = -normalizedY * configuration.maxRotation
        let newRotationY = normalizedX * configuration.maxRotation

        // Smooth update
        withAnimation(.interactiveSpring(response: 0.15, dampingFraction: 0.8)) {
            tiltState.rotationX = newRotationX
            tiltState.rotationY = newRotationY

            if !tiltState.isDragging {
                tiltState.isDragging = true
                if configuration.enableHaptics {
                    HapticManager.light(intensity: 0.5)
                }
            }
        }
    }

    private func resetTilt() {
        withAnimation(configuration.resetAnimation) {
            tiltState = .identity
        }

        if configuration.enableHaptics {
            HapticManager.light(intensity: 0.3)
        }
    }
}

// MARK: - Tiltable View Modifier

/// View modifier for adding tilt behavior to any view
struct TiltableModifier: ViewModifier {
    let configuration: TiltConfiguration

    func body(content: Content) -> some View {
        TiltableCard(configuration: configuration) {
            content
        }
    }
}

extension View {
    /// Make this view tiltable with 3D perspective
    func tiltable(configuration: TiltConfiguration = .default) -> some View {
        modifier(TiltableModifier(configuration: configuration))
    }

    /// Make this view subtly tiltable
    func tiltableSubtle() -> some View {
        modifier(TiltableModifier(configuration: .subtle))
    }

    /// Make this view dramatically tiltable
    func tiltableDramatic() -> some View {
        modifier(TiltableModifier(configuration: .dramatic))
    }
}

// MARK: - Gyroscope Tilt (Motion-Based)

/// A view that tilts based on device motion
struct GyroscopeTiltView<Content: View>: View {
    let intensity: Double
    let maxRotation: Double
    @ViewBuilder let content: () -> Content

    @State private var rotationX: Double = 0
    @State private var rotationY: Double = 0

    init(
        intensity: Double = 1.0,
        maxRotation: Double = 10,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.intensity = intensity
        self.maxRotation = maxRotation
        self.content = content
    }

    var body: some View {
        content()
            .rotation3DEffect(
                .degrees(rotationX * intensity),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5,
            )
            .rotation3DEffect(
                .degrees(rotationY * intensity),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5,
            )
            .onAppear {
                startMotionUpdates()
            }
            .onDisappear {
                stopMotionUpdates()
            }
    }

    private func startMotionUpdates() {
        // Motion updates would be implemented with CoreMotion
        // For now, use a subtle ambient animation as fallback
        withAnimation(
            .easeInOut(duration: 3)
                .repeatForever(autoreverses: true),
        ) {
            rotationX = maxRotation * 0.3
            rotationY = maxRotation * 0.2
        }
    }

    private func stopMotionUpdates() {
        withAnimation(ProMotionAnimation.smooth) {
            rotationX = 0
            rotationY = 0
        }
    }
}

// MARK: - Glass Tiltable Card

/// Tiltable card with glass morphism styling
struct GlassTiltableCard<Content: View>: View {
    let configuration: TiltConfiguration
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        configuration: TiltConfiguration = .default,
        cornerRadius: CGFloat = 20,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.configuration = configuration
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        TiltableCard(configuration: configuration) {
            content()
                .padding(Spacing.md)
                #if !SKIP
                .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .background(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 1,
                        ),
                )
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Tiltable Cards") {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                Text("Drag the cards to tilt")
                    .font(Font.DesignSystem.headlineMedium)
                    .padding(.top, Spacing.lg)

                // Default tilt
                GlassTiltableCard {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Image(systemName: "cube.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.DesignSystem.primary)

                        Text("Default Tilt")
                            .font(Font.DesignSystem.headlineSmall)

                        Text("Standard 3D tilt effect with moderate rotation")
                            .font(Font.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 160.0)
                .padding(.horizontal, Spacing.lg)

                // Subtle tilt
                GlassTiltableCard(configuration: .subtle) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.DesignSystem.success)

                        Text("Subtle Tilt")
                            .font(Font.DesignSystem.headlineSmall)

                        Text("Gentle effect for cards requiring less distraction")
                            .font(Font.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 160.0)
                .padding(.horizontal, Spacing.lg)

                // Dramatic tilt
                GlassTiltableCard(configuration: .dramatic) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.DesignSystem.warning)

                        Text("Dramatic Tilt")
                            .font(Font.DesignSystem.headlineSmall)

                        Text("Bold 3D effect for featured content")
                            .font(Font.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 160.0)
                .padding(.horizontal, Spacing.lg)

                Spacer(minLength: Spacing.xl)
            }
        }
        .background(Color.DesignSystem.background)
    }
#endif

#endif
