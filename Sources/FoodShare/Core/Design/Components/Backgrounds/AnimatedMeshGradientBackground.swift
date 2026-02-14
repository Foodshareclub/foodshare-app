//
//  AnimatedMeshGradientBackground.swift
//  Foodshare
//
//  Liquid Glass v26 - Animated MeshGradient Background
//  Creates a lava-lamp style morphing gradient effect
//  Requires iOS 18+ for MeshGradient support
//

import SwiftUI
import FoodShareDesignSystem

/// Animated mesh gradient background with lava-lamp style color morphing
/// Uses TimelineView for frame-perfect animations at 120Hz on ProMotion displays
struct AnimatedMeshGradientBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    // Static 3x3 grid points
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: animatedColors(time: time),
                smoothsColors: true,
                colorSpace: .perceptual,
            )
            .ignoresSafeArea()
            .drawingGroup() // GPU rasterization for 120Hz ProMotion
        }
    }

    /// Generate animated colors based on time
    /// Uses sin/cos waves for smooth color transitions
    private func animatedColors(time: Double) -> [Color] {
        let speed = 0.5 // Adjust for slower/faster morphing
        let t = time * speed

        if colorScheme == .dark {
            return [
                // Top row
                Color.DesignSystem.darkPrimaryColor.opacity(0.6 + sin(t) * 0.2),
                Color.DesignSystem.darkAccentColor.opacity(0.4 + cos(t * 1.3) * 0.2),
                Color.DesignSystem.darkPrimaryColor.opacity(0.5 + sin(t * 1.7) * 0.2),

                // Middle row
                Color.DesignSystem.darkBackgroundColor.opacity(1.0),
                Color.DesignSystem.darkPrimaryColor.opacity(0.3 + sin(t * 0.8) * 0.15),
                Color.DesignSystem.darkAccentColor.opacity(0.3 + cos(t * 1.1) * 0.2),

                // Bottom row
                Color.DesignSystem.darkPrimaryColor.opacity(0.4 + cos(t * 1.5) * 0.2),
                Color.DesignSystem.darkBackgroundColor.opacity(1.0),
                Color.DesignSystem.darkAccentColor.opacity(0.5 + sin(t * 1.2) * 0.2)
            ]
        } else {
            return [
                // Top row - Light mode
                Color.DesignSystem.lightPrimaryColor.opacity(0.3 + sin(t) * 0.15),
                Color.DesignSystem.lightAccentColor.opacity(0.4 + cos(t * 1.3) * 0.15),
                Color.DesignSystem.lightPrimaryColor.opacity(0.2 + sin(t * 1.7) * 0.15),

                // Middle row
                Color.DesignSystem.lightBackgroundColor.opacity(1.0),
                Color.DesignSystem.lightPrimaryColor.opacity(0.2 + sin(t * 0.8) * 0.1),
                Color.DesignSystem.lightAccentColor.opacity(0.3 + cos(t * 1.1) * 0.15),

                // Bottom row
                Color.DesignSystem.lightAccentColor.opacity(0.4 + cos(t * 1.5) * 0.15),
                Color.DesignSystem.lightBackgroundColor.opacity(1.0),
                Color.DesignSystem.lightPrimaryColor.opacity(0.25 + sin(t * 1.2) * 0.15)
            ]
        }
    }
}

// MARK: - Blue/Cyan Variant for Auth Screens

/// Blue/Cyan variant of the animated mesh gradient
/// Optimized for authentication and onboarding screens
struct AnimatedBlueCyanMeshBackground: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: blueCyanColors(time: time),
                smoothsColors: true,
                colorSpace: .perceptual,
            )
            .ignoresSafeArea()
            .drawingGroup() // GPU rasterization for 120Hz ProMotion
        }
    }

    private func blueCyanColors(time: Double) -> [Color] {
        let speed = 0.4
        let t = time * speed

        // Dark navy base with blue/cyan accents
        let base = Color(red: 0.05, green: 0.08, blue: 0.12)

        return [
            // Top row
            Color.DesignSystem.accentBlue.opacity(0.4 + sin(t) * 0.15),
            Color.DesignSystem.accentCyan.opacity(0.3 + cos(t * 1.3) * 0.15),
            Color.DesignSystem.accentBlue.opacity(0.35 + sin(t * 1.7) * 0.15),

            // Middle row
            base,
            Color.DesignSystem.accentBlue.opacity(0.2 + sin(t * 0.8) * 0.1),
            Color.DesignSystem.accentCyan.opacity(0.25 + cos(t * 1.1) * 0.15),

            // Bottom row
            Color.DesignSystem.accentCyan.opacity(0.3 + cos(t * 1.5) * 0.15),
            base,
            Color.DesignSystem.accentBlue.opacity(0.35 + sin(t * 1.2) * 0.15)
        ]
    }
}

// MARK: - Foodshare Brand Variant (Pink/Teal)

