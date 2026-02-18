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
        case .messaging: return "Messaging"
        case .createListing: return "Create Listing"
        case .profile: return "Profile"
        case .challenges: return "Challenges"
        case .reviews: return "Reviews"
        case .favorites: return "Favorites"
        case .notifications: return "Notifications"
        }
    }

    var description: String {
        switch self {
        case .messaging: return "Send and receive messages with other Foodshare members"
        case .createListing: return "Share your surplus food with the community"
        case .profile: return "Customize your profile and track your impact"
        case .challenges: return "Participate in community challenges and earn badges"
        case .reviews: return "Leave reviews for other community members"
        case .favorites: return "Save your favorite listings for later"
        case .notifications: return "Get notified about nearby food and messages"
        }
    }

    #if !SKIP
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
    #endif

    var icon: String {
        switch self {
        case .messaging: return "message.fill"
        case .createListing: return "plus.circle.fill"
        case .profile: return "person.fill"
        case .challenges: return "trophy.fill"
        case .reviews: return "star.fill"
        case .favorites: return "heart.fill"
        case .notifications: return "bell.fill"
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
        #if !SKIP
        withAnimation(.easeInOut(duration: 0.3)) {
            isGuestMode = true
        }
        #else
        isGuestMode = true
        #endif
        showSignUpPrompt = false
        restrictedFeature = nil
        HapticManager.light()
    }

    /// Disable guest mode and clear guest data
    func disableGuestMode() {
        #if !SKIP
        withAnimation(.easeInOut(duration: 0.3)) {
            isGuestMode = false
        }
        #else
        isGuestMode = false
        #endif
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
        return isGuestMode
    }

    /// Reset guest session (useful for testing)
    func resetGuestSession() {
        showSignUpPrompt = false
        restrictedFeature = nil
    }
}
