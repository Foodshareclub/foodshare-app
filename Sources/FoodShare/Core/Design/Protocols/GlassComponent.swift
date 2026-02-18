//
//  GlassComponent.swift
//  Foodshare
//
//  Swift 6.3 Protocol hierarchy for Liquid Glass components
//  Provides composable, type-safe foundation for glass UI elements
//


#if !SKIP
import SwiftUI

// MARK: - GlassComponent Protocol

/// Base protocol for all Liquid Glass design system components
/// Provides consistent styling, GPU rasterization options, and accessibility support
@MainActor
protocol GlassComponent: View {
    associatedtype Content: View

    /// Corner radius for the glass container
    var cornerRadius: CGFloat { get }

    /// Whether to use GPU rasterization via drawingGroup() for complex effects
    var useGPURasterization: Bool { get }

    /// The content to display inside the glass container
    @ViewBuilder var content: Content { get }
}

extension GlassComponent {
    var cornerRadius: CGFloat { CornerRadius.large }
    var useGPURasterization: Bool { false }
}

// MARK: - GlassContainerComponent Protocol

/// Protocol for glass containers that wrap other content
@MainActor
protocol GlassContainerComponent: GlassComponent {
    associatedtype Header: View

    /// Optional header view for the container
    @ViewBuilder var header: Header { get }

    /// Padding inside the glass container
    var contentPadding: EdgeInsets { get }
}

extension GlassContainerComponent {
    var contentPadding: EdgeInsets {
        EdgeInsets(top: Spacing.md, leading: Spacing.md, bottom: Spacing.md, trailing: Spacing.md)
    }
}

// MARK: - GlassInteractiveComponent Protocol

/// Protocol for interactive glass components (buttons, toggles, etc.)
@MainActor
protocol GlassInteractiveComponent: GlassComponent {
    /// Whether the component is currently disabled
    var isDisabled: Bool { get }

    /// Haptic feedback intensity (none, light, medium, heavy)
    var hapticStyle: HapticStyle { get }
}

enum HapticStyle: Sendable {
    case none
    case light
    case medium
    case heavy

    @MainActor
    func trigger() {
        switch self {
        case .none: break
        case .light: HapticManager.light()
        case .medium: HapticManager.medium()
        case .heavy: HapticManager.heavy()
        }
    }
}

extension GlassInteractiveComponent {
    var isDisabled: Bool { false }
    var hapticStyle: HapticStyle { .light }
}

// MARK: - GlassAnimatableComponent Protocol

/// Protocol for glass components with built-in animations
@MainActor
protocol GlassAnimatableComponent: GlassComponent {
    /// Whether animations should be enabled (respects reduceMotion)
    var animationsEnabled: Bool { get }

    /// Animation delay for staggered appearances
    var appearanceDelay: Double { get }
}

extension GlassAnimatableComponent {
    var animationsEnabled: Bool {
        !UIAccessibility.isReduceMotionEnabled
    }

    var appearanceDelay: Double { 0 }
}

// MARK: - GlassLoadableComponent Protocol

/// Protocol for glass components that can display loading states
@MainActor
protocol GlassLoadableComponent: GlassComponent {
    /// Whether the component is currently loading
    var isLoading: Bool { get }

    /// Loading indicator style
    var loadingStyle: GlassLoadingStyle { get }
}

enum GlassLoadingStyle: Sendable {
    case spinner
    case shimmer
    case skeleton
    case glassPulse
}

extension GlassLoadableComponent {
    var loadingStyle: GlassLoadingStyle { .shimmer }
}

// MARK: - Glass Component Effect View Modifier

/// Applies standard glass morphism effect to any view (component variant)
struct GlassComponentEffectModifier: ViewModifier {
    let cornerRadius: CGFloat
    let useGPURasterization: Bool
    let borderOpacity: Double
    let fillOpacity: Double

    init(
        cornerRadius: CGFloat = CornerRadius.large,
        useGPURasterization: Bool = false,
        borderOpacity: Double = 0.12,
        fillOpacity: Double = 0.05
    ) {
        self.cornerRadius = cornerRadius
        self.useGPURasterization = useGPURasterization
        self.borderOpacity = borderOpacity
        self.fillOpacity = fillOpacity
    }

    func body(content: Content) -> some View {
        let glassContent = content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(fillOpacity))
                    #if !SKIP
                    .background(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .background(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(borderOpacity),
                                Color.white.opacity(borderOpacity * 0.5)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )

        if useGPURasterization {
            glassContent.drawingGroup()
        } else {
            glassContent
        }
    }
}

extension View {
    /// Applies glass morphism effect with standard styling
    func glassEffect(
        cornerRadius: CGFloat = CornerRadius.large,
        useGPURasterization: Bool = false,
        borderOpacity: Double = 0.12,
        fillOpacity: Double = 0.05
    ) -> some View {
        modifier(GlassComponentEffectModifier(
            cornerRadius: cornerRadius,
            useGPURasterization: useGPURasterization,
            borderOpacity: borderOpacity,
            fillOpacity: fillOpacity
        ))
    }
}

// MARK: - Preview

#Preview("Glass Effect Modifier") {
    VStack(spacing: Spacing.md) {
        Text("Standard Glass Effect")
            .font(.DesignSystem.headlineMedium)
            .foregroundColor(.DesignSystem.text)
            .padding(Spacing.lg)
            .glassEffect()

        Text("GPU Rasterized")
            .font(.DesignSystem.headlineMedium)
            .foregroundColor(.DesignSystem.text)
            .padding(Spacing.lg)
            .glassEffect(useGPURasterization: true)

        Text("Custom Corner Radius")
            .font(.DesignSystem.headlineMedium)
            .foregroundColor(.DesignSystem.text)
            .padding(Spacing.lg)
            .glassEffect(cornerRadius: CornerRadius.xl)
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#endif
