//
//  MetalCardEffects.swift
//  FoodShare
//
//  Pre-configured Metal effect cards for common use cases.
//  Combines Metal shader effects with glass card styling.
//


#if !SKIP
#if !SKIP
import SwiftUI

// MARK: - Metal Glass Card

/// A card with pre-configured Metal effects and glass styling
struct MetalGlassCard<Content: View>: View {
    let preset: Preset
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    enum Preset {
        case feed
        case profile
        case premium
        case celebration
        case forum
        case message
        case achievement

        /// The Metal effect for this preset
        var effect: MetalEffect {
            switch self {
            case .feed:
                return .combined([
                    .glassBlur(intensity: 0.6),
                    .shimmer(intensity: 0.2, color: .white)
                ])
            case .profile:
                return .combined([
                    .frostedGlass(intensity: 0.7),
                    .glow(color: .DesignSystem.brandGreen, intensity: 0.3)
                ])
            case .premium:
                return .premiumShine
            case .celebration:
                return .celebrationConfetti(intensity: 0.8)
            case .forum:
                return .combined([
                    .glassBlur(intensity: 0.5),
                    .shimmer(intensity: 0.15, color: .DesignSystem.brandBlue)
                ])
            case .message:
                return .combined([
                    .frostedGlass(intensity: 0.6),
                    .shimmer(intensity: 0.1, color: .white)
                ])
            case .achievement:
                return .combined([
                    .holographic(intensity: 0.5),
                    .badgeSparkle(intensity: 0.6)
                ])
            }
        }

        /// Glass style for this preset
        var glassStyle: GlassCardStyle {
            switch self {
            case .feed:
                return .standard
            case .profile:
                return .elevated
            case .premium:
                return .premium
            case .celebration:
                return .celebration
            case .forum:
                return .standard
            case .message:
                return .subtle
            case .achievement:
                return .premium
            }
        }
    }

    init(preset: Preset, @ViewBuilder content: () -> Content) {
        self.preset = preset
        self.content = content()
    }

    var body: some View {
        content
            .modifier(GlassCardModifier(style: preset.glassStyle))
            .metalEffect(reduceMotion ? .none : preset.effect)
            .drawingGroup() // GPU rasterization for 120Hz
    }
}

// MARK: - Glass Card Style

enum GlassCardStyle {
    case subtle
    case standard
    case elevated
    case premium
    case celebration

    var cornerRadius: CGFloat {
        switch self {
        case .subtle: return CornerRadius.medium
        case .standard: return CornerRadius.large
        case .elevated: return CornerRadius.large
        case .premium: return CornerRadius.xl
        case .celebration: return CornerRadius.xl
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .subtle: return 4
        case .standard: return 8
        case .elevated: return 12
        case .premium: return 16
        case .celebration: return 20
        }
    }

    var shadowOpacity: Double {
        switch self {
        case .subtle: return 0.05
        case .standard: return 0.08
        case .elevated: return 0.12
        case .premium: return 0.15
        case .celebration: return 0.2
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .subtle: return 0.5
        case .standard: return 1
        case .elevated: return 1
        case .premium: return 1.5
        case .celebration: return 2
        }
    }

    var borderColors: [Color] {
        switch self {
        case .subtle:
            return [Color.white.opacity(0.1)]
        case .standard:
            return [Color.DesignSystem.glassBorder]
        case .elevated:
            return [Color.white.opacity(0.2), Color.white.opacity(0.1)]
        case .premium:
            return [Color.DesignSystem.brandGreen, Color.DesignSystem.brandTeal]
        case .celebration:
            return [Color.DesignSystem.brandGreen, Color.DesignSystem.brandTeal, Color.DesignSystem.brandBlue]
        }
    }
}

// MARK: - Glass Card Modifier

struct GlassCardModifier: ViewModifier {
    let style: GlassCardStyle

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: style.cornerRadius))
            .overlay(borderOverlay)
            .shadow(
                color: .black.opacity(style.shadowOpacity),
                radius: style.shadowRadius,
                y: style.shadowRadius / 2
            )
    }

    @ViewBuilder
    private var cardBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: style.cornerRadius)
                .fill(Color(uiColor: .systemBackground).opacity(0.95))
        } else {
            RoundedRectangle(cornerRadius: style.cornerRadius)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
        }
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius)
            .stroke(
                LinearGradient(
                    colors: style.borderColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: style.borderWidth
            )
    }
}

// MARK: - Effect Card Presets

extension View {
    /// Applies feed item card styling with Metal effects
    func feedCardEffect() -> some View {
        self.modifier(GlassCardModifier(style: .standard))
            .metalEffect(.combined([
                .glassBlur(intensity: 0.6),
                .shimmer(intensity: 0.2, color: .white)
            ]))
    }

