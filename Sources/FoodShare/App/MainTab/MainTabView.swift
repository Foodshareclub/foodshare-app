//
//  MainTabView.swift
//  Foodshare
//
//  Main tab navigation with Explore, Challenges, Chats, and Profile
//  Refactored: December 2025 - Modular architecture with extracted components
//  Enhanced: January 2026 - Enterprise notification center with dropdown
//

import FoodShareDesignSystem
import Supabase
import SwiftUI

// MARK: - Main Tab View

struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(GuestManager.self) private var guestManager
    @Environment(\.translationService) private var t
    @State private var selectedTab: Tab = .explore

    /// Notification Center State
    @State private var notificationCenterViewModel: NotificationCenterViewModel?

    // Deep link navigation state
    @State private var deepLinkListingId: Int?
    @State private var deepLinkProfileId: UUID?
    @State private var deepLinkChallengeId: Int?
    @State private var deepLinkForumPostId: Int?
    @State private var deepLinkMessageRoomId: String?
    @State private var deepLinkChatRoomId: String?
    @State private var deepLinkSettingsSection: String?
    @State private var showCreateListingSheet = false
    @State private var showMyPosts = false
    @State private var showNotificationsSheet = false
    @State private var showNotificationsFullSheet = false
    @State private var showDonationSheet = false
    @State private var showHelpSheet = false
    @State private var showFeedbackSheet = false
    @State private var showPrivacySheet = false
    @State private var showTermsSheet = false

    enum Tab: Int, CaseIterable {
        case explore = 0
        case chats = 1
        case challenges = 2
        case forum = 3
        case profile = 4

        @MainActor
        func title(using t: EnhancedTranslationService) -> String {
            switch self {
            case .explore: t.t("tabs.explore")
            case .chats: t.t("tabs.chats")
            case .challenges: t.t("tabs.challenges")
            case .forum: t.t("tabs.forum")
            case .profile: t.t("tabs.profile")
            }
        }

        var icon: String {
            switch self {
            case .explore: "magnifyingglass"
            case .chats: "message.fill"
            case .challenges: "trophy.fill"
            case .forum: "bubble.left.and.bubble.right.fill"
            case .profile: "person.fill"
            }
        }
    }

    var body: some View {
        mainTabContent
            .modifier(MainTabSheetsModifier(
                appState: appState,
                guestManager: guestManager,
                showCreateListingSheet: $showCreateListingSheet,
                showNotificationsSheet: $showNotificationsSheet,
                showDonationSheet: $showDonationSheet,
                showHelpSheet: $showHelpSheet,
                showFeedbackSheet: $showFeedbackSheet,
                showPrivacySheet: $showPrivacySheet,
                showTermsSheet: $showTermsSheet,
            ))
            .modifier(NotificationCenterModifier(
                viewModel: notificationCenterViewModel,
                showNotificationsFullSheet: $showNotificationsFullSheet,
                onNotificationTap: handleNotificationNavigation,
            ))
            .sheet(isPresented: $showNotificationsFullSheet) {
                notificationsFullSheet
            }
            .onChange(of: appState.deepLinkDestination) { _, destination in
                handleDeepLinkNavigation(destination)
            }
            .onReceive(NotificationCenter.default.publisher(for: .didReceivePushNotification)) { notification in
                handlePushNotificationTap(notification)
            }
            .task {
                await setupNotificationCenter()
            }
    }

    // MARK: - Notification Center Setup

    private func setupNotificationCenter() async {
        guard let userId = appState.currentUser?.id else { return }

        // Create the notification center view model if not already created
        if notificationCenterViewModel == nil {
            notificationCenterViewModel = NotificationCenterViewModel(
                repository: appState.dependencies.notificationRepository,
                userId: userId,
            )
        }

        // Load initial data and subscribe to real-time updates
        if let viewModel = notificationCenterViewModel {
            await viewModel.loadRecent()
            await viewModel.subscribeToRealtime()
        }
    }

    // MARK: - Notification Navigation

    private func handleNotificationNavigation(_ notification: UserNotification) {
        // Dismiss dropdown first
        notificationCenterViewModel?.dismissDropdown()

        // Navigate based on notification type
        if let destination = NotificationNavigation.destination(for: notification) {
            appState.deepLinkDestination = destination
        }
    }

    // MARK: - Notifications Full Sheet

    @ViewBuilder
    private var notificationsFullSheet: some View {
        if let userId = appState.currentUser?.id {
            NotificationsView(
                viewModel: NotificationsViewModel(
                    repository: appState.dependencies.notificationRepository,
                    userId: userId,
                ),
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Main Tab Content

    private var mainTabContent: some View {
        TabView(selection: $selectedTab) {
            ExploreTabView(
                deepLinkListingId: $deepLinkListingId,
                deepLinkForumPostId: $deepLinkForumPostId,
            )
            .tabItem {
                Label(t.t("tabs.explore"), systemImage: Tab.explore.icon)
                    .accessibilityLabel("Explore food listings")
            }
            .tag(Tab.explore)

            ChatsTabView()
                .tabItem {
                    Label(t.t("tabs.chats"), systemImage: Tab.chats.icon)
                        .accessibilityLabel("Messages")
                }
                .tag(Tab.chats)

            ChallengesTabView(deepLinkChallengeId: $deepLinkChallengeId)
                .tabItem {
                    Label(t.t("tabs.challenges"), systemImage: Tab.challenges.icon)
                        .accessibilityLabel("Food waste challenges")
                }
                .tag(Tab.challenges)

            ForumTabView(deepLinkForumPostId: $deepLinkForumPostId)
                .tabItem {
                    Label(t.t("tabs.forum"), systemImage: Tab.forum.icon)
                        .accessibilityLabel("Community forum")
                }
                .tag(Tab.forum)

            ProfileTabView(deepLinkProfileId: $deepLinkProfileId)
                .tabItem {
                    Label(t.t("tabs.profile"), systemImage: Tab.profile.icon)
                        .accessibilityLabel("Profile")
                }
                .tag(Tab.profile)
        }
        .tint(.DesignSystem.brandGreen)
        .overlay(alignment: .top) {
            if guestManager.isGuestMode {
                GuestModeBanner()
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.xs)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: guestManager.isGuestMode)
            }
        }
    }

    // MARK: - Deep Link Navigation Handler

    private func handleDeepLinkNavigation(_ destination: AppState.DeepLinkDestination?) {
        guard let destination else { return }

        switch destination {
        // Content destinations
        case let .listing(listingId):
            selectedTab = .explore
            deepLinkListingId = listingId

        case let .profile(profileId):
            selectedTab = .profile
            deepLinkProfileId = profileId

        case .messages:
            selectedTab = .chats

        case let .messageRoom(roomId):
            selectedTab = .chats
            deepLinkMessageRoomId = roomId

        case let .challenge(challengeId):
            selectedTab = .challenges
            deepLinkChallengeId = challengeId

        case let .forumPost(postId):
            selectedTab = .forum
            deepLinkForumPostId = postId

        case .map:
            selectedTab = .explore

        // User destinations
        case .myPosts:
            selectedTab = .profile
            showMyPosts = true

        case let .myPost(postId):
            selectedTab = .profile
            deepLinkListingId = postId // Reuse listing navigation

        case .chat:
            selectedTab = .chats

        case let .chatRoom(roomId):
            selectedTab = .chats
            deepLinkMessageRoomId = roomId

        case .createListing:
            selectedTab = .explore
            showCreateListingSheet = true

        // Settings destinations
        case .notifications:
            selectedTab = .profile
            showNotificationsSheet = true

        case .donation:
            selectedTab = .profile
            showDonationSheet = true

        case .help:
            selectedTab = .profile
            showHelpSheet = true

        case .feedback:
            selectedTab = .profile
            showFeedbackSheet = true

        case .privacy:
            selectedTab = .profile
            showPrivacySheet = true

        case .terms:
            selectedTab = .profile
            showTermsSheet = true

        case .settings:
            selectedTab = .profile

        case let .settingsSection(section):
            selectedTab = .profile
            deepLinkSettingsSection = section
        }
    }

    // MARK: - Push Notification Handler

    private func handlePushNotificationTap(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeString = userInfo["type"] as? String else
        {
            return
        }

        // Route based on notification type
        switch typeString {
        case "new_message":
            if let roomId = userInfo["roomId"] as? String {
                appState.deepLinkDestination = .messageRoom(roomId)
            } else {
                appState.deepLinkDestination = .messages
            }

        case "arrangement_request", "arrangement_confirmed", "arrangement_cancelled":
            if let postIdString = userInfo["postId"] as? String,
               let postId = Int(postIdString)
            {
                appState.deepLinkDestination = .listing(postId)
            }

        case "new_listing_nearby":
            if let postIdString = userInfo["postId"] as? String,
               let postId = Int(postIdString)
            {
                appState.deepLinkDestination = .listing(postId)
            } else {
                appState.deepLinkDestination = .map(nil, nil)
            }

        case "review_reminder":
            // Navigate to profile reviews section
            appState.deepLinkDestination = .profile(appState.currentUser?.id ?? UUID())

        case "fridge_update":
            // Navigate to user's posts/fridge
            appState.deepLinkDestination = .myPosts

        default:
            // Unknown type - just show explore
            break
        }
    }
}

