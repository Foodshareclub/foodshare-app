//
//  MetricsReporter.swift
//  FoodShare
//
//  Client-side metrics collection and reporting.
//  Batches metrics for efficient transmission and handles offline scenarios.
//
//  Features:
//  - Automatic request duration tracking
//  - Circuit breaker state change reporting
//  - Cache hit/miss tracking
//  - Batched uploads (30-second intervals)
//  - Offline buffering with automatic retry
//
//  Usage:
//  ```swift
//  // Record a request
//  await MetricsReporter.shared.recordRequest(
//      endpoint: "/api/posts",
//      method: "GET",
//      statusCode: 200,
//      durationMs: 150,
//      cacheHit: false
//  )
//
//  // Record circuit breaker event
//  await MetricsReporter.shared.recordCircuitBreakerEvent(
//      circuitName: "supabase_rpc",
//      state: "open",
//      failureCount: 5
//  )
//  ```
//


#if !SKIP
import Foundation
import OSLog

// MARK: - Metric Types

/// A single API request metric
struct RequestMetric: Codable, Sendable {
    let id: UUID
    let endpoint: String
    let method: String
    let statusCode: Int?
    let responseTimeMs: Int
    let errorType: String?
    let cacheHit: Bool
    let requestSizeBytes: Int?
    let responseSizeBytes: Int?
    let timestamp: Date

    init(
        endpoint: String,
        method: String = "GET",
        statusCode: Int? = nil,
        responseTimeMs: Int,
        errorType: String? = nil,
        cacheHit: Bool = false,
        requestSizeBytes: Int? = nil,
        responseSizeBytes: Int? = nil,
    ) {
        self.id = UUID()
        self.endpoint = endpoint
        self.method = method
        self.statusCode = statusCode
        self.responseTimeMs = responseTimeMs
        self.errorType = errorType
        self.cacheHit = cacheHit
        self.requestSizeBytes = requestSizeBytes
        self.responseSizeBytes = responseSizeBytes
        self.timestamp = Date()
    }
}

/// A circuit breaker state change event
struct CircuitBreakerMetric: Codable, Sendable {
    let id: UUID
    let circuitName: String
    let state: String
    let previousState: String?
    let failureCount: Int
    let successCount: Int
    let consecutiveFailures: Int
    let triggerReason: String?
    let timestamp: Date

    init(
        circuitName: String,
        state: String,
        previousState: String? = nil,
        failureCount: Int = 0,
        successCount: Int = 0,
        consecutiveFailures: Int = 0,
        triggerReason: String? = nil,
    ) {
        self.id = UUID()
        self.circuitName = circuitName
        self.state = state
        self.previousState = previousState
        self.failureCount = failureCount
        self.successCount = successCount
        self.consecutiveFailures = consecutiveFailures
        self.triggerReason = triggerReason
        self.timestamp = Date()
    }
}

/// Metrics batch for upload
struct MetricsBatch: Codable, Sendable {
    let requests: [RequestMetric]
    let circuitEvents: [CircuitBreakerMetric]
    let deviceInfo: MetricsDeviceInfo
    let batchTimestamp: Date
}

/// Device information for metrics context
struct MetricsDeviceInfo: Codable, Sendable {
    let platform: String
    let appVersion: String
    let osVersion: String
    let deviceModel: String
    let locale: String

    @MainActor
    static var current: MetricsDeviceInfo {
        MetricsDeviceInfo(
            platform: "ios",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: "iPhone", // Simplified to avoid UIDevice dependency
            locale: Locale.current.identifier,
        )
    }
}

// MARK: - RPC Parameter Types

/// Parameters for recording a request metric
struct RecordRequestParams: Codable, Sendable {
    let p_endpoint: String
    let p_method: String
    let p_response_time_ms: Int
    let p_app_platform: String
    let p_app_version: String
    let p_cache_hit: Bool
    let p_status_code: Int?
    let p_error_type: String?
    let p_request_size: Int?
    let p_response_size: Int?
}

/// Parameters for recording a circuit breaker event
struct RecordCircuitEventParams: Codable, Sendable {
    let p_circuit_name: String
    let p_state: String
    let p_previous_state: String?
    let p_failure_count: Int
    let p_success_count: Int
    let p_consecutive_failures: Int
    let p_trigger_reason: String?
    let p_app_platform: String
}

// MARK: - Metrics Reporter

