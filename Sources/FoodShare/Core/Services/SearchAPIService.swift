//
//  SearchAPIService.swift
//  Foodshare
//
//  API service for search via api-v1-search edge function
//


#if !SKIP
import Foundation

// MARK: - Search API Service

actor SearchAPIService {
    nonisolated static let shared = SearchAPIService()
    private let client: APIClient

    init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Search

    /// Perform a search query with optional geo and filter parameters
    /// - Parameters:
    ///   - query: Search text
    ///   - mode: Search mode (semantic, text, hybrid, fuzzy)
    ///   - lat: Latitude for geo-search
    ///   - lng: Longitude for geo-search
    ///   - radiusKm: Radius in kilometers for geo-search
    ///   - categoryIds: Optional category IDs to filter by
    ///   - limit: Maximum results to return
    ///   - offset: Pagination offset
    func search(
        query: String,
        mode: SearchMode = .hybrid,
        lat: Double? = nil,
        lng: Double? = nil,
        radiusKm: Double? = nil,
        categoryIds: [Int]? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> SearchResultDTO {
        var params: [String: String] = [
            "q": query,
            "mode": mode.rawValue,
            "limit": "\(limit)",
            "offset": "\(offset)",
        ]
        if let lat { params["lat"] = "\(lat)" }
        if let lng { params["lng"] = "\(lng)" }
        if let radiusKm { params["radiusKm"] = "\(radiusKm)" }
        if let categoryIds, !categoryIds.isEmpty {
            params["categoryIds"] = categoryIds.map { "\($0)" }.joined(separator: ",")
        }

        return try await client.get("api-v1-search", params: params)
    }
}

// MARK: - Search Mode

enum SearchMode: String, Sendable {
    case semantic
    case text
    case hybrid
    case fuzzy
}

// MARK: - DTOs

/// Top-level search result from the API
struct SearchResultDTO: Codable, Sendable {
    let items: [SearchItemDTO]
    let totalCount: Int?
    let hasMore: Bool?
}

/// Individual search result item
struct SearchItemDTO: Codable, Identifiable, Sendable {
    let id: Int
    let title: String?
    let description: String?
    let score: Double?
    let distanceMeters: Double?
    let latitude: Double?
    let longitude: Double?
    let images: [String]?
    let postType: String?
}

#endif
