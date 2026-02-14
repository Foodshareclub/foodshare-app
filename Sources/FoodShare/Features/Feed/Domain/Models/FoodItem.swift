//
//  FoodItem.swift
//  Foodshare
//
//  Food item domain model - Maps to `posts` table in Supabase
//  Updated to match actual database schema (December 2025)
//

#if !SKIP
import CoreLocation
#endif
import Foundation

/// Represents a food listing in the system
/// Maps to `posts` table in Supabase (cross-platform with web app)
struct FoodItem: Codable, Identifiable, Sendable, Hashable {
    // MARK: - Identity

    let id: Int // bigint in database

    // MARK: - Ownership

    let profileId: UUID? // profile_id (FK to profiles) - optional for legacy data

    // MARK: - Content

    let postName: String // post_name (title)
    let postDescription: String? // post_description
    let postType: String // post_type: 'food', 'fridge', 'foodbank', 'thing', 'volunteer'

    // MARK: - Timing

    let pickupTime: String? // pickup_time
    let availableHours: String? // available_hours for fridges/foodbanks

    // MARK: - Location (PostGIS geography)

    let postAddress: String? // post_address (full address)
    let postStrippedAddress: String? // post_stripped_address (privacy-friendly, no street number)
    let latitude: Double? // extracted from location geography
    let longitude: Double? // extracted from location geography

    // MARK: - Media (text[] array)

    let images: [String]? // images text[] array

    // MARK: - Status

    var isActive: Bool // is_active (renamed from 'active')
    var isArranged: Bool // is_arranged (renamed from 'post_arranged')
    var postArrangedTo: UUID? // post_arranged_to (user who arranged)
    var postArrangedAt: Date? // post_arranged_at (when arranged)

    // MARK: - Analytics

    var postViews: Int // post_views
    var postLikeCounter: Int? // post_like_counter

    // MARK: - Fridge/Foodbank Specific

    let hasPantry: Bool? // has_pantry
    let foodStatus: String? // food_status: 'nearly empty', 'room for more', 'pretty full', 'overflowing'
    let network: String? // network (fridge/foodbank networks)
    let website: String? // website URL
    let donation: String? // donation info
    let donationRules: String? // donation_rules
    let fridgeId: String? // fridge_id (cross-reference to community_fridges)
    let locationType: String? // location_type (church, storefront, etc.)
    let metadata: [String: AnyCodable]? // metadata JSONB (fridge-specific fields)

    // MARK: - Category

    let categoryId: Int? // category_id (FK to categories)

    // MARK: - Timestamps

    let createdAt: Date // created_at
    let updatedAt: Date // updated_at

    // MARK: - Distance (from RPC function)

    let distanceMeters: Double? // distance_meters (calculated by PostGIS)

    // MARK: - Translation Fields (from BFF)

    /// Pre-translated title (populated when locale != "en")
    var titleTranslated: String?
    /// Pre-translated description (populated when locale != "en")
    var descriptionTranslated: String?
    /// The locale of the translation (e.g., "ru", "de", "es")
    var translationLocale: String?

    // MARK: - Computed Properties

    /// Indicates if listing is available for claim
    var isAvailable: Bool {
        isActive && !isArranged
    }

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

    /// Display title - uses translated version if available
    var title: String {
        titleTranslated ?? postName
    }

    /// Display description - uses translated version if available
    var description: String? {
        descriptionTranslated ?? postDescription
    }

    /// Whether this item has been translated
    var isTranslated: Bool {
        titleTranslated != nil || descriptionTranslated != nil
    }

    /// Original title (always English)
    var originalTitle: String {
        postName
    }

    /// Original description (always English)
    var originalDescription: String? {
        postDescription
    }

    /// Location as coordinate
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Location as Location struct
    var location: Location? {
        guard let latitude, let longitude else { return nil }
        return Location(latitude: latitude, longitude: longitude)
    }

    /// Display address (uses stripped address for privacy, falls back to full address)
    var displayAddress: String? {
        postStrippedAddress ?? postAddress
    }

