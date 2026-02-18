//
//  AppStateManager.swift
//  Foodshare
//
//  Central state manager for cross-feature state synchronization
//  Solves the problem of searchRadius not syncing between Feed and Map
//
//  Design Principles:
//  - Single source of truth for shared state
//  - Observable for SwiftUI reactivity
//  - Persistence to UserDefaults + optional backend sync
//  - Thread-safe with @MainActor
//


#if !SKIP
#if !SKIP
import Combine
#endif
#if !SKIP
import CoreLocation
#endif
import Foundation
import Observation
import OSLog

/// Central manager for cross-feature state that needs to be synchronized
/// Examples: searchRadius, currentLocation, unread counts
@Observable
@MainActor
final class AppStateManager {
    // MARK: - Singleton

    static let shared = AppStateManager()

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AppStateManager")

    // MARK: - Search State

    /// Search radius in kilometers (synced between Feed and Map)
    private(set) var searchRadius = 5.0 {
        didSet {
            if oldValue != searchRadius {
                logger.info("Search radius changed: \(oldValue)km → \(self.searchRadius)km")
                persistSearchRadius()
                notifySearchRadiusChanged()
            }
        }
    }

    /// Default search radius
    static let defaultSearchRadius = 5.0

    /// Minimum search radius
    static let minimumSearchRadius = 1.0

    /// Maximum search radius
    static let maximumSearchRadius = 100.0

    // MARK: - Location State

    /// Current user location (shared across features)
    private(set) var currentLocation: CLLocationCoordinate2D?

    /// Last known city/area name
    private(set) var currentLocationName: String?

    // MARK: - Notification State

    /// Unread message count (for badge display)
    private(set) var unreadMessageCount = 0

    /// Unread notification count
    private(set) var unreadNotificationCount = 0

    // MARK: - User Preferences

    /// Distance unit preference (metric/imperial)
    private(set) var distanceUnit: DistanceUnit = .kilometers

    /// Whether to show distance in listings
    private(set) var showDistance = true

    // MARK: - Observers

    /// Notification name for search radius changes
    static let searchRadiusDidChangeNotification = Notification.Name("AppStateManager.searchRadiusDidChange")

    /// Notification name for location changes
    static let locationDidChangeNotification = Notification.Name("AppStateManager.locationDidChange")

    /// Publishers for reactive updates
    private let searchRadiusSubject = PassthroughSubject<Double, Never>()
    var searchRadiusPublisher: AnyPublisher<Double, Never> {
        searchRadiusSubject.eraseToAnyPublisher()
    }

    // MARK: - Persistence Keys

    private enum UserDefaultsKey {
        static let searchRadius = "app_state_search_radius"
        static let distanceUnit = "app_state_distance_unit"
        static let showDistance = "app_state_show_distance"
    }

    // MARK: - Initialization

    private init() {
        loadPersistedState()
    }

    // MARK: - Search Radius

    /// Update search radius with validation
    /// - Parameter radius: New radius in kilometers
    func updateSearchRadius(_ radius: Double) async {
        let clampedRadius = min(max(radius, Self.minimumSearchRadius), Self.maximumSearchRadius)

        guard clampedRadius != searchRadius else {
            logger.debug("Search radius unchanged: \(clampedRadius)km")
            return
        }

        searchRadius = clampedRadius

        // Optionally sync to backend profile
        await syncSearchRadiusToBackend()
    }

    /// Reset search radius to default
    func resetSearchRadius() async {
        await updateSearchRadius(Self.defaultSearchRadius)
    }

    // MARK: - Location

    /// Update current location
    /// - Parameters:
    ///   - coordinate: New coordinate
    ///   - name: Optional location name (city, area)
    func updateLocation(_ coordinate: CLLocationCoordinate2D?, name: String? = nil) {
        let changed = currentLocation?.latitude != coordinate?.latitude ||
            currentLocation?.longitude != coordinate?.longitude

        currentLocation = coordinate
        currentLocationName = name

        if changed {
            logger.info("Location updated: \(coordinate?.latitude ?? 0), \(coordinate?.longitude ?? 0)")
            NotificationCenter.default.post(
                name: Self.locationDidChangeNotification,
                object: self,
                userInfo: ["coordinate": coordinate as Any],
            )
        }
    }

    // MARK: - Notifications

