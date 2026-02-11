package com.foodshare.features.settings.di

import com.foodshare.features.settings.data.repository.SupabaseSettingsRepository
import com.foodshare.features.settings.domain.repository.SettingsRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Dependency injection module for settings feature
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class SettingsModule {

    @Binds
    @Singleton
    abstract fun bindSettingsRepository(
        impl: SupabaseSettingsRepository
    ): SettingsRepository
}
