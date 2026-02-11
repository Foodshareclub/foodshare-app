package com.foodshare.features.insights.di

import com.foodshare.features.insights.data.repository.SupabaseInsightsRepository
import com.foodshare.features.insights.domain.repository.InsightsRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class InsightsModule {

    @Binds
    @Singleton
    abstract fun bindInsightsRepository(
        impl: SupabaseInsightsRepository
    ): InsightsRepository
}
