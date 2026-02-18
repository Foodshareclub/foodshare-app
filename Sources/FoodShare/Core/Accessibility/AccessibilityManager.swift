//
//  AccessibilityManager.swift
//  Foodshare
//
//  Centralized accessibility state management for enterprise-grade inclusivity
//  Tracks Dynamic Type, Reduce Motion, VoiceOver, and High Contrast preferences
//


#if !SKIP
#if !SKIP
import Combine
#endif
import SwiftUI
#if !SKIP
import UIKit
#endif

// MARK: - UIContentSizeCategory Extension

extension UIContentSizeCategory {
    /// Human-readable name for the content size category
    public var displayName: String {
        switch self {
        case .extraSmall: "Extra Small"
        case .small: "Small"
        case .medium: "Medium"
        case .large: "Large (Default)"
        case .extraLarge: "Extra Large"
        case .extraExtraLarge: "XXL"
        case .extraExtraExtraLarge: "XXXL"
        case .accessibilityMedium: "Accessibility Medium"
        case .accessibilityLarge: "Accessibility Large"
        case .accessibilityExtraLarge: "Accessibility XL"
        case .accessibilityExtraExtraLarge: "Accessibility XXL"
        case .accessibilityExtraExtraExtraLarge: "Accessibility XXXL"
        default: "Unknown"
        }
    }

    /// Localized display name using translation service
    @MainActor
    public func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .extraSmall: t.t("accessibility.text_size.extra_small")
        case .small: t.t("accessibility.text_size.small")
        case .medium: t.t("accessibility.text_size.medium")
        case .large: t.t("accessibility.text_size.large")
        case .extraLarge: t.t("accessibility.text_size.extra_large")
        case .extraExtraLarge: t.t("accessibility.text_size.xxl")
        case .extraExtraExtraLarge: t.t("accessibility.text_size.xxxl")
        case .accessibilityMedium: t.t("accessibility.text_size.accessibility_medium")
        case .accessibilityLarge: t.t("accessibility.text_size.accessibility_large")
        case .accessibilityExtraLarge: t.t("accessibility.text_size.accessibility_xl")
        case .accessibilityExtraExtraLarge: t.t("accessibility.text_size.accessibility_xxl")
        case .accessibilityExtraExtraExtraLarge: t.t("accessibility.text_size.accessibility_xxxl")
        default: t.t("accessibility.text_size.unknown")
        }
    }
}

// MARK: - Accessibility Manager

/// Centralized manager for accessibility preferences and state
/// Uses @Observable for modern SwiftUI integration
@MainActor @Observable
public final class AccessibilityManager {

    // MARK: - Singleton

    public static let shared = AccessibilityManager()

    // MARK: - Published State

    /// Whether VoiceOver is currently active
    public private(set) var isVoiceOverRunning = false

    /// Whether Reduce Motion is enabled
    public private(set) var isReduceMotionEnabled = false

    /// Whether Reduce Transparency is enabled
    public private(set) var isReduceTransparencyEnabled = false

    /// Whether Bold Text is enabled
    public private(set) var isBoldTextEnabled = false

    /// Whether Increase Contrast is enabled
    public private(set) var isIncreaseContrastEnabled = false

    /// Whether Differentiate Without Color is enabled
    public private(set) var isDifferentiateWithoutColorEnabled = false

    /// Current Dynamic Type size category
    public private(set) var preferredContentSizeCategory: UIContentSizeCategory = .medium

    /// Whether user prefers cross-fade transitions
    public private(set) var prefersCrossFadeTransitions = false

    /// Whether Switch Control is running
    public private(set) var isSwitchControlRunning = false

    // MARK: - Derived Properties

    /// Whether animations should be simplified or disabled
    public var shouldReduceAnimations: Bool {
        isReduceMotionEnabled || prefersCrossFadeTransitions
    }

    /// Whether glass effects should be simplified
    public var shouldSimplifyGlassEffects: Bool {
        isReduceTransparencyEnabled || isReduceMotionEnabled
    }

