//
//  SupabaseSearchRepository.swift
//  Foodshare
//
//  Supabase implementation of search repository
//  Uses SearchAPIService (Edge Function) as primary path with direct Supabase fallback
//

import FoodShareArchitecture
import FoodShareRepository
import Foundation
import OSLog
import Supabase

@MainActor
final class SupabaseSearchRepository: BaseSupabaseRepository, SearchRepository {
    private nonisolated(unsafe) var recentSearches: [String] = []
    private let searchAPI: SearchAPIService

    /// Rate limiter for search requests (30 requests per 60 seconds)
    private let searchRateLimiter = RateLimiter(maxRequests: 30, perSeconds: 60)

    init(supabase: Supabase.SupabaseClient, searchAPI: SearchAPIService = .shared) {
        self.searchAPI = searchAPI
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "SearchRepository")
        loadRecentSearches()
    }

    // MARK: - Server-Side Search (API-first with RPC fallback)

    func searchFoodItemsServerSide(params: ServerSearchParams) async throws -> ServerSearchResult {
        // Check rate limit before making request
        try await searchRateLimiter.checkRateLimit()

        logger
            .debug(
                "Server-side search: query=\(params.searchQuery ?? "nil"), sort=\(params.sortBy.rawValue)",
            )

        // Try API first
        do {
            let result = try await searchAPI.search(
                query: params.searchQuery ?? "",
                mode: .hybrid,
                lat: params.location.latitude,
                lng: params.location.longitude,
                radiusKm: params.radiusKm,
                categoryIds: params.categoryId.map { [$0] },
                limit: params.limit,
                offset: params.offset
            )

            logger.debug("API search returned \(result.items.count) items, totalCount=\(result.totalCount ?? 0)")

            // Map SearchItemDTOs to FoodItems
            let foodItems = result.items.map { $0.toFoodItem() }

            return ServerSearchResult(
                items: foodItems,
                totalCount: result.totalCount ?? foodItems.count,
                categoryBreakdown: [:],
                hasMore: result.hasMore ?? false,
            )
        } catch {
            logger.warning("API search failed, falling back to RPC: \(error.localizedDescription)")
        }

        // Fallback: direct RPC call
        let rpcParams = SearchFoodItemsParams(
            pLatitude: params.location.latitude,
            pLongitude: params.location.longitude,
            pRadiusKm: params.radiusKm,
            pSearchQuery: params.searchQuery,
            pCategoryId: params.categoryId,
            pPostType: params.postType,
            pAvailableOnly: params.availableOnly,
            pArrangedOnly: params.arrangedOnly,
            pSortBy: params.sortBy.rawValue,
            pLimit: params.limit,
            pOffset: params.offset,
        )

        let dto: ServerSearchResultDTO = try await executeRPC("search_food_items", params: rpcParams)

        logger.debug("RPC search returned \(dto.items.count) items, total=\(dto.totalCount)")

        return ServerSearchResult(
            items: dto.items,
            totalCount: dto.totalCount,
            categoryBreakdown: dto.categoryBreakdown,
            hasMore: dto.hasMore,
        )
    }

    // MARK: - Legacy Search (API-first with RPC fallback)

    func searchFoodItems(query: SearchQuery) async throws -> [FoodItem] {
        // Try API first with text mode
        do {
            let result = try await searchAPI.search(
                query: query.text ?? "",
                mode: .text,
                lat: query.location.latitude,
                lng: query.location.longitude,
                radiusKm: query.radiusKm,
                categoryIds: query.categoryId.map { [$0] },
                limit: 50
            )

            logger.debug("API text search returned \(result.items.count) items")

            return result.items.map { $0.toFoodItem() }
        } catch {
            logger.warning("API text search failed, falling back to RPC: \(error.localizedDescription)")
        }

        // Fallback: direct RPC call
        let params = NearbyFoodItemsParams(
            lat: query.location.latitude,
            long: query.location.longitude,
            dist_meters: query.radiusKm * Constants.metersPerKilometer,
            search_query: (query.text?.isEmpty == false) ? query.text : nil,
            category_filter: query.categoryId,
        )

        let response: [FoodItem] = try await supabase
            .rpc("nearby_food_items", params: params)
            .limit(50)
            .execute()
            .value

        var items = response

        // Filter by text if provided
        if let text = query.text, !text.isEmpty {
            items = items.filter { item in
                item.title.localizedCaseInsensitiveContains(text) ||
                    (item.description?.localizedCaseInsensitiveContains(text) ?? false)
            }
        }

        return items
    }

    // MARK: - Search Suggestions (direct Supabase - no API endpoint)

    func getSearchSuggestions(query: String) async throws -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []

        // Add recent searches
        let recentMatches = recentSearches.filter { $0.localizedCaseInsensitiveContains(query) }
        suggestions += recentMatches.prefix(3).map {
            SearchSuggestion(text: $0, type: .recent)
        }

        // Add popular items
        if !query.isEmpty {
            let response: [SearchSuggestionDTO] = try await supabase
                .from("food_items")
                .select("title")
                .ilike("title", pattern: "%\(query)%")
                .limit(5)
                .execute()
                .value

            suggestions += response.map {
                SearchSuggestion(text: $0.title, type: .popular)
            }
        }

        return suggestions
    }

    // MARK: - Recent Searches (UserDefaults - unchanged)

    func saveRecentSearch(query: String) async throws {
        guard !query.isEmpty else { return }

        // Remove if exists
        recentSearches.removeAll { $0 == query }

        // Add to front
        recentSearches.insert(query, at: 0)

        // Keep only last 10
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }

        // Save using UserDefaultsStore
        await UserDefaultsStore.shared.set(recentSearches, forKey: "recentSearches")
    }

    func getRecentSearches() async throws -> [String] {
        recentSearches
    }

    private func loadRecentSearches() {
        recentSearches = UserDefaultsStore.shared.stringArray(forKey: "recentSearches") ?? []
    }
}

