// MARK: - StatusIndicator.swift
// Atomic Component: Online/Offline/Syncing Status Indicator
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade



#if !SKIP
import SwiftUI

/// A status indicator showing connection and sync state.
///
/// This atomic component provides:
/// - Animated pulse for active states
/// - Color-coded status display
/// - Optional label text
/// - Accessibility support
///
/// ## Usage
/// ```swift
/// StatusIndicator(status: .online)
/// StatusIndicator(status: .syncing, showLabel: true)
/// StatusIndicator(status: .offline, size: .large)
/// ```
public struct StatusIndicator: View {
    // MARK: - Status

    /// Possible status states
    public enum Status {
        case online
        case offline
        case syncing
        case error

        var color: Color {
            switch self {
            case .online:
                .DesignSystem.success
            case .offline:
                .DesignSystem.textTertiary
            case .syncing:
                .DesignSystem.brandBlue
            case .error:
                .DesignSystem.error
            }
        }

        var label: String {
            switch self {
            case .online:
                "Online"
            case .offline:
                "Offline"
            case .syncing:
                "Syncing"
            case .error:
                "Error"
            }
        }

        var icon: String? {
            switch self {
            case .online:
                "checkmark.circle.fill"
            case .offline:
                "wifi.slash"
            case .syncing:
                nil // Uses animated dots
            case .error:
                "exclamationmark.triangle.fill"
            }
        }

        var shouldPulse: Bool {
            switch self {
            case .online, .syncing:
                true
            case .offline, .error:
                false
            }
        }
    }

    // MARK: - Size

    public enum Size {
        case small
        case medium
        case large

        var dimension: CGFloat {
            switch self {
            case .small: 8
            case .medium: 10
            case .large: 12
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .small: 10
            case .medium: 12
            case .large: 14
            }
        }
    }

    // MARK: - Properties

    private let status: Status
    private let size: Size
    private let showLabel: Bool

    // MARK: - State

    @State private var isPulsing = false

    // MARK: - Initialization

    /// Creates a new status indicator.
    ///
    /// - Parameters:
    ///   - status: The current status
    ///   - size: Size variant
    ///   - showLabel: Whether to show the label text
    public init(
        status: Status,
        size: Size = .medium,
        showLabel: Bool = false,
    ) {
        self.status = status
        self.size = size
        self.showLabel = showLabel
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 6) {
            // Status indicator
            ZStack {
                if status == .syncing {
                    // Animated syncing indicator
                    syncingIndicator
                } else if let icon = status.icon {
                    // Icon-based indicator
                    Image(systemName: icon)
                        .font(.system(size: size.dimension, weight: .semibold))
                        .foregroundColor(status.color)
                } else {
                    // Dot indicator
                    Circle()
                        .fill(status.color)
                        .frame(width: size.dimension, height: size.dimension)
                        .overlay(
                            Circle()
                                .fill(status.color.opacity(0.3))
                                .scaleEffect(isPulsing ? 1.5 : 1.0)
                                .opacity(isPulsing ? 0 : 1),
                        )
                }
            }

            // Label
            if showLabel {
                Text(status.label)
                    .font(.system(size: size.fontSize, weight: .medium))
                    .foregroundColor(status.color)
            }
        }
        .accessibilityLabel("\(status.label)")
        .onAppear {
            if status.shouldPulse {
                startPulsing()
            }
        }
        .onChange(of: status) { _, newStatus in
            if newStatus.shouldPulse {
                startPulsing()
            } else {
                isPulsing = false
            }
        }
    }

    // MARK: - Syncing Indicator

    private var syncingIndicator: some View {
        HStack(spacing: 2) {
            ForEach(0 ..< 3) { index in
                Circle()
                    .fill(status.color)
                    .frame(width: size.dimension / 2, height: size.dimension / 2)
                    .opacity(isPulsing ? 0.3 : 1.0)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isPulsing,
                    )
            }
        }
    }

    // MARK: - Animations

    private func startPulsing() {
        withAnimation(.easeInOut(duration: 1.0).repeatForever()) {
            isPulsing = true
        }
    }
}

// MARK: - Preview

