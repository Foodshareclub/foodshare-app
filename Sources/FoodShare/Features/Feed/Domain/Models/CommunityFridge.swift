//
//  CommunityFridge.swift
//  Foodshare
//
//  Community fridge model - Maps to `community_fridges` table in Supabase
//  Key differentiator feature for Foodshare
//



#if !SKIP
import CoreLocation
import Foundation

/// Represents a community fridge location
/// Maps to `community_fridges` table in Supabase (47 rows)
struct CommunityFridge: Identifiable, Sendable, Hashable {
    // MARK: - Identity

    let id: UUID // UUID primary key

    // MARK: - Basic Info

    let name: String // fridge name
    let status: FridgeStatus // Active, Inactive, Pending
    let description: String? // description

    // MARK: - Location

    let streetAddress: String? // street_address
    let city: String? // city
    let state: String? // state
    let zipCode: String? // zip_code
    let fullAddress: String? // full_address
    let latitude: Double? // latitude
    let longitude: Double? // longitude
    let referenceDirections: String? // reference_directions
    let locationType: String? // location_type (church, storefront, etc.)

    // MARK: - Host Info

    let hostCompany: String? // host_company
    let companyType: String? // company_type
    let pointPersonName: String? // point_person_name
    let pointPersonEmail: String? // point_person_email

    // MARK: - Operations

    let availableHours: String? // available_hours
    let hasPantry: Bool // has_pantry
    let languages: [String]? // languages array

    // MARK: - Status Tracking

    let latestFoodStatus: String? // latest_food_status
    let latestCleanlinessStatus: String? // latest_cleanliness_status
    let totalCheckIns: Int // total_check_ins
    let lastCheckIn: Date? // last_check_in
    let statusLastUpdated: Date? // status_last_updated

    // MARK: - Dates

    let launchDate: Date? // launch_date
    let createdDate: Date? // created_date
    let ageYears: Double? // age_years

    // MARK: - Links

    let checkInLink: String? // check_in_link
    let slackChannelId: String? // slack_channel_id
    let slackChannelLink: String? // slack_channel_link
    let photoUrl: String? // photo_url
    let qrCodeUrl: String? // qr_code_url

    // MARK: - Timestamps

    let createdAt: Date // created_at
    let updatedAt: Date // updated_at

    // MARK: - Distance (from RPC function)

    let distanceMeters: Double? // distance_meters (calculated by PostGIS)

    // MARK: - Computed Properties

    /// Distance in kilometers
    var distanceKm: Double? {
        guard let distanceMeters else { return nil }
        return distanceMeters / 1000.0
    }

    /// Formatted distance string
    var distanceDisplay: String? {
        guard let distanceMeters else { return nil }
        if distanceMeters < 1000 {
            return "\(Int(distanceMeters))m"
        } else {
            return String(format: "%.1fkm", distanceMeters / 1000.0)
        }
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: Location? {
        guard let latitude, let longitude else { return nil }
        return Location(latitude: latitude, longitude: longitude)
    }

    var displayAddress: String {
        fullAddress ?? [streetAddress, city, state, zipCode]
            .compactMap(\.self)
            .joined(separator: ", ")
    }

    var foodStatusEnum: FridgeFoodStatus? {
        guard let latestFoodStatus else { return nil }
        return FridgeFoodStatus(rawValue: latestFoodStatus)
    }

    var isActive: Bool {
        status == .active
    }

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id, name, status, description
        case streetAddress = "street_address"
        case city, state
        case zipCode = "zip_code"
        case fullAddress = "full_address"
        case latitude, longitude
        case referenceDirections = "reference_directions"
        case locationType = "location_type"
        case hostCompany = "host_company"
        case companyType = "company_type"
        case pointPersonName = "point_person_name"
        case pointPersonEmail = "point_person_email"
        case availableHours = "available_hours"
        case hasPantry = "has_pantry"
        case languages
        case latestFoodStatus = "latest_food_status"
        case latestCleanlinessStatus = "latest_cleanliness_status"
        case totalCheckIns = "total_check_ins"
        case lastCheckIn = "last_check_in"
        case statusLastUpdated = "status_last_updated"
        case launchDate = "launch_date"
        case createdDate = "created_date"
        case ageYears = "age_years"
        case checkInLink = "check_in_link"
        case slackChannelId = "slack_channel_id"
        case slackChannelLink = "slack_channel_link"
        case photoUrl = "photo_url"
        case qrCodeUrl = "qr_code_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case distanceMeters = "distance_meters"
    }
}

