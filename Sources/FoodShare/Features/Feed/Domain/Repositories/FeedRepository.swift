//
//  FeedRepository.swift
//  Foodshare
//
//  Repository protocol for feed operations
//  Maps to `posts`, `categories`, and `community_fridges` tables
//

import Foundation

/// Repository for fetching and managing food listings feed
protocol FeedRepository: Sendable {
    // MARK: - Cursor-Based Pagination (Preferred)

    /// Fetch food listings near a location with cursor-based pagination
    /// - Parameters:
    ///   - location: Center point for search
    ///   - radius: Search radius in kilometers
    ///   - pagination: Cursor-based pagination parameters
    ///   - excludeBlockedUsers: Whether to filter out blocked users (default: true)
    /// - Returns: Array of food listings sorted by distance
    func fetchListings(
        near location: Location,
        radius: Double,
        pagination: CursorPaginationParams,
        excludeBlockedUsers: Bool,
    ) async throws -> [FoodItem]

    /// Fetch food listings by category with cursor-based pagination
    /// - Parameters:
    ///   - categoryId: Category ID to filter by
    ///   - location: Center point for search
    ///   - radius: Search radius in kilometers
    ///   - pagination: Cursor-based pagination parameters
    ///   - excludeBlockedUsers: Whether to filter out blocked users (default: true)
    /// - Returns: Array of food listings in the category
    func fetchListings(
        categoryId: Int,
        near location: Location,
        radius: Double,
        pagination: CursorPaginationParams,
        excludeBlockedUsers: Bool,
    ) async throws -> [FoodItem]

    // MARK: - Offset-Based Pagination (Legacy)

    /// Fetch food listings near a location with offset pagination (legacy)
    /// - Parameters:
    ///   - location: Center point for search
    ///   - radius: Search radius in kilometers
    ///   - limit: Maximum number of results
    ///   - offset: Number of items to skip (for pagination)
    ///   - excludeBlockedUsers: Whether to filter out blocked users (default: true)
    /// - Returns: Array of food listings sorted by distance
    func fetchListings(
        near location: Location,
        radius: Double,
        limit: Int,
        offset: Int,
        excludeBlockedUsers: Bool,
    ) async throws -> [FoodItem]

    /// Fetch food listings by category with offset pagination (legacy)
    /// - Parameters:
    ///   - categoryId: Category ID to filter by
    ///   - location: Center point for search
    ///   - radius: Search radius in kilometers
    ///   - limit: Maximum number of results
    ///   - offset: Number of items to skip (for pagination)
    ///   - excludeBlockedUsers: Whether to filter out blocked users (default: true)
    /// - Returns: Array of food listings in the category
    func fetchListings(
        categoryId: Int,
        near location: Location,
        radius: Double,
        limit: Int,
        offset: Int,
        excludeBlockedUsers: Bool,
    ) async throws -> [FoodItem]

    /// Fetch a single listing by ID
    /// - Parameter id: Listing ID
    /// - Returns: The food listing
    func fetchListing(id: Int) async throws -> FoodItem

    /// Fetch all active categories
    /// - Returns: Array of food categories sorted by sort_order
    func fetchCategories() async throws -> [Category]

    /// Increment view count for a listing
    /// - Parameter listingId: ID of the listing
    func incrementViewCount(listingId: Int) async throws

    /// Fetch community fridges near a location
    /// - Parameters:
    ///   - location: Center point for search
    ///   - radius: Search radius in kilometers
    ///   - limit: Maximum number of results
    /// - Returns: Array of community fridges
    func fetchCommunityFridges(
        near location: Location,
        radius: Double,
        limit: Int,
    ) async throws -> [CommunityFridge]

    /// Fetch all initial feed data in a single call (categories + items + trending)
    /// - Parameters:
    ///   - location: Center point for search
    ///   - radius: Search radius in kilometers
    ///   - feedLimit: Maximum number of feed items
    ///   - trendingLimit: Maximum number of trending items
    ///   - postType: Optional post type filter
    ///   - categoryId: Optional category filter
    /// - Returns: Combined feed initial data
    func fetchInitialData(
        location: Location,
        radius: Double,
        feedLimit: Int,
        trendingLimit: Int,
        postType: String?,
        categoryId: Int?,
    ) async throws -> FeedInitialData
}

/// Combined response from get_feed_initial_data RPC
struct FeedInitialData: Sendable {
    let categories: [Category]
    let feedItems: [FoodItem]
    let trendingItems: [FoodItem]
    let stats: FeedStats
}
