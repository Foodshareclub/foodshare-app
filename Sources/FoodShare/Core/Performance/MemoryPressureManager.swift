//
//  MemoryPressureManager.swift
//  FoodShare
//
//  Centralized memory pressure handling with automatic cache eviction.
//  Responds to iOS memory warnings and proactively manages resources.
//
//  Features:
//  - Memory warning observation
//  - Priority-based cache eviction
//  - Proactive memory monitoring
//  - Image cache integration
//  - Metrics reporting
//

import Foundation
import Observation
import OSLog
#if !SKIP
import UIKit
#endif

// MARK: - Memory Pressure Level

public enum MemoryPressureLevel: Int, Comparable, Sendable {
    case normal = 0
    case warning = 1
    case critical = 2
    case terminal = 3

    public static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var description: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        case .terminal: "Terminal"
        }
    }

    public var shouldEvictCaches: Bool {
        self >= .warning
    }

    public var shouldReduceAnimations: Bool {
        self >= .critical
    }
}

// MARK: - Memory Stats

public struct MemoryStats: Sendable {
    public let usedMB: Double
    public let availableMB: Double
    public let totalMB: Double
    public let pressureLevel: MemoryPressureLevel

    public var usagePercentage: Double {
        guard totalMB > 0 else { return 0 }
        return (usedMB / totalMB) * 100
    }

    public var isHealthy: Bool {
        pressureLevel == .normal
    }
}

// MARK: - Cache Priority

public enum CachePriority: Int, Comparable, Sendable {
    case low = 0 // Clear first (e.g., prefetched images)
    case medium = 1 // Clear under pressure (e.g., cached API responses)
    case high = 2 // Keep longer (e.g., user avatar, current view images)
    case critical = 3 // Clear last (e.g., auth tokens, user data)

