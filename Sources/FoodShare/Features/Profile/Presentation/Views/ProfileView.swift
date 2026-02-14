//
//  ProfileView.swift
//  Foodshare
//
//  Refactored with Swift 6 bleeding-edge practices:
//  - Composable view architecture with extracted components
//  - Type-safe navigation with NavigationPath
//  - Modern @Observable binding patterns
//  - Accessibility-first design
//

import CoreImage.CIFilterBuiltins
import FoodShareDesignSystem
import Kingfisher
import PhotosUI
import SwiftUI

#if DEBUG
    import Inject
#endif

// MARK: - Profile View

struct ProfileView: View {

    @Environment(AppState.self) private var appState
    @Environment(\.translationService) private var t
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: ProfileViewModel
    @Binding var navigationPath: NavigationPath
    @State private var showSignOutAlert = false
    @State private var showEditProfile = false
    @State private var showAvatarDetail = false
    @State private var showQRCode = false
    @State private var showBlockUser = false
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var showAppInfo = false
    @State private var unreadNotificationCount = 0
    @State private var showNotifications = false
    @FocusState private var isSearchFocused: Bool

    init(viewModel: ProfileViewModel, navigationPath: Binding<NavigationPath>) {
        _viewModel = State(initialValue: viewModel)
        _navigationPath = navigationPath
    }

    var body: some View {
        ZStack {
            Color.DesignSystem.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search header matching Explore/Chats/Forum pattern
                profileSearchHeader

                ProfileContentView(
                    viewModel: viewModel,
                    showEditProfile: $showEditProfile,
                    showSignOutAlert: $showSignOutAlert,
                    showAvatarDetail: $showAvatarDetail,
                    showQRCode: $showQRCode,
                    showBlockUser: $showBlockUser,
                    searchText: searchText,
                )
            }
        }
        .navigationBarHidden(true)
        .navigationTitle(t.t("tabs.profile"))
        .sheet(isPresented: $showEditProfile) {
            if let deps = dependencies, let userId = appState.currentUser?.id {
                EditProfileView(
                    repository: deps.profileRepository,
                    userId: userId,
                    profile: viewModel.profile,
                )
            }
        }
        .sheet(isPresented: $showAvatarDetail) {
            AvatarDetailView(avatarUrl: viewModel.profile?.avatarUrl)
        }
        .sheet(isPresented: $showQRCode) {
            if let profile = viewModel.profile {
                ProfileQRCodeView(profile: profile)
            }
        }
        .sheet(isPresented: $showAppInfo) {
            AppInfoSheet()
        }
        .sheet(isPresented: $showNotifications) {
            if let userId = appState.currentUser?.id {
                NotificationsView(
                    viewModel: NotificationsViewModel(
                        repository: appState.dependencies.notificationRepository,
                        userId: userId,
                    ),
                )
            }
        }
        .sheet(isPresented: $showBlockUser) {
            if let profile = viewModel.profile {
                // TODO: Fix BlockUserSheet - temporarily disabled
                // BlockUserSheet(
                //     userId: profile.id,
                //     userName: profile.nickname,
                //     userAvatar: profile.avatarUrl,
                // )
            }
        }
        .alert(t.t("profile.sign_out"), isPresented: $showSignOutAlert) {
            Button(t.t("common.cancel"), role: .cancel) {}
            Button(t.t("profile.sign_out"), role: .destructive) {
                Task { await appState.signOut() }
            }
        } message: {
            Text(t.t("profile.sign_out_confirm"))
        }
        .alert(item: $viewModel.alertItem) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(t.t("common.ok"))),
            )
        }
        .task {
            await viewModel.loadProfile()
            await refreshNotificationCount()
        }
        .refreshable { await viewModel.refresh() }
        .onChange(of: showNotifications) { _, isShowing in
            // Refresh notification count when sheet closes (user may have marked as read)
            if !isShowing {
                Task { await refreshNotificationCount() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Refresh notification count when returning from background
            Task { await refreshNotificationCount() }
        }
    }

    // MARK: - Search Header (using unified TabSearchHeader)

    @State private var settingsGearRotation: Double = 0

    private var profileSearchHeader: some View {
        TabSearchHeader(
            searchText: $searchText,
            isSearchActive: $isSearchActive,
            isSearchFocused: $isSearchFocused,
            placeholder: t.t("profile.search_placeholder"),
            showAppInfo: $showAppInfo,
        ) {
            // Show block button when viewing another user's profile
            if !viewModel.isOwnProfile, viewModel.hasProfile {
                Menu {
                    Button(role: .destructive) {
                        showBlockUser = true
                    } label: {
                        Label(t.t("settings.block_user"), systemImage: "hand.raised.fill")
                    }
                } label: {
                    GlassActionButton(
                        icon: "ellipsis",
                        accessibilityLabel: t.t("common.more_options"),
                        action: {},
                    )
                }
            }

            // Show settings gear with notification indicator when viewing own profile
            if viewModel.isOwnProfile {
                GlassActionButtonWithNotification(
                    icon: "gearshape",
                    unreadCount: unreadNotificationCount,
                    rotationDegrees: settingsGearRotation,
                    accessibilityLabel: t.t("settings.title"),
                    onButtonTap: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            settingsGearRotation += 90
                        }
                        navigationPath.append(ProfileDestination.settings)
                    },
                    onNotificationTap: {
                        showNotifications = true
                    },
                )
            }
        }
    }

    // MARK: - Notification Count

    private func refreshNotificationCount() async {
        guard let userId = appState.currentUser?.id else { return }

        do {
            unreadNotificationCount = try await appState.dependencies.notificationRepository
                .fetchUnreadCount(for: userId)
        } catch {
            await AppLogger.shared.error("Failed to fetch notification count", error: error)
        }
    }

    // MARK: - Block User Action

    private func blockUser(userId: UUID, blockedUserId: UUID, reason: String?) async {
        guard let deps = dependencies else { return }

        do {
            try await deps.profileRepository.blockUser(
                userId: userId,
                blockedUserId: blockedUserId,
                reason: reason,
            )

            HapticManager.success()

            // Show success message
            viewModel.alertItem = AlertItem(
                title: t.t("settings.user_blocked"),
                message: t.t("settings.user_blocked_description"),
            )

            // Navigate back or refresh feed
            // await appState.feedViewModel.refresh()

        } catch {
            HapticManager.error()
            viewModel.alertItem = AlertItem(
                title: t.t("common.error.title"),
                message: error.localizedDescription,
            )
        }
    }
}

