//
//  NotificationRowCompact.swift
//  Foodshare
//
//  Compact notification row for the dropdown panel
//  Liquid Glass v27 design with swipe actions
//



#if !SKIP
import SwiftUI

// MARK: - Notification Row Compact

/// A compact notification row designed for the dropdown panel
///
/// Features:
/// - Icon with type-based color
/// - Title and time ago
/// - Unread indicator dot
/// - Swipe actions for mark read and delete
struct NotificationRowCompact: View {
    let notification: UserNotification
    let onTap: () -> Void
    let onMarkRead: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion: Bool

    // MARK: - Constants

    private let swipeThreshold: CGFloat = 60
    private let maxSwipe: CGFloat = 120

    init(
        notification: UserNotification,
        onTap: @escaping () -> Void,
        onMarkRead: @escaping () -> Void,
        onDelete: @escaping () -> Void,
    ) {
        self.notification = notification
        self.onTap = onTap
        self.onMarkRead = onMarkRead
        self.onDelete = onDelete
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Swipe actions background
            swipeActionsBackground

            // Main row content
            rowContent
                .offset(x: offset)
                .gesture(swipeGesture)
        }
        .frame(height: 64.0)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }

    // MARK: - Row Content

    private var rowContent: some View {
        Button(action: handleTap) {
            HStack(spacing: Spacing.sm) {
                // Icon
                iconView

                // Content
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    HStack {
                        Text(notification.title)
                            .font(.DesignSystem.labelMedium)
                            .fontWeight(notification.isRead ? .regular : .semibold)
                            .foregroundStyle(Color.DesignSystem.textPrimary)
                            .lineLimit(1)

                        Spacer()

                        Text(notification.timeAgo)
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.textTertiary)
                    }

                    if let body = notification.body, !body.isEmpty {
                        Text(body)
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .lineLimit(1)
                    }
                }

                // Unread indicator
                if !notification.isRead {
                    unreadIndicator
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.interpolatingSpring(stiffness: 400, damping: 25), value: isPressed)
    }

    // MARK: - Icon View

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 36.0, height: 36)

            Image(systemName: notification.type.icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(iconColor)
        }
    }

    private var iconColor: Color {
        switch notification.type.color {
        case "brandGreen": .DesignSystem.brandGreen
        case "brandBlue": .DesignSystem.brandBlue
        case "error": .DesignSystem.error
        case "purple": .purple
        case "orange": .orange
        case "yellow": .yellow
        case "teal": .teal
        default: .DesignSystem.textSecondary
        }
    }

    // MARK: - Unread Indicator

    private var unreadIndicator: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .frame(width: 8.0, height: 8)
            .shadow(color: .DesignSystem.brandGreen.opacity(0.5), radius: 2)
    }

    // MARK: - Row Background

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: CornerRadius.medium)
            .fill(
                notification.isRead
                    ? Color.DesignSystem.glassBackground.opacity(0.5)
                    : Color.DesignSystem.glassBackground,
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .stroke(
                        notification.isRead
                            ? Color.DesignSystem.glassBorder.opacity(0.3)
                            : Color.DesignSystem.brandGreen.opacity(0.2),
                        lineWidth: 0.5,
                    ),
            )
    }

    // MARK: - Swipe Actions Background

    private var swipeActionsBackground: some View {
        HStack(spacing: 0) {
            Spacer()

            // Mark as read action
            if !notification.isRead {
                swipeActionButton(
                    icon: "checkmark.circle.fill",
                    color: .DesignSystem.brandGreen,
                    action: onMarkRead,
                )
            }

            // Delete action
            swipeActionButton(
                icon: "trash.fill",
                color: .DesignSystem.error,
                action: onDelete,
            )
        }
        .frame(width: maxSwipe)
    }

    private func swipeActionButton(
        icon: String,
        color: Color,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: {
            resetSwipe()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 50.0, height: 64)
                .background(color)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let translation = value.translation.width
                // Only allow left swipe
                if translation < 0 {
                    offset = max(-maxSwipe, translation)
                }
            }
            .onEnded { value in
                let translation = value.translation.width
                let velocity = value.predictedEndTranslation.width

                withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
                    if translation < -swipeThreshold || velocity < -500 {
                        offset = -maxSwipe
                    } else {
                        offset = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func handleTap() {
        HapticManager.light()

        withAnimation(.interpolatingSpring(stiffness: 400, damping: 25)) {
            isPressed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.interpolatingSpring(stiffness: 400, damping: 25)) {
                isPressed = false
            }
            onTap()
        }
    }

    private func resetSwipe() {
        withAnimation(.interpolatingSpring(stiffness: 300, damping: 25)) {
            offset = 0
        }
    }
}

// MARK: - Preview

#Preview("Notification Row Compact") {
    VStack(spacing: Spacing.sm) {
        NotificationRowCompact(
            notification: .fixture(
                type: NotificationType.newMessage,
                title: "New message from Sarah",
                body: "Is the pasta still available?",
                isRead: false,
            ),
            onTap: {},
            onMarkRead: {},
            onDelete: {},
        )

        NotificationRowCompact(
            notification: .fixture(
                type: NotificationType.arrangementConfirmed,
                title: "Pickup confirmed!",
                body: "Your request has been confirmed",
                isRead: true,
            ),
            onTap: {},
            onMarkRead: {},
            onDelete: {},
        )

        NotificationRowCompact(
            notification: .fixture(
                type: NotificationType.newListingNearby,
                title: "New food nearby!",
                body: "Fresh vegetables 0.3 miles away",
                isRead: false,
            ),
            onTap: {},
            onMarkRead: {},
            onDelete: {},
        )

        NotificationRowCompact(
            notification: .fixture(
                type: NotificationType.challengeCompleted,
                title: "Challenge Complete!",
                isRead: false,
            ),
            onTap: {},
            onMarkRead: {},
            onDelete: {},
        )
    }
    .padding()
    .background(Color.DesignSystem.background)
}


#endif
