//
//  MockForumRepository.swift
//  Foodshare
//
//  Mock implementation of ForumRepository for testing
//

import Foundation

#if DEBUG
/// Mock implementation of ForumRepository for unit tests
/// Implements core forum functionality for testing
final class MockForumRepository: ForumRepository, @unchecked Sendable {
    // MARK: - Test Configuration

    var shouldFail = false
    var delay: TimeInterval = 0

    // MARK: - Mock Data

    var mockPosts: [ForumPost] = [
        ForumPost.fixture(id: 1, title: "Welcome to Foodshare Forum"),
        ForumPost.fixture(id: 2, title: "Best practices for sharing food"),
        ForumPost.fixture(id: 3, title: "Recipe exchange thread", postType: .question),
    ]
    var mockCategories: [ForumCategory] = []
    var mockComments: [Int: [ForumComment]] = [:]
    var mockTags: [ForumTag] = []
    var likedPosts: Set<Int> = []
    var bookmarkedPosts: Set<Int> = []

    // MARK: - Call Tracking

    private(set) var fetchPostsCallCount = 0
    private(set) var fetchPostCallCount = 0
    private(set) var fetchCommentsCallCount = 0
    private(set) var createCommentCallCount = 0
    private(set) var toggleLikeCallCount = 0
    private(set) var toggleBookmarkCallCount = 0

    // MARK: - Posts (Cursor-Based Pagination)

    func fetchPosts(
        categoryId: Int?,
        postType: ForumPostType?,
        sortBy: ForumSortOption,
        pagination: CursorPaginationParams
    ) async throws -> [ForumPost] {
        fetchPostsCallCount += 1

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        var filtered = mockPosts

        if let categoryId {
            filtered = filtered.filter { $0.categoryId == categoryId }
        }

        if let postType {
            filtered = filtered.filter { $0.postType == postType }
        }

        return Array(filtered.prefix(pagination.limit))
    }

    func fetchPosts(
        categoryId: Int?,
        postType: ForumPostType?,
        sortBy: ForumSortOption,
        limit: Int,
        offset: Int
    ) async throws -> [ForumPost] {
        fetchPostsCallCount += 1

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        var filtered = mockPosts

        if let categoryId {
            filtered = filtered.filter { $0.categoryId == categoryId }
        }

        if let postType {
            filtered = filtered.filter { $0.postType == postType }
        }

        let endIndex = min(offset + limit, filtered.count)
        guard offset < filtered.count else { return [] }
        return Array(filtered[offset..<endIndex])
    }

    func fetchPost(id: Int) async throws -> ForumPost {
        fetchPostCallCount += 1

        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        guard let post = mockPosts.first(where: { $0.id == id }) else {
            throw AppError.notFound(resource: "ForumPost")
        }

        return post
    }

    func searchPosts(query: String, limit: Int) async throws -> [ForumPost] {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        let lowercaseQuery = query.lowercased()
        return mockPosts.filter {
            $0.title.lowercased().contains(lowercaseQuery) ||
            $0.description.lowercased().contains(lowercaseQuery)
        }.prefix(limit).map { $0 }
    }

    func fetchTrendingPosts(limit: Int) async throws -> [ForumPost] {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        return Array(mockPosts.prefix(limit))
    }

    func fetchPinnedPosts(categoryId: Int?) async throws -> [ForumPost] {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        return mockPosts.filter { $0.isPinned }
    }

    // MARK: - Create/Update/Delete Posts

    func createPost(_ request: CreateForumPostRequest) async throws -> ForumPost {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        let newPost = ForumPost.fixture(
            id: mockPosts.count + 1,
            profileId: request.profileId,
            title: request.title,
            description: request.description,
            postType: request.postType
        )
        mockPosts.insert(newPost, at: 0)
        return newPost
    }

    func updatePost(id: Int, _ request: UpdateForumPostRequest) async throws -> ForumPost {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        guard let index = mockPosts.firstIndex(where: { $0.id == id }) else {
            throw AppError.notFound(resource: "ForumPost")
        }
        // In a real mock, we'd update the post - for now just return the existing one
        return mockPosts[index]
    }

