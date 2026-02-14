//
//  AccessibilityModifiers.swift
//  Foodshare
//
//  Enterprise-grade accessibility modifiers for the Liquid Glass design system
//  Ensures WCAG 2.1 AA compliance across all glass components
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Accessible Glass Modifier

/// Modifier that adds proper accessibility support to glass components
public struct AccessibleGlassModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let isInteractive: Bool

    @Environment(\.accessibilityManager) private var accessibilityManager

    public func body(content: Content) -> some View {
        Group {
            if accessibilityManager.shouldSimplifyGlassEffects {
                // Simplified version for reduced transparency
                content
                    .background(Color.DesignSystem.background.opacity(0.95))
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(traits)
        .if(isInteractive) { view in
            view.accessibilityAddTraits(.isButton)
        }
    }
}

// MARK: - Dynamic Type Safe Modifier

/// Modifier that ensures text scales properly with Dynamic Type
/// while preventing layout issues at accessibility sizes
public struct DynamicTypeSafeModifier: ViewModifier {
    let maxScale: CGFloat
    let lineLimit: Int?

    @Environment(\.accessibilityManager) private var accessibilityManager
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public func body(content: Content) -> some View {
        content
            .lineLimit(effectiveLineLimit)
            .minimumScaleFactor(minimumScaleFactor)
            .dynamicTypeSize(...effectiveMaxSize)
    }

    private var effectiveLineLimit: Int? {
        if accessibilityManager.isAccessibilityTextSize {
            // Allow more lines at accessibility sizes
            if let limit = lineLimit {
                return limit * 2
            }
        }
        return lineLimit
    }

    private var minimumScaleFactor: CGFloat {
        // Allow more shrinking at accessibility sizes to prevent clipping
        accessibilityManager.isAccessibilityTextSize ? 0.7 : 0.85
    }

    private var effectiveMaxSize: DynamicTypeSize {
        switch maxScale {
        case ...1.0: .large
        case ...1.2: .xLarge
        case ...1.4: .xxLarge
        case ...1.6: .xxxLarge
        default: .accessibility3
        }
    }
}

// MARK: - Reduce Motion Safe Modifier

/// Modifier that provides animation fallbacks for Reduce Motion users
public struct ReduceMotionSafeModifier<FallbackContent: View>: ViewModifier {
    let animation: Animation?
    let fallbackContent: () -> FallbackContent?

    @Environment(\.accessibilityManager) private var accessibilityManager

    init(
        animation: Animation?,
        @ViewBuilder fallback: @escaping () -> FallbackContent?,
    ) {
        self.animation = animation
        self.fallbackContent = fallback
    }

    public func body(content: Content) -> some View {
        if accessibilityManager.shouldReduceAnimations {
            if let fallback = fallbackContent() {
                fallback
            } else {
                content
            }
        } else {
            content
                .animation(animation, value: UUID())
        }
    }
}

// MARK: - High Contrast Border Modifier

/// Modifier that adds visible borders when Increase Contrast is enabled
public struct HighContrastBorderModifier<S: Shape>: ViewModifier {
    let shape: S
    let normalWidth: CGFloat
    let highContrastWidth: CGFloat

    @Environment(\.accessibilityManager) private var accessibilityManager
    @Environment(\.colorScheme) private var colorScheme

    public init(
        shape: S,
        normalWidth: CGFloat,
        highContrastWidth: CGFloat,
    ) {
        self.shape = shape
        self.normalWidth = normalWidth
        self.highContrastWidth = highContrastWidth
    }

    public func body(content: Content) -> some View {
        content
            .overlay {
                if shouldShowBorder {
                    shape
                        .stroke(borderColor, lineWidth: borderWidth)
                }
            }
    }

    private var shouldShowBorder: Bool {
        accessibilityManager.isIncreaseContrastEnabled ||
            accessibilityManager.isDifferentiateWithoutColorEnabled
    }

    private var borderWidth: CGFloat {
        shouldShowBorder ? highContrastWidth : normalWidth
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.5)
            : Color.black.opacity(0.3)
    }
}

