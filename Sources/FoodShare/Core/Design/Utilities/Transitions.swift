//
//  Transitions.swift
//  Foodshare
//
//  Smooth transitions and animations for Liquid Glass design
//

import SwiftUI

// MARK: - Custom Transitions

extension AnyTransition {
    /// Slide up with fade - great for cards appearing
    static var slideUpFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity),
        )
    }

    /// Scale with fade - great for modals
    static var scaleFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.9).combined(with: .opacity),
        )
    }

    /// Blur transition - great for glass effects
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(radius: 10, opacity: 0),
            identity: BlurModifier(radius: 0, opacity: 1),
        )
    }

    /// Glass appear - combines scale, blur, and fade
    static var glassAppear: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.95)
                .combined(with: .opacity)
                .animation(.spring(response: 0.4, dampingFraction: 0.8)),
            removal: .scale(scale: 0.95)
                .combined(with: .opacity)
                .animation(.easeOut(duration: 0.2)),
        )
    }

    /// Slide from leading edge
    static var slideFromLeading: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .move(edge: .trailing).combined(with: .opacity),
        )
    }
}

// MARK: - Blur Modifier

struct BlurModifier: ViewModifier {
    let radius: CGFloat
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: radius)
            .opacity(opacity)
    }
}

// MARK: - Animation Extensions

extension Animation {
    /// Standard spring animation for UI elements
    static var smoothSpring: Animation {
        .spring(response: 0.35, dampingFraction: 0.7)
    }

    /// Quick spring for small interactions
    static var quickSpring: Animation {
        .spring(response: 0.25, dampingFraction: 0.8)
    }

    /// Bouncy spring for playful elements
    static var bouncySpring: Animation {
        .spring(response: 0.4, dampingFraction: 0.6)
    }

    /// Smooth ease for subtle transitions
    static var smoothEase: Animation {
        .easeInOut(duration: 0.3)
    }

    /// Glass material animation
    static var glassAnimation: Animation {
        .spring(response: 0.5, dampingFraction: 0.75)
    }

    // MARK: - ProMotion 120Hz Optimized Animations

    /// Instant response spring - 120Hz optimized
    /// Use for micro-interactions, button taps
    static var proMotionInstant: Animation {
        .interpolatingSpring(stiffness: 400, damping: 30)
    }

    /// Quick spring - 120Hz optimized
    /// Use for toggles, small state changes
    static var proMotionQuick: Animation {
        .interpolatingSpring(stiffness: 300, damping: 25)
    }

    /// Smooth spring - 120Hz optimized
    /// Use for cards, panels, medium transitions
    static var proMotionSmooth: Animation {
        .interpolatingSpring(stiffness: 200, damping: 22)
    }

    /// Fluid spring - 120Hz optimized
    /// Use for page transitions, large reveals
    static var proMotionFluid: Animation {
        .interpolatingSpring(stiffness: 150, damping: 20)
    }

    /// Bouncy spring - 120Hz optimized
    /// Use for success states, celebrations, playful feedback
    static var proMotionBouncy: Animation {
        .interpolatingSpring(stiffness: 250, damping: 15)
    }

    /// Glass-optimized spring - 120Hz optimized
    /// Use specifically for glass/blur transitions
    static var proMotionGlass: Animation {
        .interpolatingSpring(stiffness: 180, damping: 24)
    }
}

// MARK: - Animated Appearance Modifier

struct AnimatedAppearance: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.smoothSpring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    /// Animate view appearance with optional delay
    func animatedAppearance(delay: Double = 0) -> some View {
        modifier(AnimatedAppearance(delay: delay))
    }
}

// MARK: - Staggered Animation

struct StaggeredAnimation: ViewModifier {
    let index: Int
    let baseDelay: Double
    let staggerDelay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 15)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                let delay = baseDelay + (Double(index) * staggerDelay)
                withAnimation(.smoothSpring.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    /// Apply staggered animation based on index
    func staggeredAnimation(
        index: Int,
        baseDelay: Double = 0.1,
        staggerDelay: Double = 0.05,
    ) -> some View {
        modifier(StaggeredAnimation(
            index: index,
            baseDelay: baseDelay,
            staggerDelay: staggerDelay,
        ))
    }
}

// MARK: - Press Effect

struct PressEffect: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.quickSpring, value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false },
            )
    }
}

extension View {
    /// Add press effect to any view
    func pressEffect() -> some View {
        modifier(PressEffect())
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing,
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (phase * geometry.size.width * 2))
                }
                .mask(content),
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

/// Simple shimmer view for use as overlay on loading placeholders
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.1),
                Color.white.opacity(0.3),
                Color.white.opacity(0.1)
            ],
            startPoint: .init(x: phase - 1, y: 0.5),
            endPoint: .init(x: phase, y: 0.5),
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }
}

extension View {
    /// Add shimmer loading effect
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Pulse Effect

struct PulseEffect: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.05 : 1.0)
            .opacity(isPulsing ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    /// Add pulse animation
    func pulse() -> some View {
        modifier(PulseEffect())
    }
}

// MARK: - Bounce Effect

struct BounceEffect: ViewModifier {
    let trigger: Bool
    @State private var isBouncing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isBouncing ? 1.1 : 1.0)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    withAnimation(.bouncySpring) {
                        isBouncing = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(150))
                        withAnimation(.bouncySpring) {
                            isBouncing = false
                        }
                    }
                }
            }
    }
}

extension View {
    /// Add bounce effect triggered by boolean
    func bounce(trigger: Bool) -> some View {
        modifier(BounceEffect(trigger: trigger))
    }
}
