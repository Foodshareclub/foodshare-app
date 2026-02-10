package com.foodshare.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: - Request Parameters

@Serializable
data class HomeScreenParams(
    @SerialName("p_user_id") val pUserId: String,
    @SerialName("p_lat") val pLat: Double,
    @SerialName("p_lng") val pLng: Double,
    @SerialName("p_radius_km") val pRadiusKm: Double = 10.0,
    @SerialName("p_feed_limit") val pFeedLimit: Int = 20,
    @SerialName("p_trending_limit") val pTrendingLimit: Int = 5
)

@Serializable
data class FeedParams(
    @SerialName("p_user_id") val pUserId: String,
    @SerialName("p_lat") val pLat: Double,
    @SerialName("p_lng") val pLng: Double,
    @SerialName("p_radius_km") val pRadiusKm: Double = 10.0,
    @SerialName("p_limit") val pLimit: Int = 20,
    @SerialName("p_cursor") val pCursor: String? = null,
    @SerialName("p_post_type") val pPostType: String? = null,
    @SerialName("p_category_id") val pCategoryId: Long? = null
)

@Serializable
data class ListingDetailParams(
    @SerialName("p_listing_id") val pListingId: Long,
    @SerialName("p_viewer_id") val pViewerId: String? = null
)

@Serializable
data class MessagesParams(
    @SerialName("p_user_id") val pUserId: String,
    @SerialName("p_limit") val pLimit: Int = 20,
    @SerialName("p_cursor") val pCursor: String? = null,
    @SerialName("p_include_archived") val pIncludeArchived: Boolean = false
)

@Serializable
data class ChatScreenParams(
    @SerialName("p_room_id") val pRoomId: String,
    @SerialName("p_user_id") val pUserId: String,
    @SerialName("p_messages_limit") val pMessagesLimit: Int = 50
)

@Serializable
data class ProfileParams(
    @SerialName("p_profile_id") val pProfileId: String,
    @SerialName("p_viewer_id") val pViewerId: String,
    @SerialName("p_include_listings") val pIncludeListings: Boolean = true,
    @SerialName("p_include_reviews") val pIncludeReviews: Boolean = true,
    @SerialName("p_listings_limit") val pListingsLimit: Int = 6,
    @SerialName("p_reviews_limit") val pReviewsLimit: Int = 5
)

@Serializable
data class NotificationsParams(
    @SerialName("p_user_id") val pUserId: String,
    @SerialName("p_filter") val pFilter: String = "all",
    @SerialName("p_limit") val pLimit: Int = 50,
    @SerialName("p_offset") val pOffset: Int = 0
)

@Serializable
data class UnreadCountsParams(
    @SerialName("p_user_id") val pUserId: String
)

@Serializable
data class ChallengesParams(
    @SerialName("p_user_id") val pUserId: String? = null,
    @SerialName("p_difficulty") val pDifficulty: String? = null,
    @SerialName("p_sort_by") val pSortBy: String = "popular",
    @SerialName("p_page_limit") val pPageLimit: Int = 20,
    @SerialName("p_page_offset") val pPageOffset: Int = 0
)

@Serializable
data class ChallengeDetailParams(
    @SerialName("p_challenge_id") val pChallengeId: Long,
    @SerialName("p_user_id") val pUserId: String? = null
)

@Serializable
data class ForumPostDetailParams(
    @SerialName("p_post_id") val pPostId: Long,
    @SerialName("p_user_id") val pUserId: String? = null,
    @SerialName("p_comments_limit") val pCommentsLimit: Int = 50
)

// MARK: - Response Models

@Serializable
data class HomeScreenData(
    @SerialName("nearby_listings") val nearbyListings: List<ListingSummary> = emptyList(),
    @SerialName("trending_listings") val trendingListings: List<ListingSummary> = emptyList(),
    @SerialName("unread_counts") val unreadCounts: UnreadCounts = UnreadCounts(),
    @SerialName("user_stats") val userStats: UserStats? = null,
    @SerialName("has_more") val hasMore: Boolean = false
) {
    @Serializable
    data class ListingSummary(
        val id: Long,
        val title: String,
        val description: String? = null,
        val image: String? = null,
        val category: String? = null,
        @SerialName("category_id") val categoryId: Long? = null,
        @SerialName("post_type") val postType: String? = null,
        val quantity: Int? = null,
        val unit: String? = null,
        @SerialName("expires_at") val expiresAt: String? = null,
        val distance: Double? = null,
        @SerialName("created_at") val createdAt: String,
        val author: Author
    )

    @Serializable
    data class Author(
        val id: String,
        val name: String,
        val avatar: String? = null,
        val rating: Double? = null
    )

    @Serializable
    data class UnreadCounts(
        val messages: Int = 0,
        val notifications: Int = 0
    )

    @Serializable
    data class UserStats(
        @SerialName("listings_count") val listingsCount: Int = 0,
        @SerialName("saved_count") val savedCount: Int = 0,
        @SerialName("arrangements_count") val arrangementsCount: Int = 0
    )
}

