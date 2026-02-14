import FoodShareDesignSystem
import OSLog
import SwiftUI

private let forumViewLogger = Logger(subsystem: "com.flutterflow.foodshare", category: "ForumView")

// MARK: - Forum View

struct ForumView: View {
    @Environment(\.translationService) private var t
    @State private var viewModel: ForumViewModel
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var selectedPost: ForumPost?
    @State private var hasAppeared = false
    @State private var hasLoadedData = false
    @State private var showNotifications = false
    @State private var showCreatePost = false
    @State private var showSavedPosts = false
    @State private var showAuthorPreview: ForumAuthor?
    @State private var unreadNotificationCount = 0
    @State private var isSearchActive = false
    @State private var showAppInfo = false
    @FocusState private var isSearchFocused: Bool
    @Environment(AppState.self) private var appState

    init(viewModel: ForumViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Search header matching Explore tab pattern
                forumSearchHeader

                content
            }

            // Floating Action Button
            if appState.currentUser != nil {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        createPostButton
                    }
                }
                .padding(Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
        }
        .navigationBarHidden(true)
        .navigationTitle(t.t("tabs.forum"))
        .sheet(isPresented: $showFilters) {
            ForumFiltersSheet(
                filters: $viewModel.filters,
                categories: viewModel.categories,
                onApply: {
                    Task { await viewModel.loadPosts() }
                },
                onSavedPostsTap: {
                    showSavedPosts = true
                },
                onNotificationsTap: {
                    showNotifications = true
                },
                unreadNotificationCount: unreadNotificationCount,
            )
            .glassSheet()
        }
        .sheet(item: $selectedPost) { post in
            ForumPostDetailView(post: post, repository: viewModel.repository)
                .glassSheet()
        }
        .sheet(isPresented: $showNotifications) {
            if let userId = appState.currentUser?.id {
                ForumNotificationsView(
                    repository: viewModel.repository,
                    profileId: userId,
                )
                .glassSheet()
            }
        }
        .sheet(isPresented: $showCreatePost) {
            CreateForumPostView(
                repository: viewModel.repository,
                categories: viewModel.categories,
            ) { _ in
                Task { await viewModel.loadPosts() }
            }
            .environment(appState)
        }
        .sheet(isPresented: $showSavedPosts) {
            SavedPostsView(repository: viewModel.repository)
                .environment(appState)
        }
        .sheet(item: $showAuthorPreview) { author in
            AuthorPreviewSheet(
                author: author,
                repository: viewModel.repository,
                onViewProfile: {
                    // Navigate to full profile
                },
            )
        }
        .sheet(isPresented: $showAppInfo) {
            AppInfoSheet()
        }
        .alert(t.t("forum.error.load_title"), isPresented: $viewModel.showError) {
            Button(t.t("common.action.retry")) {
                Task { await viewModel.loadPosts() }
            }
            Button(t.t("common.action.cancel"), role: .cancel) {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? t.t("common.error.unknown"))
        }
        .onAppear {
            forumViewLogger.info("🟢 ForumView.onAppear - hasLoadedData=\(hasLoadedData)")
            // Animate appearance
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }

            // Only load data once - prevent reload and task cancellation on tab switches
            guard !hasLoadedData else {
                forumViewLogger.debug("⏭️ ForumView already loaded data, skipping")
                return
            }
            hasLoadedData = true
            forumViewLogger.info("🚀 ForumView loading data for first time...")

            // Capture viewModel to avoid cancellation issues
            let vm = viewModel
            let userId = appState.currentUser?.id
            let repo = viewModel.repository
            Task {
                forumViewLogger.info("📥 Calling loadInitialData()...")
                await vm.loadInitialData()
                forumViewLogger.info("✅ loadInitialData() completed")
                // Load notification count
                if let userId {
                    let count = await (try? repo.fetchUnreadNotificationCount(profileId: userId)) ?? 0
                    withAnimation { unreadNotificationCount = count }
                }
            }
        }
        #if !SKIP
        .onReceive(NotificationCenter.default.publisher(for: .forumNotificationReceived)) { _ in
            Task { await loadNotificationCount() }
        }
        #endif
    }

    // MARK: - Notification Count

    private func loadNotificationCount() async {
        guard let userId = appState.currentUser?.id else { return }

        do {
            let count = try await viewModel.repository.fetchUnreadNotificationCount(profileId: userId)
            withAnimation {
                unreadNotificationCount = count
            }
        } catch {
            // Silently fail
        }
    }

    // MARK: - Create Post Button

    private var createPostButton: some View {
        Button {
            showCreatePost = true
            HapticManager.light()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 60, height: 60)
                    .shadow(
                        color: Color.DesignSystem.brandPink.opacity(0.4),
                        radius: Spacing.md,
                        y: Spacing.sm,
                    )

                Image(systemName: "plus")
                    .font(.DesignSystem.titleLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            // Category bar - always rendered to prevent layout shift
            categoryChips
                .opacity(hasAppeared ? 1 : 0)
                .animation(ProMotionAnimation.smooth.delay(0.1), value: hasAppeared)

            // Subtle divider below categories
            Rectangle()
                .fill(Color.DesignSystem.glassBorder.opacity(0.15))
                .frame(height: 1)

            // Content area - fills remaining space
            Group {
                if viewModel.isLoading, viewModel.posts.isEmpty {
                    loadingView
                } else if viewModel.loadingFailed, viewModel.posts.isEmpty {
                    // Graceful degradation: inline empty state for quota/network errors
                    loadingFailedStateView
                } else if viewModel.posts.isEmpty {
                    emptyStateView
                } else {
                    postsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func errorStateView(error: AppError) -> some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(Color.DesignSystem.error.opacity(0.3), lineWidth: 1),
                    )

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.DesignSystem.error)
            }
            .padding(.bottom, Spacing.sm)

            VStack(spacing: Spacing.sm) {
                Text(t.t("forum.error.unable_to_load"))
                    .font(.DesignSystem.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(error.localizedDescription)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            GlassButton(t.t("common.action.try_again"), icon: "arrow.clockwise", style: .primary) {
                Task { await viewModel.loadPosts() }
            }

            Spacer()
        }
        .padding(Spacing.xl)
        .animatedAppearance()
    }

    private var postsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                // Trending posts section
                if !viewModel.trendingPosts.isEmpty, searchText.isEmpty {
                    TrendingPostsSection(
                        posts: viewModel.trendingPosts,
                        onPostTap: { post in
                            HapticManager.light()
                            selectedPost = post
                        },
                        onSeeAllTap: {
                            // Could navigate to a full trending view
                            Task {
                                viewModel.filters.sortBy = .trending
                                await viewModel.loadPosts()
                            }
                        },
                    )
                    .staggeredAppearance(index: 0, baseDelay: 0.15)
                }

                // Pinned posts
                if !viewModel.pinnedPosts.isEmpty {
                    pinnedSection
                        .staggeredAppearance(index: 1, baseDelay: 0.15)
                }

                // Regular posts
                ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                    GlassForumPostCard(
                        post: post,
                        onTap: {
                            HapticManager.light()
                            selectedPost = post
                        },
                        onAuthorTap: { author in
                            showAuthorPreview = author
                        },
                        onLikeTap: {
                            guard let userId = appState.currentUser?.id else { return }
                            await viewModel.toggleLike(for: post, profileId: userId)
                        },
                    )
                    .staggeredAppearance(index: index + 2, baseDelay: 0.15, staggerDelay: 0.04)
                    .onAppear {
                        if post.id == viewModel.posts.last?.id {
                            Task { await viewModel.loadMorePosts() }
                        }
                    }
                }

                if viewModel.isLoadingMore {
                    GlassLoadingIndicator(message: t.t("common.status.loading_more"))
                        .padding(.vertical, Spacing.lg)
                }
            }
            .padding(Spacing.md)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }

    private var categoryChips: some View {
        Group {
            if viewModel.categories.isEmpty {
                // Placeholder to reserve space while loading
                Color.clear
                    .frame(height: 76) // Match GlassCategoryChip height (48 icon + 20 label + 8 spacing)
            } else {
                GlassCategoryBar(
                    selectedCategory: Binding(
                        get: { viewModel.selectedCategory },
                        set: { category in
                            Task { await viewModel.selectCategory(category) }
                        },
                    ),
                    categories: viewModel.categories,
                    showAllOption: true,
                    localizedTitleProvider: { category in
                        // Use the localized name method which handles fallbacks
                        category.localizedName(using: t)
                    },
                )
            }
        }
    }

    private var pinnedSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with glass styling
            HStack(spacing: Spacing.sm) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.DesignSystem.medalGold)
                    .rotationEffect(.degrees(-45))

                Text(t.t("forum.section.pinned"))
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                Text("\(viewModel.pinnedPosts.count)")
                    .font(.DesignSystem.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xxs)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Capsule()
                                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                            ),
                    )
            }
            .padding(.horizontal, Spacing.xs)

            ForEach(Array(viewModel.pinnedPosts.enumerated()), id: \.element.id) { _, post in
                GlassForumPostCard(
                    post: post,
                    isPinned: true,
                    onTap: {
                        HapticManager.light()
                        selectedPost = post
                    },
                    onAuthorTap: { author in
                        showAuthorPreview = author
                    },
                    onLikeTap: {
                        guard let userId = appState.currentUser?.id else { return }
                        await viewModel.toggleLike(for: post, profileId: userId)
                    },
                )
                .glassBorderGlow(isActive: true, color: .DesignSystem.medalGold)
            }
        }
    }

    // MARK: - Search Header

    private var forumSearchHeader: some View {
        TabSearchHeader(
            searchText: $searchText,
            isSearchActive: $isSearchActive,
            isSearchFocused: $isSearchFocused,
            placeholder: t.t("forum.search.placeholder"),
            showAppInfo: $showAppInfo,
            onSearchTextChange: { newValue in
                Task { await viewModel.searchPosts(query: newValue) }
            },
            onSearchSubmit: {
                Task { await viewModel.searchPosts(query: searchText) }
            },
        ) {
            GlassActionButtonWithNotification(
                icon: "slider.horizontal.3",
                unreadCount: unreadNotificationCount,
                accessibilityLabel: t.t("forum.filters.title"),
                onButtonTap: {
                    showFilters = true
                },
                onNotificationTap: {
                    showNotifications = true
                },
            )
        }
    }

    // MARK: - Supporting Views

    private var loadingView: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Glass skeleton cards for loading state
                ForEach(0 ..< 4, id: \.self) { index in
                    GlassSkeletonCard()
                        .staggeredAppearance(index: index, baseDelay: 0.1)
                }
            }
            .padding(Spacing.md)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Glass empty state with animated icon
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
                                        Color.DesignSystem.brandGreen.opacity(0.3),
                                        Color.DesignSystem.glassBorder,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                                lineWidth: 1,
                            ),
                    )
                    .glassBreathing(intensity: 0.5)

                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }
            .padding(.bottom, Spacing.sm)

            VStack(spacing: Spacing.sm) {
                Text(t.t("forum.empty.title"))
                    .font(.DesignSystem.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("forum.empty.description"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(Spacing.xl)
        .animatedAppearance()
    }

    /// Graceful degradation view for quota exceeded or network failures
    /// Shows a subtle, non-blocking empty state with retry option
    private var loadingFailedStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

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
                Text(t.t("forum.offline.title"))
                    .font(.DesignSystem.headlineMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.DesignSystem.text)

                Text(t.t("forum.offline.description"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.lg)
            }

            // Subtle retry button
            Button {
                HapticManager.light()
                Task { await viewModel.loadPosts() }
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

            Spacer()
        }
        .padding(Spacing.xl)
        .animatedAppearance()
    }
}

