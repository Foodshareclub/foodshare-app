//
//  FeedPreferencesService.swift
//  FoodShare
//
//  Service layer for feed user preferences including radius, sort, and view mode.
//  Manages local storage and database synchronization.
//

import Foundation
import OSLog

// MARK: - Feed Preferences Service Protocol

/// Protocol for managing feed user preferences
@MainActor
protocol FeedPreferencesServiceProtocol {
    /// Gets the current view mode
    var viewMode: FeedViewMode { get }

    /// Gets the current sort option
    var sortOption: FeedSortOption { get }

    /// Gets saved item IDs
    var savedItems: Set<Int> { get }

    /// Gets preferred category IDs
    var preferredCategories: [Int] { get }

    /// Sets the view mode
    func setViewMode(_ mode: FeedViewMode)

    /// Sets the sort option
    func setSortOption(_ option: FeedSortOption)

    /// Toggles a saved item
    func toggleSavedItem(_ itemId: Int) -> Bool

    /// Adds a category to preferences
    func addPreferredCategory(_ categoryId: Int)

    /// Checks if an item is saved
    func isItemSaved(_ itemId: Int) -> Bool

    /// Loads preferences from storage
    func loadPreferences()

    /// Saves preferences to storage
    func savePreferences()
}

// MARK: - Feed View Mode

enum FeedViewMode: String, CaseIterable, Sendable {
    case list = "List"
    case grid = "Grid"

    var icon: String {
        switch self {
        case .list: "list.bullet"
        case .grid: "square.grid.2x2"
        }
    }

    var localizedKey: String {
        switch self {
        case .list: "feed.view.list"
        case .grid: "feed.view.grid"
        }
    }
}

// MARK: - Feed Preferences Service

/// Default implementation of FeedPreferencesServiceProtocol
@MainActor
final class FeedPreferencesService: FeedPreferencesServiceProtocol {
    // MARK: - Properties

    private(set) var viewMode: FeedViewMode = .list
    private(set) var sortOption: FeedSortOption = .nearest
    private(set) var savedItems: Set<Int> = []
    private(set) var preferredCategories: [Int] = []

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "FeedPreferencesService")

    // MARK: - Keys

    private enum Keys {
        static let viewMode = "feedViewMode"
        static let sortOption = "feedSortOption"
        static let savedItems = "savedItems"
        static let preferredCategories = "preferredCategories"
        static let searchRadius = "feedSearchRadius"
    }

    // MARK: - Initialization

    init() {
        loadPreferences()
    }

    // MARK: - View Mode

    func setViewMode(_ mode: FeedViewMode) {
        viewMode = mode
        savePreferences()
        HapticManager.selection()
    }

    // MARK: - Sort Option

    func setSortOption(_ option: FeedSortOption) {
        sortOption = option
        savePreferences()
        HapticManager.selection()
    }

    // MARK: - Saved Items

    func toggleSavedItem(_ itemId: Int) -> Bool {
        if savedItems.contains(itemId) {
            savedItems.remove(itemId)
            savePreferences()
            HapticManager.light()
            return false
        } else {
            savedItems.insert(itemId)
            savePreferences()
            HapticManager.light()
            return true
        }
    }

    func isItemSaved(_ itemId: Int) -> Bool {
        savedItems.contains(itemId)
    }

    // MARK: - Preferred Categories

    func addPreferredCategory(_ categoryId: Int) {
        if !preferredCategories.contains(categoryId) {
            preferredCategories.append(categoryId)
            if preferredCategories.count > 5 {
                preferredCategories.removeFirst()
            }
            savePreferences()
        }
    }

    // MARK: - Persistence

    func loadPreferences() {
        if let modeString = defaults.string(forKey: Keys.viewMode),
           let mode = FeedViewMode(rawValue: modeString) {
            viewMode = mode
        }

        if let sortString = defaults.string(forKey: Keys.sortOption),
           let sort = FeedSortOption(rawValue: sortString) {
            sortOption = sort
        }

        savedItems = Set(defaults.array(forKey: Keys.savedItems) as? [Int] ?? [])
        preferredCategories = defaults.array(forKey: Keys.preferredCategories) as? [Int] ?? []

        logger.debug("Loaded preferences: viewMode=\(self.viewMode.rawValue), sortOption=\(self.sortOption.rawValue)")
    }

    func savePreferences() {
        defaults.set(viewMode.rawValue, forKey: Keys.viewMode)
        defaults.set(sortOption.rawValue, forKey: Keys.sortOption)
        defaults.set(Array(savedItems), forKey: Keys.savedItems)
        defaults.set(preferredCategories, forKey: Keys.preferredCategories)
    }
}

