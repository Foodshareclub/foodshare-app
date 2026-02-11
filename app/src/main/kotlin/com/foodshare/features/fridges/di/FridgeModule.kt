package com.foodshare.features.fridges.di

import com.foodshare.features.fridges.data.repository.SupabaseFridgeRepository
import com.foodshare.features.fridges.domain.repository.FridgeRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class FridgeModule {

    @Binds
    @Singleton
    abstract fun bindFridgeRepository(
        impl: SupabaseFridgeRepository
    ): FridgeRepository
}
