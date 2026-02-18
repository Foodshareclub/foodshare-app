//
//  AuthBackground.swift
//  Foodshare
//
//  Liquid Glass v27 Authentication Background
//  Premium animated MeshGradient with Foodshare brand support
//  Requires iOS 18+ for MeshGradient support
//


#if !SKIP
import SwiftUI

struct AuthBackground: View {
    /// Background style variant
    enum Style {
        case blueCyan // Blue/Cyan gradient (legacy CareEcho)
        case brand // Foodshare brand (Pink/Teal)
        case eco // Green/Cyan eco theme
        case nature // Green/Blue gradient (Show Map button style)
    }

    /// Use MeshGradient animation (recommended) or classic orbs
    var useMeshGradient = true
    /// Color style for the background
    var style: Style = .nature

    var body: some View {
        if useMeshGradient {
            meshGradientBackground
        } else {
            classicOrbBackground
        }
    }

    // MARK: - MeshGradient Background (iOS 18+)

    private var meshGradientBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )

            // Style-specific accent overlay
            accentOverlay

            // Animated MeshGradient layer
            meshGradientLayer
                .opacity(0.6)
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var accentOverlay: some View {
        switch style {
        case .blueCyan:
            LinearGradient(
                colors: [
                    Color.DesignSystem.accentBlue.opacity(0.15),
                    Color.clear,
                    Color.DesignSystem.accentCyan.opacity(0.08)
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
        case .brand:
            LinearGradient(
                colors: [
                    Color.DesignSystem.brandPink.opacity(0.18),
                    Color.clear,
                    Color.DesignSystem.brandTeal.opacity(0.12)
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
        case .eco:
            LinearGradient(
                colors: [
                    Color.DesignSystem.brandGreen.opacity(0.15),
                    Color.clear,
                    Color.DesignSystem.accentCyan.opacity(0.1)
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
        case .nature:
            LinearGradient(
                colors: [
                    Color.DesignSystem.brandGreen.opacity(0.35),
                    Color.clear,
                    Color.DesignSystem.brandBlue.opacity(0.25)
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
        }
    }

    @ViewBuilder
    private var meshGradientLayer: some View {
        if #available(iOS 18.0, *) {
            switch style {
            case .blueCyan:
                AnimatedBlueCyanMeshBackground()
            case .brand:
                AnimatedBrandMeshBackground()
            case .eco:
                AnimatedEcoMeshBackground()
            case .nature:
                AnimatedNatureMeshBackground()
            }
        } else {
            classicOrbBackground
        }
    }

    // MARK: - Classic Orb Background (Fallback)

    @State private var animateOrbs = false

    /// Primary color for orbs based on style
    private var orbPrimaryColor: Color {
        switch style {
        case .blueCyan: Color.DesignSystem.accentBlue
        case .brand: Color.DesignSystem.brandPink
        case .eco: Color.DesignSystem.brandGreen
        case .nature: Color.DesignSystem.brandGreen
        }
    }

    /// Secondary color for orbs based on style
    private var orbSecondaryColor: Color {
        switch style {
        case .blueCyan: Color.DesignSystem.accentCyan
        case .brand: Color.DesignSystem.brandTeal
        case .eco: Color.DesignSystem.accentCyan
        case .nature: Color.DesignSystem.brandBlue
        }
    }

    private var classicOrbBackground: some View {
        ZStack {
            // Base dark gradient
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.05, green: 0.08, blue: 0.12),
                    Color(red: 0.08, green: 0.12, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )

            // Style-specific accent overlay
            accentOverlay

            // Animated orbs
            GeometryReader { geometry in
                // Primary orb (top-left)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbPrimaryColor.opacity(0.25),
                                orbPrimaryColor.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 200,
                        ),
                    )
                    .frame(width: 400.0, height: 400)
                    .blur(radius: 80)
                    .offset(
                        x: animateOrbs ? -50 : -100,
                        y: animateOrbs ? -80 : -120,
                    )

                // Secondary orb (bottom-right)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbSecondaryColor.opacity(0.2),
                                orbSecondaryColor.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 180,
                        ),
                    )
                    .frame(width: 350.0, height: 350)
                    .blur(radius: 70)
                    .offset(
                        x: geometry.size.width - (animateOrbs ? 150 : 100),
                        y: geometry.size.height - (animateOrbs ? 200 : 250),
                    )

                // Accent orb (center) - blend of both colors
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                orbSecondaryColor.opacity(0.12),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 150,
                        ),
                    )
                    .frame(width: 300.0, height: 300)
                    .blur(radius: 60)
                    .offset(
                        x: geometry.size.width * 0.3,
                        y: geometry.size.height * (animateOrbs ? 0.4 : 0.5),
                    )
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 8)
                    .repeatForever(autoreverses: true),
            ) {
                animateOrbs = true
            }
        }
    }
}

#Preview("Mesh - Nature (Green/Blue)") {
    AuthBackground(useMeshGradient: true, style: .nature)
}

#Preview("Mesh - Brand (Pink/Teal)") {
    AuthBackground(useMeshGradient: true, style: .brand)
}

#Preview("Mesh - Eco (Green/Cyan)") {
    AuthBackground(useMeshGradient: true, style: .eco)
}

#Preview("Orbs - Nature (Green/Blue)") {
    AuthBackground(useMeshGradient: false, style: .nature)
}

#Preview("Orbs - Brand (Pink/Teal)") {
    AuthBackground(useMeshGradient: false, style: .brand)
}

#endif
