// MARK: - ChannelHeader.swift
// Molecular Component: Expandable Section Header for Push/Email/SMS
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade


#if !SKIP
import SwiftUI

/// An expandable header for notification channel sections.
///
/// This molecular component provides:
/// - Channel icon and name
/// - Expand/collapse indicator
/// - Master toggle for the entire channel
/// - Availability indicator
/// - Smooth animations
///
/// ## Usage
/// ```swift
/// ChannelHeader(
///     channel: .push,
///     isExpanded: $isExpanded,
///     isEnabled: $isPushEnabled,
///     isAvailable: true
/// )
/// ```
public struct ChannelHeader: View {
    // MARK: - Properties

    private let channel: NotificationChannel
    @Binding private var isExpanded: Bool
    @Binding private var isEnabled: Bool
    private let isAvailable: Bool
    private let isLoading: Bool
    private let onTapAction: (() -> Void)?

    // MARK: - Initialization

    /// Creates a new channel header.
    ///
    /// - Parameters:
    ///   - channel: The notification channel
    ///   - isExpanded: Binding to expansion state
    ///   - isEnabled: Binding to enabled state
    ///   - isAvailable: Whether the channel is available
    ///   - isLoading: Whether the channel is updating
    ///   - onTapAction: Optional custom tap action (overrides default expand/collapse)
    public init(
        channel: NotificationChannel,
        isExpanded: Binding<Bool>,
        isEnabled: Binding<Bool>,
        isAvailable: Bool = true,
        isLoading: Bool = false,
        onTapAction: (() -> Void)? = nil,
    ) {
        self.channel = channel
        self._isExpanded = isExpanded
        self._isEnabled = isEnabled
        self.isAvailable = isAvailable
        self.isLoading = isLoading
        self.onTapAction = onTapAction
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: Spacing.md) {
                // Expand/collapse chevron
                Image(systemName: "chevron.right")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.smooth(duration: 0.2), value: isExpanded)

                // Channel icon
                NotificationIcon(
                    channel: channel,
                    size: NotificationIcon.Size.small,
                )

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.displayName)
                        .font(.DesignSystem.headlineSmall)
                        .foregroundColor(.DesignSystem.textPrimary)

                    if !isAvailable {
                        unavailabilityLabel
                    }
                }

                Spacer()

                // Master toggle
                NotificationToggle(
                    isOn: $isEnabled,
                    isLoading: isLoading,
                    isDisabled: !isAvailable,
                )
            }
            .padding(Spacing.md)
            #if !SKIP
            .contentShape(Rectangle())
            #endif
            .onTapGesture {
                if let action = onTapAction {
                    action()
                } else {
                    withAnimation(.smooth) {
                        isExpanded.toggle()
                    }
                    HapticFeedback.light()
                }
            }

            // Divider when expanded
            if isExpanded {
                Divider()
                    .padding(.horizontal, Spacing.md)
                    .transition(.opacity)
            }
        }
        .background(Color.DesignSystem.glassBackground)
        #if !SKIP
        .accessibilityElement(children: .contain)
        #endif
        .accessibilityLabel("\(channel.displayName) notifications")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand")
    }

    // MARK: - Unavailability Label

    @ViewBuilder
    private var unavailabilityLabel: some View {
        switch channel {
        case .push:
            Text("Enable in Settings")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.warning)
        case .email:
            Text("Verify your email")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.warning)
        case .sms:
            Text("Verify your phone")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.warning)
        case .inApp:
            Text("Available in app")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.warning)
        }
    }
}

// MARK: - Compact Channel Header

/// A compact header without expand/collapse functionality
public struct CompactChannelHeader: View {
    private let channel: NotificationChannel
    @Binding private var isEnabled: Bool
    private let isAvailable: Bool
    private let isLoading: Bool

