
#if !SKIP
#if !SKIP
import CoreLocation
#endif
import Foundation

/// Utility functions for geolocation calculations
enum GeolocationUtils {
    /// Calculate distance between two locations in meters
    static func distance(from location1: Location, to location2: Location) -> Double {
        location1.distance(to: location2)
    }

    /// Calculate distance in kilometers
    static func distanceInKilometers(from location1: Location, to location2: Location) -> Double {
        distance(from: location1, to: location2) / 1000.0
    }

    /// Calculate distance in miles
    static func distanceInMiles(from location1: Location, to location2: Location) -> Double {
        distance(from: location1, to: location2) / 1609.34
    }

    /// Format distance for display
    static func formatDistance(_ meters: Double, useMetric: Bool = true) -> String {
        if useMetric {
            if meters < 1000 {
                return String(format: "%.0f m", meters)
            } else {
                let km = meters / 1000.0
                return String(format: "%.1f km", km)
            }
        } else {
            let miles = meters / 1609.34
            if miles < 0.1 {
                let feet = meters * 3.28084
                return String(format: "%.0f ft", feet)
            } else {
                return String(format: "%.1f mi", miles)
            }
        }
    }

    /// Check if location is within radius
    static func isWithinRadius(
        location: Location,
        center: Location,
        radiusMeters: Double,
    ) -> Bool {
        distance(from: location, to: center) <= radiusMeters
    }

    /// Calculate bearing between two locations in degrees
    static func bearing(from location1: Location, to location2: Location) -> Double {
        let lat1 = location1.latitude.degreesToRadians
        let lon1 = location1.longitude.degreesToRadians
        let lat2 = location2.latitude.degreesToRadians
        let lon2 = location2.longitude.degreesToRadians

        let dLon = lon2 - lon1

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x)

        return bearing.radiansToDegrees.normalized360
    }

    /// Calculate destination point given distance and bearing
    static func destination(
        from location: Location,
        distance: Double,
        bearing: Double,
    ) -> Location {
        let radius = 6_371_000.0 // Earth's radius in meters
        let angularDistance = distance / radius

        let lat1 = location.latitude.degreesToRadians
        let lon1 = location.longitude.degreesToRadians
        let bearingRad = bearing.degreesToRadians

        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
                cos(lat1) * sin(angularDistance) * cos(bearingRad),
        )

        let lon2 = lon1 + atan2(
            sin(bearingRad) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2),
        )

        return Location(
            latitude: lat2.radiansToDegrees,
            longitude: lon2.radiansToDegrees,
        )
    }

    /// Get cardinal direction from bearing
    static func cardinalDirection(from bearing: Double) -> String {
        let normalized = bearing.normalized360
        switch normalized {
        case 0 ..< 22.5, 337.5 ... 360:
            return "N"
        case 22.5 ..< 67.5:
            return "NE"
        case 67.5 ..< 112.5:
            return "E"
        case 112.5 ..< 157.5:
            return "SE"
        case 157.5 ..< 202.5:
            return "S"
        case 202.5 ..< 247.5:
            return "SW"
        case 247.5 ..< 292.5:
            return "W"
        case 292.5 ..< 337.5:
            return "NW"
        default:
            return "N"
        }
    }
}

// MARK: - Double Extensions

extension Double {
    fileprivate var degreesToRadians: Double {
        self * .pi / 180
    }
    fileprivate var radiansToDegrees: Double {
        self * 180 / .pi
    }
    fileprivate var normalized360: Double {
        var value = self
        while value < 0 {
            value += 360
        }
        while value >= 360 {
            value -= 360
        }
        return value
    }
}

// MARK: - Distance Unit System

/// Distance unit system based on user's locale
enum DistanceUnit: String, CaseIterable, Sendable {
    case kilometers
    case miles

    // MARK: - Locale Detection

    /// Returns the appropriate unit based on user's locale
    /// US, UK, and a few other countries use miles; most use kilometers
    static var current: DistanceUnit {
        let locale = Locale.current

        // Countries that primarily use miles
        let milesCountries: Set<String> = ["US", "GB", "MM", "LR"]

        if let regionCode = locale.region?.identifier,
           milesCountries.contains(regionCode)
        {
            return .miles
        }

        // Also check measurement system as fallback
        if locale.measurementSystem == Locale.MeasurementSystem.us || locale.measurementSystem == Locale.MeasurementSystem.uk {
            return .miles
        }

        return .kilometers
    }

