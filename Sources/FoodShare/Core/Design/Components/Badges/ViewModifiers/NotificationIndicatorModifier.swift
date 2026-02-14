//
//  NotificationIndicatorModifier.swift
//  Foodshare
//
//  Liquid Glass v27 - Notification Indicator ViewModifier
//  A composable ViewModifier for adding notification indicators to any view
//
//  Atomic Design: MOLECULE - Composes NotificationDot and NotificationBadge atoms
//  Follows Liquid Glass design system with dynamic materials and spatial depth
//
//  Features:
//  - Flexible positioning (topLeading, topTrailing, bottomLeading, bottomTrailing)
//  - Multiple styles (dot, badge, badgeCompact)
//  - Optional tap handler for notification indicator
//  - 44pt minimum tap target when onTap is provided
//  - "Half out" positioning (offset = radius * 1.5)
//  - Full accessibility support
//  - @MainActor for Swift 6 concurrency safety
//  - Respects Dynamic Type and Reduce Motion
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Notification Indicator Style

/// The visual style of the notification indicator
public enum NotificationIndicatorStyle {
    /// A simple pulsing dot (no count)
    case dot
    /// A numbered badge with regular size
    case badge
    /// A numbered badge with compact size
    case badgeCompact

    var badgeSize: NotificationBadge.BadgeSize? {
        switch self {
        case .dot: nil
        case .badge: .regular
        case .badgeCompact: .compact
        }
    }
}

// MARK: - Notification Indicator Position

/// The position of the notification indicator relative to the parent view
public enum NotificationIndicatorPosition {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var alignment: Alignment {
        switch self {
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }

    /// Calculate offset for "half out" positioning (radius * 1.5)
    func offset(for indicatorSize: CGFloat) -> CGSize {
        let halfOut = (indicatorSize / 2) * 1.5

        switch self {
        case .topLeading:
            return CGSize(width: -halfOut, height: -halfOut)
        case .topTrailing:
            return CGSize(width: halfOut, height: -halfOut)
        case .bottomLeading:
            return CGSize(width: -halfOut, height: halfOut)
        case .bottomTrailing:
            return CGSize(width: halfOut, height: halfOut)
        }
    }
}

// MARK: - Notification Indicator Modifier

/// ViewModifier that adds a notification indicator to any view
@MainActor
struct NotificationIndicatorModifier: ViewModifier {
    let count: Int
    let style: NotificationIndicatorStyle
    let color: Color
    let position: NotificationIndicatorPosition
    let showWhenZero: Bool
    let onTap: (() -> Void)?

    /// Minimum tap target per Apple HIG (44pt)
    private let minTapTarget: CGFloat = 44

    private var hasNotification: Bool {
        count > 0 || showWhenZero
    }

    private var indicatorSize: CGFloat {
        switch style {
        case .dot:
            18
        case .badge:
            20
        case .badgeCompact:
            16
        }
    }

    func body(content: Content) -> some View {
        ZStack(alignment: position.alignment) {
            content

            if hasNotification {
                indicatorView
                    .offset(position.offset(for: indicatorSize))
            }
        }
    }

    // MARK: - Indicator View

