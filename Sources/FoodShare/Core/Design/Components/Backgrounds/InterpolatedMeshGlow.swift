//
//  InterpolatedMeshGlow.swift
//  Foodshare
//
//  Liquid Glass v26 - Interpolated Mesh Glow Effect
//  Creates a high-detail animated glow using 5x5 MeshGradient
//  Requires iOS 18+ for MeshGradient support
//


#if !SKIP
import SwiftUI

/// Animated glow effect using MeshGradient with color interpolation
/// Creates a pulsing, breathing glow effect perfect for emphasis elements
@available(iOS 18.0, macOS 15.0, *)
struct InterpolatedMeshGlow: View {
    /// Starting colors for interpolation
    let fromColors: [Color]
    /// Target colors for interpolation
    let toColors: [Color]
    /// Current interpolation progress (0.0 - 1.0)
    let progress: Double
    /// Duration for fade animation
    let fadeDuration: Double
    /// Base size of the glow circle
    let baseSize: CGFloat

    @State private var scale: CGFloat = 1
    @State private var blur: CGFloat = 20

    init(
        fromColors: [Color] = [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue,
                               Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan,
                               Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue,
                               Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan,
                               Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue],
        toColors: [Color] = [Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan,
                             Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue,
                             Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan,
                             Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue,
                             Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan, Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan],
        progress: Double = 0.5,
        fadeDuration: Double = 3.0,
        baseSize: CGFloat = 200
    ) {
        self.fromColors = fromColors
        self.toColors = toColors
        self.progress = progress
        self.fadeDuration = fadeDuration
        self.baseSize = baseSize
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate * 0.5
            let animatedColors = zip(fromColors, toColors).enumerated().map { i, pair in
                pair.0.interpolate(to: pair.1, amount: progress)
                    .opacity(0.2 + sin(t + Double(i)) * 0.3)
            }

            Circle()
                .fill(
                    MeshGradient(
                        width: 5,
                        height: 5,
                        points: meshPoints,
                        colors: animatedColors,
                        smoothsColors: true,
                        colorSpace: .perceptual
                    )
                )
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(scale)
                .blur(radius: blur)
                .drawingGroup() // GPU rasterization for 120Hz ProMotion
                .onAppear {
                    withAnimation(
                        .easeInOut(duration: fadeDuration)
                            .repeatForever(autoreverses: true)
                    ) {
                        scale = 1.25
                        blur = 35
                    }
                }
        }
    }

    /// 5x5 grid of mesh points for high-detail glow
    private var meshPoints: [SIMD2<Float>] {
        [
            [0, 0], [0.25, 0], [0.5, 0], [0.75, 0], [1, 0],
            [0, 0.25], [0.25, 0.25], [0.5, 0.25], [0.75, 0.25], [1, 0.25],
            [0, 0.5], [0.25, 0.5], [0.5, 0.5], [0.75, 0.5], [1, 0.5],
            [0, 0.75], [0.25, 0.75], [0.5, 0.75], [0.75, 0.75], [1, 0.75],
            [0, 1], [0.25, 1], [0.5, 1], [0.75, 1], [1, 1]
        ]
    }
}

// MARK: - Convenience Initializers

@available(iOS 18.0, macOS 15.0, *)
extension InterpolatedMeshGlow {
    /// Blue/Cyan glow preset for auth screens
    static func blueCyan(size: CGFloat = 200, progress: Double = 0.5) -> InterpolatedMeshGlow {
        InterpolatedMeshGlow(
            fromColors: Array(repeating: Color.DesignSystem.accentBlue, count: 25),
            toColors: Array(repeating: Color.DesignSystem.accentCyan, count: 25),
            progress: progress,
            fadeDuration: 3.0,
            baseSize: size
        )
    }

    /// Green glow preset (Foodshare brand)
    static func green(size: CGFloat = 200, progress: Double = 0.5) -> InterpolatedMeshGlow {
        InterpolatedMeshGlow(
            fromColors: Array(repeating: Color.DesignSystem.brandGreen, count: 25),
            toColors: Array(repeating: Color.DesignSystem.brandCyan, count: 25),
            progress: progress,
            fadeDuration: 3.0,
            baseSize: size
        )
    }

