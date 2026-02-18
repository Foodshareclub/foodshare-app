//
//  IPGeolocationResult.swift
//  Foodshare
//
//  Rich result type for IP geolocation with confidence scoring and metadata.
//


#if !SKIP
import Foundation

// MARK: - Location Confidence

/// Confidence level for a geolocation result
///
/// Higher confidence indicates more accurate location data.
/// Used to adjust search radius and UI feedback.
enum LocationConfidence: Int, Comparable, Sendable, Codable, CaseIterable {
    /// ISP-level accuracy only (country/region)
    /// Accuracy radius: ~100km
    case veryLow = 1

    /// City-level accuracy from single provider
    /// Accuracy radius: ~50km
    case low = 2

    /// Multiple providers agree on location
    /// Accuracy radius: ~25km
    case medium = 3

    /// GPS-verified or high-confidence IP location
    /// Accuracy radius: ~10km
    case high = 4

    static func < (lhs: LocationConfidence, rhs: LocationConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Suggested search radius based on confidence level
    var suggestedSearchRadiusKm: Double {
        switch self {
        case .veryLow: 100.0
        case .low: 50.0
        case .medium: 25.0
        case .high: 10.0
        }
    }

    /// Accuracy radius in kilometers
    var accuracyRadiusKm: Double {
        switch self {
        case .veryLow: 100.0
        case .low: 50.0
        case .medium: 25.0
        case .high: 5.0
        }
    }

    /// Cache TTL based on confidence
    var cacheTTL: TimeInterval {
        switch self {
        case .veryLow: 300 // 5 minutes
        case .low: 1800 // 30 minutes
        case .medium: 3600 // 1 hour
        case .high: 7200 // 2 hours
        }
    }

    /// Human-readable description
    var displayName: String {
        switch self {
        case .veryLow: "Very Approximate"
        case .low: "Approximate"
        case .medium: "Good Estimate"
        case .high: "Accurate"
        }
    }

    /// Localized display name using translation service
    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .veryLow: t.t("geolocation.confidence.very_low")
        case .low: t.t("geolocation.confidence.low")
        case .medium: t.t("geolocation.confidence.medium")
        case .high: t.t("geolocation.confidence.high")
        }
    }

    /// Short description for UI
    var shortDescription: String {
        switch self {
        case .veryLow: "~100km accuracy"
        case .low: "~50km accuracy"
        case .medium: "~25km accuracy"
        case .high: "~10km accuracy"
        }
    }

    /// Localized short description using translation service
    @MainActor
    func localizedShortDescription(using t: EnhancedTranslationService) -> String {
        switch self {
        case .veryLow: t.t("geolocation.confidence.accuracy_very_low")
        case .low: t.t("geolocation.confidence.accuracy_low")
        case .medium: t.t("geolocation.confidence.accuracy_medium")
        case .high: t.t("geolocation.confidence.accuracy_high")
        }
    }
}

// MARK: - Geolocation Metadata

/// Rich metadata about the geolocated position
struct GeolocationMetadata: Sendable, Codable, Equatable {
    /// City name (if available)
    let city: String?

    /// Region/state/province name
    let region: String?

    /// Country name
    let country: String?

    /// ISO country code (e.g., "US", "GB")
    let countryCode: String?

    /// Timezone identifier (e.g., "America/Los_Angeles")
    let timezone: String?

    /// Internet Service Provider name
    let isp: String?

    /// Whether a VPN or proxy was detected
    let isVPN: Bool?

    /// Whether this is a GDPR region (EU/EEA)
    var isGDPRRegion: Bool {
        let gdprCountries = [
            "AT", "BE", "BG", "HR", "CY", "CZ", "DK", "EE", "FI",
            "FR", "DE", "GR", "HU", "IE", "IT", "LV", "LT", "LU",
            "MT", "NL", "PL", "PT", "RO", "SK", "SI", "ES", "SE",
            "IS", "LI", "NO", "GB"
        ]
        return gdprCountries.contains(countryCode ?? "")
    }

    /// Formatted location string for display
    var formattedLocation: String {
        var components: [String] = []
        if let city { components.append(city) }
        if let region { components.append(region) }
        if let country { components.append(country) }

        if components.isEmpty {
            return "Unknown Location"
        }
        return components.joined(separator: ", ")
    }

    /// Short location string (city, country)
    var shortLocation: String {
        var components: [String] = []
        if let city { components.append(city) }
        if let countryCode { components.append(countryCode) }

        if components.isEmpty {
            return "Unknown"
        }
        return components.joined(separator: ", ")
    }

    /// Empty metadata
    static let empty = GeolocationMetadata(
        city: nil,
        region: nil,
        country: nil,
        countryCode: nil,
        timezone: nil,
        isp: nil,
        isVPN: nil,
    )

    /// Create metadata with just city and country
    static func simple(city: String?, country: String?, countryCode: String?) -> GeolocationMetadata {
        GeolocationMetadata(
            city: city,
            region: nil,
            country: country,
            countryCode: countryCode,
            timezone: nil,
            isp: nil,
            isVPN: nil,
        )
    }
}

// MARK: - IP Geolocation Result

/// Complete result from IP geolocation with location, confidence, and metadata
struct IPGeolocationResult: Sendable, Equatable {
    /// The resolved geographic location
    let location: Location

    /// The provider that returned this result
    let provider: IPGeolocationProvider

