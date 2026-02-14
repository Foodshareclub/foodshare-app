//
//  GlassAnimations.swift
//  Foodshare
//
//  Advanced Liquid Glass animations for premium visual effects
//  Shimmer, pulse, glow, and breathing effects optimized for 120Hz ProMotion
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Glass Shimmer Effect

/// A shimmer effect that moves across a view for loading or highlight states
struct GlassShimmerModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    let duration: Double
    let angle: Angle

    @State private var startPoint = UnitPoint(x: -1.5, y: 0.5)
    @State private var endPoint = UnitPoint(x: -0.5, y: 0.5)

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        LinearGradient(
                            colors: [
                                color.opacity(0),
                                color.opacity(0.4),
                                color.opacity(0.6),
                                color.opacity(0.4),
                                color.opacity(0),
                            ],
                            startPoint: startPoint,
                            endPoint: endPoint,
                        )
                        .rotationEffect(angle)
                        .allowsHitTesting(false)
                    }
                },
            )
            .onAppear {
                guard isActive else { return }
                withAnimation(
                    .linear(duration: duration)
                        .repeatForever(autoreverses: false),
                ) {
                    startPoint = UnitPoint(x: 1, y: 0.5)
                    endPoint = UnitPoint(x: 2.5, y: 0.5)
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    startPoint = UnitPoint(x: -1.5, y: 0.5)
                    endPoint = UnitPoint(x: -0.5, y: 0.5)
                    withAnimation(
                        .linear(duration: duration)
                            .repeatForever(autoreverses: false),
                    ) {
                        startPoint = UnitPoint(x: 1, y: 0.5)
                        endPoint = UnitPoint(x: 2.5, y: 0.5)
                    }
                }
            }
    }
}

// MARK: - Glass Pulse Effect

/// A pulsing glow effect for attention-grabbing elements
struct GlassPulseModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    let minScale: CGFloat
    let maxScale: CGFloat
    let duration: Double

    @State private var currentScale: CGFloat = 1.0
    @State private var opacity = 0.6

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(color.opacity(opacity))
                            .scaleEffect(currentScale)
                            .blur(radius: 8)
                            .allowsHitTesting(false)
                    }
                },
            )
            .onAppear {
                guard isActive else { return }
                startPulse()
            }
            .onChange(of: isActive) { _, active in
                if active { startPulse() }
            }
    }

    private func startPulse() {
        currentScale = minScale
        opacity = 0.6
        withAnimation(
            .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
        ) {
            currentScale = maxScale
            opacity = 0.2
        }
    }
}

// MARK: - Glass Breathing Effect

/// A subtle breathing animation for ambient elements
struct GlassBreathingModifier: ViewModifier {
    let isActive: Bool
    let intensity: Double
    let duration: Double

    @State private var animationPhase: Double = 0

    func body(content: Content) -> some View {
        content
            .opacity(isActive ? 0.7 + (0.3 * sin(animationPhase)) : 1.0)
            .scaleEffect(isActive ? 1.0 + (0.02 * sin(animationPhase) * intensity) : 1.0)
            .onAppear {
                guard isActive else { return }
                startBreathing()
            }
            .onChange(of: isActive) { _, active in
                if active { startBreathing() }
            }
    }

    private func startBreathing() {
        withAnimation(
            .easeInOut(duration: duration)
                .repeatForever(autoreverses: false),
        ) {
            animationPhase = .pi * 2
        }
    }
}

// MARK: - Glass Border Glow

/// An animated glowing border effect
struct GlassBorderGlowModifier: ViewModifier {
    let isActive: Bool
    let color: Color
    let lineWidth: CGFloat
    let cornerRadius: CGFloat
    let duration: Double

    @State private var glowOpacity = 0.3
    @State private var blurRadius: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(color.opacity(glowOpacity), lineWidth: lineWidth)
                            .blur(radius: blurRadius)
                    }
                },
            )
            .overlay(
                Group {
                    if isActive {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(color.opacity(glowOpacity * 0.8), lineWidth: lineWidth * 0.5)
                    }
                },
            )
            .onAppear {
                guard isActive else { return }
                startGlow()
            }
            .onChange(of: isActive) { _, active in
                if active { startGlow() }
            }
    }

    private func startGlow() {
        withAnimation(
            .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
        ) {
            glowOpacity = 0.8
            blurRadius = 8
        }
    }
}

// MARK: - Glass Highlight Sweep

/// A highlight sweep that moves across the view once
struct GlassHighlightSweepModifier: ViewModifier {
    @Binding var trigger: Bool
    let color: Color
    let duration: Double

