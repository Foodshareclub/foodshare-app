//
//  PerformanceMonitor.swift
//  FoodShare
//
//  Actor-based performance monitoring with percentile tracking
//  Tracks view load times, network requests, and frame rates
//
//  Target Metrics:
//  - View load time: < 300ms (p95)
//  - Network requests: < 500ms (p95)
//  - Frame rate: 60fps minimum
//  - Memory: < 150MB average
//


#if !SKIP
import Foundation
import OSLog
#if !SKIP
import QuartzCore
#endif

// MARK: - Performance Metric Types

/// Types of operations to track
public enum PerformanceMetricType: String, Sendable, CaseIterable {
    case viewLoad = "view_load"
    case networkRequest = "network_request"
    case databaseQuery = "database_query"
    case imageLoad = "image_load"
    case animation
    case cacheOperation = "cache_operation"
    case custom

    /// Target duration in milliseconds (p95)
    public var targetP95Ms: Double {
        switch self {
        case .viewLoad: 300
        case .networkRequest: 500
        case .databaseQuery: 100
        case .imageLoad: 200
        case .animation: 16.67 // 60fps
        case .cacheOperation: 10
        case .custom: 1000
        }
    }
}

// MARK: - Metric Sample

private struct MetricSample: Sendable {
    let operation: String
    let type: PerformanceMetricType
    let durationMs: Double
    let timestamp: Date
    let metadata: [String: String]
}

// MARK: - Percentile Stats

public struct PercentileStats: Sendable {
    public let p50: Double
    public let p75: Double
    public let p90: Double
    public let p95: Double
    public let p99: Double
    public let min: Double
    public let max: Double
    public let mean: Double
    public let count: Int

    /// Whether p95 is within target
    public func isWithinTarget(_ targetP95: Double) -> Bool {
        p95 <= targetP95
    }
}

// MARK: - Performance Alert

public struct PerformanceAlert: Sendable, Identifiable {
    public let id = UUID()
    public let operation: String
    public let type: PerformanceMetricType
    public let actualMs: Double
    public let targetMs: Double
    public let timestamp: Date
    public let message: String
}

// MARK: - Performance Monitor Actor

