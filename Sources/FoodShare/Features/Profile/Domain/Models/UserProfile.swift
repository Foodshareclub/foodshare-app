//
//  UserProfile.swift
//  Foodshare
//
//  User profile domain model
//


#if !SKIP
import Foundation

// MARK: - Dietary Preferences

/// Represents dietary preferences/restrictions for food sharing.
enum DietaryPreference: String, Codable, CaseIterable, Sendable, Identifiable {
    case vegetarian
    case vegan
    case glutenFree = "gluten_free"
    case dairyFree = "dairy_free"
    case nutFree = "nut_free"
    case halal
    case kosher
    case organic
    case lowSodium = "low_sodium"
    case sugarFree = "sugar_free"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .glutenFree: "Gluten-Free"
        case .dairyFree: "Dairy-Free"
        case .nutFree: "Nut-Free"
        case .halal: "Halal"
        case .kosher: "Kosher"
        case .organic: "Organic"
        case .lowSodium: "Low Sodium"
        case .sugarFree: "Sugar-Free"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .vegetarian: t.t("dietary.vegetarian")
        case .vegan: t.t("dietary.vegan")
        case .glutenFree: t.t("dietary.gluten_free")
        case .dairyFree: t.t("dietary.dairy_free")
        case .nutFree: t.t("dietary.nut_free")
        case .halal: t.t("dietary.halal")
        case .kosher: t.t("dietary.kosher")
        case .organic: t.t("dietary.organic")
        case .lowSodium: t.t("dietary.low_sodium")
        case .sugarFree: t.t("dietary.sugar_free")
        }
    }

    var icon: String {
        switch self {
        case .vegetarian: "leaf.fill"
        case .vegan: "leaf.circle.fill"
        case .glutenFree: "wheat.slash"
        case .dairyFree: "cup.and.saucer"
        case .nutFree: "allergens"
        case .halal: "checkmark.seal.fill"
        case .kosher: "checkmark.seal.fill"
        case .organic: "sparkles"
        case .lowSodium: "drop.fill"
        case .sugarFree: "cube.fill"
        }
    }

    var color: String {
        switch self {
        case .vegetarian, .vegan, .organic: "brandGreen"
        case .glutenFree, .dairyFree, .sugarFree: "brandOrange"
        case .nutFree: "error"
        case .halal, .kosher: "brandBlue"
        case .lowSodium: "brandTeal"
        }
    }
}

// MARK: - Preferred Contact Method

/// Represents the user's preferred method of contact.
enum ContactMethod: String, Codable, CaseIterable, Sendable {
    case inApp = "in_app"
    case email
    case phone
    case sms

    var displayName: String {
        switch self {
        case .inApp: "In-App Messages"
        case .email: "Email"
        case .phone: "Phone Call"
        case .sms: "SMS/Text"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .inApp: t.t("contact.in_app")
        case .email: t.t("contact.email")
        case .phone: t.t("contact.phone")
        case .sms: t.t("contact.sms")
        }
    }

    var icon: String {
        switch self {
        case .inApp: "message.fill"
        case .email: "envelope.fill"
        case .phone: "phone.fill"
        case .sms: "text.bubble.fill"
        }
    }
}

// MARK: - Weekday

/// Represents days of the week for availability.
enum Weekday: String, Codable, CaseIterable, Sendable, Identifiable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday

    var id: String {
        rawValue
    }

    var shortName: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        case .saturday: "Sat"
        case .sunday: "Sun"
        }
    }

    @MainActor
    func localizedShortName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .monday: t.t("weekday.mon")
        case .tuesday: t.t("weekday.tue")
        case .wednesday: t.t("weekday.wed")
        case .thursday: t.t("weekday.thu")
        case .friday: t.t("weekday.fri")
        case .saturday: t.t("weekday.sat")
        case .sunday: t.t("weekday.sun")
        }
    }

    var singleLetter: String {
        switch self {
        case .monday: "M"
        case .tuesday: "T"
        case .wednesday: "W"
        case .thursday: "T"
        case .friday: "F"
        case .saturday: "S"
        case .sunday: "S"
        }
    }
}