    @State private var offset: CGFloat = -200
    @State private var viewWidth: CGFloat = 400

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
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
                    .frame(width: 100)
                    .offset(x: offset)
                    .blur(radius: 2)
                    .onAppear {
                        viewWidth = geometry.size.width
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        viewWidth = newWidth
                    }
                }
                .clipped()
                .allowsHitTesting(false),
            )
            .onChange(of: trigger) { _, shouldAnimate in
                if shouldAnimate {
                    offset = -200
                    withAnimation(.easeInOut(duration: duration)) {
                        offset = viewWidth + 200
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(duration))
                        trigger = false
                    }
                }
            }
    }
}

// MARK: - Glass Float Effect

/// A subtle floating animation for cards and elements
struct GlassFloatModifier: ViewModifier {
    let isActive: Bool
    let amplitude: CGFloat
    let duration: Double

    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: isActive ? offset : 0)
            .onAppear {
                guard isActive else { return }
                startFloat()
            }
            .onChange(of: isActive) { _, active in
                if active { startFloat() }
            }
    }

    private func startFloat() {
        offset = -amplitude
        withAnimation(
            .easeInOut(duration: duration)
                .repeatForever(autoreverses: true),
        ) {
            offset = amplitude
        }
    }
}

// MARK: - Glass Ripple Effect

/// A ripple effect that emanates from a point
struct GlassRippleModifier: ViewModifier {
    @Binding var trigger: Bool
    let color: Color
    let duration: Double

    @State private var scale: CGFloat = 0.5
    @State private var opacity = 0.8

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if trigger {
                        Circle()
                            .stroke(color.opacity(opacity), lineWidth: 2)
                            .scaleEffect(scale)
                            .allowsHitTesting(false)
                    }
                },
            )
            .onChange(of: trigger) { _, shouldAnimate in
                if shouldAnimate {
                    scale = 0.5
                    opacity = 0.8
                    withAnimation(.easeOut(duration: duration)) {
                        scale = 2.0
                        opacity = 0
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(duration))
                        trigger = false
                    }
                }
            }
    }
}

// MARK: - Skeleton Loading Effect

/// A skeleton loading placeholder with shimmer
struct GlassSkeletonModifier: ViewModifier {
    let isLoading: Bool
    let cornerRadius: CGFloat

    @State private var shimmerOffset: CGFloat = -300

    func body(content: Content) -> some View {
        Group {
            if isLoading {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.DesignSystem.glassBackground)
                    .overlay(
                        GeometryReader { geometry in
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.2),
                                    Color.white.opacity(0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            )
                            .frame(width: 150)
                            .offset(x: shimmerOffset)
                            .onAppear {
                                withAnimation(
                                    .linear(duration: 1.5)
                                        .repeatForever(autoreverses: false),
                                ) {
                                    shimmerOffset = geometry.size.width + 150
                                }
                            }
                        }
                        .clipped(),
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    )
            } else {
                content
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Apply a shimmer effect that sweeps across the view
    func glassShimmer(
        isActive: Bool = true,
        color: Color = .white,
        duration: Double = 1.5,
        angle: Angle = .degrees(0),
    ) -> some View {
        modifier(GlassShimmerModifier(
            isActive: isActive,
            color: color,
            duration: duration,
            angle: angle,
        ))
    }

    /// Apply a pulsing glow effect
    func glassPulse(
        isActive: Bool = true,
        color: Color = .DesignSystem.brandGreen,
        minScale: CGFloat = 1.0,
        maxScale: CGFloat = 1.1,
        duration: Double = 1.5,
    ) -> some View {
        modifier(GlassPulseModifier(
            isActive: isActive,
            color: color,
            minScale: minScale,
            maxScale: maxScale,
            duration: duration,
        ))
    }

    /// Apply a subtle breathing animation
    func glassBreathing(
        isActive: Bool = true,
        intensity: Double = 1.0,
        duration: Double = 3.0,
    ) -> some View {
        modifier(GlassBreathingModifier(
            isActive: isActive,
            intensity: intensity,
            duration: duration,
        ))
    }

    /// Apply an animated glowing border
    func glassBorderGlow(
        isActive: Bool = true,
        color: Color = .DesignSystem.brandGreen,
        lineWidth: CGFloat = 2,
        cornerRadius: CGFloat = CornerRadius.large,
        duration: Double = 1.5,
    ) -> some View {
        modifier(GlassBorderGlowModifier(
            isActive: isActive,
            color: color,
            lineWidth: lineWidth,
            cornerRadius: cornerRadius,
            duration: duration,
        ))
    }

    /// Apply a highlight sweep animation
    func glassHighlightSweep(
        trigger: Binding<Bool>,
        color: Color = .white,
        duration: Double = 0.8,
    ) -> some View {
        modifier(GlassHighlightSweepModifier(
            trigger: trigger,
            color: color,
            duration: duration,
        ))
    }

    /// Apply a floating animation
    func glassFloat(
        isActive: Bool = true,
        amplitude: CGFloat = 4,
        duration: Double = 2.0,
    ) -> some View {
        modifier(GlassFloatModifier(
            isActive: isActive,
            amplitude: amplitude,
            duration: duration,
        ))
    }

    /// Apply a ripple effect
    func glassRipple(
        trigger: Binding<Bool>,
        color: Color = .DesignSystem.brandGreen,
        duration: Double = 0.6,
    ) -> some View {
        modifier(GlassRippleModifier(
            trigger: trigger,
            color: color,
            duration: duration,
        ))
    }

    /// Apply a skeleton loading state with shimmer
    func glassSkeleton(
        isLoading: Bool,
        cornerRadius: CGFloat = CornerRadius.medium,
    ) -> some View {
        modifier(GlassSkeletonModifier(
            isLoading: isLoading,
            cornerRadius: cornerRadius,
        ))
    }
}

// MARK: - Phase Animator for Complex Sequences

/// Multi-phase glass animation for complex visual sequences
struct GlassPhaseAnimator<Phase: Hashable, Content: View>: View {
    let phases: [Phase]
    let trigger: Bool
    @ViewBuilder let content: (Phase) -> Content

