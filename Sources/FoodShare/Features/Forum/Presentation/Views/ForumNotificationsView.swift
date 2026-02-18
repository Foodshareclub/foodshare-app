//
//  ForumNotificationsView.swift
//  Foodshare
//
//  Forum notifications view with grouped notifications and management
//  Follows Liquid Glass Design System v26
//


#if !SKIP
import SwiftUI

#if DEBUG
    import Inject
#endif

// MARK: - Forum Notifications View

struct ForumNotificationsView: View {
    
    @Environment(\.translationService) private var t
    @State private var viewModel: ForumNotificationsViewModel
    @Environment(\.dismiss) private var dismiss

    init(repository: ForumRepository, profileId: UUID) {
        _viewModel = State(initialValue: ForumNotificationsViewModel(
            repository: repository,
            profileId: profileId,
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.DesignSystem.background
                    .ignoresSafeArea()

                if viewModel.isLoading, viewModel.notifications.isEmpty {
                    loadingView
                } else if viewModel.notifications.isEmpty {
                    GlassEmptyNotificationsView()
                } else {
                    notificationsList
                }
            }
            .navigationTitle(t.t("common.notifications"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(t.t("common.done")) {
                        dismiss()
                    }
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.primary)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if viewModel.unreadCount > 0 {
                            Button(action: viewModel.markAllAsRead) {
                                Label(t.t("notifications.mark_all_read"), systemImage: "checkmark.circle")
                            }
                        }

                        Button(action: viewModel.deleteReadNotifications) {
                            Label(t.t("notifications.clear_read"), systemImage: "trash")
                        }

                        Divider()

                        Button(action: { viewModel.showSettings = true }) {
                            Label(t.t("common.settings"), systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadNotifications()
            }
            .sheet(isPresented: $viewModel.showSettings) {
                NotificationSettingsSheet()
            }
            .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
                Button(t.t("common.ok"), role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color.DesignSystem.primary))
                .scaleEffect(1.2)

            Text(t.t("notifications.loading"))
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
    }

    private var notificationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                // Unread section
                if !viewModel.unreadNotifications.isEmpty {
                    Section {
                        ForEach(viewModel.unreadNotifications) { notification in
                            notificationRow(notification)
                        }
                    } header: {
                        sectionHeader(t.t("notifications.unread"), count: viewModel.unreadCount)
                    }
                }

                // Today section
                if !viewModel.todayNotifications.isEmpty {
                    Section {
                        ForEach(viewModel.todayNotifications) { notification in
                            notificationRow(notification)
                        }
                    } header: {
                        sectionHeader(t.t("common.today"), count: viewModel.todayNotifications.count)
                    }
                }

                // Earlier section
                if !viewModel.earlierNotifications.isEmpty {
                    Section {
                        ForEach(viewModel.earlierNotifications) { notification in
                            notificationRow(notification)
                        }
                    } header: {
                        sectionHeader(t.t("common.earlier"), count: viewModel.earlierNotifications.count)
                    }
                }

                // Load more indicator
                if viewModel.hasMore {
                    loadMoreButton
                        .padding(.vertical, Spacing.md)
                }
            }
        }
    }

    private func notificationRow(_ notification: ForumNotification) -> some View {
        GlassNotificationRow(
            notification: notification,
            onTap: {
                viewModel.handleNotificationTap(notification)
            },
            onMarkRead: {
                Task {
                    await viewModel.markAsRead(notification)
                }
            },
        )
        .contextMenu {
            if !notification.isRead {
                Button {
                    Task { await viewModel.markAsRead(notification) }
                } label: {
                    Label(t.t("notifications.mark_as_read"), systemImage: "checkmark.circle")
                }
            }

            Button(role: .destructive) {
                Task { await viewModel.deleteNotification(notification) }
            } label: {
                Label(t.t("common.delete"), systemImage: "trash")
            }
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.DesignSystem.labelMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)

            if count > 0 {
                Text("\(count)")
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.DesignSystem.primary.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.DesignSystem.background.opacity(0.95))
    }

    private var loadMoreButton: some View {
        Button(action: {
            Task { await viewModel.loadMore() }
        }) {
            HStack(spacing: Spacing.xs) {
                if viewModel.isLoadingMore {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.DesignSystem.primary))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.down.circle")
                }
                Text(t.t("common.load_more"))
            }
            .font(.DesignSystem.labelMedium)
            .foregroundStyle(Color.DesignSystem.primary)
        }
        .disabled(viewModel.isLoadingMore)
    }
}

