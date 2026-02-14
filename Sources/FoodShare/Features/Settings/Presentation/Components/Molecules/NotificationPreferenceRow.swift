// MARK: - NotificationPreferenceRow.swift
// Molecular Component: Single Preference Row with Toggle + Frequency Picker
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade

import SwiftUI

/// A complete row for managing a single notification preference.
///
/// This molecular component provides:
/// - Icon, title, and description display
/// - Toggle for enable/disable
/// - Expandable frequency picker
/// - Loading state support
/// - Haptic feedback
///
/// ## Usage
/// ```swift
/// NotificationPreferenceRow(
///     category: .posts,
///     channel: .push,
///     isEnabled: $isEnabled,
///     frequency: $frequency,
///     isLoading: false
/// )
/// ```
public struct NotificationPreferenceRow: View {
    // MARK: - Properties

    private let category: NotificationCategory
    private let channel: NotificationChannel
    @Binding private var isEnabled: Bool
    @Binding private var frequency: NotificationFrequency
    private let isLoading: Bool
    private let isDisabled: Bool

    // MARK: - State

    @State private var showFrequencyPicker = false

    // MARK: - Initialization

    /// Creates a new notification preference row.
    ///
    /// - Parameters:
    ///   - category: The notification category
    ///   - channel: The notification channel
    ///   - isEnabled: Binding to enabled state
    ///   - frequency: Binding to frequency setting
    ///   - isLoading: Whether the preference is currently updating
    ///   - isDisabled: Whether the row should be disabled
    public init(
        category: NotificationCategory,
        channel: NotificationChannel,
        isEnabled: Binding<Bool>,
        frequency: Binding<NotificationFrequency>,
        isLoading: Bool = false,
        isDisabled: Bool = false,
    ) {
        self.category = category
        self.channel = channel
        self._isEnabled = isEnabled
        self._frequency = frequency
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: Spacing.md) {
                // Icon
                NotificationIcon(
                    category: category,
                    size: .small,
                )

                // Content
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(category.displayName)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(isDisabled ? .DesignSystem.textTertiary : .DesignSystem.textPrimary)

                    if isEnabled {
                        FrequencyBadge(frequency: frequency)
                    }
                }

                Spacer()

