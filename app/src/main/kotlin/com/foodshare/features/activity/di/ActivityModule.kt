package com.foodshare.features.activity.di

import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.features.activity.data.repository.SupabaseActivityRepository
import com.foodshare.features.activity.domain.repository.ActivityRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

/**
 * Hilt module for Activity feature dependencies.
 */
@Module
@InstallIn(SingletonComponent::class)
object ActivityModule {

    @Provides
    @Singleton
    fun provideActivityRepository(
        supabaseClient: SupabaseClient,
        rpcClient: RateLimitedRPCClient,
        realtimeManager: RealtimeChannelManager
    ): ActivityRepository {
        return SupabaseActivityRepository(supabaseClient, rpcClient, realtimeManager)
    }
}
