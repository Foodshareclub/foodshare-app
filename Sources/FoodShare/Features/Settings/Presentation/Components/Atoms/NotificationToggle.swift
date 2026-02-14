// MARK: - NotificationToggle.swift
// Atomic Component: Animated Toggle with Loading State
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade

import SwiftUI

/// An animated toggle control for notification preferences with loading state support.
///
/// This atomic component provides:
/// - Smooth animations with haptic feedback
/// - Loading spinner overlay during async operations
/// - Accessibility support with custom labels
/// - Liquid Glass design language integration
///
/// ## Usage
/// ```swift
/// NotificationToggle(
///     isOn: $isEnabled,
///     isLoading: viewModel.isUpdating(category: .posts, channel: .push)
/// )
/// .accessibilityLabel("Enable post notifications")
/// ```
public struct NotificationToggle: View {
    // MARK: - Properties

    /// The binding to the toggle state
    @Binding private var isOn: Bool

    /// Whether the toggle is currently in a loading state
    private let isLoading: Bool

    /// Optional custom accent color
    private let accentColor: Color

    /// Whether the toggle is disabled
    private let isDisabled: Bool

    // MARK: - State

    @State private var isAnimating = false

    // MARK: - Initialization

    /// Creates a new notification toggle.
    ///
    /// - Parameters:
    ///   - isOn: Binding to the toggle state
    ///   - isLoading: Whether the toggle is in a loading state
    ///   - accentColor: Custom accent color (defaults to brand green)
    ///   - isDisabled: Whether the toggle is disabled
    public init(
        isOn: Binding<Bool>,
        isLoading: Bool = false,
        accentColor: Color = .DesignSystem.brandGreen,
        isDisabled: Bool = false,
    ) {
        self._isOn = isOn
        self.isLoading = isLoading
        self.accentColor = accentColor
        self.isDisabled = isDisabled
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            // Base toggle
            Toggle("", isOn: $isOn)
                .tint(accentColor)
                .labelsHidden()
                .disabled(isDisabled || isLoading)
                .opacity(isLoading ? 0.5 : 1.0)
                .animation(.smooth(duration: 0.2), value: isOn)
                .animation(.smooth(duration: 0.2), value: isLoading)

            // Loading overlay
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: accentColor))
                        .scaleEffect(0.7)
                        .frame(width: 51, height: 31) // Standard toggle size
                }
            }
        }
        .frame(width: 51, height: 31)
        .onChange(of: isOn) { oldValue, newValue in
            if !isLoading {
                // Haptic feedback on change
                HapticFeedback.light()
            }
        }
    }
}

// MARK: - Preview

#Preview("Toggle States") {
    VStack(spacing: Spacing.lg) {
        // Off state
        HStack {
            Text("Off")
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textPrimary)
            Spacer()
            NotificationToggle(isOn: .constant(false))
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        // On state
        HStack {
            Text("On")
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textPrimary)
            Spacer()
            NotificationToggle(isOn: .constant(true))
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        // Loading state
        HStack {
            Text("Loading")
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textPrimary)
            Spacer()
            NotificationToggle(isOn: .constant(true), isLoading: true)
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        // Disabled state
        HStack {
            Text("Disabled")
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
            Spacer()
            NotificationToggle(isOn: .constant(false), isDisabled: true)
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))

        // Custom color
        HStack {
            Text("Custom Color")
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textPrimary)
            Spacer()
            NotificationToggle(
                isOn: .constant(true),
                accentColor: .DesignSystem.brandBlue,
            )
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var isOn = false
        @State private var isLoading = false

        var body: some View {
            VStack(spacing: Spacing.xl) {
                HStack {
                    Text("Notifications")
                        .font(.DesignSystem.headlineMedium)
                        .foregroundColor(.DesignSystem.textPrimary)
                    Spacer()
                    NotificationToggle(isOn: $isOn, isLoading: isLoading)
                }
                .padding(Spacing.md)
                .background(Color.DesignSystem.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Simulate Loading") {
                    isLoading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isLoading = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(Spacing.md)
            .background(Color.DesignSystem.background)
        }
    }

    return InteractivePreview()
}