@Serializable
data class FeedScreenData(
    val listings: List<FeedListing> = emptyList(),
    @SerialName("has_more") val hasMore: Boolean = false,
    @SerialName("next_cursor") val nextCursor: String? = null
) {
    @Serializable
    data class FeedListing(
        val id: Long,
        val title: String,
        val description: String? = null,
        val image: String? = null,
        val images: List<String>? = null,
        val category: String? = null,
        @SerialName("category_id") val categoryId: Long? = null,
        @SerialName("post_type") val postType: String? = null,
        val quantity: Int? = null,
        val unit: String? = null,
        @SerialName("expires_at") val expiresAt: String? = null,
        val distance: Double? = null,
        val latitude: Double? = null,
        val longitude: Double? = null,
        val address: String? = null,
        @SerialName("views_count") val viewsCount: Int = 0,
        @SerialName("saves_count") val savesCount: Int = 0,
        @SerialName("comments_count") val commentsCount: Int = 0,
        @SerialName("created_at") val createdAt: String,
        val author: Author,
        @SerialName("is_saved") val isSaved: Boolean? = null
    ) {
        @Serializable
        data class Author(
            val id: String,
            val name: String,
            val avatar: String? = null,
            val rating: Double? = null,
            @SerialName("is_verified") val isVerified: Boolean = false
        )
    }
}

@Serializable
data class ListingDetailData(
    val success: Boolean = true,
    val error: String? = null,
    val listing: ListingDetail? = null,
    @SerialName("related_listings") val relatedListings: List<RelatedListing>? = null,
    @SerialName("author_listings") val authorListings: List<RelatedListing>? = null
) {
    @Serializable
    data class ListingDetail(
        val id: Long,
        val title: String,
        val description: String? = null,
        val image: String? = null,
        val images: List<String>? = null,
        val category: String? = null,
        @SerialName("category_id") val categoryId: Long? = null,
        @SerialName("post_type") val postType: String? = null,
        val quantity: Int? = null,
        val unit: String? = null,
        @SerialName("expires_at") val expiresAt: String? = null,
        val latitude: Double? = null,
        val longitude: Double? = null,
        val address: String? = null,
        @SerialName("views_count") val viewsCount: Int = 0,
        @SerialName("saves_count") val savesCount: Int = 0,
        @SerialName("comments_count") val commentsCount: Int = 0,
        val status: String? = null,
        @SerialName("created_at") val createdAt: String,
        @SerialName("updated_at") val updatedAt: String? = null,
        val author: Author,
        @SerialName("is_saved") val isSaved: Boolean? = null,
        @SerialName("can_edit") val canEdit: Boolean? = null,
        @SerialName("can_delete") val canDelete: Boolean? = null
    ) {
        @Serializable
        data class Author(
            val id: String,
            val name: String,
            val avatar: String? = null,
            val rating: Double? = null,
            @SerialName("is_verified") val isVerified: Boolean = false,
            @SerialName("listings_count") val listingsCount: Int? = null,
            @SerialName("joined_at") val joinedAt: String? = null
        )
    }

    @Serializable
    data class RelatedListing(
        val id: Long,
        val title: String,
        val image: String? = null,
        val distance: Double? = null
    )
}

@Serializable
data class MessagesScreenData(
    val conversations: List<Conversation> = emptyList(),
    @SerialName("has_more") val hasMore: Boolean = false,
    @SerialName("next_cursor") val nextCursor: String? = null
) {
    @Serializable
    data class Conversation(
        val id: String,
        @SerialName("other_user") val otherUser: OtherUser,
        @SerialName("last_message") val lastMessage: LastMessage? = null,
        @SerialName("unread_count") val unreadCount: Int = 0,
        @SerialName("listing_id") val listingId: Long? = null,
        @SerialName("listing_title") val listingTitle: String? = null,
        @SerialName("listing_image") val listingImage: String? = null,
        @SerialName("updated_at") val updatedAt: String
    ) {
        @Serializable
        data class OtherUser(
            val id: String,
            val name: String,
            val avatar: String? = null,
            @SerialName("is_online") val isOnline: Boolean? = null
        )

        @Serializable
        data class LastMessage(
            val content: String,
            @SerialName("sender_id") val senderId: String,
            @SerialName("created_at") val createdAt: String,
            @SerialName("is_read") val isRead: Boolean = false
        )
    }
}

