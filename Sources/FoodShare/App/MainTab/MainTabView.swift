//
//  MainTabView.swift
//  Foodshare
//
//  Main tab navigation with Explore, Challenges, Chats, and Profile
//  Refactored: December 2025 - Modular architecture with extracted components
//  Enhanced: January 2026 - Enterprise notification center with dropdown
//



#if !SKIP
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
            #if !SKIP
            .onReceive(NotificationCenter.default.publisher(for: .didReceivePushNotification)) { notification in
                handlePushNotificationTap(notification)
            }
            #endif
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
            .presentationDetents([PresentationDetent.large])
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
                    .presentationDetents([PresentationDetent.large])
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
                .presentationDetents([PresentationDetent.large])
                #if !SKIP
                .presentationDragIndicator(.visible)
                #endif
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
                    .presentationDetents([PresentationDetent.large])
            }
            .sheet(isPresented: $showDonationSheet) {
                DonationView()
                    .presentationDetents([PresentationDetent.large])
            }
            .sheet(isPresented: $showHelpSheet) {
                HelpView()
                    .presentationDetents([PresentationDetent.large])
            }
            .sheet(isPresented: $showFeedbackSheet) {
                feedbackSheet
            }
            .sheet(isPresented: $showPrivacySheet) {
                LegalDocumentView(type: LegalDocumentView.LegalDocumentType.privacy)
                    .presentationDetents([PresentationDetent.large])
            }
            .sheet(isPresented: $showTermsSheet) {
                LegalDocumentView(type: LegalDocumentView.LegalDocumentType.terms)
                    .presentationDetents([PresentationDetent.large])
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
        .presentationDetents([PresentationDetent.large])
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

    @Environment(\.colorScheme) private var colorScheme: ColorScheme

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


#else
// MARK: - Android MainTabView Stub (Skip)
// Full implementation in Phase 2

import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) var appState
    @Environment(GuestManager.self) var guestManager

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Explore Tab
            ExploreTab()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
                .tag(0)

            // Challenges Tab
            ChallengesTab()
                .tabItem {
                    Label("Challenges", systemImage: "trophy.fill")
                }
                .tag(1)

            // Chats Tab
            ChatsTab()
                .tabItem {
                    Label("Chats", systemImage: "message.fill")
                }
                .tag(2)

            // Forum Tab
            ForumTab()
                .tabItem {
                    Label("Forum", systemImage: "bubble.left.and.bubble.right.fill")
                }
                .tag(3)

            // Profile Tab
            ProfileTab()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
    }
}

// MARK: - Explore Tab (Feed)

private struct ExploreTab: View {
    @Environment(AppState.self) var appState
    @Environment(FeedViewModel.self) var feedViewModel

    @State private var showCreateListing = false
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 0.0) {
                        // Category bar
                        CategoryBar(
                            categories: feedViewModel.categories,
                            selectedCategory: feedViewModel.selectedCategory,
                            onSelect: { cat in feedViewModel.selectCategory(cat) }
                        )
                        .padding(.vertical, 8.0)

                        if feedViewModel.isLoading && feedViewModel.items.isEmpty {
                            VStack(spacing: 16.0) {
                                ProgressView()
                                Text("Loading nearby food...")
                                    .font(.system(size: 14.0))
                                    .foregroundStyle(Color.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60.0)
                        } else if feedViewModel.items.isEmpty {
                            VStack(spacing: 16.0) {
                                Image(systemName: "leaf.fill")
                                    .font(.system(size: 48.0))
                                    .foregroundStyle(Color.gray.opacity(0.4))
                                Text("No food listings nearby")
                                    .font(.system(size: 18.0, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                Text("Try expanding your search radius or check back later")
                                    .font(.system(size: 14.0))
                                    .foregroundStyle(Color.gray)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 60.0)
                            .padding(.horizontal, 32.0)
                        } else {
                            ForEach(feedViewModel.items) { item in
                                NavigationLink(destination: FoodItemDetailView(item: item)) {
                                    FoodListingCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16.0)
                                .padding(.vertical, 6.0)
                            }

                            if feedViewModel.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }

                            if feedViewModel.hasMore && !feedViewModel.isLoadingMore {
                                Color.clear
                                    .frame(height: 1.0)
                                    .task {
                                        await feedViewModel.loadMore()
                                    }
                            }
                        }
                    }
                }
                .refreshable {
                    await feedViewModel.refresh()
                }

                // FAB: Create Listing
                if appState.isAuthenticated {
                    Button(action: { showCreateListing = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24.0, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 56.0, height: 56.0)
                            .background(Color(red: 0.2, green: 0.7, blue: 0.4))
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.3), radius: 6.0, y: 3.0)
                    }
                    .padding(.trailing, 16.0)
                    .padding(.bottom, 16.0)
                }
            }
            .navigationTitle("Explore")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSearch = true }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                }
            }
            .sheet(isPresented: $showCreateListing) {
                CreateListingView()
                    .environment(appState)
            }
            .sheet(isPresented: $showSearch) {
                SearchView()
            }
            .task {
                await feedViewModel.loadCategories()
                if feedViewModel.items.isEmpty {
                    await feedViewModel.loadFeed()
                }
            }
        }
    }
}

