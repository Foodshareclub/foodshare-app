//
//  ProfileMetalEffects.swift
//  Foodshare
//
//  Swift wrappers for Profile Metal shader effects
//  Optimized for ProMotion 120Hz displays
//


#if !SKIP
import MetalKit
import SwiftUI

// MARK: - Profile Metal Effect Type

enum ProfileMetalEffect: String, CaseIterable {
    case avatarRing = "avatar_ring_fragment"
    case progressRing = "progress_ring_fragment"
    case statsBackground = "stats_background_fragment"
    case badgeGlow = "badge_glow_fragment"
    case impactViz = "impact_viz_fragment"
    case liquidGlassRefraction = "liquid_glass_refraction_fragment"
}

// MARK: - Profile Uniforms

struct ProfileShaderUniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var intensity: Float
    var primaryColor: SIMD4<Float>
    var secondaryColor: SIMD4<Float>
    var progress: Float
}

// MARK: - Profile Metal Effect View

struct ProfileMetalEffectView: UIViewRepresentable {
    let effect: ProfileMetalEffect
    let intensity: Float
    let primaryColor: Color
    let secondaryColor: Color
    let progress: Float

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        effect: ProfileMetalEffect,
        intensity: Float = 1.0,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandBlue,
        progress: Float = 0.0,
    ) {
        self.effect = effect
        self.intensity = intensity
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.progress = progress
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear

        // ProMotion optimization: prefer 120Hz when available
        mtkView.preferredFramesPerSecond = 120

        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.intensity = intensity
        context.coordinator.primaryColor = primaryColor
        context.coordinator.secondaryColor = secondaryColor
        context.coordinator.progress = progress
        context.coordinator.reduceMotion = reduceMotion
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            effect: effect,
            intensity: intensity,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            progress: progress,
        )
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var effect: ProfileMetalEffect
        var intensity: Float
        var primaryColor: Color
        var secondaryColor: Color
        var progress: Float
        var reduceMotion = false
        private var time: Float = 0

        init(
            effect: ProfileMetalEffect,
            intensity: Float,
            primaryColor: Color,
            secondaryColor: Color,
            progress: Float,
        ) {
            self.effect = effect
            self.intensity = intensity
            self.primaryColor = primaryColor
            self.secondaryColor = secondaryColor
            self.progress = progress
            super.init()
            setupMetal()
        }

        func setupMetal() {
            guard let device = MTLCreateSystemDefaultDevice() else { return }
            self.device = device
            commandQueue = device.makeCommandQueue()

            guard let library = device.makeDefaultLibrary() else { return }

            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = library.makeFunction(name: "glass_vertex")
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: effect.rawValue)
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            // Enable alpha blending
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            // Reduce animation speed if reduce motion is enabled
            let timeIncrement: Float = reduceMotion ? 0.004 : 0.016
            time += timeIncrement

            guard let drawable = view.currentDrawable,
                  let pipelineState,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else
            {
                return
            }

            renderEncoder.setRenderPipelineState(pipelineState)

            var uniforms = ProfileShaderUniforms(
                time: time,
                resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                intensity: intensity,
                primaryColor: primaryColor.toSIMD4(),
                secondaryColor: secondaryColor.toSIMD4(),
                progress: progress,
            )
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<ProfileShaderUniforms>.stride, index: 0)

            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply animated avatar ring effect using Metal shader
    func avatarRingEffect(
        intensity: CGFloat = 1.0,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandBlue,
    ) -> some View {
        overlay(
            ProfileMetalEffectView(
                effect: .avatarRing,
                intensity: Float(intensity),
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply animated progress ring effect
    func progressRingEffect(
        progress: CGFloat,
        intensity: CGFloat = 1.0,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandTeal,
    ) -> some View {
        overlay(
            ProfileMetalEffectView(
                effect: .progressRing,
                intensity: Float(intensity),
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                progress: Float(progress),
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply animated stats background effect
    func statsBackgroundEffect(
        intensity: CGFloat = 0.5,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandBlue,
    ) -> some View {
        background(
            ProfileMetalEffectView(
                effect: .statsBackground,
                intensity: Float(intensity),
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
            ),
        )
    }

    /// Apply badge glow effect
    func badgeGlowEffect(
        intensity: CGFloat = 1.0,
        color: Color = .DesignSystem.medalGold,
    ) -> some View {
        overlay(
            ProfileMetalEffectView(
                effect: .badgeGlow,
                intensity: Float(intensity),
                primaryColor: color,
                secondaryColor: color,
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply environmental impact visualization
    func impactVisualization(
        intensity: CGFloat = 0.6,
        color: Color = .DesignSystem.brandGreen,
    ) -> some View {
        background(
            ProfileMetalEffectView(
                effect: .impactViz,
                intensity: Float(intensity),
                primaryColor: color,
                secondaryColor: color,
            ),
        )
    }
}

// MARK: - Standalone Effect Views

/// Animated avatar ring component
struct MetalAvatarRing: View {
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        size: CGFloat = 120,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandBlue,
    ) {
        self.size = size
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }

    var body: some View {
        if reduceMotion {
            // Fallback for reduced motion
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: size * 0.08,
                )
                .frame(width: size, height: size)
        } else {
            ProfileMetalEffectView(
                effect: .avatarRing,
                intensity: 1.0,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
            )
            .frame(width: size, height: size)
        }
    }
}

/// Animated circular progress indicator
struct MetalProgressRing: View {
    let progress: CGFloat
    let size: CGFloat
    let primaryColor: Color
    let secondaryColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        progress: CGFloat,
        size: CGFloat = 80,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandTeal,
    ) {
        self.progress = progress
        self.size = size
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
    }

    var body: some View {
        if reduceMotion {
            // Fallback for reduced motion
            ZStack {
                Circle()
                    .stroke(Color.DesignSystem.glassBackground, lineWidth: size * 0.1)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [primaryColor, secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round),
                    )
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: size, height: size)
        } else {
            ProfileMetalEffectView(
                effect: .progressRing,
                intensity: 1.0,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                progress: Float(progress),
            )
            .frame(width: size, height: size)
        }
    }
}

/// Badge with animated glow effect
struct MetalBadgeGlow: View {
    let size: CGFloat
    let color: Color
    let isEarned: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        size: CGFloat = 60,
        color: Color = .DesignSystem.medalGold,
        isEarned: Bool = true,
    ) {
        self.size = size
        self.color = color
        self.isEarned = isEarned
    }

    var body: some View {
        if reduceMotion || !isEarned {
            // Static fallback
            Circle()
                .fill(
                    RadialGradient(
                        colors: isEarned ? [color, color.opacity(0.3)] : [.gray.opacity(0.3), .gray.opacity(0.1)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2,
                    ),
                )
                .frame(width: size, height: size)
        } else {
            ProfileMetalEffectView(
                effect: .badgeGlow,
                intensity: 1.0,
                primaryColor: color,
                secondaryColor: color,
            )
            .frame(width: size, height: size)
        }
    }
}

// MARK: - Preview

#Preview("Profile Metal Effects") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Text("Avatar Ring")
                .font(.DesignSystem.headlineSmall)

            MetalAvatarRing(size: 120)

            Text("Progress Ring")
                .font(.DesignSystem.headlineSmall)

            HStack(spacing: Spacing.lg) {
                MetalProgressRing(progress: 0.25, size: 60)
                MetalProgressRing(progress: 0.5, size: 60)
                MetalProgressRing(progress: 0.75, size: 60)
                MetalProgressRing(progress: 1.0, size: 60)
            }

            Text("Badge Glow")
                .font(.DesignSystem.headlineSmall)

            HStack(spacing: Spacing.lg) {
                MetalBadgeGlow(size: 50, color: .DesignSystem.medalGold)
                MetalBadgeGlow(size: 50, color: .DesignSystem.medalSilver)
                MetalBadgeGlow(size: 50, color: .DesignSystem.medalBronze)
            }

            Text("Stats Background")
                .font(.DesignSystem.headlineSmall)

            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.clear)
                .frame(height: 100.0)
                .statsBackgroundEffect()
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))

            Text("Impact Visualization")
                .font(.DesignSystem.headlineSmall)

            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.clear)
                .frame(height: 100.0)
                .impactVisualization()
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        }
        .padding()
    }
    .background(Color.DesignSystem.background)
    .preferredColorScheme(.dark)
}

#endif