@Serializable
data class ChatScreenData(
    val success: Boolean = true,
    val room: ChatRoom? = null,
    val messages: List<ChatMessage> = emptyList(),
    @SerialName("has_more") val hasMore: Boolean = false
) {
    @Serializable
    data class ChatRoom(
        val id: String,
        @SerialName("other_user") val otherUser: OtherUser,
        val listing: Listing? = null,
        @SerialName("created_at") val createdAt: String
    ) {
        @Serializable
        data class OtherUser(
            val id: String,
            val name: String,
            val avatar: String? = null,
            @SerialName("is_online") val isOnline: Boolean? = null,
            @SerialName("last_seen") val lastSeen: String? = null
        )

        @Serializable
        data class Listing(
            val id: Long,
            val title: String,
            val image: String? = null,
            val status: String? = null
        )
    }

    @Serializable
    data class ChatMessage(
        val id: String,
        val content: String,
        @SerialName("sender_id") val senderId: String,
        @SerialName("message_type") val messageType: String? = null,
        @SerialName("is_read") val isRead: Boolean = false,
        @SerialName("created_at") val createdAt: String
    )
}

@Serializable
data class ProfileScreenData(
    val profile: ProfileInfo,
    val listings: List<ProfileListing>? = null,
    val reviews: List<ProfileReview>? = null,
    val stats: ProfileStats,
    @SerialName("is_own_profile") val isOwnProfile: Boolean = false,
    @SerialName("is_following") val isFollowing: Boolean? = null
) {
    @Serializable
    data class ProfileInfo(
        val id: String,
        val name: String,
        val avatar: String? = null,
        val bio: String? = null,
        val location: String? = null,
        @SerialName("is_verified") val isVerified: Boolean = false,
        @SerialName("joined_at") val joinedAt: String
    )

    @Serializable
    data class ProfileListing(
        val id: Long,
        val title: String,
        val image: String? = null,
        val status: String? = null,
        @SerialName("created_at") val createdAt: String
    )

    @Serializable
    data class ProfileReview(
        val id: Long,
        val rating: Int,
        val comment: String? = null,
        @SerialName("reviewer_name") val reviewerName: String,
        @SerialName("reviewer_avatar") val reviewerAvatar: String? = null,
        @SerialName("created_at") val createdAt: String
    )

    @Serializable
    data class ProfileStats(
        @SerialName("listings_count") val listingsCount: Int = 0,
        @SerialName("completed_count") val completedCount: Int = 0,
        val rating: Double? = null,
        @SerialName("reviews_count") val reviewsCount: Int = 0,
        @SerialName("impact_score") val impactScore: Int? = null
    )
}

@Serializable
data class NotificationsScreenData(
    val notifications: List<NotificationItem> = emptyList(),
    @SerialName("unread_count") val unreadCount: Int = 0,
    @SerialName("has_more") val hasMore: Boolean = false
) {
    @Serializable
    data class NotificationItem(
        val id: Long,
        val type: String,
        val title: String,
        val body: String,
        @SerialName("is_read") val isRead: Boolean = false,
        @SerialName("created_at") val createdAt: String,
        @SerialName("time_ago") val timeAgo: String? = null
    )
}

@Serializable
data class UnreadCountsData(
    val messages: Int = 0,
    val notifications: Int = 0,
    val total: Int = 0
)

