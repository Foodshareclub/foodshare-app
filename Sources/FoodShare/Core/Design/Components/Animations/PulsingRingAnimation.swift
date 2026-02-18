//
//  PulsingRingAnimation.swift
//  Foodshare
//
//  Liquid Glass v27 - Animated Pulsing Ring
//  ProMotion 120Hz optimized ring animation for notification indicators
//


#if !SKIP
import SwiftUI

// MARK: - Pulsing Ring Animation

/// A ProMotion-optimized pulsing ring animation
///
/// Creates an animated ring effect that pulses outward when active.
/// Uses interpolating spring animations for smooth 120Hz performance.
///
/// Example usage:
/// ```swift
/// PulsingRingAnimation(isActive: hasUnread, color: .brandGreen)
/// ```
struct PulsingRingAnimation: View {
    let isActive: Bool
    let color: Color
    let size: CGFloat
    let ringCount: Int

    @State private var animationPhase: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    init(
        isActive: Bool,
        color: Color = .DesignSystem.brandGreen,
        size: CGFloat = 44,
        ringCount: Int = 2,
    ) {
        self.isActive = isActive
        self.color = color
        self.size = size
        self.ringCount = ringCount
    }

    var body: some View {
        ZStack {
            if isActive, !reduceMotion {
                ForEach(0 ..< ringCount, id: \.self) { index in
                    pulsingRing(index: index)
                }
            }
        }
        .frame(width: size, height: size)
        .onChange(of: isActive) { _, newValue in
            if newValue, !reduceMotion {
                startAnimation()
            }
        }
        .onAppear {
            if isActive, !reduceMotion {
                startAnimation()
            }
        }
    }

    // MARK: - Pulsing Ring

    private func pulsingRing(index: Int) -> some View {
        let delay = Double(index) * 0.4
        let scale = 1.0 + (animationPhase * 0.5)
        let opacity = max(0.0, 1.0 - animationPhase)

        return Circle()
            .stroke(
                color.opacity(opacity * 0.6),
                lineWidth: 2,
            )
            .scaleEffect(scale)
            .animation(
                .interpolatingSpring(stiffness: 50, damping: 8)
                    .repeatForever(autoreverses: false)
                    .delay(delay),
                value: animationPhase,
            )
    }

    // MARK: - Animation Control

    private func startAnimation() {
        animationPhase = 0
        withAnimation(.linear(duration: 0.01)) {
            animationPhase = 1.0
        }
    }
}

// MARK: - Continuous Pulsing Ring

/// A continuously pulsing ring that animates in a loop
/// Use for persistent notification indicators
struct ContinuousPulsingRing: View {
    let isActive: Bool
    let color: Color
    let size: CGFloat

    @State private var scale: CGFloat = 1.0
    @State private var opacity: CGFloat = 0.8
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    init(
        isActive: Bool,
        color: Color = .DesignSystem.brandGreen,
        size: CGFloat = 44,
    ) {
        self.isActive = isActive
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            if isActive, !reduceMotion {
                // Outer ring
                Circle()
                    .stroke(color.opacity(opacity * 0.4), lineWidth: 2)
                    .scaleEffect(scale)

                // Inner ring (slightly delayed)
                Circle()
                    .stroke(color.opacity(opacity * 0.6), lineWidth: 1.5)
                    .scaleEffect(scale * 0.85)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            if isActive, !reduceMotion {
                startContinuousAnimation()
            }
        }
        .onChange(of: isActive) { _, newValue in
            if newValue, !reduceMotion {
                startContinuousAnimation()
            } else {
                resetAnimation()
            }
        }
    }

    private func startContinuousAnimation() {
        withAnimation(
            .interpolatingSpring(stiffness: 40, damping: 6)
                .repeatForever(autoreverses: true),
        ) {
            scale = 1.3
            opacity = 0.3
        }
    }

    private func resetAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 1.0
            opacity = 0.8
        }
    }
}

// MARK: - Glow Pulse Effect

/// A subtle glow pulse effect for bell icons
/// More subtle than full ring animation
struct GlowPulseEffect: View {
    let isActive: Bool
    let color: Color
    let size: CGFloat

    @State private var glowOpacity: CGFloat = 0.3
    @State private var glowScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    init(
        isActive: Bool,
        color: Color = .DesignSystem.brandGreen,
        size: CGFloat = 44,
    ) {
        self.isActive = isActive
        self.color = color
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(isActive ? glowOpacity : 0),
                        color.opacity(0.0),
                    ],
                    center: .center,
                    startRadius: size * 0.2,
                    endRadius: size * 0.6,
                ),
            )
            .scaleEffect(glowScale)
            .frame(width: size, height: size)
            .onAppear {
                if isActive, !reduceMotion {
                    startGlowAnimation()
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue, !reduceMotion {
                    startGlowAnimation()
                } else {
                    stopGlowAnimation()
                }
            }
    }

    private func startGlowAnimation() {
        withAnimation(
            .interpolatingSpring(stiffness: 60, damping: 8)
                .repeatForever(autoreverses: true),
        ) {
            glowOpacity = 0.6
            glowScale = 1.2
        }
    }

    private func stopGlowAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            glowOpacity = 0
            glowScale = 1.0
        }
    }
}

// MARK: - Preview

#Preview("Pulsing Ring Animations") {
    VStack(spacing: Spacing.xxl) {
        Text("Pulsing Ring Animations")
            .font(.DesignSystem.displayMedium)
            .foregroundStyle(Color.DesignSystem.textPrimary)

        HStack(spacing: Spacing.xxl) {
            VStack(spacing: Spacing.md) {
                ZStack {
                    PulsingRingAnimation(isActive: true)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.DesignSystem.brandGreen)
                }
                Text("Multi-Ring")
                    .font(.DesignSystem.caption)
            }

            VStack(spacing: Spacing.md) {
                ZStack {
                    ContinuousPulsingRing(isActive: true)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.DesignSystem.brandGreen)
                }
                Text("Continuous")
                    .font(.DesignSystem.caption)
            }

            VStack(spacing: Spacing.md) {
                ZStack {
                    GlowPulseEffect(isActive: true)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.DesignSystem.brandGreen)
                }
                Text("Glow")
                    .font(.DesignSystem.caption)
            }
        }

        HStack(spacing: Spacing.xxl) {
            VStack(spacing: Spacing.md) {
                ZStack {
                    PulsingRingAnimation(isActive: false)
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                Text("Inactive")
                    .font(.DesignSystem.caption)
            }

            VStack(spacing: Spacing.md) {
                ZStack {
                    ContinuousPulsingRing(
                        isActive: true,
                        color: .DesignSystem.brandPink,
                    )
                    Image(systemName: "heart.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.DesignSystem.brandPink)
                }
                Text("Custom Color")
                    .font(.DesignSystem.caption)
            }

            VStack(spacing: Spacing.md) {
                ZStack {
                    GlowPulseEffect(
                        isActive: true,
                        color: .DesignSystem.warning,
                        size: 56,
                    )
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.DesignSystem.warning)
                }
                Text("Warning")
                    .font(.DesignSystem.caption)
            }
        }
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#endif
