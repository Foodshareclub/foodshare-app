//
//  FeedView.swift
//  Foodshare
//
//  Airbnb-style Explore tab with search pill and category bar
//  Premium glassmorphism with 120Hz ProMotion animations
//  Liquid Glass v27 design system with GPU-accelerated rendering
//

import FoodShareDesignSystem
import OSLog
import SwiftUI

#if DEBUG
    import Inject
#endif

private let feedLogger = Logger(subsystem: "com.flutterflow.foodshare", category: "FeedView")

struct FeedView: View {

    @Environment(\.translationService) private var t
    @Environment(FeedViewModel.self) private var viewModel
    @Environment(LocationManager.self) private var locationManager
    @Environment(AppState.self) private var appState
    @State private var showShareNow = false
    @State private var locationError: LocationError?
    @State private var showLocationError = false
    @State private var selectedListingCategory: ListingCategory? = .food

    // ProMotion animation states for 120Hz smooth transitions
    @State private var hasAppeared = false
    @State private var cardAppearanceStates = LimitedDictionary<Int, Bool>(maxCapacity: 50)
    @State private var refreshPulse = false
    @State private var scrollOffset: CGFloat = 0

    /// Cached index lookup for O(1) access
    private var listingIndexCache: [Int: Int] {
        Dictionary(uniqueKeysWithValues: filteredListings.enumerated().map { ($1.id, $0) })
    }

    var body: some View {
        ZStack {
            // Background
            Color.DesignSystem.background
                .ignoresSafeArea()

            // Main content
            VStack(spacing: 0) {
                // Airbnb-style Category Bar with ProMotion 120Hz animation
                GlassCategoryBar(
                    selectedCategory: $selectedListingCategory,
                    categories: ListingCategory.feedCategories,
                    showAllOption: false,
                    localizedTitleProvider: { category in
                        category.localizedDisplayName(using: t)
                    },
                )
                .opacity(hasAppeared ? 1 : 0)
                .animation(ProMotionAnimation.smooth.delay(0.1), value: hasAppeared)
                .onChange(of: selectedListingCategory) { _, newValue in
                    HapticManager.light()
                    Task {
                        await viewModel.filterByPostType(newValue?.rawValue)
                    }
                }

                // Subtle divider below categories
                Rectangle()
                    .fill(Color.DesignSystem.glassBorder.opacity(0.15))
                    .frame(height: 1)

                // Content area
                if viewModel.isLoading, !viewModel.hasListings {
                    loadingView
                } else if viewModel.loadingFailed, !viewModel.hasListings {
                    // Graceful degradation: inline empty state for quota/network errors
                    Spacer()
                    loadingFailedStateView
                    Spacer()
                } else if !viewModel.hasListings {
                    Spacer()
                    emptyStateView
                    Spacer()
                } else {
                    feedContent
                }
            }
        }
        .onAppear {
            // ProMotion 120Hz entrance animation
            withAnimation(ProMotionAnimation.smooth) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showShareNow) {
            ShareNowView()
                .environment(appState)
        }
        .alert(t.t("common.error.title"), isPresented: Binding(
            get: { viewModel.showError },
            set: { if !$0 { viewModel.dismissError() } },
        )) {
            Button(t.t("common.ok"), role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.localizedErrorMessage(using: t))
        }
        .alert(t.t("feed.location_required"), isPresented: $showLocationError) {
            Button(t.t("common.settings"), role: .cancel) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(t.t("common.cancel"), role: .cancel) {
                showLocationError = false
            }
        } message: {
            if let error = locationError {
                Text(error.errorDescription ?? error.localizedDescription)
            } else {
                Text(t.t("feed.location_required"))
            }
        }
        .task {
            await loadDataWithLocation()
        }
    }

    // MARK: - Feed Content