@Serializable
data class ChallengesScreenData(
    val challenges: List<Challenge> = emptyList(),
    @SerialName("user_challenges") val userChallenges: List<UserChallenge> = emptyList(),
    val leaderboard: List<LeaderboardEntry> = emptyList(),
    val stats: ChallengeStats,
    @SerialName("has_more") val hasMore: Boolean = false
) {
    @Serializable
    data class Challenge(
        val id: Long,
        val title: String,
        val description: String? = null,
        val image: String? = null,
        val difficulty: String? = null,
        val score: Int = 0,
        @SerialName("participants_count") val participantsCount: Int = 0,
        @SerialName("completion_rate") val completionRate: Double? = null,
        @SerialName("created_at") val createdAt: String,
        @SerialName("has_joined") val hasJoined: Boolean? = null,
        @SerialName("is_completed") val isCompleted: Boolean? = null
    )

    @Serializable
    data class UserChallenge(
        val id: Long,
        @SerialName("challenge_id") val challengeId: Long,
        val title: String,
        val image: String? = null,
        val score: Int = 0,
        @SerialName("is_completed") val isCompleted: Boolean = false,
        @SerialName("joined_at") val joinedAt: String,
        @SerialName("completed_at") val completedAt: String? = null
    )

    @Serializable
    data class LeaderboardEntry(
        val rank: Int,
        @SerialName("user_id") val userId: String,
        val name: String,
        val avatar: String? = null,
        val score: Int = 0,
        @SerialName("completed_count") val completedCount: Int = 0
    )

    @Serializable
    data class ChallengeStats(
        @SerialName("total_challenges") val totalChallenges: Int = 0,
        @SerialName("total_participants") val totalParticipants: Int = 0,
        @SerialName("user_rank") val userRank: Int? = null,
        @SerialName("user_score") val userScore: Int? = null
    )
}

@Serializable
data class ChallengeDetailData(
    val success: Boolean = true,
    val error: String? = null,
    val challenge: ChallengeDetail? = null,
    val participants: List<Participant>? = null,
    @SerialName("related_challenges") val relatedChallenges: List<RelatedChallenge>? = null
) {
    @Serializable
    data class ChallengeDetail(
        val id: Long,
        val title: String,
        val description: String? = null,
        val image: String? = null,
        val difficulty: String? = null,
        val score: Int = 0,
        val action: String? = null,
        @SerialName("participants_count") val participantsCount: Int = 0,
        @SerialName("completion_rate") val completionRate: Double? = null,
        @SerialName("created_at") val createdAt: String,
        val creator: Creator? = null,
        @SerialName("has_joined") val hasJoined: Boolean? = null,
        @SerialName("is_completed") val isCompleted: Boolean? = null,
        @SerialName("joined_at") val joinedAt: String? = null,
        @SerialName("completed_at") val completedAt: String? = null
    ) {
        @Serializable
        data class Creator(
            val id: String,
            val name: String,
            val avatar: String? = null
        )
    }

    @Serializable
    data class Participant(
        @SerialName("user_id") val userId: String,
        val name: String,
        val avatar: String? = null,
        @SerialName("is_completed") val isCompleted: Boolean = false,
        @SerialName("completed_at") val completedAt: String? = null
    )

    @Serializable
    data class RelatedChallenge(
        val id: Long,
        val title: String,
        val image: String? = null,
        val difficulty: String? = null,
        val score: Int = 0
    )
}

@Serializable
data class ForumPostDetailData(
    val success: Boolean = true,
    val error: String? = null,
    val post: ForumPost? = null,
    val comments: List<ForumComment>? = null,
    @SerialName("related_posts") val relatedPosts: List<RelatedPost>? = null
) {
    @Serializable
    data class ForumPost(
        val id: Long,
        val title: String,
        val content: String? = null,
        val image: String? = null,
        @SerialName("category_id") val categoryId: Int? = null,
        @SerialName("category_name") val categoryName: String? = null,
        @SerialName("views_count") val viewsCount: Int = 0,
        @SerialName("likes_count") val likesCount: Int = 0,
        @SerialName("comments_count") val commentsCount: Int = 0,
        @SerialName("is_pinned") val isPinned: Boolean = false,
        @SerialName("is_locked") val isLocked: Boolean = false,
        @SerialName("created_at") val createdAt: String,
        val author: Author,
        @SerialName("has_liked") val hasLiked: Boolean? = null,
        @SerialName("has_bookmarked") val hasBookmarked: Boolean? = null
    ) {
        @Serializable
        data class Author(
            val id: String,
            val name: String,
            val avatar: String? = null,
            @SerialName("is_verified") val isVerified: Boolean = false
        )
    }

    @Serializable
    data class ForumComment(
        val id: Long,
        val content: String,
        @SerialName("author_id") val authorId: String,
        @SerialName("author_name") val authorName: String,
        @SerialName("author_avatar") val authorAvatar: String? = null,
        @SerialName("parent_id") val parentId: Long? = null,
        val depth: Int = 0,
        @SerialName("likes_count") val likesCount: Int = 0,
        @SerialName("created_at") val createdAt: String,
        @SerialName("has_liked") val hasLiked: Boolean? = null
    )

    @Serializable
    data class RelatedPost(
        val id: Long,
        val title: String,
        @SerialName("comments_count") val commentsCount: Int = 0
    )
}