// MARK: - Forum Post Card (Liquid Glass Enhanced)

struct ForumPostCard: View {
    @Environment(\.translationService) private var t
    let post: ForumPost
    var isPinned = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header
                HStack(spacing: Spacing.sm) {
                    // Author avatar
                    AsyncImage(url: post.author?.avatarURL) { phase in
                        switch phase {
                        case .empty:
                            Circle()
                                .fill(Color.DesignSystem.glassBackground)
                                .overlay(ShimmerView())
                        case let .success(image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            .DesignSystem.brandGreen.opacity(0.3),
                                            .DesignSystem.brandBlue.opacity(0.3),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                )
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.DesignSystem.textSecondary)
                                }
                        @unknown default:
                            Circle().fill(Color.DesignSystem.glassBackground)
                        }
                    }
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: Spacing.xxs) {
                            Text(post.author?.displayName ?? t.t("forum.post.anonymous"))
                                .font(.DesignSystem.bodySmall)
                                .fontWeight(.medium)
                                .foregroundColor(.DesignSystem.text)

                            if post.author?.isVerified == true {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.DesignSystem.brandGreen)
                            }
                        }

                        Text(post.forumPostCreatedAt, style: .relative)
                            .font(.DesignSystem.captionSmall)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    Spacer()

                    // Post type badge
                    postTypeBadge
                }

                // Title (uses translated version if available)
                Text(post.displayTitle)
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.text)
                    .lineLimit(2)

                // Description preview (HTML stripped, uses translated version if available)
                if !post.displayDescription.isEmpty {
                    Text(post.displayDescription.htmlStripped)
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .lineLimit(3)
                }

                // Image preview
                if let imageUrl = post.imageUrl {
                    AsyncImage(url: imageUrl) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.DesignSystem.glassBackground)
                                .overlay(ShimmerView())
                        case let .success(image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Color.DesignSystem.glassBackground)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundColor(.DesignSystem.textSecondary)
                                }
                        @unknown default:
                            Rectangle().fill(Color.DesignSystem.glassBackground)
                        }
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                }

                // Footer stats
                HStack(spacing: Spacing.md) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.DesignSystem.error.opacity(0.7))
                        Text("\(post.likesCount)")
                    }

                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "bubble.right.fill")
                            .foregroundColor(.DesignSystem.brandBlue.opacity(0.7))
                        Text("\(post.commentsCount)")
                    }

                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "eye.fill")
                        Text("\(post.viewsCount)")
                    }

                    Spacer()

                    if let category = post.category {
                        Text(category.name)
                            .font(.DesignSystem.captionSmall)
                            .fontWeight(.medium)
                            .foregroundColor(category.displayColor)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xxs)
                            .background(
                                Capsule()
                                    .fill(category.displayColor.opacity(0.15)),
                            )
                    }
                }
                .font(.DesignSystem.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(
                                isPinned
                                    ? LinearGradient(
                                        colors: [
                                            .DesignSystem.accentOrange.opacity(0.5),
                                            .DesignSystem.medalGold.opacity(0.3),
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    )
                                    : LinearGradient(
                                        colors: [Color.DesignSystem.glassBorder],
                                        startPoint: .top,
                                        endPoint: .bottom,
                                    ),
                                lineWidth: isPinned ? 2 : 1,
                            ),
                    ),
            )
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var postTypeBadge: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: post.postType.iconName)
            if post.isQuestion, post.hasAnswer {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.DesignSystem.success)
            }
        }
        .font(.DesignSystem.captionSmall)
        .fontWeight(.medium)
        .foregroundStyle(post.postType == .question
            ? Color.DesignSystem.accentOrange
            : Color.DesignSystem
                .textSecondary)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(
            Capsule()
                .fill(post.postType == .question
                    ? Color.DesignSystem.accentOrange.opacity(0.15)
                    : Color.DesignSystem.glassBackground),
        )
    }
}