// MARK: - View Model

@Observable
@MainActor
final class ForumNotificationsViewModel {
    // Dependencies
    private let repository: ForumRepository
    private let profileId: UUID

    // State
    var notifications: [ForumNotification] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMore = true
    var showSettings = false
    var showError = false
    var errorMessage = ""

    // Navigation
    var selectedNotification: ForumNotification?

    // Pagination
    private var currentOffset = 0
    private var pageSize: Int { AppConfiguration.shared.pageSize }

    init(repository: ForumRepository, profileId: UUID) {
        self.repository = repository
        self.profileId = profileId
    }

    // MARK: - Computed Properties

    var unreadCount: Int {
        notifications.count(where: { !$0.isRead })
    }

    var unreadNotifications: [ForumNotification] {
        notifications.filter { !$0.isRead }
    }

    var todayNotifications: [ForumNotification] {
        let calendar = Calendar.current
        return notifications.filter { notification in
            guard notification.isRead, let createdAt = notification.createdAt else { return false }
            return calendar.isDateInToday(createdAt)
        }
    }

    var earlierNotifications: [ForumNotification] {
        let calendar = Calendar.current
        return notifications.filter { notification in
            guard notification.isRead, let createdAt = notification.createdAt else { return false }
            return !calendar.isDateInToday(createdAt)
        }
    }

    // MARK: - Actions

    func loadNotifications() async {
        guard !isLoading else { return }

        isLoading = true
        currentOffset = 0

        do {
            let fetched = try await repository.fetchNotifications(
                profileId: profileId,
                limit: pageSize,
                offset: 0,
            )
            notifications = fetched
            hasMore = fetched.count == pageSize
        } catch {
            showErrorMessage("Failed to load notifications")
        }

        isLoading = false
    }

    func loadMore() async {
        guard !isLoadingMore, hasMore else { return }

        isLoadingMore = true
        currentOffset += pageSize

        do {
            let fetched = try await repository.fetchNotifications(
                profileId: profileId,
                limit: pageSize,
                offset: currentOffset,
            )
            notifications.append(contentsOf: fetched)
            hasMore = fetched.count == pageSize
        } catch {
            currentOffset -= pageSize
            showErrorMessage("Failed to load more notifications")
        }

        isLoadingMore = false
    }

    func refresh() async {
        await loadNotifications()
    }

    func markAsRead(_ notification: ForumNotification) async {
        guard !notification.isRead else { return }

        do {
            try await repository.markNotificationAsRead(id: notification.id)
            if let index = notifications.firstIndex(where: { $0.id == notification.id }) {
                // Create updated notification with isRead = true
                let updated = ForumNotification(
                    id: notification.id,
                    recipientId: notification.recipientId,
                    actorId: notification.actorId,
                    type: notification.type,
                    forumId: notification.forumId,
                    commentId: notification.commentId,
                    data: notification.data,
                    isRead: true,
                    createdAt: notification.createdAt,
                )
                notifications[index] = updated
            }
            HapticManager.light()
        } catch {
            showErrorMessage("Failed to mark as read")
        }
    }

    func markAllAsRead() {
        Task {
            do {
                try await repository.markAllNotificationsAsRead(profileId: profileId)
                notifications = notifications.map { notification in
                    ForumNotification(
                        id: notification.id,
                        recipientId: notification.recipientId,
                        actorId: notification.actorId,
                        type: notification.type,
                        forumId: notification.forumId,
                        commentId: notification.commentId,
                        data: notification.data,
                        isRead: true,
                        createdAt: notification.createdAt,
                    )
                }
                HapticManager.success()
            } catch {
                showErrorMessage("Failed to mark all as read")
            }
        }
    }

    func deleteNotification(_ notification: ForumNotification) async {
        do {
            try await repository.deleteNotification(id: notification.id)
            notifications.removeAll { $0.id == notification.id }
            HapticManager.light()
        } catch {
            showErrorMessage("Failed to delete notification")
        }
    }

    func deleteReadNotifications() {
        Task {
            do {
                try await repository.deleteReadNotifications(profileId: profileId)
                notifications.removeAll { $0.isRead }
                HapticManager.success()
            } catch {
                showErrorMessage("Failed to clear notifications")
            }
        }
    }