/// Thread-safe performance monitoring using actor isolation
public actor PerformanceMonitor {
    /// Shared instance
    public static let shared = PerformanceMonitor()

    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "PerformanceMonitor")

    /// Maximum samples to keep per operation
    private let maxSamplesPerOperation = 1000

    /// Storage for metric samples
    private var samples: [String: [MetricSample]] = [:]

    /// Recent alerts
    private var alerts: [PerformanceAlert] = []

    /// Whether monitoring is enabled
    private var isEnabled = true

    /// Callback for performance alerts
    private var alertHandler: (@Sendable (PerformanceAlert) -> Void)?

    private init() {}

    // MARK: - Configuration

    /// Enable or disable monitoring
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    /// Set alert handler for performance violations
    public func setAlertHandler(_ handler: @escaping @Sendable (PerformanceAlert) -> Void) {
        alertHandler = handler
    }

    // MARK: - Measurement

    /// Measure the duration of an async operation
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - type: Type of metric
    ///   - metadata: Optional additional context
    ///   - block: The operation to measure
    /// - Returns: Result of the operation
    public func measure<T>(
        _ operation: String,
        type: PerformanceMetricType = .custom,
        metadata: [String: String] = [:],
        block: () async throws -> T,
    ) async rethrows -> T {
        guard isEnabled else {
            return try await block()
        }

        let startTime = CACurrentMediaTime()
        let result = try await block()
        let endTime = CACurrentMediaTime()

        let durationMs = (endTime - startTime) * 1000
        await recordSample(operation: operation, type: type, durationMs: durationMs, metadata: metadata)

        return result
    }

    /// Measure a synchronous operation
    public func measureSync<T>(
        _ operation: String,
        type: PerformanceMetricType = .custom,
        metadata: [String: String] = [:],
        block: () throws -> T,
    ) rethrows -> T {
        guard isEnabled else {
            return try block()
        }

        let startTime = CACurrentMediaTime()
        let result = try block()
        let endTime = CACurrentMediaTime()

        let durationMs = (endTime - startTime) * 1000

        // Record asynchronously to not block the caller
        Task {
            await recordSample(operation: operation, type: type, durationMs: durationMs, metadata: metadata)
        }

        return result
    }

    /// Record a pre-measured sample
    public func record(
        _ operation: String,
        type: PerformanceMetricType,
        durationMs: Double,
        metadata: [String: String] = [:],
    ) {
        Task {
            await recordSample(operation: operation, type: type, durationMs: durationMs, metadata: metadata)
        }
    }

    // MARK: - Percentile Retrieval

    /// Get percentile statistics for an operation
    public func getPercentiles(for operation: String) -> PercentileStats? {
        guard let operationSamples = samples[operation], !operationSamples.isEmpty else {
            return nil
        }

        let durations = operationSamples.map(\.durationMs).sorted()
        return calculatePercentiles(durations)
    }

    /// Get percentile statistics for a metric type
    public func getPercentiles(for type: PerformanceMetricType) -> PercentileStats? {
        let allSamples = samples.values
            .flatMap(\.self)
            .filter { $0.type == type }
            .map(\.durationMs)
            .sorted()

        guard !allSamples.isEmpty else { return nil }
        return calculatePercentiles(allSamples)
    }

    /// Get all operation names
    public func getOperations() -> [String] {
        Array(samples.keys).sorted()
    }

    /// Get sample count for an operation
    public func getSampleCount(for operation: String) -> Int {
        samples[operation]?.count ?? 0
    }

    // MARK: - Alerts

    /// Get recent performance alerts
    public func getAlerts(limit: Int = 50) -> [PerformanceAlert] {
        Array(alerts.suffix(limit))
    }

    /// Clear all alerts
    public func clearAlerts() {
        alerts.removeAll()
    }

    // MARK: - Cleanup

    /// Clear all samples for an operation
    public func clearSamples(for operation: String) {
        samples.removeValue(forKey: operation)
    }

    /// Clear all samples
    public func clearAllSamples() {
        samples.removeAll()
    }

    /// Prune old samples older than duration
    public func pruneSamples(olderThan duration: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-duration)

        for (operation, operationSamples) in samples {
            samples[operation] = operationSamples.filter { $0.timestamp > cutoff }
        }
    }

    // MARK: - Reporting

    /// Generate a performance report
    public func generateReport() -> PerformanceReport {
        var operationStats: [String: PercentileStats] = [:]

        for operation in samples.keys {
            if let stats = getPercentiles(for: operation) {
                operationStats[operation] = stats
            }
        }

        return PerformanceReport(
            generatedAt: Date(),
            operationStats: operationStats,
            alertCount: alerts.count,
            totalSampleCount: samples.values.reduce(0) { $0 + $1.count },
        )
    }

    // MARK: - Private Methods

    private func recordSample(
        operation: String,
        type: PerformanceMetricType,
        durationMs: Double,
        metadata: [String: String],
    ) {
        let sample = MetricSample(
            operation: operation,
            type: type,
            durationMs: durationMs,
            timestamp: Date(),
            metadata: metadata,
        )

        // Add sample
        if samples[operation] == nil {
            samples[operation] = []
        }
        samples[operation]?.append(sample)

        // Trim if needed
        if let count = samples[operation]?.count, count > maxSamplesPerOperation {
            samples[operation]?.removeFirst(count - maxSamplesPerOperation)
        }

        // Check for performance violation
        if durationMs > type.targetP95Ms {
            let alert = PerformanceAlert(
                operation: operation,
                type: type,
                actualMs: durationMs,
                targetMs: type.targetP95Ms,
                timestamp: Date(),
                message: "\(operation) took \(String(format: "%.0f", durationMs))ms (target: \(String(format: "%.0f", type.targetP95Ms))ms)",
            )

            alerts.append(alert)
            if alerts.count > 100 {
                alerts.removeFirst(alerts.count - 100)
            }

            alertHandler?(alert)

            logger.warning("Performance violation: \(alert.message)")
        }

        // Debug logging
        #if DEBUG
            logger.debug("\(type.rawValue).\(operation): \(String(format: "%.2f", durationMs))ms")
        #endif
    }

    private func calculatePercentiles(_ sortedValues: [Double]) -> PercentileStats {
        guard !sortedValues.isEmpty else {
            return PercentileStats(p50: 0, p75: 0, p90: 0, p95: 0, p99: 0, min: 0, max: 0, mean: 0, count: 0)
        }

        let count = sortedValues.count
        let sum = sortedValues.reduce(0, +)

        func percentile(_ p: Double) -> Double {
            let index = Int((Double(count - 1) * p).rounded())
            return sortedValues[min(index, count - 1)]
        }

        return PercentileStats(
            p50: percentile(0.50),
            p75: percentile(0.75),
            p90: percentile(0.90),
            p95: percentile(0.95),
            p99: percentile(0.99),
            min: sortedValues.first ?? 0,
            max: sortedValues.last ?? 0,
            mean: sum / Double(count),
            count: count,
        )
    }
}