// MARK: - Glass Forum Post Card (Enhanced Liquid Glass)

struct GlassForumPostCard: View {
    @Environment(\.translationService) private var t
    let post: ForumPost
    var isPinned = false
    let onTap: () -> Void
    var onAuthorTap: ((ForumAuthor) -> Void)?
    var onLikeTap: (() async -> Void)?
    var isLiked = false

    @State private var highlightTrigger = false
    @State private var hasAppeared = false
    @State private var likeCount = 0
    @State private var localIsLiked = false
    @State private var isLikeAnimating = false

    init(
        post: ForumPost,
        isPinned: Bool = false,
        onTap: @escaping () -> Void,
        onAuthorTap: ((ForumAuthor) -> Void)? = nil,
        onLikeTap: (() async -> Void)? = nil,
        isLiked: Bool = false,
    ) {
        self.post = post
        self.isPinned = isPinned
        self.onTap = onTap
        self.onAuthorTap = onAuthorTap
        self.onLikeTap = onLikeTap
        self.isLiked = isLiked
        _likeCount = State(initialValue: post.likesCount)
        _localIsLiked = State(initialValue: isLiked)
    }

    var body: some View {
        Button(action: {
            highlightTrigger = true
            onTap()
        }) {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                // Header
                headerSection

                // Title (uses translated version if available)
                Text(post.displayTitle)
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.text)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Description preview (HTML stripped, uses translated version if available)
                if !post.displayDescription.isEmpty {
                    Text(post.displayDescription.htmlStripped)
                        .font(.DesignSystem.bodySmall)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }

                // Image preview
                if let imageUrl = post.imageUrl {
                    imagePreview(url: imageUrl)
                }

                // Footer stats
                footerSection
            }
            .padding(Spacing.md)
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
            .overlay(glassOverlay)
            .overlay(highlightOverlay)
            .shadow(color: categoryColor.opacity(0.15), radius: 15, y: 8)
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        }
        .buttonStyle(GlassPostCardButtonStyle())
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack(spacing: Spacing.sm) {
            // Author avatar with glass ring
            avatarView

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xxs) {
                    Text(post.author?.displayName ?? t.t("forum.post.anonymous"))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.DesignSystem.text)

                    if post.author?.isVerified == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing,
                                ),
                            )
                    }
                }

                Text(post.forumPostCreatedAt, style: .relative)
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Spacer()

            // Post type badge
            glassPostTypeBadge
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        let avatarContent = AsyncImage(url: post.author?.avatarURL) { phase in
            switch phase {
            case .empty:
                Circle()
                    .fill(Color.DesignSystem.glassBackground)
                    .overlay(ShimmerView())
            case let .success(image):
                image.resizable().aspectRatio(contentMode: .fill)
            case .failure:
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.3), Color.DesignSystem.brandBlue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
            @unknown default:
                Circle().fill(Color.DesignSystem.glassBackground)
            }
        }
        .frame(width: 42, height: 42)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.DesignSystem.glassBorder,
                            Color.white.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                    lineWidth: 2,
                ),
        )
        .shadow(color: categoryColor.opacity(0.2), radius: 4, y: 2)

        if let author = post.author, let onAuthorTap {
            Button {
                HapticManager.light()
                onAuthorTap(author)
            } label: {
                avatarContent
            }
            .buttonStyle(.plain)
        } else {
            avatarContent
        }
    }

    private var glassPostTypeBadge: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: post.postType.iconName)
            if post.isQuestion, post.hasAnswer {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.DesignSystem.success)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(
            post.postType == .question
                ? Color.DesignSystem.accentOrange
                : Color.DesignSystem.textSecondary,
        )
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(
                            post.postType == .question
                                ? Color.DesignSystem.accentOrange.opacity(0.3)
                                : Color.DesignSystem.glassBorder,
                            lineWidth: 1,
                        ),
                ),
        )
    }

    // MARK: - Image Preview

    private func imagePreview(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(Color.DesignSystem.glassBackground)
                    .overlay(ShimmerView())
            case let .success(image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            case .failure:
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [categoryColor.opacity(0.1), Color.DesignSystem.glassBackground],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .overlay {
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
            @unknown default:
                Rectangle().fill(Color.DesignSystem.glassBackground)
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
        )
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        HStack(spacing: Spacing.md) {
            // Interactive Like Button
            Button {
                HapticManager.light()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isLikeAnimating = true
                    localIsLiked.toggle()
                    likeCount += localIsLiked ? 1 : -1
                }
                // Reset animation state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isLikeAnimating = false
                }
                // Call async like handler
                Task {
                    await onLikeTap?()
                }
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: localIsLiked ? "heart.fill" : "heart")
                        .foregroundColor(localIsLiked ? .DesignSystem.error : .DesignSystem.error.opacity(0.6))
                        .scaleEffect(isLikeAnimating ? 1.3 : 1.0)
                    Text("\(likeCount)")
                }
                .font(.DesignSystem.captionSmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
            }
            .buttonStyle(.plain)

            // Comments count (non-interactive, opens on card tap)
            GlassStatBadge(icon: "bubble.right.fill", value: post.commentsCount, color: .DesignSystem.brandBlue)

            // Views count
            GlassStatBadge(icon: "eye.fill", value: post.viewsCount, color: .DesignSystem.textSecondary)

            // Share Button with Deep Link
            Button {
                HapticManager.light()
                sharePost()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Category badge
            if let category = post.category {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: category.systemIconName)
                        .font(.system(size: 10))
                    Text(category.name)
                }
                .font(.DesignSystem.captionSmall)
                .fontWeight(.medium)
                .foregroundColor(category.displayColor)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(
                    Capsule()
                        .fill(category.displayColor.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(category.displayColor.opacity(0.2), lineWidth: 1),
                        ),
                )
            }
        }
    }

    // MARK: - Share Post

    private func sharePost() {
        #if !SKIP
        // Create deep link URL for the post
        // Force unwrap is safe - URL format is validated at compile time
        let deepLinkURL = URL(string: "https://foodshare.club/forum/\(post.slug ?? String(post.id))")!

        let shareText = "\(post.displayTitle)\n\n\(t.t("forum.share.message"))"
        let activityItems: [Any] = [shareText, deepLinkURL]

        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil,
        )

        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController
        {
            // Handle iPad popover
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = rootVC.view
                popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            rootVC.present(activityVC, animated: true)
        }
        #endif
    }

    // MARK: - Glass Background

    private var glassBackground: some View {
        ZStack {
            // Base material
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)

            // Category-tinted gradient at bottom
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            categoryColor.opacity(0.03),
                        ],
                        startPoint: .top,
                        endPoint: .bottom,
                    ),
                )

            // Top light reflection
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .center,
                    ),
                )
        }
    }

    private var glassOverlay: some View {
        RoundedRectangle(cornerRadius: CornerRadius.large)
            .stroke(
                isPinned
                    ? LinearGradient(
                        colors: [
                            Color.DesignSystem.medalGold.opacity(0.5),
                            Color.DesignSystem.accentOrange.opacity(0.3),
                            Color.DesignSystem.medalGold.opacity(0.2),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    )
                    : LinearGradient(
                        colors: [
                            Color.white.opacity(0.2),
                            Color.DesignSystem.glassBorder,
                            Color.white.opacity(0.1),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                lineWidth: isPinned ? 1.5 : 1,
            )
    }

    private var highlightOverlay: some View {
        RoundedRectangle(cornerRadius: CornerRadius.large)
            .fill(Color.clear)
            .glassHighlightSweep(trigger: $highlightTrigger, color: .white)
    }

    private var categoryColor: Color {
        post.category?.displayColor ?? Color.DesignSystem.brandGreen
    }
}

// MARK: - Glass Stat Badge

struct GlassStatBadge: View {
    let icon: String
    let value: Int
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: icon)
                .foregroundColor(color.opacity(0.8))
                .symbolEffect(.bounce, value: value)
            Text("\(value)")
                .contentTransition(.numericText())
                .animation(.interpolatingSpring(stiffness: 280, damping: 25), value: value)
        }
        .font(.DesignSystem.captionSmall)
        .foregroundStyle(Color.DesignSystem.textSecondary)
    }
}

