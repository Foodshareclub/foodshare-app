

#if !SKIP
import CoreData
import Foundation
import OSLog
import Supabase

// MARK: - Supabase Forum Repository (Facade)

/// Supabase implementation of ForumRepository
/// Delegates to specialized sub-repositories for different responsibilities
/// Thread-safe with @MainActor isolation for UI state updates
/// Supports offline-first pattern with automatic cache synchronization
@MainActor
final class SupabaseForumRepository: ForumRepository {
    // MARK: - Sub-Repositories

    private let posts: SupabaseForumPostRepository
    private let comments: SupabaseForumCommentRepository
    private let engagement: SupabaseForumEngagementRepository
    private let polls: SupabaseForumPollRepository
    private let reputation: SupabaseForumReputationRepository

    // MARK: - Initialization

    init(
        supabase: Supabase.SupabaseClient,
        coreDataStack: CoreDataStack = .shared,
        networkMonitor: NetworkMonitor = .shared,
    ) {
        posts = SupabaseForumPostRepository(
            supabase: supabase,
            coreDataStack: coreDataStack,
            networkMonitor: networkMonitor,
        )
        comments = SupabaseForumCommentRepository(supabase: supabase)
        engagement = SupabaseForumEngagementRepository(supabase: supabase)
        polls = SupabaseForumPollRepository(supabase: supabase)
        reputation = SupabaseForumReputationRepository(supabase: supabase)
    }

    // MARK: - Posts (Delegated to SupabaseForumPostRepository)

    func fetchPosts(
        categoryId: Int?,
        postType: ForumPostType?,
        sortBy: ForumSortOption,
        pagination: CursorPaginationParams,
    ) async throws -> [ForumPost] {
        try await posts.fetchPosts(
            categoryId: categoryId,
            postType: postType,
            sortBy: sortBy,
            pagination: pagination,
        )
    }

    func fetchPosts(
        categoryId: Int?,
        postType: ForumPostType?,
        sortBy: ForumSortOption,
        limit: Int,
        offset: Int,
    ) async throws -> [ForumPost] {
        try await posts.fetchPosts(
            categoryId: categoryId,
            postType: postType,
            sortBy: sortBy,
            limit: limit,
            offset: offset,
        )
    }

    func fetchPost(id: Int) async throws -> ForumPost {
        try await posts.fetchPost(id: id)
    }

    func searchPosts(query: String, limit: Int) async throws -> [ForumPost] {
        try await posts.searchPosts(query: query, limit: limit)
    }

    func fetchTrendingPosts(limit: Int) async throws -> [ForumPost] {
        try await posts.fetchTrendingPosts(limit: limit)
    }

    func fetchPinnedPosts(categoryId: Int?) async throws -> [ForumPost] {
        try await posts.fetchPinnedPosts(categoryId: categoryId)
    }

    func createPost(_ request: CreateForumPostRequest) async throws -> ForumPost {
        try await posts.createPost(request)
    }

    func updatePost(id: Int, _ request: UpdateForumPostRequest) async throws -> ForumPost {
        try await posts.updatePost(id: id, request)
    }

    func deletePost(id: Int, profileId: UUID) async throws {
        try await posts.deletePost(id: id, profileId: profileId)
    }

    func fetchCategories() async throws -> [ForumCategory] {
        try await posts.fetchCategories()
    }

    func fetchPopularTags(limit: Int) async throws -> [ForumTag] {
        try await posts.fetchPopularTags(limit: limit)
    }

    // MARK: - Comments (Delegated to SupabaseForumCommentRepository)

    func fetchComments(forumId: Int, pagination: CursorPaginationParams) async throws -> [ForumComment] {
        try await comments.fetchComments(forumId: forumId, pagination: pagination)
    }

    func fetchComments(forumId: Int, limit: Int, offset: Int) async throws -> [ForumComment] {
        try await comments.fetchComments(forumId: forumId, limit: limit, offset: offset)
    }

    func createComment(_ request: CreateCommentRequest) async throws -> ForumComment {
        try await comments.createComment(request)
    }

    func updateComment(id: Int, content: String) async throws -> ForumComment {
        try await comments.updateComment(id: id, content: content)
    }

    func fetchReplies(commentId: Int, limit: Int, offset: Int) async throws -> [ForumComment] {
        try await comments.fetchReplies(commentId: commentId, limit: limit, offset: offset)
    }

    func deleteComment(id: Int) async throws {
        try await comments.deleteComment(id: id)
    }