    func deletePost(id: Int, profileId: UUID) async throws {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        mockPosts.removeAll { $0.id == id && $0.profileId == profileId }
    }

    // MARK: - Categories

    func fetchCategories() async throws -> [ForumCategory] {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        return mockCategories
    }

    // MARK: - Tags

    func fetchPopularTags(limit: Int) async throws -> [ForumTag] {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        return Array(mockTags.prefix(limit))
    }

    // MARK: - Comments

    func fetchComments(forumId: Int, pagination: CursorPaginationParams) async throws -> [ForumComment] {
        fetchCommentsCallCount += 1

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        let comments = mockComments[forumId] ?? []
        return Array(comments.prefix(pagination.limit))
    }

    func fetchComments(forumId: Int, limit: Int, offset: Int) async throws -> [ForumComment] {
        fetchCommentsCallCount += 1

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        let comments = mockComments[forumId] ?? []
        let endIndex = min(offset + limit, comments.count)
        guard offset < comments.count else { return [] }
        return Array(comments[offset..<endIndex])
    }

    func createComment(_ request: CreateCommentRequest) async throws -> ForumComment {
        createCommentCallCount += 1

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        let comment = ForumComment.fixture(
            id: Int.random(in: 1000...9999),
            forumId: request.forumId,
            comment: request.comment
        )

        if mockComments[request.forumId] == nil {
            mockComments[request.forumId] = []
        }
        mockComments[request.forumId]?.append(comment)

        return comment
    }

    func deleteComment(id: Int) async throws {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        for (forumId, comments) in mockComments {
            mockComments[forumId] = comments.filter { $0.id != id }
        }
    }

    func updateComment(id: Int, content: String) async throws -> ForumComment {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        // Find and update the comment
        for (forumId, comments) in mockComments {
            if let index = comments.firstIndex(where: { $0.id == id }) {
                let oldComment = comments[index]
                let updatedComment = ForumComment(
                    id: oldComment.id,
                    userId: oldComment.userId,
                    forumId: oldComment.forumId,
                    parentId: oldComment.parentId,
                    comment: content,
                    depth: oldComment.depth,
                    isEdited: true,
                    updatedAt: Date(),
                    likesCount: oldComment.likesCount,
                    repliesCount: oldComment.repliesCount,
                    reportsCount: oldComment.reportsCount,
                    isBestAnswer: oldComment.isBestAnswer,
                    isPinned: oldComment.isPinned,
                    commentCreatedAt: oldComment.commentCreatedAt,
                    author: oldComment.author,
                    replies: oldComment.replies
                )
                mockComments[forumId]?[index] = updatedComment
                return updatedComment
            }
        }
        throw AppError.notFound(resource: "Comment")
    }

    func fetchReplies(commentId: Int, limit: Int, offset: Int) async throws -> [ForumComment] {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        // Return empty array for mock - in real implementation would fetch nested replies
        return []
    }

    // MARK: - Reactions (Legacy Like)

    func togglePostLike(forumId: Int, profileId: UUID) async throws -> Bool {
        toggleLikeCallCount += 1

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        if likedPosts.contains(forumId) {
            likedPosts.remove(forumId)
            return false
        } else {
            likedPosts.insert(forumId)
            return true
        }
    }

    func toggleCommentLike(commentId: Int, profileId: UUID) async throws -> Bool {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        return true
    }

    func hasLikedPost(forumId: Int, profileId: UUID) async throws -> Bool {
        if shouldFail {
            throw AppError.networkError("Mock error")
        }
        return likedPosts.contains(forumId)
    }

    // MARK: - Emoji Reactions

