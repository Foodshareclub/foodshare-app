//
//  GlassButton.swift
//  Foodshare
//
//  Liquid Glass Button Component with ProMotion-optimized animations
//  CareEcho-inspired layered glass effects and blue/cyan gradients
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Scale Button Style

/// Subtle scale effect on press for natural tactile feedback
/// Optimized for 120Hz ProMotion displays with interpolating springs
struct ScaleButtonStyle: ButtonStyle {
    let scale: CGFloat
    let haptic: HapticType

    enum HapticType {
        case none
        case light
        case medium
        case heavy
    }

    init(scale: CGFloat = 0.96, haptic: HapticType = .light) {
        self.scale = scale
        self.haptic = haptic
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .brightness(configuration.isPressed ? 0.03 : 0)
            // ProMotion 120Hz optimized: interpolating spring for instant response
            .animation(.interpolatingSpring(stiffness: 400, damping: 30), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    triggerHaptic()
                }
            }
    }

    private func triggerHaptic() {
        switch haptic {
        case .none:
            break
        case .light:
            HapticManager.light()
        case .medium:
            HapticManager.medium()
        case .heavy:
            HapticManager.heavy()
        }
    }
}

// MARK: - Glass Button

struct GlassButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let isLoading: Bool
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    enum ButtonStyle {
        case primary      // Foodshare brand (Pink/Teal gradient)
        case secondary    // Glass background
        case outline      // Clear with border
        case ghost        // Clear, no border
        case destructive  // Red gradient
        case blueCyan     // Blue/Cyan gradient (legacy CareEcho style)
        case pinkTeal     // Full Foodshare brand CTA style
        case green        // Success/Eco green style
        case nature       // Nature theme (Green/Blue gradient)
    }

    init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isLoading = isLoading
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .tint(.white)
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: (style == .pinkTeal || style == .blueCyan || style == .nature) ? 58 : 56)
            .background(layeredBackground)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.96, haptic: .none))
        .disabled(isLoading)
        .opacity(isEnabled && !isLoading ? 1.0 : 0.55)
        .drawingGroup() // GPU rasterization for 120Hz ProMotion
        .accessibilityLabel(isLoading ? "\(title), Loading" : title)
    }

    // MARK: - Layered Background (CareEcho-style)

    @ViewBuilder
    private var layeredBackground: some View {
        switch style {
        case .primary, .pinkTeal:
            // Foodshare brand style - Pink/Teal gradient
            ZStack {
                // Primary gradient fill
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandPink.opacity(0.95),
                                Color.DesignSystem.brandTeal.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // White highlight overlay
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear,
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )

        case .blueCyan:
            // Legacy CareEcho-style layered blue/cyan gradient
            ZStack {
                // Primary gradient fill
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.accentBlue.opacity(0.95),
                                Color.DesignSystem.accentCyan.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // White highlight overlay
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear,
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )

        case .green:
            // Eco-friendly green style
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.95),
                                Color.DesignSystem.brandCyan.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear,
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )

        case .nature:
            // Nature theme - Green/Blue gradient
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.95),
                                Color.DesignSystem.brandBlue.opacity(0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear,
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )

        case .secondary:
            // Glass background
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.08))

                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.05), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )

        case .outline:
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [Color.DesignSystem.accentBlue.opacity(0.6), Color.DesignSystem.accentCyan.opacity(0.4)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )

        case .ghost:
            Color.clear

        case .destructive:
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.error,
                                Color.DesignSystem.error.opacity(0.85)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.1), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .pinkTeal, .blueCyan, .secondary, .destructive, .green, .nature:
            .white
        case .outline:
            Color.DesignSystem.brandPink
        case .ghost:
            Color.DesignSystem.brandPink
        }
    }

    private var shadowColor: Color {
        switch style {
        case .primary, .pinkTeal:
            Color.DesignSystem.brandPink.opacity(0.6)
        case .blueCyan:
            Color.DesignSystem.accentBlue.opacity(0.6)
        case .green:
            Color.DesignSystem.brandGreen.opacity(0.6)
        case .nature:
            Color.DesignSystem.brandGreen.opacity(0.5)
        case .destructive:
            Color.DesignSystem.error.opacity(0.5)
        case .secondary:
            Color.black.opacity(0.3)
        default:
            Color.clear
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .primary, .pinkTeal, .blueCyan, .green, .nature:
            24
        case .secondary, .destructive:
            12
        default:
            0
        }
    }

    private var shadowOffset: CGFloat {
        switch style {
        case .primary, .pinkTeal, .blueCyan, .green, .nature:
            12
        case .secondary, .destructive:
            6
        default:
            0
        }
    }
}

#Preview("All Button Styles") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            Text("Foodshare Brand")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)

            GlassButton("Primary (Pink/Teal)", icon: "plus.circle.fill", style: .primary) {}
            GlassButton("Pink Teal CTA", icon: "heart.fill", style: .pinkTeal) {}

            Text("Alternative Styles")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.sm)

            GlassButton("Blue/Cyan Style", icon: "bolt.fill", style: .blueCyan) {}
            GlassButton("Eco Green", icon: "leaf.fill", style: .green) {}
            GlassButton("Nature Theme", icon: "leaf.circle.fill", style: .nature) {}
            GlassButton("Secondary", style: .secondary) {}

            Text("Minimal Styles")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.sm)

            GlassButton("Outline Button", style: .outline) {}
            GlassButton("Ghost Button", style: .ghost) {}

            Text("Destructive")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Spacing.sm)

            GlassButton("Delete Account", icon: "trash.fill", style: .destructive) {}
        }
        .padding()
    }
    .background(Color.black)
}
