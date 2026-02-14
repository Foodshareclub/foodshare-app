//
//  CoreLocationCompat.swift
//  FoodShare
//
//  Skip-compatible replacements for CoreLocation types.
//  Only compiled when transpiling for Android via Skip.
//  On iOS, the real CoreLocation framework is used instead.
//

#if SKIP

import Foundation

/// Skip-compatible replacement for CoreLocation.CLLocationCoordinate2D
public struct CLLocationCoordinate2D: Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

/// Skip-compatible replacement for CoreLocation.CLLocation
/// Provides the distance(from:) API used for geo calculations
public final class CLLocation: @unchecked Sendable {
    public let coordinate: CLLocationCoordinate2D

    public init(latitude: Double, longitude: Double) {
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Calculate distance between two locations using Haversine formula
    /// - Returns: Distance in meters
    public func distance(from location: CLLocation) -> Double {
        let R = 6371000.0 // Earth's radius in meters
        let lat1 = coordinate.latitude * .pi / 180
        let lat2 = location.coordinate.latitude * .pi / 180
        let dLat = (location.coordinate.latitude - coordinate.latitude) * .pi / 180
        let dLon = (location.coordinate.longitude - coordinate.longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) +
            cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        return R * c
    }
}

#endif
