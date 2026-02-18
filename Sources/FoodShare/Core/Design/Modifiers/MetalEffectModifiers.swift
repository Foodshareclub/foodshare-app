//
//  MetalEffectModifiers.swift
//  Foodshare
//
//  Swift wrappers for Metal shader effects
//  Enhanced with unified MetalEffect API and iOS 17+ ShaderLibrary support
//


#if !SKIP
import MetalKit
import SwiftUI

// MARK: - Unified Metal Effect Modifier

/// Unified view modifier that applies any MetalEffect to a view
struct MetalEffectModifier: ViewModifier {
    let effect: MetalEffect
    let respectsReduceMotion: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(effect: MetalEffect, respectsReduceMotion: Bool = true) {
        self.effect = effect
        self.respectsReduceMotion = respectsReduceMotion
    }

    func body(content: Content) -> some View {
        if respectsReduceMotion && reduceMotion {
            content
        } else {
            applyEffect(to: content)
        }
    }

    @ViewBuilder
    private func applyEffect(to content: Content) -> some View {
        switch effect {
        case .none:
            content
        case let .glassBlur(intensity, tint):
            content.overlay(
                MetalEffectView(
                    shaderName: effect.shaderName,
                    intensity: Float(intensity),
                    tintColor: tint.opacity(0.1)
                )
                .allowsHitTesting(false)
            )
        case let .shimmer(intensity, color):
            content.overlay(
                MetalEffectView(
                    shaderName: effect.shaderName,
                    intensity: Float(intensity),
                    tintColor: color
                )
                .allowsHitTesting(false)
            )
        case let .liquidRipple(intensity):
            content.overlay(
                MetalEffectView(
                    shaderName: effect.shaderName,
                    intensity: Float(intensity),
                    tintColor: .blue.opacity(0.3)
                )
                .allowsHitTesting(false)
            )
        case let .chromaticAberration(intensity):
            content.overlay(
                MetalEffectView(
                    shaderName: effect.shaderName,
                    intensity: Float(intensity),
                    tintColor: .clear
                )
                .allowsHitTesting(false)
            )
        case let .glow(color, intensity):
            content.overlay(
                MetalEffectView(
                    shaderName: effect.shaderName,
                    intensity: Float(intensity),
                    tintColor: color
                )
                .allowsHitTesting(false)
            )
        case let .frostedGlass(intensity):
            content.overlay(
                MetalEffectView(
                    shaderName: effect.shaderName,
                    intensity: Float(intensity),
                    tintColor: .white.opacity(0.2)
                )
                .allowsHitTesting(false)
            )
        case let .gradientMesh(tint, intensity):
            content.overlay(
                MetalEffectView(
                    shaderName: effect.shaderName,
                    intensity: Float(intensity),
                    tintColor: tint
                )
                .allowsHitTesting(false)
            )
        case let .depthBlur(intensity):
            content.overlay(
                MetalEffectView(
                    shaderName: effect.shaderName,
                    intensity: Float(intensity),
                    tintColor: .clear
                )
                .allowsHitTesting(false)
            )
        case let .combined(effects):
            effects.reduce(AnyView(content)) { view, effect in
                AnyView(view.modifier(MetalEffectModifier(effect: effect, respectsReduceMotion: false)))
            }
        default:
            // For effects not yet implemented, just return content
            content
        }
    }
}

extension View {
    /// Apply a unified Metal effect to this view
    /// - Parameters:
    ///   - effect: The MetalEffect to apply
    ///   - respectsReduceMotion: Whether to disable effect when reduce motion is enabled
    func metalEffect(_ effect: MetalEffect, respectsReduceMotion: Bool = true) -> some View {
        modifier(MetalEffectModifier(effect: effect, respectsReduceMotion: respectsReduceMotion))
    }
}

// MARK: - Metal Effect View

struct MetalEffectView: UIViewRepresentable {
    let shaderName: String
    let intensity: Float
    let tintColor: Color
    @State private var time: Float = 0

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.intensity = intensity
        context.coordinator.tintColor = tintColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(shaderName: shaderName, intensity: intensity, tintColor: tintColor)
    }

    class Coordinator: NSObject, MTKViewDelegate {
        var device: MTLDevice?
        var commandQueue: MTLCommandQueue?
        var pipelineState: MTLRenderPipelineState?
        var shaderName: String
        var intensity: Float
        var tintColor: Color
        var time: Float = 0

        init(shaderName: String, intensity: Float, tintColor: Color) {
            self.shaderName = shaderName
            self.intensity = intensity
            self.tintColor = tintColor
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
            pipelineDescriptor.fragmentFunction = library.makeFunction(name: shaderName)
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            time += 0.016 // ~60fps

            guard let drawable = view.currentDrawable,
                  let pipelineState,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
                return
            }

            renderEncoder.setRenderPipelineState(pipelineState)

            // Pass uniforms
            var uniforms = FragmentUniforms(
                time: time,
                resolution: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
                intensity: intensity,
                tintColor: tintColor.toSIMD4(),
            )
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<FragmentUniforms>.stride, index: 0)

            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
            renderEncoder.endEncoding()

            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

struct FragmentUniforms {
    var time: Float
    var resolution: SIMD2<Float>
    var intensity: Float
    var tintColor: SIMD4<Float>
}

// MARK: - Color Extension

extension Color {
    func toSIMD4() -> SIMD4<Float> {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply glass blur effect using Metal shader
    func glassBlur(intensity: CGFloat = 1.0) -> some View {
        overlay(
            MetalEffectView(
                shaderName: "glass_blur_fragment",
                intensity: Float(intensity),
                tintColor: .white.opacity(0.1),
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply frosted glass effect
    func frostedGlass(intensity: CGFloat = 1.0) -> some View {
        overlay(
            MetalEffectView(
                shaderName: "frosted_glass_fragment",
                intensity: Float(intensity),
                tintColor: .white.opacity(0.2),
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply shimmer effect
    func shimmer(intensity: CGFloat = 1.0, color: Color = .white) -> some View {
        overlay(
            MetalEffectView(
                shaderName: "shimmer_fragment",
                intensity: Float(intensity),
                tintColor: color,
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply liquid ripple effect
    func liquidRipple(intensity: CGFloat = 1.0) -> some View {
        overlay(
            MetalEffectView(
                shaderName: "liquid_ripple_fragment",
                intensity: Float(intensity),
                tintColor: .blue.opacity(0.3),
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply chromatic aberration
    func chromaticAberration(intensity: CGFloat = 1.0) -> some View {
        overlay(
            MetalEffectView(
                shaderName: "chromatic_aberration_fragment",
                intensity: Float(intensity),
                tintColor: .clear,
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply glow effect
    func metalGlow(intensity: CGFloat = 1.0, color: Color = Color.DesignSystem.brandGreen) -> some View {
        overlay(
            MetalEffectView(
                shaderName: "glow_fragment",
                intensity: Float(intensity),
                tintColor: color,
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply gradient mesh effect
    func gradientMesh(intensity: CGFloat = 1.0, tint: Color = Color.DesignSystem.primary) -> some View {
        overlay(
            MetalEffectView(
                shaderName: "gradient_mesh_fragment",
                intensity: Float(intensity),
                tintColor: tint,
            )
            .allowsHitTesting(false),
        )
    }

    /// Apply depth blur effect (stronger at edges)
    func depthBlur(intensity: CGFloat = 1.0) -> some View {
        overlay(
            MetalEffectView(
                shaderName: "depth_blur_fragment",
                intensity: Float(intensity),
                tintColor: .clear,
            )
            .allowsHitTesting(false),
        )
    }
}

#endif
