package com.foodshare.core.network

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Backend-For-Frontend Service
 *
 * Provides unified access to all BFF RPC functions for optimized data fetching.
 * Each function returns aggregated data to minimize client round-trips.
 *
 * SYNC: This mirrors iOS FoodShare.BFFService
 */
@Singleton
class BFFService @Inject constructor(
    private val rpcClient: RateLimitedRPCClient
) {
    companion object {
        private const val TAG = "BFFService"
    }

    // Simple in-memory cache
    private val cache = mutableMapOf<String, CacheEntry<*>>()

    private data class CacheEntry<T>(
        val data: T,
        val expiresAt: Long
    )

    // MARK: - Home Screen

    /**
     * Fetch all data needed for the home screen in a single call.
     */
    suspend fun getHomeScreenData(
        userId: UUID,
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 10.0,
        feedLimit: Int = 20,
        trendingLimit: Int = 5
    ): Result<HomeScreenData> {
        val cacheKey = "home_${userId}_${(latitude * 100).toInt()}_${(longitude * 100).toInt()}"
        
        getCached<HomeScreenData>(cacheKey, 60_000)?.let { return Result.success(it) }

        val params = HomeScreenParams(
            pUserId = userId.toString(),
            pLat = latitude,
            pLng = longitude,
            pRadiusKm = radiusKm,
            pFeedLimit = feedLimit,
            pTrendingLimit = trendingLimit
        )

        return rpcClient.call<HomeScreenParams, HomeScreenData>(
            "get_home_screen_data",
            params,
            RPCConfig.relaxed
        ).onSuccess { setCache(cacheKey, it, 60_000) }
    }

    // MARK: - Feed Screen

    /**
     * Fetch paginated feed data with location-based filtering.
     */
    suspend fun getFeedData(
        userId: UUID,
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 10.0,
        limit: Int = 20,
        cursor: String? = null,
        postType: String? = null,
        categoryId: Long? = null
    ): Result<FeedScreenData> {
        val params = FeedParams(
            pUserId = userId.toString(),
            pLat = latitude,
            pLng = longitude,
            pRadiusKm = radiusKm,
            pLimit = limit,
            pCursor = cursor,
            pPostType = postType,
            pCategoryId = categoryId
        )

        return rpcClient.call<FeedParams, FeedScreenData>(
            "get_bff_feed_data",
            params,
            RPCConfig.relaxed
        )
    }

    // MARK: - Listing Detail

    /**
     * Fetch complete listing detail with related content.
     */
    suspend fun getListingDetail(
        listingId: Long,
        viewerId: UUID? = null
    ): Result<ListingDetailData> {
        val cacheKey = "listing_$listingId"
        
        getCached<ListingDetailData>(cacheKey, 30_000)?.let { return Result.success(it) }

        val params = ListingDetailParams(
            pListingId = listingId,
            pViewerId = viewerId?.toString()
        )

        return rpcClient.call<ListingDetailParams, ListingDetailData>(
            "get_listing_detail_data",
            params
        ).onSuccess { if (it.success) setCache(cacheKey, it, 30_000) }
    }

    // MARK: - Messages Screen

    /**
     * Fetch conversations list with last messages.
     */
    suspend fun getMessagesData(
        userId: UUID,
        limit: Int = 20,
        cursor: String? = null,
        includeArchived: Boolean = false
    ): Result<MessagesScreenData> {
        val params = MessagesParams(
            pUserId = userId.toString(),
            pLimit = limit,
            pCursor = cursor,
            pIncludeArchived = includeArchived
        )

        return rpcClient.call<MessagesParams, MessagesScreenData>(
            "get_bff_messages_data",
            params
        )
    }

    // MARK: - Chat Screen

    /**
     * Fetch chat room data with messages.
     */
    suspend fun getChatScreenData(
        roomId: UUID,
        userId: UUID,
        messagesLimit: Int = 50
    ): Result<ChatScreenData> {
        val params = ChatScreenParams(
            pRoomId = roomId.toString(),
            pUserId = userId.toString(),
            pMessagesLimit = messagesLimit
        )

        return rpcClient.call<ChatScreenParams, ChatScreenData>(
            "get_chat_screen_data",
            params
        )
    }

    // MARK: - Profile Screen

    /**
     * Fetch profile data with listings and reviews.
     */
    suspend fun getProfileData(
        profileId: UUID,
        viewerId: UUID,
        includeListings: Boolean = true,
        includeReviews: Boolean = true,
        listingsLimit: Int = 6,
        reviewsLimit: Int = 5
    ): Result<ProfileScreenData> {
        val cacheKey = "profile_$profileId"
        
        getCached<ProfileScreenData>(cacheKey, 120_000)?.let { return Result.success(it) }

        val params = ProfileParams(
            pProfileId = profileId.toString(),
            pViewerId = viewerId.toString(),
            pIncludeListings = includeListings,
            pIncludeReviews = includeReviews,
            pListingsLimit = listingsLimit,
            pReviewsLimit = reviewsLimit
        )

        return rpcClient.call<ProfileParams, ProfileScreenData>(
            "get_bff_profile_data",
            params
        ).onSuccess { setCache(cacheKey, it, 120_000) }
    }

    // MARK: - Notifications Screen

    /**
     * Fetch notifications with filtering.
     */
    suspend fun getNotificationsData(
        userId: UUID,
        filter: String = "all",
        limit: Int = 50,
        offset: Int = 0
    ): Result<NotificationsScreenData> {
        val params = NotificationsParams(
            pUserId = userId.toString(),
            pFilter = filter,
            pLimit = limit,
            pOffset = offset
        )

        return rpcClient.call<NotificationsParams, NotificationsScreenData>(
            "get_notifications_screen",
            params
        )
    }

    // MARK: - Unread Counts

    /**
     * Fetch just unread counts for badge updates.
     */
    suspend fun getUnreadCounts(userId: UUID): Result<UnreadCountsData> {
        val params = UnreadCountsParams(pUserId = userId.toString())

        return rpcClient.call<UnreadCountsParams, UnreadCountsData>(
            "get_bff_unread_counts",
            params,
            RPCConfig.relaxed
        )
    }

    // MARK: - Challenges Screen

    /**
     * Fetch challenges with leaderboard and user progress.
     */
    suspend fun getChallengesData(
        userId: UUID? = null,
        difficulty: String? = null,
        sortBy: String = "popular",
        limit: Int = 20,
        offset: Int = 0
    ): Result<ChallengesScreenData> {
        val cacheKey = "challenges_${difficulty ?: "all"}_${sortBy}_$offset"
        
        getCached<ChallengesScreenData>(cacheKey, 120_000)?.let { return Result.success(it) }

        val params = ChallengesParams(
            pUserId = userId?.toString(),
            pDifficulty = difficulty,
            pSortBy = sortBy,
            pPageLimit = limit,
            pPageOffset = offset
        )

        return rpcClient.call<ChallengesParams, ChallengesScreenData>(
            "get_challenges_screen_data",
            params
        ).onSuccess { setCache(cacheKey, it, 120_000) }
    }

    // MARK: - Challenge Detail

    /**
     * Fetch challenge detail with participants.
     */
    suspend fun getChallengeDetail(
        challengeId: Long,
        userId: UUID? = null
    ): Result<ChallengeDetailData> {
        val cacheKey = "challenge_$challengeId"
        
        getCached<ChallengeDetailData>(cacheKey, 60_000)?.let { return Result.success(it) }

        val params = ChallengeDetailParams(
            pChallengeId = challengeId,
            pUserId = userId?.toString()
        )

        return rpcClient.call<ChallengeDetailParams, ChallengeDetailData>(
            "get_challenge_detail",
            params
        ).onSuccess { if (it.success) setCache(cacheKey, it, 60_000) }
    }

    // MARK: - Forum Post Detail

    /**
     * Fetch forum post with comments.
     */
    suspend fun getForumPostDetail(
        postId: Long,
        userId: UUID? = null,
        commentsLimit: Int = 50
    ): Result<ForumPostDetailData> {
        val cacheKey = "forum_post_$postId"
        
        getCached<ForumPostDetailData>(cacheKey, 30_000)?.let { return Result.success(it) }

        val params = ForumPostDetailParams(
            pPostId = postId,
            pUserId = userId?.toString(),
            pCommentsLimit = commentsLimit
        )

        return rpcClient.call<ForumPostDetailParams, ForumPostDetailData>(
            "get_forum_post_detail",
            params
        ).onSuccess { if (it.success) setCache(cacheKey, it, 30_000) }
    }

    // MARK: - Cache Management

    fun invalidateCache(key: String) {
        cache.remove(key)
    }

    fun invalidateCacheMatching(prefix: String) {
        cache.keys.filter { it.startsWith(prefix) }.forEach { cache.remove(it) }
    }

    fun clearCache() {
        cache.clear()
    }

    @Suppress("UNCHECKED_CAST")
    private fun <T> getCached(key: String, maxAgeMs: Long): T? {
        val entry = cache[key] as? CacheEntry<T> ?: return null
        return if (System.currentTimeMillis() < entry.expiresAt) entry.data else null
    }

    private fun <T> setCache(key: String, data: T, ttlMs: Long) {
        cache[key] = CacheEntry(data, System.currentTimeMillis() + ttlMs)
    }

    // MARK: - Forum Feed Screen

    /**
     * Fetch forum feed with posts, categories, and featured content.
     */
    suspend fun getForumFeedData(
        userId: UUID? = null,
        categoryId: Int? = null,
        postType: String? = null,
        sortBy: String = "recent",
        limit: Int = 20,
        offset: Int = 0
    ): Result<ForumFeedScreenData> {
        val cacheKey = "forum_feed_${categoryId ?: 0}_${sortBy}_$offset"
        
        getCached<ForumFeedScreenData>(cacheKey, 60_000)?.let { return Result.success(it) }

        val params = ForumFeedParams(
            pUserId = userId?.toString(),
            pCategoryId = categoryId,
            pPostType = postType,
            pSortBy = sortBy,
            pPageLimit = limit,
            pPageOffset = offset
        )

        return rpcClient.call<ForumFeedParams, ForumFeedScreenData>(
            "get_forum_feed_data",
            params
        ).onSuccess { setCache(cacheKey, it, 60_000) }
    }

    // MARK: - Search Screen

    /**
     * Fetch search results or suggestions.
     */
    suspend fun getSearchData(
        userId: UUID? = null,
        query: String? = null,
        searchType: String = "all",
        latitude: Double? = null,
        longitude: Double? = null,
        radiusKm: Double = 50.0,
        categoryId: Long? = null,
        limit: Int = 20,
        offset: Int = 0
    ): Result<SearchScreenData> {
        val params = SearchParams(
            pUserId = userId?.toString(),
            pQuery = query,
            pSearchType = searchType,
            pLatitude = latitude,
            pLongitude = longitude,
            pRadiusKm = radiusKm,
            pCategoryId = categoryId,
            pLimit = limit,
            pOffset = offset
        )

        return rpcClient.call<SearchParams, SearchScreenData>(
            "get_search_screen_data",
            params
        )
    }
}