// MARK: - Forum Feed Models

@Serializable
data class ForumFeedParams(
    @SerialName("p_user_id") val pUserId: String? = null,
    @SerialName("p_category_id") val pCategoryId: Int? = null,
    @SerialName("p_post_type") val pPostType: String? = null,
    @SerialName("p_sort_by") val pSortBy: String = "recent",
    @SerialName("p_page_limit") val pPageLimit: Int = 20,
    @SerialName("p_page_offset") val pPageOffset: Int = 0
)

@Serializable
data class ForumFeedScreenData(
    val success: Boolean = true,
    val posts: List<ForumPostSummary> = emptyList(),
    val categories: List<ForumCategory> = emptyList(),
    val featured: List<FeaturedPost> = emptyList(),
    @SerialName("user_stats") val userStats: ForumUserStats? = null,
    val pagination: ForumPagination = ForumPagination()
) {
    @Serializable
    data class ForumPostSummary(
        val id: Long,
        val title: String,
        val description: String? = null,
        val image: String? = null,
        @SerialName("comments_count") val commentsCount: Int = 0,
        @SerialName("likes_count") val likesCount: Int? = null,
        @SerialName("views_count") val viewsCount: Int = 0,
        @SerialName("post_type") val postType: String? = null,
        @SerialName("is_pinned") val isPinned: Boolean = false,
        @SerialName("is_locked") val isLocked: Boolean = false,
        @SerialName("is_featured") val isFeatured: Boolean = false,
        val slug: String? = null,
        @SerialName("category_id") val categoryId: Int? = null,
        @SerialName("category_name") val categoryName: String? = null,
        @SerialName("category_color") val categoryColor: String? = null,
        @SerialName("created_at") val createdAt: String,
        @SerialName("last_activity_at") val lastActivityAt: String? = null,
        val author: Author,
        @SerialName("user_interaction") val userInteraction: UserInteraction = UserInteraction()
    ) {
        @Serializable
        data class Author(
            val id: String,
            val name: String,
            val avatar: String? = null,
            @SerialName("is_verified") val isVerified: Boolean = false
        )

        @Serializable
        data class UserInteraction(
            @SerialName("has_reacted") val hasReacted: Boolean = false,
            @SerialName("has_bookmarked") val hasBookmarked: Boolean = false
        )
    }

    @Serializable
    data class ForumCategory(
        val id: Int,
        val name: String,
        val description: String? = null,
        val color: String? = null,
        val icon: String? = null,
        val slug: String? = null,
        @SerialName("post_count") val postCount: Int = 0
    )

    @Serializable
    data class FeaturedPost(
        val id: Long,
        val title: String,
        val image: String? = null,
        val slug: String? = null,
        @SerialName("author_name") val authorName: String,
        @SerialName("featured_at") val featuredAt: String? = null
    )

    @Serializable
    data class ForumUserStats(
        @SerialName("posts_count") val postsCount: Int = 0,
        @SerialName("comments_count") val commentsCount: Int = 0,
        @SerialName("bookmarks_count") val bookmarksCount: Int = 0,
        @SerialName("unread_notifications") val unreadNotifications: Int = 0
    )

    @Serializable
    data class ForumPagination(
        val limit: Int = 20,
        val offset: Int = 0,
        @SerialName("has_more") val hasMore: Boolean = false
    )
}

// MARK: - Search Models

@Serializable
data class SearchParams(
    @SerialName("p_user_id") val pUserId: String? = null,
    @SerialName("p_query") val pQuery: String? = null,
    @SerialName("p_search_type") val pSearchType: String = "all",
    @SerialName("p_latitude") val pLatitude: Double? = null,
    @SerialName("p_longitude") val pLongitude: Double? = null,
    @SerialName("p_radius_km") val pRadiusKm: Double = 50.0,
    @SerialName("p_category_id") val pCategoryId: Long? = null,
    @SerialName("p_limit") val pLimit: Int = 20,
    @SerialName("p_offset") val pOffset: Int = 0
)

