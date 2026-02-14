//
//  ServiceProtocols.swift
//  FoodShare
//
//  Core protocols for dependency injection and testability.
//  Enables deterministic testing of ViewModels and services.
//

import Foundation

// MARK: - Date Provider

/// Protocol for providing the current date, enabling deterministic testing
protocol DateProviding: Sendable {
    /// Returns the current date
    func now() -> Date
}

/// Default implementation using system date
struct SystemDateProvider: DateProviding {
    func now() -> Date { Date() }
}

/// Mock implementation for testing with fixed date
struct MockDateProvider: DateProviding {
    let fixedDate: Date

    func now() -> Date { fixedDate }
}

// MARK: - Haptic Service

/// Protocol for haptic feedback, enabling testing without actual haptics
protocol HapticServiceProtocol: Sendable {
    func light()
    func medium()
    func heavy()
    func soft()
    func rigid()
    func selection()
    func success()
    func warning()
    func error()
}

/// Default implementation using HapticManager
struct SystemHapticService: HapticServiceProtocol {
    @MainActor
    func light() { HapticManager.light() }

    @MainActor
    func medium() { HapticManager.medium() }

    @MainActor
    func heavy() { HapticManager.heavy() }

    @MainActor
    func soft() { HapticManager.soft() }

    @MainActor
    func rigid() { HapticManager.rigid() }

    @MainActor
    func selection() { HapticManager.selection() }

    @MainActor
    func success() { HapticManager.success() }

    @MainActor
    func warning() { HapticManager.warning() }

    @MainActor
    func error() { HapticManager.error() }
}

/// Mock implementation for testing
final class MockHapticService: HapticServiceProtocol, @unchecked Sendable {
    private(set) var lightCallCount = 0
    private(set) var mediumCallCount = 0
    private(set) var heavyCallCount = 0
    private(set) var selectionCallCount = 0
    private(set) var successCallCount = 0

    func light() { lightCallCount += 1 }
    func medium() { mediumCallCount += 1 }
    func heavy() { heavyCallCount += 1 }
    func soft() { }
    func rigid() { }
    func selection() { selectionCallCount += 1 }
    func success() { successCallCount += 1 }
    func warning() { }
    func error() { }

    func reset() {
        lightCallCount = 0
        mediumCallCount = 0
        heavyCallCount = 0
        selectionCallCount = 0
        successCallCount = 0
    }
}

// MARK: - User Defaults Provider

/// Protocol for UserDefaults access, enabling testing without persistence
protocol UserDefaultsProviding: Sendable {
    func string(forKey key: String) -> String?
    func integer(forKey key: String) -> Int
    func double(forKey key: String) -> Double
    func bool(forKey key: String) -> Bool
    func array(forKey key: String) -> [Any]?

    func set(_ value: Any?, forKey key: String)
    func set(_ value: Int, forKey key: String)
    func set(_ value: Double, forKey key: String)
    func set(_ value: Bool, forKey key: String)

    func removeObject(forKey key: String)
    func synchronize() -> Bool
}

/// Default implementation using system UserDefaults
struct SystemUserDefaultsProvider: UserDefaultsProviding {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func string(forKey key: String) -> String? { defaults.string(forKey: key) }
    func integer(forKey key: String) -> Int { defaults.integer(forKey: key) }
    func double(forKey key: String) -> Double { defaults.double(forKey: key) }
    func bool(forKey key: String) -> Bool { defaults.bool(forKey: key) }
    func array(forKey key: String) -> [Any]? { defaults.array(forKey: key) }

    func set(_ value: Any?, forKey key: String) { defaults.set(value, forKey: key) }
    func set(_ value: Int, forKey key: String) { defaults.set(value, forKey: key) }
    func set(_ value: Double, forKey key: String) { defaults.set(value, forKey: key) }
    func set(_ value: Bool, forKey key: String) { defaults.set(value, forKey: key) }

    func removeObject(forKey key: String) { defaults.removeObject(forKey: key) }
    func synchronize() -> Bool { defaults.synchronize() }
}

