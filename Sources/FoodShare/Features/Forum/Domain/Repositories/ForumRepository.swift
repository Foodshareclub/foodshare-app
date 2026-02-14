import Foundation

// MARK: - Forum Repository Protocol

/// Repository protocol for forum operations
protocol ForumRepository: Sendable {
    // MARK: - Posts (Cursor-Based Pagination)

    /// Fetch forum posts with cursor-based pagination (preferred for infinite scroll)
    func fetchPosts(
        categoryId: Int?,
        postType: ForumPostType?,
        sortBy: ForumSortOption,
        pagination: CursorPaginationParams,
    ) async throws -> [ForumPost]

    /// Fetch forum posts with offset pagination (legacy, for backward compatibility)
    func fetchPosts(
        categoryId: Int?,
        postType: ForumPostType?,
        sortBy: ForumSortOption,
        limit: Int,
        offset: Int,
    ) async throws -> [ForumPost]

    /// Fetch a single post by ID
    func fetchPost(id: Int) async throws -> ForumPost

    /// Fetch posts by search query
    func searchPosts(query: String, limit: Int) async throws -> [ForumPost]

    /// Fetch trending/hot posts
    func fetchTrendingPosts(limit: Int) async throws -> [ForumPost]

    /// Fetch pinned posts
    func fetchPinnedPosts(categoryId: Int?) async throws -> [ForumPost]

    /// Create a new forum post
    func createPost(_ request: CreateForumPostRequest) async throws -> ForumPost

    /// Update an existing forum post
    func updatePost(id: Int, _ request: UpdateForumPostRequest) async throws -> ForumPost

    /// Delete a forum post
    func deletePost(id: Int, profileId: UUID) async throws

    // MARK: - Categories

    /// Fetch all active categories
    func fetchCategories() async throws -> [ForumCategory]

    // MARK: - Tags

    /// Fetch popular tags
    func fetchPopularTags(limit: Int) async throws -> [ForumTag]

    // MARK: - Comments (Cursor-Based Pagination)

    /// Fetch comments with cursor-based pagination (preferred for chat-like scrolling)
    func fetchComments(forumId: Int, pagination: CursorPaginationParams) async throws -> [ForumComment]

    /// Fetch comments with offset pagination (legacy, for backward compatibility)
    func fetchComments(forumId: Int, limit: Int, offset: Int) async throws -> [ForumComment]

    /// Create a new comment
    func createComment(_ request: CreateCommentRequest) async throws -> ForumComment

    /// Update an existing comment
    func updateComment(id: Int, content: String) async throws -> ForumComment

    /// Fetch replies to a comment with pagination
    func fetchReplies(commentId: Int, limit: Int, offset: Int) async throws -> [ForumComment]

    /// Delete a comment
    func deleteComment(id: Int) async throws

    // MARK: - Reactions (Legacy Like)

    /// Toggle like on a post
    func togglePostLike(forumId: Int, profileId: UUID) async throws -> Bool

    /// Toggle like on a comment
    func toggleCommentLike(commentId: Int, profileId: UUID) async throws -> Bool

    /// Check if user has liked a post
    func hasLikedPost(forumId: Int, profileId: UUID) async throws -> Bool

    // MARK: - Emoji Reactions

    /// Fetch all available reaction types
    func fetchReactionTypes() async throws -> [ReactionType]

    /// Fetch reactions summary for a post
    func fetchPostReactions(forumId: Int, profileId: UUID) async throws -> ReactionsSummary

    /// Fetch reactions summary for a comment
    func fetchCommentReactions(commentId: Int, profileId: UUID) async throws -> ReactionsSummary

    /// Toggle a reaction on a post (add if not exists, remove if exists)
    func togglePostReaction(forumId: Int, reactionTypeId: Int, profileId: UUID) async throws -> ReactionsSummary

    /// Toggle a reaction on a comment (add if not exists, remove if exists)
    func toggleCommentReaction(commentId: Int, reactionTypeId: Int, profileId: UUID) async throws -> ReactionsSummary

    /// Fetch users who reacted to a post with a specific reaction type
    func fetchPostReactors(forumId: Int, reactionTypeId: Int, limit: Int) async throws -> [UUID]

    // MARK: - Bookmarks

    /// Toggle bookmark on a post
    func toggleBookmark(forumId: Int, profileId: UUID) async throws -> Bool

