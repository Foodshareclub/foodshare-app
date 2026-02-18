//
//  NotificationsView.swift
//  Foodshare
//
//  Notification center view with Liquid Glass v26 design
//



#if !SKIP
import SwiftUI



struct NotificationsView: View {

    @Bindable var viewModel: NotificationsViewModel
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t

    init(viewModel: NotificationsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                Group {
                    if viewModel.isLoading, !viewModel.hasNotifications {
                        loadingView
                    } else if viewModel.hasNotifications {
                        notificationsList
                    } else {
                        emptyState
                    }
                }
            }
            .navigationTitle(t.t("notifications.title"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if viewModel.unreadCount > 0 {
                        Button {
                            Task { await viewModel.markAllAsRead() }
                        } label: {
                            Text(t.t("notifications.mark_all_read"))
                                .font(.DesignSystem.captionSmall)
                                .foregroundColor(.DesignSystem.brandGreen)
                        }
                    }
                }
            }
            .task {
                await viewModel.loadInitial()
                await viewModel.subscribeToUpdates()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
                Button(t.t("common.ok")) { viewModel.clearError() }
            } message: {
                Text(viewModel.error?.errorDescription ?? "Unknown error")
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.sm) {
                ForEach(0..<6, id: \.self) { index in
                    NotificationSkeletonRow()
                        .staggeredAppearance(index: index)
                }
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Notifications List

    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(viewModel.notifications) { notification in
                    notificationRowView(notification)
                }
                loadMoreTrigger
            }
            .padding(Spacing.md)
        }
    }

    @ViewBuilder
    private func notificationRowView(_ notification: UserNotification) -> some View {
        NotificationRow(notification: notification)
            #if !SKIP
            .contentShape(Rectangle())
            #endif
            .onTapGesture {
                HapticManager.light()
                Task { await viewModel.markAsRead(notification) }
            }
    }

    @ViewBuilder
    private var loadMoreTrigger: some View {
        if viewModel.hasMore {
            ProgressView()
                .padding(Spacing.lg)
                .onAppear {
                    Task { await viewModel.loadMore() }
                }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            // Animated icon
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.2),
                                Color.DesignSystem.brandBlue.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 80,
                        ),
                    )
                    .frame(width: 160.0, height: 160)

                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .shimmer(duration: 3.0, bounce: false)
            }

            Text(t.t("notifications.no_notifications"))
                .font(.LiquidGlass.headlineLarge)
                .foregroundColor(.DesignSystem.text)

            Text(t.t("notifications.no_notifications_desc"))
                .font(.LiquidGlass.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
    }
}

// MARK: - Notification Row

struct NotificationRow: View {
    let notification: UserNotification

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

    private var borderStyle: AnyShapeStyle {
        if notification.isRead {
            AnyShapeStyle(Color.DesignSystem.glassBorder)
        } else {
            AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color.DesignSystem.brandGreen.opacity(0.3),
                        Color.DesignSystem.brandBlue.opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Icon with colored background
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 44.0, height: 44)

                Image(systemName: notification.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    Text(notification.title)
                        .font(.LiquidGlass.labelLarge)
                        .foregroundColor(.DesignSystem.text)
                        .fontWeight(notification.isRead ? .regular : .semibold)

                    Spacer()

                    Text(notification.timeAgo)
                        .font(.LiquidGlass.caption)
                        .foregroundColor(.DesignSystem.textTertiary)
                }

                if !notification.displayBody.isEmpty {
                    Text(notification.displayBody)
                        .font(.LiquidGlass.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .lineLimit(2)
                }

                // Actor info if available
                if let actor = notification.actorProfile {
                    HStack(spacing: Spacing.xs) {
                        Circle()
                            .fill(Color.DesignSystem.primary.opacity(0.2))
                            .frame(width: 20.0, height: 20)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.DesignSystem.primary),
                            )

                        Text(actor.displayName)
                            .font(.LiquidGlass.caption)
                            .foregroundColor(.DesignSystem.textTertiary)
                    }
                }
            }

            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 10.0, height: 10)
                    .shadow(color: .DesignSystem.brandGreen.opacity(0.5), radius: 4)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(notification.isRead
                    ? Color.DesignSystem.glassBackground
                    : Color.DesignSystem.glassBackground.opacity(1.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(borderStyle, lineWidth: 1),
                    ),
        )
        #if !SKIP
        .contentShape(Rectangle())
        #endif
    }
}

// MARK: - Notification Skeleton Row

private struct NotificationSkeletonRow: View {
    @State private var shimmerPhase: CGFloat = -200

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            // Icon skeleton
            Circle()
                .fill(skeletonGradient)
                .frame(width: 44.0, height: 44)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack {
                    // Title skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 120.0, height: 16)

                    Spacer()

                    // Time skeleton
                    RoundedRectangle(cornerRadius: 4)
                        .fill(skeletonGradient)
                        .frame(width: 50.0, height: 12)
                }

                // Body skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 200.0, height: 14)

                // Extra line skeleton
                RoundedRectangle(cornerRadius: 4)
                    .fill(skeletonGradient)
                    .frame(width: 150.0, height: 12)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(Color.DesignSystem.glassBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder.opacity(0.5), lineWidth: 1)
                )
        )
        .overlay(shimmerOverlay)
    }

    private var skeletonGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.DesignSystem.textTertiary.opacity(0.3),
                Color.DesignSystem.textTertiary.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.15),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 150.0)
            .offset(x: shimmerPhase)
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    shimmerPhase = geometry.size.width + 150
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
    }
}


#endif
