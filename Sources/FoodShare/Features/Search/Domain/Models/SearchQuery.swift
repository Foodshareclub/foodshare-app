//
//  SearchQuery.swift
//  Foodshare
//
//  Search query domain model
//


#if !SKIP
#if !SKIP
import CoreLocation
#endif
import Foundation

struct SearchQuery: Sendable {
    let text: String?
    let categoryId: Int?
    let location: CLLocationCoordinate2D
    let radiusKm: Double
    let maxExpiryDays: Int?
    let sortBy: SearchSortOption

    init(
        text: String? = nil,
        categoryId: Int? = nil,
        location: CLLocationCoordinate2D,
        radiusKm: Double = 5.0,
        maxExpiryDays: Int? = nil,
        sortBy: SearchSortOption = .distance,
    ) {
        self.text = text
        self.categoryId = categoryId
        self.location = location
        self.radiusKm = radiusKm
        self.maxExpiryDays = maxExpiryDays
        self.sortBy = sortBy
    }
}

enum SearchSortOption: String, CaseIterable, Sendable {
    case distance = "Distance"
    case newest = "Newest"
    case expiringSoon = "Expiring Soon"

    var systemImage: String {
        switch self {
        case .distance: "location.fill"
        case .newest: "clock.fill"
        case .expiringSoon: "calendar.badge.exclamationmark"
        }
    }
}

struct SearchSuggestion: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let type: SuggestionType

    enum SuggestionType {
        case recent
        case category
        case popular
    }
}

// MARK: - Test Fixtures

extension SearchQuery {
    /// Create a fixture for testing
    static func fixture(
        text: String? = nil,
        categoryId: Int? = nil,
        location: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        radiusKm: Double = 5.0,
        maxExpiryDays: Int? = nil,
        sortBy: SearchSortOption = .distance,
    ) -> SearchQuery {
        SearchQuery(
            text: text,
            categoryId: categoryId,
            location: location,
            radiusKm: radiusKm,
            maxExpiryDays: maxExpiryDays,
            sortBy: sortBy,
        )
    }
}

extension SearchSuggestion {
    /// Create a fixture for testing
    static func fixture(
        text: String = "Fresh produce",
        type: SuggestionType = .popular,
    ) -> SearchSuggestion {
        SearchSuggestion(text: text, type: type)
    }
}

#endif
