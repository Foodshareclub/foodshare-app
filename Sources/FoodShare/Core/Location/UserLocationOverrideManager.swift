//
//  UserLocationOverrideManager.swift
//  Foodshare
//
//  Allows users to manually set their location when IP geolocation is inaccurate.
//

#if !SKIP
import CoreLocation
#endif
import Foundation
import OSLog

// MARK: - Location Override

/// A user-defined location override with metadata
struct LocationOverride: Codable, Sendable {
    /// The overridden location coordinates
    let location: Location

    /// User-provided or geocoded city name
    let cityName: String?

    /// When the override was created
    let createdAt: Date

    /// When the override expires
    let expiresAt: Date

    /// How the override was set
    let source: OverrideSource

    /// Whether this override is still valid
    var isValid: Bool {
        Date() < expiresAt
    }

    /// Time remaining until expiry
    var timeRemaining: TimeInterval {
        max(0, expiresAt.timeIntervalSince(Date()))
    }

    /// Formatted time remaining
    var formattedTimeRemaining: String {
        let hours = Int(timeRemaining / 3600)
        let days = hours / 24

        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            let minutes = Int(timeRemaining / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    /// Source of the override
    enum OverrideSource: String, Codable, Sendable {
        case manualEntry = "manual"
        case mapPin = "map_pin"
        case citySearch = "city_search"
        case addressSearch = "address_search"
    }
}

// MARK: - User Location Override Manager

/// Manages user-defined location overrides when IP geolocation is inaccurate
actor UserLocationOverrideManager {
    static let shared = UserLocationOverrideManager()

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "UserLocationOverride")

    // MARK: - Configuration

    /// Maximum duration for an override (7 days)
    private let maxOverrideDuration: TimeInterval = 86400 * 7

    /// Default duration for an override (24 hours)
    private let defaultOverrideDuration: TimeInterval = 86400

    /// UserDefaults key for persisted override
    private let storageKey = "user_location_override"

    // MARK: - State

    /// Current override (in-memory cache)
    private var cachedOverride: LocationOverride?

    /// Whether we've loaded from disk
    private var isLoaded = false

    private init() {}

    // MARK: - Public API

    /// Get the current valid override, if any
    var currentOverride: LocationOverride? {
        get async {
            await loadIfNeeded()

            guard let override = cachedOverride, override.isValid else {
                // Clear invalid override
                if cachedOverride != nil {
                    await clearOverride(reason: "expired")
                }
                return nil
            }

            return override
        }
    }

    /// Get the current override location, if valid
    var currentLocation: Location? {
        get async {
            await currentOverride?.location
        }
    }

    /// Check if there's an active override
    var hasActiveOverride: Bool {
        get async {
            await currentOverride != nil
        }
    }

    /// Set a manual location override
    ///
    /// - Parameters:
    ///   - location: The location to set
    ///   - cityName: Optional city name for display
    ///   - duration: How long the override should last (default: 24 hours, max: 7 days)
    ///   - source: How the override was created
    func setOverride(
        location: Location,
        cityName: String? = nil,
        duration: TimeInterval? = nil,
        source: LocationOverride.OverrideSource = .manualEntry,
    ) async {
        let effectiveDuration = min(duration ?? defaultOverrideDuration, maxOverrideDuration)

        let override = LocationOverride(
            location: location,
            cityName: cityName,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(effectiveDuration),
            source: source,
        )

        cachedOverride = override
        await persistOverride(override)

        logger.info("Location override set: \(cityName ?? "unknown") for \(Int(effectiveDuration / 3600))h")

        // Record analytics event
        await AppLogger.shared.userAction("location_override_set", details: [
            "latitude": AnyCodable(location.latitude),
            "longitude": AnyCodable(location.longitude),
            "city": AnyCodable(cityName ?? "unknown"),
            "duration_hours": AnyCodable(Int(effectiveDuration / 3600)),
            "source": AnyCodable(source.rawValue)
        ])
    }

    /// Set override from a search result (convenience method)
    func setOverrideFromSearch(
        latitude: Double,
        longitude: Double,
        cityName: String,
    ) async {
        let location = Location(latitude: latitude, longitude: longitude)
        await setOverride(
            location: location,
            cityName: cityName,
            source: .citySearch,
        )
    }

    /// Set override from a map pin drop
    func setOverrideFromMapPin(coordinate: CLLocationCoordinate2D) async {
        let location = Location(coordinate: coordinate)
        await setOverride(
            location: location,
            cityName: nil,
            source: .mapPin,
        )
    }

    /// Clear the current override
    func clearOverride(reason: String = "user_cleared") async {
        cachedOverride = nil
        UserDefaults.standard.removeObject(forKey: storageKey)

        logger.info("Location override cleared: \(reason)")

        await AppLogger.shared.userAction("location_override_cleared", details: [
            "reason": AnyCodable(reason)
        ])
    }

    /// Extend the current override by additional time
    func extendOverride(by additionalTime: TimeInterval) async -> Bool {
        guard let override = cachedOverride, override.isValid else {
            return false
        }

        let newExpiry = min(
            override.expiresAt.addingTimeInterval(additionalTime),
            Date().addingTimeInterval(maxOverrideDuration),
        )

        let extendedOverride = LocationOverride(
            location: override.location,
            cityName: override.cityName,
            createdAt: override.createdAt,
            expiresAt: newExpiry,
            source: override.source,
        )

        cachedOverride = extendedOverride
        await persistOverride(extendedOverride)

        logger.info("Location override extended to \(extendedOverride.formattedTimeRemaining)")
        return true
    }

    // MARK: - Conversion to IPGeolocationResult

    /// Convert current override to an IPGeolocationResult
    func asGeolocationResult() async -> IPGeolocationResult? {
        guard let override = await currentOverride else {
            return nil
        }

        return IPGeolocationResult(
            location: override.location,
            provider: .manual,
            confidence: .medium, // User-set is considered medium confidence
            timestamp: override.createdAt,
            isFromCache: false,
            accuracyRadiusKm: 25.0,
            metadata: GeolocationMetadata.simple(
                city: override.cityName,
                country: nil,
                countryCode: nil,
            ),
            fetchDurationMs: 0,
        )
    }

    // MARK: - Persistence

    private func loadIfNeeded() async {
        guard !isLoaded else { return }
        isLoaded = true

        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            let override = try JSONDecoder().decode(LocationOverride.self, from: data)
            if override.isValid {
                cachedOverride = override
                logger.debug("Loaded persisted location override")
            } else {
                // Clean up expired override
                UserDefaults.standard.removeObject(forKey: storageKey)
                logger.debug("Cleared expired persisted override")
            }
        } catch {
            logger.error("Failed to decode persisted override: \(error.localizedDescription)")
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    private func persistOverride(_ override: LocationOverride) async {
        do {
            let data = try JSONEncoder().encode(override)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to persist override: \(error.localizedDescription)")
        }
    }
}

// MARK: - City Search Support

extension UserLocationOverrideManager {
    /// Common cities for quick selection
    static let commonCities: [(name: String, location: Location)] = [
        ("New York, USA", .newYork),
        ("London, UK", .london),
        ("Sacramento, USA", .sacramento),
        ("Tokyo, Japan", .tokyo),
        ("Paris, France", Location(latitude: 48.8566, longitude: 2.3522)),
        ("Sydney, Australia", Location(latitude: -33.8688, longitude: 151.2093)),
        ("Toronto, Canada", Location(latitude: 43.6532, longitude: -79.3832)),
        ("Berlin, Germany", Location(latitude: 52.5200, longitude: 13.4050)),
        ("Singapore", Location(latitude: 1.3521, longitude: 103.8198)),
        ("Dubai, UAE", Location(latitude: 25.2048, longitude: 55.2708))
    ]

    /// Search for a city using Apple's geocoding
    func searchCity(_ query: String) async -> [(name: String, location: Location)] {
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(query)
            return placemarks.compactMap { placemark -> (String, Location)? in
                guard let location = placemark.location else { return nil }

                let name = [
                    placemark.locality,
                    placemark.administrativeArea,
                    placemark.country
                ]
                .compactMap(\.self)
                .joined(separator: ", ")

                guard !name.isEmpty else { return nil }

                return (name, Location(coordinate: location.coordinate))
            }
        } catch {
            logger.error("City search failed: \(error.localizedDescription)")
            return []
        }
    }
}
