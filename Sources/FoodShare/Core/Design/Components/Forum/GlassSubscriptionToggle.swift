//
//  GlassSubscriptionToggle.swift
//  Foodshare
//
//  Glass subscription toggle and notification bell components
//  Follows Liquid Glass Design System v26
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Glass Subscription Toggle

/// Bell icon toggle for subscribing/unsubscribing to forum content
/// Features animated fill state and notification count badge
struct GlassSubscriptionToggle: View {
    @Binding var isSubscribed: Bool
    let notificationCount: Int
    let isLoading: Bool
    let onToggle: () -> Void

    @State private var isAnimating = false

    init(
        isSubscribed: Binding<Bool>,
        notificationCount: Int = 0,
        isLoading: Bool = false,
        onToggle: @escaping () -> Void,
    ) {
        _isSubscribed = isSubscribed
        self.notificationCount = notificationCount
        self.isLoading = isLoading
        self.onToggle = onToggle
    }

    var body: some View {
        Button(action: handleTap) {
            ZStack(alignment: .topTrailing) {
                // Bell icon with animated state
                bellIcon
                    .frame(width: 44, height: 44)
                    .background(backgroundColor)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(borderColor, lineWidth: 1),
                    )
                    .shadow(color: shadowColor, radius: Spacing.shadowSM, y: 1)

                // Notification badge
                if notificationCount > 0, isSubscribed {
                    notificationBadge
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.92, haptic: .light))
        .disabled(isLoading)
    }

    @ViewBuilder
    private var bellIcon: some View {
        if isLoading {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.DesignSystem.primary))
                .scaleEffect(0.7)
        } else {
            Image(systemName: isSubscribed ? "bell.fill" : "bell")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isSubscribed ? Color.DesignSystem.primary : Color.DesignSystem.textSecondary)
                .symbolEffect(.bounce, value: isAnimating)
        }
    }

    private var notificationBadge: some View {
        Text(notificationCount > 99 ? "99+" : "\(notificationCount)")
            .font(.DesignSystem.captionSmall)
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.DesignSystem.error),
            )
            .transition(.scale.combined(with: .opacity))
    }

    private var backgroundColor: Color {
        isSubscribed
            ? Color.DesignSystem.primary.opacity(0.12)
            : Color.DesignSystem.glassBackground
    }

    private var borderColor: Color {
        isSubscribed
            ? Color.DesignSystem.primary.opacity(0.3)
            : Color.DesignSystem.glassBorder
    }

    private var shadowColor: Color {
        isSubscribed
            ? Color.DesignSystem.primary.opacity(0.15)
            : Color.black.opacity(0.08)
    }

    private func handleTap() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isAnimating.toggle()
        }
        HapticManager.light()
        onToggle()
    }
}

// MARK: - Glass Subscription Card

/// Full subscription settings card with preference toggles
struct GlassSubscriptionCard: View {
    @Environment(\.translationService) private var t
    let subscription: ForumSubscription?
    @Binding var preferences: SubscriptionPreferences
    let onSave: () -> Void
    let onUnsubscribe: () -> Void

    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header
            HStack {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.DesignSystem.primary)

