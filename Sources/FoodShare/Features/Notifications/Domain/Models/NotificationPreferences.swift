// MARK: - NotificationPreferences.swift
// Enterprise Notification Preferences Domain Models
// FoodShare iOS - Clean Architecture Domain Layer


#if !SKIP
import Foundation

// MARK: - Notification Category

/// Categories of notifications matching backend schema
public enum NotificationCategory: String, Codable, CaseIterable, Sendable {
    case posts // New listings, post updates
    case forum // Forum posts, replies
    case challenges // Challenge invites, completions
    case comments // Comments on your posts
    case chats // Direct messages, chat rooms
    case social // Follows, likes, shares
    case system // Account, security, billing
    case marketing // Promotions, newsletters

    public var displayName: String {
        switch self {
        case .posts: "Posts & Listings"
        case .forum: "Forum"
        case .challenges: "Challenges"
        case .comments: "Comments"
        case .chats: "Messages"
        case .social: "Social"
        case .system: "System"
        case .marketing: "Marketing"
        }
    }

    public var description: String {
        switch self {
        case .posts: "New listings and updates from people you follow"
        case .forum: "Forum posts and replies to your topics"
        case .challenges: "Challenge invites, completions, and reminders"
        case .comments: "Comments on your posts and replies"
        case .chats: "Direct messages and chat room activity"
        case .social: "New followers, likes, and shares"
        case .system: "Account, security, and billing notifications"
        case .marketing: "Promotions, newsletters, and updates"
        }
    }

    public var icon: String {
        switch self {
        case .posts: "leaf.fill"
        case .forum: "bubble.left.and.bubble.right.fill"
        case .challenges: "trophy.fill"
        case .comments: "text.bubble.fill"
        case .chats: "message.fill"
        case .social: "person.2.fill"
        case .system: "gearshape.fill"
        case .marketing: "megaphone.fill"
        }
    }

    /// Whether this category can be disabled (system cannot)
    public var canDisable: Bool {
        self != .system
    }

    /// Display order for UI
    public var sortOrder: Int {
        switch self {
        case .chats: 0 // Most important
        case .posts: 1
        case .comments: 2
        case .social: 3
        case .forum: 4
        case .challenges: 5
        case .system: 6
        case .marketing: 7 // Least important
        }
    }
}

// MARK: - Notification Channel

/// Delivery channels for notifications
public enum NotificationChannel: String, Codable, CaseIterable, Sendable {
    case push
    case email
    case sms
    case inApp = "in_app"

    public var displayName: String {
        switch self {
        case .push: "Push"
        case .email: "Email"
        case .sms: "SMS"
        case .inApp: "In-App"
        }
    }

    public var description: String {
        switch self {
        case .push: "Mobile and browser notifications"
        case .email: "Email notifications"
        case .sms: "Text message notifications"
        case .inApp: "In-app message notifications"
        }
    }

    public var icon: String {
        switch self {
        case .push: "bell.badge.fill"
        case .email: "envelope.fill"
        case .sms: "text.bubble.fill"
        case .inApp: "app.badge.fill"
        }
    }
}

// MARK: - Notification Frequency

/// Delivery frequency for notifications
public enum NotificationFrequency: String, Codable, CaseIterable, Sendable {
    case instant
    case hourly
    case daily
    case weekly
    case never

    public var displayName: String {
        switch self {
        case .instant: "Instant"
        case .hourly: "Hourly Digest"
        case .daily: "Daily Digest"
        case .weekly: "Weekly Digest"
        case .never: "Never"
        }
    }

    public var description: String {
        switch self {
        case .instant: "Notify immediately"
        case .hourly: "Batch and send every hour"
        case .daily: "Include in daily digest at 9am"
        case .weekly: "Include in weekly digest on Mondays"
        case .never: "Don't send notifications"
        }
    }

    public var icon: String {
        switch self {
        case .instant: "bolt.fill"
        case .hourly: "clock.fill"
        case .daily: "sun.max.fill"
        case .weekly: "calendar"
        case .never: "bell.slash.fill"
        }
    }

    public var titleKey: String {
        switch self {
        case .instant: "email_preferences.frequency.instant.title"
        case .hourly: "email_preferences.frequency.hourly.title"
        case .daily: "email_preferences.frequency.daily.title"
        case .weekly: "email_preferences.frequency.weekly.title"
        case .never: "email_preferences.frequency.never.title"
        }
    }

