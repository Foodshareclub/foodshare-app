//
//  MetalEffect.swift
//  Foodshare
//
//  Unified Metal effect system for Liquid Glass components
//  Provides type-safe, composable GPU shader effects
//


#if !SKIP
import SwiftUI

// MARK: - MetalEffect Enum

/// Type-safe enumeration of all available Metal shader effects
/// Supports composition via `.combined()` for layered effects
enum MetalEffect: Equatable, Sendable {
    /// Glass blur effect with customizable intensity and tint
    case glassBlur(intensity: CGFloat = 1.0, tint: Color = .white)

    /// Shimmer animation effect for loading states
    case shimmer(intensity: CGFloat = 1.0, color: Color = .white)

    /// Liquid ripple distortion effect
    case liquidRipple(intensity: CGFloat = 1.0)

    /// RGB separation/chromatic aberration effect
    case chromaticAberration(intensity: CGFloat = 1.0)

    /// Glow effect with customizable color
    case glow(color: Color, intensity: CGFloat = 1.0)

    /// Morphing transition between states
    case morphTransition(progress: CGFloat)

    /// Touch-responsive ripple effect
    case touchRipple(center: CGPoint, progress: CGFloat)

    /// Skeleton loading wave effect
    case skeletonWave(intensity: CGFloat = 1.0)

    /// Button press ripple effect
    case buttonPress(center: CGPoint, progress: CGFloat)

    /// Celebration confetti particles
    case celebrationConfetti(intensity: CGFloat = 1.0)

    /// Achievement unlock burst
    case achievementBurst(progress: CGFloat)

    /// Badge sparkle effect
    case badgeSparkle(intensity: CGFloat = 1.0)

    /// Frosted glass effect
    case frostedGlass(intensity: CGFloat = 1.0)

    /// Gradient mesh animation
    case gradientMesh(tint: Color = Color.DesignSystem.primary, intensity: CGFloat = 1.0)

    /// Depth-based blur (stronger at edges)
    case depthBlur(intensity: CGFloat = 1.0)

    /// Holographic iridescent effect
    case holographic(intensity: CGFloat = 1.0)

    /// Energy field effect (touch-reactive)
    case energyField(touchPoint: CGPoint)

    /// Caustics water refraction
    case caustics(intensity: CGFloat = 1.0)

    /// Smoke/vapor effect
    case smoke(intensity: CGFloat = 1.0)

    /// Combined multiple effects (layered)
    case combined([MetalEffect])

    /// None - no effect applied
    case none

    // MARK: - Shader Name Mapping

    /// Returns the Metal shader function name for this effect
    var shaderName: String {
        switch self {
        case .glassBlur: "glass_blur_fragment"
        case .shimmer: "shimmer_fragment"
        case .liquidRipple: "liquid_ripple_fragment"
        case .chromaticAberration: "chromatic_aberration_fragment"
        case .glow: "glow_fragment"
        case .morphTransition: "component_morph_fragment"
        case .touchRipple: "touch_ripple_fragment"
        case .skeletonWave: "skeleton_wave_fragment"
        case .buttonPress: "button_press_ripple_fragment"
        case .celebrationConfetti: "celebration_confetti_compute"
        case .achievementBurst: "achievement_burst_fragment"
        case .badgeSparkle: "badge_sparkle_fragment"
        case .frostedGlass: "frosted_glass_fragment"
        case .gradientMesh: "gradient_mesh_fragment"
        case .depthBlur: "depth_blur_fragment"
        case .holographic: "holographic_fragment"
        case .energyField: "energy_field_fragment"
        case .caustics: "caustics_fragment"
        case .smoke: "smoke_fragment"
        case .combined: "combined_effects_fragment"
        case .none: ""
        }
    }

    // MARK: - Effect Intensity

    /// Returns the intensity value for this effect
    var intensity: CGFloat {
        switch self {
        case let .glassBlur(intensity, _): intensity
        case let .shimmer(intensity, _): intensity
        case let .liquidRipple(intensity): intensity
        case let .chromaticAberration(intensity): intensity
        case let .glow(_, intensity): intensity
        case let .morphTransition(progress): progress
        case let .touchRipple(_, progress): progress
        case let .skeletonWave(intensity): intensity
        case let .buttonPress(_, progress): progress
        case let .celebrationConfetti(intensity): intensity
        case let .achievementBurst(progress): progress
        case let .badgeSparkle(intensity): intensity
        case let .frostedGlass(intensity): intensity
        case let .gradientMesh(_, intensity): intensity
        case let .depthBlur(intensity): intensity
        case let .holographic(intensity): intensity
        case .energyField: 1.0
        case let .caustics(intensity): intensity
        case let .smoke(intensity): intensity
        case .combined: 1.0
        case .none: 0.0
        }
    }