// MARK: - Navigation Destination Enum

enum ProfileDestination: Hashable {
    case listings(userId: UUID, repository: ListingRepository)
    case history(userId: UUID, repository: ListingRepository)
    case badges(collection: BadgeCollection, stats: ForumUserStats)
    case reviews(reviews: [Review], userName: String, rating: Double)
    case forum
    case settings
    case notifications
    case help

    static func == (lhs: ProfileDestination, rhs: ProfileDestination) -> Bool {
        switch (lhs, rhs) {
        case let (.listings(l, _), .listings(r, _)): l == r
        case let (.history(l, _), .history(r, _)): l == r
        case let (.badges(lc, ls), .badges(rc, rs)): lc.earnedBadges.count == rc.earnedBadges.count && ls
            .profileId == rs.profileId
        case let (.reviews(lr, _, _), .reviews(rr, _, _)): lr.map(\.id) == rr.map(\.id)
        case (.forum, .forum), (.settings, .settings), (.notifications, .notifications), (.help, .help): true
        default: false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case let .listings(id, _): hasher.combine("listings"); hasher.combine(id)
        case let .history(id, _): hasher.combine("history"); hasher.combine(id)
        case let .badges(c, _): hasher.combine("badges"); hasher.combine(c.earnedBadges.count)
        case let .reviews(r, _, _): hasher.combine("reviews"); hasher.combine(r.count)
        case .forum: hasher.combine("forum")
        case .settings: hasher.combine("settings")
        case .notifications: hasher.combine("notifications")
        case .help: hasher.combine("help")
        }
    }
}

// MARK: - Profile Content View

private struct ProfileContentView: View {
    @Environment(\.translationService) private var t
    @Bindable var viewModel: ProfileViewModel
    @Binding var showEditProfile: Bool
    @Binding var showSignOutAlert: Bool
    @Binding var showAvatarDetail: Bool
    @Binding var showQRCode: Bool
    @Binding var showBlockUser: Bool
    var searchText = ""