/// Actor-based metrics reporter with batching and offline support
actor MetricsReporter {

    // MARK: - Singleton

    static let shared = MetricsReporter()

    // MARK: - Configuration

    struct Configuration: Sendable {
        let batchIntervalSeconds: TimeInterval
        let maxBatchSize: Int
        let maxOfflineEvents: Int
        let enabledInDebug: Bool

        static let `default` = Configuration(
            batchIntervalSeconds: 30,
            maxBatchSize: 100,
            maxOfflineEvents: 500,
            enabledInDebug: true,
        )

        static let aggressive = Configuration(
            batchIntervalSeconds: 10,
            maxBatchSize: 50,
            maxOfflineEvents: 200,
            enabledInDebug: true,
        )
    }

    // MARK: - Properties

    private let configuration: Configuration
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "metrics")

    // Metric queues
    private var requestMetrics: [RequestMetric] = []
    private var circuitMetrics: [CircuitBreakerMetric] = []

    // State
    private var flushTask: Task<Void, Never>?
    private var isEnabled = true
    private let persistenceKey = "metrics_buffer"

    // Stats
    private var totalRecorded = 0
    private var totalSent = 0
    private var totalDropped = 0

    // MARK: - Initialization

    private init(configuration: Configuration = .default) {
        self.configuration = configuration

        #if DEBUG
            self.isEnabled = configuration.enabledInDebug
        #endif
    }

    /// Initialize the reporter - call this on app launch
    func initialize() async {
        await loadPersistedMetrics()
        startFlushTimer()
    }

    deinit {
        flushTask?.cancel()
    }

    // MARK: - Public API

    /// Records an API request metric
    func recordRequest(
        endpoint: String,
        method: String = "GET",
        statusCode: Int? = nil,
        durationMs: Int,
        errorType: String? = nil,
        cacheHit: Bool = false,
        requestSizeBytes: Int? = nil,
        responseSizeBytes: Int? = nil,
    ) {
        guard isEnabled else { return }

        let metric = RequestMetric(
            endpoint: sanitizeEndpoint(endpoint),
            method: method,
            statusCode: statusCode,
            responseTimeMs: durationMs,
            errorType: errorType,
            cacheHit: cacheHit,
            requestSizeBytes: requestSizeBytes,
            responseSizeBytes: responseSizeBytes,
        )

        requestMetrics.append(metric)
        totalRecorded += 1

        // Trim if over limit
        if requestMetrics.count > configuration.maxOfflineEvents {
            let dropped = requestMetrics.count - configuration.maxOfflineEvents
            requestMetrics.removeFirst(dropped)
            totalDropped += dropped
        }

        // Check for immediate flush
        if requestMetrics.count >= configuration.maxBatchSize {
            Task { await flush() }
        }
    }

    /// Records a circuit breaker state change
    func recordCircuitBreakerEvent(
        circuitName: String,
        state: String,
        previousState: String? = nil,
        failureCount: Int = 0,
        successCount: Int = 0,
        consecutiveFailures: Int = 0,
        triggerReason: String? = nil,
    ) {
        guard isEnabled else { return }

        let metric = CircuitBreakerMetric(
            circuitName: circuitName,
            state: state,
            previousState: previousState,
            failureCount: failureCount,
            successCount: successCount,
            consecutiveFailures: consecutiveFailures,
            triggerReason: triggerReason,
        )

        circuitMetrics.append(metric)

        // Circuit events are always flushed immediately
        Task { await flush() }
    }

    /// Manually flush all pending metrics
    func flush() async {
        guard isEnabled else { return }
        guard !requestMetrics.isEmpty || !circuitMetrics.isEmpty else { return }

        let deviceInfo = await MainActor.run { MetricsDeviceInfo.current }

        let batch = MetricsBatch(
            requests: requestMetrics,
            circuitEvents: circuitMetrics,
            deviceInfo: deviceInfo,
            batchTimestamp: Date(),
        )

        // Clear queues before upload (will re-add on failure)
        let requestCount = requestMetrics.count
        let circuitCount = circuitMetrics.count
        requestMetrics.removeAll()
        circuitMetrics.removeAll()

        do {
            try await uploadBatch(batch)
            totalSent += requestCount + circuitCount
            logger.debug("Flushed \(requestCount) requests, \(circuitCount) circuit events")
        } catch {
            logger.error("Failed to upload metrics: \(error.localizedDescription)")

            // Re-add failed metrics for retry
            requestMetrics.insert(contentsOf: batch.requests, at: 0)
            circuitMetrics.insert(contentsOf: batch.circuitEvents, at: 0)

            // Persist for offline recovery
            await persistMetrics()
        }
    }

    /// Enable or disable metrics collection
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            requestMetrics.removeAll()
            circuitMetrics.removeAll()
        }
    }

    /// Get current metrics statistics
    func getStatistics() -> (recorded: Int, sent: Int, dropped: Int, pending: Int) {
        (
            recorded: totalRecorded,
            sent: totalSent,
            dropped: totalDropped,
            pending: requestMetrics.count + circuitMetrics.count,
        )
    }

    // MARK: - Private Implementation

    private func startFlushTimer() {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.configuration.batchIntervalSeconds ?? 30))
                await self?.flush()
            }
        }
    }

    private func uploadBatch(_ batch: MetricsBatch) async throws {
        // Get Supabase client from the app's manager
        let supabase = await SupabaseManager.shared.client

        // Upload request metrics
        for metric in batch.requests {
            let params = RecordRequestParams(
                p_endpoint: metric.endpoint,
                p_method: metric.method,
                p_response_time_ms: metric.responseTimeMs,
                p_app_platform: batch.deviceInfo.platform,
                p_app_version: batch.deviceInfo.appVersion,
                p_cache_hit: metric.cacheHit,
                p_status_code: metric.statusCode,
                p_error_type: metric.errorType,
                p_request_size: metric.requestSizeBytes,
                p_response_size: metric.responseSizeBytes,
            )

            try await supabase.rpc("record_request", params: params).execute()
        }

        // Upload circuit events
        for event in batch.circuitEvents {
            let params = RecordCircuitEventParams(
                p_circuit_name: event.circuitName,
                p_state: event.state,
                p_previous_state: event.previousState,
                p_failure_count: event.failureCount,
                p_success_count: event.successCount,
                p_consecutive_failures: event.consecutiveFailures,
                p_trigger_reason: event.triggerReason,
                p_app_platform: batch.deviceInfo.platform,
            )

            try await supabase.rpc("record_circuit_event", params: params).execute()
        }
    }

    private func sanitizeEndpoint(_ endpoint: String) -> String {
        // Remove UUIDs and IDs from endpoints for aggregation
        var sanitized = endpoint

        // Replace UUIDs
        let uuidPattern = #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#
        if let regex = try? NSRegularExpression(pattern: uuidPattern) {
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: ":id",
            )
        }

        // Replace numeric IDs
        let numericPattern = #"/\d+(/|$)"#
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                range: NSRange(sanitized.startIndex..., in: sanitized),
                withTemplate: "/:id$1",
            )
        }

        return sanitized
    }

    private func persistMetrics() async {
        guard !requestMetrics.isEmpty || !circuitMetrics.isEmpty else { return }

        let deviceInfo = await MainActor.run { MetricsDeviceInfo.current }

        let batch = MetricsBatch(
            requests: requestMetrics,
            circuitEvents: circuitMetrics,
            deviceInfo: deviceInfo,
            batchTimestamp: Date(),
        )

        do {
            let secureStorage = SecureStorage.shared
            try await secureStorage.store(batch, forKey: persistenceKey)
            logger.debug("Persisted \(batch.requests.count) metrics for offline recovery")
        } catch {
            logger.error("Failed to persist metrics: \(error.localizedDescription)")
        }
    }

    private func loadPersistedMetrics() async {
        do {
            let secureStorage = SecureStorage.shared
            if let batch: MetricsBatch = try await secureStorage.retrieve(MetricsBatch.self, forKey: persistenceKey) {
                requestMetrics.append(contentsOf: batch.requests)
                circuitMetrics.append(contentsOf: batch.circuitEvents)
                try await secureStorage.remove(forKey: persistenceKey)
                logger.debug("Loaded \(batch.requests.count) persisted metrics")
            }
        } catch {
            logger.error("Failed to load persisted metrics: \(error.localizedDescription)")
        }
    }
}

// MARK: - Request Timing Helper

/// Helper for timing requests
final class RequestTimer: @unchecked Sendable {
    private let startTime: CFAbsoluteTime
    private let endpoint: String
    private let method: String

    init(endpoint: String, method: String = "GET") {
        self.startTime = CFAbsoluteTimeGetCurrent()
        self.endpoint = endpoint
        self.method = method
    }

    /// Finishes timing and records the metric
    func finish(
        statusCode: Int? = nil,
        errorType: String? = nil,
        cacheHit: Bool = false,
        requestSizeBytes: Int? = nil,
        responseSizeBytes: Int? = nil,
    ) async {
        let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        await MetricsReporter.shared.recordRequest(
            endpoint: endpoint,
            method: method,
            statusCode: statusCode,
            durationMs: durationMs,
            errorType: errorType,
            cacheHit: cacheHit,
            requestSizeBytes: requestSizeBytes,
            responseSizeBytes: responseSizeBytes,
        )
    }
}

#endif