#Preview("Status Types") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        Text("Status Indicators")
            .font(.DesignSystem.headlineMedium)
            .foregroundColor(.DesignSystem.textPrimary)

        Divider()

        // Without labels
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Icon Only")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)

            HStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.xs) {
                    StatusIndicator(status: .online)
                    Text("Online")
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }

                VStack(spacing: Spacing.xs) {
                    StatusIndicator(status: .offline)
                    Text("Offline")
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }

                VStack(spacing: Spacing.xs) {
                    StatusIndicator(status: .syncing)
                    Text("Syncing")
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }

                VStack(spacing: Spacing.xs) {
                    StatusIndicator(status: .error)
                    Text("Error")
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }
            }
        }

        Divider()

        // With labels
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("With Labels")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                StatusIndicator(status: .online, showLabel: true)
                StatusIndicator(status: .offline, showLabel: true)
                StatusIndicator(status: .syncing, showLabel: true)
                StatusIndicator(status: .error, showLabel: true)
            }
        }

        Divider()

        // Size variants
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Sizes")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)

            HStack(spacing: Spacing.lg) {
                VStack(spacing: Spacing.xs) {
                    StatusIndicator(status: .online, size: .small)
                    Text("Small")
                        .font(.system(size: 9))
                        .foregroundColor(.DesignSystem.textTertiary)
                }

                VStack(spacing: Spacing.xs) {
                    StatusIndicator(status: .online, size: .medium)
                    Text("Medium")
                        .font(.system(size: 9))
                        .foregroundColor(.DesignSystem.textTertiary)
                }

                VStack(spacing: Spacing.xs) {
                    StatusIndicator(status: .online, size: .large)
                    Text("Large")
                        .font(.system(size: 9))
                        .foregroundColor(.DesignSystem.textTertiary)
                }
            }
        }

        Divider()

        // In context
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("In Context")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)

            VStack(spacing: 0) {
                HStack {
                    StatusIndicator(status: .online, showLabel: true)
                    Spacer()
                    Text("Connected")
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
                }
                .padding(Spacing.md)
                .background(Color.DesignSystem.glassBackground)

                Divider()

                HStack {
                    StatusIndicator(status: .syncing, showLabel: true)
                    Spacer()
                    Text("Updating preferences...")
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textTertiary)
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

#Preview("Banner Usage") {
    VStack(spacing: Spacing.md) {
        // Offline banner
        HStack(spacing: Spacing.sm) {
            StatusIndicator(status: .offline, size: .medium)

            VStack(alignment: .leading, spacing: 2) {
                Text("You're offline")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text("Changes will sync when you're back online")
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()

            Text("3 pending")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.DesignSystem.textTertiary.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.warning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.DesignSystem.warning.opacity(0.3), lineWidth: 1),
        )

        // Syncing banner
        HStack(spacing: Spacing.sm) {
            StatusIndicator(status: .syncing, size: .medium)

            Text("Syncing preferences...")
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textPrimary)

            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.brandBlue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.DesignSystem.brandBlue.opacity(0.3), lineWidth: 1),
        )

        // Error banner
        HStack(spacing: Spacing.sm) {
            StatusIndicator(status: .error, size: .medium)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sync failed")
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text("Tap to retry")
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.DesignSystem.captionSmall)
                .foregroundColor(.DesignSystem.textTertiary)
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.error.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.DesignSystem.error.opacity(0.3), lineWidth: 1),
        )
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var status: StatusIndicator.Status = .online

        var body: some View {
            VStack(spacing: Spacing.xl) {
                // Current status display
                VStack(spacing: Spacing.md) {
                    StatusIndicator(status: status, size: .large, showLabel: true)

                    Text(statusDescription)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity)
                .background(Color.DesignSystem.glassBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Status controls
                VStack(spacing: Spacing.sm) {
                    Text("Change Status")
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)

                    Button("Online") {
                        withAnimation { status = .online }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.DesignSystem.success)

                    Button("Syncing") {
                        withAnimation { status = .syncing }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.DesignSystem.brandBlue)

                    Button("Offline") {
                        withAnimation { status = .offline }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.DesignSystem.textSecondary)

                    Button("Error") {
                        withAnimation { status = .error }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.DesignSystem.error)
                }
            }
            .padding(Spacing.md)
            .background(Color.DesignSystem.background)
        }

        private var statusDescription: String {
            switch status {
            case .online:
                "All systems operational. Changes sync in real-time."
            case .offline:
                "No internet connection. Changes will sync when you're back online."
            case .syncing:
                "Syncing your preferences to the server."
            case .error:
                "Failed to sync. Please check your connection and try again."
            }
        }
    }

    return InteractivePreview()
}


#endif