@Serializable
data class SearchScreenData(
    val success: Boolean = true,
    @SerialName("has_query") val hasQuery: Boolean = false,
    val query: String? = null,
    val listings: List<SearchListing>? = null,
    val users: List<SearchUser>? = null,
    @SerialName("forum_posts") val forumPosts: List<SearchForumPost>? = null,
    val suggestions: List<String>? = null,
    val trending: List<TrendingSearch>? = null,
    @SerialName("recent_searches") val recentSearches: List<RecentSearch>? = null,
    val pagination: SearchPagination? = null
) {
    @Serializable
    data class SearchListing(
        val id: Long,
        val title: String,
        val description: String? = null,
        val image: String? = null,
        @SerialName("post_type") val postType: String? = null,
        val quantity: Int? = null,
        val unit: String? = null,
        @SerialName("expires_at") val expiresAt: String? = null,
        @SerialName("views_count") val viewsCount: Int = 0,
        val distance: Double? = null,
        @SerialName("created_at") val createdAt: String,
        val author: Author
    ) {
        @Serializable
        data class Author(
            val id: String,
            val name: String,
            val avatar: String? = null
        )
    }

    @Serializable
    data class SearchUser(
        val id: String,
        val name: String,
        val avatar: String? = null,
        val bio: String? = null,
        @SerialName("is_verified") val isVerified: Boolean = false,
        @SerialName("listings_count") val listingsCount: Int = 0,
        val rating: Double? = null
    )

    @Serializable
    data class SearchForumPost(
        val id: Long,
        val title: String,
        val description: String? = null,
        val image: String? = null,
        @SerialName("comments_count") val commentsCount: Int = 0,
        @SerialName("likes_count") val likesCount: Int? = null,
        val slug: String? = null,
        @SerialName("category_name") val categoryName: String? = null,
        @SerialName("created_at") val createdAt: String,
        val author: Author
    ) {
        @Serializable
        data class Author(
            val id: String,
            val name: String,
            val avatar: String? = null
        )
    }

    @Serializable
    data class TrendingSearch(
        val query: String,
        val count: Int = 0
    )

    @Serializable
    data class RecentSearch(
        val query: String,
        @SerialName("searched_at") val searchedAt: String
    )

    @Serializable
    data class SearchPagination(
        val limit: Int = 20,
        val offset: Int = 0,
        @SerialName("total_count") val totalCount: Int? = null,
        @SerialName("has_more") val hasMore: Boolean = false
    )
}

// =============================================================================
// Unified BFF Response Types (matching Edge Function handlers)
// =============================================================================

/**
 * Common pagination metadata used across BFF responses.
 * SYNC: Matches bff-responses.ts PaginationMeta
 */
@Serializable
data class BFFPaginationMeta(
    val page: Int,
    val limit: Int,
    val total: Int,
    @SerialName("has_more") val hasMore: Boolean
)

/**
 * Unified geo location format.
 * SYNC: Matches bff-responses.ts GeoLocation
 */
@Serializable
data class BFFGeoLocation(
    val latitude: Double,
    val longitude: Double,
    val address: String? = null,
    val city: String? = null,
    @SerialName("distance_km") val distanceKm: Double? = null
)

/**
 * Unified user summary format.
 * SYNC: Matches bff-responses.ts UserSummary
 */
@Serializable
data class BFFUserSummary(
    val id: String,
    @SerialName("display_name") val displayName: String,
    @SerialName("avatar_url") val avatarUrl: String? = null,
    val rating: Double = 0.0,
    @SerialName("review_count") val reviewCount: Int = 0,
    @SerialName("is_verified") val isVerified: Boolean = false,
    @SerialName("member_since") val memberSince: String
)

/**
 * Unified image info format.
 * SYNC: Matches bff-responses.ts ImageInfo
 */
@Serializable
data class BFFImageInfo(
    val url: String,
    @SerialName("thumbnail_url") val thumbnailUrl: String? = null,
    val width: Int? = null,
    val height: Int? = null,
    val blurhash: String? = null
)

/**
 * Unified category info format.
 * SYNC: Matches bff-responses.ts CategoryInfo
 */
@Serializable
data class BFFCategoryInfo(
    val id: Int,
    val name: String,
    val icon: String,
    val color: String
)

/**
 * Unified listing summary format.
 * SYNC: Matches bff-responses.ts ListingSummary
 */
@Serializable
data class BFFListingSummary(
    val id: String,
    val title: String,
    val description: String,
    val quantity: Int,
    val unit: String,
    val category: BFFCategoryInfo? = null,
    val images: List<BFFImageInfo> = emptyList(),
    val location: BFFGeoLocation,
    @SerialName("expires_at") val expiresAt: String? = null,
    val status: String,
    @SerialName("created_at") val createdAt: String,
    val user: BFFUserSummary,
    @SerialName("is_favorited") val isFavorited: Boolean = false,
    @SerialName("favorite_count") val favoriteCount: Int = 0
)

