//
//  AnalyticsEventCatalog.swift
//  FoodShare
//
//  Type-safe analytics event definitions
//  Eliminates inconsistent event naming and ensures proper parameter types
//

import Foundation

// MARK: - Analytics Event Protocol

/// Protocol for all analytics events
public protocol AnalyticsEventProtocol: Sendable {
    /// Event name (used by analytics providers)
    var eventName: String { get }

    /// Event parameters
    var parameters: [String: Any] { get }

    /// Event category for grouping
    var category: AnalyticsCategory { get }
}

// MARK: - Analytics Category

/// Categories for organizing analytics events
public enum AnalyticsCategory: String, Sendable {
    case authentication = "auth"
    case listing
    case search
    case messaging
    case profile
    case engagement
    case navigation
    case error
    case performance
    case onboarding
    case subscription
    case challenge
    case forum
}

// MARK: - Authentication Events

public enum AuthAnalyticsEvent: AnalyticsEventProtocol, Sendable {
    case signUp(method: AuthMethod)
    case signIn(method: AuthMethod)
    case signOut
    case signInFailed(method: AuthMethod, errorCode: String?)
    case passwordReset
    case emailVerified
    case accountDeleted

    public var eventName: String {
        switch self {
        case .signUp: "sign_up"
        case .signIn: "sign_in"
        case .signOut: "sign_out"
        case .signInFailed: "sign_in_failed"
        case .passwordReset: "password_reset"
        case .emailVerified: "email_verified"
        case .accountDeleted: "account_deleted"
        }
    }

    public var parameters: [String: Any] {
        switch self {
        case let .signUp(method):
            ["method": method.rawValue]
        case let .signIn(method):
            ["method": method.rawValue]
        case .signOut, .passwordReset, .emailVerified, .accountDeleted:
            [:]
        case let .signInFailed(method, errorCode):
            [
                "method": method.rawValue,
                "error_code": errorCode ?? "unknown",
            ]
        }
    }

    public var category: AnalyticsCategory {
        .authentication
    }
}

public enum AuthMethod: String, Sendable {
    case email
    case apple
    case google
    case guest
}

// MARK: - Listing Events

public enum ListingAnalyticsEvent: AnalyticsEventProtocol, Sendable {
    case created(categoryId: Int?, hasImages: Bool, itemCount: Int)
    case viewed(listingId: Int, source: ListingViewSource)
    case shared(listingId: Int, method: ShareMethod)
    case saved(listingId: Int)
    case unsaved(listingId: Int)
    case claimed(listingId: Int)
    case completed(listingId: Int)
    case deleted(listingId: Int)
    case edited(listingId: Int, fieldsChanged: [String])
    case imageAdded(listingId: Int, imageCount: Int)
    case locationSet(listingId: Int, hasCoordinates: Bool)

    public var eventName: String {
        switch self {
        case .created: "listing_created"
        case .viewed: "listing_viewed"
        case .shared: "listing_shared"
        case .saved: "listing_saved"
        case .unsaved: "listing_unsaved"
        case .claimed: "listing_claimed"
        case .completed: "listing_completed"
        case .deleted: "listing_deleted"
        case .edited: "listing_edited"
        case .imageAdded: "listing_image_added"
        case .locationSet: "listing_location_set"
        }
    }

    public var parameters: [String: Any] {
        switch self {
        case let .created(categoryId, hasImages, itemCount):
            [
                "category_id": categoryId ?? -1,
                "has_images": hasImages,
                "item_count": itemCount,
            ]
        case let .viewed(listingId, source):
            [
                "listing_id": listingId,
                "source": source.rawValue,
            ]
        case let .shared(listingId, method):
            [
                "listing_id": listingId,
                "method": method.rawValue,
            ]
        case let .saved(listingId), let .unsaved(listingId), let .claimed(listingId),
             let .completed(listingId), let .deleted(listingId):
            ["listing_id": listingId]
        case let .edited(listingId, fieldsChanged):
            [
                "listing_id": listingId,
                "fields_changed": fieldsChanged.joined(separator: ","),
                "fields_count": fieldsChanged.count,
            ]
        case let .imageAdded(listingId, imageCount):
            [
                "listing_id": listingId,
                "image_count": imageCount,
            ]
        case let .locationSet(listingId, hasCoordinates):
            [
                "listing_id": listingId,
                "has_coordinates": hasCoordinates,
            ]
        }
    }