    /// Fetch user's bookmarked posts with cursor-based pagination
    func fetchBookmarkedPosts(profileId: UUID, pagination: CursorPaginationParams) async throws -> [ForumPost]

    /// Fetch user's bookmarked posts with offset pagination (legacy)
    func fetchBookmarkedPosts(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumPost]

    // MARK: - Views

    /// Record a post view
    func recordView(forumId: Int, profileId: UUID) async throws

    // MARK: - Polls

    /// Fetch poll for a forum post
    func fetchPoll(forumId: Int) async throws -> ForumPoll?

    /// Fetch poll by ID with options and user votes
    func fetchPollWithOptions(pollId: UUID, profileId: UUID) async throws -> ForumPoll

    /// Vote on a poll
    func votePoll(pollId: UUID, optionIds: [UUID], profileId: UUID) async throws -> ForumPoll

    /// Remove vote from a poll (for changing vote in multiple-choice)
    func removeVote(pollId: UUID, optionId: UUID, profileId: UUID) async throws

    /// Create a poll for a forum post
    func createPoll(_ request: CreatePollRequest) async throws -> ForumPoll

    /// Fetch poll results
    func fetchPollResults(pollId: UUID, profileId: UUID) async throws -> ForumPollResults

    // MARK: - Reputation & Trust Levels

    /// Fetch user's forum statistics
    func fetchUserStats(profileId: UUID) async throws -> ForumUserStats

    /// Fetch or create user's forum statistics (for new users)
    func fetchOrCreateUserStats(profileId: UUID) async throws -> ForumUserStats

    /// Fetch all trust levels
    func fetchTrustLevels() async throws -> [ForumTrustLevel]

    /// Fetch a specific trust level
    func fetchTrustLevel(level: Int) async throws -> ForumTrustLevel

    /// Fetch user's reputation history
    func fetchReputationHistory(profileId: UUID, limit: Int) async throws -> [ReputationHistoryItem]

    /// Increment a user stat (for tracking reads, time spent, etc.)
    func incrementUserStat(profileId: UUID, stat: UserStatType, by amount: Int) async throws

    /// Check if user can perform an action based on trust level
    func canPerformAction(profileId: UUID, action: TrustLevelAction) async throws -> Bool

    // MARK: - Badges

    /// Fetch all available badges
    func fetchBadges() async throws -> [ForumBadge]

    /// Fetch badges earned by a user
    func fetchUserBadges(profileId: UUID) async throws -> [UserBadgeWithDetails]

    /// Fetch a user's complete badge collection (all badges + earned + featured)
    func fetchBadgeCollection(profileId: UUID) async throws -> BadgeCollection

    /// Check if a user has earned a specific badge
    func hasEarnedBadge(profileId: UUID, badgeId: Int) async throws -> Bool

    /// Award a badge to a user (for manual/special badges)
    func awardBadge(badgeId: Int, to profileId: UUID, by awarderId: UUID?) async throws -> UserBadge

    /// Toggle featured status of a user's badge
    func toggleFeaturedBadge(userBadgeId: UUID, profileId: UUID) async throws -> Bool

    /// Get badges that user can earn next based on progress
    func fetchNextBadges(profileId: UUID, limit: Int) async throws -> [(badge: ForumBadge, progress: Double)]

    // MARK: - Subscriptions

    /// Fetch user's subscription to a specific post
    func fetchPostSubscription(forumId: Int, profileId: UUID) async throws -> ForumSubscription?

    /// Fetch user's subscription to a specific category
    func fetchCategorySubscription(categoryId: Int, profileId: UUID) async throws -> ForumSubscription?

    /// Fetch all user's subscriptions
    func fetchSubscriptions(profileId: UUID) async throws -> [ForumSubscription]

