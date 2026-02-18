//
//  SettingItem.swift
//  Foodshare
//
//  Searchable settings item model for settings search functionality
//


#if !SKIP
import Foundation

/// Represents a single searchable setting item
struct SettingItem: Identifiable, Sendable, Hashable {
    let id: String
    let titleKey: String
    let keywords: [String]
    let category: SettingsCategory
    let icon: String
    let iconColorName: String

    init(
        id: String,
        titleKey: String,
        keywords: [String] = [],
        category: SettingsCategory,
        icon: String,
        iconColorName: String = "brandGreen"
    ) {
        self.id = id
        self.titleKey = titleKey
        self.keywords = keywords
        self.category = category
        self.icon = icon
        self.iconColorName = iconColorName
    }

    /// Check if this setting matches the search query
    /// - Parameter query: The search query string
    /// - Returns: True if the setting matches the query
    func matchesSearch(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }

        let lowercasedQuery = query.lowercased()

        // Check title key
        if titleKey.lowercased().contains(lowercasedQuery) {
            return true
        }

        // Check keywords
        if keywords.contains(where: { $0.lowercased().contains(lowercasedQuery) }) {
            return true
        }

        // Check category name
        if category.rawValue.lowercased().contains(lowercasedQuery) {
            return true
        }

        return false
    }

    /// Calculate relevance score for sorting search results
    /// - Parameter query: The search query string
    /// - Returns: Higher score means more relevant
    func relevanceScore(for query: String) -> Int {
        guard !query.isEmpty else { return 0 }

        let lowercasedQuery = query.lowercased()
        var score = 0

        // Exact title match gets highest score
        if titleKey.lowercased() == lowercasedQuery {
            score += 100
        } else if titleKey.lowercased().hasPrefix(lowercasedQuery) {
            score += 75
        } else if titleKey.lowercased().contains(lowercasedQuery) {
            score += 50
        }

        // Keyword matches
        for keyword in keywords {
            if keyword.lowercased() == lowercasedQuery {
                score += 40
            } else if keyword.lowercased().hasPrefix(lowercasedQuery) {
                score += 30
            } else if keyword.lowercased().contains(lowercasedQuery) {
                score += 20
            }
        }

        // Category match
        if category.rawValue.lowercased().contains(lowercasedQuery) {
            score += 10
        }

        return score
    }
}

// MARK: - All Setting Items Registry