// MARK: - Large Touch Target Modifier

/// Modifier that ensures touch targets meet accessibility guidelines
public struct LargeTouchTargetModifier: ViewModifier {
    let minSize: CGFloat

    @Environment(\.accessibilityManager) private var accessibilityManager

    public func body(content: Content) -> some View {
        content
            .frame(minWidth: effectiveMinSize, minHeight: effectiveMinSize)
            .contentShape(Rectangle())
    }

    private var effectiveMinSize: CGFloat {
        max(minSize, accessibilityManager.featureFlags.minimumTouchTargetSize)
    }
}

// MARK: - Accessibility Focus Modifier

/// Modifier that manages accessibility focus state
public struct AccessibilityFocusModifier: ViewModifier {
    @Binding var isFocused: Bool
    let identifier: String

    @AccessibilityFocusState private var focusState: String?

    public func body(content: Content) -> some View {
        content
            .accessibilityFocused($focusState, equals: identifier)
            .onChange(of: isFocused) { _, newValue in
                if newValue {
                    focusState = identifier
                }
            }
            .onChange(of: focusState) { _, newValue in
                isFocused = (newValue == identifier)
            }
    }
}

// MARK: - Color Blind Safe Modifier

/// Modifier that adds non-color indicators for Differentiate Without Color
public struct ColorBlindSafeModifier: ViewModifier {
    let state: SemanticState
    let showIcon: Bool

    @Environment(\.accessibilityManager) private var accessibilityManager
    @Environment(\.translationService) private var t

    public enum SemanticState {
        case success
        case warning
        case error
        case info
        case neutral

        var icon: String {
            switch self {
            case .success: "checkmark.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.circle.fill"
            case .info: "info.circle.fill"
            case .neutral: "circle.fill"
            }
        }

        var label: String {
            switch self {
            case .success: "Success"
            case .warning: "Warning"
            case .error: "Error"
            case .info: "Information"
            case .neutral: ""
            }
        }

        /// Returns the localized label for this state
        @MainActor
        func localizedLabel(using t: EnhancedTranslationService) -> String {
            switch self {
            case .success: t.t("accessibility.state.success")
            case .warning: t.t("accessibility.state.warning")
            case .error: t.t("accessibility.state.error")
            case .info: t.t("accessibility.state.info")
            case .neutral: ""
            }
        }
    }

    public func body(content: Content) -> some View {
        HStack(spacing: Spacing.xs) {
            if showIcon, accessibilityManager.isDifferentiateWithoutColorEnabled {
                Image(systemName: state.icon)
                    .accessibilityHidden(true)
            }
            content
        }
        .accessibilityLabel(state.localizedLabel(using: t).isEmpty ? "" : "\(state.localizedLabel(using: t)): ")
    }
}

// MARK: - Accessibility Header Modifier

/// Modifier that marks a view as a heading for VoiceOver navigation
public struct AccessibilityHeaderModifier: ViewModifier {
    let level: HeadingLevel

    public enum HeadingLevel {
        case h1, h2, h3, h4, h5, h6

        var trait: AccessibilityTraits {
            .isHeader
        }

        var accessibilityHeadingLevel: AccessibilityHeadingLevel {
            switch self {
            case .h1: .h1
            case .h2: .h2
            case .h3: .h3
            case .h4: .h4
            case .h5: .h5
            case .h6: .h6
            }
        }
    }

    public func body(content: Content) -> some View {
        content
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(level.accessibilityHeadingLevel)
    }
}

// MARK: - Shimmer Accessibility Modifier

/// Modifier that provides accessibility announcements for loading states
public struct ShimmerAccessibilityModifier: ViewModifier {
    let isLoading: Bool
    let loadingMessage: String
    let loadedMessage: String

    @State private var hasAnnouncedLoading = false

