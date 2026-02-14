//
//  SupabaseFoodItemRepository.swift
//  Foodshare
//
//  Supabase food item repository implementation
//  Maps to `posts` table in Supabase
//  Features retry logic with exponential backoff for transient failures
//

#if !SKIP
import CoreLocation
#endif
import FoodShareArchitecture
import FoodShareRepository
import Foundation
import OSLog
import PostgREST
import Supabase

// MARK: - Repository Implementation

@MainActor
final class SupabaseFoodItemRepository: BaseSupabaseRepository, FoodItemRepository {
    private let rateLimiter: RateLimiter
    private let productsAPI: ProductsAPIService

    init(supabase: Supabase.SupabaseClient, productsAPI: ProductsAPIService = .shared) {
        // Allow 60 requests per minute
        self.rateLimiter = RateLimiter(maxRequests: 60, perSeconds: 60)
        self.productsAPI = productsAPI
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "FoodItemRepository")
    }

    func fetchNearbyItems(location: CLLocationCoordinate2D, radiusKm: Double) async throws -> [FoodItem] {
        try await fetchNearbyItems(location: location, radiusKm: radiusKm, limit: 50, offset: 0, postType: nil)
    }

    func fetchNearbyItems(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
        offset: Int,
        postType: String? = nil,
    ) async throws -> [FoodItem] {
        // Apply rate limiting
        try await rateLimiter.checkRateLimit()

        logger
            .debug(
                "📡 [FoodItemRepo] Fetching nearby items: lat=\(location.latitude), lng=\(location.longitude), radius=\(radiusKm)km, limit=\(limit), postType=\(postType ?? "all")",
            )

        // Use ProductsAPIService, fall back to direct query if API fails
        do {
            let cursor = offset > 0 ? "\(offset)" : nil
            let products = try await productsAPI.getNearbyProducts(
                lat: location.latitude,
                lng: location.longitude,
                radiusKm: radiusKm,
                postType: postType,
                limit: limit,
                cursor: cursor,
            )

            let items = products.map { $0.toFoodItem() }
            logger.debug("✅ [FoodItemRepo] Successfully fetched \(items.count) items from ProductsAPI")
            return items
        } catch {
            logger.warning("⚠️ [FoodItemRepo] ProductsAPI failed, falling back to direct query: \(error.localizedDescription)")
            return try await fetchNearbyItemsDirect(limit: limit, offset: offset)
        }
    }

    /// Direct query fallback when RPC function isn't available
    /// Uses Supabase SDK to query the posts_with_location view
    private func fetchNearbyItemsDirect(limit: Int, offset: Int) async throws -> [FoodItem] {
        logger.debug("📡 [FoodItemRepo] Using SDK fallback query on posts_with_location view")

        do {
            let response = try await supabase
                .from("posts_with_location")
                .select()
                .eq("is_active", value: true)
                .eq("is_arranged", value: false)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()

            let items = try decoder.decode([FoodItem].self, from: response.data)
            logger.debug("✅ [FoodItemRepo] Successfully decoded \(items.count) items via SDK")
            return items
        } catch {
            logger.error("❌ [FoodItemRepo] SDK query failed: \(error.localizedDescription)")
            throw mapError(error)
        }
    }

    func fetchItemById(_ id: Int) async throws -> FoodItem {
        // Use AsyncHelpers.withRetry for automatic exponential backoff on transient failures
        try await AsyncHelpers.withRetry {
            let product = try await self.productsAPI.getProduct(id: id)
            return product.toFoodItem()
        }
    }

    // MARK: - Trending Items (Server-Side Engagement Scoring)

    func fetchTrendingItems(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
    ) async throws -> [FoodItem] {
        try await rateLimiter.checkRateLimit()

        logger.debug("📡 [FoodItemRepo] Fetching trending items via ProductsAPI: radius=\(radiusKm)km, limit=\(limit)")

        do {
            let feedResponse = try await productsAPI.getFeed(
                lat: location.latitude,
                lng: location.longitude,
                radiusKm: radiusKm,
                limit: limit,
            )

            let items = feedResponse.listings.map { $0.toFoodItem() }
            logger.debug("✅ [FoodItemRepo] Fetched \(items.count) trending items from ProductsAPI")
            return items
        } catch {
            // Fall back to client-side sorting if API not available
            logger.warning("⚠️ [FoodItemRepo] ProductsAPI feed failed, using fallback: \(error.localizedDescription)")
            return try await fetchTrendingItemsFallback(location: location, radiusKm: radiusKm, limit: limit)
        }
    }

    /// Fallback: Fetch items and sort client-side by engagement
    private func fetchTrendingItemsFallback(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
    ) async throws -> [FoodItem] {
        let items = try await fetchNearbyItems(
            location: location,
            radiusKm: radiusKm,
            limit: limit * 2, // Fetch more to get better trending candidates
            offset: 0,
            postType: nil,
        )

        // Client-side engagement scoring: views + likes*2 + arrangements*5
        let sorted = items.sorted { first, second in
            let firstEngagement = first.postViews + (first.postLikeCounter ?? 0) * 2
            let secondEngagement = second.postViews + (second.postLikeCounter ?? 0) * 2
            return firstEngagement > secondEngagement
        }

        return Array(sorted.prefix(limit))
    }

    // MARK: - Filtered Feed (Server-Side Sorting)

    func fetchFilteredFeed(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
        offset: Int,
        postType: String?,
        categoryId: Int?,
        sortOption: String,
    ) async throws -> [FoodItem] {
        try await rateLimiter.checkRateLimit()

        logger
            .debug("📡 [FoodItemRepo] Fetching filtered feed via ProductsAPI: sort=\(sortOption), postType=\(postType ?? "all")")

        do {
            let cursor = offset > 0 ? "\(offset)" : nil
            let products = try await productsAPI.getNearbyProducts(
                lat: location.latitude,
                lng: location.longitude,
                radiusKm: radiusKm,
                postType: postType,
                categoryId: categoryId,
                limit: limit,
                cursor: cursor,
            )

            let items = products.map { $0.toFoodItem() }
            logger.debug("✅ [FoodItemRepo] Fetched \(items.count) items from filtered feed via ProductsAPI")
            return items
        } catch {
            // Fall back to existing fetch + client-side filtering
            logger.warning("⚠️ [FoodItemRepo] ProductsAPI filtered feed failed, using fallback: \(error.localizedDescription)")
            return try await fetchNearbyItems(
                location: location,
                radiusKm: radiusKm,
                limit: limit,
                offset: offset,
                postType: postType,
            )
        }
    }
}