// MARK: - Main Tab Sheets Modifier

/// ViewModifier that consolidates all sheet presentations to reduce body complexity
struct MainTabSheetsModifier: ViewModifier {
    let appState: AppState
    let guestManager: GuestManager

    @Binding var showCreateListingSheet: Bool
    @Binding var showNotificationsSheet: Bool
    @Binding var showDonationSheet: Bool
    @Binding var showHelpSheet: Bool
    @Binding var showFeedbackSheet: Bool
    @Binding var showPrivacySheet: Bool
    @Binding var showTermsSheet: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Bindable(appState).showAuthentication) {
                AuthView()
                    .presentationDetents([.large])
                    .interactiveDismissDisabled(false)
            }
            .sheet(isPresented: $showCreateListingSheet) {
                CreateListingSheet()
            }
            .sheet(isPresented: Bindable(guestManager).showSignUpPrompt) {
                guestUpgradeSheet
            }
            .modifier(DeepLinkSheetsModifier(
                showNotificationsSheet: $showNotificationsSheet,
                showDonationSheet: $showDonationSheet,
                showHelpSheet: $showHelpSheet,
                showFeedbackSheet: $showFeedbackSheet,
                showPrivacySheet: $showPrivacySheet,
                showTermsSheet: $showTermsSheet,
                appState: appState,
            ))
    }

    @ViewBuilder
    private var guestUpgradeSheet: some View {
        if let feature = guestManager.restrictedFeature {
            GuestUpgradePromptView(feature: feature)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Deep Link Sheets Modifier

/// Separate modifier for deep link sheets to further reduce complexity
struct DeepLinkSheetsModifier: ViewModifier {
    @Binding var showNotificationsSheet: Bool
    @Binding var showDonationSheet: Bool
    @Binding var showHelpSheet: Bool
    @Binding var showFeedbackSheet: Bool
    @Binding var showPrivacySheet: Bool
    @Binding var showTermsSheet: Bool
    let appState: AppState

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showNotificationsSheet) {
                NotificationsSettingsView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showDonationSheet) {
                DonationView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showHelpSheet) {
                HelpView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showFeedbackSheet) {
                feedbackSheet
            }
            .sheet(isPresented: $showPrivacySheet) {
                LegalDocumentView(type: LegalDocumentView.LegalDocumentType.privacy)
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showTermsSheet) {
                LegalDocumentView(type: LegalDocumentView.LegalDocumentType.terms)
                    .presentationDetents([.large])
            }
    }

    private var feedbackSheet: some View {
        FeedbackView(
            viewModel: FeedbackViewModel(
                repository: SupabaseFeedbackRepository(supabase: SupabaseManager.shared.client),
                userId: appState.currentUser?.id,
                defaultName: appState.currentUser?.displayName ?? "",
                defaultEmail: appState.currentUser?.email ?? "",
            ),
        )
        .presentationDetents([.large])
    }
}