    /// Nature Green/Blue glow preset (Primary theme)
    static func nature(size: CGFloat = 200, progress: Double = 0.5) -> InterpolatedMeshGlow {
        InterpolatedMeshGlow(
            fromColors: Array(repeating: Color.DesignSystem.brandGreen, count: 25),
            toColors: Array(repeating: Color.DesignSystem.brandBlue, count: 25),
            progress: progress,
            fadeDuration: 3.5,
            baseSize: size
        )
    }

    /// Purple/Pink glow preset
    static func purplePink(size: CGFloat = 200, progress: Double = 0.5) -> InterpolatedMeshGlow {
        InterpolatedMeshGlow(
            fromColors: Array(repeating: Color.DesignSystem.brandPurple, count: 25),
            toColors: Array(repeating: Color.DesignSystem.accentPink, count: 25),
            progress: progress,
            fadeDuration: 3.0,
            baseSize: size
        )
    }

    /// Foodshare brand pink glow preset (Primary brand identity)
    static func brandPink(size: CGFloat = 200, progress: Double = 0.5) -> InterpolatedMeshGlow {
        InterpolatedMeshGlow(
            fromColors: Array(repeating: Color.DesignSystem.brandPink, count: 25),
            toColors: Array(repeating: Color.DesignSystem.brandTeal, count: 25),
            progress: progress,
            fadeDuration: 3.5,
            baseSize: size
        )
    }

    /// Foodshare pink to orange glow preset
    static func pinkOrange(size: CGFloat = 200, progress: Double = 0.5) -> InterpolatedMeshGlow {
        InterpolatedMeshGlow(
            fromColors: Array(repeating: Color.DesignSystem.brandPink, count: 25),
            toColors: Array(repeating: Color.DesignSystem.brandOrange, count: 25),
            progress: progress,
            fadeDuration: 3.0,
            baseSize: size
        )
    }
}

// MARK: - Simple Glow Effect (Non-Mesh)

/// Simpler glow effect using radial gradient
/// Use when MeshGradient is too heavy or for simpler use cases
struct SimpleGlow: View {
    let color: Color
    let size: CGFloat
    let blur: CGFloat

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6

    init(color: Color = Color.DesignSystem.accentBlue, size: CGFloat = 150, blur: CGFloat = 40) {
        self.color = color
        self.size = size
        self.blur = blur
    }

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        color.opacity(0.6),
                        color.opacity(0.3),
                        color.opacity(0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: blur)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 2.5)
                        .repeatForever(autoreverses: true)
                ) {
                    scale = 1.15
                    opacity = 0.8
                }
            }
    }
}

@available(iOS 18.0, macOS 15.0, *)
#Preview("Nature Green/Blue Glow") {
    ZStack {
        Color.black.ignoresSafeArea()
        InterpolatedMeshGlow.nature(size: 300)
    }
}

@available(iOS 18.0, macOS 15.0, *)
#Preview("Interpolated Mesh Glow") {
    ZStack {
        Color.black.ignoresSafeArea()
        InterpolatedMeshGlow.blueCyan(size: 300)
    }
}

@available(iOS 18.0, macOS 15.0, *)
#Preview("Foodshare Brand Pink Glow") {
    ZStack {
        Color.black.ignoresSafeArea()
        InterpolatedMeshGlow.brandPink(size: 300)
    }
}

@available(iOS 18.0, macOS 15.0, *)
#Preview("Pink Orange Glow") {
    ZStack {
        Color.black.ignoresSafeArea()
        InterpolatedMeshGlow.pinkOrange(size: 300)
    }
}

#Preview("Simple Glow") {
    ZStack {
        Color.black.ignoresSafeArea()
        SimpleGlow(color: .cyan, size: 200, blur: 50)
    }
}

#endif