    func handleNotificationTap(_ notification: ForumNotification) {
        selectedNotification = notification

        // Mark as read if needed
        if !notification.isRead {
            Task { await markAsRead(notification) }
        }

        // Navigation would be handled by parent view
        // For now just trigger haptic
        HapticManager.light()
    }

    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - Notification Settings Sheet

struct NotificationSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @State private var replyNotifications = true
    @State private var mentionNotifications = true
    @State private var reactionNotifications = false
    @State private var emailNotifications = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $replyNotifications) {
                        Label(t.t("notifications.replies"), systemImage: "arrowshape.turn.up.left.fill")
                    }

                    Toggle(isOn: $mentionNotifications) {
                        Label(t.t("notifications.mentions"), systemImage: "at")
                    }

                    Toggle(isOn: $reactionNotifications) {
                        Label(t.t("notifications.reactions"), systemImage: "face.smiling.fill")
                    }
                } header: {
                    Text(t.t("notifications.push"))
                } footer: {
                    Text(t.t("notifications.push_footer"))
                }

                Section {
                    Toggle(isOn: $emailNotifications) {
                        Label(t.t("notifications.email_digest"), systemImage: "envelope.fill")
                    }
                } header: {
                    Text(t.t("common.email"))
                } footer: {
                    Text(t.t("notifications.email_footer"))
                }
            }
            .navigationTitle(t.t("settings.notifications.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) {
                        dismiss()
                    }
                }
            }
            .tint(Color.DesignSystem.primary)
        }
    }
}

// MARK: - Previews

