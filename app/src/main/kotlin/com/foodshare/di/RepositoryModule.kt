package com.foodshare.di

import com.foodshare.data.location.FusedLocationService
import com.foodshare.data.repository.SupabaseAuthRepository
import com.foodshare.data.repository.SupabaseChatRepository
import com.foodshare.data.repository.SupabaseFavoritesRepository
import com.foodshare.data.repository.SupabaseFeedRepository
import com.foodshare.data.repository.SupabaseListingRepository
import com.foodshare.data.repository.SupabaseReviewRepository
import com.foodshare.data.repository.SupabaseSearchRepository
import com.foodshare.domain.location.LocationService
import com.foodshare.domain.repository.AuthRepository
import com.foodshare.domain.repository.ChatRepository
import com.foodshare.domain.repository.FavoritesRepository
import com.foodshare.domain.repository.FeedRepository
import com.foodshare.domain.repository.ListingRepository
import com.foodshare.domain.repository.ReviewRepository
import com.foodshare.domain.repository.SearchRepository
import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

/**
 * Hilt module for binding repository implementations
 */
@Module
@InstallIn(SingletonComponent::class)
abstract class RepositoryModule {

    @Binds
    @Singleton
    abstract fun bindAuthRepository(
        impl: SupabaseAuthRepository
    ): AuthRepository

    @Binds
    @Singleton
    abstract fun bindFeedRepository(
        impl: SupabaseFeedRepository
    ): FeedRepository

    @Binds
    @Singleton
    abstract fun bindListingRepository(
        impl: SupabaseListingRepository
    ): ListingRepository

    @Binds
    @Singleton
    abstract fun bindLocationService(
        impl: FusedLocationService
    ): LocationService

    @Binds
    @Singleton
    abstract fun bindFavoritesRepository(
        impl: SupabaseFavoritesRepository
    ): FavoritesRepository

    @Binds
    @Singleton
    abstract fun bindChatRepository(
        impl: SupabaseChatRepository
    ): ChatRepository

    @Binds
    @Singleton
    abstract fun bindReviewRepository(
        impl: SupabaseReviewRepository
    ): ReviewRepository

    @Binds
    @Singleton
    abstract fun bindSearchRepository(
        impl: SupabaseSearchRepository
    ): SearchRepository
}
