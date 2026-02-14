import MetalKit
import SwiftUI
import FoodShareDesignSystem

// MARK: - Metal Shader Effect

/// Represents a Metal shader effect with its parameters
public enum MetalShaderEffect: Equatable {
    case liquidDistortion(intensity: CGFloat, center: CGPoint, time: CGFloat)
    case chromaticAberration(intensity: CGFloat, center: CGPoint)
    case depthBlur(focusPoint: CGFloat, focusRange: CGFloat, strength: CGFloat)
    case glassFrost(intensity: CGFloat, scale: CGFloat, time: CGFloat)
    case glow(color: Color, intensity: CGFloat, radius: CGFloat)
    case none
}

// MARK: - Metal Shader View

/// SwiftUI view that applies Metal shader effects to its content
/// Falls back to SwiftUI blur on non-Metal devices
public struct MetalShaderView<Content: View>: View {

    // MARK: - Properties

    let effect: MetalShaderEffect
    let content: () -> Content

    @State private var metalAvailable = true

    // MARK: - Initialization

    public init(
        effect: MetalShaderEffect,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.effect = effect
        self.content = content
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if metalAvailable {
                metalContent
            } else {
                fallbackContent
            }
        }
        .onAppear {
            checkMetalAvailability()
        }
    }

    // MARK: - Metal Content

    @ViewBuilder
    private var metalContent: some View {
        switch effect {
        case let .liquidDistortion(intensity, center, time):
            content()
                .modifier(LiquidDistortionModifier(
                    intensity: intensity,
                    center: center,
                    time: time,
                ))

        case let .chromaticAberration(intensity, center):
            content()
                .modifier(ChromaticAberrationModifier(
                    intensity: intensity,
                    center: center,
                ))

        case let .depthBlur(focusPoint, focusRange, strength):
            content()
                .modifier(DepthBlurModifier(
                    focusPoint: focusPoint,
                    focusRange: focusRange,
                    strength: strength,
                ))

        case let .glassFrost(intensity, scale, time):
            content()
                .modifier(GlassFrostModifier(
                    intensity: intensity,
                    scale: scale,
                    time: time,
                ))

        case let .glow(color, intensity, radius):
            content()
                .modifier(MetalGlowModifier(
                    glowColor: color,
                    intensity: intensity,
                    radius: radius,
                ))

        case .none:
            content()
        }
    }

    // MARK: - Fallback Content

    @ViewBuilder
    private var fallbackContent: some View {
        switch effect {
        case .liquidDistortion, .glassFrost:
            content()
                .blur(radius: 2)

        case .chromaticAberration:
            content() // No good SwiftUI fallback

        case let .depthBlur(_, _, strength):
            content()
                .blur(radius: strength * 10)

        case let .glow(color, intensity, _):
            content()
                .shadow(color: color.opacity(intensity), radius: 10)

        case .none:
            content()
        }
    }

    // MARK: - Helpers

    private func checkMetalAvailability() {
        metalAvailable = MTLCreateSystemDefaultDevice() != nil
    }
}

// MARK: - Liquid Distortion Modifier

/// iOS 17+ shader modifier for liquid distortion effect
struct LiquidDistortionModifier: ViewModifier {
    let intensity: CGFloat
    let center: CGPoint
    let time: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .visualEffect { content, proxy in
                    content
                        .distortionEffect(
                            ShaderLibrary.liquidDistortion(
                                .float(time),
                                .float(intensity),
                                .float2(center.x, center.y),
                                .float2(proxy.size.width, proxy.size.height),
                            ),
                            maxSampleOffset: CGSize(width: 20, height: 20),
                        )
                }
        } else {
            content
        }
    }
}

// MARK: - Chromatic Aberration Modifier

struct ChromaticAberrationModifier: ViewModifier {
    let intensity: CGFloat
    let center: CGPoint

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .visualEffect { content, proxy in
                    content
                        .colorEffect(
                            ShaderLibrary.chromaticAberration(
                                .float(intensity),
                                .float2(center.x, center.y),
                                .float2(proxy.size.width, proxy.size.height),
                            ),
                        )
                }
        } else {
            content
        }
    }
}

// MARK: - Depth Blur Modifier

struct DepthBlurModifier: ViewModifier {
    let focusPoint: CGFloat
    let focusRange: CGFloat
    let strength: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .visualEffect { content, proxy in
                    content
                        .layerEffect(
                            ShaderLibrary.depthBlur(
                                .float(focusPoint),
                                .float(focusRange),
                                .float(strength),
                                .float2(proxy.size.width, proxy.size.height),
                            ),
                            maxSampleOffset: CGSize(width: 50, height: 50),
                        )
                }
        } else {
            content
                .blur(radius: strength * 10)
        }
    }
}

// MARK: - Glass Frost Modifier

struct GlassFrostModifier: ViewModifier {
    let intensity: CGFloat
    let scale: CGFloat
    let time: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .visualEffect { content, proxy in
                    content
                        .distortionEffect(
                            ShaderLibrary.glassFrost(
                                .float(intensity),
                                .float(scale),
                                .float(time),
                                .float2(proxy.size.width, proxy.size.height),
                            ),
                            maxSampleOffset: CGSize(width: 10, height: 10),
                        )
                }
        } else {
            content
                .blur(radius: intensity * 5)
        }
    }
}

// MARK: - Metal Glow Modifier

struct MetalGlowModifier: ViewModifier {
    let glowColor: Color
    let intensity: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        ZStack {
            // Glow layer
            content
                .blur(radius: radius)
                .opacity(intensity)
                .blendMode(.screen)

            // Original content
            content
        }
    }
}

// MARK: - SwiftUI Shader Library (iOS 17+)

