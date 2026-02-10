package com.foodshare.features.activity.data.repository

import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.network.RPCConfig
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.core.realtime.RealtimeFilter
import com.foodshare.features.activity.data.dto.*
import com.foodshare.features.activity.domain.model.ActivityItem
import com.foodshare.features.activity.domain.model.ActivityType
import com.foodshare.features.activity.domain.model.PostActivityItem
import com.foodshare.features.activity.domain.model.PostActivityStats
import com.foodshare.features.activity.domain.repository.ActivityRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.merge
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Supabase implementation of ActivityRepository.
 *
 * SYNC: Mirrors Swift SupabaseActivityRepository
 */
@Singleton
class SupabaseActivityRepository @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val rpcClient: RateLimitedRPCClient,
    private val realtimeManager: RealtimeChannelManager
) : ActivityRepository {

    private val currentUserId: String?
        get() = supabaseClient.auth.currentUserOrNull()?.id

    override suspend fun getActivities(offset: Int, limit: Int): Result<List<ActivityItem>> {
        val params = GetActivityFeedParams(
            limit = limit,
            offset = offset
        )

        return rpcClient.call<GetActivityFeedParams, List<MixedActivityDto>>(
            functionName = "get_mixed_activity_feed",
            params = params,
            config = RPCConfig.normal
        ).map { dtos ->
            dtos.map { it.toDomain() }
        }
    }

    override fun observeActivities(): Flow<ActivityItem> {
        // Subscribe to new posts
        val postsFilter = RealtimeFilter(
            table = "posts",
            filter = null // Listen to all new posts
        )

        // Subscribe to new forum posts
        val forumFilter = RealtimeFilter(
            table = "forum",
            filter = null
        )

        return channelFlow {
            // Merge both channels
            val postsFlow = realtimeManager.subscribe<PostInsertDto>(postsFilter)
            val forumFlow = realtimeManager.subscribe<ForumInsertDto>(forumFilter)

            merge(
                postsFlow.map { change ->
                    change.currentRecord()?.toActivityItem()
                },
                forumFlow.map { change ->
                    change.currentRecord()?.toActivityItem()
                }
            ).collect { item ->
                item?.let { send(it) }
            }
        }
    }

    override suspend fun getPostActivities(postId: Int, limit: Int): Result<List<PostActivityItem>> {
        return runCatching {
            supabaseClient.from("post_activity_logs")
                .select {
                    filter { eq("post_id", postId) }
                    order("created_at", Order.DESCENDING)
                    limit(limit.toLong())
                }
                .decodeList<PostActivityLogDto>()
                .map { it.toDomain() }
        }
    }

    override suspend fun getRecentActivitiesForMyPosts(): Result<List<PostActivityItem>> {
        val userId = currentUserId ?: return Result.failure(
            IllegalStateException("User not authenticated")
        )

        return runCatching {
            // Get user's post IDs first, then get activities
            val myPostIds = supabaseClient.from("posts")
                .select {
                    filter { eq("profile_id", userId) }
                }
                .decodeList<PostIdDto>()
                .map { it.id }

            if (myPostIds.isEmpty()) {
                return@runCatching emptyList()
            }

            supabaseClient.from("post_activity_logs")
                .select {
                    filter { isIn("post_id", myPostIds) }
                    order("created_at", Order.DESCENDING)
                    limit(50)
                }
                .decodeList<PostActivityLogDto>()
                .map { it.toDomain() }
        }
    }

    override suspend fun getPostActivityStats(postId: Int): Result<PostActivityStats> {
        val params = GetPostActivityStatsParams(postId = postId)

        return rpcClient.call<GetPostActivityStatsParams, PostActivityStatsDto>(
            functionName = "get_post_activity_stats",
            params = params,
            config = RPCConfig.normal
        ).map { it.toDomain() }
    }
}

// Helper DTOs for realtime subscriptions
@kotlinx.serialization.Serializable
private data class PostInsertDto(
    val id: Int,
    @kotlinx.serialization.SerialName("post_name") val postName: String,
    @kotlinx.serialization.SerialName("post_type") val postType: String,
    @kotlinx.serialization.SerialName("profile_id") val profileId: String,
    @kotlinx.serialization.SerialName("created_at") val createdAt: String
) {
    fun toActivityItem(): ActivityItem {
        return ActivityItem(
            id = "post-$id",
            type = ActivityType.NEW_LISTING,
            title = "New listing posted",
            subtitle = postName,
            timestamp = try { Instant.parse(createdAt) } catch (e: Exception) { Instant.now() },
            linkedPostId = id,
            linkedProfileId = profileId
        )
    }
}

@kotlinx.serialization.Serializable
private data class ForumInsertDto(
    val id: Int,
    val title: String,
    @kotlinx.serialization.SerialName("user_id") val userId: String,
    @kotlinx.serialization.SerialName("created_at") val createdAt: String
) {
    fun toActivityItem(): ActivityItem {
        return ActivityItem(
            id = "forum-$id",
            type = ActivityType.FORUM_POST,
            title = "New forum discussion",
            subtitle = title,
            timestamp = try { Instant.parse(createdAt) } catch (e: Exception) { Instant.now() },
            linkedForumId = id,
            linkedProfileId = userId
        )
    }
}

@kotlinx.serialization.Serializable
private data class PostIdDto(
    val id: Int
)
