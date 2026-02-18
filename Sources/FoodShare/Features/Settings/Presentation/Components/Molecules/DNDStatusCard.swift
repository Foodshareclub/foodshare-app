// MARK: - DNDStatusCard.swift
// Molecular Component: Do Not Disturb Quick Toggle Card
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade



#if !SKIP
import SwiftUI

/// A card for quickly enabling/disabling Do Not Disturb mode.
///
/// This molecular component provides:
/// - Current DND status display
/// - Quick toggle functionality
/// - Remaining time indicator
/// - Preset duration buttons
/// - Glass morphism design
///
/// ## Usage
/// ```swift
/// DNDStatusCard(
///     dnd: viewModel.preferences.settings.dnd,
///     onEnable: { hours in await viewModel.enableDND(hours: hours) },
///     onDisable: { await viewModel.disableDND() }
/// )
/// ```
public struct DNDStatusCard: View {
    // MARK: - Properties

    private let dnd: DoNotDisturb
    private let onEnable: (Int) async -> Void
    private let onDisable: () async -> Void
    private let onCustomize: (() -> Void)?

    // MARK: - State

    @State private var isProcessing = false
    @State private var showDurationPicker = false

    // MARK: - Preset Durations

    private let presetDurations = [1, 2, 4, 8]

    // MARK: - Initialization

    /// Creates a new DND status card.
    ///
    /// - Parameters:
    ///   - dnd: Current DND settings
    ///   - onEnable: Async handler for enabling DND with duration in hours
    ///   - onDisable: Async handler for disabling DND
    ///   - onCustomize: Optional handler for showing custom duration picker
    public init(
        dnd: DoNotDisturb,
        onEnable: @escaping (Int) async -> Void,
        onDisable: @escaping () async -> Void,
        onCustomize: (() -> Void)? = nil,
    ) {
        self.dnd = dnd
        self.onEnable = onEnable
        self.onDisable = onDisable
        self.onCustomize = onCustomize
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
                                colors: dnd.isActive
                                    ? [.DesignSystem.accentPurple, .DesignSystem.brandBlue]
                                    : [.DesignSystem.textSecondary, .DesignSystem.textTertiary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 44.0, height: 44)

                    Image(systemName: dnd.isActive ? "moon.fill" : "moon")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }

                // Title and status
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("Do Not Disturb")
                        .font(.DesignSystem.headlineSmall)
                        .foregroundColor(.DesignSystem.textPrimary)

                    if dnd.isActive {
                        if let remaining = dnd.remainingTimeFormatted {
                            Text(remaining)
                                .font(.DesignSystem.captionSmall)
                                .foregroundColor(.DesignSystem.accentPurple)
                        } else {
                            Text("Active")
                                .font(.DesignSystem.captionSmall)
                                .foregroundColor(.DesignSystem.accentPurple)
                        }
                    } else {
                        Text("Receive all notifications")
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }

                Spacer()

                // Main toggle
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.DesignSystem.brandGreen))
                        .scaleEffect(0.8)
                } else {
                    Toggle("", isOn: Binding(
                        get: { dnd.isActive },
                        set: { newValue in
                            if newValue {
                                showDurationPicker = true
                            } else {
                                Task {
                                    isProcessing = true
                                    await onDisable()
                                    isProcessing = false
                                }
                            }
                        },
                    ))
                    .tint(.DesignSystem.accentPurple)
                    .labelsHidden()
                }
            }

            // Duration picker (when enabling)
            if showDurationPicker, !dnd.isActive {
                durationPicker
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top)),
                    ))
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    dnd.isActive
                        ? Color.DesignSystem.accentPurple.opacity(0.3)
                        : Color.clear,
                    lineWidth: 1,
                ),
        )
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        VStack(spacing: Spacing.sm) {
            Divider()

            Text("Enable for:")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(
                columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ],
                spacing: Spacing.sm,
            ) {
                ForEach(presetDurations, id: \.self) { hours in
                    Button {
                        Task {
                            showDurationPicker = false
                            isProcessing = true
                            HapticFeedback.selection()
                            await onEnable(hours)
                            isProcessing = false
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(hours)")
                                .font(.system(size: 18, weight: .bold))

                            Text(hours == 1 ? "hour" : "hours")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.DesignSystem.accentPurple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.DesignSystem.accentPurple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            // Custom duration
            if let customize = onCustomize {
                Button {
                    showDurationPicker = false
                    customize()
                } label: {
                    HStack {
                        Image(systemName: "clock")
                        Text("Custom Duration")
                    }
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.brandBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.DesignSystem.brandBlue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Cancel
            Button("Cancel") {
                withAnimation {
                    showDurationPicker = false
                }
            }
            .font(.DesignSystem.bodySmall)
            .foregroundColor(.DesignSystem.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
        }
    }
}

// MARK: - Preview

#Preview("DND States") {
    VStack(spacing: Spacing.md) {
        // Inactive
        DNDStatusCard(
            dnd: DoNotDisturb(enabled: false),
            onEnable: { _ in try? await Task.sleep(nanoseconds: 500_000_000) },
            onDisable: { try? await Task.sleep(nanoseconds: 500_000_000) },
        )

        // Active with time
        DNDStatusCard(
            dnd: DoNotDisturb(
                enabled: true,
                until: Date().addingTimeInterval(7200), // 2 hours
            ),
            onEnable: { _ in try? await Task.sleep(nanoseconds: 500_000_000) },
            onDisable: { try? await Task.sleep(nanoseconds: 500_000_000) },
        )

        // Active indefinitely
        DNDStatusCard(
            dnd: DoNotDisturb(enabled: true, until: nil),
            onEnable: { _ in try? await Task.sleep(nanoseconds: 500_000_000) },
            onDisable: { try? await Task.sleep(nanoseconds: 500_000_000) },
        )
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var dnd = DoNotDisturb(enabled: false)

        var body: some View {
            VStack(spacing: Spacing.lg) {
                DNDStatusCard(
                    dnd: dnd,
                    onEnable: { hours in
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        dnd = DoNotDisturb(
                            enabled: true,
                            until: Date().addingTimeInterval(Double(hours) * 3600),
                        )
                    },
                    onDisable: {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        dnd = DoNotDisturb(enabled: false)
                    },
                    onCustomize: {
                        print("Show custom duration picker")
                    },
                )

                // Status display
                VStack(spacing: Spacing.sm) {
                    HStack {
                        Text("Status:")
                        Spacer()
                        Text(dnd.isActive ? "Active" : "Inactive")
                            .foregroundColor(dnd.isActive ? .DesignSystem.accentPurple : .DesignSystem.textSecondary)
                    }

                    if let until = dnd.until {
                        HStack {
                            Text("Until:")
                            Spacer()
                            Text(until, style: .time)
                                .foregroundColor(.DesignSystem.brandBlue)
                        }
                    }

                    if let remaining = dnd.remainingTimeFormatted {
                        HStack {
                            Text("Remaining:")
                            Spacer()
                            Text(remaining)
                                .foregroundColor(.DesignSystem.accentPurple)
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

#Preview("With Description") {
    VStack(spacing: Spacing.md) {
        DNDStatusCard(
            dnd: DoNotDisturb(enabled: false),
            onEnable: { _ in },
            onDisable: {},
        )

        // Description card
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.DesignSystem.brandBlue)

                Text("About Do Not Disturb")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textPrimary)
            }

            Text(
                "When enabled, you won't receive any notifications. Your preferences will be paused until you turn it off or the timer expires.",
            )
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


#endif
