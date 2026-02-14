//
//  GuestManager.swift
//  Foodshare
//
//  Manages guest mode access using modern Swift 6.2 @Observable pattern
//  MIGRATED: From ObservableObject to @Observable for improved performance
//

import Foundation
import Observation
import SwiftUI

// MARK: - Guest Restricted Features

/// Features that require authentication
enum GuestRestrictedFeature {
    case messaging
    case createListing
    case profile
    case challenges
    case reviews
    case favorites
    case notifications

    var title: String {
        switch self {
        case .messaging: "Messaging"
        case .createListing: "Create Listing"
        case .profile: "Profile"
        case .challenges: "Challenges"
        case .reviews: "Reviews"
        case .favorites: "Favorites"
        case .notifications: "Notifications"
        }
    }

    var description: String {
        switch self {
        case .messaging: "Send and receive messages with other Foodshare members"
        case .createListing: "Share your surplus food with the community"
        case .profile: "Customize your profile and track your impact"
        case .challenges: "Participate in community challenges and earn badges"
        case .reviews: "Leave reviews for other community members"
        case .favorites: "Save your favorite listings for later"
        case .notifications: "Get notified about nearby food and messages"
        }
    }

    /// Localized title using translation service
    @MainActor
    func localizedTitle(using t: EnhancedTranslationService) -> String {
        switch self {
        case .messaging: t.t("guest.feature.messaging.title")
        case .createListing: t.t("guest.feature.create_listing.title")
        case .profile: t.t("guest.feature.profile.title")
        case .challenges: t.t("guest.feature.challenges.title")
        case .reviews: t.t("guest.feature.reviews.title")
        case .favorites: t.t("guest.feature.favorites.title")
        case .notifications: t.t("guest.feature.notifications.title")
        }
    }

    /// Localized description using translation service
    @MainActor
    func localizedDescription(using t: EnhancedTranslationService) -> String {
        switch self {
        case .messaging: t.t("guest.feature.messaging.desc")
        case .createListing: t.t("guest.feature.create_listing.desc")
        case .profile: t.t("guest.feature.profile.desc")
        case .challenges: t.t("guest.feature.challenges.desc")
        case .reviews: t.t("guest.feature.reviews.desc")
        case .favorites: t.t("guest.feature.favorites.desc")
        case .notifications: t.t("guest.feature.notifications.desc")
        }
    }

    var icon: String {
        switch self {
        case .messaging: "message.fill"
        case .createListing: "plus.circle.fill"
        case .profile: "person.fill"
        case .challenges: "trophy.fill"
        case .reviews: "star.fill"
        case .favorites: "heart.fill"
        case .notifications: "bell.fill"
        }
    }
}

// MARK: - Guest Manager

@MainActor
@Observable
final class GuestManager {
    // MARK: - Observable Properties

    var isGuestMode: Bool {
        didSet {
            UserDefaults.standard.set(isGuestMode, forKey: "isGuestMode")
        }
    }

    var showSignUpPrompt: Bool = false
    var restrictedFeature: GuestRestrictedFeature?

    // MARK: - Initialization

    init() {
        isGuestMode = UserDefaults.standard.bool(forKey: "isGuestMode")
    }

    // MARK: - Public Methods

    /// Enable guest mode
    func enableGuestMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isGuestMode = true
        }
        showSignUpPrompt = false
        restrictedFeature = nil
        HapticManager.light()
    }

    /// Disable guest mode and clear guest data
    func disableGuestMode() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isGuestMode = false
        }
        showSignUpPrompt = false
        restrictedFeature = nil
        HapticManager.light()
    }

    /// Show sign-up prompt for a specific feature
    func promptSignUp(for feature: GuestRestrictedFeature) {
        restrictedFeature = feature
        showSignUpPrompt = true
        HapticManager.medium()
    }

    /// Dismiss the sign-up prompt
    func dismissSignUpPrompt() {
        showSignUpPrompt = false
        restrictedFeature = nil
    }

    /// Check if a feature is restricted for guests
    func isRestricted(_ feature: GuestRestrictedFeature) -> Bool {
        isGuestMode
    }

    /// Reset guest session (useful for testing)
    func resetGuestSession() {
        showSignUpPrompt = false
        restrictedFeature = nil
    }
}