    // MARK: - Search Filtering

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchQuery: String {
        searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredReviews: [Review] {
        guard isSearching else { return viewModel.reviews }
        return viewModel.reviews.filter { review in
            review.feedback.lowercased().contains(searchQuery) ||
                review.reviewer?.nickname?.lowercased().contains(searchQuery) == true
        }
    }

    private var filteredBadges: [UserBadgeWithDetails] {
        guard isSearching, let collection = viewModel.badgeCollection else {
            return viewModel.badgeCollection?.earnedBadges ?? []
        }
        return collection.earnedBadges.filter { badgeWithDetails in
            badgeWithDetails.badge.name.lowercased().contains(searchQuery) ||
                badgeWithDetails.badge.description.lowercased().contains(searchQuery)
        }
    }

    private var hasSearchResults: Bool {
        !filteredReviews.isEmpty || !filteredBadges.isEmpty
    }

    var body: some View {
        ZStack {
            Color.backgroundGradient.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: Spacing.md) {
                    if viewModel.isLoading, !viewModel.hasProfile {
                        ProfileLoadingView()
                    } else if viewModel.hasProfile {
                        if isSearching {
                            searchResultsContent
                        } else {
                            profileContent
                        }
                    }
                }
                .padding(Spacing.md)
            }
        }
    }

    // MARK: - Search Results Content

    @ViewBuilder
    private var searchResultsContent: some View {
        if hasSearchResults {
            // Show filtered badges if any match
            if !filteredBadges.isEmpty {
                FilteredBadgesSection(badges: filteredBadges, searchQuery: searchQuery)
            }

            // Show filtered reviews if any match
            if !filteredReviews.isEmpty {
                FilteredReviewsSection(reviews: filteredReviews, searchQuery: searchQuery)
            }
        } else {
            // No results empty state
            emptySearchState
        }
    }

    private var emptySearchState: some View {
        VStack(spacing: Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(width: 80, height: 80)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            VStack(spacing: Spacing.sm) {
                Text(t.t("common.no_results"))
                    .font(.LiquidGlass.headlineMedium)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("profile.search.no_match", args: ["query": searchText]))
                    .font(.LiquidGlass.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    @ViewBuilder
    private var profileContent: some View {
        ProfileHeaderSection(
            viewModel: viewModel,
            showAvatarDetail: $showAvatarDetail,
            showQRCode: $showQRCode,
        )

        // Level Progress Card (Phase 2)
        if let profile = viewModel.profile {
            LevelProgressCard(profile: profile)
        }

        // Streak Indicator (Phase 2)
        StreakIndicatorCard()

        if !viewModel.isProfileComplete {
            ProfileCompletionCard(
                completion: viewModel.profileCompletion,
                onTap: { showEditProfile = true },
            )
        }

        ProfileStatsSection(viewModel: viewModel)
        ImpactStatsSection(
            stats: viewModel.impactStats,
            memberSince: viewModel.memberSince,
            memberDuration: viewModel.memberDuration,
        )

        if viewModel.hasBadges || viewModel.isLoadingBadges {
            BadgesSection(viewModel: viewModel)
        }

        if viewModel.hasReviews || viewModel.isLoadingReviews {
            ReviewsSection(viewModel: viewModel)
        }

        ProfileActionsSection(
            viewModel: viewModel,
            showSignOutAlert: $showSignOutAlert,
        )
    }
}

// MARK: - Filtered Badges Section

private struct FilteredBadgesSection: View {
    @Environment(\.translationService) private var t
    let badges: [UserBadgeWithDetails]
    let searchQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label(t.t("profile.badges"), systemImage: "medal.fill")
                    .font(.LiquidGlass.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                Text(t.t("profile.search.found", args: ["count": "\(badges.count)"]))
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            GlassHorizontalScroll.compact {
                ForEach(badges) { badgeWithDetails in
                    GlassBadgeItem(
                        badge: badgeWithDetails.badge,
                        isEarned: true,
                        isFeatured: badgeWithDetails.userBadge.isFeatured,
                        progress: nil,
                        onTap: nil,
                    )
                    .frame(width: 72)
                }
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

// MARK: - Filtered Reviews Section

private struct FilteredReviewsSection: View {
    @Environment(\.translationService) private var t
    let reviews: [Review]
    let searchQuery: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "star.bubble.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                    Text(t.t("profile.reviews"))
                        .font(.LiquidGlass.headlineSmall)
                        .foregroundStyle(Color.DesignSystem.text)
                }

                Spacer()

                Text(t.t("profile.search.found", args: ["count": "\(reviews.count)"]))
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            ForEach(reviews) { review in
                ReviewCard(review: review)
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

// MARK: - Profile Header Section

private struct ProfileHeaderSection: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel
    @Binding var showAvatarDetail: Bool
    @Binding var showQRCode: Bool

    var body: some View {
        VStack(spacing: Spacing.md) {
            EnhancedProfileAvatarView(
                avatarUrl: viewModel.profile?.avatarUrl,
                onTap: {
                    showAvatarDetail = true
                    HapticManager.medium()
                },
            )

            Text(viewModel.localizedDisplayName(using: t))
                .font(.LiquidGlass.headlineLarge)
                .foregroundStyle(Color.DesignSystem.text)
                .accessibilityAddTraits(.isHeader)

            if let bio = viewModel.profile?.bio, !bio.isEmpty {
                Text(bio)
                    .font(.LiquidGlass.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let location = viewModel.profile?.location, !location.isEmpty {
                Label(location, systemImage: "location.fill")
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            // Share Profile Button
            Button {
                showQRCode = true
                HapticManager.light()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "qrcode")
                    Text(t.t("profile.share_profile"))
                }
                .font(.LiquidGlass.labelMedium)
                .foregroundStyle(Color.DesignSystem.themed.primary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(Color.DesignSystem.themed.primary.opacity(0.15))
                .clipShape(Capsule())
            }
            .padding(.top, Spacing.xs)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .glassEffect(cornerRadius: CornerRadius.xl)
    }
}

// MARK: - Enhanced Profile Avatar View (with Kingfisher)

private struct EnhancedProfileAvatarView: View {
    @Environment(\.translationService) private var t
    let avatarUrl: String?
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Group {
            if let avatarUrl, let url = URL(string: avatarUrl) {
                KFImage(url)
                    .placeholder {
                        ShimmerPlaceholder()
                    }
                    .fade(duration: 0.3)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 100, height: 100)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(
                LinearGradient(
                    colors: [Color.DesignSystem.themed.gradientStart, Color.DesignSystem.themed.gradientEnd],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
                lineWidth: 3,
            ),
        )
        .shadow(color: Color.DesignSystem.themed.glow.opacity(0.3), radius: 12)
        .glassBorderGlow(
            isActive: true,
            color: Color.DesignSystem.themed.primary,
            lineWidth: 2,
            cornerRadius: 50,
            duration: 2.0,
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.1, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityLabel(t.t("profile.photo_tap_to_view"))
        .accessibilityAddTraits(.isButton)
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.DesignSystem.primary.opacity(0.2))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.DesignSystem.primary)
            }
    }
}

// MARK: - Avatar Detail View (Full Screen)

struct AvatarDetailView: View {
    @Environment(\.translationService) private var t
    let avatarUrl: String?
    @Environment(\.dismiss) private var dismiss
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let avatarUrl, let url = URL(string: avatarUrl) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                zoomScale = lastZoomScale * value
                            }
                            .onEnded { _ in
                                lastZoomScale = zoomScale
                                if zoomScale < 1.0 {
                                    withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                                        zoomScale = 1.0
                                        lastZoomScale = 1.0
                                    }
                                }
                            },
                    )
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation(.interpolatingSpring(stiffness: 300, damping: 20)) {
                                    if zoomScale > 1.0 {
                                        zoomScale = 1.0
                                        lastZoomScale = 1.0
                                    } else {
                                        zoomScale = 2.5
                                        lastZoomScale = 2.5
                                    }
                                }
                            },
                    )
            } else {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                    Text(t.t("profile.no_photo"))
                        .font(.LiquidGlass.bodyLarge)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
            }
        }
        .presentationBackground(.black)
    }
}