// MARK: - Glass Post Card Button Style

struct GlassPostCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        GlassCardPressWrapper(isPressed: configuration.isPressed, reduceMotion: reduceMotion) {
            configuration.label
        }
    }
}

// MARK: - Glass Card Press Wrapper

private struct GlassCardPressWrapper<Content: View>: View {
    let isPressed: Bool
    let reduceMotion: Bool
    let content: () -> Content

    @State private var pressLocation: CGPoint = .zero
    @State private var showRipple = false

    var body: some View {
        content()
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .brightness(isPressed ? 0.03 : 0)
            .rotation3DEffect(
                .degrees(isPressed ? 2 : 0),
                axis: (x: 0.8, y: -0.2, z: 0),
                anchor: .center,
                anchorZ: 0,
                perspective: 0.3,
            )
            .shadow(
                color: .black.opacity(isPressed ? 0.15 : 0.08),
                radius: isPressed ? 4 : 8,
                y: isPressed ? 2 : 4,
            )
            .overlay(
                // Subtle highlight sweep on press
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isPressed ? 0.15 : 0),
                                Color.white.opacity(isPressed ? 0.05 : 0),
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .allowsHitTesting(false),
            )
            .animation(
                reduceMotion ? .none : .spring(response: 0.2, dampingFraction: 0.65),
                value: isPressed,
            )
    }
}

