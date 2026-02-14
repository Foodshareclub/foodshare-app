#if !SKIP
import CoreLocation
#endif
import Foundation

protocol FoodItemRepository: Sendable {
    /// Fetch nearby items with default pagination
    func fetchNearbyItems(location: CLLocationCoordinate2D, radiusKm: Double) async throws -> [FoodItem]

    /// Fetch nearby items with pagination
    func fetchNearbyItems(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
        offset: Int,
        postType: String?,
    ) async throws -> [FoodItem]

    /// Fetch a single item by ID
    func fetchItemById(_ id: Int) async throws -> FoodItem

    /// Fetch trending items via server-side engagement scoring
    /// Server calculates: views + likes*2 + arrangements*5
    func fetchTrendingItems(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
    ) async throws -> [FoodItem]

    /// Fetch filtered and sorted feed via server
    /// Moves sorting/filtering logic server-side for consistency
    func fetchFilteredFeed(
        location: CLLocationCoordinate2D,
        radiusKm: Double,
        limit: Int,
        offset: Int,
        postType: String?,
        categoryId: Int?,
        sortOption: String,
    ) async throws -> [FoodItem]
}