// MARK: - Profile Completion Card (with Circular Progress Ring)

private struct ProfileCompletionCard: View {
    @Environment(\.translationService) private var t
    let completion: ProfileCompletion
    let onTap: () -> Void

    @State private var animatedProgress: Double = 0

    private var progressColor: Color {
        switch completion.percentage {
        case 0 ..< 30: .DesignSystem.error
        case 30 ..< 70: .DesignSystem.brandOrange
        default: .DesignSystem.brandGreen
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Circular Progress Ring
            ZStack {
                Circle()
                    .stroke(Color.DesignSystem.glassBackground, lineWidth: 8)
                    .frame(width: 70, height: 70)

                Circle()
                    .trim(from: 0, to: animatedProgress / 100)
                    .stroke(
                        LinearGradient(
                            colors: [progressColor, progressColor.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round),
                    )
                    .frame(width: 70, height: 70)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(animatedProgress))%")
                        .font(.LiquidGlass.headlineSmall)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.DesignSystem.text)
                        .contentTransition(.numericText())
                }
            }
            .onAppear {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                    animatedProgress = completion.percentage
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(t.t("profile.complete_profile"))
                    .font(.LiquidGlass.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)

                if let nextStep = completion.nextStep {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.DesignSystem.accentYellow)

                        Text(t.t("profile.next_step", args: ["step": nextStep]))
                            .font(.LiquidGlass.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Text(t.t("profile.complete_profile_benefit"))
                    .font(.LiquidGlass.captionSmall)
                    .foregroundStyle(Color.DesignSystem.brandGreen)
                    .padding(.top, Spacing.xxs)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .onTapGesture {
            onTap()
            HapticManager.light()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t.t("profile.completion_accessibility", args: ["percent": "\(Int(completion.percentage))"]))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Profile Stats Section

private struct ProfileStatsSection: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel

    @State private var hasAppeared = false

    var body: some View {
        HStack(spacing: 0) {
            ProfileStatItem(
                value: viewModel.sharedCount,
                label: t.t("profile.stats.shared"),
                icon: "arrow.up.heart.fill",
                color: .DesignSystem.brandOrange,
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.interpolatingSpring(stiffness: 300, damping: 22).delay(0.0), value: hasAppeared)

            Divider().frame(height: 50)

            ProfileStatItem(
                value: viewModel.receivedCount,
                label: t.t("profile.stats.received"),
                icon: "arrow.down.heart.fill",
                color: .DesignSystem.success,
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.interpolatingSpring(stiffness: 300, damping: 22).delay(0.08), value: hasAppeared)

            Divider().frame(height: 50)

            ProfileStatItem(
                value: viewModel.ratingText,
                label: t.t("profile.stats.rating"),
                icon: "star.fill",
                color: .DesignSystem.accentYellow,
            )
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared ? 0 : 20)
            .animation(.interpolatingSpring(stiffness: 300, damping: 22).delay(0.16), value: hasAppeared)
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            t.t(
                "profile.stats.accessibility",
                args: [
                    "shared": viewModel.sharedCount,
                    "received": viewModel.receivedCount,
                    "rating": viewModel.ratingText,
                ],
            ),
        )
        .onAppear {
            hasAppeared = true
        }
    }
}

// MARK: - Animated Profile Stat Item (with count-up effect)

struct ProfileStatItem: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    @State private var displayValue = "0"
    @State private var isPulsing = false
    @State private var hasAnimated = false

    private var numericValue: Int? {
        // Extract numeric value from string (handles "4.8" -> 4)
        if let dotIndex = value.firstIndex(of: ".") {
            return Int(value[..<dotIndex])
        }
        return Int(value)
    }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                // Pulsing background circle
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 0.3)

                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }

            Text(displayValue)
                .font(.LiquidGlass.headlineLarge)
                .fontWeight(.bold)
                .foregroundStyle(Color.DesignSystem.text)
                .contentTransition(.numericText())

            Text(label)
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            animateValue()
        }
    }

    private func animateValue() {
        // If it's a rating like "4.8", animate to final value
        if value.contains(".") {
            let steps = 20
            let finalDouble = Double(value) ?? 0
            for i in 0 ... steps {
                let delay = Double(i) * 0.05
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let progress = Double(i) / Double(steps)
                    let currentValue = finalDouble * progress
                    withAnimation(.easeOut(duration: 0.05)) {
                        displayValue = String(format: "%.1f", currentValue)
                    }
                }
            }
        } else if let target = numericValue {
            // Animate integer values
            let duration = 1.0
            let steps = min(target, 30) // Max 30 steps for performance
            guard steps > 0 else {
                displayValue = value
                return
            }

            for i in 0 ... steps {
                let delay = (duration / Double(steps)) * Double(i)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    let progress = Double(i) / Double(steps)
                    let currentValue = Int(Double(target) * progress)
                    withAnimation(.easeOut(duration: 0.03)) {
                        displayValue = "\(currentValue)"
                    }
                }
            }
        } else {
            displayValue = value
        }

        // Trigger pulse at end
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.4)) {
                isPulsing = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                isPulsing = false
            }
            HapticManager.light()
        }
    }
}

