
#if !SKIP
#if !SKIP
import CoreLocation
#endif
import Foundation

// MARK: - Search Repository Protocol

protocol SearchRepository: Sendable {
    func searchFoodItems(query: SearchQuery) async throws -> [FoodItem]
    func getSearchSuggestions(query: String) async throws -> [SearchSuggestion]
    func saveRecentSearch(query: String) async throws
    func getRecentSearches() async throws -> [String]

    /// Server-side search with full filtering, sorting, and stats
    func searchFoodItemsServerSide(params: ServerSearchParams) async throws -> ServerSearchResult
}

// MARK: - Server Search Parameters

struct ServerSearchParams: Sendable {
    let location: CLLocationCoordinate2D
    let radiusKm: Double
    let searchQuery: String?
    let categoryId: Int?
    let postType: String?
    let availableOnly: Bool
    let arrangedOnly: Bool
    let sortBy: SortOption
    let limit: Int
    let offset: Int

    enum SortOption: String, Sendable {
        case distance
        case newest
        case oldest
        case expiringSoon = "expiring_soon"
        case popular
    }

    init(
        location: CLLocationCoordinate2D,
        radiusKm: Double = 10.0,
        searchQuery: String? = nil,
        categoryId: Int? = nil,
        postType: String? = nil,
        availableOnly: Bool = true,
        arrangedOnly: Bool = false,
        sortBy: SortOption = .distance,
        limit: Int = 50,
        offset: Int = 0,
    ) {
        self.location = location
        self.radiusKm = radiusKm
        self.searchQuery = searchQuery
        self.categoryId = categoryId
        self.postType = postType
        self.availableOnly = availableOnly
        self.arrangedOnly = arrangedOnly
        self.sortBy = sortBy
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - Server Search Result

struct ServerSearchResult: Sendable {
    let items: [FoodItem]
    let totalCount: Int
    let categoryBreakdown: [String: Int]
    let hasMore: Bool

    static let empty = ServerSearchResult(
        items: [],
        totalCount: 0,
        categoryBreakdown: [:],
        hasMore: false,
    )
}

#endif