    public var descriptionKey: String {
        switch self {
        case .instant: "email_preferences.frequency.instant.description"
        case .hourly: "email_preferences.frequency.hourly.description"
        case .daily: "email_preferences.frequency.daily.description"
        case .weekly: "email_preferences.frequency.weekly.description"
        case .never: "email_preferences.frequency.never.description"
        }
    }
}

// MARK: - Category Preference

/// Individual category preference with channel-specific settings
public struct CategoryPreference: Codable, Sendable, Equatable, Identifiable {
    public var id: String {
        "\(category.rawValue)-\(channel.rawValue)"
    }

    public let category: NotificationCategory
    public let channel: NotificationChannel
    public var enabled: Bool
    public var frequency: NotificationFrequency

    public init(
        category: NotificationCategory,
        channel: NotificationChannel,
        enabled: Bool = true,
        frequency: NotificationFrequency = .instant,
    ) {
        self.category = category
        self.channel = channel
        self.enabled = enabled
        self.frequency = frequency
    }
}

// MARK: - Quiet Hours

/// Quiet hours configuration
public struct QuietHours: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var start: String // HH:mm format
    public var end: String // HH:mm format
    public var timezone: String

    public init(
        enabled: Bool = false,
        start: String = "22:00",
        end: String = "08:00",
        timezone: String = TimeZone.current.identifier,
    ) {
        self.enabled = enabled
        self.start = start
        self.end = end
        self.timezone = timezone
    }

    /// Parse start time as Date components
    public var startTime: DateComponents? {
        parseTime(start)
    }

    /// Parse end time as Date components
    public var endTime: DateComponents? {
        parseTime(end)
    }

    private func parseTime(_ timeString: String) -> DateComponents? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else
        {
            return nil
        }
        return DateComponents(hour: hour, minute: minute)
    }
}

// MARK: - Do Not Disturb

/// Do Not Disturb configuration
public struct DoNotDisturb: Codable, Sendable, Equatable {
    public var enabled: Bool
    public var until: Date?

    public init(enabled: Bool = false, until: Date? = nil) {
        self.enabled = enabled
        self.until = until
    }

    /// Check if DND is currently active
    public var isActive: Bool {
        guard enabled else { return false }
        guard let until else { return true } // No expiry = always on
        return Date() < until
    }

    /// Remaining time until DND expires
    public var remainingTime: TimeInterval? {
        guard isActive, let until else { return nil }
        return until.timeIntervalSinceNow
    }

    /// Formatted remaining time string
    public var remainingTimeFormatted: String? {
        guard let remaining = remainingTime, remaining > 0 else { return nil }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m remaining"
        } else {
            return "\(minutes)m remaining"
        }
    }
}

// MARK: - Digest Settings

/// Digest delivery configuration
public struct DigestSettings: Codable, Sendable, Equatable {
    public var dailyEnabled: Bool
    public var dailyTime: String // HH:mm format
    public var weeklyEnabled: Bool
    public var weeklyDay: Int // 0 = Sunday, 1 = Monday, etc.

    public init(
        dailyEnabled: Bool = true,
        dailyTime: String = "09:00",
        weeklyEnabled: Bool = true,
        weeklyDay: Int = 1, // Monday
    ) {
        self.dailyEnabled = dailyEnabled
        self.dailyTime = dailyTime
        self.weeklyEnabled = weeklyEnabled
        self.weeklyDay = weeklyDay
    }

    public var weeklyDayName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.weekdaySymbols[weeklyDay]
    }
}

// MARK: - Global Settings

/// Global notification settings
public struct NotificationGlobalSettings: Codable, Sendable, Equatable {
    public var pushEnabled: Bool
    public var emailEnabled: Bool
    public var smsEnabled: Bool
    public var phoneNumber: String?
    public var phoneVerified: Bool
    public var quietHours: QuietHours
    public var dnd: DoNotDisturb
    public var digest: DigestSettings

    public init(
        pushEnabled: Bool = true,
        emailEnabled: Bool = true,
        smsEnabled: Bool = false,
        phoneNumber: String? = nil,
        phoneVerified: Bool = false,
        quietHours: QuietHours = QuietHours(),
        dnd: DoNotDisturb = DoNotDisturb(),
        digest: DigestSettings = DigestSettings(),
    ) {
        self.pushEnabled = pushEnabled
        self.emailEnabled = emailEnabled
        self.smsEnabled = smsEnabled
        self.phoneNumber = phoneNumber
        self.phoneVerified = phoneVerified
        self.quietHours = quietHours
        self.dnd = dnd
        self.digest = digest
    }
}