    public var category: AnalyticsCategory {
        .listing
    }
}

public enum ListingViewSource: String, Sendable {
    case feed
    case search
    case map
    case profile
    case deepLink
    case notification
    case share
}

public enum ShareMethod: String, Sendable {
    case copy
    case messages
    case mail
    case social
    case other
}

// MARK: - Search Events

public enum SearchAnalyticsEvent: AnalyticsEventProtocol, Sendable {
    case performed(query: String, resultsCount: Int, radiusKm: Double?)
    case filterApplied(filterType: String, value: String)
    case resultTapped(listingId: Int, position: Int)
    case noResults(query: String)
    case cleared

    public var eventName: String {
        switch self {
        case .performed: "search_performed"
        case .filterApplied: "search_filter_applied"
        case .resultTapped: "search_result_tapped"
        case .noResults: "search_no_results"
        case .cleared: "search_cleared"
        }
    }

    public var parameters: [String: Any] {
        switch self {
        case let .performed(query, resultsCount, radiusKm):
            [
                "query": query,
                "query_length": query.count,
                "results_count": resultsCount,
                "radius_km": radiusKm ?? -1,
            ]
        case let .filterApplied(filterType, value):
            [
                "filter_type": filterType,
                "filter_value": value,
            ]
        case let .resultTapped(listingId, position):
            [
                "listing_id": listingId,
                "position": position,
            ]
        case let .noResults(query):
            [
                "query": query,
                "query_length": query.count,
            ]
        case .cleared:
            [:]
        }
    }

    public var category: AnalyticsCategory {
        .search
    }
}

// MARK: - Messaging Events

public enum MessagingAnalyticsEvent: AnalyticsEventProtocol, Sendable {
    case conversationStarted(listingId: Int)
    case messageSent(roomId: String, messageLength: Int)
    case messageRead(roomId: String)
    case conversationArchived(roomId: String)
    case conversationDeleted(roomId: String)

    public var eventName: String {
        switch self {
        case .conversationStarted: "conversation_started"
        case .messageSent: "message_sent"
        case .messageRead: "message_read"
        case .conversationArchived: "conversation_archived"
        case .conversationDeleted: "conversation_deleted"
        }
    }

    public var parameters: [String: Any] {
        switch self {
        case let .conversationStarted(listingId):
            ["listing_id": listingId]
        case let .messageSent(roomId, messageLength):
            [
                "room_id": roomId,
                "message_length": messageLength,
            ]
        case let .messageRead(roomId), let .conversationArchived(roomId),
             let .conversationDeleted(roomId):
            ["room_id": roomId]
        }
    }

    public var category: AnalyticsCategory {
        .messaging
    }
}

// MARK: - Engagement Events

public enum EngagementAnalyticsEvent: AnalyticsEventProtocol, Sendable {
    case appOpened(source: AppOpenSource)
    case screenViewed(screenName: String, className: String?)
    case buttonTapped(buttonName: String, context: String?)
    case feedRefreshed(itemCount: Int)
    case pullToRefresh(screenName: String)
    case scrolledToEnd(screenName: String)
    case sessionStarted
    case sessionEnded(durationSeconds: Int)

    public var eventName: String {
        switch self {
        case .appOpened: "app_opened"
        case .screenViewed: "screen_viewed"
        case .buttonTapped: "button_tapped"
        case .feedRefreshed: "feed_refreshed"
        case .pullToRefresh: "pull_to_refresh"
        case .scrolledToEnd: "scrolled_to_end"
        case .sessionStarted: "session_started"
        case .sessionEnded: "session_ended"
        }
    }

    public var parameters: [String: Any] {
        switch self {
        case let .appOpened(source):
            ["source": source.rawValue]
        case let .screenViewed(screenName, className):
            [
                "screen_name": screenName,
                "class_name": className ?? "",
            ]
        case let .buttonTapped(buttonName, context):
            [
                "button_name": buttonName,
                "context": context ?? "",
            ]
        case let .feedRefreshed(itemCount):
            ["item_count": itemCount]
        case let .pullToRefresh(screenName), let .scrolledToEnd(screenName):
            ["screen_name": screenName]
        case .sessionStarted:
            [:]
        case let .sessionEnded(durationSeconds):
            ["duration_seconds": durationSeconds]
        }
    }