    public func body(content: Content) -> some View {
        content
            .accessibilityLabel(isLoading ? loadingMessage : loadedMessage)
            .accessibilityValue(isLoading ? "Loading" : "Loaded")
            .onChange(of: isLoading) { _, newValue in
                if newValue, !hasAnnouncedLoading {
                    AccessibilityAnnouncementQueue.shared.announceLoading(loadingMessage)
                    hasAnnouncedLoading = true
                } else if !newValue, hasAnnouncedLoading {
                    AccessibilityAnnouncementQueue.shared.announceLoaded(loadedMessage)
                    hasAnnouncedLoading = false
                }
            }
    }
}

/// Localized modifier that provides accessibility announcements for loading states
public struct LocalizedShimmerAccessibilityModifier: ViewModifier {
    let isLoading: Bool
    let loadingMessage: String
    let loadedMessage: String
    let translationService: EnhancedTranslationService

    @State private var hasAnnouncedLoading = false

    public func body(content: Content) -> some View {
        content
            .accessibilityLabel(isLoading ? loadingMessage : loadedMessage)
            .accessibilityValue(isLoading ? translationService.t("accessibility.loading") : translationService.t("accessibility.loaded"))
            .onChange(of: isLoading) { _, newValue in
                if newValue, !hasAnnouncedLoading {
                    AccessibilityAnnouncementQueue.shared.announceLoading(loadingMessage, using: translationService)
                    hasAnnouncedLoading = true
                } else if !newValue, hasAnnouncedLoading {
                    AccessibilityAnnouncementQueue.shared.announceLoaded(loadedMessage, using: translationService)
                    hasAnnouncedLoading = false
                }
            }
    }
}

// MARK: - View Extensions

extension View {

    /// Adds comprehensive accessibility support to glass components
    public func accessibleGlass(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        isInteractive: Bool = false,
    ) -> some View {
        modifier(AccessibleGlassModifier(
            label: label,
            hint: hint,
            traits: traits,
            isInteractive: isInteractive,
        ))
    }

    /// Ensures text scales safely with Dynamic Type
    public func dynamicTypeSafe(
        maxScale: CGFloat = 1.6,
        lineLimit: Int? = nil,
    ) -> some View {
        modifier(DynamicTypeSafeModifier(
            maxScale: maxScale,
            lineLimit: lineLimit,
        ))
    }

    /// Provides animation fallbacks for Reduce Motion
    public func reduceMotionSafe(
        animation: Animation?,
        @ViewBuilder fallback: @escaping () -> some View,
    ) -> some View {
        modifier(ReduceMotionSafeModifier(
            animation: animation,
            fallback: fallback,
        ))
    }

    /// Provides animation fallbacks for Reduce Motion (no custom fallback)
    public func reduceMotionSafe(animation: Animation?) -> some View {
        modifier(ReduceMotionSafeModifier(
            animation: animation,
            fallback: { EmptyView() as EmptyView? },
        ))
    }

    /// Adds high contrast borders when needed
    public func highContrastBorder(
        _ shape: some Shape,
        normalWidth: CGFloat = 0,
        highContrastWidth: CGFloat = 2,
    ) -> some View {
        modifier(HighContrastBorderModifier(
            shape: shape,
            normalWidth: normalWidth,
            highContrastWidth: highContrastWidth,
        ))
    }

    /// Ensures minimum touch target size
    public func largeTouchTarget(minSize: CGFloat = 44) -> some View {
        modifier(LargeTouchTargetModifier(minSize: minSize))
    }

    /// Adds color-blind safe indicators
    public func colorBlindSafe(
        state: ColorBlindSafeModifier.SemanticState,
        showIcon: Bool = true,
    ) -> some View {
        modifier(ColorBlindSafeModifier(state: state, showIcon: showIcon))
    }

    /// Marks view as a heading for VoiceOver
    public func accessibilityHeading(_ level: AccessibilityHeaderModifier.HeadingLevel) -> some View {
        modifier(AccessibilityHeaderModifier(level: level))
    }

    /// Adds accessibility support for shimmer/loading states
    public func accessibilityShimmer(
        isLoading: Bool,
        loadingMessage: String = "Content loading",
        loadedMessage: String = "Content loaded",
    ) -> some View {
        modifier(ShimmerAccessibilityModifier(
            isLoading: isLoading,
            loadingMessage: loadingMessage,
            loadedMessage: loadedMessage,
        ))
    }