    // MARK: - Effect Color

    /// Returns the primary color for this effect, if applicable
    var effectColor: Color {
        switch self {
        case let .glassBlur(_, tint): tint
        case let .shimmer(_, color): color
        case let .glow(color, _): color
        case let .gradientMesh(tint, _): tint
        default: .white
        }
    }

    // MARK: - Equatable Conformance

    static func == (lhs: MetalEffect, rhs: MetalEffect) -> Bool {
        switch (lhs, rhs) {
        case (.glassBlur(let l1, let l2), .glassBlur(let r1, let r2)):
            l1 == r1 && l2 == r2
        case (.shimmer(let l1, let l2), .shimmer(let r1, let r2)):
            l1 == r1 && l2 == r2
        case (.liquidRipple(let l), .liquidRipple(let r)):
            l == r
        case (.chromaticAberration(let l), .chromaticAberration(let r)):
            l == r
        case (.glow(let lc, let li), .glow(let rc, let ri)):
            lc == rc && li == ri
        case (.morphTransition(let l), .morphTransition(let r)):
            l == r
        case (.touchRipple(let lc, let lp), .touchRipple(let rc, let rp)):
            lc == rc && lp == rp
        case (.skeletonWave(let l), .skeletonWave(let r)):
            l == r
        case (.buttonPress(let lc, let lp), .buttonPress(let rc, let rp)):
            lc == rc && lp == rp
        case (.celebrationConfetti(let l), .celebrationConfetti(let r)):
            l == r
        case (.achievementBurst(let l), .achievementBurst(let r)):
            l == r
        case (.badgeSparkle(let l), .badgeSparkle(let r)):
            l == r
        case (.frostedGlass(let l), .frostedGlass(let r)):
            l == r
        case (.gradientMesh(let lc, let li), .gradientMesh(let rc, let ri)):
            lc == rc && li == ri
        case (.depthBlur(let l), .depthBlur(let r)):
            l == r
        case (.holographic(let l), .holographic(let r)):
            l == r
        case (.energyField(let l), .energyField(let r)):
            l == r
        case (.caustics(let l), .caustics(let r)):
            l == r
        case (.smoke(let l), .smoke(let r)):
            l == r
        case (.combined(let l), .combined(let r)):
            l == r
        case (.none, .none):
            true
        default:
            false
        }
    }
}

// MARK: - MetalEffect Builder

/// Fluent builder for combining multiple Metal effects
struct MetalEffectBuilder {
    private var effects: [MetalEffect] = []

    /// Add a glass blur effect
    func glassBlur(intensity: CGFloat = 1.0, tint: Color = .white) -> MetalEffectBuilder {
        var builder = self
        builder.effects.append(.glassBlur(intensity: intensity, tint: tint))
        return builder
    }

    /// Add a shimmer effect
    func shimmer(intensity: CGFloat = 1.0, color: Color = .white) -> MetalEffectBuilder {
        var builder = self
        builder.effects.append(.shimmer(intensity: intensity, color: color))
        return builder
    }

    /// Add a glow effect
    func glow(color: Color, intensity: CGFloat = 1.0) -> MetalEffectBuilder {
        var builder = self
        builder.effects.append(.glow(color: color, intensity: intensity))
        return builder
    }

    /// Add a chromatic aberration effect
    func chromaticAberration(intensity: CGFloat = 1.0) -> MetalEffectBuilder {
        var builder = self
        builder.effects.append(.chromaticAberration(intensity: intensity))
        return builder
    }

    /// Build the combined effect
    func build() -> MetalEffect {
        if effects.isEmpty {
            return .none
        } else if effects.count == 1 {
            return effects[0]
        } else {
            return .combined(effects)
        }
    }
}

// MARK: - Convenience Extensions

extension MetalEffect {
    /// Create a builder for combining effects
    static func builder() -> MetalEffectBuilder {
        MetalEffectBuilder()
    }

    /// Quick preset for loading states
    static var loadingShimmer: MetalEffect {
        .shimmer(intensity: 0.8, color: .white.opacity(0.3))
    }

    /// Quick preset for success celebrations
    static var successGlow: MetalEffect {
        .glow(color: Color.DesignSystem.brandGreen, intensity: 0.7)
    }

    /// Quick preset for error states
    static var errorGlow: MetalEffect {
        .glow(color: Color.DesignSystem.error, intensity: 0.6)
    }

    /// Quick preset for premium/featured items
    static var premiumShine: MetalEffect {
        .combined([
            .shimmer(intensity: 0.5, color: .yellow.opacity(0.3)),
            .glow(color: .orange, intensity: 0.4)
        ])
    }
}

#endif
