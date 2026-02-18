//
//  ShaderLibraryExtensions.swift
//  Foodshare
//
//  iOS 17+ ShaderLibrary extensions for easier shader integration
//  Provides type-safe access to Metal shaders in SwiftUI
//


#if !SKIP
import SwiftUI

// MARK: - ShaderLibrary Extensions

@available(iOS 17.0, *)
extension ShaderLibrary {
    // MARK: - Glass Effects

    /// Glass shimmer effect for loading states
    static var glassShimmer: Shader {
        ShaderLibrary.default.shimmer_fragment(
            .float(0), // time
            .float(1) // intensity
        )
    }

    /// Liquid distortion effect
    static var liquidDistortion: Shader {
        ShaderLibrary.default.liquid_ripple_fragment(
            .float(0), // time
            .float(1) // intensity
        )
    }

    /// Touch ripple interaction effect
    static var touchRipple: Shader {
        ShaderLibrary.default.touch_ripple_fragment(
            .float(0), // time
            .float2(0.5, 0.5), // touch point
            .float(0) // progress
        )
    }

    // MARK: - Component Effects

    /// Skeleton loading wave effect
    static var skeletonWave: Shader {
        ShaderLibrary.default.skeleton_wave_fragment(
            .float(0), // time
            .float(1) // intensity
        )
    }

    /// Button press ripple effect
    static var buttonRipple: Shader {
        ShaderLibrary.default.button_press_ripple_fragment(
            .float(0), // time
            .float2(0.5, 0.5), // touch center
            .float(0) // progress
        )
    }

    /// Component state morph transition
    static var componentMorph: Shader {
        ShaderLibrary.default.component_morph_fragment(
            .float(0), // time
            .float(0) // progress
        )
    }

    // MARK: - Celebration Effects

    /// Achievement burst effect
    static var achievementBurst: Shader {
        ShaderLibrary.default.achievement_burst_fragment(
            .float(0), // time
            .float(0) // progress
        )
    }

    /// Badge sparkle effect
    static var badgeSparkle: Shader {
        ShaderLibrary.default.badge_sparkle_fragment(
            .float(0), // time
            .float(1) // intensity
        )
    }

    /// Glow pulse effect
    static var glowPulse: Shader {
        ShaderLibrary.default.glow_pulse_fragment(
            .float(0), // time
            .color(.green) // tint color
        )
    }
}

// MARK: - Shader Parameter Builders

@available(iOS 17.0, *)
struct ShaderParameters {
    /// Creates parameters for shimmer effect
    static func shimmer(time: Float, intensity: Float = 1.0) -> [Shader.Argument] {
        [.float(time), .float(intensity)]
    }

    /// Creates parameters for ripple effect
    static func ripple(time: Float, center: CGPoint, progress: Float) -> [Shader.Argument] {
        [.float(time), .float2(Float(center.x), Float(center.y)), .float(progress)]
    }

    /// Creates parameters for glow effect
    static func glow(time: Float, color: Color, intensity: Float = 1.0) -> [Shader.Argument] {
        [.float(time), .color(color), .float(intensity)]
    }
}

// MARK: - Animated Shader View Modifier

@available(iOS 17.0, *)
struct AnimatedShaderModifier: ViewModifier {
    let shaderName: String
    let intensity: CGFloat
    @State private var startTime = Date()

    func body(content: Content) -> some View {
        TimelineView(.animation) { timeline in
            let elapsed = Float(timeline.date.timeIntervalSince(startTime))
            content
                .layerEffect(
                    ShaderLibrary.default[dynamicMember: shaderName](
                        .float(elapsed),
                        .float(Float(intensity))
                    ),
                    maxSampleOffset: .zero
                )
        }
    }
}

@available(iOS 17.0, *)
extension View {
    /// Applies an animated shader effect
    func animatedShader(_ name: String, intensity: CGFloat = 1.0) -> some View {
        modifier(AnimatedShaderModifier(shaderName: name, intensity: intensity))
    }
}

// MARK: - Shader-Based Visual Effect Views

@available(iOS 17.0, *)
struct ShaderShimmerView: View {
    let color: Color
    let intensity: CGFloat
    @State private var startTime = Date()

    init(color: Color = .white, intensity: CGFloat = 1.0) {
        self.color = color
        self.intensity = intensity
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = Float(timeline.date.timeIntervalSince(startTime))

            Rectangle()
                .fill(.clear)
                .visualEffect { content, proxy in
                    content
                        .layerEffect(
                            ShaderLibrary.default.skeleton_wave_fragment(
                                .float(elapsed),
                                .float(Float(intensity))
                            ),
                            maxSampleOffset: CGSize(width: 100.0, height: 0.0)
                        )
                }
        }
    }
}

@available(iOS 17.0, *)
struct ShaderGlowView: View {
    let color: Color
    let intensity: CGFloat
    @State private var startTime = Date()

    init(color: Color = Color.DesignSystem.brandGreen, intensity: CGFloat = 1.0) {
        self.color = color
        self.intensity = intensity
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = Float(timeline.date.timeIntervalSince(startTime))

            Rectangle()
                .fill(.clear)
                .visualEffect { content, proxy in
                    content
                        .layerEffect(
                            ShaderLibrary.default.glow_pulse_fragment(
                                .float(elapsed),
                                .color(color)
                            ),
                            maxSampleOffset: .zero
                        )
                }
        }
    }
}

// MARK: - Interactive Touch Shader

@available(iOS 17.0, *)
struct TouchRippleShaderView: View {
    @Binding var touchLocation: CGPoint?
    @State private var rippleProgress: CGFloat = 0
    @State private var startTime = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = Float(timeline.date.timeIntervalSince(startTime))

            Rectangle()
                .fill(.clear)
                .visualEffect { content, proxy in
                    let normalizedTouch = CGPoint(
                        x: (touchLocation?.x ?? proxy.size.width / 2) / proxy.size.width,
                        y: (touchLocation?.y ?? proxy.size.height / 2) / proxy.size.height
                    )

                    return content
                        .layerEffect(
                            ShaderLibrary.default.touch_ripple_fragment(
                                .float(elapsed),
                                .float2(Float(normalizedTouch.x), Float(normalizedTouch.y)),
                                .float(Float(rippleProgress))
                            ),
                            maxSampleOffset: CGSize(width: 50.0, height: 50.0)
                        )
                }
        }
        .onChange(of: touchLocation) { _, newValue in
            if newValue != nil {
                withAnimation(.easeOut(duration: 0.6)) {
                    rippleProgress = 1.0
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    rippleProgress = 0
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Shader Effects") {
    if #available(iOS 17.0, *) {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Shimmer effect
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(height: 100.0)
                    .overlay(
                        ShaderShimmerView()
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    )

                // Glow effect
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(height: 100.0)
                    .overlay(
                        ShaderGlowView(color: .DesignSystem.brandGreen)
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    )
            }
            .padding()
        }
        .background(Color.DesignSystem.background)
    } else {
        Text("Requires iOS 17+")
    }
}

#endif