    /// Current Dynamic Type scale factor (relative to default)
    public var dynamicTypeScale: CGFloat {
        switch preferredContentSizeCategory {
        case .extraSmall: 0.82
        case .small: 0.88
        case .medium: 1.0
        case .large: 1.06
        case .extraLarge: 1.12
        case .extraExtraLarge: 1.18
        case .extraExtraExtraLarge: 1.24
        case .accessibilityMedium: 1.35
        case .accessibilityLarge: 1.50
        case .accessibilityExtraLarge: 1.70
        case .accessibilityExtraExtraLarge: 1.90
        case .accessibilityExtraExtraExtraLarge: 2.10
        default: 1.0
        }
    }

    /// Whether text is at accessibility sizes (AX categories)
    public var isAccessibilityTextSize: Bool {
        preferredContentSizeCategory.isAccessibilityCategory
    }

    /// Whether any assistive technology is active
    public var isAssistiveTechnologyActive: Bool {
        isVoiceOverRunning || isSwitchControlRunning
    }

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        // Initial state
        updateAccessibilityState()

        // Observe changes
        setupObservers()
    }

    // MARK: - State Updates

    private func updateAccessibilityState() {
        isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
        isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
        isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
        isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
        isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
        isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
        prefersCrossFadeTransitions = UIAccessibility.prefersCrossFadeTransitions
        isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
        preferredContentSizeCategory = UIApplication.shared.preferredContentSizeCategory
    }

    private func setupObservers() {
        // VoiceOver
        NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isVoiceOverRunning = UIAccessibility.isVoiceOverRunning
            }
            .store(in: &cancellables)

        // Reduce Motion
        NotificationCenter.default.publisher(for: UIAccessibility.reduceMotionStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isReduceMotionEnabled = UIAccessibility.isReduceMotionEnabled
            }
            .store(in: &cancellables)

        // Reduce Transparency
        NotificationCenter.default.publisher(for: UIAccessibility.reduceTransparencyStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isReduceTransparencyEnabled = UIAccessibility.isReduceTransparencyEnabled
            }
            .store(in: &cancellables)

        // Bold Text
        NotificationCenter.default.publisher(for: UIAccessibility.boldTextStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isBoldTextEnabled = UIAccessibility.isBoldTextEnabled
            }
            .store(in: &cancellables)

        // Increase Contrast
        NotificationCenter.default.publisher(for: UIAccessibility.darkerSystemColorsStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isIncreaseContrastEnabled = UIAccessibility.isDarkerSystemColorsEnabled
            }
            .store(in: &cancellables)

        // Differentiate Without Color
        NotificationCenter.default.publisher(for: UIAccessibility.differentiateWithoutColorDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isDifferentiateWithoutColorEnabled = UIAccessibility.shouldDifferentiateWithoutColor
            }
            .store(in: &cancellables)

        // Cross-fade transitions
        NotificationCenter.default.publisher(for: UIAccessibility.prefersCrossFadeTransitionsStatusDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.prefersCrossFadeTransitions = UIAccessibility.prefersCrossFadeTransitions
            }
            .store(in: &cancellables)

        // Switch Control
        NotificationCenter.default.publisher(for: UIAccessibility.switchControlStatusDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.isSwitchControlRunning = UIAccessibility.isSwitchControlRunning
            }
            .store(in: &cancellables)

        // Dynamic Type
        NotificationCenter.default.publisher(for: UIContentSizeCategory.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                if let category = notification
                    .userInfo?[UIContentSizeCategory.newValueUserInfoKey] as? UIContentSizeCategory {
                    self?.preferredContentSizeCategory = category
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Utility Methods

    /// Returns an appropriate animation based on accessibility preferences
    public func animation(for baseAnimation: Animation) -> Animation? {
        if shouldReduceAnimations {
            return nil
        }
        return baseAnimation
    }

    /// Returns an appropriate spring animation or nil for reduced motion
    public func springAnimation(
        response: Double = 0.3,
        dampingFraction: Double = 0.8,
        blendDuration: Double = 0,
    ) -> Animation? {
        if shouldReduceAnimations {
            return nil
        }
        return .spring(response: response, dampingFraction: dampingFraction, blendDuration: blendDuration)
    }

    /// Clamps a font size for accessibility text sizes
    public func clampedFontSize(_ size: CGFloat, max: CGFloat) -> CGFloat {
        if isAccessibilityTextSize {
            return min(size * dynamicTypeScale, max)
        }
        return size * dynamicTypeScale
    }

    /// Posts an accessibility announcement
    public func announce(_ message: String, after delay: TimeInterval = 0.1) {
        Task {
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    /// Posts a screen change notification
    public func screenChanged(to element: Any? = nil) {
        UIAccessibility.post(notification: .screenChanged, argument: element)
    }

    /// Posts a layout change notification
    public func layoutChanged(to element: Any? = nil) {
        UIAccessibility.post(notification: .layoutChanged, argument: element)
    }
}

// MARK: - Environment Key

private struct AccessibilityManagerKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: AccessibilityManager = // Note: This is safe because
        // AccessibilityManager is @MainActor isolated
        // and SwiftUI environment values are always accessed on the main thread
        MainActor.assumeIsolated {
            AccessibilityManager.shared
        }
}

extension EnvironmentValues {
    public var accessibilityManager: AccessibilityManager {
        get { self[AccessibilityManagerKey.self] }
        set { self[AccessibilityManagerKey.self] = newValue }
    }
}

// MARK: - Accessibility Feature Flags

/// Feature flags based on accessibility preferences
@MainActor
public struct AccessibilityFeatureFlags {
    let manager: AccessibilityManager

    /// Whether to use simplified card designs
    public var useSimplifiedCards: Bool {
        manager.isAccessibilityTextSize || manager.isReduceTransparencyEnabled
    }

    /// Whether to use high contrast borders
    public var useHighContrastBorders: Bool {
        manager.isIncreaseContrastEnabled || manager.isDifferentiateWithoutColorEnabled
    }

    /// Whether to show text labels alongside icons
    public var showIconLabels: Bool {
        manager.isVoiceOverRunning || manager.isDifferentiateWithoutColorEnabled
    }

    /// Whether to use larger touch targets
    public var useLargerTouchTargets: Bool {
        manager.isAccessibilityTextSize || manager.isSwitchControlRunning
    }

    /// Minimum touch target size
    public var minimumTouchTargetSize: CGFloat {
        useLargerTouchTargets ? 60 : 44
    }
}

extension AccessibilityManager {
    public var featureFlags: AccessibilityFeatureFlags {
        AccessibilityFeatureFlags(manager: self)
    }
}

// MARK: - Preview

#Preview("Accessibility Manager State") {
    struct AccessibilityStateView: View {
        let manager = AccessibilityManager.shared

        var body: some View {
            List {
                Section("Assistive Technologies") {
                    StateRow("VoiceOver", isEnabled: manager.isVoiceOverRunning)
                    StateRow("Switch Control", isEnabled: manager.isSwitchControlRunning)
                }

                Section("Visual Preferences") {
                    StateRow("Reduce Motion", isEnabled: manager.isReduceMotionEnabled)
                    StateRow("Reduce Transparency", isEnabled: manager.isReduceTransparencyEnabled)
                    StateRow("Bold Text", isEnabled: manager.isBoldTextEnabled)
                    StateRow("Increase Contrast", isEnabled: manager.isIncreaseContrastEnabled)
                    StateRow("Differentiate Without Color", isEnabled: manager.isDifferentiateWithoutColorEnabled)
                }

                Section("Dynamic Type") {
                    HStack {
                        Text("Category")
                        Spacer()
                        Text(manager.preferredContentSizeCategory.displayName)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Scale Factor")
                        Spacer()
                        Text(String(format: "%.2fx", manager.dynamicTypeScale))
                            .foregroundStyle(.secondary)
                    }
                    StateRow("Accessibility Size", isEnabled: manager.isAccessibilityTextSize)
                }

                Section("Derived State") {
                    StateRow("Should Reduce Animations", isEnabled: manager.shouldReduceAnimations)
                    StateRow("Should Simplify Glass", isEnabled: manager.shouldSimplifyGlassEffects)
                    StateRow("Assistive Tech Active", isEnabled: manager.isAssistiveTechnologyActive)
                }
            }
            .navigationTitle("Accessibility State")
        }
    }

    struct StateRow: View {
        let title: String
        let isEnabled: Bool

        init(_ title: String, isEnabled: Bool) {
            self.title = title
            self.isEnabled = isEnabled
        }

        var body: some View {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isEnabled ? .green : .secondary)
            }
        }
    }

    return NavigationStack {
        AccessibilityStateView()
    }
}

#endif