    /// Confidence level of the result
    let confidence: LocationConfidence

    /// When this result was obtained
    let timestamp: Date

    /// Whether this result came from cache
    let isFromCache: Bool

    /// Estimated accuracy radius in kilometers
    let accuracyRadiusKm: Double

    /// Rich metadata about the location
    let metadata: GeolocationMetadata

    /// Time taken to fetch this result (0 for cached results)
    let fetchDurationMs: Int

    // MARK: - Initialization

    init(
        location: Location,
        provider: IPGeolocationProvider,
        confidence: LocationConfidence,
        timestamp: Date = Date(),
        isFromCache: Bool = false,
        accuracyRadiusKm: Double? = nil,
        metadata: GeolocationMetadata = .empty,
        fetchDurationMs: Int = 0,
    ) {
        self.location = location
        self.provider = provider
        self.confidence = confidence
        self.timestamp = timestamp
        self.isFromCache = isFromCache
        self.accuracyRadiusKm = accuracyRadiusKm ?? confidence.accuracyRadiusKm
        self.metadata = metadata
        self.fetchDurationMs = fetchDurationMs
    }

    // MARK: - Computed Properties

    /// Age of this result
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }

    /// Whether this result is still valid based on confidence-based TTL
    var isValid: Bool {
        age < confidence.cacheTTL
    }

    /// Suggested search radius for this result
    var suggestedSearchRadiusKm: Double {
        confidence.suggestedSearchRadiusKm
    }

    /// Human-readable source description
    var sourceDescription: String {
        if isFromCache {
            return "Cached (\(provider.displayName))"
        }
        return provider.displayName
    }

    /// Display text for UI
    var displayText: String {
        let prefix = confidence.displayName
        if let city = metadata.city {
            return "\(prefix) (\(city))"
        }
        return prefix
    }

    // MARK: - Equatable

    static func == (lhs: IPGeolocationResult, rhs: IPGeolocationResult) -> Bool {
        lhs.location == rhs.location &&
            lhs.provider == rhs.provider &&
            lhs.confidence == rhs.confidence &&
            lhs.timestamp == rhs.timestamp &&
            lhs.isFromCache == rhs.isFromCache
    }
}

// MARK: - Confidence Calculation

extension IPGeolocationResult {
    /// Calculate confidence based on provider agreement
    ///
    /// - Parameters:
    ///   - primaryResult: The primary result to evaluate
    ///   - verificationResults: Additional results from other providers
    ///   - agreementThresholdKm: Maximum distance for results to be considered "agreeing"
    /// - Returns: Updated confidence level
    static func calculateConfidence(
        for primaryResult: IPGeolocationResult,
        verifiedBy verificationResults: [IPGeolocationResult],
        agreementThresholdKm: Double = 50.0,
    ) -> LocationConfidence {
        // Count how many providers agree (within threshold)
        var agreementCount = 0
        for other in verificationResults where other.provider != primaryResult.provider {
            let distance = primaryResult.location.distanceInKilometers(to: other.location)
            if distance < agreementThresholdKm {
                agreementCount += 1
            }
        }

        let hasMetadata = primaryResult.metadata.city != nil

        if hasMetadata {
            if agreementCount >= 2 {
                return .high
            } else if agreementCount >= 1 {
                return .medium
            } else {
                return .low
            }
        } else {
            return .veryLow
        }
    }

    /// Create an upgraded result with higher confidence
    func withConfidence(_ newConfidence: LocationConfidence) -> IPGeolocationResult {
        IPGeolocationResult(
            location: location,
            provider: provider,
            confidence: newConfidence,
            timestamp: timestamp,
            isFromCache: isFromCache,
            accuracyRadiusKm: newConfidence.accuracyRadiusKm,
            metadata: metadata,
            fetchDurationMs: fetchDurationMs,
        )
    }

    /// Create a cached version of this result
    func asCached() -> IPGeolocationResult {
        IPGeolocationResult(
            location: location,
            provider: provider,
            confidence: confidence,
            timestamp: timestamp,
            isFromCache: true,
            accuracyRadiusKm: accuracyRadiusKm,
            metadata: metadata,
            fetchDurationMs: 0,
        )
    }
}

// MARK: - Test Fixtures

extension IPGeolocationResult {
    /// Create a fixture for testing
    static func fixture(
        location: Location = .london,
        provider: IPGeolocationProvider = .ipwhois,
        confidence: LocationConfidence = .medium,
        city: String? = "London",
        country: String? = "United Kingdom",
        countryCode: String? = "GB",
    ) -> IPGeolocationResult {
        IPGeolocationResult(
            location: location,
            provider: provider,
            confidence: confidence,
            timestamp: Date(),
            isFromCache: false,
            accuracyRadiusKm: confidence.accuracyRadiusKm,
            metadata: .simple(city: city, country: country, countryCode: countryCode),
            fetchDurationMs: 150,
        )
    }

    /// High confidence Sacramento result (for testing)
    static let sacramento = IPGeolocationResult.fixture(
        location: .sacramento,
        provider: .ipinfo,
        confidence: .high,
        city: "Sacramento",
        country: "United States",
        countryCode: "US",
    )

    /// Low confidence result (for testing)
    static let lowConfidence = IPGeolocationResult.fixture(
        location: .newYork,
        provider: .ipdata,
        confidence: .low,
        city: nil,
        country: "United States",
        countryCode: "US",
    )
}

#endif