// MARK: - Codable Conformance

extension CommunityFridge: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)

        // Status with fallback to .active if missing or invalid
        if let statusString = try container.decodeIfPresent(String.self, forKey: .status),
           let decodedStatus = FridgeStatus(rawValue: statusString)
        {
            status = decodedStatus
        } else {
            status = .active
        }

        description = try container.decodeIfPresent(String.self, forKey: .description)
        streetAddress = try container.decodeIfPresent(String.self, forKey: .streetAddress)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        zipCode = try container.decodeIfPresent(String.self, forKey: .zipCode)
        fullAddress = try container.decodeIfPresent(String.self, forKey: .fullAddress)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        referenceDirections = try container.decodeIfPresent(String.self, forKey: .referenceDirections)
        locationType = try container.decodeIfPresent(String.self, forKey: .locationType)
        hostCompany = try container.decodeIfPresent(String.self, forKey: .hostCompany)
        companyType = try container.decodeIfPresent(String.self, forKey: .companyType)
        pointPersonName = try container.decodeIfPresent(String.self, forKey: .pointPersonName)
        pointPersonEmail = try container.decodeIfPresent(String.self, forKey: .pointPersonEmail)
        availableHours = try container.decodeIfPresent(String.self, forKey: .availableHours)

        // hasPantry with default false
        hasPantry = try container.decodeIfPresent(Bool.self, forKey: .hasPantry) ?? false

        languages = try container.decodeIfPresent([String].self, forKey: .languages)
        latestFoodStatus = try container.decodeIfPresent(String.self, forKey: .latestFoodStatus)
        latestCleanlinessStatus = try container.decodeIfPresent(String.self, forKey: .latestCleanlinessStatus)

        // totalCheckIns with default 0
        totalCheckIns = try container.decodeIfPresent(Int.self, forKey: .totalCheckIns) ?? 0

        lastCheckIn = try container.decodeIfPresent(Date.self, forKey: .lastCheckIn)
        statusLastUpdated = try container.decodeIfPresent(Date.self, forKey: .statusLastUpdated)
        launchDate = try container.decodeIfPresent(Date.self, forKey: .launchDate)
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate)
        ageYears = try container.decodeIfPresent(Double.self, forKey: .ageYears)
        checkInLink = try container.decodeIfPresent(String.self, forKey: .checkInLink)
        slackChannelId = try container.decodeIfPresent(String.self, forKey: .slackChannelId)
        slackChannelLink = try container.decodeIfPresent(String.self, forKey: .slackChannelLink)
        photoUrl = try container.decodeIfPresent(String.self, forKey: .photoUrl)
        qrCodeUrl = try container.decodeIfPresent(String.self, forKey: .qrCodeUrl)

        // Timestamps with default to now
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()

        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
    }
}

// MARK: - Fridge Status

enum FridgeStatus: String, Codable, Sendable, CaseIterable {
    case active = "Active"
    case inactive = "Inactive"
    case pending = "Pending"

    var displayName: String {
        rawValue
    }

    var color: String {
        switch self {
        case .active: "#2ECC71" // Green
        case .inactive: "#E74C3C" // Red
        case .pending: "#F39C12" // Orange
        }
    }

    var icon: String {
        switch self {
        case .active: "checkmark.circle.fill"
        case .inactive: "xmark.circle.fill"
        case .pending: "clock.fill"
        }
    }
}

// MARK: - FoodItem Adapter

