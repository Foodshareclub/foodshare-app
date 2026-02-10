package com.foodshare.features.notifications.di

import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.features.notifications.data.repository.SupabaseNotificationRepository
import com.foodshare.features.notifications.domain.repository.NotificationRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

/**
 * Hilt module for Notification feature dependencies.
 */
@Module
@InstallIn(SingletonComponent::class)
object NotificationModule {

    @Provides
    @Singleton
    fun provideNotificationRepository(
        supabaseClient: SupabaseClient,
        rpcClient: RateLimitedRPCClient,
        realtimeManager: RealtimeChannelManager
    ): NotificationRepository {
        return SupabaseNotificationRepository(supabaseClient, rpcClient, realtimeManager)
    }
}
