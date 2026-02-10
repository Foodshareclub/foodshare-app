package com.foodshare.features.challenges.di

import com.foodshare.core.network.RateLimitedRPCClient
import com.foodshare.features.challenges.data.repository.SupabaseChallengeRepository
import com.foodshare.features.challenges.domain.repository.ChallengeRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

/**
 * Hilt module for Challenges feature dependencies.
 */
@Module
@InstallIn(SingletonComponent::class)
object ChallengeModule {

    @Provides
    @Singleton
    fun provideChallengeRepository(
        supabaseClient: SupabaseClient,
        rpcClient: RateLimitedRPCClient
    ): ChallengeRepository {
        return SupabaseChallengeRepository(supabaseClient, rpcClient)
    }
}
