// MARK: - QuietHoursCard.swift
// Molecular Component: Quiet Hours Configuration Card
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade

import SwiftUI

/// A card for configuring quiet hours settings.
///
/// This molecular component provides:
/// - Enable/disable toggle
/// - Start and end time display
/// - Quick access to configuration
/// - Visual time range indicator
///
/// ## Usage
/// ```swift
/// QuietHoursCard(
///     quietHours: viewModel.preferences.settings.quietHours,
///     onToggle: { await viewModel.updateQuietHours(enabled: $0, start: "22:00", end: "08:00") },
///     onConfigure: { viewModel.showQuietHoursSheet = true }
/// )
/// ```
public struct QuietHoursCard: View {
    // MARK: - Properties

    private let quietHours: QuietHours
    private let onToggle: (Bool) async -> Void
    private let onConfigure: () -> Void

    // MARK: - State

    @State private var isProcessing = false

    // MARK: - Initialization

    /// Creates a new quiet hours card.
    ///
    /// - Parameters:
    ///   - quietHours: Current quiet hours settings
    ///   - onToggle: Async handler for toggling quiet hours
    ///   - onConfigure: Handler for showing configuration sheet
    public init(
        quietHours: QuietHours,
        onToggle: @escaping (Bool) async -> Void,
        onConfigure: @escaping () -> Void,
    ) {
        self.quietHours = quietHours
        self.onToggle = onToggle
        self.onConfigure = onConfigure
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: Spacing.md) {
            // Header
            HStack(spacing: Spacing.md) {
                // Icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: quietHours.enabled
                                    ? [.DesignSystem.brandBlue, .DesignSystem.accentPurple]
                                    : [.DesignSystem.textSecondary, .DesignSystem.textTertiary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: quietHours.enabled ? "moon.stars.fill" : "moon.stars")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Title and status
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Quiet Hours")
                        .font(.DesignSystem.headlineSmall)
                        .foregroundColor(.DesignSystem.textPrimary)

                    if quietHours.enabled {
                        Text("\(quietHours.start) - \(quietHours.end)")
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.brandBlue)
                    } else {
                        Text("No quiet hours set")
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }

                Spacer()

                // Toggle
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .DesignSystem.brandGreen))
                        .scaleEffect(0.8)
                } else {
                    Toggle("", isOn: Binding(
                        get: { quietHours.enabled },
                        set: { newValue in
                            Task {
                                isProcessing = true
                                HapticFeedback.light()
                                await onToggle(newValue)
                                isProcessing = false
                            }
                        },
                    ))
                    .tint(.DesignSystem.brandBlue)
                    .labelsHidden()
                }
            }

            // Time range visualization (when enabled)
            if quietHours.enabled {
                timeRangeVisualization
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top)),
                    ))
            }

            // Configure button
            Button {
                HapticFeedback.light()
                onConfigure()
            } label: {
                HStack {
                    Image(systemName: "clock")
                    Text(quietHours.enabled ? "Change Times" : "Set Quiet Hours")
                }
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.brandBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.DesignSystem.brandBlue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    quietHours.enabled
                        ? Color.DesignSystem.brandBlue.opacity(0.3)
                        : Color.clear,
                    lineWidth: 1,
                ),
        )
    }

    // MARK: - Time Range Visualization

    private var timeRangeVisualization: some View {
        VStack(spacing: Spacing.xs) {
            Divider()

            HStack(spacing: Spacing.sm) {
                // Start time
                VStack(spacing: 4) {
                    Image(systemName: "moon.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.DesignSystem.brandBlue)

                    Text(quietHours.start)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.DesignSystem.textPrimary)

                    Text("Start")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.DesignSystem.brandBlue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Connector
                Image(systemName: "arrow.right")
                    .font(.system(size: 12))
                    .foregroundColor(.DesignSystem.textTertiary)

                // End time
                VStack(spacing: 4) {
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.DesignSystem.accentOrange)

                    Text(quietHours.end)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.DesignSystem.textPrimary)

                    Text("End")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.DesignSystem.accentOrange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Description
            HStack(spacing: Spacing.xs) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.DesignSystem.textTertiary)

                Text("Notifications will be silenced during these hours")
                    .font(.system(size: 11))
                    .foregroundColor(.DesignSystem.textTertiary)

                Spacer()
            }
        }
    }
}

// MARK: - Preview

#Preview("Quiet Hours States") {
    VStack(spacing: Spacing.md) {
        // Disabled
        QuietHoursCard(
            quietHours: QuietHours(enabled: false),
            onToggle: { _ in try? await Task.sleep(nanoseconds: 500_000_000) },
            onConfigure: { print("Configure") },
        )

        // Enabled
        QuietHoursCard(
            quietHours: QuietHours(
                enabled: true,
                start: "22:00",
                end: "08:00",
            ),
            onToggle: { _ in try? await Task.sleep(nanoseconds: 500_000_000) },
            onConfigure: { print("Configure") },
        )

        // Custom times
        QuietHoursCard(
            quietHours: QuietHours(
                enabled: true,
                start: "23:30",
                end: "07:00",
            ),
            onToggle: { _ in try? await Task.sleep(nanoseconds: 500_000_000) },
            onConfigure: { print("Configure") },
        )
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var quietHours = QuietHours(enabled: false)

        var body: some View {
            VStack(spacing: Spacing.lg) {
                QuietHoursCard(
                    quietHours: quietHours,
                    onToggle: { enabled in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        quietHours.enabled = enabled
                    },
                    onConfigure: {
                        // Simulate changing times
                        quietHours.start = "23:00"
                        quietHours.end = "07:30"
                    },
                )

                // Status display
                VStack(spacing: Spacing.sm) {
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(quietHours.enabled ? "Active" : "Inactive")
                            .foregroundColor(quietHours.enabled ? .DesignSystem.brandBlue : .DesignSystem.textSecondary)
                    }

                    if quietHours.enabled {
                        HStack {
                            Text("Times:")
                            Spacer()
                            Text("\(quietHours.start) - \(quietHours.end)")
                                .foregroundColor(.DesignSystem.brandBlue)
                        }
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

#Preview("With DND") {
    VStack(spacing: Spacing.md) {
        DNDStatusCard(
            dnd: DoNotDisturb(enabled: true, until: Date().addingTimeInterval(3600)),
            onEnable: { _ in },
            onDisable: {},
        )

        QuietHoursCard(
            quietHours: QuietHours(enabled: true, start: "22:00", end: "08:00"),
            onToggle: { _ in },
            onConfigure: {},
        )

        // Info card
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.DesignSystem.brandBlue)

                Text("DND vs Quiet Hours")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textPrimary)
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("• Do Not Disturb: Temporary silence for a set duration")
                Text("• Quiet Hours: Daily recurring silence during specific times")
            }
            .font(.DesignSystem.captionSmall)
            .foregroundColor(.DesignSystem.textSecondary)
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.brandBlue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}
