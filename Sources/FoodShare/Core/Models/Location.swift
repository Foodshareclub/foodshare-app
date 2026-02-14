#if !SKIP
import CoreLocation
#endif
import Foundation

// MARK: - Location Error

/// Errors that can occur when working with location services
enum LocationError: LocalizedError, Sendable, Equatable {
    case permissionDenied
    case locationServicesDisabled
    case locationUnavailable
    case timeout
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Location permission denied. Please enable location access in Settings."
        case .locationServicesDisabled:
            "Location services are disabled. Please enable Location Services in Settings > Privacy."
        case .locationUnavailable:
            "Unable to determine your location. Please try again."
        case .timeout:
            "Location request timed out. Please try again."
        case let .unknown(error):
            "Location error: \(error.localizedDescription)"
        }
    }

    static func == (lhs: LocationError, rhs: LocationError) -> Bool {
        switch (lhs, rhs) {
        case (.permissionDenied, .permissionDenied),
             (.locationServicesDisabled, .locationServicesDisabled),
             (.locationUnavailable, .locationUnavailable),
             (.timeout, .timeout):
            true
        case let (.unknown(lhsError), .unknown(rhsError)):
            lhsError.localizedDescription == rhsError.localizedDescription
        default:
            false
        }
    }
}

// MARK: - Location Model

/// Represents a geographic location with coordinates
struct Location: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    /// Initialize from CLLocationCoordinate2D
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Initialize from CLLocationCoordinate2D
    init(coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }

    /// Convert to CLLocationCoordinate2D
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Calculate distance to another location in meters
    func distance(to other: Location) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2)
    }

    /// Calculate distance to another location in kilometers
    func distanceInKilometers(to other: Location) -> Double {
        distance(to: other) / 1000.0
    }

    /// Calculate distance to another location in miles
    func distanceInMiles(to other: Location) -> Double {
        distance(to: other) / 1609.34
    }

    /// Validate that coordinates are valid
    var isValid: Bool {
        latitude >= -90 && latitude <= 90 &&
            longitude >= -180 && longitude <= 180
    }
}

/// Address with location information
struct Address: Codable, Identifiable, Sendable {
    let id: UUID
    let profileId: UUID
    let addressLine1: String?
    let addressLine2: String?
    let city: String?
    let stateProvince: String?
    let postalCode: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case addressLine1 = "address_line1"
        case addressLine2 = "address_line2"
        case city
        case stateProvince = "state_province"
        case postalCode = "postal_code"
        case country
        case latitude
        case longitude
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Location from coordinates (if available)
    var location: Location? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return Location(latitude: lat, longitude: lon)
    }

    /// Full address string
    var formattedAddress: String {
        var components: [String] = []

        if let line1 = addressLine1 { components.append(line1) }
        if let line2 = addressLine2 { components.append(line2) }
        if let city { components.append(city) }
        if let state = stateProvince { components.append(state) }
        if let postal = postalCode { components.append(postal) }
        if let country { components.append(country) }

        return components.joined(separator: ", ")
    }

    /// Short address for display
    var shortAddress: String {
        var components: [String] = []

        if let city { components.append(city) }
        if let state = stateProvince { components.append(state) }

        return components.joined(separator: ", ")
    }
}

// MARK: - Editable Address (for form binding)

/// Editable address for form binding in Edit Profile
struct EditableAddress: Codable, Equatable, Sendable {
    var addressLine1: String
    var addressLine2: String
    var city: String
    var stateProvince: String
    var postalCode: String
    var country: String
    var latitude: Double?
    var longitude: Double?

    /// Empty address for initialization
    static let empty = EditableAddress(
        addressLine1: "",
        addressLine2: "",
        city: "",
        stateProvince: "",
        postalCode: "",
        country: "",
        latitude: nil,
        longitude: nil,
    )

    /// Initialize from existing Address
    init(from address: Address?) {
        self.addressLine1 = address?.addressLine1 ?? ""
        self.addressLine2 = address?.addressLine2 ?? ""
        self.city = address?.city ?? ""
        self.stateProvince = address?.stateProvince ?? ""
        self.postalCode = address?.postalCode ?? ""
        self.country = address?.country ?? ""
        self.latitude = address?.latitude
        self.longitude = address?.longitude
    }

    /// Memberwise initializer
    init(
        addressLine1: String,
        addressLine2: String,
        city: String,
        stateProvince: String,
        postalCode: String,
        country: String,
        latitude: Double?,
        longitude: Double?,
    ) {
        self.addressLine1 = addressLine1
        self.addressLine2 = addressLine2
        self.city = city
        self.stateProvince = stateProvince
        self.postalCode = postalCode
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Whether the address has meaningful content
    var hasContent: Bool {
        !city.isEmpty || !addressLine1.isEmpty
    }

    /// Short formatted address for display
    var formattedShort: String {
        [city, stateProvince].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Full formatted address
    var formattedFull: String {
        [addressLine1, addressLine2, city, stateProvince, postalCode, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Coordinate from latitude/longitude
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Test Fixtures

extension Location {
    /// Create a fixture for testing
    static func fixture(
        latitude: Double = 51.5074,
        longitude: Double = -0.1278,
    ) -> Location {
        Location(latitude: latitude, longitude: longitude)
    }

    /// London, UK
    static let london = Location(latitude: 51.5074, longitude: -0.1278)

    /// New York, USA
    static let newYork = Location(latitude: 40.7128, longitude: -74.0060)

    /// Sacramento, USA
    static let sacramento = Location(latitude: 38.5816, longitude: -121.4944)

    /// Tokyo, Japan
    static let tokyo = Location(latitude: 35.6762, longitude: 139.6503)
}

extension Address {
    /// Create a fixture for testing
    static func fixture(
        id: UUID = UUID(),
        profileId: UUID = UUID(),
        addressLine1: String? = "123 Main Street",
        addressLine2: String? = nil,
        city: String? = "London",
        stateProvince: String? = "Greater London",
        postalCode: String? = "SW1A 1AA",
        country: String? = "United Kingdom",
        latitude: Double? = 51.5074,
        longitude: Double? = -0.1278,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
    ) -> Address {
        Address(
            id: id,
            profileId: profileId,
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            stateProvince: stateProvince,
            postalCode: postalCode,
            country: country,
            latitude: latitude,
            longitude: longitude,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }
}

extension EditableAddress {
    /// Create a fixture for testing
    static func fixture(
        addressLine1: String = "123 Main Street",
        addressLine2: String = "",
        city: String = "Sacramento",
        stateProvince: String = "CA",
        postalCode: String = "95814",
        country: String = "USA",
        latitude: Double? = 38.5816,
        longitude: Double? = -121.4944,
    ) -> EditableAddress {
        EditableAddress(
            addressLine1: addressLine1,
            addressLine2: addressLine2,
            city: city,
            stateProvince: stateProvince,
            postalCode: postalCode,
            country: country,
            latitude: latitude,
            longitude: longitude,
        )
    }
}
