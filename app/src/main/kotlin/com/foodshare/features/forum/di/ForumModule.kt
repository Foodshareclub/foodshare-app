package com.foodshare.features.forum.di

import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.features.forum.data.repository.SupabaseForumRepository
import com.foodshare.features.forum.domain.repository.ForumRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object ForumModule {

    @Provides
    @Singleton
    fun provideForumRepository(
        supabaseClient: SupabaseClient,
        rpcClient: RateLimitedRPCClient,
        realtimeManager: RealtimeChannelManager
    ): ForumRepository {
        return SupabaseForumRepository(
            supabaseClient = supabaseClient,
            rpcClient = rpcClient,
            realtimeManager = realtimeManager
        )
    }
}