extension SettingItem {
    /// All searchable settings in the app
    static let allItems: [SettingItem] = [
        // Account
        SettingItem(
            id: "email",
            titleKey: "email",
            keywords: ["email", "mail", "address", "contact"],
            category: .account,
            icon: "envelope.fill",
            iconColorName: "brandBlue"
        ),
        SettingItem(
            id: "name",
            titleKey: "name",
            keywords: ["name", "display name", "username", "profile name"],
            category: .account,
            icon: "person.fill",
            iconColorName: "brandGreen"
        ),
        SettingItem(
            id: "edit_profile",
            titleKey: "edit_profile",
            keywords: ["edit", "profile", "account", "change", "update"],
            category: .account,
            icon: "pencil",
            iconColorName: "accentOrange"
        ),

        // Subscription
        SettingItem(
            id: "premium",
            titleKey: "premium",
            keywords: ["premium", "subscription", "upgrade", "pro", "paid"],
            category: .subscription,
            icon: "crown.fill",
            iconColorName: "brandPink"
        ),

        // Security
        SettingItem(
            id: "app_lock",
            titleKey: "app_lock",
            keywords: ["lock", "biometric", "face id", "touch id", "passcode", "security", "fingerprint"],
            category: .security,
            icon: "lock.fill",
            iconColorName: "brandBlue"
        ),
        SettingItem(
            id: "login_security",
            titleKey: "login_security",
            keywords: ["login", "security", "password", "authentication", "2fa", "mfa"],
            category: .security,
            icon: "shield.fill",
            iconColorName: "brandGreen"
        ),

        // Preferences
        SettingItem(
            id: "language",
            titleKey: "language",
            keywords: ["language", "locale", "translation", "lang"],
            category: .preferences,
            icon: "globe",
            iconColorName: "brandBlue"
        ),
        SettingItem(
            id: "search_radius",
            titleKey: "search_radius",
            keywords: ["radius", "distance", "range", "km", "miles", "search"],
            category: .preferences,
            icon: "location.circle.fill",
            iconColorName: "brandGreen"
        ),
        SettingItem(
            id: "location_services",
            titleKey: "location_services",
            keywords: ["location", "gps", "map", "services"],
            category: .preferences,
            icon: "location.fill",
            iconColorName: "brandBlue"
        ),

        // Appearance
        SettingItem(
            id: "theme",
            titleKey: "settings.theme",
            keywords: ["theme", "color", "palette", "colors", "visual"],
            category: .appearance,
            icon: "paintpalette.fill",
            iconColorName: "brandPink"
        ),
        SettingItem(
            id: "appearance_mode",
            titleKey: "appearance_mode",
            keywords: ["dark mode", "light mode", "appearance", "dark", "light", "system"],
            category: .appearance,
            icon: "circle.lefthalf.filled",
            iconColorName: "brandBlue"
        ),

        // Notifications
        SettingItem(
            id: "push_notifications",
            titleKey: "push_notifications",
            keywords: ["push", "notifications", "alerts", "notify"],
            category: .notifications,
            icon: "bell.badge.fill",
            iconColorName: "error"
        ),
        SettingItem(
            id: "message_alerts",
            titleKey: "message_alerts",
            keywords: ["message", "alerts", "chat", "inbox"],
            category: .notifications,
            icon: "message.fill",
            iconColorName: "brandGreen"
        ),
        SettingItem(
            id: "like_notifications",
            titleKey: "like_notifications",
            keywords: ["like", "heart", "favorites", "notifications"],
            category: .notifications,
            icon: "heart.fill",
            iconColorName: "accentPink"
        ),

        // Communication
        SettingItem(
            id: "email_preferences",
            titleKey: "email_preferences.title",
            keywords: ["email", "preferences", "newsletter", "updates"],
            category: .communication,
            icon: "envelope.badge.fill",
            iconColorName: "brandTeal"
        ),
        SettingItem(
            id: "newsletter",
            titleKey: "newsletter.title",
            keywords: ["newsletter", "subscribe", "updates", "news"],
            category: .communication,
            icon: "newspaper.fill",
            iconColorName: "brandGreen"
        ),
        SettingItem(
            id: "invite_friends",
            titleKey: "invite_friends",
            keywords: ["invite", "friends", "share", "referral"],
            category: .communication,
            icon: "person.badge.plus.fill",
            iconColorName: "brandPink"
        ),

        // Accessibility
        SettingItem(
            id: "reduce_animations",
            titleKey: "reduce_animations",
            keywords: ["animations", "motion", "reduce", "accessibility"],
            category: .accessibility,
            icon: "figure.walk.motion",
            iconColorName: "brandTeal"
        ),
        SettingItem(
            id: "high_contrast",
            titleKey: "high_contrast",
            keywords: ["contrast", "accessibility", "visibility"],
            category: .accessibility,
            icon: "circle.lefthalf.filled.inverse",
            iconColorName: "brandBlue"
        ),
        SettingItem(
            id: "larger_text",
            titleKey: "larger_text",
            keywords: ["text", "font", "size", "larger", "accessibility"],
            category: .accessibility,
            icon: "textformat.size.larger",
            iconColorName: "brandGreen"
        ),

        // Data & Privacy
        SettingItem(
            id: "export_data",
            titleKey: "export_data",
            keywords: ["export", "data", "gdpr", "download", "backup"],
            category: .dataPrivacy,
            icon: "square.and.arrow.up.fill",
            iconColorName: "accentPurple"
        ),
        SettingItem(
            id: "backup_settings",
            titleKey: "backup_settings",
            keywords: ["backup", "restore", "settings", "save"],
            category: .dataPrivacy,
            icon: "externaldrive.fill",
            iconColorName: "brandBlue"
        ),
        SettingItem(
            id: "privacy_settings",
            titleKey: "privacy_settings",
            keywords: ["privacy", "settings", "security", "data"],
            category: .dataPrivacy,
            icon: "hand.raised.fill",
            iconColorName: "accentPurple"
        ),

        // Support
        SettingItem(
            id: "buy_coffee",
            titleKey: "buy_us_a_coffee",
            keywords: ["donate", "coffee", "support", "tip"],
            category: .support,
            icon: "cup.and.saucer.fill",
            iconColorName: "accentPink"
        ),
        SettingItem(
            id: "help_center",
            titleKey: "help_center",
            keywords: ["help", "faq", "support", "questions"],
            category: .support,
            icon: "questionmark.circle.fill",
            iconColorName: "accentOrange"
        ),
        SettingItem(
            id: "send_feedback",
            titleKey: "send_feedback",
            keywords: ["feedback", "report", "bug", "suggestion"],
            category: .support,
            icon: "bubble.left.and.bubble.right.fill",
            iconColorName: "brandBlue"
        ),

        // About
        SettingItem(
            id: "version",
            titleKey: "version",
            keywords: ["version", "build", "app version"],
            category: .about,
            icon: "app.badge.fill",
            iconColorName: "brandGreen"
        ),
        SettingItem(
            id: "privacy_policy",
            titleKey: "privacy_policy",
            keywords: ["privacy", "policy", "legal"],
            category: .about,
            icon: "hand.raised.fill",
            iconColorName: "accentPurple"
        ),
        SettingItem(
            id: "terms_of_service",
            titleKey: "terms_of_service",
            keywords: ["terms", "service", "legal", "tos"],
            category: .about,
            icon: "doc.text.fill",
            iconColorName: "brandBlue"
        ),
        SettingItem(
            id: "app_icon",
            titleKey: "app_icon",
            keywords: ["icon", "app icon", "customize", "change icon"],
            category: .appearance,
            icon: "app.fill",
            iconColorName: "brandGreen"
        ),

        // Danger Zone
        SettingItem(
            id: "sign_out",
            titleKey: "sign_out",
            keywords: ["sign out", "logout", "log out", "exit"],
            category: .dangerZone,
            icon: "rectangle.portrait.and.arrow.right",
            iconColorName: "accentOrange"
        ),
        SettingItem(
            id: "delete_account",
            titleKey: "delete_account",
            keywords: ["delete", "account", "remove", "erase"],
            category: .dangerZone,
            icon: "trash.fill",
            iconColorName: "error"
        ),
    ]

    /// Get items grouped by category
    static var itemsByCategory: [SettingsCategory: [SettingItem]] {
        var result: [SettingsCategory: [SettingItem]] = [:]
        for item in allItems {
            result[item.category, default: []].append(item)
        }
        return result
    }

    /// Search all items and return matches sorted by relevance
    /// - Parameter query: The search query
    /// - Returns: Matching items sorted by relevance score
    static func search(_ query: String) -> [SettingItem] {
        guard !query.isEmpty else { return allItems }

        return allItems
            .filter { $0.matchesSearch(query) }
            .sorted { $0.relevanceScore(for: query) > $1.relevanceScore(for: query) }
    }
}

#endif