@available(iOS 17.0, *)
extension ShaderLibrary {
    /// Liquid distortion effect
    static func liquidDistortion(
        _ time: Shader.Argument,
        _ intensity: Shader.Argument,
        _ center: Shader.Argument,
        _ size: Shader.Argument,
    ) -> Shader {
        ShaderLibrary.default.liquidDistortion(time, intensity, center, size)
    }

    /// Chromatic aberration effect
    static func chromaticAberration(
        _ intensity: Shader.Argument,
        _ center: Shader.Argument,
        _ size: Shader.Argument,
    ) -> Shader {
        ShaderLibrary.default.chromaticAberration(intensity, center, size)
    }

    /// Depth blur (tilt-shift) effect
    static func depthBlur(
        _ focusPoint: Shader.Argument,
        _ focusRange: Shader.Argument,
        _ strength: Shader.Argument,
        _ size: Shader.Argument,
    ) -> Shader {
        ShaderLibrary.default.depthBlur(focusPoint, focusRange, strength, size)
    }

    /// Frosted glass effect
    static func glassFrost(
        _ intensity: Shader.Argument,
        _ scale: Shader.Argument,
        _ time: Shader.Argument,
        _ size: Shader.Argument,
    ) -> Shader {
        ShaderLibrary.default.glassFrost(intensity, scale, time, size)
    }
}

// MARK: - View Extensions

extension View {
    /// Applies liquid distortion effect
    public func liquidDistortion(
        intensity: CGFloat = 0.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5),
        time: CGFloat = 0,
    ) -> some View {
        MetalShaderView(effect: .liquidDistortion(intensity: intensity, center: center, time: time)) {
            self
        }
    }

    /// Applies chromatic aberration effect
    public func chromaticAberration(
        intensity: CGFloat = 0.3,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5),
    ) -> some View {
        MetalShaderView(effect: .chromaticAberration(intensity: intensity, center: center)) {
            self
        }
    }

    /// Applies depth blur (tilt-shift) effect
    public func depthBlur(
        focusPoint: CGFloat = 0.5,
        focusRange: CGFloat = 0.2,
        strength: CGFloat = 0.5,
    ) -> some View {
        MetalShaderView(effect: .depthBlur(focusPoint: focusPoint, focusRange: focusRange, strength: strength)) {
            self
        }
    }

    /// Applies frosted glass effect
    public func glassFrost(
        intensity: CGFloat = 0.5,
        scale: CGFloat = 10,
        time: CGFloat = 0,
    ) -> some View {
        MetalShaderView(effect: .glassFrost(intensity: intensity, scale: scale, time: time)) {
            self
        }
    }

    /// Applies glow effect
    public func glowEffect(
        color: Color = .white,
        intensity: CGFloat = 0.5,
        radius: CGFloat = 10,
    ) -> some View {
        MetalShaderView(effect: .glow(color: color, intensity: intensity, radius: radius)) {
            self
        }
    }
}

// MARK: - Animated Metal Effects

/// Animated liquid distortion with TimelineView
public struct AnimatedLiquidDistortion<Content: View>: View {
    let intensity: CGFloat
    let center: CGPoint
    let speed: Double
    @ViewBuilder let content: () -> Content

    @State private var time: CGFloat = 0

    public init(
        intensity: CGFloat = 0.5,
        center: CGPoint = CGPoint(x: 0.5, y: 0.5),
        speed: Double = 1.0,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.intensity = intensity
        self.center = center
        self.speed = speed
        self.content = content
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let elapsedTime = timeline.date.timeIntervalSinceReferenceDate * speed

            content()
                .liquidDistortion(
                    intensity: intensity,
                    center: center,
                    time: CGFloat(elapsedTime),
                )
        }
    }
}

/// Animated frosted glass with subtle movement
public struct AnimatedGlassFrost<Content: View>: View {
    let intensity: CGFloat
    let scale: CGFloat
    let speed: Double
    @ViewBuilder let content: () -> Content

    public init(
        intensity: CGFloat = 0.5,
        scale: CGFloat = 10,
        speed: Double = 0.5,
        @ViewBuilder content: @escaping () -> Content,
    ) {
        self.intensity = intensity
        self.scale = scale
        self.speed = speed
        self.content = content
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let elapsedTime = timeline.date.timeIntervalSinceReferenceDate * speed

            content()
                .glassFrost(
                    intensity: intensity,
                    scale: scale,
                    time: CGFloat(elapsedTime),
                )
        }
    }
}

// MARK: - Preview

#Preview("Metal Shader Effects") {
    VStack(spacing: 20) {
        Text("Liquid Glass Shaders")
            .font(.DesignSystem.headlineLarge)

        // Chromatic Aberration
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.DesignSystem.brandGreen)
            .frame(height: 100)
            .chromaticAberration(intensity: 0.5)
            .overlay(Text("Chromatic").foregroundStyle(.white))

        // Glow
        RoundedRectangle(cornerRadius: 20)
            .fill(Color.DesignSystem.brandGreen)
            .frame(height: 100)
            .glowEffect(color: .DesignSystem.brandGreen, intensity: 0.8, radius: 15)
            .overlay(Text("Glow").foregroundStyle(.white))

        // Depth Blur
        RoundedRectangle(cornerRadius: 20)
            .fill(
                LinearGradient(
                    colors: [.DesignSystem.brandGreen, .DesignSystem.info],
                    startPoint: .top,
                    endPoint: .bottom,
                ),
            )
            .frame(height: 100)
            .depthBlur(focusPoint: 0.5, focusRange: 0.3, strength: 0.5)
            .overlay(Text("Depth Blur").foregroundStyle(.white))
    }
    .padding()
    .background(Color.DesignSystem.background)
}
