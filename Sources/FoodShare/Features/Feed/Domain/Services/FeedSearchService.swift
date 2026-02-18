//
//  FeedSearchService.swift
//  FoodShare
//
//  Service layer for feed search and filtering operations.
//  Provides local filtering and sorting of food items.
//



#if !SKIP
import Foundation

// MARK: - Feed Search Service Protocol

/// Protocol for feed search and filtering operations
protocol FeedSearchServiceProtocol: Sendable {
    /// Filters items by search query
    /// - Parameters:
    ///   - items: The items to filter
    ///   - query: The search query
    /// - Returns: Filtered items matching the query
    func search(items: [FoodItem], query: String) -> [FoodItem]

    /// Filters items by category
    /// - Parameters:
    ///   - items: The items to filter
    ///   - category: The category to filter by (nil for all)
    /// - Returns: Filtered items in the category
    func filterByCategory(items: [FoodItem], category: Category?) -> [FoodItem]

    /// Filters items by post type
    /// - Parameters:
    ///   - items: The items to filter
    ///   - postType: The post type to filter by (nil for all)
    /// - Returns: Filtered items of the post type
    func filterByPostType(items: [FoodItem], postType: String?) -> [FoodItem]

    /// Sorts items by the specified option
    /// - Parameters:
    ///   - items: The items to sort
    ///   - option: The sort option
    /// - Returns: Sorted items
    func sort(items: [FoodItem], by option: FeedSortOption) -> [FoodItem]

    /// Applies all filters and sorting
    /// - Parameters:
    ///   - items: The items to process
    ///   - query: Search query (empty for no search)
    ///   - category: Category filter (nil for all)
    ///   - postType: Post type filter (nil for all)
    ///   - sortOption: Sort option
    /// - Returns: Filtered and sorted items
    func applyFilters(
        items: [FoodItem],
        query: String,
        category: Category?,
        postType: String?,
        sortOption: FeedSortOption
    ) -> [FoodItem]
}

// MARK: - Feed Sort Option

enum FeedSortOption: String, CaseIterable, Sendable {
    case nearest = "Nearest"
    case newest = "Newest"
    case expiringSoon = "Expiring Soon"
    case mostViewed = "Popular"

    var icon: String {
        switch self {
        case .nearest: "location"
        case .newest: "clock"
        case .expiringSoon: "exclamationmark.clock"
        case .mostViewed: "flame"
        }
    }

    var localizedKey: String {
        switch self {
        case .nearest: "feed.sort.nearest"
        case .newest: "feed.sort.newest"
        case .expiringSoon: "feed.sort.expiring"
        case .mostViewed: "feed.sort.popular"
        }
    }
}

// MARK: - Feed Search Service

/// Default implementation of FeedSearchServiceProtocol
struct FeedSearchService: FeedSearchServiceProtocol {
    // MARK: - Search

    func search(items: [FoodItem], query: String) -> [FoodItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty else { return items }

        return items.filter { item in
            item.title.lowercased().contains(trimmedQuery) ||
            (item.description?.lowercased().contains(trimmedQuery) ?? false) ||
            item.postType.lowercased().contains(trimmedQuery)
        }
    }

    // MARK: - Filter by Category

    func filterByCategory(items: [FoodItem], category: Category?) -> [FoodItem] {
        guard let category = category else { return items }
        return items.filter { $0.categoryId == category.id }
    }

    // MARK: - Filter by Post Type

    func filterByPostType(items: [FoodItem], postType: String?) -> [FoodItem] {
        guard let postType = postType else { return items }
        return items.filter { $0.postType == postType }
    }

    // MARK: - Sort

    func sort(items: [FoodItem], by option: FeedSortOption) -> [FoodItem] {
        switch option {
        case .nearest:
            // Already sorted by distance from API
            return items

        case .newest:
            return items.sorted { $0.createdAt > $1.createdAt }

        case .expiringSoon:
            // Sort by creation date (oldest first as proxy for expiring soon)
            return items.sorted { $0.createdAt < $1.createdAt }

        case .mostViewed:
            return items.sorted { $0.postViews > $1.postViews }
        }
    }

    // MARK: - Apply All Filters

    func applyFilters(
        items: [FoodItem],
        query: String,
        category: Category?,
        postType: String?,
        sortOption: FeedSortOption
    ) -> [FoodItem] {
        var result = items

        // Apply category filter
        result = filterByCategory(items: result, category: category)

        // Apply post type filter
        result = filterByPostType(items: result, postType: postType)

        // Apply search filter
        result = search(items: result, query: query)

        // Apply sorting
        result = sort(items: result, by: sortOption)

        return result
    }
}

// MARK: - Search Highlighting

extension FeedSearchService {
    /// Generates highlighted ranges for a search query in text
    /// - Parameters:
    ///   - text: The text to search in
    ///   - query: The search query
    /// - Returns: Array of ranges where query matches
    static func highlightRanges(in text: String, for query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }

        var ranges: [Range<String.Index>] = []
        var searchRange = text.startIndex..<text.endIndex

        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()

        while let range = lowercasedText.range(of: lowercasedQuery, range: searchRange) {
            // Convert to original text indices
            let distance = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
            let length = lowercasedText.distance(from: range.lowerBound, to: range.upperBound)

            let startIndex = text.index(text.startIndex, offsetBy: distance)
            let endIndex = text.index(startIndex, offsetBy: length)

            ranges.append(startIndex..<endIndex)
            searchRange = range.upperBound..<lowercasedText.endIndex
        }

        return ranges
    }
}


#endif