// MARK: - Category Bar

private struct CategoryBar: View {
    let categories: [Category]
    let selectedCategory: Category?
    let onSelect: (Category?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8.0) {
                // "All" chip
                CategoryChip(
                    name: "All",
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    onTap: { onSelect(nil) }
                )

                ForEach(categories) { category in
                    CategoryChip(
                        name: category.name,
                        icon: category.icon,
                        isSelected: selectedCategory?.id == category.id,
                        onTap: { onSelect(category) }
                    )
                }
            }
            .padding(.horizontal, 16.0)
        }
    }
}

private struct CategoryChip: View {
    let name: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4.0) {
                Image(systemName: icon)
                    .font(.system(size: 12.0))
                Text(name)
                    .font(.system(size: 13.0, weight: .medium))
            }
            .padding(.horizontal, 12.0)
            .padding(.vertical, 8.0)
            .background(isSelected ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color.white.opacity(0.1))
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.7))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Food Listing Card

private struct FoodListingCard: View {
    let item: FoodItem

    var body: some View {
        VStack(alignment: .leading, spacing: 0.0) {
            // Image
            if let imageUrl = item.displayImageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: ContentMode.fill)
                            .frame(height: 180.0)
                            .clipped()
                    case .failure:
                        imagePlaceholder
                    default:
                        ProgressView()
                            .frame(height: 180.0)
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                imagePlaceholder
            }

            // Content
            VStack(alignment: .leading, spacing: 6.0) {
                Text(item.title)
                    .font(.system(size: 16.0, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                if let desc = item.description {
                    Text(desc)
                        .font(.system(size: 13.0))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(2)
                }

                HStack(spacing: 12.0) {
                    if let distance = item.distanceDisplay {
                        HStack(spacing: 4.0) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 11.0))
                            Text(distance)
                                .font(.system(size: 12.0))
                        }
                        .foregroundStyle(Color.white.opacity(0.5))
                    }

                    if let address = item.displayAddress {
                        Text(address)
                            .font(.system(size: 12.0))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Status badge
                    Text(item.status.displayName)
                        .font(.system(size: 11.0, weight: .medium))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 8.0)
                        .padding(.vertical, 3.0)
                        .background(item.isAvailable ? Color(red: 0.18, green: 0.8, blue: 0.44) : Color.orange)
                        .clipShape(Capsule())
                }
            }
            .padding(12.0)
        }
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12.0))
    }

    private var imagePlaceholder: some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: "leaf.fill")
                .font(.system(size: 32.0))
                .foregroundStyle(Color.white.opacity(0.2))
        }
        .frame(height: 180.0)
    }
}

// MARK: - Generic Placeholder Tab

private struct PlaceholderTab: View {
    let title: String
    let icon: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16.0) {
                Image(systemName: icon)
                    .font(.system(size: 48.0))
                    .foregroundStyle(Color.white.opacity(0.3))
                Text(title)
                    .font(.system(size: 20.0, weight: .semibold))
                    .foregroundStyle(Color.white)
                Text("Coming soon")
                    .font(.system(size: 14.0))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .navigationTitle(title)
        }
    }
}