                // Toggle
                NotificationToggle(
                    isOn: $isEnabled,
                    isLoading: isLoading,
                    isDisabled: isDisabled,
                )
            }
            .padding(Spacing.md)
            .contentShape(Rectangle())
            .onTapGesture {
                if isEnabled, !isLoading, !isDisabled {
                    withAnimation(.smooth) {
                        showFrequencyPicker.toggle()
                    }
                    HapticFeedback.light()
                }
            }

            // Frequency picker (expandable)
            if showFrequencyPicker, isEnabled, !isDisabled {
                frequencyPicker
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top)),
                    ))
            }
        }
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isDisabled ? 0.5 : 1.0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(category.displayName) notifications")
        .accessibilityValue(isEnabled ? "Enabled, \(frequency.displayName)" : "Disabled")
    }

    // MARK: - Frequency Picker

    private var frequencyPicker: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, Spacing.md)

            VStack(spacing: Spacing.xs) {
                ForEach(NotificationFrequency.allCases, id: \.self) { freq in
                    frequencyOption(freq)
                }
            }
            .padding(Spacing.md)
        }
    }

    private func frequencyOption(_ freq: NotificationFrequency) -> some View {
        Button {
            withAnimation(.smooth) {
                frequency = freq
                showFrequencyPicker = false
            }
            HapticFeedback.selection()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: freq.icon)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(frequency == freq ? .DesignSystem.brandGreen : .DesignSystem.textSecondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(freq.displayName)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textPrimary)

                    Text(freq.description)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()

                if frequency == freq {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.brandGreen)
                }
            }
            .padding(Spacing.sm)
            .background(
                frequency == freq
                    ? Color.DesignSystem.brandGreen.opacity(0.1)
                    : Color.clear,
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simplified Row (No Frequency)

/// A simplified row that only shows enable/disable toggle
public struct SimpleNotificationPreferenceRow: View {
    private let category: NotificationCategory
    private let channel: NotificationChannel
    @Binding private var isEnabled: Bool
    private let isLoading: Bool
    private let isDisabled: Bool
    private let showDescription: Bool

    public init(
        category: NotificationCategory,
        channel: NotificationChannel,
        isEnabled: Binding<Bool>,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        showDescription: Bool = false,
    ) {
        self.category = category
        self.channel = channel
        self._isEnabled = isEnabled
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.showDescription = showDescription
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon
            NotificationIcon(
                category: category,
                size: .small,
            )

            // Content
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(category.displayName)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(isDisabled ? .DesignSystem.textTertiary : .DesignSystem.textPrimary)

                if showDescription {
                    Text(category.description)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Toggle
            NotificationToggle(
                isOn: $isEnabled,
                isLoading: isLoading,
                isDisabled: isDisabled,
            )
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview("Preference Row States") {
    VStack(spacing: Spacing.md) {
        // Enabled with frequency
        NotificationPreferenceRow(
            category: .posts,
            channel: .push,
            isEnabled: .constant(true),
            frequency: .constant(.daily),
        )

        // Enabled with instant
        NotificationPreferenceRow(
            category: .chats,
            channel: .push,
            isEnabled: .constant(true),
            frequency: .constant(.instant),
        )

        // Disabled
        NotificationPreferenceRow(
            category: .marketing,
            channel: .email,
            isEnabled: .constant(false),
            frequency: .constant(.weekly),
        )

        // Loading
        NotificationPreferenceRow(
            category: .social,
            channel: .push,
            isEnabled: .constant(true),
            frequency: .constant(.instant),
            isLoading: true,
        )

        // Disabled row
        NotificationPreferenceRow(
            category: .system,
            channel: .push,
            isEnabled: .constant(true),
            frequency: .constant(.instant),
            isDisabled: true,
        )
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("Interactive Row") {
    struct InteractivePreview: View {
        @State private var isEnabled = true
        @State private var frequency: NotificationFrequency = .instant

        var body: some View {
            VStack(spacing: Spacing.lg) {
                NotificationPreferenceRow(
                    category: .posts,
                    channel: .push,
                    isEnabled: $isEnabled,
                    frequency: $frequency,
                )

                // Info
                VStack(spacing: Spacing.sm) {
                    HStack {
                        Text("Enabled:")
                        Spacer()
                        Text(isEnabled ? "Yes" : "No")
                            .foregroundColor(isEnabled ? .DesignSystem.success : .DesignSystem.textSecondary)
                    }

                    HStack {
                        Text("Frequency:")
                        Spacer()
                        Text(frequency.displayName)
                            .foregroundColor(.DesignSystem.brandBlue)
                    }
                }
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textPrimary)
                .padding(Spacing.md)
                .background(Color.DesignSystem.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(Spacing.md)
            .background(Color.DesignSystem.background)
        }
    }

    return InteractivePreview()
}

#Preview("Simple Rows") {
    VStack(spacing: Spacing.md) {
        SimpleNotificationPreferenceRow(
            category: .posts,
            channel: .push,
            isEnabled: .constant(true),
        )

        SimpleNotificationPreferenceRow(
            category: .chats,
            channel: .push,
            isEnabled: .constant(true),
            showDescription: true,
        )

        SimpleNotificationPreferenceRow(
            category: .marketing,
            channel: .email,
            isEnabled: .constant(false),
            showDescription: true,
        )
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("All Categories") {
    ScrollView {
        VStack(spacing: Spacing.sm) {
            ForEach(NotificationCategory.allCases, id: \.self) { category in
                NotificationPreferenceRow(
                    category: category,
                    channel: .push,
                    isEnabled: .constant(true),
                    frequency: .constant(.instant),
                )
            }
        }
        .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
}