    /// Primary image URL for display
    var displayImageUrl: String? {
        images?.first
    }

    /// Alias for displayImageUrl (backward compatibility)
    var primaryImageUrl: String? {
        displayImageUrl
    }

    /// All image URLs as URL objects
    var imageURLs: [URL] {
        (images ?? []).compactMap { URL(string: $0) }
    }

    /// Status for display
    var status: FoodItemStatus {
        if !isActive {
            .inactive
        } else if isArranged {
            .arranged
        } else {
            .available
        }
    }

    /// Human-readable food status for fridges
    var foodStatusDisplay: String? {
        foodStatus?.replacingOccurrences(of: "_", with: " ").capitalized
    }

    // MARK: - CodingKeys

    // CodingKeys: No explicit snake_case mappings needed - BaseSupabaseRepository
    // decoder uses .convertFromSnakeCase which handles the conversion automatically
    enum CodingKeys: String, CodingKey {
        case id
        case profileId
        case postName
        case postDescription
        case postType
        case pickupTime
        case availableHours
        case postAddress
        case postStrippedAddress
        case latitude, longitude
        case images
        case isActive
        case isArranged
        case postArrangedTo
        case postArrangedAt
        case postViews
        case postLikeCounter
        case hasPantry
        case foodStatus
        case condition // From direct query (fallback)
        case network, website, donation
        case donationRules
        case fridgeId
        case locationType
        case metadata
        case categoryId
        case createdAt
        case updatedAt
        case distanceMeters
        // Translation fields from BFF
        case titleTranslated
        case descriptionTranslated
        case translationLocale
    }

    // MARK: - Custom Decoding

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(Int.self, forKey: .id)
        profileId = try container.decodeIfPresent(UUID.self, forKey: .profileId)
        postName = try container.decodeIfPresent(String.self, forKey: .postName) ?? "Untitled"
        postDescription = try container.decodeIfPresent(String.self, forKey: .postDescription)
        postType = try container.decodeIfPresent(String.self, forKey: .postType) ?? "food"
        pickupTime = try container.decodeIfPresent(String.self, forKey: .pickupTime)
        availableHours = try container.decodeIfPresent(String.self, forKey: .availableHours)
        postAddress = try container.decodeIfPresent(String.self, forKey: .postAddress)
        postStrippedAddress = try container.decodeIfPresent(String.self, forKey: .postStrippedAddress)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        images = try container.decodeIfPresent([String].self, forKey: .images)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        isArranged = try container.decodeIfPresent(Bool.self, forKey: .isArranged) ?? false
        postArrangedTo = try container.decodeIfPresent(UUID.self, forKey: .postArrangedTo)
        postArrangedAt = try container.decodeIfPresent(Date.self, forKey: .postArrangedAt)
        postViews = try container.decodeIfPresent(Int.self, forKey: .postViews) ?? 0
        postLikeCounter = try container.decodeIfPresent(Int.self, forKey: .postLikeCounter)
        hasPantry = try container.decodeIfPresent(Bool.self, forKey: .hasPantry)
        // Try food_status first (from RPC), fall back to condition (from direct query)
        foodStatus = try container.decodeIfPresent(String.self, forKey: .foodStatus)
            ?? container.decodeIfPresent(String.self, forKey: .condition)
        network = try container.decodeIfPresent(String.self, forKey: .network)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        donation = try container.decodeIfPresent(String.self, forKey: .donation)
        donationRules = try container.decodeIfPresent(String.self, forKey: .donationRules)
        fridgeId = try container.decodeIfPresent(String.self, forKey: .fridgeId)
        locationType = try container.decodeIfPresent(String.self, forKey: .locationType)
        metadata = try container.decodeIfPresent([String: AnyCodable].self, forKey: .metadata)
        categoryId = try container.decodeIfPresent(Int.self, forKey: .categoryId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        distanceMeters = try container.decodeIfPresent(Double.self, forKey: .distanceMeters)
        // Translation fields from BFF
        titleTranslated = try container.decodeIfPresent(String.self, forKey: .titleTranslated)
        descriptionTranslated = try container.decodeIfPresent(String.self, forKey: .descriptionTranslated)
        translationLocale = try container.decodeIfPresent(String.self, forKey: .translationLocale)
    }