// MARK: - Glass Skeleton Card (Loading State)

struct GlassSkeletonCard: View {
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header skeleton
            HStack(spacing: Spacing.sm) {
                Circle()
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: 100, height: 12)
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: 60, height: 10)
                }

                Spacer()

                Capsule()
                    .frame(width: 60, height: 24)
            }

            // Title skeleton
            RoundedRectangle(cornerRadius: 4)
                .frame(height: 16)
            RoundedRectangle(cornerRadius: 4)
                .frame(width: 200, height: 16)

            // Description skeleton
            RoundedRectangle(cornerRadius: 4)
                .frame(height: 12)
            RoundedRectangle(cornerRadius: 4)
                .frame(width: 240, height: 12)

            // Footer skeleton
            HStack(spacing: Spacing.md) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 4)
                        .frame(width: 40, height: 14)
                }
                Spacer()
                Capsule()
                    .frame(width: 70, height: 20)
            }
        }
        .foregroundStyle(Color.DesignSystem.glassBackground)
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large))
        .glassShimmer(isActive: true)
    }
}

// MARK: - Glass Loading Indicator

struct GlassLoadingIndicator: View {
    let message: String

    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Custom glass spinner
            ZStack {
                Circle()
                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 3)
                    .frame(width: 24, height: 24)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round),
                    )
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }

            Text(message)
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Forum Filters Sheet