// MARK: - Time Range

/// Represents a time range for pickup availability.
struct TimeRange: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let startHour: Int
    let startMinute: Int
    let endHour: Int
    let endMinute: Int

    init(id: UUID = UUID(), startHour: Int, startMinute: Int = 0, endHour: Int, endMinute: Int = 0) {
        self.id = id
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
    }

    var displayString: String {
        let startTime = String(format: "%d:%02d", startHour > 12 ? startHour - 12 : startHour, startMinute)
        let startPeriod = startHour >= 12 ? "PM" : "AM"
        let endTime = String(format: "%d:%02d", endHour > 12 ? endHour - 12 : endHour, endMinute)
        let endPeriod = endHour >= 12 ? "PM" : "AM"
        return "\(startTime) \(startPeriod) - \(endTime) \(endPeriod)"
    }

    static let morning = TimeRange(startHour: 8, endHour: 12)
    static let afternoon = TimeRange(startHour: 12, endHour: 17)
    static let evening = TimeRange(startHour: 17, endHour: 21)
}

// MARK: - Profile Visibility

/// Represents the visibility level of a user's profile.
///
/// Controls who can see the user's profile information and activity.
enum ProfileVisibility: String, Codable, CaseIterable, Sendable, Equatable {
    /// Profile is visible to all users
    case `public`
    /// Profile is visible only to friends/connections
    case friendsOnly = "friends_only"
    /// Profile is hidden from other users
    case `private`

    /// Display name for UI
    var displayName: String {
        switch self {
        case .public: "Public"
        case .friendsOnly: "Friends Only"
        case .private: "Private"
        }
    }

    /// SF Symbol icon name
    var icon: String {
        switch self {
        case .public: "globe"
        case .friendsOnly: "person.2.fill"
        case .private: "lock.fill"
        }
    }

    /// Description text for settings
    var description: String {
        switch self {
        case .public: "Anyone can view your profile and activity"
        case .friendsOnly: "Only people you've connected with can see your profile"
        case .private: "Your profile is hidden from other users"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .public: t.t("visibility.public")
        case .friendsOnly: t.t("visibility.friends_only")
        case .private: t.t("visibility.private")
        }
    }

    @MainActor
    func localizedDescription(using t: EnhancedTranslationService) -> String {
        switch self {
        case .public: t.t("visibility.public_desc")
        case .friendsOnly: t.t("visibility.friends_only_desc")
        case .private: t.t("visibility.private_desc")
        }
    }
}

/// Represents a user's public profile in the Foodshare app.
///
/// Maps to the `profiles` table joined with `profile_stats` in Supabase.
/// Statistics are stored in the separate `profile_stats` table.
///
/// Database columns:
/// - profiles: id, nickname, avatar_url, bio, about_me, created_time, search_radius_km
/// - profile_stats: items_shared, items_received, rating_average, rating_count
struct UserProfile: Codable, Identifiable, Sendable, Equatable {
    /// Unique identifier (matches Supabase Auth user ID)
    let id: UUID
    /// Display name shown to other users
    let nickname: String
    /// URL to the user's avatar image in Supabase Storage
    let avatarUrl: String?
    /// User's self-description (from bio column)
    let bio: String?
    /// User's about me text (from about_me column, used as location fallback)
    let aboutMe: String?
    /// Average rating from reviews (0.0-5.0)
    let ratingAverage: Double
    /// Total food items shared by this user
    let itemsShared: Int
    /// Total food items received by this user
    let itemsReceived: Int
    /// Total number of reviews received
    let ratingCount: Int
    /// When the profile was created
    let createdTime: Date
    /// User's preferred search radius in kilometers (1-800)
    let searchRadiusKm: Int?
    /// User's preferred locale code (e.g., "en", "ru", "de"). Nil means use system locale.
    let preferredLocale: String?