// MARK: - Enhanced Impact Stats Section (with real-world comparisons)

private struct ImpactStatsSection: View {
    @Environment(\.translationService) private var t
    let stats: ImpactStats
    let memberSince: String
    let memberDuration: String

    @State private var showImpactDetail = false

    /// Real-world comparisons
    private var treesEquivalent: Int {
        // 1 tree absorbs ~22kg CO2/year, so kg/22 = trees for a year
        max(1, Int(stats.co2SavedKg / 22))
    }

    private var showerMinutes: Int {
        // Average shower uses ~9 liters/minute
        max(1, Int(stats.waterSavedLiters / 9))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.brandGreen)

                Text(t.t("profile.impact.title"))
                    .font(.LiquidGlass.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                Text(stats.communityRank)
                    .font(.LiquidGlass.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.themed.gradientStart,
                                    Color.DesignSystem.themed.gradientEnd,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        ),
                    )
            }

            HStack(spacing: Spacing.md) {
                EnhancedImpactMetricView(
                    icon: "cloud.fill",
                    value: stats.formattedCO2,
                    label: t.t("profile.impact.co2_saved"),
                    comparison: t.t("profile.impact.trees_equivalent", args: ["count": "\(treesEquivalent)"]),
                    color: .DesignSystem.brandBlue,
                )
                EnhancedImpactMetricView(
                    icon: "drop.fill",
                    value: stats.formattedWater,
                    label: t.t("profile.impact.water_saved"),
                    comparison: t.t("profile.impact.shower_equivalent", args: ["minutes": "\(showerMinutes)"]),
                    color: .DesignSystem.brandTeal,
                )
                EnhancedImpactMetricView(
                    icon: "fork.knife",
                    value: "\(stats.mealsShared + stats.mealsReceived)",
                    label: t.t("profile.impact.meals"),
                    comparison: t.t("profile.impact.meals_shared", args: ["count": "\(stats.mealsShared)"]),
                    color: .DesignSystem.brandOrange,
                )
            }

            // Member since info
            HStack(spacing: Spacing.xs) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                Text(memberSince)
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)

                Text("•")
                    .foregroundStyle(Color.DesignSystem.textTertiary)

                Text(memberDuration)
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            // Share impact button
            Button {
                showImpactDetail = true
                HapticManager.light()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(t.t("profile.impact.share"))
                }
                .font(.LiquidGlass.labelSmall)
                .foregroundStyle(Color.DesignSystem.themed.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(Color.DesignSystem.themed.primary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .drawingGroup() // GPU acceleration for glass effects
    }
}

// MARK: - Enhanced Impact Metric View (with comparison)