    // MARK: - Memberwise Init (for fixtures and tests)

    init(
        id: Int,
        profileId: UUID?,
        postName: String,
        postDescription: String?,
        postType: String,
        pickupTime: String?,
        availableHours: String?,
        postAddress: String?,
        postStrippedAddress: String?,
        latitude: Double?,
        longitude: Double?,
        images: [String]?,
        isActive: Bool,
        isArranged: Bool,
        postArrangedTo: UUID?,
        postArrangedAt: Date?,
        postViews: Int,
        postLikeCounter: Int?,
        hasPantry: Bool?,
        foodStatus: String?,
        network: String?,
        website: String?,
        donation: String?,
        donationRules: String?,
        fridgeId: String? = nil,
        locationType: String? = nil,
        metadata: [String: AnyCodable]? = nil,
        categoryId: Int?,
        createdAt: Date,
        updatedAt: Date,
        distanceMeters: Double?,
        titleTranslated: String? = nil,
        descriptionTranslated: String? = nil,
        translationLocale: String? = nil,
    ) {
        self.id = id
        self.profileId = profileId
        self.postName = postName
        self.postDescription = postDescription
        self.postType = postType
        self.pickupTime = pickupTime
        self.availableHours = availableHours
        self.postAddress = postAddress
        self.postStrippedAddress = postStrippedAddress
        self.latitude = latitude
        self.longitude = longitude
        self.images = images
        self.isActive = isActive
        self.isArranged = isArranged
        self.postArrangedTo = postArrangedTo
        self.postArrangedAt = postArrangedAt
        self.postViews = postViews
        self.postLikeCounter = postLikeCounter
        self.hasPantry = hasPantry
        self.foodStatus = foodStatus
        self.network = network
        self.website = website
        self.donation = donation
        self.donationRules = donationRules
        self.fridgeId = fridgeId
        self.locationType = locationType
        self.metadata = metadata
        self.categoryId = categoryId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.distanceMeters = distanceMeters
        self.titleTranslated = titleTranslated
        self.descriptionTranslated = descriptionTranslated
        self.translationLocale = translationLocale
    }

    // MARK: - Hashable & Equatable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FoodItem, rhs: FoodItem) -> Bool {
        lhs.id == rhs.id && lhs.updatedAt == rhs.updatedAt
    }

    // MARK: - Encoding (uses food_status key for consistency)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(profileId, forKey: .profileId)
        try container.encode(postName, forKey: .postName)
        try container.encodeIfPresent(postDescription, forKey: .postDescription)
        try container.encode(postType, forKey: .postType)
        try container.encodeIfPresent(pickupTime, forKey: .pickupTime)
        try container.encodeIfPresent(availableHours, forKey: .availableHours)
        try container.encodeIfPresent(postAddress, forKey: .postAddress)
        try container.encodeIfPresent(postStrippedAddress, forKey: .postStrippedAddress)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(isArranged, forKey: .isArranged)
        try container.encodeIfPresent(postArrangedTo, forKey: .postArrangedTo)
        try container.encodeIfPresent(postArrangedAt, forKey: .postArrangedAt)
        try container.encode(postViews, forKey: .postViews)
        try container.encodeIfPresent(postLikeCounter, forKey: .postLikeCounter)
        try container.encodeIfPresent(hasPantry, forKey: .hasPantry)
        try container.encodeIfPresent(foodStatus, forKey: .foodStatus)
        try container.encodeIfPresent(network, forKey: .network)
        try container.encodeIfPresent(website, forKey: .website)
        try container.encodeIfPresent(donation, forKey: .donation)
        try container.encodeIfPresent(donationRules, forKey: .donationRules)
        try container.encodeIfPresent(fridgeId, forKey: .fridgeId)
        try container.encodeIfPresent(locationType, forKey: .locationType)
        try container.encodeIfPresent(metadata, forKey: .metadata)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(distanceMeters, forKey: .distanceMeters)
        // Translation fields
        try container.encodeIfPresent(titleTranslated, forKey: .titleTranslated)
        try container.encodeIfPresent(descriptionTranslated, forKey: .descriptionTranslated)
        try container.encodeIfPresent(translationLocale, forKey: .translationLocale)
    }
}

