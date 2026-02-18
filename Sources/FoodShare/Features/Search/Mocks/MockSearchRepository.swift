//
//  MockSearchRepository.swift
//  Foodshare
//
//  Mock search repository for testing and previews
//


#if !SKIP
import CoreLocation
import Foundation

#if DEBUG
    final class MockSearchRepository: SearchRepository, @unchecked Sendable {
        nonisolated(unsafe) var mockItems: [FoodItem] = FoodItem.sampleListings
        nonisolated(unsafe) var mockSuggestions: [SearchSuggestion] = []
        nonisolated(unsafe) var recentSearches: [String] = []
        nonisolated(unsafe) var shouldFail = false

        init() {
            // Initialize with sample suggestions
            mockSuggestions = [
                SearchSuggestion(text: "Fresh vegetables", type: .popular),
                SearchSuggestion(text: "Homemade bread", type: .popular),
                SearchSuggestion(text: "Organic produce", type: .popular)
            ]
        }

        func searchFoodItems(query: SearchQuery) async throws -> [FoodItem] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            var results = mockItems

            // Filter by text if provided
            if let text = query.text, !text.isEmpty {
                results = results.filter { item in
                    item.title.localizedCaseInsensitiveContains(text) ||
                        (item.description?.localizedCaseInsensitiveContains(text) ?? false)
                }
            }

            // Filter by category if provided
            if let categoryId = query.categoryId {
                results = results.filter { $0.categoryId == categoryId }
            }

            return results
        }

        func getSearchSuggestions(query: String) async throws -> [SearchSuggestion] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 100_000_000)

            var suggestions: [SearchSuggestion] = []

            // Add matching recent searches
            let recentMatches = recentSearches.filter {
                $0.localizedCaseInsensitiveContains(query)
            }
            suggestions += recentMatches.prefix(3).map {
                SearchSuggestion(text: $0, type: .recent)
            }

            // Add matching popular suggestions
            if !query.isEmpty {
                let popularMatches = mockSuggestions.filter {
                    $0.text.localizedCaseInsensitiveContains(query)
                }
                suggestions += popularMatches
            }

            return suggestions
        }

        func saveRecentSearch(query: String) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            guard !query.isEmpty else { return }

            // Remove if exists
            recentSearches.removeAll { $0 == query }

            // Add to front
            recentSearches.insert(query, at: 0)

            // Keep only last 10
            if recentSearches.count > 10 {
                recentSearches = Array(recentSearches.prefix(10))
            }
        }

        func getRecentSearches() async throws -> [String] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return recentSearches
        }

        func searchFoodItemsServerSide(params: ServerSearchParams) async throws -> ServerSearchResult {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            var results = mockItems

            // Filter by text if provided
            if let query = params.searchQuery, !query.isEmpty {
                results = results.filter { item in
                    item.postName.localizedCaseInsensitiveContains(query) ||
                        (item.postDescription?.localizedCaseInsensitiveContains(query) ?? false) ||
                        (item.postAddress?.localizedCaseInsensitiveContains(query) ?? false)
                }
            }

            // Filter by category if provided
            if let categoryId = params.categoryId {
                results = results.filter { $0.categoryId == categoryId }
            }

            // Filter by post type
            if let postType = params.postType {
                results = results.filter { $0.postType == postType }
            }

            // Filter by availability
            if params.availableOnly {
                results = results.filter(\.isAvailable)
            }

            // Filter by arranged
            if params.arrangedOnly {
                results = results.filter(\.isArranged)
            }

            // Apply sorting
            switch params.sortBy {
            case .distance:
                break // Already sorted by distance
            case .newest:
                results.sort { $0.createdAt > $1.createdAt }
            case .oldest:
                results.sort { $0.createdAt < $1.createdAt }
            case .expiringSoon:
                results.sort { $0.createdAt < $1.createdAt }
            case .popular:
                results.sort { $0.postViews > $1.postViews }
            }

            // Build category breakdown
            let categoryBreakdown = Dictionary(grouping: results) { $0.postType }
                .mapValues(\.count)

            // Apply pagination
            let startIndex = min(params.offset, results.count)
            let endIndex = min(params.offset + params.limit, results.count)
            let paginatedResults = Array(results[startIndex ..< endIndex])

            return ServerSearchResult(
                items: paginatedResults,
                totalCount: results.count,
                categoryBreakdown: categoryBreakdown,
                hasMore: endIndex < results.count,
            )
        }
    }
#endif

#endif
