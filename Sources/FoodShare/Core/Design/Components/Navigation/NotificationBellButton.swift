//
//  NotificationBellButton.swift
//  Foodshare
//
//  Liquid Glass v27 - Enterprise Notification Bell Button
//  Animated bell with shake, pulsing ring, badge counter, and full accessibility
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Notification Bell Button

/// An enterprise-grade animated notification bell button
///
/// Features:
/// - Shake animation on new notification with haptic feedback
/// - Pulsing ring behind when unread > 0
/// - Animated badge counter using GlassNumberCounter
/// - Full VoiceOver accessibility with dynamic announcements
/// - 120Hz ProMotion optimized animations
/// - Press scale feedback
/// - Customizable size variants
///
/// Example usage:
/// ```swift
/// NotificationBellButton(
///     unreadCount: viewModel.unreadCount,
///     hasNewNotification: viewModel.hasNewNotification,
///     action: { viewModel.toggleDropdown() }
/// )
/// ```
struct NotificationBellButton: View {
    let unreadCount: Int
    let hasNewNotification: Bool
    let size: BellSize
    let action: () -> Void

    @State private var shakeRotation: Double = 0
    @State private var isPressed = false
    @State private var bellScale: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    // MARK: - Size Variant

    enum BellSize {
        case compact // 32pt - for dense toolbars
        case regular // 44pt - default
        case large // 56pt - for prominent placement

        var iconSize: CGFloat {
            switch self {
            case .compact: 18
            case .regular: 22
            case .large: 28
            }
        }

        var frameSize: CGFloat {
            switch self {
            case .compact: 32
            case .regular: 44
            case .large: 56
            }
        }

        var badgeSize: CGFloat {
            switch self {
            case .compact: 14
            case .regular: 18
            case .large: 22
            }
        }

        var badgeOffset: CGPoint {
            switch self {
            case .compact: CGPoint(x: 8, y: -6)
            case .regular: CGPoint(x: 10, y: -8)
            case .large: CGPoint(x: 14, y: -10)
            }
        }
    }

    init(
        unreadCount: Int,
        hasNewNotification: Bool = false,
        size: BellSize = .regular,
        action: @escaping () -> Void,
    ) {
        self.unreadCount = unreadCount
        self.hasNewNotification = hasNewNotification
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: handleTap) {
            ZStack {
                // Pulsing ring behind bell (only when unread > 0)
                if unreadCount > 0, !reduceMotion {
                    GlowPulseEffect(
                        isActive: true,
                        color: .DesignSystem.brandGreen,
                        size: size.frameSize,
                    )
                }

                // Bell icon with shake animation
                bellIcon
                    .rotationEffect(.degrees(shakeRotation), anchor: .top)
                    .scaleEffect(bellScale)

                // Badge (only when unread > 0)
                if unreadCount > 0 {
                    badgeView
                        .offset(x: size.badgeOffset.x, y: size.badgeOffset.y)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: size.frameSize, height: size.frameSize)
            .contentShape(Rectangle())
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(unreadCount > 0 ? "\(unreadCount)" : "")
        .onChange(of: hasNewNotification) { _, newValue in
            if newValue, !reduceMotion {
                triggerShakeAnimation()
            }
        }
        .onChange(of: unreadCount) { oldValue, newValue in
            // Animate badge appearance/disappearance
            if (oldValue == 0 && newValue > 0) || (oldValue > 0 && newValue == 0) {
                withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
                    bellScale = 1.1
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(150))
                    withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
                        bellScale = 1.0
                    }
                }
            }
        }
    }

    // MARK: - Bell Icon

    private var bellIcon: some View {
        Image(systemName: unreadCount > 0 ? "bell.badge.fill" : "bell.fill")
            .font(.system(size: size.iconSize, weight: .medium))
            .foregroundStyle(
                unreadCount > 0
                    ? Color.DesignSystem.brandGreen
                    : Color.DesignSystem.textSecondary,
            )
            .symbolRenderingMode(.hierarchical)
    }

    // MARK: - Badge View

    private var badgeView: some View {
        NotificationBadge(
            count: unreadCount,
            size: badgeSize,
            color: .DesignSystem.brandPink,
        )
    }

    private var badgeSize: NotificationBadge.BadgeSize {
        switch size {
        case .compact: .compact
        case .regular: .regular
        case .large: .large
        }
    }

    // MARK: - Actions

    private func handleTap() {
        guard isEnabled else { return }

        HapticManager.light()

        // Press animation
        withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
            isPressed = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
                isPressed = false
            }
            action()
        }
    }

    private func triggerShakeAnimation() {
        // Enhanced bell shake animation sequence
        let shakeSequence: [(Double, Int)] = [
            (18, 40), // Quick initial swing
            (-15, 40),
            (12, 40),
            (-10, 40),
            (8, 50),
            (-6, 50),
            (4, 50),
            (-2, 60),
            (0, 100), // Settle
        ]

        Task { @MainActor in
            for (rotation, durationMs) in shakeSequence {
                withAnimation(.interpolatingSpring(stiffness: 500, damping: 8)) {
                    shakeRotation = rotation
                }
                try? await Task.sleep(for: .milliseconds(durationMs))
            }
        }

        // Scale bounce during shake
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
            bellScale = 1.15
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.interpolatingSpring(stiffness: 300, damping: 15)) {
                bellScale = 1.0
            }
        }

        HapticManager.warning()
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        switch unreadCount {
        case 0:
            "Notifications"
        case 1:
            "Notifications, 1 unread"
        default:
            "Notifications, \(unreadCount) unread"
        }
    }

    private var accessibilityHint: String {
        if unreadCount > 0 {
            "Double tap to view \(unreadCount) unread notification\(unreadCount == 1 ? "" : "s")"
        } else {
            "Double tap to view notifications"
        }
    }
}