// MARK: - Profile Tab

private struct ProfileTab: View {
    @Environment(AppState.self) var appState
    @Environment(GuestManager.self) var guestManager

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20.0) {
                    if let user = appState.currentUser {
                        // Avatar
                        if let avatarUrl = user.avatarUrl, let url = URL(string: avatarUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: ContentMode.fill)
                                        .frame(width: 100.0, height: 100.0)
                                        .clipShape(Circle())
                                default:
                                    profileAvatarPlaceholder
                                }
                            }
                        } else {
                            profileAvatarPlaceholder
                        }

                        // Name
                        Text(user.displayName ?? "User")
                            .font(.system(size: 22.0, weight: .bold))
                            .foregroundStyle(Color.white)

                        if let email = user.email {
                            Text(email)
                                .font(.system(size: 14.0))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }

                        // Member since
                        if let created = user.createdTime {
                            Text("Member since \(Self.formatDate(created))")
                                .font(.system(size: 13.0))
                                .foregroundStyle(Color.white.opacity(0.4))
                        }

                        // Settings button
                        NavigationLink(destination: SettingsView().environment(appState)) {
                            HStack(spacing: 10.0) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 16.0))
                                Text("Settings")
                                    .font(.system(size: 16.0, weight: .medium))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12.0))
                            }
                            .foregroundStyle(Color.white.opacity(0.7))
                            .padding(14.0)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12.0))
                        }
                        .padding(.horizontal, 24.0)

                        // Sign Out Button
                        Button(action: {
                            Task { await appState.signOut() }
                        }) {
                            Text("Sign Out")
                                .font(.system(size: 16.0, weight: .medium))
                                .foregroundStyle(Color.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12.0)
                        }
                        .background(Color.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12.0))
                        .padding(.horizontal, 32.0)

                    } else if guestManager.isGuestMode {
                        // Guest mode profile
                        profileAvatarPlaceholder

                        Text("Guest")
                            .font(.system(size: 22.0, weight: .bold))
                            .foregroundStyle(Color.white)

                        Text("Sign up to save your activity and connect with the community")
                            .font(.system(size: 14.0))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32.0)

                        Button(action: { guestManager.disableGuestMode() }) {
                            Text("Sign Up / Sign In")
                                .font(.system(size: 16.0, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12.0)
                        }
                        .background(Color(red: 0.2, green: 0.7, blue: 0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 12.0))
                        .padding(.horizontal, 32.0)
                    }

                    Spacer()
                }
                .padding(.top, 32.0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .navigationTitle("Profile")
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    private var profileAvatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 100.0, height: 100.0)
            Image(systemName: "person.fill")
                .font(.system(size: 40.0))
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }
}

// MARK: - Challenges Tab

private struct ChallengeItem: Codable, Identifiable {
    let id: Int
    let title: String?
    let description: String?
    let startDate: Date?
    let endDate: Date?
    let targetValue: Int?
    let currentParticipants: Int?
    let imageUrl: String?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, title, description
        case startDate = "start_date"
        case endDate = "end_date"
        case targetValue = "target_value"
        case currentParticipants = "current_participants"
        case imageUrl = "image_url"
        case isActive = "is_active"
    }
}

private struct ChallengesTab: View {
    @State private var challenges: [ChallengeItem] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12.0) {
                    if isLoading && challenges.isEmpty {
                        ProgressView()
                            .padding(.top, 60.0)
                    } else if challenges.isEmpty {
                        VStack(spacing: 16.0) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 48.0))
                                .foregroundStyle(Color.white.opacity(0.2))
                            Text("No challenges available")
                                .font(.system(size: 18.0, weight: .semibold))
                                .foregroundStyle(Color.white)
                            Text("Check back soon for community challenges")
                                .font(.system(size: 14.0))
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                        .padding(.top, 60.0)
                    } else {
                        ForEach(challenges) { challenge in
                            ChallengeCard(challenge: challenge)
                                .padding(.horizontal, 16.0)
                        }
                    }
                }
                .padding(.top, 8.0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .navigationTitle("Challenges")
            .task {
                await loadChallenges()
            }
            .refreshable {
                await loadChallenges()
            }
        }
    }

    private func loadChallenges() async {
        isLoading = true
        let baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        let apiKey = AppEnvironment.supabasePublishableKey ?? ""

        // Direct Supabase query for challenges (no Edge Function exists)
        guard let url = URL(string: "\(baseURL)/rest/v1/challenges?is_active=eq.true&order=start_date.desc&limit=20") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = AuthenticationService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            challenges = try decoder.decode([ChallengeItem].self, from: data)
        } catch {
            // Silently fail
        }

        isLoading = false
    }
}

