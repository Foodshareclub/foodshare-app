//
//  ExploreTabView.swift
//  Foodshare
//
//  Explore tab with integrated search, map toggle, and feed
//

import FoodShareDesignSystem
import SwiftUI

// MARK: - Explore Tab View

struct ExploreTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(GuestManager.self) private var guestManager
    @Environment(FeedViewModel.self) private var feedViewModel
    @Environment(\.translationService) private var t
    @Binding var deepLinkListingId: Int?
    @Binding var deepLinkForumPostId: Int?

    @State private var showCreateListing = false
    @State private var showNotifications = false
    @State private var showActivityFeed = false
    @State private var createListingViewModel: CreateListingViewModel?
    @State private var notificationsViewModel: NotificationsViewModel?
    @State private var activityViewModel: ActivityViewModel?
    @State private var searchViewModel: SearchViewModel?
    @State private var mapViewModel: MapViewModel?
    @State private var unreadNotificationCount = 0

    // Search state
    @State private var searchText = ""
    @State private var isSearchActive = false
    @FocusState private var isSearchFocused: Bool

    // Map toggle state (Airbnb-style)
    @State private var showMapView = false
    @State private var showFilters = false
    @State private var showAppInfo = false
    @State private var showSubscriptionPaywall = false

    /// Feature flag manager - using @State to observe changes
    @State private var featureFlagManager = FeatureFlagManager.shared

    /// Premium access - checks feature flag first, then StoreKit/admin status
    private var isPremium: Bool {
        // Free premium trial flag bypasses all premium gates
        if featureFlagManager.isFreePremiumTrialEnabled {
            return true
        }
        // Otherwise check StoreKit subscription or admin status
        return StoreKitService.shared.isPremium
            || AdminAuthorizationService.shared.isAdminUser
            || AdminAuthorizationService.shared.isSuperAdminUser
    }

    /// Navigation state for deep links
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack(alignment: .bottom) {
                // Main content layer - keep both views in memory to preserve state
                ZStack {
                    // List View with Search (always in memory)
                    VStack(spacing: 0) {
                        // Search bar header
                        searchHeader

                        // Content: Feed or Search Results
                        if isSearchActive, let searchVM = searchViewModel {
                            searchResultsView(viewModel: searchVM)
                        } else {
                            FeedView()
                                .environment(feedViewModel)
                                .environment(appState.locationManager)
                        }
                    }
                    .opacity(showMapView || isSearchActive ? 0 : 1)
                    .allowsHitTesting(!showMapView && !isSearchActive)

                    // Map View (always in memory to preserve state)
                    if let mapVM = mapViewModel {
                        MapView(viewModel: mapVM)
                            .environment(appState.locationManager)
                            .opacity(showMapView && !isSearchActive ? 1 : 0)
                            .allowsHitTesting(showMapView && !isSearchActive)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showMapView)
                .animation(.easeInOut(duration: 0.3), value: isSearchActive)

                // Floating buttons overlay
                VStack {
                    Spacer()

                    // Centered Map/List toggle with create button overlay
                    ZStack {
                        // Airbnb-style Map/List toggle button (truly centered)
                        if !isSearchActive {
                            mapListToggleButton
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        // Floating create button (right side) - always visible
                        if !isSearchActive, !showMapView {
                            createButton
                                .padding(.trailing, Spacing.lg)
                        }
                    }
                    .padding(.bottom, Spacing.lg)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .navigationDestination(for: DeepLinkRoute.self) { route in
                switch route {
                case let .listing(id):
                    DeepLinkListingView(listingId: id)
                case let .forumPost(id):
                    DeepLinkForumPostView(postId: id)
                case .challenge, .profile:
                    // These routes are handled by other tabs
                    EmptyView()
                }
            }
            .navigationDestination(for: FoodItem.self) { listing in
                FoodItemDetailView(item: listing)
            }
        }
        .onChange(of: deepLinkListingId) { _, newValue in
            if let listingId = newValue {
                navigationPath.append(DeepLinkRoute.listing(listingId))
                deepLinkListingId = nil // Clear after handling
            }
        }
        .onChange(of: deepLinkForumPostId) { _, newValue in
            if let postId = newValue {
                navigationPath.append(DeepLinkRoute.forumPost(postId))
                deepLinkForumPostId = nil // Clear after handling
            }
        }
        .sheet(isPresented: $showCreateListing) {
            if let viewModel = createListingViewModel {
                CreateListingView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showNotifications) {
            if let viewModel = notificationsViewModel {
                NotificationsView(viewModel: viewModel)
            }
        }
        .onChange(of: showNotifications) { _, isShowing in
            // Refresh notification count when sheet closes (user may have marked as read)
            if !isShowing {
                Task { await refreshNotificationCount() }
            }
        }
        .sheet(isPresented: $showActivityFeed) {
            if let viewModel = activityViewModel {
                NavigationStack {
                    ActivityFeedView(viewModel: viewModel)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(t.t("common.done")) { showActivityFeed = false }
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet()
                .environment(feedViewModel)
        }
        .sheet(isPresented: $showAppInfo) {
            AppInfoSheet()
        }
        .sheet(isPresented: $showSubscriptionPaywall) {
            SubscriptionView()
                .environment(appState)
        }
        .task {
            // Load admin status and feature flags for premium check
            try? await AdminAuthorizationService.shared.refresh()
            try? await featureFlagManager.refresh()
            print(
                "🚩 [FLAGS] Loaded in ExploreTabView - isLoaded=\(featureFlagManager.isLoaded), freePremiumTrial=\(featureFlagManager.isFreePremiumTrialEnabled)",
            )
            setupViewModels()
            await refreshNotificationCount()
            await subscribeToNotificationUpdates()
        }
        .onAppear {
            // Ensure MapViewModel is always initialized to preserve state
            if mapViewModel == nil {
                mapViewModel = MapViewModel(feedRepository: appState.dependencies.feedRepository)
            }
        }
        #if !SKIP
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh notification count when returning from background
            Task { await refreshNotificationCount() }
        }
        #endif
    }

    // MARK: - Search Header

    private var searchHeader: some View {
        TabSearchHeader(
            searchText: $searchText,
            isSearchActive: $isSearchActive,
            isSearchFocused: $isSearchFocused,
            placeholder: t.t("search.placeholder._title"),
            showAppInfo: $showAppInfo,
            onSearchTextChange: { newValue in
                searchViewModel?.searchQuery = newValue
            },
            onSearchSubmit: {
                Task {
                    await searchViewModel?.search()
                }
            },
            onSearchClear: {
                searchViewModel?.clearSearch()
            },
        ) {
            GlassActionButtonWithNotification(
                icon: "slider.horizontal.3",
                unreadCount: unreadNotificationCount,
                accessibilityLabel: t.t("common.filter"),
                onButtonTap: {
                    showFilters = true
                },
                onNotificationTap: {
                    showNotifications = true
                },
            )
        }
    }

    // MARK: - Search Results View

    private func searchResultsView(viewModel: SearchViewModel) -> some View {
        Group {
            if viewModel.isSearching {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text(t.t("status.searching"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .padding(.top, Spacing.md)
                    Spacer()
                }
            } else if viewModel.hasResults {
                ScrollView {
                    LazyVStack(spacing: Spacing.md) {
                        // Category filter chips
                        categoryFilterChips(viewModel: viewModel)

                        // Results
                        ForEach(viewModel.filteredResults) { item in
                            NavigationLink {
                                FoodItemDetailView(item: item)
                            } label: {
                                SearchResultRow(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Spacing.md)
                }
            } else if searchText.isEmpty {
                // Show recent searches and suggestions
                recentSearchesSection(viewModel: viewModel)
            } else {
                ContentUnavailableView(
                    t.t("errors.no_results.title"),
                    systemImage: "magnifyingglass",
                    description: Text(t.t("errors.no_results.description")),
                )
            }
        }
        .background(Color.DesignSystem.background)
    }

    // MARK: - Category Filter Chips

    private func categoryFilterChips(viewModel: SearchViewModel) -> some View {
        // Create binding that converts between ListingCategory? and String?
        let selectedCategoryBinding = Binding<ListingCategory?>(
            get: {
                guard let postType = viewModel.filters.postType else { return nil }
                return ListingCategory.feedCategories.first { $0.rawValue == postType }
            },
            set: { newCategory in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.filters.postType = newCategory?.rawValue
                }
                HapticManager.selection()
                Task { await viewModel.search() }
            },
        )

        return GlassCategoryBar(
            selectedCategory: selectedCategoryBinding,
            categories: ListingCategory.feedCategories,
            showAllOption: true,
            localizedTitleProvider: { category in
                category.localizedDisplayName(using: t)
            },
        )
    }

    // MARK: - Recent Searches Section

    private func recentSearchesSection(viewModel: SearchViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if !viewModel.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        HStack {
                            Text(t.t("search.recent._title"))
                                .font(.DesignSystem.headlineSmall)
                                .foregroundColor(.DesignSystem.text)

                            Spacer()

                            Button(t.t("search.clear")) {
                                viewModel.clearRecentSearches()
                            }
                            .font(.DesignSystem.caption)
                            .foregroundColor(.DesignSystem.brandGreen)
                        }

                        FlowLayout(spacing: Spacing.sm) {
                            ForEach(viewModel.recentSearches, id: \.self) { search in
                                Button {
                                    searchText = search
                                    viewModel.selectRecentSearch(search)
                                } label: {
                                    HStack(spacing: Spacing.xs) {
                                        Image(systemName: "clock.arrow.circlepath")
                                            .font(.system(size: 12))
                                        Text(search)
                                            .font(.DesignSystem.bodySmall)
                                    }
                                    .foregroundColor(.DesignSystem.text)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, Spacing.xs)
                                    .background(
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                            .overlay(
                                                Capsule()
                                                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                            ),
                                    )
                                }
                            }
                        }
                    }
                }

                // Popular categories section
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text(t.t("search.categories"))
                        .font(.DesignSystem.headlineSmall)
                        .foregroundColor(.DesignSystem.text)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                    ], spacing: Spacing.sm) {
                        ForEach(ListingCategory.feedCategories) { category in
                            Button {
                                viewModel.filters.postType = category.rawValue
                                Task { await viewModel.searchNearby() }
                            } label: {
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: category.icon)
                                        .font(.title2)
                                        .foregroundColor(category.color)
                                    Text(category.localizedDisplayName(using: t))
                                        .font(.DesignSystem.bodyMedium)
                                        .foregroundColor(.DesignSystem.text)
                                    Spacer()
                                }
                                .padding(Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                        ),
                                )
                            }
                        }
                    }
                }
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Map/List Toggle Button (Airbnb-style)

    private var mapListToggleButton: some View {
        let isMapLocked = !showMapView && !isPremium

        return Button {
            // Debug: Log premium check values
            print("🔓 [MAP] isPremium=\(isPremium), isMapLocked=\(isMapLocked)")
            print("🔓 [MAP] StoreKit.isPremium=\(StoreKitService.shared.isPremium)")
            print("🔓 [MAP] isAdmin=\(AdminAuthorizationService.shared.isAdminUser)")
            print("🔓 [MAP] isSuperAdmin=\(AdminAuthorizationService.shared.isSuperAdminUser)")
            print("🔓 [MAP] freePremiumTrial=\(featureFlagManager.isFreePremiumTrialEnabled)")
            print("🔓 [MAP] flagsLoaded=\(featureFlagManager.isLoaded)")
            print("🔓 [MAP] isGuestMode=\(guestManager.isGuestMode)")

            // Map view requires premium (switching TO map, not FROM map)
            if isMapLocked {
                showSubscriptionPaywall = true
                HapticManager.medium()
                return
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showMapView.toggle()
            }
            HapticManager.medium()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: showMapView ? "list.bullet" : "map.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(t.t(showMapView ? "search.show_posts" : "search.show_map"))
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.brandGreen,
                                Color.DesignSystem.brandBlue,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing,
                        ),
                    ),
            )
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            .overlay(alignment: .topTrailing) {
                if isMapLocked {
                    premiumBadge
                        .offset(x: 8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Premium badge overlay for locked features
    private var premiumBadge: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .black))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                LinearGradient(
                    colors: [.DesignSystem.brandPink, .DesignSystem.brandPurple],
                    startPoint: .leading,
                    endPoint: .trailing,
                ),
            )
            .clipShape(Capsule())
            .shadow(color: .DesignSystem.brandPink.opacity(0.5), radius: 4, y: 2)
    }

    // MARK: - Create Button (matches Show Map style)

    private var createButton: some View {
        Button {
            HapticManager.medium()
            if guestManager.isGuestMode {
                // Guest users: Show upgrade prompt sheet
                guestManager.promptSignUp(for: .createListing)
            } else if appState.currentUser != nil {
                showCreateListing = true
            } else {
                appState.showAuthentication = true
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.vertical, Spacing.md)
                .padding(.horizontal, Spacing.md)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen,
                                    Color.DesignSystem.brandBlue,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        ),
                )
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Activity Feed Button

    private var activityFeedButton: some View {
        Button {
            HapticManager.light()
            showActivityFeed = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16))
                .foregroundColor(.DesignSystem.text)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                        ),
                )
        }
    }

    // MARK: - Notification Bell Button

    private var notificationBellButton: some View {
        Button {
            HapticManager.light()
            showNotifications = true
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.DesignSystem.text)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                            ),
                    )

                // Notification badge
                if unreadNotificationCount > 0 {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                            .frame(width: 18, height: 18)

                        Text(unreadNotificationCount > 99 ? "99+" : "\(unreadNotificationCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(x: 4, y: -4)
                    .shadow(color: .DesignSystem.brandGreen.opacity(0.5), radius: 4)
                }
            }
        }
    }

    // MARK: - Refresh Notification Count

    private func refreshNotificationCount() async {
        guard let userId = appState.currentUser?.id else { return }

        do {
            unreadNotificationCount = try await appState.dependencies.notificationRepository
                .fetchUnreadCount(for: userId)
        } catch {
            await AppLogger.shared.error("Failed to fetch notification count", error: error)
        }
    }

    // MARK: - Real-Time Notification Subscription

    /// Subscribe to real-time notifications via Supabase Realtime.
    /// Updates the badge count when new notifications arrive.
    private func subscribeToNotificationUpdates() async {
        guard let userId = appState.currentUser?.id else { return }

        await appState.dependencies.notificationRepository.subscribeToNotifications(
            for: userId,
        ) { [self] notification in
            // Increment count for new unread notifications
            if !notification.isRead {
                unreadNotificationCount += 1
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: Spacing.lg) {
            // Animated loading icon with glass effect
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .DesignSystem.brandGreen.opacity(0.5),
                                        .DesignSystem.brandBlue.opacity(0.3),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 2,
                            ),
                    )

                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.DesignSystem.brandGreen)
            }

            Text(t.t("status.loading"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.DesignSystem.background)
    }

    // MARK: - Setup

    private func setupViewModels() {
        let deps = appState.dependencies

        // Note: FeedViewModel is now provided via @Environment from FoodShareApp
        // This ensures consistent search radius and feed state across all tabs

        // Setup SearchViewModel
        if searchViewModel == nil {
            searchViewModel = SearchViewModel(
                repository: deps.feedRepository,
                searchRepository: deps.searchRepository,
                locationService: appState.locationManager,
            )
        }

        // Setup CreateListingViewModel
        if createListingViewModel == nil {
            createListingViewModel = CreateListingViewModel(repository: deps.listingRepository)
        }

        // Setup NotificationsViewModel
        if notificationsViewModel == nil, let userId = appState.currentUser?.id {
            notificationsViewModel = NotificationsViewModel(repository: deps.notificationRepository, userId: userId)
        }

        // Setup ActivityViewModel (community-wide activity feed)
        if activityViewModel == nil {
            activityViewModel = ActivityViewModel(
                repository: appState.dependencies.activityRepository,
                client: appState.authService.supabase,
            )
        }

        // Setup MapViewModel - always initialize to preserve state
        if mapViewModel == nil {
            mapViewModel = MapViewModel(feedRepository: appState.dependencies.feedRepository)
        }
    }
}