// MARK: - Food Item Status

/// Represents the current state of a food listing
/// Derived from `is_active` and `is_arranged` fields
enum FoodItemStatus: String, Codable, Sendable, CaseIterable {
    case available // is_active=true, is_arranged=false
    case arranged // is_active=true, is_arranged=true
    case inactive // is_active=false

    /// User-friendly display name
    var displayName: String {
        switch self {
        case .available: "Available"
        case .arranged: "Arranged"
        case .inactive: "Inactive"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .available: t.t("listing.status.available")
        case .arranged: t.t("listing.status.arranged")
        case .inactive: t.t("listing.status.inactive")
        }
    }

    /// Indicates if listing can be claimed
    var isClaimable: Bool {
        self == .available
    }

    /// Color for status badge
    var color: String {
        switch self {
        case .available: "#2ECC71" // Green
        case .arranged: "#F39C12" // Orange
        case .inactive: "#95A5A6" // Gray
        }
    }
}

// MARK: - Post Type

/// Types of posts in the system (matches web app listing types)
enum PostType: String, Codable, Sendable, CaseIterable {
    case food
    case thing
    case borrow
    case wanted
    case fridge
    case foodbank
    case business
    case volunteer
    case challenge
    case zerowaste
    case vegan
    case community

    var displayName: String {
        switch self {
        case .food: "Food"
        case .thing: "Non-Food Item"
        case .borrow: "Borrow"
        case .wanted: "Wanted"
        case .fridge: "Community Fridge"
        case .foodbank: "Food Bank"
        case .business: "Business"
        case .volunteer: "Volunteer"
        case .challenge: "Challenge"
        case .zerowaste: "Zero Waste"
        case .vegan: "Vegan"
        case .community: "Community Event"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .food: t.t("post_type.food")
        case .thing: t.t("post_type.thing")
        case .borrow: t.t("post_type.borrow")
        case .wanted: t.t("post_type.wanted")
        case .fridge: t.t("post_type.fridge")
        case .foodbank: t.t("post_type.foodbank")
        case .business: t.t("post_type.business")
        case .volunteer: t.t("post_type.volunteer")
        case .challenge: t.t("post_type.challenge")
        case .zerowaste: t.t("post_type.zerowaste")
        case .vegan: t.t("post_type.vegan")
        case .community: t.t("post_type.community")
        }
    }

    var icon: String {
        switch self {
        case .food: "leaf.fill"
        case .thing: "shippingbox.fill"
        case .borrow: "arrow.triangle.2.circlepath"
        case .wanted: "magnifyingglass"
        case .fridge: "refrigerator.fill"
        case .foodbank: "building.2.fill"
        case .business: "storefront.fill"
        case .volunteer: "person.2.fill"
        case .challenge: "trophy.fill"
        case .zerowaste: "arrow.3.trianglepath"
        case .vegan: "carrot.fill"
        case .community: "person.3.fill"
        }
    }
}

// MARK: - Food Status (for Fridges)

/// Food level status for community fridges
enum FridgeFoodStatus: String, Codable, Sendable, CaseIterable {
    case nearlyEmpty = "nearly empty"
    case roomForMore = "room for more"
    case prettyFull = "pretty full"
    case overflowing