private struct ChallengeCard: View {
    let challenge: ChallengeItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20.0))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))

                Text(challenge.title ?? "Challenge")
                    .font(.system(size: 16.0, weight: .semibold))
                    .foregroundStyle(Color.white)

                Spacer()

                if let participants = challenge.currentParticipants {
                    Text("\(participants) joined")
                        .font(.system(size: 12.0))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }

            if let desc = challenge.description {
                Text(desc)
                    .font(.system(size: 13.0))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(3)
            }

            if let target = challenge.targetValue {
                HStack {
                    Text("Goal: \(target) items")
                        .font(.system(size: 12.0))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Spacer()
                }
            }
        }
        .padding(16.0)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12.0))
    }
}

// MARK: - Forum Tab

private struct ForumPost: Codable, Identifiable {
    let id: Int
    let title: String?
    let content: String?
    let authorId: UUID?
    let authorName: String?
    let authorAvatar: String?
    let likeCount: Int?
    let commentCount: Int?
    let viewCount: Int?
    let isPinned: Bool?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case authorId = "author_id"
        case authorName = "author_name"
        case authorAvatar = "author_avatar"
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case viewCount = "view_count"
        case isPinned = "is_pinned"
        case createdAt = "created_at"
    }
}

private struct ForumEnvelope: Codable {
    let success: Bool
    let data: [ForumPost]?
}

private struct ForumTab: View {
    @State private var posts: [ForumPost] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 8.0) {
                    if isLoading && posts.isEmpty {
                        ProgressView()
                            .padding(.top, 60.0)
                    } else if posts.isEmpty {
                        VStack(spacing: 16.0) {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.system(size: 48.0))
                                .foregroundStyle(Color.white.opacity(0.2))
                            Text("No forum posts yet")
                                .font(.system(size: 18.0, weight: .semibold))
                                .foregroundStyle(Color.white)
                        }
                        .padding(.top, 60.0)
                    } else {
                        ForEach(posts) { post in
                            ForumPostCard(post: post)
                                .padding(.horizontal, 16.0)
                        }
                    }
                }
                .padding(.top, 8.0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .navigationTitle("Forum")
            .task {
                await loadPosts()
            }
            .refreshable {
                await loadPosts()
            }
        }
    }

    private func loadPosts() async {
        isLoading = true
        let baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        let apiKey = AppEnvironment.supabasePublishableKey ?? ""

        guard let url = URL(string: "\(baseURL)/functions/v1/api-v1-forum?limit=20") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = AuthenticationService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(ForumEnvelope.self, from: data)
            posts = envelope.data ?? []
        } catch {
            // Silently fail
        }

        isLoading = false
    }
}

private struct ForumPostCard: View {
    let post: ForumPost

    var body: some View {
        VStack(alignment: .leading, spacing: 10.0) {
            // Author row
            HStack(spacing: 8.0) {
                if let avatar = post.authorAvatar, let url = URL(string: avatar) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: ContentMode.fill)
                                .frame(width: 28.0, height: 28.0)
                                .clipShape(Circle())
                        default:
                            Circle()
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 28.0, height: 28.0)
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 28.0, height: 28.0)
                }

                Text(post.authorName ?? "Anonymous")
                    .font(.system(size: 13.0, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))

                Spacer()

                if post.isPinned == true {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 11.0))
                        .foregroundStyle(Color.yellow)
                }
            }

            // Title
            Text(post.title ?? "")
                .font(.system(size: 16.0, weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(2)

            // Content preview
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.system(size: 13.0))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .lineLimit(3)
            }

            // Stats
            HStack(spacing: 16.0) {
                HStack(spacing: 4.0) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11.0))
                    Text("\(post.likeCount ?? 0)")
                        .font(.system(size: 12.0))
                }

                HStack(spacing: 4.0) {
                    Image(systemName: "bubble.left.fill")
                        .font(.system(size: 11.0))
                    Text("\(post.commentCount ?? 0)")
                        .font(.system(size: 12.0))
                }

                HStack(spacing: 4.0) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 11.0))
                    Text("\(post.viewCount ?? 0)")
                        .font(.system(size: 12.0))
                }

                Spacer()
            }
            .foregroundStyle(Color.white.opacity(0.4))
        }
        .padding(14.0)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12.0))
    }
}