    /// Whether the current locale uses metric system
    static var usesMetric: Bool {
        current == .kilometers
    }

    // MARK: - Unit Properties

    /// Short unit symbol (km or mi)
    var symbol: String {
        switch self {
        case .kilometers: "km"
        case .miles: "mi"
        }
    }

    /// Full unit name
    var unitName: String {
        switch self {
        case .kilometers: "kilometers"
        case .miles: "miles"
        }
    }

    /// Singular unit name
    var singularName: String {
        switch self {
        case .kilometers: "kilometer"
        case .miles: "mile"
        }
    }

    // MARK: - Conversion Constants

    /// Conversion factor from kilometers to this unit
    var fromKilometers: Double {
        switch self {
        case .kilometers: 1.0
        case .miles: 0.621371
        }
    }

    /// Conversion factor from this unit to kilometers
    var toKilometers: Double {
        switch self {
        case .kilometers: 1.0
        case .miles: 1.60934
        }
    }

    // MARK: - Conversion Methods

    /// Convert kilometers to this unit
    func convert(fromKilometers km: Double) -> Double {
        km * fromKilometers
    }

    /// Convert this unit to kilometers
    /// Clamps to maxSearchRadiusKm (800) to prevent validation errors
    func convertToKilometers(_ value: Double) -> Double {
        let km = value * toKilometers
        // Clamp to max search radius to prevent exceeding validation limit
        // 500 miles = 804.67 km, which would exceed 800 km max
        return min(km, 800.0)
    }

    // MARK: - Slider Range

    /// Maximum radius value for UI sliders in this unit
    var maxSliderValue: Double {
        switch self {
        case .kilometers: 800.0
        case .miles: 500.0
        }
    }

    /// Minimum radius value for UI sliders in this unit
    var minSliderValue: Double {
        switch self {
        case .kilometers: 1.0
        case .miles: 0.5 // ~0.8 km
        }
    }

    /// Step value for UI sliders
    var sliderStep: Double {
        switch self {
        case .kilometers: 5.0
        case .miles: 5.0
        }
    }
}

// MARK: - Distance Formatting

extension DistanceUnit {
    /// Format a distance value with unit symbol
    /// - Parameters:
    ///   - value: Distance value in this unit
    ///   - decimals: Number of decimal places (default 0 for whole numbers)
    /// - Returns: Formatted string like "5 km" or "3 mi"
    func format(_ value: Double, decimals: Int = 0) -> String {
        if decimals == 0 {
            "\(Int(value.rounded())) \(symbol)"
        } else {
            String(format: "%.\(decimals)f \(symbol)", value)
        }
    }

    /// Format a distance value from kilometers to this unit with symbol
    func formatFromKilometers(_ km: Double, decimals: Int = 0) -> String {
        let converted = convert(fromKilometers: km)
        return format(converted, decimals: decimals)
    }
}

// MARK: - Static Convenience Methods

extension DistanceUnit {
    /// Format distance using current locale's unit system
    static func formatLocalized(_ km: Double, decimals: Int = 0) -> String {
        current.formatFromKilometers(km, decimals: decimals)
    }

    /// Convert kilometers to current locale's unit
    static func localizedValue(fromKilometers km: Double) -> Double {
        current.convert(fromKilometers: km)
    }

    /// Convert current locale's unit to kilometers
    static func kilometersFromLocalized(_ value: Double) -> Double {
        current.convertToKilometers(value)
    }

    /// Current locale's unit symbol
    static var localizedSymbol: String {
        current.symbol
    }

    /// Current locale's max slider value
    static var localizedMaxSlider: Double {
        current.maxSliderValue
    }

    /// Current locale's min slider value
    static var localizedMinSlider: Double {
        current.minSliderValue
    }

    /// Current locale's slider step
    static var localizedSliderStep: Double {
        current.sliderStep
    }
}

// MARK: - Double Extension for Distance

extension Double {
    /// Convert this value from kilometers to the current locale's unit
    var localizedDistance: Double {
        DistanceUnit.localizedValue(fromKilometers: self)
    }

    /// Format this kilometer value using the current locale's unit
    func formatAsDistance(decimals: Int = 0) -> String {
        DistanceUnit.formatLocalized(self, decimals: decimals)
    }

    /// Convert this value from the current locale's unit to kilometers
    var asKilometers: Double {
        DistanceUnit.kilometersFromLocalized(self)
    }
}

#endif