    var displayName: String {
        rawValue.capitalized
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .nearlyEmpty: t.t("fridge_status.nearly_empty")
        case .roomForMore: t.t("fridge_status.room_for_more")
        case .prettyFull: t.t("fridge_status.pretty_full")
        case .overflowing: t.t("fridge_status.overflowing")
        }
    }

    var icon: String {
        switch self {
        case .nearlyEmpty: "battery.0percent"
        case .roomForMore: "battery.50percent"
        case .prettyFull: "battery.75percent"
        case .overflowing: "battery.100percent"
        }
    }

    var color: String {
        switch self {
        case .nearlyEmpty: "#E74C3C" // Red
        case .roomForMore: "#F39C12" // Orange
        case .prettyFull: "#2ECC71" // Green
        case .overflowing: "#3498DB" // Blue
        }
    }
}

// MARK: - Test Fixtures

#if DEBUG

    extension FoodItem {
        /// Test fixture for FoodItem
        static func fixture(
            id: Int = 1,
            profileId: UUID = UUID(),
            postName: String = "Fresh Apples",
            postDescription: String? = "Delicious organic apples from my garden",
            postType: String = "food",
            pickupTime: String? = "Anytime today",
            availableHours: String? = nil,
            postAddress: String? = "123 Main St, Sacramento",
            postStrippedAddress: String? = "Main St, Sacramento",
            latitude: Double? = 38.5816,
            longitude: Double? = -121.4944,
            images: [String]? = ["https://images.unsplash.com/photo-1560806887-1e4cd0b6cbd6"],
            isActive: Bool = true,
            isArranged: Bool = false,
            postArrangedTo: UUID? = nil,
            postArrangedAt: Date? = nil,
            postViews: Int = 0,
            postLikeCounter: Int? = 0,
            hasPantry: Bool? = nil,
            foodStatus: String? = nil,
            network: String? = nil,
            website: String? = nil,
            donation: String? = nil,
            donationRules: String? = nil,
            categoryId: Int? = 1,
            createdAt: Date = Date(),
            updatedAt: Date = Date(),
            distanceMeters: Double? = 1500.0,
        ) -> FoodItem {
            FoodItem(
                id: id,
                profileId: profileId,
                postName: postName,
                postDescription: postDescription,
                postType: postType,
                pickupTime: pickupTime,
                availableHours: availableHours,
                postAddress: postAddress,
                postStrippedAddress: postStrippedAddress,
                latitude: latitude,
                longitude: longitude,
                images: images,
                isActive: isActive,
                isArranged: isArranged,
                postArrangedTo: postArrangedTo,
                postArrangedAt: postArrangedAt,
                postViews: postViews,
                postLikeCounter: postLikeCounter,
                hasPantry: hasPantry,
                foodStatus: foodStatus,
                network: network,
                website: website,
                donation: donation,
                donationRules: donationRules,
                categoryId: categoryId,
                createdAt: createdAt,
                updatedAt: updatedAt,
                distanceMeters: distanceMeters,
            )
        }

        /// Sample listings for previews
        static let sampleListings: [FoodItem] = [
            .fixture(id: 1, postName: "Fresh Apples", postDescription: "5 organic apples"),
            .fixture(id: 2, postName: "Homemade Bread", postDescription: "Sourdough loaf", categoryId: 3),
            .fixture(id: 3, postName: "Leftover Pizza", postDescription: "4 slices, pepperoni", categoryId: 6),
            .fixture(id: 4, postName: "Canned Goods", postDescription: "Assorted cans", categoryId: 5),
        ]
    }

    #endif

// MARK: - Description Cleaning

extension FoodItem {
    /// Cleans description by removing metadata markers like [DESCRIPTION], [SOURCE], etc.
    static func cleanDescription(_ description: String?) -> String {
        guard var cleaned = description else { return "" }

        let patterns = [
            "\\[DESCRIPTION\\]\\s*",
            "\\[SOURCE\\]\\s*",
            "\\[INFO\\]\\s*",
            "\\[NOTES\\]\\s*",
            "Imported from OpenStreetMap[^.]*\\.",
            "\\(ID:\\s*node/\\d+\\)",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                cleaned = regex.stringByReplacingMatches(
                    in: cleaned,
                    range: NSRange(cleaned.startIndex..., in: cleaned),
                    withTemplate: ""
                )
            }
        }

        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        return cleaned
    }
}