// MARK: - Complete Preferences

/// Complete notification preferences response from API
public struct NotificationPreferences: Codable, Sendable, Equatable {
    public var settings: NotificationGlobalSettings
    public var preferences: [String: [String: CategoryPreferenceData]]

    /// Category metadata from API
    public struct CategoryMetadata: Codable, Sendable {
        public let key: String
        public let label: String
        public let description: String
    }

    /// Channel metadata from API
    public struct ChannelMetadata: Codable, Sendable {
        public let key: String
        public let label: String
        public let description: String
    }

    /// Frequency metadata from API
    public struct FrequencyMetadata: Codable, Sendable {
        public let key: String
        public let label: String
        public let description: String
    }

    /// Raw preference data from API
    public struct CategoryPreferenceData: Codable, Sendable, Equatable {
        public var enabled: Bool
        public var frequency: String
    }

    public init(
        settings: NotificationGlobalSettings = NotificationGlobalSettings(),
        preferences: [String: [String: CategoryPreferenceData]] = [:],
    ) {
        self.settings = settings
        self.preferences = preferences
    }

    /// Get preference for specific category and channel
    public func preference(for category: NotificationCategory, channel: NotificationChannel) -> CategoryPreference {
        let categoryData = preferences[category.rawValue]
        let channelData = categoryData?[channel.rawValue]

        return CategoryPreference(
            category: category,
            channel: channel,
            enabled: channelData?.enabled ?? true,
            frequency: NotificationFrequency(rawValue: channelData?.frequency ?? "instant") ?? .instant,
        )
    }

    /// Get all preferences for a category
    public func preferences(for category: NotificationCategory) -> [CategoryPreference] {
        NotificationChannel.allCases.map { channel in
            preference(for: category, channel: channel)
        }
    }

    /// Get all preferences for a channel
    public func preferences(for channel: NotificationChannel) -> [CategoryPreference] {
        NotificationCategory.allCases.map { category in
            preference(for: category, channel: channel)
        }
    }

    /// Check if any push notifications are enabled
    public var hasPushEnabled: Bool {
        guard settings.pushEnabled else { return false }
        return NotificationCategory.allCases.contains { category in
            preference(for: category, channel: .push).enabled
        }
    }

    /// Check if any email notifications are enabled
    public var hasEmailEnabled: Bool {
        guard settings.emailEnabled else { return false }
        return NotificationCategory.allCases.contains { category in
            preference(for: category, channel: .email).enabled
        }
    }
}

// MARK: - API Request/Response Types

/// Request to update a single preference
public struct UpdatePreferenceRequest: Codable, Sendable {
    public let category: String
    public let channel: String
    public var enabled: Bool?
    public var frequency: String?

    public init(preference: CategoryPreference) {
        self.category = preference.category.rawValue
        self.channel = preference.channel.rawValue
        self.enabled = preference.enabled
        self.frequency = preference.frequency.rawValue
    }
}

/// Request to update global settings
public struct UpdateSettingsRequest: Codable, Sendable {
    public var push_enabled: Bool?
    public var email_enabled: Bool?
    public var sms_enabled: Bool?
    public var phone_number: String?
    public var quiet_hours: QuietHoursRequest?
    public var digest: DigestRequest?
    public var dnd: DNDRequest?

    public struct QuietHoursRequest: Codable, Sendable {
        public var enabled: Bool?
        public var start: String?
        public var end: String?
        public var timezone: String?
    }

    public struct DigestRequest: Codable, Sendable {
        public var daily_enabled: Bool?
        public var daily_time: String?
        public var weekly_enabled: Bool?
        public var weekly_day: Int?
    }

    public struct DNDRequest: Codable, Sendable {
        public var enabled: Bool?
        public var until: String?
    }
}

/// Request to enable DND
public struct EnableDNDRequest: Codable, Sendable {
    public var until: String?
    public var duration_hours: Int?

    public init(until: Date) {
        let formatter = ISO8601DateFormatter()
        self.until = formatter.string(from: until)
        self.duration_hours = nil
    }

    public init(durationHours: Int) {
        self.until = nil
        self.duration_hours = durationHours
    }
}


#endif