/**
 * Unified listing detail response.
 * SYNC: Matches bff-responses.ts ListingDetailResponse
 */
@Serializable
data class BFFListingDetailResponse(
    val listing: BFFListingDetail,
    val seller: BFFSellerDetail,
    @SerialName("related_listings") val relatedListings: List<BFFListingSummary> = emptyList(),
    @SerialName("recent_reviews") val recentReviews: List<BFFReviewSummary> = emptyList(),
    @SerialName("can_contact") val canContact: Boolean = true,
    @SerialName("can_favorite") val canFavorite: Boolean = true,
    @SerialName("can_report") val canReport: Boolean = true
) {
    @Serializable
    data class BFFListingDetail(
        val id: String,
        val title: String,
        val description: String,
        @SerialName("full_description") val fullDescription: String,
        val quantity: Int,
        val unit: String,
        val category: BFFCategoryInfo? = null,
        val images: List<BFFImageInfo> = emptyList(),
        val location: BFFGeoLocation,
        @SerialName("expires_at") val expiresAt: String? = null,
        val status: String,
        @SerialName("created_at") val createdAt: String,
        val user: BFFUserSummary,
        @SerialName("is_favorited") val isFavorited: Boolean = false,
        @SerialName("favorite_count") val favoriteCount: Int = 0,
        @SerialName("pickup_instructions") val pickupInstructions: String? = null,
        @SerialName("dietary_tags") val dietaryTags: List<String> = emptyList(),
        val allergens: List<String> = emptyList(),
        @SerialName("view_count") val viewCount: Int = 0
    )

    @Serializable
    data class BFFSellerDetail(
        val id: String,
        @SerialName("display_name") val displayName: String,
        @SerialName("avatar_url") val avatarUrl: String? = null,
        val rating: Double = 0.0,
        @SerialName("review_count") val reviewCount: Int = 0,
        @SerialName("is_verified") val isVerified: Boolean = false,
        @SerialName("member_since") val memberSince: String,
        val bio: String? = null,
        @SerialName("total_shares") val totalShares: Int = 0,
        @SerialName("response_rate") val responseRate: Double = 0.0,
        @SerialName("response_time_minutes") val responseTimeMinutes: Int = 60
    )
}

/**
 * Unified review summary format.
 * SYNC: Matches bff-responses.ts ReviewSummary
 */
@Serializable
data class BFFReviewSummary(
    val id: String,
    val rating: Int,
    val comment: String? = null,
    @SerialName("created_at") val createdAt: String,
    val reviewer: BFFUserSummary,
    @SerialName("listing_title") val listingTitle: String? = null
)

/**
 * Unified search response.
 * SYNC: Matches bff-responses.ts SearchResponse
 */
@Serializable
data class BFFSearchResponse(
    val results: List<BFFListingSummary> = emptyList(),
    val pagination: BFFPaginationMeta,
    val filters: BFFSearchFilters,
    val suggestions: List<BFFSearchSuggestion> = emptyList(),
    val facets: BFFSearchFacets,
    val meta: BFFSearchMeta
) {
    @Serializable
    data class BFFSearchFilters(
        val query: String? = null,
        @SerialName("category_ids") val categoryIds: List<Int>? = null,
        @SerialName("dietary_tags") val dietaryTags: List<String>? = null,
        @SerialName("max_distance_km") val maxDistanceKm: Double? = null,
        val latitude: Double? = null,
        val longitude: Double? = null,
        @SerialName("sort_by") val sortBy: String? = null,
        val status: String? = null
    )

    @Serializable
    data class BFFSearchSuggestion(
        val text: String,
        val type: String,
        val count: Int? = null
    )

    @Serializable
    data class BFFSearchFacets(
        val categories: List<CategoryFacet> = emptyList(),
        @SerialName("dietary_tags") val dietaryTags: List<DietaryFacet> = emptyList()
    ) {
        @Serializable
        data class CategoryFacet(val id: Int, val name: String, val count: Int)

        @Serializable
        data class DietaryFacet(val tag: String, val count: Int)
    }

    @Serializable
    data class BFFSearchMeta(
        @SerialName("search_time_ms") val searchTimeMs: Long,
        @SerialName("total_matches") val totalMatches: Int
    )
}

/**
 * Unified challenges response.
 * SYNC: Matches bff-responses.ts ChallengesResponse
 */