    @ViewBuilder
    private var indicatorView: some View {
        if let onTap {
            // Interactive indicator with tap handler
            Button {
                HapticManager.medium()
                onTap()
            } label: {
                indicatorContent
            }
            .buttonStyle(NotificationIndicatorButtonStyle())
            // 44pt minimum tap target for accessibility
            .frame(width: minTapTarget, height: minTapTarget)
            .contentShape(Circle())
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("Double tap to view notifications")
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(count > 0 ? "\(min(count, 999))" : "")
        } else {
            // Non-interactive indicator
            indicatorContent
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var indicatorContent: some View {
        switch style {
        case .dot:
            NotificationDot(
                isActive: count > 0,
                size: indicatorSize,
                activeColor: color,
            )

        case .badge, .badgeCompact:
            if let badgeSize = style.badgeSize {
                NotificationBadge(
                    count: count,
                    size: badgeSize,
                    color: color,
                    showWhenZero: showWhenZero,
                )
            }
        }
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch count {
        case 0:
            "Notifications"
        case 1:
            "1 notification"
        case ...99:
            "\(count) notifications"
        default:
            "99 plus notifications"
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds a notification indicator to this view
    ///
    /// - Parameters:
    ///   - count: The number of notifications to display
    ///   - style: The visual style of the indicator (default: .dot)
    ///   - color: The color of the indicator (default: brandPink)
    ///   - position: The position of the indicator (default: .topTrailing)
    ///   - showWhenZero: Whether to show the indicator when count is 0 (default: false)
    ///   - onTap: Optional tap handler for the notification indicator
    ///
    /// Usage:
    /// ```swift
    /// Image(systemName: "bell.fill")
    ///     .notificationIndicator(count: 5)
    ///
    /// ProfileButton()
    ///     .notificationIndicator(
    ///         count: unreadCount,
    ///         style: .badge,
    ///         color: .DesignSystem.error,
    ///         position: .topTrailing,
    ///         onTap: { showNotifications = true }
    ///     )
    /// ```
    public func notificationIndicator(
        count: Int,
        style: NotificationIndicatorStyle = .dot,
        color: Color? = nil,
        position: NotificationIndicatorPosition = .topTrailing,
        showWhenZero: Bool = false,
        onTap: (() -> Void)? = nil,
    ) -> some View {
        modifier(
            NotificationIndicatorModifier(
                count: count,
                style: style,
                color: color ?? .DesignSystem.brandPink,
                position: position,
                showWhenZero: showWhenZero,
                onTap: onTap,
            ),
        )
    }
}

// MARK: - Notification Indicator Button Style

/// Custom button style with pressed state feedback for the notification indicator
private struct NotificationIndicatorButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Notification Indicator Modifier") {
    struct PreviewWrapper: View {
        @State private var count = 5
        @State private var showNotifications = false

        var body: some View {
            ScrollView {
                VStack(spacing: Spacing.xxl) {
                    Text("Notification Indicator Modifier")
                        .font(.DesignSystem.displayMedium)
                        .foregroundStyle(Color.DesignSystem.textPrimary)

                    // Dot style variants
                    VStack(spacing: Spacing.lg) {
                        Text("Dot Style")
                            .font(.DesignSystem.headlineSmall)
                            .foregroundStyle(Color.DesignSystem.textPrimary)

                        HStack(spacing: Spacing.xxl) {
                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 1,
                                        style: .dot,
                                        position: .topTrailing,
                                    )
                                Text("Top Trailing")
                                    .font(.DesignSystem.caption)
                            }

                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 1,
                                        style: .dot,
                                        position: .topLeading,
                                    )
                                Text("Top Leading")
                                    .font(.DesignSystem.caption)
                            }

                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 0,
                                        style: .dot,
                                        position: .topTrailing,
                                    )
                                Text("No Count")
                                    .font(.DesignSystem.caption)
                            }
                        }
                    }

                    Divider()
                        .padding(.horizontal, Spacing.xl)

                    // Badge style variants
                    VStack(spacing: Spacing.lg) {
                        Text("Badge Style")
                            .font(.DesignSystem.headlineSmall)
                            .foregroundStyle(Color.DesignSystem.textPrimary)

                        HStack(spacing: Spacing.xxl) {
                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 3,
                                        style: .badge,
                                        position: .topTrailing,
                                    )
                                Text("Regular")
                                    .font(.DesignSystem.caption)
                            }

                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 12,
                                        style: .badgeCompact,
                                        position: .topTrailing,
                                    )
                                Text("Compact")
                                    .font(.DesignSystem.caption)
                            }

                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 150,
                                        style: .badge,
                                        position: .topTrailing,
                                    )
                                Text("99+")
                                    .font(.DesignSystem.caption)
                            }
                        }
                    }

                    Divider()
                        .padding(.horizontal, Spacing.xl)

                    // Position variants
                    VStack(spacing: Spacing.lg) {
                        Text("Positions")
                            .font(.DesignSystem.headlineSmall)
                            .foregroundStyle(Color.DesignSystem.textPrimary)

                        HStack(spacing: Spacing.xxl) {
                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 5,
                                        style: .badge,
                                        position: .topLeading,
                                    )
                                Text("Top Leading")
                                    .font(.DesignSystem.caption)
                            }

                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 5,
                                        style: .badge,
                                        position: .bottomLeading,
                                    )
                                Text("Bottom Leading")
                                    .font(.DesignSystem.caption)
                            }

                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 5,
                                        style: .badge,
                                        position: .bottomTrailing,
                                    )
                                Text("Bottom Trailing")
                                    .font(.DesignSystem.caption)
                            }
                        }
                    }

                    Divider()
                        .padding(.horizontal, Spacing.xl)

                    // Color variants
                    VStack(spacing: Spacing.lg) {
                        Text("Colors")
                            .font(.DesignSystem.headlineSmall)
                            .foregroundStyle(Color.DesignSystem.textPrimary)

                        HStack(spacing: Spacing.xxl) {
                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 3,
                                        style: .badge,
                                        color: .DesignSystem.brandPink,
                                    )
                                Text("Pink")
                                    .font(.DesignSystem.caption)
                            }

                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 3,
                                        style: .badge,
                                        color: .DesignSystem.brandGreen,
                                    )
                                Text("Green")
                                    .font(.DesignSystem.caption)
                            }

                            VStack(spacing: Spacing.md) {
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .frame(width: 56, height: 56)
                                    .notificationIndicator(
                                        count: 3,
                                        style: .badge,
                                        color: .DesignSystem.error,
                                    )
                                Text("Error")
                                    .font(.DesignSystem.caption)
                            }
                        }
                    }

                    Divider()
                        .padding(.horizontal, Spacing.xl)

                    // Interactive demo with tap handler
                    VStack(spacing: Spacing.lg) {
                        Text("Interactive")
                            .font(.DesignSystem.headlineSmall)
                            .foregroundStyle(Color.DesignSystem.textPrimary)

                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Image(systemName: "bell.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.DesignSystem.brandGreen),
                            )
                            .frame(width: 56, height: 56)
                            .notificationIndicator(
                                count: count,
                                style: .badge,
                                onTap: {
                                    showNotifications = true
                                },
                            )

                        HStack(spacing: Spacing.md) {
                            Button("Add") {
                                count += 1
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Reset") {
                                count = 0
                            }
                            .buttonStyle(.bordered)

                            Button("99+") {
                                count = 150
                            }
                            .buttonStyle(.bordered)
                        }

                        Text("Count: \(count)")
                            .font(.DesignSystem.bodySmall)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }
                .padding()
            }
            .background(Color.DesignSystem.background)
            .alert("Notifications", isPresented: $showNotifications) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You have \(count) notification\(count == 1 ? "" : "s")")
            }
        }
    }

    return PreviewWrapper()
}