struct ForumFiltersSheet: View {
    @Environment(\.translationService) private var t
    @Binding var filters: ForumFilters
    let categories: [ForumCategory]
    let onApply: () -> Void
    var onSavedPostsTap: (() -> Void)?
    var onNotificationsTap: (() -> Void)?
    var unreadNotificationCount = 0
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false
    @State private var sectionAppearStates: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                mainContent
            }
            .navigationTitle(t.t("forum.filters.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                toolbarLeading
                toolbarTrailing
            }
            .confirmationDialog(t.t("forum.filters.reset_title"), isPresented: $showResetConfirmation) {
                Button(t.t("forum.filters.reset_to_defaults"), role: .destructive) {
                    resetFilters()
                }
                Button(t.t("common.action.cancel"), role: .cancel) {
                    HapticManager.soft()
                }
            } message: {
                Text(t.t("forum.filters.reset_message"))
            }
            .onAppear {
                animateSectionsIn()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CornerRadius.xl)
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                sortBySection
                postTypeSection
                optionsSection
                yourContentSection
            }
            .padding(Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Sections

    private var sortBySection: some View {
        filterSection(
            id: "sortBy",
            icon: "arrow.up.arrow.down",
            title: t.t("forum.filters.sort_by"),
        ) {
            VStack(spacing: Spacing.sm) {
                ForEach(ForumSortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(ProMotionAnimation.smooth) {
                            filters.sortBy = option
                        }
                        HapticManager.selection()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: option.icon)
                                .font(.system(size: 14))
                                .foregroundColor(filters.sortBy == option
                                    ? .DesignSystem.brandGreen
                                    : .DesignSystem.textSecondary)
                                    .frame(width: 24)
                                    .symbolEffect(.pulse, options: .repeating, value: filters.sortBy == option)

                            Text(option.displayName)
                                .font(.DesignSystem.bodySmall)
                                .foregroundColor(.DesignSystem.text)

                            Spacer()

                            if filters.sortBy == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.DesignSystem.brandGreen)
                                    .symbolEffect(.bounce, value: filters.sortBy)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(filters.sortBy == option
                                    ? Color.DesignSystem.brandGreen.opacity(0.1)
                                    : Color.clear),
                        )
                    }
                    .buttonStyle(ProMotionButtonStyle())
                }
            }
        }
    }

    private var postTypeSection: some View {
        filterSection(
            id: "postType",
            icon: "doc.text",
            title: t.t("forum.filters.post_type"),
        ) {
            VStack(spacing: Spacing.sm) {
                // All Types option
                postTypeButton(type: nil, displayName: t.t("forum.filters.all_types"), icon: "square.grid.2x2")

                ForEach(ForumPostType.allCases, id: \.self) { type in
                    postTypeButton(type: type, displayName: type.displayName, icon: type.iconName)
                }
            }
        }
    }

    private func postTypeButton(type: ForumPostType?, displayName: String, icon: String) -> some View {
        Button {
            withAnimation(ProMotionAnimation.smooth) {
                filters.postType = type
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(filters.postType == type
                        ? .DesignSystem.brandGreen
                        : .DesignSystem.textSecondary)
                        .frame(width: 24)

                Text(displayName)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                if filters.postType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.DesignSystem.brandGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(filters.postType == type
                        ? Color.DesignSystem.brandGreen.opacity(0.1)
                        : Color.clear),
            )
        }
        .buttonStyle(ProMotionButtonStyle())
    }

    private var optionsSection: some View {
        filterSection(
            id: "options",
            icon: "slider.horizontal.3",
            title: t.t("forum.filters.options"),
        ) {
            VStack(spacing: Spacing.md) {
                // Questions Only Toggle
                glassToggle(
                    title: t.t("forum.filters.questions_only"),
                    subtitle: t.t("forum.filters.questions_only_subtitle"),
                    icon: "questionmark.circle",
                    isOn: $filters.showQuestionsOnly,
                )

                // Unanswered Only Toggle
                glassToggle(
                    title: t.t("forum.filters.unanswered_only"),
                    subtitle: t.t("forum.filters.unanswered_only_subtitle"),
                    icon: "exclamationmark.bubble",
                    isOn: $filters.showUnansweredOnly,
                )
            }
        }
    }

    private var yourContentSection: some View {
        filterSection(
            id: "yourContent",
            icon: "person.crop.circle",
            title: t.t("forum.filters.your_content"),
        ) {
            VStack(spacing: Spacing.sm) {
                // Saved Posts
                navigationRow(
                    title: t.t("forum.filters.saved_posts"),
                    subtitle: t.t("forum.filters.saved_posts_subtitle"),
                    icon: "bookmark.fill",
                    iconColor: .DesignSystem.accentOrange,
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSavedPostsTap?()
                    }
                }

                // Notifications
                navigationRow(
                    title: t.t("forum.filters.notifications"),
                    subtitle: t.t("forum.filters.notifications_subtitle"),
                    icon: "bell.fill",
                    iconColor: .DesignSystem.brandBlue,
                    badge: unreadNotificationCount,
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onNotificationsTap?()
                    }
                }
            }
        }
    }

    private func navigationRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        badge: Int = 0,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.DesignSystem.text)

                    Text(subtitle)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()

                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing,
                                    ),
                                ),
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                    ),
            )
        }
        .buttonStyle(ProMotionButtonStyle())
    }

    private func glassToggle(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .DesignSystem.brandGreen.opacity(0.15),
                                .DesignSystem.brandBlue.opacity(0.15),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.DesignSystem.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(.DesignSystem.text)

                Text(subtitle)
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.DesignSystem.brandGreen)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    HapticManager.selection()
                }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    // MARK: - Toolbar

    private var toolbarLeading: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                HapticManager.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
            }
        }
    }

    private var toolbarTrailing: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showResetConfirmation = true
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .symbolEffect(.rotate, value: showResetConfirmation)
                    Text(t.t("common.action.reset"))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)
                }
                .foregroundColor(.DesignSystem.brandGreen)
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.DesignSystem.background,
                    Color.DesignSystem.surface.opacity(0.5),
                ],
                startPoint: .top,
                endPoint: .bottom,
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.DesignSystem.brandGreen.opacity(0.03),
                    Color.clear,
                ],
                center: .topLeading,
                startRadius: 50,
                endRadius: 400,
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.DesignSystem.brandBlue.opacity(0.03),
                    Color.clear,
                ],
                center: .bottomTrailing,
                startRadius: 50,
                endRadius: 400,
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Helpers

    private func resetFilters() {
        HapticManager.medium()
        withAnimation(ProMotionAnimation.smooth) {
            filters.reset()
        }
        onApply()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            HapticManager.success()
        }
    }

    private func animateSectionsIn() {
        let sections = ["sortBy", "postType", "options", "yourContent"]
        let baseDelay = 0.08

        Task { @MainActor in
            for (index, section) in sections.enumerated() {
                let delayMs = Int(Double(index) * baseDelay * 1000)

                if delayMs > 0 {
                    try? await Task.sleep(for: .milliseconds(delayMs))
                }

                withAnimation(ProMotionAnimation.smooth) {
                    sectionAppearStates[section] = true
                }
            }
        }
    }

    // MARK: - Filter Section Helper

    private func filterSection(
        id: String,
        icon: String,
        title: String,
        @ViewBuilder content: () -> some View,
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with animated icon
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .DesignSystem.brandGreen.opacity(0.2),
                                    .DesignSystem.brandBlue.opacity(0.2),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .symbolEffect(.bounce, options: .nonRepeating, value: sectionAppearStates[id] ?? false)
                }

                Text(title)
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)
            }

            content()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                )
                .shadow(
                    color: .black.opacity(0.05),
                    radius: 8,
                    y: 2,
                ),
        )
        .opacity(sectionAppearStates[id] == true ? 1 : 0)
        .offset(y: sectionAppearStates[id] == true ? 0 : 20)
        .animation(ProMotionAnimation.smooth, value: sectionAppearStates[id])
    }
}