@Serializable
data class BFFChallengesResponse(
    @SerialName("active_challenges") val activeChallenges: List<BFFChallengeWithProgress> = emptyList(),
    @SerialName("completed_challenges") val completedChallenges: List<BFFChallengeWithProgress> = emptyList(),
    @SerialName("upcoming_challenges") val upcomingChallenges: List<BFFChallengeSummary> = emptyList(),
    @SerialName("user_stats") val userStats: BFFChallengeUserStats,
    val leaderboard: BFFChallengeLeaderboard
) {
    @Serializable
    data class BFFChallengeSummary(
        val id: String,
        val title: String,
        val description: String,
        val type: String,
        @SerialName("icon_url") val iconUrl: String,
        @SerialName("start_date") val startDate: String,
        @SerialName("end_date") val endDate: String,
        @SerialName("is_active") val isActive: Boolean,
        val reward: BFFChallengeReward
    )

    @Serializable
    data class BFFChallengeWithProgress(
        val id: String,
        val title: String,
        val description: String,
        val type: String,
        @SerialName("icon_url") val iconUrl: String,
        @SerialName("start_date") val startDate: String,
        @SerialName("end_date") val endDate: String,
        @SerialName("is_active") val isActive: Boolean,
        val reward: BFFChallengeReward,
        val progress: BFFChallengeProgress
    )

    @Serializable
    data class BFFChallengeReward(
        val points: Int,
        @SerialName("badge_id") val badgeId: String? = null,
        @SerialName("badge_name") val badgeName: String? = null,
        @SerialName("badge_icon_url") val badgeIconUrl: String? = null
    )

    @Serializable
    data class BFFChallengeProgress(
        @SerialName("challenge_id") val challengeId: String,
        @SerialName("current_value") val currentValue: Int,
        @SerialName("target_value") val targetValue: Int,
        @SerialName("progress_percentage") val progressPercentage: Int,
        @SerialName("is_completed") val isCompleted: Boolean,
        @SerialName("completed_at") val completedAt: String? = null,
        @SerialName("claimed_at") val claimedAt: String? = null
    )

    @Serializable
    data class BFFChallengeUserStats(
        @SerialName("total_challenges_completed") val totalChallengesCompleted: Int,
        @SerialName("current_streak") val currentStreak: Int,
        @SerialName("points_earned") val pointsEarned: Int,
        @SerialName("badges_earned") val badgesEarned: Int
    )

    @Serializable
    data class BFFChallengeLeaderboard(
        val rank: Int,
        @SerialName("total_participants") val totalParticipants: Int,
        @SerialName("top_users") val topUsers: List<BFFLeaderboardEntry>
    )

    @Serializable
    data class BFFLeaderboardEntry(
        val rank: Int,
        val user: BFFUserSummary,
        val points: Int,
        @SerialName("challenges_completed") val challengesCompleted: Int
    )
}

/**
 * Unified notifications response.
 * SYNC: Matches bff-responses.ts NotificationsResponse
 */
@Serializable
data class BFFNotificationsResponse(
    val notifications: List<BFFNotificationItem> = emptyList(),
    val grouped: List<BFFNotificationGroup> = emptyList(),
    val pagination: BFFPaginationMeta,
    @SerialName("unread_count") val unreadCount: Int = 0,
    val settings: BFFNotificationSettings
) {
    @Serializable
    data class BFFNotificationItem(
        val id: String,
        val type: String,
        val title: String,
        val body: String,
        @SerialName("image_url") val imageUrl: String? = null,
        val data: Map<String, String> = emptyMap(),
        @SerialName("is_read") val isRead: Boolean = false,
        @SerialName("created_at") val createdAt: String,
        val action: BFFNotificationAction? = null
    )

    @Serializable
    data class BFFNotificationAction(
        val type: String,
        val destination: String
    )

    @Serializable
    data class BFFNotificationGroup(
        val date: String,
        val notifications: List<BFFNotificationItem>
    )

    @Serializable
    data class BFFNotificationSettings(
        @SerialName("push_enabled") val pushEnabled: Boolean = true,
        @SerialName("email_enabled") val emailEnabled: Boolean = true,
        val categories: BFFNotificationCategories
    )

    @Serializable
    data class BFFNotificationCategories(
        val messages: Boolean = true,
        val listings: Boolean = true,
        val reviews: Boolean = true,
        val challenges: Boolean = true,
        val promotions: Boolean = false
    )
}