/// In-memory implementation for testing
final class MockUserDefaultsProvider: UserDefaultsProviding, @unchecked Sendable {
    private var storage: [String: Any] = [:]

    func string(forKey key: String) -> String? { storage[key] as? String }
    func integer(forKey key: String) -> Int { storage[key] as? Int ?? 0 }
    func double(forKey key: String) -> Double { storage[key] as? Double ?? 0 }
    func bool(forKey key: String) -> Bool { storage[key] as? Bool ?? false }
    func array(forKey key: String) -> [Any]? { storage[key] as? [Any] }

    func set(_ value: Any?, forKey key: String) { storage[key] = value }
    func set(_ value: Int, forKey key: String) { storage[key] = value }
    func set(_ value: Double, forKey key: String) { storage[key] = value }
    func set(_ value: Bool, forKey key: String) { storage[key] = value }

    func removeObject(forKey key: String) { storage.removeValue(forKey: key) }
    func synchronize() -> Bool { true }

    func reset() { storage.removeAll() }
}

// MARK: - Network Connectivity

/// Protocol for checking network connectivity
protocol NetworkConnectivityProviding: Sendable {
    var isConnected: Bool { get }
    var connectionType: ConnectionType { get }
}

enum ConnectionType: Sendable {
    case wifi
    case cellular
    case none
}

// MARK: - Analytics Provider

/// Protocol for analytics events, enabling testing without actual tracking
protocol AnalyticsProviding: Sendable {
    func track(event: String, properties: [String: Any]?)
    func identify(userId: String, traits: [String: Any]?)
    func screen(name: String, properties: [String: Any]?)
}

/// Mock implementation for testing
final class MockAnalyticsProvider: AnalyticsProviding, @unchecked Sendable {
    private(set) var events: [(name: String, properties: [String: Any]?)] = []
    private(set) var screens: [(name: String, properties: [String: Any]?)] = []
    private(set) var identifiedUserId: String?

    func track(event: String, properties: [String: Any]?) {
        events.append((event, properties))
    }

    func identify(userId: String, traits: [String: Any]?) {
        identifiedUserId = userId
    }

    func screen(name: String, properties: [String: Any]?) {
        screens.append((name, properties))
    }

    func reset() {
        events.removeAll()
        screens.removeAll()
        identifiedUserId = nil
    }
}

// MARK: - Service Container

/// Dependency injection container for services
@MainActor
final class ServiceContainer {
    static let shared = ServiceContainer()

    var dateProvider: DateProviding = SystemDateProvider()
    var hapticService: HapticServiceProtocol = SystemHapticService()
    var userDefaults: UserDefaultsProviding = SystemUserDefaultsProvider()

    private init() {}

    /// Resets all services to defaults (for testing)
    func reset() {
        dateProvider = SystemDateProvider()
        hapticService = SystemHapticService()
        userDefaults = SystemUserDefaultsProvider()
    }

    /// Configures services for testing
    func configureForTesting(
        dateProvider: DateProviding? = nil,
        hapticService: HapticServiceProtocol? = nil,
        userDefaults: UserDefaultsProviding? = nil
    ) {
        if let dateProvider { self.dateProvider = dateProvider }
        if let hapticService { self.hapticService = hapticService }
        if let userDefaults { self.userDefaults = userDefaults }
    }
}

// MARK: - Testing Utilities

#if DEBUG
/// Utilities for testing
enum TestingUtilities {
    /// Creates a fixed date for testing (2024-01-15 12:00:00 UTC)
    static var fixedDate: Date {
        var components = DateComponents()
        components.year = 2024
        components.month = 1
        components.day = 15
        components.hour = 12
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Container for mock services used in testing
    struct MockContainer {
        let dateProvider: MockDateProvider
        let haptics: MockHapticService
        let defaults: MockUserDefaultsProvider
    }

    /// Creates a mock service container for testing
    static func createMockContainer() -> MockContainer {
        MockContainer(
            dateProvider: MockDateProvider(fixedDate: fixedDate),
            haptics: MockHapticService(),
            defaults: MockUserDefaultsProvider()
        )
    }
}
#endif