    @State private var currentPhase: Phase

    init(
        phases: [Phase],
        trigger: Bool,
        @ViewBuilder content: @escaping (Phase) -> Content,
    ) {
        precondition(!phases.isEmpty, "GlassPhaseAnimator requires at least one phase")
        self.phases = phases
        self.trigger = trigger
        self.content = content
        _currentPhase = State(initialValue: phases[0])
    }

    var body: some View {
        content(currentPhase)
            .onChange(of: trigger) { _, _ in
                animateThroughPhases()
            }
    }

    private func animateThroughPhases() {
        Task { @MainActor in
            for (index, phase) in phases.enumerated() {
                if index > 0 {
                    try? await Task.sleep(for: .seconds(0.3))
                }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    currentPhase = phase
                }
            }
        }
    }
}

// MARK: - Interactive Glass Button Effect

/// A button style that combines multiple glass effects
struct GlassInteractiveButtonStyle: ButtonStyle {
    let baseColor: Color
    let isEnabled: Bool

    init(baseColor: Color = .DesignSystem.brandGreen, isEnabled: Bool = true) {
        self.baseColor = baseColor
        self.isEnabled = isEnabled
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.2 : 0))
                    .animation(.easeOut(duration: 0.1), value: configuration.isPressed),
            )
            .opacity(isEnabled ? 1 : 0.5)
    }
}

// Note: ProMotionAnimation is defined in ProMotionAnimations.swift

// Note: ProMotionButtonStyle is defined in ProMotionAnimations.swift

// MARK: - Preview

#Preview("Glass Animations") {
    struct PreviewContainer: View {
        @State private var sweepTrigger = false
        @State private var rippleTrigger = false
        @State private var isLoading = true

        var body: some View {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Shimmer Effect
                    Text("Shimmer Effect")
                        .font(.DesignSystem.headlineMedium)

                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(.ultraThinMaterial)
                        .frame(height: 100)
                        .glassShimmer(isActive: true)

                    // Pulse Effect
                    Text("Pulse Effect")
                        .font(.DesignSystem.headlineMedium)

                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(Color.DesignSystem.brandGreen.opacity(0.3))
                        .frame(height: 100)
                        .glassPulse(isActive: true)

                    // Border Glow
                    Text("Border Glow")
                        .font(.DesignSystem.headlineMedium)

                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(.ultraThinMaterial)
                        .frame(height: 100)
                        .glassBorderGlow(isActive: true)

                    // Float Effect
                    Text("Float Effect")
                        .font(.DesignSystem.headlineMedium)

                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .fill(.ultraThinMaterial)
                        .frame(height: 100)
                        .glassFloat(isActive: true)

                    // Highlight Sweep
                    Text("Highlight Sweep (Tap)")
                        .font(.DesignSystem.headlineMedium)

                    Button {
                        sweepTrigger = true
                    } label: {
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .fill(.ultraThinMaterial)
                            .frame(height: 100)
                            .glassHighlightSweep(trigger: $sweepTrigger)
                    }

                    // Ripple Effect
                    Text("Ripple Effect (Tap)")
                        .font(.DesignSystem.headlineMedium)

                    Button {
                        rippleTrigger = true
                    } label: {
                        Circle()
                            .fill(Color.DesignSystem.brandGreen)
                            .frame(width: 80, height: 80)
                            .glassRipple(trigger: $rippleTrigger)
                    }

                    // Skeleton Loading
                    Text("Skeleton Loading")
                        .font(.DesignSystem.headlineMedium)

                    Text("Content loaded!")
                        .frame(height: 60)
                        .frame(maxWidth: .infinity)
                        .glassSkeleton(isLoading: isLoading)

                    Button("Toggle Loading") {
                        isLoading.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewContainer()
}