    /// Subscribe to a post
    func subscribeToPost(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription

    /// Subscribe to a category
    func subscribeToCategory(_ request: CreateSubscriptionRequest) async throws -> ForumSubscription

    /// Unsubscribe from a post
    func unsubscribeFromPost(forumId: Int, profileId: UUID) async throws

    /// Unsubscribe from a category
    func unsubscribeFromCategory(categoryId: Int, profileId: UUID) async throws

    /// Update subscription preferences
    func updateSubscription(id: UUID, preferences: SubscriptionPreferences) async throws -> ForumSubscription

    // MARK: - Notifications

    /// Fetch user's notifications with pagination
    func fetchNotifications(profileId: UUID, limit: Int, offset: Int) async throws -> [ForumNotification]

    /// Fetch unread notification count
    func fetchUnreadNotificationCount(profileId: UUID) async throws -> Int

    /// Mark a notification as read
    func markNotificationAsRead(id: UUID) async throws

    /// Mark all notifications as read
    func markAllNotificationsAsRead(profileId: UUID) async throws

    /// Delete a notification
    func deleteNotification(id: UUID) async throws

    /// Delete all read notifications
    func deleteReadNotifications(profileId: UUID) async throws
}

// MARK: - User Stat Types

enum UserStatType: String, Sendable {
    case postsRead = "posts_read"
    case topicsRead = "topics_read"
    case timeSpentMinutes = "time_spent_minutes"
    case likesGiven = "likes_given"
}

// MARK: - Trust Level Actions

enum TrustLevelAction: Sendable {
    case createPost
    case createReply
    case uploadImage
    case postLink
    case mentionUser
    case sendMessage
    case createPoll
    case deleteOwnPost
    case flag
}

// MARK: - Forum Sort Options

enum ForumSortOption: String, CaseIterable, Sendable {
    case newest
    case oldest
    case mostLiked = "most_liked"
    case mostCommented = "most_commented"
    case trending

    var displayName: String {
        switch self {
        case .newest: "Newest"
        case .oldest: "Oldest"
        case .mostLiked: "Most Liked"
        case .mostCommented: "Most Discussed"
        case .trending: "Trending"
        }
    }

    var orderColumn: String {
        switch self {
        case .newest, .oldest: "forum_post_created_at"
        case .mostLiked: "forum_likes_counter"
        case .mostCommented: "forum_comments_counter"
        case .trending: "hot_score"
        }
    }

    var ascending: Bool {
        self == .oldest
    }
    
    var apiValue: String {
        switch self {
        case .newest: "recent"
        case .oldest: "recent"
        case .mostLiked: "popular"
        case .mostCommented: "popular"
        case .trending: "trending"
        }
    }

    var icon: String {
        switch self {
        case .newest: "clock.arrow.circlepath"
        case .oldest: "clock"
        case .mostLiked: "heart.fill"
        case .mostCommented: "bubble.left.and.bubble.right.fill"
        case .trending: "flame.fill"
        }
    }
}

// MARK: - Forum Filters

struct ForumFilters: Equatable, Sendable {
    var categoryId: Int?
    var postType: ForumPostType?
    var sortBy: ForumSortOption = .newest
    var searchQuery = ""
    var showPinnedOnly = false
    var showQuestionsOnly = false
    var showUnansweredOnly = false

    var hasActiveFilters: Bool {
        categoryId != nil ||
            postType != nil ||
            !searchQuery.isEmpty ||
            showPinnedOnly ||
            showQuestionsOnly ||
            showUnansweredOnly
    }

    mutating func reset() {
        categoryId = nil
        postType = nil
        sortBy = .newest
        searchQuery = ""
        showPinnedOnly = false
        showQuestionsOnly = false
        showUnansweredOnly = false
    }
}

// MARK: - Create Forum Post Request

struct CreateForumPostRequest: Sendable {
    let profileId: UUID
    let title: String
    let description: String
    let categoryId: Int?
    let postType: ForumPostType
    let imageUrl: String?
    let pollOptions: [String]?

    init(
        profileId: UUID,
        title: String,
        description: String,
        categoryId: Int? = nil,
        postType: ForumPostType = .discussion,
        imageUrl: String? = nil,
        pollOptions: [String]? = nil,
    ) {
        self.profileId = profileId
        self.title = title
        self.description = description
        self.categoryId = categoryId
        self.postType = postType
        self.imageUrl = imageUrl
        self.pollOptions = pollOptions
    }
}

// MARK: - Update Forum Post Request

struct UpdateForumPostRequest: Sendable {
    let title: String?
    let description: String?
    let categoryId: Int?
    let imageUrl: String?

    init(
        title: String? = nil,
        description: String? = nil,
        categoryId: Int? = nil,
        imageUrl: String? = nil,
    ) {
        self.title = title
        self.description = description
        self.categoryId = categoryId
        self.imageUrl = imageUrl
    }
}