struct EnhancedImpactMetricView: View {
    let icon: String
    let value: String
    let label: String
    let comparison: String
    let color: Color

    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
                    .symbolEffect(.pulse, options: .repeating, value: isAnimating)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isAnimating = true
                }
            }

            Text(value)
                .font(.LiquidGlass.headlineSmall)
                .fontWeight(.bold)
                .foregroundStyle(Color.DesignSystem.text)
                .contentTransition(.numericText())

            Text(label)
                .font(.LiquidGlass.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .lineLimit(1)

            // Real-world comparison
            Text(comparison)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(color.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Impact Metric View

struct ImpactMetricView: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

            Text(value)
                .font(.LiquidGlass.headlineSmall)
                .fontWeight(.bold)
                .foregroundStyle(Color.DesignSystem.text)
                .contentTransition(.numericText())

            Text(label)
                .font(.LiquidGlass.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Badges Section

private struct BadgesSection: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Label(t.t("profile.badges"), systemImage: "medal.fill")
                    .font(.LiquidGlass.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                if let collection = viewModel.badgeCollection {
                    Text("\(collection.earnedBadges.count)/\(collection.allBadges.count)")
                        .font(.LiquidGlass.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                NavigationLink(value: ProfileDestination.badges(
                    collection: viewModel.badgeCollection ?? .empty,
                    stats: viewModel.userStats ?? .empty,
                )) {
                    Image(systemName: "chevron.right")
                        .font(.LiquidGlass.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            if viewModel.isLoadingBadges {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, Spacing.md)
            } else if let collection = viewModel.badgeCollection {
                BadgesContent(collection: collection)
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

private struct BadgesContent: View {
    @Environment(\.translationService) private var t
    let collection: BadgeCollection

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            if !collection.featuredBadges.isEmpty {
                GlassHorizontalScroll.compact {
                    ForEach(collection.featuredBadges) { userBadge in
                        GlassBadgeItem(
                            badge: userBadge.badge,
                            isEarned: true,
                            isFeatured: true,
                            progress: nil,
                            onTap: nil,
                        )
                        .frame(width: 72)
                    }
                }
            } else if !collection.earnedBadges.isEmpty {
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(collection.earnedBadges.prefix(4))) { userBadge in
                        GlassBadgeItem(
                            badge: userBadge.badge,
                            isEarned: true,
                            isFeatured: false,
                            progress: nil,
                            onTap: nil,
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            if collection.totalPoints > 0 {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.yellow)

                    Text(t.t("profile.badge_points_earned", args: ["count": "\(collection.totalPoints)"]))
                        .font(.LiquidGlass.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)

                    Spacer()
                }
                .padding(.top, Spacing.xs)
            }
        }
    }
}

// MARK: - Reviews Section

private struct ReviewsSection: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "star.bubble.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                    Text(t.t("profile.reviews"))
                        .font(.LiquidGlass.headlineSmall)
                        .foregroundStyle(Color.DesignSystem.text)
                }

                Spacer()

                if !viewModel.reviews.isEmpty {
                    Text("\(viewModel.reviewCount)")
                        .font(.LiquidGlass.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                NavigationLink(value: ProfileDestination.reviews(
                    reviews: viewModel.reviews,
                    userName: viewModel.localizedDisplayName(using: t),
                    rating: viewModel.profile?.ratingAverage ?? 0,
                )) {
                    Image(systemName: "chevron.right")
                        .font(.LiquidGlass.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            if viewModel.isLoadingReviews {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Spacer()
                }
                .padding(.vertical, Spacing.md)
            } else if viewModel.reviews.isEmpty {
                ReviewsEmptyState()
            } else {
                ReviewsContent(viewModel: viewModel)
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

private struct ReviewsEmptyState: View {
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "star.leadinghalf.filled")
                .font(.system(size: 28))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow.opacity(0.5), .orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
            Text(t.t("profile.no_reviews"))
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }
}

private struct ReviewsContent: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                StarRatingView(rating: viewModel.profile?.ratingAverage ?? 0, size: 14)
                Text(String(format: "%.1f", viewModel.profile?.ratingAverage ?? 0))
                    .font(.LiquidGlass.headlineSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.DesignSystem.text)
                Text("•")
                    .foregroundStyle(Color.DesignSystem.textTertiary)
                Text(t.t("profile.review_count", args: ["count": "\(viewModel.reviewCount)"]))
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            ForEach(viewModel.reviews.prefix(2)) { review in
                ReviewCard(review: review)
            }

            if viewModel.reviewCount > 2 {
                NavigationLink(value: ProfileDestination.reviews(
                    reviews: viewModel.reviews,
                    userName: viewModel.localizedDisplayName(using: t),
                    rating: viewModel.profile?.ratingAverage ?? 0,
                )) {
                    HStack(spacing: Spacing.xs) {
                        Text(t.t("profile.see_all_reviews", args: ["count": "\(viewModel.reviewCount)"]))
                        Image(systemName: "chevron.right")
                    }
                    .font(.LiquidGlass.labelMedium)
                    .foregroundStyle(Color.DesignSystem.themed.primary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, Spacing.xs)
            }
        }
    }
}

// MARK: - Profile Actions Section

private struct ProfileActionsSection: View {
    @Environment(\.translationService) private var t
    let viewModel: ProfileViewModel
    @Binding var showSignOutAlert: Bool

    private var listingRepository: ListingRepository {
        SupabaseListingRepository(supabase: SupabaseManager.shared.client)
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            NavigationLink(value: ProfileDestination.listings(
                userId: viewModel.profile?.id ?? UUID(),
                repository: listingRepository,
            )) {
                ProfileMenuRow(
                    title: t.t("profile.my_listings"),
                    icon: "list.bullet.rectangle.fill",
                    color: Color.DesignSystem.themed.gradientEnd,
                )
            }

            NavigationLink(value: ProfileDestination.history(
                userId: viewModel.profile?.id ?? UUID(),
                repository: listingRepository,
            )) {
                ProfileMenuRow(
                    title: t.t("profile.history.title"),
                    icon: "clock.arrow.circlepath",
                    color: Color.DesignSystem.themed.secondary,
                )
            }

            NavigationLink(value: ProfileDestination.forum) {
                ProfileMenuRow(
                    title: t.t("profile.community_forum"),
                    icon: "bubble.left.and.bubble.right.fill",
                    color: Color.DesignSystem.themed.primary,
                )
            }

            NavigationLink(value: ProfileDestination.settings) {
                ProfileMenuRow(title: t.t("settings.title"), icon: "gearshape.fill")
            }

            NavigationLink(value: ProfileDestination.notifications) {
                ProfileMenuRow(title: t.t("profile.notifications"), icon: "bell.fill")
            }

            NavigationLink(value: ProfileDestination.help) {
                ProfileMenuRow(title: t.t("profile.help_support"), icon: "questionmark.circle.fill")
            }

            Button {
                showSignOutAlert = true
                HapticManager.warning()
            } label: {
                ProfileMenuRow(
                    title: t.t("profile.sign_out"),
                    icon: "arrow.right.square.fill",
                    color: .DesignSystem.error,
                )
            }
        }
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

// MARK: - Profile Menu Row

struct ProfileMenuRow: View {
    let title: String
    let icon: String
    var color: Color = .DesignSystem.text

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .font(.LiquidGlass.labelLarge)
                .foregroundStyle(color)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.LiquidGlass.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Profile Loading View

private struct ProfileLoadingView: View {
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color.DesignSystem.themed.primary)

            Text(t.t("profile.loading"))
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Spacing.xxl)
    }
}

// MARK: - User Level Model

struct UserLevel: Sendable, Equatable {
    let level: Int
    let currentXP: Int
    let xpForNextLevel: Int
    let totalXP: Int

    var progress: Double {
        guard xpForNextLevel > 0 else { return 1.0 }
        return Double(currentXP) / Double(xpForNextLevel)
    }

    var title: String {
        switch level {
        case 1 ... 5: "Newcomer"
        case 6 ... 10: "Food Saver"
        case 11 ... 20: "Community Helper"
        case 21 ... 35: "Sharing Champion"
        case 36 ... 50: "Food Hero"
        case 51 ... 75: "Sustainability Star"
        case 76 ... 100: "Eco Warrior"
        default: "Legend"
        }
    }

    var iconName: String {
        switch level {
        case 1 ... 5: "leaf"
        case 6 ... 10: "leaf.fill"
        case 11 ... 20: "tree"
        case 21 ... 35: "sparkles"
        case 36 ... 50: "star.fill"
        case 51 ... 75: "crown"
        case 76 ... 100: "trophy"
        default: "flame.fill"
        }
    }

    @MainActor
    static func calculate(from profile: UserProfile) -> UserLevel {
        let config = AppConfiguration.shared
        let sharedXP = profile.itemsShared * config.xpPerShare
        let receivedXP = profile.itemsReceived * config.xpPerReceive
        let reviewXP = profile.ratingCount * config.xpPerReview
        let ratingBonus = Int(profile.ratingAverage * Double(config.xpRatingBonus))

        let totalXP = sharedXP + receivedXP + reviewXP + ratingBonus

        let level = Int(floor(sqrt(Double(totalXP) / 10.0))) + 1
        let xpForCurrentLevel = (level - 1) * (level - 1) * 10
        let xpForNextLevel = level * level * 10
        let currentXP = totalXP - xpForCurrentLevel
        let xpNeeded = xpForNextLevel - xpForCurrentLevel

        return UserLevel(
            level: level,
            currentXP: currentXP,
            xpForNextLevel: xpNeeded,
            totalXP: totalXP,
        )
    }
}

// MARK: - Level Progress Card (Gamification)

struct LevelProgressCard: View {
    @Environment(\.translationService) private var t
    let profile: UserProfile

    @State private var animatedProgress: Double = 0
    @State private var hasAnimated = false

    private var level: UserLevel {
        UserLevel.calculate(from: profile)
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            HStack {
                HStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.themed.gradientStart,
                                        Color.DesignSystem.themed.gradientEnd,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: level.iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("profile.level", args: ["level": "\(level.level)"]))
                            .font(.LiquidGlass.headlineSmall)
                            .foregroundStyle(Color.DesignSystem.text)

                        Text(level.title)
                            .font(.LiquidGlass.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(t.t(
                        "profile.xp_progress",
                        args: ["current": "\(level.currentXP)", "total": "\(level.xpForNextLevel)"],
                    ))
                    .font(.LiquidGlass.bodySmall)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.DesignSystem.text)

                    Text(t.t("profile.to_next_level", args: ["percent": "\(Int(animatedProgress * 100))"]))
                        .font(.LiquidGlass.captionSmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .contentTransition(.numericText())
                }
            }

            // Progress bar with 120Hz animation
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(height: 10)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.DesignSystem.themed.gradientStart,
                                    Color.DesignSystem.themed.gradientEnd,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .frame(width: geometry.size.width * animatedProgress, height: 10)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1),
                        )
                }
            }
            .frame(height: 10)
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            withAnimation(.interpolatingSpring(stiffness: 100, damping: 15).delay(0.3)) {
                animatedProgress = level.progress
            }
            HapticManager.light()
        }
    }
}