// MARK: - Search Radius Service

/// Service for managing search radius with database sync
@MainActor
final class FeedSearchRadiusService {
    // MARK: - State

    enum State: Sendable {
        case loading
        case loaded(Double)
        case guest(Double)

        var radius: Double {
            switch self {
            case .loading:
                return 5.0 // Default search radius; actual value loaded from AppConfiguration
            case .loaded(let radius), .guest(let radius):
                return radius
            }
        }

        var isReady: Bool {
            if case .loading = self { return false }
            return true
        }
    }

    // MARK: - Properties

    private(set) var state: State = .loading

    private let profileRepository: (any ProfileRepository)?
    private let getCurrentUserId: () -> UUID?
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "FeedSearchRadiusService")

    // MARK: - Initialization

    init(
        profileRepository: (any ProfileRepository)?,
        getCurrentUserId: @escaping () -> UUID?,
        isGuestMode: Bool
    ) {
        self.profileRepository = profileRepository
        self.getCurrentUserId = getCurrentUserId

        if isGuestMode || getCurrentUserId() == nil {
            self.state = .guest(AppConfiguration.shared.defaultSearchRadiusKm)
        }
    }

    // MARK: - Load from Database

    func loadFromDatabase() async {
        let defaultRadius = AppConfiguration.shared.defaultSearchRadiusKm

        guard let userId = getCurrentUserId(), let repository = profileRepository else {
            state = .guest(defaultRadius)
            logger.debug("Cannot load search radius from DB - no user or repository")
            return
        }

        do {
            let profile = try await repository.fetchProfile(userId: userId)
            if let dbRadius = profile.searchRadiusKm, dbRadius > 0 {
                state = .loaded(Double(dbRadius))
                saveToLocalStorage(Double(dbRadius))
                logger.info("Loaded search radius from database: \(dbRadius)km")
            } else {
                state = .loaded(defaultRadius)
                logger.info("No search radius in profile, using default: \(defaultRadius)km")
            }
        } catch {
            let cached = UserDefaults.standard.double(forKey: "feedSearchRadius")
            let fallbackRadius = cached > 0 ? cached : defaultRadius
            state = .guest(fallbackRadius)
            logger.warning("Failed to load search radius from database, using cached: \(fallbackRadius)km")
        }
    }

    // MARK: - Update Radius

    func updateRadius(_ radius: Double) async -> Bool {
        // Update locally first
        state = .loaded(radius)
        saveToLocalStorage(radius)

        // Persist to database if authenticated
        guard let userId = getCurrentUserId(), profileRepository != nil else {
            return true // Local-only update succeeded
        }

        return await persistWithRetry(userId: userId, radiusKm: Int(radius), maxRetries: 3)
    }

    // MARK: - Private Helpers

    private func saveToLocalStorage(_ radius: Double) {
        UserDefaults.standard.set(radius, forKey: "feedSearchRadius")
    }

    private func persistWithRetry(userId: UUID, radiusKm: Int, maxRetries: Int) async -> Bool {
        guard let repository = profileRepository else { return false }

        for attempt in 0...maxRetries {
            do {
                try await withTimeout(seconds: 5) {
                    try await repository.updateSearchRadius(userId: userId, radiusKm: radiusKm)
                }
                logger.info("Search radius synced to database: \(radiusKm)km")
                return true
            } catch {
                logger.warning("Search radius sync attempt \(attempt + 1)/\(maxRetries + 1) failed: \(error.localizedDescription)")

                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        logger.error("Search radius sync failed after \(maxRetries + 1) attempts")
        return false
    }

    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw FeedRadiusError.timeout
            }

            if let result = try await group.next() {
                group.cancelAll()
                return result
            }
            throw FeedRadiusError.timeout
        }
    }
}

enum FeedRadiusError: Error {
    case timeout
}