    /// Update unread message count
    /// - Parameter count: New unread count
    func updateUnreadMessageCount(_ count: Int) {
        guard count != unreadMessageCount else { return }
        unreadMessageCount = max(0, count)
        logger.debug("Unread message count: \(self.unreadMessageCount)")
    }

    /// Increment unread message count
    func incrementUnreadMessages() {
        unreadMessageCount += 1
    }

    /// Clear unread messages
    func clearUnreadMessages() {
        unreadMessageCount = 0
    }

    /// Update unread notification count
    /// - Parameter count: New unread count
    func updateUnreadNotificationCount(_ count: Int) {
        guard count != unreadNotificationCount else { return }
        unreadNotificationCount = max(0, count)
        logger.debug("Unread notification count: \(self.unreadNotificationCount)")
    }

    // MARK: - Preferences

    /// Update distance unit preference
    /// - Parameter unit: New distance unit
    func updateDistanceUnit(_ unit: DistanceUnit) {
        guard unit != distanceUnit else { return }
        distanceUnit = unit
        UserDefaults.standard.set(unit.rawValue, forKey: UserDefaultsKey.distanceUnit)
        logger.info("Distance unit changed to: \(unit.rawValue)")
    }

    /// Update show distance preference
    /// - Parameter show: Whether to show distance
    func updateShowDistance(_ show: Bool) {
        guard show != showDistance else { return }
        showDistance = show
        UserDefaults.standard.set(show, forKey: UserDefaultsKey.showDistance)
    }

    // MARK: - Persistence

    private func loadPersistedState() {
        let defaults = UserDefaults.standard

        // Load search radius
        if defaults.object(forKey: UserDefaultsKey.searchRadius) != nil {
            let saved = defaults.double(forKey: UserDefaultsKey.searchRadius)
            searchRadius = min(max(saved, Self.minimumSearchRadius), Self.maximumSearchRadius)
        }

        // Load distance unit
        if let unitRaw = defaults.string(forKey: UserDefaultsKey.distanceUnit),
           let unit = DistanceUnit(rawValue: unitRaw)
        {
            distanceUnit = unit
        }

        // Load show distance
        if defaults.object(forKey: UserDefaultsKey.showDistance) != nil {
            showDistance = defaults.bool(forKey: UserDefaultsKey.showDistance)
        }

        logger.info("Loaded persisted state: searchRadius=\(self.searchRadius)km, unit=\(self.distanceUnit.rawValue)")
    }

    private func persistSearchRadius() {
        UserDefaults.standard.set(searchRadius, forKey: UserDefaultsKey.searchRadius)
    }

    private func notifySearchRadiusChanged() {
        // Post notification for non-SwiftUI observers
        NotificationCenter.default.post(
            name: Self.searchRadiusDidChangeNotification,
            object: self,
            userInfo: ["radius": searchRadius],
        )

        // Publish for Combine subscribers
        searchRadiusSubject.send(searchRadius)
    }

    private func syncSearchRadiusToBackend() async {
        // Optional: sync to user profile in Supabase
        // This would use the ProfileRepository to update user preferences
        // For now, we just persist locally
        logger.debug("Search radius sync to backend: \(self.searchRadius)km (local only)")
    }

    // MARK: - State Reset

    /// Reset all state to defaults (for logout)
    func resetToDefaults() {
        searchRadius = Self.defaultSearchRadius
        currentLocation = nil
        currentLocationName = nil
        unreadMessageCount = 0
        unreadNotificationCount = 0
        distanceUnit = .kilometers
        showDistance = true

        // Clear persisted state
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: UserDefaultsKey.searchRadius)
        defaults.removeObject(forKey: UserDefaultsKey.distanceUnit)
        defaults.removeObject(forKey: UserDefaultsKey.showDistance)

        logger.info("AppStateManager reset to defaults")
    }
}

// MARK: - SwiftUI Environment Integration

import SwiftUI

extension EnvironmentValues {
    @Entry var appStateManager: AppStateManager = MainActor.assumeIsolated { AppStateManager.shared }
}

// MARK: - Preview Support

extension AppStateManager {
    /// Create a preview instance with custom state
    static func preview(
        searchRadius: Double = 5.0,
        unreadMessages: Int = 3,
    ) -> AppStateManager {
        let manager = AppStateManager.shared
        Task { @MainActor in
            await manager.updateSearchRadius(searchRadius)
            manager.updateUnreadMessageCount(unreadMessages)
        }
        return manager
    }
}

#endif