// MARK: - Performance Report

public struct PerformanceReport: Sendable {
    public let generatedAt: Date
    public let operationStats: [String: PercentileStats]
    public let alertCount: Int
    public let totalSampleCount: Int

    /// Operations that are within their target p95
    public var healthyOperations: [String] {
        operationStats.filter { _, stats in
            // Default target if not specified
            stats.p95 <= 500
        }.map(\.key).sorted()
    }

    /// Operations exceeding their target p95
    public var unhealthyOperations: [String] {
        operationStats.filter { _, stats in
            stats.p95 > 500
        }.map(\.key).sorted()
    }
}

// MARK: - Convenience Extensions

extension PerformanceMonitor {
    /// Measure a view load
    public func measureViewLoad<T>(
        _ viewName: String,
        block: () async throws -> T,
    ) async rethrows -> T {
        try await measure(viewName, type: .viewLoad, block: block)
    }

    /// Measure a network request
    public func measureNetworkRequest<T>(
        _ endpoint: String,
        block: () async throws -> T,
    ) async rethrows -> T {
        try await measure(endpoint, type: .networkRequest, block: block)
    }

    /// Measure a database query
    public func measureDatabaseQuery<T>(
        _ queryName: String,
        block: () async throws -> T,
    ) async rethrows -> T {
        try await measure(queryName, type: .databaseQuery, block: block)
    }
}

// MARK: - Scoped Measurement Token

/// Token for manual start/stop measurement
public struct MeasurementToken: Sendable {
    let operation: String
    let type: PerformanceMetricType
    let startTime: CFAbsoluteTime
    let metadata: [String: String]

    init(operation: String, type: PerformanceMetricType, metadata: [String: String]) {
        self.operation = operation
        self.type = type
        startTime = CACurrentMediaTime()
        self.metadata = metadata
    }

    /// End the measurement and record the sample
    public func end() {
        let durationMs = (CACurrentMediaTime() - startTime) * 1000
        Task {
            await PerformanceMonitor.shared.record(operation, type: type, durationMs: durationMs, metadata: metadata)
        }
    }
}

extension PerformanceMonitor {
    /// Start a measurement that can be ended manually
    public nonisolated func startMeasurement(
        _ operation: String,
        type: PerformanceMetricType = .custom,
        metadata: [String: String] = [:],
    ) -> MeasurementToken {
        MeasurementToken(operation: operation, type: type, metadata: metadata)
    }
}

#endif