    // MARK: - Reactions (Delegated to SupabaseForumEngagementRepository)

    func togglePostLike(forumId: Int, profileId: UUID) async throws -> Bool {
        try await engagement.togglePostLike(forumId: forumId, profileId: profileId)
    }

    func toggleCommentLike(commentId: Int, profileId: UUID) async throws -> Bool {
        try await engagement.toggleCommentLike(commentId: commentId, profileId: profileId)
    }

    func hasLikedPost(forumId: Int, profileId: UUID) async throws -> Bool {
        try await engagement.hasLikedPost(forumId: forumId, profileId: profileId)
    }

    // MARK: - Emoji Reactions (Delegated to SupabaseForumEngagementRepository)

    func fetchReactionTypes() async throws -> [ReactionType] {
        try await engagement.fetchReactionTypes()
    }

    func fetchPostReactions(forumId: Int, profileId: UUID) async throws -> ReactionsSummary {
        try await engagement.fetchPostReactions(forumId: forumId, profileId: profileId)
    }

    func fetchCommentReactions(commentId: Int, profileId: UUID) async throws -> ReactionsSummary {
        try await engagement.fetchCommentReactions(commentId: commentId, profileId: profileId)
    }

    func togglePostReaction(forumId: Int, reactionTypeId: Int, profileId: UUID) async throws -> ReactionsSummary {
        try await engagement.togglePostReaction(forumId: forumId, reactionTypeId: reactionTypeId, profileId: profileId)
    }

    func toggleCommentReaction(commentId: Int, reactionTypeId: Int, profileId: UUID) async throws -> ReactionsSummary {
        try await engagement.toggleCommentReaction(commentId: commentId, reactionTypeId: reactionTypeId, profileId: profileId)
    }

    func fetchPostReactors(forumId: Int, reactionTypeId: Int, limit: Int) async throws -> [UUID] {
        try await engagement.fetchPostReactors(forumId: forumId, reactionTypeId: reactionTypeId, limit: limit)
    }

    // MARK: - Bookmarks (Delegated to SupabaseForumEngagementRepository)

    func toggleBookmark(forumId: Int, profileId: UUID) async throws -> Bool {
        try await engagement.toggleBookmark(forumId: forumId, profileId: profileId)
    }

    func fetchBookmarkedPosts(profileId: UUID, pagination: CursorPaginationParams) async throws -> [ForumPost] {
        try await engagement.fetchBookmarkedPosts(profileId: profileId, pagination: pagination)
    }

    func fetchBookmarkedPosts(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumPost] {
        try await engagement.fetchBookmarkedPosts(profileId: profileId, limit: limit, offset: offset)
    }

    func recordView(forumId: Int, profileId: UUID) async throws {
        try await engagement.recordView(forumId: forumId, profileId: profileId)
    }

    // MARK: - Polls (Delegated to SupabaseForumPollRepository)

    func fetchPoll(forumId: Int) async throws -> ForumPoll? {
        try await polls.fetchPoll(forumId: forumId)
    }

    func fetchPollWithOptions(pollId: UUID, profileId: UUID) async throws -> ForumPoll {
        try await polls.fetchPollWithOptions(pollId: pollId, profileId: profileId)
    }

    func votePoll(pollId: UUID, optionIds: [UUID], profileId: UUID) async throws -> ForumPoll {
        try await polls.votePoll(pollId: pollId, optionIds: optionIds, profileId: profileId)
    }

    func removeVote(pollId: UUID, optionId: UUID, profileId: UUID) async throws {
        try await polls.removeVote(pollId: pollId, optionId: optionId, profileId: profileId)
    }

    func createPoll(_ request: CreatePollRequest) async throws -> ForumPoll {
        try await polls.createPoll(request)
    }

    func fetchPollResults(pollId: UUID, profileId: UUID) async throws -> ForumPollResults {
        try await polls.fetchPollResults(pollId: pollId, profileId: profileId)
    }

    // MARK: - Reputation & Trust Levels (Delegated to SupabaseForumReputationRepository)

    func fetchUserStats(profileId: UUID) async throws -> ForumUserStats {
        try await reputation.fetchUserStats(profileId: profileId)
    }

    func fetchOrCreateUserStats(profileId: UUID) async throws -> ForumUserStats {
        try await reputation.fetchOrCreateUserStats(profileId: profileId)
    }

    func fetchTrustLevels() async throws -> [ForumTrustLevel] {
        try await reputation.fetchTrustLevels()
    }

