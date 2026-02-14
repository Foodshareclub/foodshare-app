//
//  AppRoute.swift
//  Foodshare
//
//  Unified navigation routes for type-safe, centralized navigation
//
//  This provides:
//  - Type-safe navigation across the entire app
//  - Deep link support with URL parsing
//  - Consistent navigation patterns across features
//

import Foundation

// MARK: - App Route

/// All navigation destinations in the app
///
/// Usage:
/// ```swift
/// // Navigate to a route
/// coordinator.navigate(to: .listingDetail(item), in: .feed)
///
/// // Handle deep links
/// if let route = AppRoute(deepLink: url) {
///     coordinator.navigate(to: route)
/// }
/// ```
enum AppRoute: Hashable, Sendable {
    // MARK: - Feed Routes

    /// View details of a food listing
    case listingDetail(FoodItem)

    /// View all listings with optional category filter
    case allListings(category: String?)

    /// Create a new listing
    case createListing

    /// Edit an existing listing
    case editListing(FoodItem)

    // MARK: - Profile Routes

    /// View a user's profile
    case profile(userId: UUID)

    /// Edit current user's profile
    case editProfile

    /// View user's badges
    case badges(userId: UUID)

    /// View user's reviews
    case reviews(userId: UUID)

    /// Settings screen
    case settings

    /// Notification settings
    case notificationSettings

    /// Privacy settings
    case privacySettings

    /// Help and support
    case help

    /// About the app
    case about

    // MARK: - Messaging Routes

    /// View a conversation
    case conversation(roomId: UUID)

    /// Start a new conversation
    case newConversation(recipientId: UUID)

    /// View all messages
    case messageArchive

    // MARK: - Forum Routes

    /// View a forum post
    case forumPost(postId: Int)

    /// Create a new forum post
    case createForumPost

    /// Forum category listing
    case forumCategory(categoryId: Int)

    // MARK: - Challenge Routes

    /// View challenge details
    case challengeDetail(challengeId: Int)

    /// View all challenges
    case allChallenges

    /// Challenge leaderboard
    case leaderboard(challengeId: Int)

    // MARK: - Map Routes

    /// View map centered on location
    case mapLocation(latitude: Double, longitude: Double)

    /// View listings near location
    case nearbyListings(latitude: Double, longitude: Double, radiusKm: Double)

    // MARK: - Utility Routes

    /// Web content viewer
    case webView(title: String, url: URL)

    /// Full screen image viewer
    case imageViewer(urls: [URL], initialIndex: Int)

    /// Report content
    case report(contentType: ReportContentType, contentId: String)

    // MARK: - Tab Routes

    /// Switch to a specific tab
    case tab(Tab)
}

// MARK: - Tab Enum

/// Main app tabs
enum Tab: String, CaseIterable, Sendable {
    case feed = "Feed"
    case explore = "Explore"
    case challenges = "Challenges"
    case messaging = "Messages"
    case profile = "Profile"

    var icon: String {
        switch self {
        case .feed: "house.fill"
        case .explore: "map.fill"
        case .challenges: "trophy.fill"
        case .messaging: "bubble.left.and.bubble.right.fill"
        case .profile: "person.fill"
        }
    }

    var index: Int {
        switch self {
        case .feed: 0
        case .explore: 1
        case .challenges: 2
        case .messaging: 3
        case .profile: 4
        }
    }
}

// MARK: - Report Content Type

enum ReportContentType: String, Sendable {
    case listing
    case user
    case message
    case forumPost
    case review
}

// MARK: - Deep Link Support

extension AppRoute {
    /// Initialize from a deep link URL
    ///
    /// Supports URL schemes:
    /// - `foodshare://listing/{id}`
    /// - `foodshare://profile/{userId}`
    /// - `foodshare://conversation/{roomId}`
    /// - `foodshare://challenge/{id}`
    /// - `foodshare://forum/{postId}`
    ///
    /// - Parameter url: The deep link URL
    init?(deepLink url: URL) {
        guard url.scheme == "foodshare" || url.host == "foodshare.app" else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        guard !pathComponents.isEmpty else {
            return nil
        }

        switch pathComponents[0] {
        case "listing":
            guard pathComponents.count > 1,
                  let id = Int(pathComponents[1]) else { return nil }
            // Note: We'd need to fetch the FoodItem from ID
            // For now, this is a placeholder pattern
            return nil // Would need async fetch

        case "profile":
            guard pathComponents.count > 1,
                  let userId = UUID(uuidString: pathComponents[1]) else { return nil }
            self = .profile(userId: userId)

        case "conversation", "chat":
            guard pathComponents.count > 1,
                  let roomId = UUID(uuidString: pathComponents[1]) else { return nil }
            self = .conversation(roomId: roomId)

        case "challenge":
            guard pathComponents.count > 1,
                  let id = Int(pathComponents[1]) else { return nil }
            self = .challengeDetail(challengeId: id)

        case "forum", "post":
            guard pathComponents.count > 1,
                  let id = Int(pathComponents[1]) else { return nil }
            self = .forumPost(postId: id)

        case "settings":
            self = .settings

        case "help":
            self = .help

        case "create":
            if pathComponents.count > 1, pathComponents[1] == "listing" {
                self = .createListing
            } else {
                return nil
            }

        default:
            return nil
        }
    }

    /// Generate a deep link URL for this route
    var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "foodshare"

        switch self {
        case let .listingDetail(item):
            components.path = "/listing/\(item.id)"

        case let .profile(userId):
            components.path = "/profile/\(userId.uuidString)"

        case let .conversation(roomId):
            components.path = "/conversation/\(roomId.uuidString)"

        case let .challengeDetail(id):
            components.path = "/challenge/\(id)"

        case let .forumPost(id):
            components.path = "/forum/\(id)"

        case .settings:
            components.path = "/settings"

        case .help:
            components.path = "/help"

        case .createListing:
            components.path = "/create/listing"

        default:
            return nil
        }

        return components.url
    }
}

// MARK: - Destination Tab

extension AppRoute {
    /// The tab this route belongs to
    var destinationTab: Tab {
        switch self {
        case .listingDetail, .allListings, .createListing, .editListing:
            .feed
        case .profile, .editProfile, .badges, .reviews, .settings, .notificationSettings,
             .privacySettings, .help, .about:
            .profile
        case .conversation, .newConversation, .messageArchive:
            .messaging
        case .forumPost, .createForumPost, .forumCategory:
            .feed // Forum is accessed via feed in current UI
        case .challengeDetail, .allChallenges, .leaderboard:
            .challenges
        case .mapLocation, .nearbyListings:
            .explore
        case .webView, .imageViewer, .report:
            .feed // Utility views can be shown from any tab
        case let .tab(tab):
            tab
        }
    }
}