    public static func < (lhs: CachePriority, rhs: CachePriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Evictable Cache Protocol

public protocol EvictableCache: AnyObject {
    var cacheIdentifier: String { get }
    var priority: CachePriority { get }
    var approximateSizeMB: Double { get }

    func evictAll()
    func evictLowPriority()
    func evictToSize(_ targetSizeMB: Double)
}

extension EvictableCache {
    public func evictLowPriority() {
        evictAll()
    }

    public func evictToSize(_ targetSizeMB: Double) {
        if approximateSizeMB > targetSizeMB {
            evictAll()
        }
    }
}

// MARK: - Memory Pressure Manager

@MainActor
@Observable
public final class MemoryPressureManager {
    public static let shared = MemoryPressureManager()

    // MARK: - Observable Properties

    public private(set) var currentLevel: MemoryPressureLevel = .normal
    public private(set) var stats: MemoryStats?
    public private(set) var lastEvictionDate: Date?

    // MARK: - Configuration

    public struct Configuration {
        public var warningThresholdMB: Double = 150
        public var criticalThresholdMB: Double = 250
        public var terminalThresholdMB: Double = 350
        public var monitoringInterval: TimeInterval = 5.0
        public var enableProactiveEviction = true

        public static let `default` = Configuration()
    }

    public var configuration: Configuration = .default

    // MARK: - Private Properties

    private var registeredCaches: [ObjectIdentifier: WeakCacheWrapper] = [:]
    private var monitoringTask: Task<Void, Never>?
    private var memoryWarningObserver: NSObjectProtocol?

    // Thresholds
    private var peakMemoryMB: Double = 0

    // Logger
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "MemoryPressureManager")

    // MARK: - Initialization

    private init() {
        setupMemoryWarningObserver()
        startMonitoring()
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        monitoringTask?.cancel()
    }

    // MARK: - Public API

    /// Register a cache for automatic eviction
    public func registerCache(_ cache: EvictableCache) {
        let id = ObjectIdentifier(cache)
        registeredCaches[id] = WeakCacheWrapper(cache: cache)
        cleanupStaleReferences()
    }

    /// Unregister a cache
    public func unregisterCache(_ cache: EvictableCache) {
        let id = ObjectIdentifier(cache)
        registeredCaches.removeValue(forKey: id)
    }

    /// Manually trigger cache eviction
    public func evictCaches(for level: MemoryPressureLevel) {
        let sortedCaches = registeredCaches.values
            .compactMap(\.cache)
            .sorted { $0.priority < $1.priority }

        switch level {
        case .normal:
            return

        case .warning:
            // Evict low priority caches
            for cache in sortedCaches where cache.priority <= .low {
                cache.evictAll()
                logEviction(cache: cache, reason: "memory_warning")
            }

        case .critical:
            // Evict low and medium priority caches
            for cache in sortedCaches where cache.priority <= .medium {
                cache.evictAll()
                logEviction(cache: cache, reason: "memory_critical")
            }

        case .terminal:
            // Evict everything except critical
            for cache in sortedCaches where cache.priority < .critical {
                cache.evictAll()
                logEviction(cache: cache, reason: "memory_terminal")
            }
        }

        lastEvictionDate = Date()

        logger.info("[Memory] Evicted caches for level: \(level.description)")
    }

    /// Get current memory statistics
    public func getCurrentStats() -> MemoryStats {
        let used = getUsedMemoryMB()
        let available = getAvailableMemoryMB()
        let total = getTotalMemoryMB()
        let level = calculatePressureLevel(usedMB: used)

        return MemoryStats(
            usedMB: used,
            availableMB: available,
            totalMB: total,
            pressureLevel: level,
        )
    }

    /// Force a memory cleanup
    public func performCleanup() {
        evictCaches(for: .warning)

        // Suggest garbage collection
        URLCache.shared.removeAllCachedResponses()

        // Post cleanup notification
        NotificationCenter.default.post(name: .memoryCleanupPerformed, object: nil)
    }

    // MARK: - Private Methods

    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main,
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleMemoryWarning()
            }
        }
    }

    private func startMonitoring() {
        monitoringTask?.cancel()

        monitoringTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.configuration.monitoringInterval ?? 5.0))

                guard !Task.isCancelled, let self else { break }

                await self.updateMemoryStatus()
            }
        }
    }

    private func updateMemoryStatus() {
        let newStats = getCurrentStats()
        stats = newStats

        // Track peak
        peakMemoryMB = max(peakMemoryMB, newStats.usedMB)

        // Update level
        let previousLevel = currentLevel
        currentLevel = newStats.pressureLevel

        // Proactive eviction
        if configuration.enableProactiveEviction, currentLevel > previousLevel {
            handlePressureLevelChange(from: previousLevel, to: currentLevel)
        }
    }

    private func handleMemoryWarning() {
        currentLevel = .critical
        evictCaches(for: .critical)

        // Report to metrics
        Task {
            await MetricsReporter.shared.record(event: .memoryWarning(
                level: currentLevel.description,
                usedMB: stats?.usedMB ?? 0,
            ))
        }
    }

    private func handlePressureLevelChange(from: MemoryPressureLevel, to: MemoryPressureLevel) {
        guard to > from else { return }

        evictCaches(for: to)

        // Notify observers
        NotificationCenter.default.post(
            name: .memoryPressureLevelChanged,
            object: nil,
            userInfo: ["level": to],
        )
    }

    private func calculatePressureLevel(usedMB: Double) -> MemoryPressureLevel {
        if usedMB >= configuration.terminalThresholdMB {
            return .terminal
        } else if usedMB >= configuration.criticalThresholdMB {
            return .critical
        } else if usedMB >= configuration.warningThresholdMB {
            return .warning
        }
        return .normal
    }

    private func cleanupStaleReferences() {
        registeredCaches = registeredCaches.filter { $0.value.cache != nil }
    }

    private func logEviction(cache: EvictableCache, reason: String) {
        logger.info(
            "[Memory] Evicted cache '\(cache.cacheIdentifier)' (~\(String(format: "%.1f", cache.approximateSizeMB))MB) - reason: \(reason)",
        )
    }

    // MARK: - Memory Measurement

    private func getUsedMemoryMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }
        return Double(info.resident_size) / 1024.0 / 1024.0
    }

    private func getAvailableMemoryMB() -> Double {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else { return 0 }

        let freePages = UInt64(vmStats.free_count)
        let inactivePages = UInt64(vmStats.inactive_count)
        let availableBytes = (freePages + inactivePages) * UInt64(pageSize)

        return Double(availableBytes) / 1024.0 / 1024.0
    }

    private func getTotalMemoryMB() -> Double {
        Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
    }
}

// MARK: - Weak Cache Wrapper

private final class WeakCacheWrapper {
    weak var cache: EvictableCache?

    init(cache: EvictableCache) {
        self.cache = cache
    }
}

// MARK: - Notifications

extension Notification.Name {
    public static let memoryPressureLevelChanged = Notification.Name("memoryPressureLevelChanged")
    public static let memoryCleanupPerformed = Notification.Name("memoryCleanupPerformed")
}

// MARK: - SwiftUI Environment

import SwiftUI

private struct MemoryPressureKey: EnvironmentKey {
    static let defaultValue: MemoryPressureLevel = .normal
}

extension EnvironmentValues {
    public var memoryPressure: MemoryPressureLevel {
        get { self[MemoryPressureKey.self] }
        set { self[MemoryPressureKey.self] = newValue }
    }
}

// MARK: - View Modifier

public struct MemoryAwareModifier: ViewModifier {
    @State private var manager = MemoryPressureManager.shared

    public func body(content: Content) -> some View {
        content
            .environment(\.memoryPressure, manager.currentLevel)
    }
}

extension View {
    /// Makes the view aware of memory pressure levels
    public func memoryAware() -> some View {
        modifier(MemoryAwareModifier())
    }
}