    func fetchReactionTypes() async throws -> [ReactionType] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return []
    }

    func fetchPostReactions(forumId: Int, profileId: UUID) async throws -> ReactionsSummary {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ReactionsSummary(totalCount: 0, reactions: [], userReactionTypeIds: [])
    }

    func fetchCommentReactions(commentId: Int, profileId: UUID) async throws -> ReactionsSummary {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ReactionsSummary(totalCount: 0, reactions: [], userReactionTypeIds: [])
    }

    func togglePostReaction(forumId: Int, reactionTypeId: Int, profileId: UUID) async throws -> ReactionsSummary {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ReactionsSummary(totalCount: 0, reactions: [], userReactionTypeIds: [])
    }

    func toggleCommentReaction(commentId: Int, reactionTypeId: Int, profileId: UUID) async throws -> ReactionsSummary {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ReactionsSummary(totalCount: 0, reactions: [], userReactionTypeIds: [])
    }

    func fetchPostReactors(forumId: Int, reactionTypeId: Int, limit: Int) async throws -> [UUID] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return []
    }

    // MARK: - Bookmarks

    func toggleBookmark(forumId: Int, profileId: UUID) async throws -> Bool {
        toggleBookmarkCallCount += 1

        if shouldFail {
            throw AppError.networkError("Mock error")
        }

        if bookmarkedPosts.contains(forumId) {
            bookmarkedPosts.remove(forumId)
            return false
        } else {
            bookmarkedPosts.insert(forumId)
            return true
        }
    }

    func fetchBookmarkedPosts(profileId: UUID, pagination: CursorPaginationParams) async throws -> [ForumPost] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return mockPosts.filter { bookmarkedPosts.contains($0.id) }
    }

    func fetchBookmarkedPosts(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumPost] {
        if shouldFail { throw AppError.networkError("Mock error") }
        let bookmarked = mockPosts.filter { bookmarkedPosts.contains($0.id) }
        let endIndex = min(offset + limit, bookmarked.count)
        guard offset < bookmarked.count else { return [] }
        return Array(bookmarked[offset..<endIndex])
    }

    // MARK: - Views

    func recordView(forumId: Int, profileId: UUID) async throws {
        if shouldFail { throw AppError.networkError("Mock error") }
    }

    // MARK: - Polls

    func fetchPoll(forumId: Int) async throws -> ForumPoll? {
        if shouldFail { throw AppError.networkError("Mock error") }
        return nil
    }

    func fetchPollWithOptions(pollId: UUID, profileId: UUID) async throws -> ForumPoll {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumPoll.fixture()
    }

    func votePoll(pollId: UUID, optionIds: [UUID], profileId: UUID) async throws -> ForumPoll {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumPoll.fixture()
    }

    func removeVote(pollId: UUID, optionId: UUID, profileId: UUID) async throws {
        if shouldFail { throw AppError.networkError("Mock error") }
    }

    func createPoll(_ request: CreatePollRequest) async throws -> ForumPoll {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumPoll.fixture()
    }

    func fetchPollResults(pollId: UUID, profileId: UUID) async throws -> ForumPollResults {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumPollResults.fixture()
    }

    // MARK: - Reputation & Trust Levels

    func fetchUserStats(profileId: UUID) async throws -> ForumUserStats {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumUserStats.fixture()
    }

    func fetchOrCreateUserStats(profileId: UUID) async throws -> ForumUserStats {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumUserStats.fixture()
    }

    func fetchTrustLevels() async throws -> [ForumTrustLevel] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return []
    }

    func fetchTrustLevel(level: Int) async throws -> ForumTrustLevel {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumTrustLevel.fixture(level: level, name: "Level \(level)")
    }

    func fetchReputationHistory(profileId: UUID, limit: Int) async throws -> [ReputationHistoryItem] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return []
    }

    func incrementUserStat(profileId: UUID, stat: UserStatType, by amount: Int) async throws {
        if shouldFail { throw AppError.networkError("Mock error") }
    }

    func canPerformAction(profileId: UUID, action: TrustLevelAction) async throws -> Bool {
        if shouldFail { throw AppError.networkError("Mock error") }
        return true
    }

    // MARK: - Badges

    func fetchBadges() async throws -> [ForumBadge] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return []
    }

    func fetchUserBadges(profileId: UUID) async throws -> [UserBadgeWithDetails] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return []
    }

    func fetchBadgeCollection(profileId: UUID) async throws -> BadgeCollection {
        if shouldFail { throw AppError.networkError("Mock error") }
        return BadgeCollection(allBadges: [], earnedBadges: [], featuredBadges: [])
    }

    func hasEarnedBadge(profileId: UUID, badgeId: Int) async throws -> Bool {
        if shouldFail { throw AppError.networkError("Mock error") }
        return false
    }

    func awardBadge(badgeId: Int, to profileId: UUID, by awarderId: UUID?) async throws -> UserBadge {
        if shouldFail { throw AppError.networkError("Mock error") }
        return UserBadge(id: UUID(), profileId: profileId, badgeId: badgeId, awardedAt: Date(), awardedBy: awarderId, isFeatured: false)
    }

    func toggleFeaturedBadge(userBadgeId: UUID, profileId: UUID) async throws -> Bool {
        if shouldFail { throw AppError.networkError("Mock error") }
        return true
    }

    func fetchNextBadges(profileId: UUID, limit: Int) async throws -> [(badge: ForumBadge, progress: Double)] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return []
    }

    // MARK: - Subscriptions

    func fetchPostSubscription(forumId: Int, profileId: UUID) async throws -> ForumSubscription? {
        if shouldFail { throw AppError.networkError("Mock error") }
        return nil
    }

    func fetchCategorySubscription(categoryId: Int, profileId: UUID) async throws -> ForumSubscription? {
        if shouldFail { throw AppError.networkError("Mock error") }
        return nil
    }

    func fetchSubscriptions(profileId: UUID) async throws -> [ForumSubscription] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return []
    }

    func subscribeToPost(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumSubscription.fixture()
    }

    func subscribeToCategory(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumSubscription.fixture()
    }

    func unsubscribeFromPost(forumId: Int, profileId: UUID) async throws {
        if shouldFail { throw AppError.networkError("Mock error") }
    }

    func unsubscribeFromCategory(categoryId: Int, profileId: UUID) async throws {
        if shouldFail { throw AppError.networkError("Mock error") }
    }

    func updateSubscription(id: UUID, preferences: SubscriptionPreferences) async throws -> ForumSubscription {
        if shouldFail { throw AppError.networkError("Mock error") }
        return ForumSubscription.fixture()
    }

    // MARK: - Notifications

    func fetchNotifications(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumNotification] {
        if shouldFail { throw AppError.networkError("Mock error") }
        return []
    }

    func fetchUnreadNotificationCount(profileId: UUID) async throws -> Int {
        if shouldFail { throw AppError.networkError("Mock error") }
        return 0
    }

    func markNotificationAsRead(id: UUID) async throws {
        if shouldFail { throw AppError.networkError("Mock error") }
    }

    func markAllNotificationsAsRead(profileId: UUID) async throws {
        if shouldFail { throw AppError.networkError("Mock error") }
    }

    func deleteNotification(id: UUID) async throws {
        if shouldFail { throw AppError.networkError("Mock error") }
    }

    func deleteReadNotifications(profileId: UUID) async throws {
        if shouldFail { throw AppError.networkError("Mock error") }
    }

    // MARK: - Test Helpers

    func reset() {
        shouldFail = false
        delay = 0
        mockPosts = [
            ForumPost.fixture(id: 1, title: "Welcome to Foodshare Forum"),
            ForumPost.fixture(id: 2, title: "Best practices for sharing food"),
            ForumPost.fixture(id: 3, title: "Recipe exchange thread", postType: .question),
        ]
        mockCategories = []
        mockComments = [:]
        mockTags = []
        likedPosts = []
        bookmarkedPosts = []
        fetchPostsCallCount = 0
        fetchPostCallCount = 0
        fetchCommentsCallCount = 0
        createCommentCallCount = 0
        toggleLikeCallCount = 0
        toggleBookmarkCallCount = 0
    }
}
#endif