/// Foodshare brand colors mesh gradient (Pink/Teal)
/// Premium animated background for main app screens
struct AnimatedBrandMeshBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: brandColors(time: time),
                smoothsColors: true,
                colorSpace: .perceptual,
            )
            .ignoresSafeArea()
            .drawingGroup() // GPU rasterization for 120Hz ProMotion
        }
    }

    private func brandColors(time: Double) -> [Color] {
        let speed = 0.35
        let t = time * speed

        // Dark base for rich contrast
        let base = Color(red: 0.04, green: 0.05, blue: 0.08)

        return [
            // Top row - Pink dominant
            Color.DesignSystem.brandPink.opacity(0.45 + sin(t) * 0.12),
            Color.DesignSystem.brandTeal.opacity(0.28 + cos(t * 1.3) * 0.1),
            Color.DesignSystem.brandPink.opacity(0.35 + sin(t * 1.7) * 0.12),

            // Middle row - Dark base with subtle accents
            base,
            Color.DesignSystem.brandPink.opacity(0.18 + sin(t * 0.8) * 0.08),
            Color.DesignSystem.brandTeal.opacity(0.22 + cos(t * 1.1) * 0.1),

            // Bottom row - Teal dominant
            Color.DesignSystem.brandTeal.opacity(0.32 + cos(t * 1.5) * 0.12),
            base,
            Color.DesignSystem.brandPink.opacity(0.38 + sin(t * 1.2) * 0.1)
        ]
    }
}

// MARK: - Eco Green Variant

/// Green/Cyan eco-friendly mesh gradient
/// For sustainability and eco-themed screens
struct AnimatedEcoMeshBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: ecoColors(time: time),
                smoothsColors: true,
                colorSpace: .perceptual,
            )
            .ignoresSafeArea()
            .drawingGroup() // GPU rasterization for 120Hz ProMotion
        }
    }

    private func ecoColors(time: Double) -> [Color] {
        let speed = 0.4
        let t = time * speed

        let base = Color(red: 0.03, green: 0.06, blue: 0.05)

        return [
            // Top row - Green dominant
            Color.DesignSystem.brandGreen.opacity(0.42 + sin(t) * 0.12),
            Color.DesignSystem.accentCyan.opacity(0.28 + cos(t * 1.3) * 0.1),
            Color.DesignSystem.brandTeal.opacity(0.35 + sin(t * 1.7) * 0.12),

            // Middle row
            base,
            Color.DesignSystem.brandGreen.opacity(0.18 + sin(t * 0.8) * 0.08),
            Color.DesignSystem.accentCyan.opacity(0.2 + cos(t * 1.1) * 0.1),

            // Bottom row - Cyan accent
            Color.DesignSystem.accentCyan.opacity(0.3 + cos(t * 1.5) * 0.12),
            base,
            Color.DesignSystem.brandGreen.opacity(0.38 + sin(t * 1.2) * 0.12)
        ]
    }
}

#Preview("Animated Mesh Gradient") {
    AnimatedMeshGradientBackground()
}

#Preview("Blue/Cyan Mesh Gradient") {
    AnimatedBlueCyanMeshBackground()
}

#Preview("Brand Mesh Gradient") {
    AnimatedBrandMeshBackground()
}

// MARK: - Nature Green/Blue Variant

/// Green/Blue nature mesh gradient (matches Show Map button)
/// For auth and primary action screens
struct AnimatedNatureMeshBackground: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0.0, 0.0], [0.5, 0.0], [1.0, 0.0],
                    [0.0, 0.5], [0.5, 0.5], [1.0, 0.5],
                    [0.0, 1.0], [0.5, 1.0], [1.0, 1.0]
                ],
                colors: natureColors(time: time),
                smoothsColors: true,
                colorSpace: .perceptual,
            )
            .ignoresSafeArea()
            .drawingGroup() // GPU rasterization for 120Hz ProMotion
        }
    }

    private func natureColors(time: Double) -> [Color] {
        let speed = 0.35
        let t = time * speed

        let base = Color(red: 0.05, green: 0.08, blue: 0.12)

        return [
            // Top row - Vibrant green (matching Show Map button)
            Color.DesignSystem.brandGreen.opacity(0.75 + sin(t) * 0.15),
            Color.DesignSystem.brandBlue.opacity(0.55 + cos(t * 1.3) * 0.12),
            Color.DesignSystem.brandGreen.opacity(0.65 + sin(t * 1.7) * 0.15),

            // Middle row - Brighter transition
            Color.DesignSystem.brandGreen.opacity(0.35 + sin(t * 0.9) * 0.1),
            Color.DesignSystem.brandBlue.opacity(0.40 + sin(t * 0.8) * 0.1),
            Color.DesignSystem.brandBlue.opacity(0.50 + cos(t * 1.1) * 0.12),

            // Bottom row - Blue dominant
            Color.DesignSystem.brandBlue.opacity(0.60 + cos(t * 1.5) * 0.15),
            base,
            Color.DesignSystem.brandGreen.opacity(0.55 + sin(t * 1.2) * 0.12)
        ]
    }
}

#Preview("Eco Mesh Gradient") {
    AnimatedEcoMeshBackground()
}

#Preview("Nature Mesh Gradient") {
    AnimatedNatureMeshBackground()
}