// MARK: - Streak Indicator Card (Gamification)

struct StreakIndicatorCard: View {
    @Environment(\.translationService) private var t
    // In a real app, this would come from the profile/database
    // For now, we calculate a streak based on current date as demo
    @State private var streakDays = 7
    @State private var isFlameAnimating = false

    private var streakMessageKey: String {
        switch streakDays {
        case 0: "profile.streak.start"
        case 1: "profile.streak.great_start"
        case 2 ... 6: "profile.streak.on_fire"
        case 7 ... 13: "profile.streak.amazing_week"
        case 14 ... 29: "profile.streak.two_weeks"
        case 30 ... 59: "profile.streak.one_month"
        case 60 ... 89: "profile.streak.incredible"
        default: "profile.streak.legendary"
        }
    }

    private var flameColor: Color {
        switch streakDays {
        case 0 ... 2: .orange
        case 3 ... 6: .orange
        case 7 ... 13: .red
        case 14 ... 29: .red
        default: .purple
        }
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Animated flame icon
            ZStack {
                // Glow effect
                Circle()
                    .fill(flameColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .scaleEffect(isFlameAnimating ? 1.2 : 1.0)
                    .opacity(isFlameAnimating ? 0.3 : 0.6)

                Image(systemName: "flame.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [flameColor, .yellow],
                            startPoint: .bottom,
                            endPoint: .top,
                        ),
                    )
                    .scaleEffect(isFlameAnimating ? 1.1 : 1.0)
                    .symbolEffect(.bounce, options: .repeating.speed(0.5), value: isFlameAnimating)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isFlameAnimating = true
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack(spacing: Spacing.xs) {
                    Text("\(streakDays)")
                        .font(.LiquidGlass.displaySmall)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.DesignSystem.text)
                        .contentTransition(.numericText())

                    Text(t.t("profile.streak.day_streak"))
                        .font(.LiquidGlass.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.text)
                }

                Text(t.t(streakMessageKey))
                    .font(.LiquidGlass.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Spacer()

            // Streak calendar preview (last 7 days)
            HStack(spacing: 3) {
                ForEach(0 ..< 7, id: \.self) { day in
                    Circle()
                        .fill(day < streakDays % 7 || streakDays >= 7 ? flameColor : Color.DesignSystem.glassBackground)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(t.t(
            "profile.streak.accessibility",
            args: ["days": "\(streakDays)", "message": t.t(streakMessageKey)],
        ))
    }
}

// MARK: - Profile QR Code View

struct ProfileQRCodeView: View {
    @Environment(\.translationService) private var t
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    @State private var isPulsing = false

    private var profileURL: String {
        "foodshare://profile/\(profile.id.uuidString)"
    }

    private var qrCodeImage: UIImage {
        generateQRCode(from: profileURL)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    // Profile preview card
                    VStack(spacing: Spacing.md) {
                        if let avatarUrl = profile.avatarUrl, let url = URL(string: avatarUrl) {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.DesignSystem.themed.gradientStart,
                                                Color.DesignSystem.themed.gradientEnd,
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing,
                                        ),
                                        lineWidth: 2,
                                    ),
                                )
                        } else {
                            Circle()
                                .fill(Color.DesignSystem.primary.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(Color.DesignSystem.primary)
                                }
                        }

                        Text(profile.nickname)
                            .font(.LiquidGlass.headlineLarge)
                            .foregroundStyle(Color.DesignSystem.text)

                        HStack(spacing: Spacing.md) {
                            Label("\(profile.itemsShared)", systemImage: "arrow.up.heart.fill")
                                .foregroundStyle(Color.DesignSystem.brandOrange)
                            Label("\(profile.itemsReceived)", systemImage: "arrow.down.heart.fill")
                                .foregroundStyle(Color.DesignSystem.success)
                            Label(String(format: "%.1f", profile.ratingAverage), systemImage: "star.fill")
                                .foregroundStyle(Color.DesignSystem.accentYellow)
                        }
                        .font(.LiquidGlass.caption)
                    }
                    .padding(Spacing.lg)
                    .glassEffect(cornerRadius: CornerRadius.xl)

                    // QR Code with scanning pulse
                    VStack(spacing: Spacing.md) {
                        Text(t.t("profile.qr.scan_to_connect"))
                            .font(.LiquidGlass.headlineSmall)
                            .foregroundStyle(Color.DesignSystem.text)

                        ZStack {
                            // Pulse rings
                            ForEach(0 ..< 3, id: \.self) { index in
                                RoundedRectangle(cornerRadius: CornerRadius.large + 8)
                                    .stroke(
                                        Color.DesignSystem.brandGreen.opacity(0.3 - Double(index) * 0.08),
                                        lineWidth: 2,
                                    )
                                    .frame(
                                        width: 200 + CGFloat(index) * 24 + Spacing.lg * 2,
                                        height: 200 + CGFloat(index) * 24 + Spacing.lg * 2,
                                    )
                                    .scaleEffect(isPulsing ? 1.05 : 1.0)
                                    .opacity(isPulsing ? 0.5 : 0.8)
                                    .animation(
                                        .easeInOut(duration: 1.5)
                                            .repeatForever(autoreverses: true)
                                            .delay(Double(index) * 0.2),
                                        value: isPulsing,
                                    )
                            }

                            Image(uiImage: qrCodeImage)
                                .interpolation(.none)
                                .resizable()
                                .frame(width: 200, height: 200)
                                .padding(Spacing.lg)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.large)
                                        .stroke(
                                            LinearGradient(
                                                colors: [
                                                    Color.DesignSystem.brandGreen.opacity(0.6),
                                                    Color.DesignSystem.brandTeal.opacity(0.4),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing,
                                            ),
                                            lineWidth: 2,
                                        ),
                                )
                                .shadow(color: Color.DesignSystem.brandGreen.opacity(0.15), radius: 15, y: 5)
                        }
                    }
                    .padding(Spacing.xl)
                    .glassEffect(cornerRadius: CornerRadius.xl)
                    .onAppear {
                        isPulsing = true
                    }

                    // Share button
                    ShareLink(item: profileURL) {
                        Label(t.t("profile.qr.share_link"), systemImage: "square.and.arrow.up")
                            .font(.LiquidGlass.bodyLarge)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.DesignSystem.themed.gradientStart,
                                        Color.DesignSystem.themed.gradientEnd,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing,
                                ),
                            )
                            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
                    }
                    .padding(.horizontal, Spacing.lg)

                    Spacer()
                }
                .padding(Spacing.lg)
            }
            .navigationTitle(t.t("profile.qr.share_profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) {
                        dismiss()
                    }
                    .foregroundStyle(Color.DesignSystem.themed.primary)
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "H"

        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)

            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                return UIImage(cgImage: cgImage)
            }
        }

        return UIImage(systemName: "qrcode") ?? UIImage()
    }
}