    enum CodingKeys: String, CodingKey {
        case id, nickname, bio
        case avatarUrl = "avatar_url"
        case aboutMe = "about_me"
        case ratingAverage = "rating_average"
        case itemsShared = "items_shared"
        case itemsReceived = "items_received"
        case ratingCount = "rating_count"
        case createdTime = "created_time"
        case searchRadiusKm = "search_radius_km"
        case preferredLocale = "preferred_locale"
    }

    // MARK: - Computed Properties (for backward compatibility)

    /// User's general location (uses aboutMe as fallback)
    var location: String? {
        aboutMe
    }

    /// Average rating (alias for ratingAverage)
    var rating: Double {
        ratingAverage
    }

    /// Total items shared (alias for itemsShared)
    var totalShared: Int {
        itemsShared
    }

    /// Total items received (alias for itemsReceived)
    var totalReceived: Int {
        itemsReceived
    }

    /// Total reviews (alias for ratingCount)
    var totalReviews: Int {
        ratingCount
    }

    /// Creation date (alias for createdTime)
    var createdAt: Date {
        createdTime
    }

    /// Search radius with default fallback
    @MainActor var effectiveSearchRadius: Double {
        Double(searchRadiusKm ?? Int(AppConfiguration.shared.defaultSearchRadiusKm))
    }
}

/// Request payload for updating a user's profile.
///
/// All fields are optional - only non-nil values will be updated.
/// Note: Statistics (items_shared, rating_average, etc.) are in profile_stats
/// table and should be updated separately.
struct UpdateProfileRequest: Encodable, Sendable {
    /// New display name (nil to keep current)
    let nickname: String?
    /// New bio text (nil to keep current)
    let bio: String?
    /// New about me text (nil to keep current)
    let aboutMe: String?
    /// New search radius in kilometers, 1-800 (nil to keep current)
    let searchRadiusKm: Int?
    /// New preferred locale code (nil to keep current)
    let preferredLocale: String?
    /// New avatar image data to upload (nil to keep current, not sent to DB)
    let avatarData: Data?

    enum CodingKeys: String, CodingKey {
        case nickname, bio
        case aboutMe = "about_me"
        case searchRadiusKm = "search_radius_km"
        case preferredLocale = "preferred_locale"
        // avatarData is not sent directly - handled separately via Storage
    }

    /// Custom encoding to exclude avatarData from JSON
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(aboutMe, forKey: .aboutMe)
        try container.encodeIfPresent(searchRadiusKm, forKey: .searchRadiusKm)
        try container.encodeIfPresent(preferredLocale, forKey: .preferredLocale)
    }
}

/// Aggregated statistics for a user's activity.
///
/// Used for displaying user stats in profile views and cards.
struct UserStats: Codable, Sendable, Equatable {
    /// Number of food items shared
    let shared: Int
    /// Number of food items received
    let received: Int
    /// Average rating (1.0-5.0)
    let rating: Double
}

// MARK: - Test Fixtures

extension UserProfile {
    /// Create a fixture for testing
    static func fixture(
        id: UUID = UUID(),
        nickname: String = "John Doe",
        avatarUrl: String? = nil,
        bio: String? = "Love sharing food with my community!",
        aboutMe: String? = "Sacramento, CA",
        ratingAverage: Double = 4.8,
        itemsShared: Int = 25,
        itemsReceived: Int = 15,
        ratingCount: Int = 20,
        createdTime: Date = Date(),
        searchRadiusKm: Int? = 5,
        preferredLocale: String? = nil,
    ) -> UserProfile {
        UserProfile(
            id: id,
            nickname: nickname,
            avatarUrl: avatarUrl,
            bio: bio,
            aboutMe: aboutMe,
            ratingAverage: ratingAverage,
            itemsShared: itemsShared,
            itemsReceived: itemsReceived,
            ratingCount: ratingCount,
            createdTime: createdTime,
            searchRadiusKm: searchRadiusKm,
            preferredLocale: preferredLocale,
        )
    }
}

extension UserStats {
    /// Create a fixture for testing
    static func fixture(
        shared: Int = 25,
        received: Int = 15,
        rating: Double = 4.8,
    ) -> UserStats {
        UserStats(shared: shared, received: received, rating: rating)
    }
}

#endif