// MARK: - Create Listing Sheet (for deep links)

struct CreateListingSheet: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: CreateListingViewModel?

    var body: some View {
        Group {
            if let viewModel {
                CreateListingView(viewModel: viewModel)
            } else {
                ProgressView()
                    .task {
                        viewModel = CreateListingViewModel(repository: appState.dependencies.listingRepository)
                    }
            }
        }
    }
}

// MARK: - Notification Center Modifier

/// ViewModifier that adds the notification center overlay with bell button and dropdown
///
/// Notification center modifier that shows dropdown when triggered.
/// Bell button is now integrated into the search header filter button.
struct NotificationCenterModifier: ViewModifier {
    let viewModel: NotificationCenterViewModel?
    @Binding var showNotificationsFullSheet: Bool
    let onNotificationTap: (UserNotification) -> Void

    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            // Bell button removed - now integrated into search header filter button
            // via GlassActionButtonWithNotification in ExploreTabView
            .overlay {
                // Dropdown overlay (full screen)
                if let viewModel, viewModel.isDropdownVisible {
                    notificationCenterOverlay(viewModel: viewModel)
                }
            }
    }

    private func notificationCenterOverlay(viewModel: NotificationCenterViewModel) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                // Backdrop with tap to dismiss
                Color.black
                    .opacity(colorScheme == .dark ? 0.5 : 0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.dismissDropdown()
                    }
                    .transition(.opacity)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Dismiss notifications")

                // Dropdown panel - positioned below the bell button
                VStack {
                    NotificationDropdown(
                        viewModel: viewModel,
                        onSeeAll: {
                            viewModel.dismissDropdown()
                            showNotificationsFullSheet = true
                        },
                        onNotificationTap: onNotificationTap,
                    )
                    .frame(maxWidth: min(geometry.size.width - Spacing.md * 2, 400))
                    .padding(.top, 56) // Below the bell button

                    Spacer()
                }
                .padding(.horizontal, Spacing.md)
            }
        }
        .transition(.opacity)
        .animation(.interpolatingSpring(stiffness: 300, damping: 25), value: viewModel.isDropdownVisible)
    }
}

// MARK: - Keyboard Shortcut Support

extension NotificationCenterModifier {
    /// Add keyboard shortcuts for notification center
    /// - Cmd+N: Toggle notification dropdown
    /// - Escape: Dismiss dropdown
    func withKeyboardShortcuts() -> some View {
        EmptyView() // Placeholder for iOS keyboard support
    }
}