// MARK: - Compact Bell Icon (for inline usage)

/// A minimal bell icon variant for use in toolbars and lists
struct NotificationBellIcon: View {
    let unreadCount: Int
    let size: CGFloat

    init(unreadCount: Int, size: CGFloat = 18) {
        self.unreadCount = unreadCount
        self.size = size
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell.fill")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(
                    unreadCount > 0
                        ? Color.DesignSystem.brandGreen
                        : Color.DesignSystem.textSecondary,
                )

            if unreadCount > 0 {
                Circle()
                    .fill(Color.DesignSystem.brandPink)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: -2)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unreadCount > 0 ? "\(unreadCount) notifications" : "No notifications")
    }
}

// MARK: - Preview

#Preview("Notification Bell Button") {
    struct PreviewWrapper: View {
        @State private var unreadCount = 5
        @State private var hasNew = false

        var body: some View {
            VStack(spacing: Spacing.xxl) {
                Text("Notification Bell Button")
                    .font(.DesignSystem.displayMedium)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                // Size variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        NotificationBellButton(
                            unreadCount: 3,
                            size: .compact,
                            action: {},
                        )
                        Text("Compact")
                            .font(.DesignSystem.caption)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBellButton(
                            unreadCount: 3,
                            size: .regular,
                            action: {},
                        )
                        Text("Regular")
                            .font(.DesignSystem.caption)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBellButton(
                            unreadCount: 3,
                            size: .large,
                            action: {},
                        )
                        Text("Large")
                            .font(.DesignSystem.caption)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Count variants
                HStack(spacing: Spacing.xxl) {
                    VStack(spacing: Spacing.md) {
                        NotificationBellButton(unreadCount: 0, action: {})
                        Text("Empty")
                            .font(.DesignSystem.caption)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBellButton(unreadCount: 1, action: {})
                        Text("1")
                            .font(.DesignSystem.caption)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBellButton(unreadCount: 9, action: {})
                        Text("9")
                            .font(.DesignSystem.caption)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBellButton(unreadCount: 99, action: {})
                        Text("99")
                            .font(.DesignSystem.caption)
                    }

                    VStack(spacing: Spacing.md) {
                        NotificationBellButton(unreadCount: 150, action: {})
                        Text("99+")
                            .font(.DesignSystem.caption)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Interactive demo
                VStack(spacing: Spacing.md) {
                    NotificationBellButton(
                        unreadCount: unreadCount,
                        hasNewNotification: hasNew,
                        action: {},
                    )

                    HStack(spacing: Spacing.md) {
                        Button("Add") {
                            unreadCount += 1
                            hasNew = true
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(600))
                                hasNew = false
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Clear") {
                            unreadCount = 0
                        }
                        .buttonStyle(.bordered)

                        Button("Shake") {
                            hasNew = true
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(600))
                                hasNew = false
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Divider()
                    .padding(.horizontal, Spacing.xl)

                // Compact icon variants
                HStack(spacing: Spacing.lg) {
                    VStack(spacing: Spacing.sm) {
                        NotificationBellIcon(unreadCount: 0)
                        Text("Icon Empty")
                            .font(.DesignSystem.caption)
                    }

                    VStack(spacing: Spacing.sm) {
                        NotificationBellIcon(unreadCount: 5)
                        Text("Icon Badge")
                            .font(.DesignSystem.caption)
                    }
                }
            }
            .padding()
            .background(Color.DesignSystem.background)
        }
    }

    return PreviewWrapper()
}
