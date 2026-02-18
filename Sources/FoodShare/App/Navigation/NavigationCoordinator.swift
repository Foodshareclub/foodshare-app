//
//  NavigationCoordinator.swift
//  Foodshare
//
//  Centralized navigation management for consistent routing across features
//
//  This provides:
//  - Unified navigation state across all tabs
//  - Deep link handling
//  - Navigation history management
//  - Tab coordination
//


#if !SKIP
import Foundation
import Observation
import OSLog
import SwiftUI

// MARK: - Navigation Coordinator

/// Centralized coordinator for all app navigation
///
/// Usage:
/// ```swift
/// // In your view
/// @Environment(NavigationCoordinator.self) var coordinator
///
/// // Navigate to a route
/// coordinator.navigate(to: .listingDetail(item))
///
/// // Pop back
/// coordinator.pop()
///
/// // Switch tabs
/// coordinator.switchTab(to: .profile)
/// ```
@MainActor
@Observable
final class NavigationCoordinator {
    // MARK: - Properties

    /// Navigation path for feed tab
    var feedPath = NavigationPath()

    /// Navigation path for explore tab
    var explorePath = NavigationPath()

    /// Navigation path for challenges tab
    var challengesPath = NavigationPath()

    /// Navigation path for messaging tab
    var messagingPath = NavigationPath()

    /// Navigation path for profile tab
    var profilePath = NavigationPath()

    /// Currently selected tab
    var selectedTab: Tab = .feed

    /// Sheet presentation state
    var presentedSheet: AppRoute?

    /// Full screen cover state
    var presentedFullScreen: AppRoute?

    /// Alert to show
    var alertRoute: AppRoute?

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "Navigation")

    // MARK: - Navigation

    /// Navigate to a route
    ///
    /// - Parameters:
    ///   - route: The destination route
    ///   - style: How to present the route (push, sheet, fullScreen)
    func navigate(to route: AppRoute, style: PresentationStyle = .push) {
        logger.debug("Navigating to: \(String(describing: route))")

        switch style {
        case .push:
            pushRoute(route)
        case .sheet:
            presentedSheet = route
        case .fullScreen:
            presentedFullScreen = route
        }
    }

    /// Push a route onto the appropriate navigation stack
    private func pushRoute(_ route: AppRoute) {
        let tab = route.destinationTab

        // Switch to the correct tab if needed
        if selectedTab != tab {
            selectedTab = tab
        }

        // Push onto the appropriate path
        switch tab {
        case .feed:
            feedPath.append(route)
        case .explore:
            explorePath.append(route)
        case .challenges:
            challengesPath.append(route)
        case .messaging:
            messagingPath.append(route)
        case .profile:
            profilePath.append(route)
        }
    }

    /// Pop the current view from the selected tab's stack
    func pop() {
        switch selectedTab {
        case .feed:
            if !feedPath.isEmpty { feedPath.removeLast() }
        case .explore:
            if !explorePath.isEmpty { explorePath.removeLast() }
        case .challenges:
            if !challengesPath.isEmpty { challengesPath.removeLast() }
        case .messaging:
            if !messagingPath.isEmpty { messagingPath.removeLast() }
        case .profile:
            if !profilePath.isEmpty { profilePath.removeLast() }
        }
    }

    /// Pop to the root of the selected tab
    func popToRoot() {
        switch selectedTab {
        case .feed:
            feedPath = NavigationPath()
        case .explore:
            explorePath = NavigationPath()
        case .challenges:
            challengesPath = NavigationPath()
        case .messaging:
            messagingPath = NavigationPath()
        case .profile:
            profilePath = NavigationPath()
        }
    }

    /// Pop to root for a specific tab
    func popToRoot(tab: Tab) {
        switch tab {
        case .feed:
            feedPath = NavigationPath()
        case .explore:
            explorePath = NavigationPath()
        case .challenges:
            challengesPath = NavigationPath()
        case .messaging:
            messagingPath = NavigationPath()
        case .profile:
            profilePath = NavigationPath()
        }
    }

    /// Switch to a specific tab
    func switchTab(to tab: Tab) {
        logger.debug("Switching to tab: \(tab.rawValue)")
        selectedTab = tab
    }

    /// Dismiss any presented sheet or full screen
    func dismiss() {
        if presentedFullScreen != nil {
            presentedFullScreen = nil
        } else if presentedSheet != nil {
            presentedSheet = nil
        } else {
            pop()
        }
    }

    // MARK: - Deep Link Handling

    /// Handle a deep link URL
    ///
    /// - Parameter url: The deep link URL
    /// - Returns: Whether the URL was handled
    @discardableResult
    func handleDeepLink(_ url: URL) -> Bool {
        logger.info("Handling deep link: \(url.absoluteString)")

        guard let route = AppRoute(deepLink: url) else {
            logger.warning("Could not parse deep link: \(url.absoluteString)")
            return false
        }

        // Pop to root of destination tab first
        popToRoot(tab: route.destinationTab)

        // Navigate to the route
        navigate(to: route)

        return true
    }

    // MARK: - Path for Tab

    /// Get the navigation path binding for a tab
    func path(for tab: Tab) -> Binding<NavigationPath> {
        switch tab {
        case .feed:
            Binding(
                get: { self.feedPath },
                set: { self.feedPath = $0 },
            )
        case .explore:
            Binding(
                get: { self.explorePath },
                set: { self.explorePath = $0 },
            )
        case .challenges:
            Binding(
                get: { self.challengesPath },
                set: { self.challengesPath = $0 },
            )
        case .messaging:
            Binding(
                get: { self.messagingPath },
                set: { self.messagingPath = $0 },
            )
        case .profile:
            Binding(
                get: { self.profilePath },
                set: { self.profilePath = $0 },
            )
        }
    }

    // MARK: - Current State

    /// Whether the current tab has navigation history
    var canGoBack: Bool {
        switch selectedTab {
        case .feed: !feedPath.isEmpty
        case .explore: !explorePath.isEmpty
        case .challenges: !challengesPath.isEmpty
        case .messaging: !messagingPath.isEmpty
        case .profile: !profilePath.isEmpty
        }
    }

    /// Total navigation depth across all tabs
    var totalDepth: Int {
        feedPath.count + explorePath.count + challengesPath.count +
            messagingPath.count + profilePath.count
    }
}

// MARK: - Presentation Style

enum PresentationStyle: Sendable {
    case push
    case sheet
    case fullScreen
}

// MARK: - Environment Key

/// Environment key for NavigationCoordinator using the @Observable pattern
/// The coordinator must be injected via .environment() at the app root
private struct NavigationCoordinatorKey: EnvironmentKey {
    static let defaultValue: NavigationCoordinator? = nil
}

extension EnvironmentValues {
    var navigationCoordinator: NavigationCoordinator? {
        get { self[NavigationCoordinatorKey.self] }
        set { self[NavigationCoordinatorKey.self] = newValue }
    }
}

// MARK: - Navigation Link Builder

/// Helper for creating navigation links with AppRoute
@MainActor
struct AppNavigationLink<Label: View>: View {
    let route: AppRoute
    let label: Label
    @Environment(\.navigationCoordinator) private var coordinator

    init(to route: AppRoute, @ViewBuilder label: () -> Label) {
        self.route = route
        self.label = label()
    }

    var body: some View {
        Button {
            coordinator?.navigate(to: route)
        } label: {
            label
        }
    }
}

#endif