extension CommunityFridge {
    /// Initialize a CommunityFridge from a FoodItem (post_type='fridge') with metadata
    /// Used after migration from community_fridges table to posts table
    init(from foodItem: FoodItem) {
        let meta = foodItem.metadata

        // Identity — use fridge_id (original UUID) or generate one
        id = foodItem.fridgeId.flatMap { UUID(uuidString: $0) } ?? UUID()

        // Basic info
        name = foodItem.title
        description = foodItem.postDescription

        // Status from metadata, falling back to is_active
        if let statusStr = meta?["status"]?.stringValue,
           let parsed = FridgeStatus(rawValue: statusStr)
        {
            status = parsed
        } else {
            status = foodItem.isActive ? .active : .inactive
        }

        // Location
        streetAddress = meta?["street_address"]?.stringValue
        city = meta?["city"]?.stringValue
        state = meta?["state"]?.stringValue
        zipCode = meta?["zip_code"]?.stringValue
        fullAddress = foodItem.postAddress
        latitude = foodItem.latitude
        longitude = foodItem.longitude
        referenceDirections = meta?["reference_directions"]?.stringValue
        locationType = foodItem.locationType

        // Host info
        hostCompany = meta?["host_company"]?.stringValue
        companyType = meta?["company_type"]?.stringValue
        pointPersonName = meta?["point_person_name"]?.stringValue
        pointPersonEmail = meta?["point_person_email"]?.stringValue

        // Operations
        availableHours = foodItem.availableHours
        hasPantry = foodItem.hasPantry ?? false
        languages = meta?["languages"]?.stringArrayValue

        // Status tracking
        latestFoodStatus = meta?["latest_food_status"]?.stringValue ?? foodItem.foodStatus
        latestCleanlinessStatus = meta?["latest_cleanliness_status"]?.stringValue
        totalCheckIns = meta?["total_check_ins"]?.intValue ?? 0
        lastCheckIn = meta?["last_check_in"]?.stringValue.flatMap { ISO8601DateFormatter().date(from: $0) }
        statusLastUpdated = meta?["status_last_updated"]?.stringValue.flatMap { ISO8601DateFormatter().date(from: $0) }

        // Dates
        launchDate = meta?["launch_date"]?.stringValue.flatMap { ISO8601DateFormatter().date(from: $0) }
        createdDate = meta?["created_date"]?.stringValue.flatMap { ISO8601DateFormatter().date(from: $0) }
        ageYears = meta?["age_years"]?.doubleValue

        // Links
        checkInLink = meta?["check_in_link"]?.stringValue
        slackChannelId = meta?["slack_channel_id"]?.stringValue
        slackChannelLink = meta?["slack_channel_link"]?.stringValue
        photoUrl = foodItem.images?.first
        qrCodeUrl = meta?["qr_code_url"]?.stringValue

        // Timestamps
        createdAt = foodItem.createdAt
        updatedAt = foodItem.updatedAt

        // Distance
        distanceMeters = foodItem.distanceMeters
    }
}

// MARK: - Test Fixtures

#if DEBUG

    extension CommunityFridge {
        static func fixture(
            id: UUID = UUID(),
            name: String = "Community Fridge SF",
            status: FridgeStatus = .active,
            description: String? = "A community fridge serving the Mission District",
            streetAddress: String? = "123 Valencia St",
            city: String? = "Sacramento",
            state: String? = "CA",
            zipCode: String? = "94110",
            latitude: Double? = 37.7599,
            longitude: Double? = -122.4148,
            availableHours: String? = "24/7",
            hasPantry: Bool = true,
            latestFoodStatus: String? = "room for more",
            totalCheckIns: Int = 42,
        ) -> CommunityFridge {
            CommunityFridge(
                id: id,
                name: name,
                status: status,
                description: description,
                streetAddress: streetAddress,
                city: city,
                state: state,
                zipCode: zipCode,
                fullAddress: "\(streetAddress ?? ""), \(city ?? ""), \(state ?? "") \(zipCode ?? "")",
                latitude: latitude,
                longitude: longitude,
                referenceDirections: nil,
                locationType: "storefront",
                hostCompany: nil,
                companyType: nil,
                pointPersonName: nil,
                pointPersonEmail: nil,
                availableHours: availableHours,
                hasPantry: hasPantry,
                languages: ["English", "Spanish"],
                latestFoodStatus: latestFoodStatus,
                latestCleanlinessStatus: "clean",
                totalCheckIns: totalCheckIns,
                lastCheckIn: Date(),
                statusLastUpdated: Date(),
                launchDate: Date().addingTimeInterval(-365 * 24 * 60 * 60),
                createdDate: Date().addingTimeInterval(-365 * 24 * 60 * 60),
                ageYears: 1.0,
                checkInLink: nil,
                slackChannelId: nil,
                slackChannelLink: nil,
                photoUrl: "https://example.com/fridge.jpg",
                qrCodeUrl: nil,
                createdAt: Date(),
                updatedAt: Date(),
                distanceMeters: 2500.0,
            )
        }

        static let sampleFridges: [CommunityFridge] = [
            .fixture(id: UUID(), name: "Mission Fridge", city: "Sacramento"),
            .fixture(
                id: UUID(),
                name: "Oakland Community Fridge",
                city: "Oakland",
                latitude: 37.8044,
                longitude: -122.2712,
            ),
            .fixture(id: UUID(), name: "Berkeley Fridge", city: "Berkeley", latitude: 37.8716, longitude: -122.2727),
        ]
    }


#endif

#endif
