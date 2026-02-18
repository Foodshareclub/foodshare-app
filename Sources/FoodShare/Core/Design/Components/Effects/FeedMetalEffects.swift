//
//  FeedMetalEffects.swift
//  Foodshare
//
//  Swift wrappers for Feed Metal shader effects
//  GPU-accelerated card effects optimized for ProMotion 120Hz
//


#if !SKIP
import MetalKit
import SwiftUI

// MARK: - Feed Metal Effect Type

enum FeedMetalEffect: String, CaseIterable {
    case cardShimmer = "card_shimmer_fragment"
    case cardHoverGlow = "card_hover_glow_fragment"
    case trendingBadge = "trending_badge_fragment"
    case urgentPulse = "urgent_pulse_fragment"
    case categoryChipGlow = "category_chip_glow_fragment"
    case cardParallax = "card_parallax_background_fragment"
    case freshSparkle = "fresh_item_sparkle_fragment"
    case saveHeart = "save_heart_fragment"
    case distanceIndicator = "distance_indicator_fragment"
}

// MARK: - Feed Uniforms

struct FeedShaderUniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var intensity: Float
    var primaryColor: SIMD4<Float>
    var secondaryColor: SIMD4<Float>
    var progress: Float
    var parallaxOffset: Float
    var isUrgent: Float
}

// MARK: - Feed Metal Effect View

struct FeedMetalEffectView: UIViewRepresentable {
    let effect: FeedMetalEffect
    let intensity: Float
    let primaryColor: Color
    let secondaryColor: Color
    let progress: Float
    let parallaxOffset: Float

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        effect: FeedMetalEffect,
        intensity: Float = 1.0,
        primaryColor: Color = .DesignSystem.brandPink,
        secondaryColor: Color = .DesignSystem.brandTeal,
        progress: Float = 0.0,
        parallaxOffset: Float = 0.0
    ) {
        self.effect = effect
        self.intensity = intensity
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.progress = progress
        self.parallaxOffset = parallaxOffset
    }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear
        mtkView.preferredFramesPerSecond = 120
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.intensity = intensity
        context.coordinator.primaryColor = primaryColor
        context.coordinator.secondaryColor = secondaryColor
        context.coordinator.progress = progress
        context.coordinator.parallaxOffset = parallaxOffset
        context.coordinator.reduceMotion = reduceMotion
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            effect: effect,
            intensity: intensity,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            progress: progress,
            parallaxOffset: parallaxOffset
        )
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var effect: FeedMetalEffect
        var intensity: Float
        var primaryColor: Color
        var secondaryColor: Color
        var progress: Float
        var parallaxOffset: Float
        var reduceMotion = false
        private var time: Float = 0

        init(
            effect: FeedMetalEffect,
            intensity: Float,
            primaryColor: Color,
            secondaryColor: Color,
            progress: Float,
            parallaxOffset: Float
        ) {
            self.effect = effect
            self.intensity = intensity
            self.primaryColor = primaryColor
            self.secondaryColor = secondaryColor
            self.progress = progress
            self.parallaxOffset = parallaxOffset
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
            let timeIncrement: Float = reduceMotion ? 0.004 : 0.016
            time += timeIncrement

            guard let drawable = view.currentDrawable,
                  let pipelineState,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
            else { return }

            renderEncoder.setRenderPipelineState(pipelineState)

            var uniforms = FeedShaderUniforms(
                time: time,
                resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                intensity: intensity,
                primaryColor: primaryColor.toSIMD4(),
                secondaryColor: secondaryColor.toSIMD4(),
                progress: progress,
                parallaxOffset: parallaxOffset,
                isUrgent: 0.0
            )
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<FeedShaderUniforms>.stride, index: 0)

            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply shimmer loading effect to cards
    func cardShimmerEffect(intensity: CGFloat = 1.0) -> some View {
        overlay(
            FeedMetalEffectView(
                effect: .cardShimmer,
                intensity: Float(intensity)
            )
            .allowsHitTesting(false)
        )
    }

    /// Apply hover glow effect
    func cardHoverGlow(
        isActive: Bool,
        color: Color = .DesignSystem.brandGreen
    ) -> some View {
        overlay(
            Group {
                if isActive {
                    FeedMetalEffectView(
                        effect: .cardHoverGlow,
                        intensity: 0.8,
                        primaryColor: color
                    )
                    .allowsHitTesting(false)
                }
            }
        )
    }

    /// Apply trending badge effect
    func trendingBadgeEffect(intensity: CGFloat = 1.0) -> some View {
        background(
            FeedMetalEffectView(
                effect: .trendingBadge,
                intensity: Float(intensity)
            )
        )
    }

    /// Apply urgent pulse effect for expiring items
    func urgentPulseEffect(isUrgent: Bool, intensity: CGFloat = 0.8) -> some View {
        overlay(
            Group {
                if isUrgent {
                    FeedMetalEffectView(
                        effect: .urgentPulse,
                        intensity: Float(intensity),
                        primaryColor: .DesignSystem.warning
                    )
                    .allowsHitTesting(false)
                }
            }
        )
    }

    /// Apply category chip glow
    func categoryChipGlow(
        isSelected: Bool,
        color: Color = .DesignSystem.brandGreen
    ) -> some View {
        background(
            Group {
                if isSelected {
                    FeedMetalEffectView(
                        effect: .categoryChipGlow,
                        intensity: 0.6,
                        primaryColor: color
                    )
                }
            }
        )
    }

    /// Apply parallax background effect
    func cardParallaxBackground(
        offset: CGFloat,
        primaryColor: Color = .DesignSystem.brandGreen,
        secondaryColor: Color = .DesignSystem.brandBlue
    ) -> some View {
        background(
            FeedMetalEffectView(
                effect: .cardParallax,
                intensity: 0.5,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                parallaxOffset: Float(offset)
            )
        )
    }

    /// Apply fresh item sparkle effect
    func freshItemSparkle(isNew: Bool, intensity: CGFloat = 0.7) -> some View {
        overlay(
            Group {
                if isNew {
                    FeedMetalEffectView(
                        effect: .freshSparkle,
                        intensity: Float(intensity)
                    )
                    .allowsHitTesting(false)
                }
            }
        )
    }
}