    public var category: AnalyticsCategory {
        .engagement
    }
}

public enum AppOpenSource: String, Sendable {
    case normal
    case deepLink
    case notification
    case widget
    case spotlight
    case shortcut
}

// MARK: - Error Events

public enum ErrorAnalyticsEvent: AnalyticsEventProtocol, Sendable {
    case apiError(endpoint: String, statusCode: Int, message: String?)
    case networkError(type: String)
    case validationError(field: String, reason: String)
    case crashRecovered(crashId: String?)
    case unexpectedState(context: String, state: String)

    public var eventName: String {
        switch self {
        case .apiError: "api_error"
        case .networkError: "network_error"
        case .validationError: "validation_error"
        case .crashRecovered: "crash_recovered"
        case .unexpectedState: "unexpected_state"
        }
    }

    public var parameters: [String: Any] {
        switch self {
        case let .apiError(endpoint, statusCode, message):
            [
                "endpoint": endpoint,
                "status_code": statusCode,
                "message": message ?? "",
            ]
        case let .networkError(type):
            ["type": type]
        case let .validationError(field, reason):
            [
                "field": field,
                "reason": reason,
            ]
        case let .crashRecovered(crashId):
            ["crash_id": crashId ?? "unknown"]
        case let .unexpectedState(context, state):
            [
                "context": context,
                "state": state,
            ]
        }
    }

    public var category: AnalyticsCategory {
        .error
    }
}

// MARK: - Analytics Event (Unified)

/// Unified analytics event enum containing all event types
public enum AnalyticsEvent: AnalyticsEventProtocol, Sendable {
    case auth(AuthAnalyticsEvent)
    case listing(ListingAnalyticsEvent)
    case search(SearchAnalyticsEvent)
    case messaging(MessagingAnalyticsEvent)
    case engagement(EngagementAnalyticsEvent)
    case error(ErrorAnalyticsEvent)

    public var eventName: String {
        switch self {
        case let .auth(event): event.eventName
        case let .listing(event): event.eventName
        case let .search(event): event.eventName
        case let .messaging(event): event.eventName
        case let .engagement(event): event.eventName
        case let .error(event): event.eventName
        }
    }

    public var parameters: [String: Any] {
        switch self {
        case let .auth(event): event.parameters
        case let .listing(event): event.parameters
        case let .search(event): event.parameters
        case let .messaging(event): event.parameters
        case let .engagement(event): event.parameters
        case let .error(event): event.parameters
        }
    }

    public var category: AnalyticsCategory {
        switch self {
        case let .auth(event): event.category
        case let .listing(event): event.category
        case let .search(event): event.category
        case let .messaging(event): event.category
        case let .engagement(event): event.category
        case let .error(event): event.category
        }
    }
}

// MARK: - Analytics Tracker Protocol

/// Protocol for analytics tracking implementations
public protocol AnalyticsTrackerProtocol: Sendable {
    func track(_ event: any AnalyticsEventProtocol)
    func setUserProperty(_ name: String, value: String?)
    func setUserId(_ userId: String?)
}

// MARK: - Analytics Service

/// Central analytics service for tracking events
@MainActor
public final class AnalyticsService {
    public static let shared = AnalyticsService()

    private var trackers: [any AnalyticsTrackerProtocol] = []
    private var isEnabled = true

    private init() {}

    /// Add a tracker implementation
    public func addTracker(_ tracker: any AnalyticsTrackerProtocol) {
        trackers.append(tracker)
    }

    /// Enable or disable analytics
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Track an analytics event
    public func track(_ event: any AnalyticsEventProtocol) {
        guard isEnabled else { return }

        for tracker in trackers {
            tracker.track(event)
        }
    }

    /// Convenience method for unified events
    public func track(_ event: AnalyticsEvent) {
        track(event as any AnalyticsEventProtocol)
    }

    /// Set user ID for tracking
    public func setUserId(_ userId: String?) {
        for tracker in trackers {
            tracker.setUserId(userId)
        }
    }

    /// Set a user property
    public func setUserProperty(_ name: String, value: String?) {
        for tracker in trackers {
            tracker.setUserProperty(name, value: value)
        }
    }
}