                Text(t.t("notifications.preferences"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                if subscription != nil {
                    Button(t.t("common.edit")) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isEditing.toggle()
                        }
                    }
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.primary)
                }
            }

            if isEditing || subscription == nil {
                // Preference toggles
                VStack(spacing: Spacing.sm) {
                    preferenceToggle(
                        icon: "arrowshape.turn.up.left.fill",
                        title: "Replies",
                        subtitle: "Get notified when someone replies",
                        isOn: $preferences.notifyOnReply,
                    )

                    preferenceToggle(
                        icon: "at",
                        title: "Mentions",
                        subtitle: "Get notified when you're mentioned",
                        isOn: $preferences.notifyOnMention,
                    )

                    preferenceToggle(
                        icon: "face.smiling.fill",
                        title: "Reactions",
                        subtitle: "Get notified when someone reacts",
                        isOn: $preferences.notifyOnReaction,
                    )

                    Divider()
                        .background(Color.DesignSystem.glassBorder)

                    preferenceToggle(
                        icon: "envelope.fill",
                        title: "Email Notifications",
                        subtitle: "Also send notifications via email",
                        isOn: $preferences.emailNotifications,
                    )
                }
                .padding(.top, Spacing.xs)

                // Action buttons
                HStack(spacing: Spacing.sm) {
                    if subscription != nil {
                        Button(action: onUnsubscribe) {
                            Text(t.t("common.unsubscribe"))
                                .font(.DesignSystem.labelMedium)
                                .foregroundStyle(Color.DesignSystem.error)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.DesignSystem.error.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSM))
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.97, haptic: .medium))
                    }

                    Button(action: {
                        onSave()
                        withAnimation {
                            isEditing = false
                        }
                    }) {
                        Text(subscription == nil ? "Subscribe" : "Save")
                            .font(.DesignSystem.labelMedium)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.DesignSystem.primary)
                            .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusSM))
                    }
                    .buttonStyle(ScaleButtonStyle(scale: 0.97, haptic: .light))
                }
                .padding(.top, Spacing.sm)
            } else {
                // Collapsed view showing active preferences
                activePreferencesView
            }
        }
        .padding(Spacing.md)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.radiusMD)
                .strokeBorder(Color.DesignSystem.glassBorder, lineWidth: 1),
        )
    }

    private func preferenceToggle(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(Color.DesignSystem.primary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(subtitle)
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.DesignSystem.primary)
        }
        .padding(.vertical, Spacing.xs)
    }

    @ViewBuilder
    private var activePreferencesView: some View {
        if let sub = subscription {
            HStack(spacing: Spacing.sm) {
                ForEach(sub.activeNotificationTypes, id: \.self) { pref in
                    HStack(spacing: 4) {
                        Image(systemName: pref.icon)
                            .font(.system(size: 12))
                        Text(pref.displayName)
                            .font(.DesignSystem.captionSmall)
                    }
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.DesignSystem.surface)
                    .clipShape(Capsule())
                }

                if sub.emailNotifications {
                    HStack(spacing: 4) {
                        Image(systemName: "envelope.fill")
                            .font(.system(size: 12))
                        Text(t.t("common.email"))
                            .font(.DesignSystem.captionSmall)
                    }
                    .foregroundStyle(Color.DesignSystem.primary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(Color.DesignSystem.primary.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
    }
}

// MARK: - Glass Notification Row

/// Single notification item for the notifications list
struct GlassNotificationRow: View {
    @Environment(\.translationService) private var t
    let notification: ForumNotification
    let onTap: () -> Void
    let onMarkRead: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                // Type icon
                notificationIcon
                    .frame(width: 40, height: 40)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.displayMessage)
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: Spacing.xs) {
                        Text(notification.timeAgo)
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.textTertiary)

                        if notification.isRecent {
                            Text(t.t("common.new"))
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.DesignSystem.primary)
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(Color.DesignSystem.primary)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(Spacing.sm)
            .background(
                notification.isRead
                    ? Color.clear
                    : Color.DesignSystem.primary.opacity(0.05),
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            if !notification.isRead {
                Button {
                    HapticManager.light()
                    onMarkRead()
                } label: {
                    Label(t.t("common.read"), systemImage: "checkmark.circle")
                }
                .tint(Color.DesignSystem.primary)
            }
        }
    }

    private var notificationIcon: some View {
        ZStack {
            Circle()
                .fill(notification.type.color.opacity(0.15))

            Image(systemName: notification.type.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(notification.type.color)
        }
    }
}

// MARK: - Glass Notification Header

/// Header for notifications section with count and mark all read
struct GlassNotificationHeader: View {
    @Environment(\.translationService) private var t
    let unreadCount: Int
    let onMarkAllRead: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.DesignSystem.primary)

                Text(t.t("common.notifications"))
                    .font(.DesignSystem.headlineMedium)
                    .foregroundStyle(Color.DesignSystem.text)

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.DesignSystem.captionSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(Color.DesignSystem.error)
                        .clipShape(Capsule())
                }
            }

            Spacer()

            HStack(spacing: Spacing.sm) {
                if unreadCount > 0 {
                    Button(action: onMarkAllRead) {
                        Text(t.t("notifications.mark_all_read"))
                            .font(.DesignSystem.labelSmall)
                            .foregroundStyle(Color.DesignSystem.primary)
                    }
                }

                Button(action: onSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Empty Notifications View

/// Placeholder when no notifications exist
struct GlassEmptyNotificationsView: View {
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.DesignSystem.textTertiary)

            Text(t.t("notifications.empty"))
                .font(.DesignSystem.headlineSmall)
                .foregroundStyle(Color.DesignSystem.text)

            Text("When you subscribe to posts or categories, notifications will appear here.")
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, Spacing.xxl)
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Subscription Toggle") {
    VStack(spacing: Spacing.lg) {
        HStack(spacing: Spacing.md) {
            GlassSubscriptionToggle(
                isSubscribed: .constant(false),
                onToggle: {},
            )

            GlassSubscriptionToggle(
                isSubscribed: .constant(true),
                notificationCount: 5,
                onToggle: {},
            )

            GlassSubscriptionToggle(
                isSubscribed: .constant(true),
                notificationCount: 128,
                onToggle: {},
            )

            GlassSubscriptionToggle(
                isSubscribed: .constant(false),
                isLoading: true,
                onToggle: {},
            )
        }
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#Preview("Subscription Card") {
    VStack(spacing: Spacing.md) {
        GlassSubscriptionCard(
            subscription: nil,
            preferences: .constant(SubscriptionPreferences()),
            onSave: {},
            onUnsubscribe: {},
        )

        GlassSubscriptionCard(
            subscription: .fixture(),
            preferences: .constant(SubscriptionPreferences(from: .fixture())),
            onSave: {},
            onUnsubscribe: {},
        )
    }
    .padding()
    .background(Color.DesignSystem.background)
}

#Preview("Notification Row") {
    VStack(spacing: 0) {
        ForEach(ForumNotification.fixtures) { notification in
            GlassNotificationRow(
                notification: notification,
                onTap: {},
                onMarkRead: {},
            )
            Divider()
        }
    }
    .background(Color.DesignSystem.background)
}

#Preview("Empty Notifications") {
    GlassEmptyNotificationsView()
        .background(Color.DesignSystem.background)
}
#endif