    func fetchTrustLevel(level: Int) async throws -> ForumTrustLevel {
        try await reputation.fetchTrustLevel(level: level)
    }

    func fetchReputationHistory(profileId: UUID, limit: Int) async throws -> [ReputationHistoryItem] {
        try await reputation.fetchReputationHistory(profileId: profileId, limit: limit)
    }

    func incrementUserStat(profileId: UUID, stat: UserStatType, by amount: Int) async throws {
        try await reputation.incrementUserStat(profileId: profileId, stat: stat, by: amount)
    }

    func canPerformAction(profileId: UUID, action: TrustLevelAction) async throws -> Bool {
        try await reputation.canPerformAction(profileId: profileId, action: action)
    }

    // MARK: - Badges (Delegated to SupabaseForumReputationRepository)

    func fetchBadges() async throws -> [ForumBadge] {
        try await reputation.fetchBadges()
    }

    func fetchUserBadges(profileId: UUID) async throws -> [UserBadgeWithDetails] {
        try await reputation.fetchUserBadges(profileId: profileId)
    }

    func fetchBadgeCollection(profileId: UUID) async throws -> BadgeCollection {
        try await reputation.fetchBadgeCollection(profileId: profileId)
    }

    func hasEarnedBadge(profileId: UUID, badgeId: Int) async throws -> Bool {
        try await reputation.hasEarnedBadge(profileId: profileId, badgeId: badgeId)
    }

    func awardBadge(badgeId: Int, to profileId: UUID, by awarderId: UUID?) async throws -> UserBadge {
        try await reputation.awardBadge(badgeId: badgeId, to: profileId, by: awarderId)
    }

    func toggleFeaturedBadge(userBadgeId: UUID, profileId: UUID) async throws -> Bool {
        try await reputation.toggleFeaturedBadge(userBadgeId: userBadgeId, profileId: profileId)
    }

    func fetchNextBadges(profileId: UUID, limit: Int) async throws -> [(badge: ForumBadge, progress: Double)] {
        try await reputation.fetchNextBadges(profileId: profileId, limit: limit)
    }

    // MARK: - Subscriptions (Delegated to SupabaseForumReputationRepository)

    func fetchPostSubscription(forumId: Int, profileId: UUID) async throws -> ForumSubscription? {
        try await reputation.fetchPostSubscription(forumId: forumId, profileId: profileId)
    }

    func fetchCategorySubscription(categoryId: Int, profileId: UUID) async throws -> ForumSubscription? {
        try await reputation.fetchCategorySubscription(categoryId: categoryId, profileId: profileId)
    }

    func fetchSubscriptions(profileId: UUID) async throws -> [ForumSubscription] {
        try await reputation.fetchSubscriptions(profileId: profileId)
    }

    func subscribeToPost(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription {
        try await reputation.subscribeToPost(request)
    }

    func subscribeToCategory(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription {
        try await reputation.subscribeToCategory(request)
    }

    func unsubscribeFromPost(forumId: Int, profileId: UUID) async throws {
        try await reputation.unsubscribeFromPost(forumId: forumId, profileId: profileId)
    }

    func unsubscribeFromCategory(categoryId: Int, profileId: UUID) async throws {
        try await reputation.unsubscribeFromCategory(categoryId: categoryId, profileId: profileId)
    }

    func updateSubscription(id: UUID, preferences: SubscriptionPreferences) async throws -> ForumSubscription {
        try await reputation.updateSubscription(id: id, preferences: preferences)
    }

    // MARK: - Notifications (Delegated to SupabaseForumReputationRepository)

    func fetchNotifications(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumNotification] {
        try await reputation.fetchNotifications(profileId: profileId, limit: limit, offset: offset)
    }

    func fetchUnreadNotificationCount(profileId: UUID) async throws -> Int {
        try await reputation.fetchUnreadNotificationCount(profileId: profileId)
    }

    func markNotificationAsRead(id: UUID) async throws {
        try await reputation.markNotificationAsRead(id: id)
    }

    func markAllNotificationsAsRead(profileId: UUID) async throws {
        try await reputation.markAllNotificationsAsRead(profileId: profileId)
    }

    func deleteNotification(id: UUID) async throws {
        try await reputation.deleteNotification(id: id)
    }

    func deleteReadNotifications(profileId: UUID) async throws {
        try await reputation.deleteReadNotifications(profileId: profileId)
    }
}


#endif