// MARK: - Standalone Effect Components

/// Animated shimmer placeholder for loading cards
struct MetalShimmerCard: View {
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(cornerRadius: CGFloat = CornerRadius.large) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        if reduceMotion {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.DesignSystem.glassBackground)
        } else {
            FeedMetalEffectView(effect: .cardShimmer, intensity: 1.0)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

/// Trending badge with fire animation
struct MetalTrendingBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.translationService) private var t

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if reduceMotion {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
            } else {
                FeedMetalEffectView(effect: .trendingBadge, intensity: 1.0)
                    .frame(width: 20.0, height: 20)
            }

            Text(t.t("feed.trending"))
                .font(.LiquidGlass.captionSmall)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
    }
}

/// Urgent item indicator with pulsing effect
struct MetalUrgentIndicator: View {
    let hoursRemaining: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Spacing.xs) {
            if reduceMotion {
                Image(systemName: "exclamationmark.clock.fill")
                    .foregroundStyle(Color.DesignSystem.warning)
            } else {
                ZStack {
                    FeedMetalEffectView(
                        effect: .urgentPulse,
                        intensity: 0.8,
                        primaryColor: .DesignSystem.warning
                    )
                    .frame(width: 24.0, height: 24)

                    Image(systemName: "clock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                }
            }

            Text(hoursRemaining <= 1 ? "Expiring soon!" : "\(hoursRemaining)h left")
                .font(.LiquidGlass.captionSmall)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(Color.DesignSystem.warning)
        )
    }
}

/// Animated save heart button
struct MetalSaveButton: View {
    @Binding var isSaved: Bool
    let onTap: () -> Void

