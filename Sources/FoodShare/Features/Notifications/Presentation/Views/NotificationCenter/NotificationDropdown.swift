//
//  NotificationDropdown.swift
//  Foodshare
//
//  Enterprise-grade slide-down notification dropdown panel
//  Liquid Glass v27 design with backdrop blur, state handling, and animations
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Notification Dropdown

/// An enterprise-grade notification dropdown panel
///
/// Features:
/// - Glass morphism design with backdrop blur
/// - Spring animations for open/close
/// - Header with "Mark all read" button
/// - List of recent notifications (configurable limit)
/// - Footer with "See all" navigation
/// - Loading, empty, and error states
/// - Swipe actions on notification rows
/// - Full accessibility support
struct NotificationDropdown: View {
    @Bindable var viewModel: NotificationCenterViewModel
    let onSeeAll: () -> Void
    let onNotificationTap: (UserNotification) -> Void

    @Environment(\.translationService) private var t
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            dropdownHeader

            // Divider
            Rectangle()
                .fill(Color.DesignSystem.glassBorder.opacity(0.3))
                .frame(height: 0.5)

            // Content based on state
            contentView

            // Footer
            dropdownFooter
        }
        .frame(maxWidth: .infinity)
        .background(dropdownBackground)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.DesignSystem.glassHighlight,
                            Color.DesignSystem.glassBorder.opacity(0.5),
                            Color.clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 1,
                ),
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.15),
            radius: 20,
            y: 10,
        )
        .transition(.asymmetric(
            insertion: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.95, anchor: .top)),
            removal: .opacity
                .combined(with: .move(edge: .top))
                .combined(with: .scale(scale: 0.95, anchor: .top)),
        ))
    }

    // MARK: - Header

    private var dropdownHeader: some View {
        HStack {
            // Title with unread count badge
            HStack(spacing: Spacing.sm) {
                Text(t.t("notifications.title"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.textPrimary)

                if viewModel.unreadCount > 0 {
                    Text("\(viewModel.unreadCount)")
                        .font(.DesignSystem.captionSmall.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, Spacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.DesignSystem.brandGreen),
                        )
                }
            }

            Spacer()

            // Mark all read button
            if viewModel.unreadCount > 0 {
                Button {
                    Task { await viewModel.markAllAsRead() }
                } label: {
                    HStack(spacing: Spacing.xxxs) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 12))
                        Text(t.t("notifications.mark_all_read"))
                            .font(.DesignSystem.captionSmall)
                    }
                    .foregroundStyle(Color.DesignSystem.brandGreen)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mark all notifications as read")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
        switch viewModel.state {
        case .loading where !viewModel.hasNotifications:
            loadingView
        case let .error(message):
            errorView(message: message)
        case .offline:
            offlineView
        default:
            if viewModel.hasNotifications {
                notificationsList
            } else {
                emptyState
            }
        }
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.xs) {
                ForEach(viewModel.recentNotifications) { notification in
                    NotificationRowCompact(
                        notification: notification,
                        onTap: {
                            Task { await viewModel.markAsRead(notification) }
                            onNotificationTap(notification)
                        },
                        onMarkRead: {
                            Task { await viewModel.markAsRead(notification) }
                        },
                        onDelete: {
                            Task { await viewModel.deleteNotification(notification) }
                        },
                    )
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .frame(maxHeight: 380)
        .scrollIndicators(.hidden)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(0 ..< 3, id: \.self) { index in
                CompactNotificationSkeleton()
                    .opacity(1.0 - Double(index) * 0.15)
            }
        }
        .padding(Spacing.sm)
        .frame(height: 220)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.1),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 40,
                        ),
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "bell.slash")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.DesignSystem.textTertiary)
            }

            VStack(spacing: Spacing.xs) {
                Text(t.t("notifications.no_notifications"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                Text(t.t("notifications.no_notifications_desc"))
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No notifications. You're all caught up!")
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.DesignSystem.warning)

            VStack(spacing: Spacing.xs) {
                Text("Something went wrong")
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                Text(message)
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }

            Button {
                Task { await viewModel.loadRecent() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "arrow.clockwise")
                    Text("Try again")
                }
                .font(.DesignSystem.labelSmall)
                .foregroundStyle(Color.DesignSystem.brandGreen)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 180)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Offline View

    private var offlineView: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(Color.DesignSystem.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("You're offline")
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                Text("Changes will sync when you're back online")
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Footer

    private var dropdownFooter: some View {
        Button(action: {
            viewModel.dismissDropdown()
            onSeeAll()
        }) {
            HStack {
                Text(t.t("notifications.see_all"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.brandGreen)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.brandGreen)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                Color.DesignSystem.brandGreen.opacity(0.05),
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("See all notifications")
        .accessibilityHint("Opens full notification list")
    }

    // MARK: - Background

    private var dropdownBackground: some View {
        ZStack {
            // Ultra thin material for glass effect
            Rectangle()
                .fill(.ultraThinMaterial)

            // Subtle gradient overlay for depth
            LinearGradient(
                colors: [
                    Color.white.opacity(colorScheme == .dark ? 0.03 : 0.08),
                    Color.clear,
                    Color.black.opacity(0.02),
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
        }
    }
}

// MARK: - Compact Notification Skeleton

private struct CompactNotificationSkeleton: View {
    @State private var shimmerOffset: CGFloat = -200

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Icon skeleton
            Circle()
                .fill(Color.DesignSystem.textTertiary.opacity(0.15))
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                // Title skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.DesignSystem.textTertiary.opacity(0.15))
                    .frame(width: 140, height: 14)

                // Body skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.DesignSystem.textTertiary.opacity(0.1))
                    .frame(width: 100, height: 10)
            }

            Spacer()

            // Time skeleton
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.DesignSystem.textTertiary.opacity(0.1))
                .frame(width: 30, height: 10)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.glassBackground.opacity(0.3)),
        )
        .overlay(shimmerOverlay)
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.08),
                    Color.clear,
                ],
                startPoint: .leading,
                endPoint: .trailing,
            )
            .frame(width: 100)
            .offset(x: shimmerOffset)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                ) {
                    shimmerOffset = geometry.size.width + 100
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Notification Dropdown - Loaded") {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            VStack {
                Spacer().frame(height: 60)

                NotificationDropdown(
                    viewModel: .preview(),
                    onSeeAll: {},
                    onNotificationTap: { _ in },
                )
                .padding(.horizontal, Spacing.md)

                Spacer()
            }
        }
    }

    #Preview("Notification Dropdown - Empty") {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            VStack {
                Spacer().frame(height: 60)

                NotificationDropdown(
                    viewModel: .emptyPreview(),
                    onSeeAll: {},
                    onNotificationTap: { _ in },
                )
                .padding(.horizontal, Spacing.md)

                Spacer()
            }
        }
    }

    #Preview("Notification Dropdown - Loading") {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            VStack {
                Spacer().frame(height: 60)

                NotificationDropdown(
                    viewModel: .loadingPreview(),
                    onSeeAll: {},
                    onNotificationTap: { _ in },
                )
                .padding(.horizontal, Spacing.md)

                Spacer()
            }
        }
    }
#endif
