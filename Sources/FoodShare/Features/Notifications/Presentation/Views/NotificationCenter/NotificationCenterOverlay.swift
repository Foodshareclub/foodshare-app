//
//  NotificationCenterOverlay.swift
//  Foodshare
//
//  View modifier that adds the notification center overlay to any view
//  Manages dropdown visibility, backdrop, and notification navigation
//



#if !SKIP
import SwiftUI

// MARK: - Notification Center Overlay Modifier

/// A view modifier that adds the notification center overlay
///
/// This modifier:
/// - Adds a dimmed backdrop when dropdown is visible
/// - Positions the dropdown below the navigation bar
/// - Handles tap outside to dismiss
/// - Provides navigation callbacks for notifications
struct NotificationCenterOverlayModifier: ViewModifier {
    @Bindable var viewModel: NotificationCenterViewModel
    let onSeeAll: () -> Void
    let onNotificationTap: (UserNotification) -> Void

    @Environment(\.colorScheme) private var colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if viewModel.isDropdownVisible {
                    ZStack(alignment: .top) {
                        // Backdrop
                        backdrop

                        // Dropdown
                        NotificationDropdown(
                            viewModel: viewModel,
                            onSeeAll: onSeeAll,
                            onNotificationTap: onNotificationTap,
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                    }
                    .ignoresSafeArea()
                }
            }
            .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: viewModel.isDropdownVisible)
    }

    private var backdrop: some View {
        Color.black
            .opacity(colorScheme == .dark ? 0.5 : 0.3)
            .ignoresSafeArea()
            .onTapGesture {
                viewModel.dismissDropdown()
            }
            .transition(.opacity)
    }
}

// MARK: - View Extension

extension View {
    /// Adds notification center overlay with dropdown support
    ///
    /// Example usage:
    /// ```swift
    /// TabView { ... }
    ///     .notificationCenterOverlay(
    ///         viewModel: notificationCenterVM,
    ///         onSeeAll: { showNotificationsSheet = true },
    ///         onNotificationTap: { notification in
    ///             handleNotificationNavigation(notification)
    ///         }
    ///     )
    /// ```
    func notificationCenterOverlay(
        viewModel: NotificationCenterViewModel,
        onSeeAll: @escaping () -> Void,
        onNotificationTap: @escaping (UserNotification) -> Void,
    ) -> some View {
        modifier(NotificationCenterOverlayModifier(
            viewModel: viewModel,
            onSeeAll: onSeeAll,
            onNotificationTap: onNotificationTap,
        ))
    }
}

// MARK: - Notification Center Container

/// A container view that provides the full notification center experience
///
/// Use this when you want the bell button and overlay together
struct NotificationCenterContainer: View {
    @Bindable var viewModel: NotificationCenterViewModel
    let onSeeAll: () -> Void
    let onNotificationTap: (UserNotification) -> Void

    var body: some View {
        NotificationBellButton(
            unreadCount: viewModel.unreadCount,
            hasNewNotification: viewModel.hasNewNotification,
            action: {
                viewModel.toggleDropdown()
            },
        )
    }
}

// MARK: - Notification Navigation Helper

/// Helper struct for notification navigation
enum NotificationNavigation {
    /// Navigate to the appropriate destination based on notification type
    static func destination(for notification: UserNotification) -> AppState.DeepLinkDestination? {
        switch notification.type {
        case .newMessage:
            if let roomId = notification.roomId {
                return .messageRoom(roomId.uuidString)
            }
            return .messages

        case .arrangementRequest, .arrangementConfirmed, .arrangementCancelled:
            if let postId = notification.postId {
                return .listing(postId)
            }
            return nil

        case .newListingNearby:
            if let postId = notification.postId {
                return .listing(postId)
            }
            return .map(nil, nil)

        case .reviewReceived, .reviewReminder:
            return .profile(notification.recipientId)

        case .challengeCompleted:
            return nil // TODO: Add challenge destination

        case .forumReply:
            if let data = notification.data,
               let postIdString = data["forum_post_id"],
               let postId = Int(postIdString)
            {
                return .forumPost(postId)
            }
            return nil

        case .system:
            return nil
        }
    }
}

// MARK: - Preview

#if DEBUG
    #Preview("Notification Center Overlay") {
        struct PreviewWrapper: View {
            @State private var viewModel = NotificationCenterViewModel.preview()

            var body: some View {
                ZStack {
                    // Mock tab view content
                    VStack {
                        Text("Main Content")
                            .font(.DesignSystem.displayLarge)
                            .foregroundStyle(Color.DesignSystem.textPrimary)

                        Button("Toggle Dropdown") {
                            viewModel.toggleDropdown()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.DesignSystem.background)
                }
                .notificationCenterOverlay(
                    viewModel: viewModel,
                    onSeeAll: {},
                    onNotificationTap: { _ in },
                )
            }
        }

        return PreviewWrapper()
    }
#endif


#endif