#if DEBUG

    #Preview("Notifications View") {
        ForumNotificationsView(
            repository: PreviewForumRepository(),
            profileId: UUID(),
        )
    }

    #Preview("Settings Sheet") {
        NotificationSettingsSheet()
    }

    // MARK: - Preview Repository
    private final class PreviewForumRepository: ForumRepository, @unchecked Sendable {
        func fetchPosts(
            categoryId: Int?,
            postType: ForumPostType?,
            sortBy: ForumSortOption,
            pagination: CursorPaginationParams,
        ) async throws -> [ForumPost] { [] }
        func fetchPosts(
            categoryId: Int?,
            postType: ForumPostType?,
            sortBy: ForumSortOption,
            limit: Int,
            offset: Int,
        ) async throws -> [ForumPost] { [] }
        func fetchPost(id: Int) async throws -> ForumPost { ForumPost.fixture() }
        func searchPosts(query: String, limit: Int) async throws -> [ForumPost] { [] }
        func fetchTrendingPosts(limit: Int) async throws -> [ForumPost] { [] }
        func fetchPinnedPosts(categoryId: Int?) async throws -> [ForumPost] { [] }
        func createPost(_ request: CreateForumPostRequest) async throws -> ForumPost { ForumPost.fixture() }
        func updatePost(id: Int, _ request: UpdateForumPostRequest) async throws -> ForumPost { ForumPost.fixture() }
        func deletePost(id: Int, profileId: UUID) async throws {}
        func fetchCategories() async throws -> [ForumCategory] { [] }
        func fetchPopularTags(limit: Int) async throws -> [ForumTag] { [] }
        func fetchComments(forumId: Int, pagination: CursorPaginationParams) async throws -> [ForumComment] { [] }
        func fetchComments(forumId: Int, limit: Int, offset: Int) async throws -> [ForumComment] { [] }
        func createComment(_ request: CreateCommentRequest) async throws -> ForumComment { ForumComment.fixture() }
        func updateComment(id: Int, content: String) async throws -> ForumComment { ForumComment.fixture() }
        func fetchReplies(commentId: Int, limit: Int, offset: Int) async throws -> [ForumComment] { [] }
        func deleteComment(id: Int) async throws {}
        func togglePostLike(forumId: Int, profileId: UUID) async throws -> Bool { true }
        func toggleCommentLike(commentId: Int, profileId: UUID) async throws -> Bool { true }
        func hasLikedPost(forumId: Int, profileId: UUID) async throws -> Bool { false }
        func fetchReactionTypes() async throws -> [ReactionType] { ReactionType.all }
        func fetchPostReactions(forumId: Int, profileId: UUID) async throws -> ReactionsSummary { ReactionsSummary() }
        func fetchCommentReactions(
            commentId: Int,
            profileId: UUID,
        ) async throws -> ReactionsSummary { ReactionsSummary() }
        func togglePostReaction(
            forumId: Int,
            reactionTypeId: Int,
            profileId: UUID,
        ) async throws -> ReactionsSummary { ReactionsSummary() }
        func toggleCommentReaction(
            commentId: Int,
            reactionTypeId: Int,
            profileId: UUID,
        ) async throws -> ReactionsSummary { ReactionsSummary() }
        func fetchPostReactors(forumId: Int, reactionTypeId: Int, limit: Int) async throws -> [UUID] { [] }
        func toggleBookmark(forumId: Int, profileId: UUID) async throws -> Bool { true }
        func fetchBookmarkedPosts(profileId: UUID, pagination: CursorPaginationParams) async throws -> [ForumPost] { []
        }
        func fetchBookmarkedPosts(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumPost] { [] }
        func recordView(forumId: Int, profileId: UUID) async throws {}
        func fetchPoll(forumId: Int) async throws -> ForumPoll? { nil }
        func fetchPollWithOptions(pollId: UUID, profileId: UUID) async throws -> ForumPoll { ForumPoll.fixture() }
        func votePoll(pollId: UUID, optionIds: [UUID], profileId: UUID) async throws -> ForumPoll { ForumPoll.fixture()
        }
        func removeVote(pollId: UUID, optionId: UUID, profileId: UUID) async throws {}
        func createPoll(_ request: CreatePollRequest) async throws -> ForumPoll { ForumPoll.fixture() }
        func fetchPollResults(
            pollId: UUID,
            profileId: UUID,
        ) async throws -> ForumPollResults { ForumPollResults.fixture() }
        func fetchUserStats(profileId: UUID) async throws -> ForumUserStats { ForumUserStats.fixture() }
        func fetchOrCreateUserStats(profileId: UUID) async throws -> ForumUserStats { ForumUserStats.fixture() }
        func fetchTrustLevels() async throws -> [ForumTrustLevel] { ForumTrustLevel.allLevels }
        func fetchTrustLevel(level: Int) async throws -> ForumTrustLevel { ForumTrustLevel.allLevels[0] }
        func fetchReputationHistory(profileId: UUID, limit: Int) async throws -> [ReputationHistoryItem] { [] }
        func incrementUserStat(profileId: UUID, stat: UserStatType, by amount: Int) async throws {}
        func canPerformAction(profileId: UUID, action: TrustLevelAction) async throws -> Bool { true }
        func fetchBadges() async throws -> [ForumBadge] { ForumBadge.fixtures }
        func fetchUserBadges(profileId: UUID) async throws -> [UserBadgeWithDetails] { [] }
        func fetchBadgeCollection(profileId: UUID) async throws -> BadgeCollection { BadgeCollection.fixture }
        func hasEarnedBadge(profileId: UUID, badgeId: Int) async throws -> Bool { false }
        func awardBadge(
            badgeId: Int,
            to profileId: UUID,
            by awarderId: UUID?,
        ) async throws -> UserBadge { UserBadge.fixture() }
        func toggleFeaturedBadge(userBadgeId: UUID, profileId: UUID) async throws -> Bool { true }
        func fetchNextBadges(profileId: UUID, limit: Int) async throws -> [(badge: ForumBadge, progress: Double)] { [] }
        func fetchPostSubscription(forumId: Int, profileId: UUID) async throws -> ForumSubscription? { nil }
        func fetchCategorySubscription(categoryId: Int, profileId: UUID) async throws -> ForumSubscription? { nil }
        func fetchSubscriptions(profileId: UUID) async throws -> [ForumSubscription] { [] }
        func subscribeToPost(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription { .fixture() }
        func subscribeToCategory(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription { .fixture() }
        func unsubscribeFromPost(forumId: Int, profileId: UUID) async throws {}
        func unsubscribeFromCategory(categoryId: Int, profileId: UUID) async throws {}
        func updateSubscription(
            id: UUID,
            preferences: SubscriptionPreferences,
        ) async throws -> ForumSubscription { .fixture() }
        func fetchNotifications(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumNotification] {
            ForumNotification.fixtures
        }
        func fetchUnreadNotificationCount(profileId: UUID) async throws -> Int { 3 }
        func markNotificationAsRead(id: UUID) async throws {}
        func markAllNotificationsAsRead(profileId: UUID) async throws {}
        func deleteNotification(id: UUID) async throws {}
        func deleteReadNotifications(profileId: UUID) async throws {}
    }
#endif

#endif
