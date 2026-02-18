// MARK: - OfflineBanner.swift
// Organism Component: Offline Mode Indicator with Pending Changes
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade


#if !SKIP
import SwiftUI

/// A banner showing offline status and pending changes.
///
/// This organism component provides:
/// - Offline/syncing/error status display
/// - Pending changes count
/// - Retry functionality
/// - Animated transitions
/// - Dismissible when appropriate
///
/// ## Usage
/// ```swift
/// OfflineBanner(
///     isOffline: viewModel.isOffline,
///     pendingChanges: viewModel.pendingOfflineChangesCount,
///     onRetry: { await viewModel.refreshPreferences() }
/// )
/// ```
public struct OfflineBanner: View {
    // MARK: - Banner Type

    public enum BannerType {
        case offline(pendingChanges: Int)
        case syncing
        case error(message: String)
        case success(message: String)

        var icon: String {
            switch self {
            case .offline:
                "wifi.slash"
            case .syncing:
                "arrow.triangle.2.circlepath"
            case .error:
                "exclamationmark.triangle.fill"
            case .success:
                "checkmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .offline:
                .DesignSystem.warning
            case .syncing:
                .DesignSystem.brandBlue
            case .error:
                .DesignSystem.error
            case .success:
                .DesignSystem.success
            }
        }

        var backgroundColor: Color {
            color.opacity(0.1)
        }

        var borderColor: Color {
            color.opacity(0.3)
        }
    }

    // MARK: - Properties

    private let type: BannerType
    private let onRetry: (() async -> Void)?
    private let onDismiss: (() -> Void)?

    // MARK: - State

    @State private var isRetrying = false
    @State private var isVisible = true

    // MARK: - Initialization

    /// Creates a new offline banner.
    ///
    /// - Parameters:
    ///   - type: The banner type
    ///   - onRetry: Optional async handler for retry action
    ///   - onDismiss: Optional handler for dismissing the banner
    public init(
        type: BannerType,
        onRetry: (() async -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
    ) {
        self.type = type
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    /// Convenience initializer for offline state.
    public init(
        isOffline: Bool,
        pendingChanges: Int = 0,
        onRetry: (() async -> Void)? = nil,
    ) {
        if isOffline {
            self.type = .offline(pendingChanges: pendingChanges)
        } else {
            self.type = .success(message: "Back online")
        }
        self.onRetry = onRetry
        self.onDismiss = nil
    }

    // MARK: - Body

    public var body: some View {
        if isVisible {
            banner
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity),
                ))
        }
    }

    private var banner: some View {
        HStack(spacing: Spacing.sm) {
            // Status indicator
            StatusIndicator(
                status: statusIndicatorType,
                size: .medium,
            )

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
            }

            Spacer()

            // Action button
            actionView

            // Dismiss button
            if let dismiss = onDismiss {
                Button {
                    withAnimation {
                        isVisible = false
                    }
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.DesignSystem.textTertiary)
                }
            }
        }
        .padding(Spacing.md)
        .background(type.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(type.borderColor, lineWidth: 1),
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    // MARK: - Helpers

    private var statusIndicatorType: StatusIndicator.Status {
        switch type {
        case .offline:
            .offline
        case .syncing:
            .syncing
        case .error:
            .error
        case .success:
            .online
        }
    }

    private var title: String {
        switch type {
        case .offline:
            "You're offline"
        case .syncing:
            "Syncing..."
        case .error:
            "Sync failed"
        case let .success(message):
            message
        }
    }

    private var subtitle: String? {
        switch type {
        case let .offline(pendingChanges):
            if pendingChanges > 0 {
                return "\(pendingChanges) change\(pendingChanges == 1 ? "" : "s") will sync when you're back online"
            }
            return "Changes will sync when you're back online"
        case .syncing:
            return "Updating your preferences"
        case let .error(message):
            return message
        case .success:
            return "All changes synced"
        }
    }

    @ViewBuilder
    private var actionView: some View {
        switch type {
        case .offline:
            if let retry = onRetry {
                Button {
                    Task {
                        isRetrying = true
                        HapticFeedback.light()
                        await retry()
                        isRetrying = false
                    }
                } label: {
                    if isRetrying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: type.color))
                            .scaleEffect(0.7)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry")
                        }
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(type.color)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .background(type.color.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            } else {
                EmptyView()
            }

        case .error:
            if let retry = onRetry {
                Button {
                    Task {
                        isRetrying = true
                        HapticFeedback.light()
                        await retry()
                        isRetrying = false
                    }
                } label: {
                    Text("Retry")
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(type.color)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 6)
                        .background(type.color.opacity(0.15))
                        .clipShape(Capsule())
                }
            } else {
                EmptyView()
            }

        case let .offline(pendingChanges):
            if pendingChanges > 0 {
                Text("\(pendingChanges)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(minWidth: 20, minHeight: 20)
                    .padding(.horizontal, 4)
                    .background(type.color)
                    .clipShape(Circle())
            } else {
                EmptyView()
            }

        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview("Banner Types") {
    VStack(spacing: Spacing.md) {
        // Offline with pending changes
        OfflineBanner(
            type: .offline(pendingChanges: 3),
            onRetry: {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            },
        )

        // Offline without pending changes
        OfflineBanner(
            type: .offline(pendingChanges: 0),
            onRetry: {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            },
        )

        // Syncing
        OfflineBanner(type: .syncing)

        // Error
        OfflineBanner(
            type: .error(message: "Network timeout. Please check your connection."),
            onRetry: {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            },
        )

        // Success
        OfflineBanner(
            type: .success(message: "All changes synced"),
            onDismiss: {
                print("Dismissed")
            },
        )
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("Convenience Initializer") {
    VStack(spacing: Spacing.md) {
        // Offline
        OfflineBanner(
            isOffline: true,
            pendingChanges: 5,
            onRetry: {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            },
        )

        // Online
        OfflineBanner(
            isOffline: false,
            pendingChanges: 0,
        )
    }
    .padding(Spacing.md)
    .background(Color.DesignSystem.background)
}

#Preview("Interactive") {
    struct InteractivePreview: View {
        @State private var isOffline = true
        @State private var pendingChanges = 3

        var body: some View {
            VStack(spacing: Spacing.lg) {
                OfflineBanner(
                    isOffline: isOffline,
                    pendingChanges: pendingChanges,
                    onRetry: {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        isOffline = false
                        pendingChanges = 0
                    },
                )

                // Controls
                VStack(spacing: Spacing.sm) {
                    Toggle("Offline", isOn: $isOffline)
                    Stepper("Pending: \(pendingChanges)", value: $pendingChanges, in: 0 ... 10)
                }
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

#Preview("In Context") {
    ScrollView {
        VStack(spacing: Spacing.md) {
            // Offline banner at top
            OfflineBanner(
                type: .offline(pendingChanges: 2),
                onRetry: {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                },
            )

            // Content below
            VStack(spacing: Spacing.sm) {
                ForEach(0 ..< 3) { index in
                    HStack {
                        Text("Notification \(index + 1)")
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.textPrimary)

                        Spacer()

                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                            .disabled(true)
                    }
                    .padding(Spacing.md)
                    .background(Color.DesignSystem.glassBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
}

#endif