// MARK: - Chats Tab

private struct ChatRoomItem: Codable, Identifiable {
    let id: UUID
    let postId: Int?
    let lastMessage: String?
    let lastMessageTime: Date?
    let hasUnread: Bool?
    let isArranged: Bool?
    let otherParticipant: ChatParticipant?
    let post: ChatPostSummary?
}

private struct ChatParticipant: Codable {
    let id: UUID?
    let firstName: String?
    let secondName: String?
    let avatarUrl: String?

    var displayName: String {
        if let first = firstName, !first.isEmpty {
            if let second = secondName, !second.isEmpty {
                return "\(first) \(second)"
            }
            return first
        }
        return "User"
    }
}

private struct ChatPostSummary: Codable {
    let id: Int?
    let name: String?
    let type: String?
    let image: String?
}

private struct ChatRoomsEnvelope: Codable {
    let success: Bool
    let data: [ChatRoomItem]?
}

private struct ChatsTab: View {
    @Environment(AppState.self) var appState
    @Environment(GuestManager.self) var guestManager

    @State private var rooms: [ChatRoomItem] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if !appState.isAuthenticated && !guestManager.isGuestMode {
                    Text("Sign in to view your chats")
                        .foregroundStyle(Color.white.opacity(0.5))
                } else if isLoading && rooms.isEmpty {
                    ProgressView()
                } else if rooms.isEmpty {
                    VStack(spacing: 16.0) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 48.0))
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text("No conversations yet")
                            .font(.system(size: 18.0, weight: .semibold))
                            .foregroundStyle(Color.white)
                        Text("Start chatting by tapping Message on a food listing")
                            .font(.system(size: 14.0))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32.0)
                    }
                } else {
                    List(rooms) { room in
                        NavigationLink(destination: ChatDetailView(room: room)) {
                            ChatRoomRow(room: room)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .navigationTitle("Chats")
            .task {
                if appState.isAuthenticated {
                    await loadRooms()
                }
            }
            .refreshable {
                await loadRooms()
            }
        }
    }

    private func loadRooms() async {
        guard !isLoading else { return }
        isLoading = true

        let baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        let apiKey = AppEnvironment.supabasePublishableKey ?? ""

        guard let url = URL(string: "\(baseURL)/functions/v1/api-v1-chat?mode=food&limit=30") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = AuthenticationService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(ChatRoomsEnvelope.self, from: data)
            rooms = envelope.data ?? []
        } catch {
            // Silently fail — empty state will show
        }

        isLoading = false
    }
}

private struct ChatRoomRow: View {
    let room: ChatRoomItem

    var body: some View {
        HStack(spacing: 12.0) {
            // Avatar
            if let avatarUrl = room.otherParticipant?.avatarUrl, let url = URL(string: avatarUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: ContentMode.fill)
                            .frame(width: 48.0, height: 48.0)
                            .clipShape(Circle())
                    default:
                        chatAvatarPlaceholder
                    }
                }
            } else {
                chatAvatarPlaceholder
            }

            VStack(alignment: .leading, spacing: 4.0) {
                HStack {
                    Text(room.otherParticipant?.displayName ?? "User")
                        .font(.system(size: 15.0, weight: .semibold))
                        .foregroundStyle(Color.white)

                    Spacer()

                    if room.hasUnread == true {
                        Circle()
                            .fill(Color(red: 0.2, green: 0.7, blue: 0.4))
                            .frame(width: 8.0, height: 8.0)
                    }
                }

                if let postName = room.post?.name {
                    Text(postName)
                        .font(.system(size: 12.0))
                        .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.4))
                        .lineLimit(1)
                }

                if let lastMessage = room.lastMessage {
                    Text(lastMessage)
                        .font(.system(size: 13.0))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4.0)
    }

    private var chatAvatarPlaceholder: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.1))
                .frame(width: 48.0, height: 48.0)
            Image(systemName: "person.fill")
                .font(.system(size: 20.0))
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }
}

