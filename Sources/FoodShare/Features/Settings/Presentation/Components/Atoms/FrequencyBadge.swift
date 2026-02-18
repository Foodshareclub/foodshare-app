// MARK: - FrequencyBadge.swift
// Atomic Component: Frequency Badge Pill
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade



#if !SKIP
import SwiftUI

/// A compact badge displaying notification frequency with contextual styling.
///
/// This atomic component provides:
/// - Color-coded frequency display
/// - Compact pill design
/// - Animated transitions
/// - Accessibility support
///
/// ## Usage
/// ```swift
/// FrequencyBadge(frequency: .instant)
/// FrequencyBadge(frequency: .daily, isCompact: false)
/// ```
public struct FrequencyBadge: View {
    // MARK: - Properties

    /// The notification frequency to display
    private let frequency: NotificationFrequency

    /// Whether to use compact display (icon only)
    private let isCompact: Bool

    /// Optional custom size
    private let fontSize: CGFloat

    // MARK: - Initialization

    /// Creates a new frequency badge.
    ///
    /// - Parameters:
    ///   - frequency: The notification frequency
    ///   - isCompact: Whether to show only the icon (default: false)
    ///   - fontSize: Custom font size (default: 11)
    public init(
        frequency: NotificationFrequency,
        isCompact: Bool = false,
        fontSize: CGFloat = 11,
    ) {
        self.frequency = frequency
        self.isCompact = isCompact
        self.fontSize = fontSize
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: frequency.icon)
                .font(.system(size: fontSize - 1, weight: .semibold))

            if !isCompact {
                Text(frequency.displayName)
                    .font(.system(size: fontSize, weight: .medium))
            }
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, 4)
        .background(backgroundColor)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .strokeBorder(borderColor, lineWidth: 1),
        )
        .accessibilityLabel(frequency.displayName)
    }

    // MARK: - Styling

    private var backgroundColor: Color {
        switch frequency {
        case .instant:
            Color.DesignSystem.brandGreen.opacity(0.15)
        case .hourly:
            Color.DesignSystem.brandBlue.opacity(0.15)
        case .daily:
            Color.DesignSystem.accentOrange.opacity(0.15)
        case .weekly:
            Color.DesignSystem.accentPurple.opacity(0.15)
        case .never:
            Color.DesignSystem.textTertiary.opacity(0.1)
        }
    }

    private var foregroundColor: Color {
        switch frequency {
        case .instant:
            .DesignSystem.brandGreen
        case .hourly:
            .DesignSystem.brandBlue
        case .daily:
            .DesignSystem.accentOrange
        case .weekly:
            .DesignSystem.accentPurple
        case .never:
            .DesignSystem.textSecondary
        }
    }

    private var borderColor: Color {
        foregroundColor.opacity(0.3)
    }
}

// MARK: - Preview

#Preview("All Frequencies") {
    VStack(alignment: .leading, spacing: Spacing.md) {
        Text("Frequency Badges")
            .font(.DesignSystem.headlineMedium)
            .foregroundColor(.DesignSystem.textPrimary)

        Divider()

        // Full badges
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Full Display")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)

            ForEach(NotificationFrequency.allCases, id: \.self) { frequency in
                HStack {
                    FrequencyBadge(frequency: frequency)

                    Spacer()

                    Text(frequency.description)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }
            }
        }

        Divider()

        // Compact badges
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Compact Display")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)

            HStack(spacing: Spacing.sm) {
                ForEach(NotificationFrequency.allCases, id: \.self) { frequency in
                    VStack(spacing: Spacing.xxs) {
                        FrequencyBadge(frequency: frequency, isCompact: true)

                        Text(frequency.rawValue)
                            .font(.system(size: 9))
                            .foregroundColor(.DesignSystem.textTertiary)
                    }
                }
            }
        }

        Divider()

        // Size variants
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Size Variants")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)

            HStack(spacing: Spacing.md) {
                FrequencyBadge(frequency: .instant, fontSize: 9)
                FrequencyBadge(frequency: .instant, fontSize: 11)
                FrequencyBadge(frequency: .instant, fontSize: 13)
            }
        }

        Divider()

        // In context
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("In Context")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)

            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Post Notifications")
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.textPrimary)

                    FrequencyBadge(frequency: .daily)
                }

                Spacer()

                Toggle("", isOn: .constant(true))
                    .labelsHidden()
                    .tint(.DesignSystem.brandGreen)
            }
            .padding(Spacing.md)
            .background(Color.DesignSystem.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var selectedFrequency: NotificationFrequency = .instant

        var body: some View {
            VStack(spacing: Spacing.lg) {
                // Current selection
                VStack(spacing: Spacing.sm) {
                    Text("Current Frequency")
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)

                    FrequencyBadge(frequency: selectedFrequency)
                }
                .padding(Spacing.md)
                .background(Color.DesignSystem.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Picker
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Select Frequency")
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)

                    ForEach(NotificationFrequency.allCases, id: \.self) { frequency in
                        Button {
                            withAnimation(.smooth) {
                                selectedFrequency = frequency
                            }
                        } label: {
                            HStack {
                                FrequencyBadge(frequency: frequency)

                                Spacer()

                                if selectedFrequency == frequency {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.DesignSystem.brandGreen)
                                }
                            }
                            .padding(Spacing.sm)
                            .background(
                                selectedFrequency == frequency
                                    ? Color.DesignSystem.brandGreen.opacity(0.1)
                                    : Color.DesignSystem.glassBackground,
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .background(Color.DesignSystem.background)
        }
    }

    return InteractivePreview()
}

#Preview("Grid Layout") {
    ScrollView {
        LazyVGrid(
            columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
            ],
            spacing: Spacing.sm,
        ) {
            ForEach(0 ..< 15) { index in
                let frequency = NotificationFrequency.allCases[index % NotificationFrequency.allCases.count]

                VStack(spacing: Spacing.xs) {
                    Text("Category \(index + 1)")
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textPrimary)

                    FrequencyBadge(frequency: frequency, isCompact: true)
                }
                .frame(maxWidth: .infinity)
                .padding(Spacing.sm)
                .background(Color.DesignSystem.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
}


#endif
