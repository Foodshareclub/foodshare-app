package com.foodshare.features.donation.di

import com.foodshare.features.donation.data.repository.SupabaseDonationRepository
import com.foodshare.features.donation.domain.repository.DonationRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
abstract class DonationModule {

    @Binds
    @Singleton
    abstract fun bindDonationRepository(
        impl: SupabaseDonationRepository
    ): DonationRepository
}