    /// Adds localized accessibility support for shimmer/loading states
    public func accessibilityShimmer(
        isLoading: Bool,
        loadingMessage: String,
        loadedMessage: String,
        using t: EnhancedTranslationService
    ) -> some View {
        modifier(LocalizedShimmerAccessibilityModifier(
            isLoading: isLoading,
            loadingMessage: loadingMessage,
            loadedMessage: loadedMessage,
            translationService: t
        ))
    }

    /// Manages accessibility focus
    public func accessibilityFocused(
        _ isFocused: Binding<Bool>,
        identifier: String,
    ) -> some View {
        modifier(AccessibilityFocusModifier(
            isFocused: isFocused,
            identifier: identifier,
        ))
    }

    /// Conditionally applies a modifier
    @ViewBuilder
    func `if`(
        _ condition: Bool,
        transform: (Self) -> some View,
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Glass Component Accessibility Presets

/// Pre-built accessibility configurations for common glass components
public enum GlassAccessibilityPreset {

    /// Accessibility configuration for GlassButton
    public static func button(
        label: String,
        hint: String? = nil,
    ) -> some ViewModifier {
        AccessibleGlassModifier(
            label: label,
            hint: hint,
            traits: .isButton,
            isInteractive: true,
        )
    }

    /// Accessibility configuration for GlassCard
    public static func card(
        label: String,
        hint: String = "Double tap to open",
    ) -> some ViewModifier {
        AccessibleGlassModifier(
            label: label,
            hint: hint,
            traits: [],
            isInteractive: true,
        )
    }

    /// Localized accessibility configuration for GlassCard
    @MainActor
    public static func card(
        label: String,
        using t: EnhancedTranslationService
    ) -> some ViewModifier {
        AccessibleGlassModifier(
            label: label,
            hint: t.t("accessibility.action.open"),
            traits: [],
            isInteractive: true,
        )
    }

    /// Accessibility configuration for GlassTextField
    public static func textField(
        label: String,
        hint: String? = nil,
    ) -> some ViewModifier {
        AccessibleGlassModifier(
            label: label,
            hint: hint,
            traits: [],
            isInteractive: true,
        )
    }

    /// Accessibility configuration for GlassNavigationBar
    public static func navigationBar(title: String) -> some ViewModifier {
        AccessibleGlassModifier(
            label: title,
            hint: nil,
            traits: .isHeader,
            isInteractive: false,
        )
    }
}

// MARK: - Preview

#Preview("Accessibility Modifiers") {
    struct AccessibilityDemo: View {
        @State private var isFocused = false

        var body: some View {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Accessible Glass
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(height: 100)
                        .overlay(Text("Glass Card"))
                        .accessibleGlass(
                            label: "Sample glass card",
                            hint: "Double tap for details",
                            isInteractive: true,
                        )

                    // Dynamic Type Safe
                    Text("This text scales safely with Dynamic Type")
                        .dynamicTypeSafe(maxScale: 1.4, lineLimit: 2)

                    // High Contrast Border
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.DesignSystem.primary)
                        .frame(height: 50)
                        .highContrastBorder(RoundedRectangle(cornerRadius: 12))
                        .overlay(Text("High Contrast").foregroundStyle(.white))

                    // Large Touch Target
                    Button("Touch Target") {}
                        .largeTouchTarget(minSize: 44)

                    // Color Blind Safe
                    Text("Success message")
                        .colorBlindSafe(state: .success)

                    Text("Warning message")
                        .colorBlindSafe(state: .warning)

                    Text("Error message")
                        .colorBlindSafe(state: .error)

                    // Heading Levels
                    Text("Section Header")
                        .font(.DesignSystem.headlineLarge)
                        .accessibilityHeading(.h2)
                }
                .padding()
            }
            .background(Color.DesignSystem.background)
        }
    }

    return AccessibilityDemo()
}