    private var feedContent: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {

                // Trending section (when available and not filtered)
                if viewModel.hasTrendingItems, selectedListingCategory == nil {
                    trendingSection
                        .staggeredAppearance(index: 1, baseDelay: 0.05)
                }

                // Urgent items alert (expiring soon)
                if viewModel.hasUrgentItems, selectedListingCategory == nil {
                    urgentItemsAlert
                        .staggeredAppearance(index: 2, baseDelay: 0.05)
                }

                // Listings Grid/List based on view mode
                switch viewModel.viewMode {
                case .list:
                    listingsList
                case .grid:
                    listingsGrid
                }

                // Loading more indicator
                if viewModel.isLoadingMore {
                    loadingMoreIndicator
                        .padding(.vertical, Spacing.md)
                }

                // Bottom padding for floating elements
                Color.clear.frame(height: Spacing.xl)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.md)
        }
        .refreshable {
            // Trigger refresh pulse animation with ProMotion 120Hz
            withAnimation(ProMotionAnimation.quick) {
                refreshPulse = true
            }
            HapticManager.light()
            await viewModel.refresh()
            // Reset card states for fresh animations
            cardAppearanceStates.removeAll()
            withAnimation(ProMotionAnimation.smooth) {
                refreshPulse = false
            }
        }
    }

    // MARK: - Trending Section

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.orange)

                Text(t.t("feed.trending_near_you"))
                    .font(.DesignSystem.labelLarge)
                    .foregroundColor(.DesignSystem.text)
            }
            .padding(.horizontal, Spacing.md)

            GlassHorizontalScroll(spacing: Spacing.md, padding: Spacing.md) {
                ForEach(viewModel.trendingItems) { item in
                    NavigationLink(value: item) {
                        TrendingItemCard(item: item)
                    }
                    .buttonStyle(ProMotionButtonStyle())
                }
            }
        }
    }

    // MARK: - Urgent Items Alert

    private var urgentItemsAlert: some View {
        Button {
            // Could filter to show only urgent items
            HapticManager.light()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "exclamationmark.clock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.DesignSystem.warning)

                VStack(alignment: .leading, spacing: 2) {
                    Text(t.t("feed.items_expiring_soon", args: ["count": String(viewModel.urgentItems.count)]))
                        .font(.DesignSystem.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.text)

                    Text(t.t("feed.help_reduce_waste"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.DesignSystem.textTertiary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.DesignSystem.warning.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(Color.DesignSystem.warning.opacity(0.3), lineWidth: 1),
                    ),
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Listings Grid

    @ViewBuilder
    private var listingsGrid: some View {
        let indexCache = listingIndexCache
        LazyVStack(spacing: Spacing.md) {
            ForEach(filteredListings, id: \.id) { listing in
                listingRow(listing, indexCache: indexCache)
            }
        }
    }

    // MARK: - Listings List (Compact View)

    @ViewBuilder
    private var listingsList: some View {
        let indexCache = listingIndexCache
        LazyVStack(spacing: Spacing.sm) {
            ForEach(filteredListings, id: \.id) { listing in
                let index = indexCache[listing.id] ?? 0
                let isVisible = cardAppearanceStates.isTrue(listing.id)
                NavigationLink(value: listing) {
                    CompactListingRow(
                        item: listing,
                        isSaved: viewModel.isItemSaved(listing.id),
                        onSave: { viewModel.toggleSaveItem(listing.id) },
                    )
                    .opacity(isVisible ? 1 : 0)
                    .offset(x: isVisible ? 0 : -20)
                    .onAppear {
                        let delay = min(Double(index) * 0.03, 0.2)
                        withAnimation(ProMotionAnimation.smooth.delay(delay)) {
                            cardAppearanceStates.markTrue(listing.id)
                        }
                        viewModel.markItemViewed(listing.id)
                    }
                }
                .buttonStyle(ProMotionButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func listingRow(_ listing: FoodItem, indexCache: [Int: Int]) -> some View {
        let index = indexCache[listing.id] ?? 0
        let isVisible = cardAppearanceStates.isTrue(listing.id)
        NavigationLink(value: listing) {
            GlassListingCard(
                item: listing,
                useGPURasterization: true,
                enableParallax: index < 5,
                style: .modern,
            )
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 30)
            .scaleEffect(isVisible ? 1 : 0.95)
            .onAppear {
                // Staggered ProMotion 120Hz animation for card appearance
                let delay = min(Double(index) * 0.04, 0.25)
                withAnimation(ProMotionAnimation.smooth.delay(delay)) {
                    cardAppearanceStates.markTrue(listing.id)
                }
            }
        }
        .buttonStyle(ProMotionButtonStyle())
    }

    // MARK: - Loading More Indicator

    private var loadingMoreIndicator: some View {
        HStack(spacing: Spacing.sm) {
            ProgressView()
                .tint(Color.DesignSystem.brandGreen)

            Text(t.t("feed.loading_more"))
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .padding(Spacing.md)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    // MARK: - Filtered Listings

    private var filteredListings: [FoodItem] {
        viewModel.filteredListings
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Header section
                loadingHeader

                // Skeleton cards
                ForEach(0 ..< 4, id: \.self) { index in
                    FeedSkeletonCard()
                        .staggeredAppearance(index: index)
                }
            }
            .padding(Spacing.md)
        }
    }

    private var loadingHeader: some View {
        VStack(spacing: Spacing.lg) {
            // Premium glass loading indicator (Nature Green/Blue theme)
            ZStack {
                // Outer glow ring
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.2),
                                Color.DesignSystem.brandBlue.opacity(0.1),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50,
                        ),
                    )
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)

                // Animated gradient ring
                Circle()
                    .trim(from: 0, to: 0.65)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                Color.DesignSystem.brandGreen,
                                Color.DesignSystem.brandBlue,
                                Color.DesignSystem.brandGreen.opacity(0.3),
                            ]),
                            center: .center,
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round),
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))
                    .modifier(RotatingModifier())

                // Center icon
                Image(systemName: "fork.knife")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }

            // Loading text
            VStack(spacing: Spacing.xs) {
                Text(t.t("feed.loading_title"))
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)

                Text(t.t("feed.loading_subtitle"))
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            .multilineTextAlignment(.center)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        Group {
            if appState.isAuthenticated {
                // For authenticated users - show enhanced Share Now prompt
                authenticatedEmptyState
            } else {
                // For guests - show sign in prompt
                guestEmptyState
            }
        }
    }

    private var authenticatedEmptyState: some View {
        VStack(spacing: Spacing.md) {
            // Animated hero icon
            ZStack {
                // Outer glow rings
                ForEach(0 ..< 2) { index in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.2 - Double(index) * 0.08),
                                    Color.DesignSystem.brandBlue.opacity(0.12 - Double(index) * 0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                            lineWidth: 1.5,
                        )
                        .frame(width: 56 + CGFloat(index) * 16, height: 56 + CGFloat(index) * 16)
                }

                // Main icon container
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.brandGreen.opacity(0.9),
                                    Color.DesignSystem.brandBlue.opacity(0.85),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.DesignSystem.brandGreen.opacity(0.3), radius: 12, y: 4)

                    Image(systemName: "gift.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .floating(distance: 4, duration: 3)

            VStack(spacing: Spacing.xs) {
                Text(t.t("feed.be_first_to_share"))
                    .font(.LiquidGlass.titleMedium)
                    .foregroundColor(.DesignSystem.text)
                    .multilineTextAlignment(.center)

                Text(t.t("feed.empty_state_subtitle"))
                    .font(.LiquidGlass.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Share Now button
            Button {
                HapticManager.medium()
                showShareNow = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))

                    Text(t.t("feed.share_now"))
                        .font(.LiquidGlass.labelMedium)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: 160)
                .padding(.vertical, Spacing.sm)
                .background(
                    LinearGradient(
                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                        startPoint: .leading,
                        endPoint: .trailing,
                    ),
                )
                .clipShape(Capsule())
                .shadow(color: Color.DesignSystem.brandGreen.opacity(0.4), radius: 10, y: 4)
            }
            .pressAnimation()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.lg)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.lg)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .padding(.horizontal, Spacing.lg)
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    private var guestEmptyState: some View {
        VStack(spacing: Spacing.md) {
            // Compact animated icon
            ZStack {
                // Subtle glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.DesignSystem.brandGreen.opacity(0.15),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 50,
                        ),
                    )
                    .frame(width: 80, height: 80)
                    .blur(radius: 10)

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .floating()
            }

            VStack(spacing: Spacing.xs) {
                Text(t.t("feed.no_listings_title"))
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(.DesignSystem.text)

                Text(t.t("feed.guest_empty_subtitle"))
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            GlassButton(
                t.t("feed.sign_in_to_share"),
                icon: "arrow.right.circle.fill",
                style: .primary,
            ) {
                HapticManager.medium()
                appState.showAuthentication = true
            }
            .frame(maxWidth: 180)
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.xl)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.xl)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .padding(.horizontal, Spacing.xl)
        .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }

    // MARK: - Loading Failed State (Graceful Degradation)

    /// Subtle, non-blocking empty state for quota exceeded or network failures
    private var loadingFailedStateView: some View {
        VStack(spacing: Spacing.lg) {
            // Subtle glass container with cloud/offline icon
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.glassBorder,
                                        Color.DesignSystem.textSecondary.opacity(0.3),
                                        Color.DesignSystem.glassBorder,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1,
                            ),
                    )

                Image(systemName: "icloud.slash")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .padding(.bottom, Spacing.sm)

            VStack(spacing: Spacing.sm) {
                Text(t.t("feed.offline.title"))
                    .font(.DesignSystem.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("feed.offline.description"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // Subtle retry button
            Button {
                HapticManager.light()
                Task { await viewModel.loadFoodItems(forceRefresh: true) }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                    Text(t.t("common.action.try_again"))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)
                }
                .foregroundColor(.DesignSystem.brandGreen)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .stroke(Color.DesignSystem.brandGreen.opacity(0.3), lineWidth: 1),
                        ),
                )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.xl)
    }

    // MARK: - Helpers

    private func loadDataWithLocation() async {
        feedLogger.notice("📍 loadDataWithLocation() started")

        // Strategy 1: Try GPS location (most accurate)
        do {
            // Request permission if needed
            if !locationManager.isAuthorized {
                feedLogger.notice("📍 Location not authorized, requesting permission...")
                try await locationManager.requestPermission()
            } else {
                feedLogger.notice("📍 Location already authorized")
            }

            // Get current location
            feedLogger.notice("📍 Getting current location...")
            let location = try await locationManager.getCurrentLocation()
            feedLogger.notice("📍 Got GPS location: \(location.latitude), \(location.longitude)")

            // Load feed data with GPS location
            await viewModel.loadInitialData(
                latitude: location.latitude,
                longitude: location.longitude,
            )
            feedLogger.notice("📍 loadInitialData() completed with GPS location")
            return
        } catch let error as LocationError {
            feedLogger.notice("📍 GPS location failed: \(error.localizedDescription), trying IP geolocation...")
        } catch {
            feedLogger.notice("📍 GPS location failed: \(error.localizedDescription), trying IP geolocation...")
        }

        // Strategy 2: Fall back to IP-based geolocation
        do {
            feedLogger.notice("📍 Attempting IP geolocation fallback...")
            let ipLocation = try await IPGeolocationService.shared.getLocationFromIP()
            feedLogger.notice("📍 Got IP location: \(ipLocation.latitude), \(ipLocation.longitude)")

            // Load feed data with IP location (use wider radius since less accurate)
            await viewModel.loadInitialData(
                latitude: ipLocation.latitude,
                longitude: ipLocation.longitude,
            )
            feedLogger.notice("📍 loadInitialData() completed with IP location")
        } catch {
            feedLogger.error("❌ IP geolocation also failed: \(error.localizedDescription)")
            // Both GPS and IP failed - show error
            locationError = .locationUnavailable
            showLocationError = true
        }
    }
}

// Note: FilterSheet, FeedSkeletonCard, TrendingItemCard, CompactListingRow, FeedStatPill,
// FullSearchSheet, SearchTab, RecentSearchRow, and RotatingModifier have been extracted
// to separate files in the Components/ subdirectory for better organization and maintainability.