// MARK: - DTOs

/// Parameters for the nearby_food_items RPC call (legacy)
private struct NearbyFoodItemsParams: Encodable {
    let lat: Double
    let long: Double
    let dist_meters: Double
    let search_query: String?
    let category_filter: Int?
}

/// Parameters for the search_food_items RPC call (new server-side search)
private struct SearchFoodItemsParams: Encodable {
    let pLatitude: Double
    let pLongitude: Double
    let pRadiusKm: Double
    let pSearchQuery: String?
    let pCategoryId: Int?
    let pPostType: String?
    let pAvailableOnly: Bool
    let pArrangedOnly: Bool
    let pSortBy: String
    let pLimit: Int
    let pOffset: Int

    enum CodingKeys: String, CodingKey {
        case pLatitude = "p_latitude"
        case pLongitude = "p_longitude"
        case pRadiusKm = "p_radius_km"
        case pSearchQuery = "p_search_query"
        case pCategoryId = "p_category_id"
        case pPostType = "p_post_type"
        case pAvailableOnly = "p_available_only"
        case pArrangedOnly = "p_arranged_only"
        case pSortBy = "p_sort_by"
        case pLimit = "p_limit"
        case pOffset = "p_offset"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pLatitude, forKey: .pLatitude)
        try container.encode(pLongitude, forKey: .pLongitude)
        try container.encode(pRadiusKm, forKey: .pRadiusKm)
        // Encode nil explicitly for optional parameters
        if let query = pSearchQuery, !query.isEmpty {
            try container.encode(query, forKey: .pSearchQuery)
        } else {
            try container.encodeNil(forKey: .pSearchQuery)
        }
        if let categoryId = pCategoryId {
            try container.encode(categoryId, forKey: .pCategoryId)
        } else {
            try container.encodeNil(forKey: .pCategoryId)
        }
        if let postType = pPostType {
            try container.encode(postType, forKey: .pPostType)
        } else {
            try container.encodeNil(forKey: .pPostType)
        }
        try container.encode(pAvailableOnly, forKey: .pAvailableOnly)
        try container.encode(pArrangedOnly, forKey: .pArrangedOnly)
        try container.encode(pSortBy, forKey: .pSortBy)
        try container.encode(pLimit, forKey: .pLimit)
        try container.encode(pOffset, forKey: .pOffset)
    }
}

/// DTO for decoding the search_food_items RPC response
private struct ServerSearchResultDTO: Decodable {
    let items: [FoodItem]
    let totalCount: Int
    let categoryBreakdown: [String: Int]
    let hasMore: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case totalCount = "total_count"
        case categoryBreakdown = "category_breakdown"
        case hasMore = "has_more"
    }
}

struct SearchSuggestionDTO: Codable {
    let title: String
}

// MARK: - SearchItemDTO → FoodItem Mapping

extension SearchItemDTO {
    /// Convert API search item DTO to domain FoodItem model
    func toFoodItem() -> FoodItem {
        FoodItem(
            id: id,
            profileId: nil,
            postName: title ?? "Untitled",
            postDescription: description,
            postType: postType ?? "food",
            pickupTime: nil,
            availableHours: nil,
            postAddress: nil,
            postStrippedAddress: nil,
            latitude: latitude,
            longitude: longitude,
            images: images,
            isActive: true,
            isArranged: false,
            postArrangedTo: nil,
            postArrangedAt: nil,
            postViews: 0,
            postLikeCounter: nil,
            hasPantry: nil,
            foodStatus: nil,
            network: nil,
            website: nil,
            donation: nil,
            donationRules: nil,
            categoryId: nil,
            createdAt: Date(),
            updatedAt: Date(),
            distanceMeters: distanceMeters
        )
    }
}