    /// Applies profile card styling with Metal effects
    func profileCardEffect() -> some View {
        self.modifier(GlassCardModifier(style: .elevated))
            .metalEffect(.combined([
                .frostedGlass(intensity: 0.7),
                .glow(color: .DesignSystem.brandGreen, intensity: 0.3)
            ]))
    }

    /// Applies premium card styling with Metal effects
    func premiumCardEffect() -> some View {
        self.modifier(GlassCardModifier(style: .premium))
            .metalEffect(.premiumShine)
    }

    /// Applies celebration card styling with Metal effects
    func celebrationCardEffect() -> some View {
        self.modifier(GlassCardModifier(style: .celebration))
            .metalEffect(.celebrationConfetti(intensity: 0.8))
    }

    /// Applies forum post card styling with Metal effects
    func forumCardEffect() -> some View {
        self.modifier(GlassCardModifier(style: .standard))
            .metalEffect(.combined([
                .glassBlur(intensity: 0.5),
                .shimmer(intensity: 0.15, color: .DesignSystem.brandBlue)
            ]))
    }

    /// Applies message card styling with Metal effects
    func messageCardEffect() -> some View {
        self.modifier(GlassCardModifier(style: .subtle))
            .metalEffect(.combined([
                .frostedGlass(intensity: 0.6),
                .shimmer(intensity: 0.1, color: .white)
            ]))
    }

    /// Applies achievement card styling with Metal effects
    func achievementCardEffect() -> some View {
        self.modifier(GlassCardModifier(style: .premium))
            .metalEffect(.combined([
                .holographic(intensity: 0.5),
                .badgeSparkle(intensity: 0.6)
            ]))
    }
}

// MARK: - Interactive Card Effects

/// Card that responds to touch with Metal ripple effects
struct InteractiveMetalCard<Content: View>: View {
    let content: Content
    let style: GlassCardStyle
    let onTap: () -> Void

    @State private var touchPoint: CGPoint = .zero
    @State private var isPressed = false
    @State private var rippleProgress: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    init(
        style: GlassCardStyle = .standard,
        onTap: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.onTap = onTap
        self.content = content()
    }

    var body: some View {
        GeometryReader { _ in
            content
                .modifier(GlassCardModifier(style: style))
                .metalEffect(
                    reduceMotion ? .none : .touchRipple(
                        center: touchPoint,
                        progress: rippleProgress
                    )
                )
                .scaleEffect(isPressed ? 0.98 : 1.0)
                .animation(.interpolatingSpring(stiffness: 400, damping: 30), value: isPressed)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            touchPoint = value.location
                            if !isPressed {
                                isPressed = true
                                startRipple()
                            }
                        }
                        .onEnded { _ in
                            isPressed = false
                            onTap()
                            HapticManager.light()
                        }
                )
        }
    }

    private func startRipple() {
        guard !reduceMotion else { return }

        rippleProgress = 0
        withAnimation(.easeOut(duration: 0.5)) {
            rippleProgress = 1.0
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("MetalGlassCard Presets") {
    ScrollView {
        VStack(spacing: Spacing.lg) {
            Text("Feed Preset")
                .font(.DesignSystem.headlineMedium)
            MetalGlassCard(preset: .feed) {
                VStack {
                    Text("Feed Card Content")
                        .font(.DesignSystem.bodyLarge)
                    Text("With shimmer effect")
                        .font(.DesignSystem.caption)
                }
                .padding()
            }

            Text("Profile Preset")
                .font(.DesignSystem.headlineMedium)
            MetalGlassCard(preset: .profile) {
                VStack {
                    Text("Profile Card Content")
                        .font(.DesignSystem.bodyLarge)
                    Text("With glow effect")
                        .font(.DesignSystem.caption)
                }
                .padding()
            }

            Text("Premium Preset")
                .font(.DesignSystem.headlineMedium)
            MetalGlassCard(preset: .premium) {
                VStack {
                    Text("Premium Card Content")
                        .font(.DesignSystem.bodyLarge)
                    Text("With premium shine")
                        .font(.DesignSystem.caption)
                }
                .padding()
            }

            Text("Achievement Preset")
                .font(.DesignSystem.headlineMedium)
            MetalGlassCard(preset: .achievement) {
                VStack {
                    Text("Achievement Unlocked!")
                        .font(.DesignSystem.bodyLarge)
                    Text("With holographic effect")
                        .font(.DesignSystem.caption)
                }
                .padding()
            }
        }
        .padding()
    }
    .background(Color.backgroundGradient)
}
#endif
#endif // !SKIP

#endif