    public init(
        channel: NotificationChannel,
        isEnabled: Binding<Bool>,
        isAvailable: Bool = true,
        isLoading: Bool = false,
    ) {
        self.channel = channel
        self._isEnabled = isEnabled
        self.isAvailable = isAvailable
        self.isLoading = isLoading
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            // Channel icon
            NotificationIcon(
                channel: channel,
                size: NotificationIcon.Size.medium,
            )

            // Title and description
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(channel.displayName)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text(channel.description)
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            // Toggle
            NotificationToggle(
                isOn: $isEnabled,
                isLoading: isLoading,
                isDisabled: !isAvailable,
            )
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .opacity(isAvailable ? 1.0 : 0.6)
    }
}

// MARK: - Preview

#Preview("Channel Headers") {
    VStack(spacing: Spacing.md) {
        // Collapsed
        ChannelHeader(
            channel: .push,
            isExpanded: .constant(false),
            isEnabled: .constant(true),
        )

        // Expanded
        ChannelHeader(
            channel: .email,
            isExpanded: .constant(true),
            isEnabled: .constant(true),
        )

        // Unavailable
        ChannelHeader(
            channel: .sms,
            isExpanded: .constant(false),
            isEnabled: .constant(false),
            isAvailable: false,
        )

        // Loading
        ChannelHeader(
            channel: .push,
            isExpanded: .constant(true),
            isEnabled: .constant(true),
            isLoading: true,
        )
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var isPushExpanded = true
        @State private var isEmailExpanded = false
        @State private var isSMSExpanded = false
        @State private var isPushEnabled = true
        @State private var isEmailEnabled = true
        @State private var isSMSEnabled = false

        var body: some View {
            VStack(spacing: Spacing.md) {
                // Push
                VStack(spacing: 0) {
                    ChannelHeader(
                        channel: .push,
                        isExpanded: $isPushExpanded,
                        isEnabled: $isPushEnabled,
                    )

                    if isPushExpanded {
                        VStack(spacing: Spacing.sm) {
                            ForEach(NotificationCategory.allCases.prefix(3), id: \.self) { category in
                                SimpleNotificationPreferenceRow(
                                    category: category,
                                    channel: .push,
                                    isEnabled: .constant(true),
                                )
                            }
                        }
                        .padding(Spacing.md)
                        .background(Color.DesignSystem.glassBackground)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top)),
                        ))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Email
                VStack(spacing: 0) {
                    ChannelHeader(
                        channel: .email,
                        isExpanded: $isEmailExpanded,
                        isEnabled: $isEmailEnabled,
                    )

                    if isEmailExpanded {
                        VStack(spacing: Spacing.sm) {
                            ForEach(NotificationCategory.allCases.prefix(3), id: \.self) { category in
                                SimpleNotificationPreferenceRow(
                                    category: category,
                                    channel: .email,
                                    isEnabled: .constant(true),
                                )
                            }
                        }
                        .padding(Spacing.md)
                        .background(Color.DesignSystem.glassBackground)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .move(edge: .top)),
                        ))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // SMS (unavailable)
                ChannelHeader(
                    channel: .sms,
                    isExpanded: $isSMSExpanded,
                    isEnabled: $isSMSEnabled,
                    isAvailable: false,
                )
            }
            .padding(Spacing.md)
            .background(Color.DesignSystem.background)
        }
    }

    return InteractivePreview()
}

#Preview("Compact Headers") {
    VStack(spacing: Spacing.md) {
        CompactChannelHeader(
            channel: .push,
            isEnabled: .constant(true),
        )

        CompactChannelHeader(
            channel: .email,
            isEnabled: .constant(true),
        )

        CompactChannelHeader(
            channel: .sms,
            isEnabled: .constant(false),
            isAvailable: false,
        )
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("All Channels") {
    VStack(spacing: Spacing.sm) {
        ForEach(NotificationChannel.allCases, id: \.self) { channel in
            VStack(spacing: 0) {
                ChannelHeader(
                    channel: channel,
                    isExpanded: .constant(true),
                    isEnabled: .constant(true),
                )

                VStack(spacing: Spacing.sm) {
                    ForEach(NotificationCategory.allCases.prefix(2), id: \.self) { category in
                        SimpleNotificationPreferenceRow(
                            category: category,
                            channel: channel,
                            isEnabled: .constant(true),
                        )
                    }
                }
                .padding(Spacing.md)
                .background(Color.DesignSystem.glassBackground)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#endif