// MARK: - Chat Detail View (Messages)

private struct ChatMessageItem: Codable, Identifiable {
    let id: UUID
    let roomId: UUID?
    let senderId: UUID?
    let text: String?
    let image: String?
    let timestamp: Date?
}

private struct ChatDetailEnvelope: Codable {
    let success: Bool
    let data: ChatDetailData?
}

private struct ChatDetailData: Codable {
    let room: ChatRoomItem?
    let messages: [ChatMessageItem]?
    let hasMoreMessages: Bool?
}

private struct ChatDetailView: View {
    let room: ChatRoomItem

    @State private var messages: [ChatMessageItem] = []
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var isSending = false

    var body: some View {
        VStack(spacing: 0.0) {
            // Messages
            ScrollView {
                LazyVStack(spacing: 8.0) {
                    if isLoading {
                        ProgressView()
                            .padding()
                    }

                    ForEach(messages) { message in
                        ChatBubble(
                            message: message,
                            isMe: message.senderId == AuthenticationService.shared.currentUser?.id
                        )
                    }
                }
                .padding(12.0)
            }

            // Input bar
            HStack(spacing: 8.0) {
                TextField("Message...", text: $messageText)
                    .textFieldStyle(.roundedBorder)

                Button(action: { Task { await sendMessage() } }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32.0))
                        .foregroundStyle(messageText.isEmpty ? Color.gray : Color(red: 0.2, green: 0.7, blue: 0.4))
                }
                .disabled(messageText.isEmpty || isSending)
            }
            .padding(12.0)
            .background(Color(red: 0.15, green: 0.15, blue: 0.16))
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.12))
        .navigationTitle(room.otherParticipant?.displayName ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMessages()
        }
    }

    private func loadMessages() async {
        isLoading = true
        let baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        let apiKey = AppEnvironment.supabasePublishableKey ?? ""

        guard let url = URL(string: "\(baseURL)/functions/v1/api-v1-chat?mode=food&roomId=\(room.id.uuidString)&limit=50") else {
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = AuthenticationService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(ChatDetailEnvelope.self, from: data)
            messages = envelope.data?.messages ?? []
        } catch {
            // Silently fail
        }

        isLoading = false
    }

    private func sendMessage() async {
        let text = messageText
        guard !text.isEmpty else { return }
        messageText = ""
        isSending = true

        let baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        let apiKey = AppEnvironment.supabasePublishableKey ?? ""

        guard let url = URL(string: "\(baseURL)/functions/v1/api-v1-chat?mode=food&action=message") else {
            isSending = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = AuthenticationService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: String] = ["roomId": room.id.uuidString, "text": text]
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            // Reload messages to show new message
            await loadMessages()
        } catch {
            // Silently fail
        }

        isSending = false
    }
}

private struct ChatBubble: View {
    let message: ChatMessageItem
    let isMe: Bool

    var body: some View {
        HStack {
            if isMe { Spacer() }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 4.0) {
                if let text = message.text, !text.isEmpty {
                    Text(text)
                        .font(.system(size: 15.0))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 12.0)
                        .padding(.vertical, 8.0)
                        .background(isMe ? Color(red: 0.2, green: 0.7, blue: 0.4) : Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16.0))
                }
            }

            if !isMe { Spacer() }
        }
    }
}

private struct ProfileStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4.0) {
            Text(value)
                .font(.system(size: 20.0, weight: .bold))
                .foregroundStyle(Color.white)
            Text(label)
                .font(.system(size: 12.0))
                .foregroundStyle(Color.white.opacity(0.5))
        }
    }
}

#endif