    @State private var animationProgress: Float = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 15)) {
                isSaved.toggle()
            }

            if isSaved && !reduceMotion {
                animationProgress = 1.0
                withAnimation(.easeOut(duration: 0.6)) {
                    animationProgress = 0
                }
            }

            HapticManager.light()
            onTap()
        } label: {
            ZStack {
                if !reduceMotion && animationProgress > 0 {
                    FeedMetalEffectView(
                        effect: .saveHeart,
                        intensity: 1.0,
                        primaryColor: .DesignSystem.brandPink,
                        progress: animationProgress
                    )
                    .frame(width: 44.0, height: 44)
                }

                Image(systemName: isSaved ? "heart.fill" : "heart")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSaved ? Color.DesignSystem.brandPink : .white)
                    .scaleEffect(isSaved ? 1.1 : 1.0)
            }
            .frame(width: 44.0, height: 44)
            .background(
                Circle()
                    #if !SKIP
                    .fill(.ultraThinMaterial)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isSaved ? "Remove from saved" : "Save item")
    }
}

/// Distance indicator with gradient
struct MetalDistanceIndicator: View {
    let distanceKm: Double
    let maxDistanceKm: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var progress: Float {
        Float(min(distanceKm / maxDistanceKm, 1.0))
    }

    private var distanceText: String {
        if distanceKm < 1 {
            return String(format: "%.0fm", distanceKm * 1000)
        } else {
            return String(format: "%.1fkm", distanceKm)
        }
    }

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "location.fill")
                .font(.system(size: 10))
                .foregroundStyle(distanceColor)

            if reduceMotion {
                Text(distanceText)
                    .font(.LiquidGlass.captionSmall)
                    .foregroundStyle(distanceColor)
            } else {
                ZStack(alignment: .leading) {
                    FeedMetalEffectView(
                        effect: .distanceIndicator,
                        intensity: 1.0,
                        progress: progress
                    )
                    .frame(width: 40.0, height: 6)
                    .clipShape(Capsule())

                    Text(distanceText)
                        .font(.LiquidGlass.captionSmall)
                        .foregroundStyle(distanceColor)
                        .offset(x: 44)
                }
            }
        }
    }

    private var distanceColor: Color {
        if distanceKm < 1 {
            return .DesignSystem.success
        } else if distanceKm < 3 {
            return .DesignSystem.brandGreen
        } else if distanceKm < 5 {
            return .DesignSystem.warning
        } else {
            return .DesignSystem.brandOrange
        }
    }
}

// MARK: - Preview

#Preview("Feed Metal Effects") {
    ScrollView {
        VStack(spacing: Spacing.xl) {
            Text("Shimmer Card")
                .font(.DesignSystem.headlineSmall)

            MetalShimmerCard()
                .frame(height: 200.0)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))

            Text("Trending Badge")
                .font(.DesignSystem.headlineSmall)

            MetalTrendingBadge()

            Text("Urgent Indicators")
                .font(.DesignSystem.headlineSmall)

            HStack(spacing: Spacing.md) {
                MetalUrgentIndicator(hoursRemaining: 1)
                MetalUrgentIndicator(hoursRemaining: 6)
                MetalUrgentIndicator(hoursRemaining: 12)
            }

            Text("Save Button")
                .font(.DesignSystem.headlineSmall)

            HStack(spacing: Spacing.lg) {
                MetalSaveButton(isSaved: .constant(false)) {}
                MetalSaveButton(isSaved: .constant(true)) {}
            }

            Text("Distance Indicators")
                .font(.DesignSystem.headlineSmall)

            VStack(spacing: Spacing.sm) {
                MetalDistanceIndicator(distanceKm: 0.3, maxDistanceKm: 10)
                MetalDistanceIndicator(distanceKm: 2.5, maxDistanceKm: 10)
                MetalDistanceIndicator(distanceKm: 7.0, maxDistanceKm: 10)
            }
        }
        .padding()
    }
    .background(Color.DesignSystem.background)
    .preferredColorScheme(.dark)
}

#endif
