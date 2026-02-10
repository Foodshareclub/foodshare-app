package com.foodshare.features.activity.domain.repository

import com.foodshare.features.activity.domain.model.ActivityItem
import com.foodshare.features.activity.domain.model.PostActivityItem
import com.foodshare.features.activity.domain.model.PostActivityStats
import kotlinx.coroutines.flow.Flow

/**
 * Repository interface for activity data operations.
 *
 * SYNC: Mirrors Swift ActivityRepository
 */
interface ActivityRepository {

    /**
     * Fetch activities with pagination.
     */
    suspend fun getActivities(
        offset: Int = 0,
        limit: Int = 20
    ): Result<List<ActivityItem>>

    /**
     * Observe activities as a real-time flow.
     */
    fun observeActivities(): Flow<ActivityItem>

    /**
     * Get activities for a specific post.
     */
    suspend fun getPostActivities(
        postId: Int,
        limit: Int = 50
    ): Result<List<PostActivityItem>>

    /**
     * Get recent activities for the current user's posts.
     */
    suspend fun getRecentActivitiesForMyPosts(): Result<List<PostActivityItem>>

    /**
     * Get activity stats for a specific post.
     */
    suspend fun getPostActivityStats(postId: Int): Result<PostActivityStats>
}
