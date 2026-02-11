package com.foodshare.features.profile.di

import com.foodshare.data.repository.SupabaseProfileRepository
import com.foodshare.domain.repository.AuthRepository
import com.foodshare.domain.repository.ProfileRepository
import com.foodshare.features.profile.data.repository.SupabaseProfileActionRepository
import com.foodshare.features.profile.domain.repository.ProfileActionRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.github.jan.supabase.SupabaseClient
import javax.inject.Singleton

/**
 * Hilt module for Profile feature dependencies.
 */
@Module
@InstallIn(SingletonComponent::class)
object ProfileModule {

    @Provides
    @Singleton
    fun provideProfileRepository(
        supabaseClient: SupabaseClient
    ): ProfileRepository {
        return SupabaseProfileRepository(supabaseClient)
    }

    @Provides
    @Singleton
    fun provideProfileActionRepository(
        supabaseClient: SupabaseClient,
        authRepository: AuthRepository
    ): ProfileActionRepository {
        return SupabaseProfileActionRepository(supabaseClient, authRepository)
    }
}
