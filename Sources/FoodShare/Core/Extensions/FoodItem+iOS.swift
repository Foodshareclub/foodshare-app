//
//  FoodItem+iOS.swift
//  Foodshare
//
//  iOS-specific extensions for FoodItem
//  These properties require CoreLocation which is not available in FoodshareCore
//

#if !SKIP
import CoreLocation
#endif
import FoodshareCore

extension FoodItem {
    /// Location as CLLocationCoordinate2D for MapKit integration
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Location as Location struct
    var location: Location? {
        guard let latitude, let longitude else { return nil }
        return Location(latitude: latitude, longitude: longitude)
    }

    /// All image URLs as URL objects
    var imageURLs: [URL] {
        (images ?? []).compactMap { URL(string: $0) }
    }

}

// MARK: - Location struct (iOS-specific)

/// Simple location struct for iOS
struct Location: Equatable, Sendable {
    let latitude: Double
    let longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
