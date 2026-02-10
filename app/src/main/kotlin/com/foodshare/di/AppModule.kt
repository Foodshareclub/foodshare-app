package com.foodshare.di

import android.content.Context
import com.foodshare.BuildConfig
import com.foodshare.core.network.EdgeFunctionClient
import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.core.push.PushTokenManager
import com.foodshare.core.realtime.RealtimeChannelManager
import com.foodshare.core.cache.DataStoreMessageQueue
import com.foodshare.core.cache.DataStoreOfflineCache
import com.foodshare.core.cache.MessageQueue
import com.foodshare.core.cache.OfflineCache
import com.foodshare.core.sync.NetworkMonitor
import com.foodshare.core.sync.SyncManager
import com.foodshare.domain.repository.FavoritesRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.FlowType
import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.functions.Functions
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.realtime.Realtime
import io.github.jan.supabase.storage.Storage
import javax.inject.Singleton

/**
 * Hilt module for providing application-wide dependencies
 */
@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    /**
     * Provides the Supabase client as a singleton
     */
    @Provides
    @Singleton
    fun provideSupabaseClient(): SupabaseClient {
        return createSupabaseClient(
            supabaseUrl = BuildConfig.SUPABASE_URL,
            supabaseKey = BuildConfig.SUPABASE_ANON_KEY
        ) {
            install(Auth) {
                flowType = FlowType.PKCE
                scheme = "club.foodshare"
                host = "auth"
            }
            install(Postgrest)
            install(Storage)
            install(Realtime)
            install(Functions)
        }
    }

    /**
     * Provides the rate-limited RPC client
     */
    @Provides
    @Singleton
    fun provideRateLimitedRPCClient(
        supabaseClient: SupabaseClient
    ): RateLimitedRPCClient {
        return RateLimitedRPCClient(supabaseClient)
    }

    /**
     * Provides the Edge Function client
     */
    @Provides
    @Singleton
    fun provideEdgeFunctionClient(
        supabaseClient: SupabaseClient
    ): EdgeFunctionClient {
        return EdgeFunctionClient(supabaseClient)
    }

    /**
     * Provides the Realtime channel manager
     */
    @Provides
    @Singleton
    fun provideRealtimeChannelManager(
        supabaseClient: SupabaseClient
    ): RealtimeChannelManager {
        return RealtimeChannelManager(supabaseClient)
    }

    /**
     * Provides the network monitor
     */
    @Provides
    @Singleton
    fun provideNetworkMonitor(
        @ApplicationContext context: Context
    ): NetworkMonitor {
        return NetworkMonitor(context)
    }

    /**
     * Provides the push token manager
     */
    @Provides
    @Singleton
    fun providePushTokenManager(
        @ApplicationContext context: Context,
        supabaseClient: SupabaseClient
    ): PushTokenManager {
        return PushTokenManager(context, supabaseClient)
    }

    /**
     * Provides the sync manager
     */
    @Provides
    @Singleton
    fun provideSyncManager(
        @ApplicationContext context: Context,
        supabaseClient: SupabaseClient,
        rpcClient: RateLimitedRPCClient,
        networkMonitor: NetworkMonitor,
        favoritesRepository: FavoritesRepository
    ): SyncManager {
        return SyncManager(context, supabaseClient, rpcClient, networkMonitor, favoritesRepository)
    }

    /**
     * Provides the offline cache
     */
    @Provides
    @Singleton
    fun provideOfflineCache(
        @ApplicationContext context: Context
    ): OfflineCache {
        return DataStoreOfflineCache(context)
    }

    /**
     * Provides the message queue
     */
    @Provides
    @Singleton
    fun provideMessageQueue(
        @ApplicationContext context: Context
    ): MessageQueue {
        return DataStoreMessageQueue(context)
    }
}
