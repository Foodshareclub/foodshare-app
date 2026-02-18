//
//  SettingsCategory.swift
//  Foodshare
//
//  Settings category enumeration for organizing and filtering settings
//


#if !SKIP
import SwiftUI

/// Categories for organizing settings sections
enum SettingsCategory: String, CaseIterable, Identifiable, Sendable {
    case account
    case subscription
    case security
    case preferences
    case appearance
    case notifications
    case communication
    case accessibility
    case dataPrivacy
    case support
    case about
    case dangerZone

    var id: String { rawValue }

    /// SF Symbol icon name for the category
    var icon: String {
        switch self {
        case .account: "person.circle.fill"
        case .subscription: "star.circle.fill"
        case .security: "lock.shield.fill"
        case .preferences: "slider.horizontal.3"
        case .appearance: "paintpalette.fill"
        case .notifications: "bell.fill"
        case .communication: "envelope.fill"
        case .accessibility: "accessibility"
        case .dataPrivacy: "hand.raised.fill"
        case .support: "heart.fill"
        case .about: "info.circle.fill"
        case .dangerZone: "exclamationmark.triangle.fill"
        }
    }

    /// Color for the category title/icon
    var titleColor: Color {
        switch self {
        case .account: .DesignSystem.text
        case .subscription: .DesignSystem.text
        case .security: .DesignSystem.brandBlue
        case .preferences: .DesignSystem.text
        case .appearance: .DesignSystem.text
        case .notifications: .DesignSystem.text
        case .communication: .DesignSystem.text
        case .accessibility: .DesignSystem.brandTeal
        case .dataPrivacy: .DesignSystem.accentPurple
        case .support: .DesignSystem.accentPink
        case .about: .DesignSystem.text
        case .dangerZone: .DesignSystem.error
        }
    }

    /// Display order for the category
    var order: Int {
        switch self {
        case .account: 0
        case .subscription: 1
        case .security: 2
        case .preferences: 3
        case .appearance: 4
        case .notifications: 5
        case .communication: 6
        case .accessibility: 7
        case .dataPrivacy: 8
        case .support: 9
        case .about: 10
        case .dangerZone: 11
        }
    }

    /// Localization key for the category title
    var titleKey: String {
        switch self {
        case .account: "account"
        case .subscription: "subscription.title"
        case .security: "security"
        case .preferences: "preferences"
        case .appearance: "appearance"
        case .notifications: "notifications.title"
        case .communication: "communication"
        case .accessibility: "accessibility"
        case .dataPrivacy: "data_privacy"
        case .support: "support_us"
        case .about: "about"
        case .dangerZone: "account_actions"
        }
    }

    /// Categories sorted by display order
    static var sortedCases: [SettingsCategory] {
        allCases.sorted { $0.order < $1.order }
    }
}

#endif
