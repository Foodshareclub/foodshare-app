//
//  IPGeolocationMetrics.swift
//  Foodshare
//
//  Observability and metrics collection for IP geolocation service.
//


#if !SKIP
import Foundation
import OSLog

// MARK: - Provider Metrics

/// Metrics for a single IP geolocation provider
struct IPGeolocationProviderMetrics: Sendable {
    /// Total number of requests made
    var totalRequests = 0

    /// Number of successful requests
    var successfulRequests = 0

    /// Number of failed requests
    var failedRequests = 0

    /// Total response time in milliseconds
    var totalResponseTimeMs = 0

    /// Timestamp of last successful request
    var lastSuccess: Date?

    /// Timestamp of last failed request
    var lastFailure: Date?

    /// Error counts by type
    var errorsByType: [String: Int] = [:]

    /// Circuit breaker state changes
    var circuitOpenCount = 0

    // MARK: - Computed Properties

    /// Average response time in milliseconds
    var averageResponseTimeMs: Int {
        guard totalRequests > 0 else { return 0 }
        return totalResponseTimeMs / totalRequests
    }

    /// Success rate as a percentage (0.0 - 1.0)
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests)
    }

    /// Failure rate as a percentage (0.0 - 1.0)
    var failureRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(failedRequests) / Double(totalRequests)
    }

    /// Time since last successful request
    var timeSinceLastSuccess: TimeInterval? {
        lastSuccess.map { Date().timeIntervalSince($0) }
    }

    /// Time since last failure
    var timeSinceLastFailure: TimeInterval? {
        lastFailure.map { Date().timeIntervalSince($0) }
    }

    /// Most common error type
    var mostCommonError: String? {
        errorsByType.max { $0.value < $1.value }?.key
    }
}

// MARK: - IP Geolocation Metrics

/// Centralized metrics collection for IP geolocation service
actor IPGeolocationMetrics {
    static let shared = IPGeolocationMetrics()

    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "IPGeolocationMetrics")

    // MARK: - Storage

    /// Per-provider metrics
    private var providerMetrics: [IPGeolocationProvider: IPGeolocationProviderMetrics] = [:]

    /// Cache metrics
    private var cacheHits = 0
    private var cacheMisses = 0
    private var cacheInvalidations = 0

    /// Overall service metrics
    private var totalServiceRequests = 0
    private var parallelRequestBatches = 0
    private var averageProvidersPerBatch: Double = 0

    /// Session start time
    private let sessionStart = Date()

    private init() {}

    // MARK: - Recording Methods

    /// Record a request to a provider
    func recordRequest(
        provider: IPGeolocationProvider,
        duration: TimeInterval,
        success: Bool,
        error: IPGeolocationError? = nil,
    ) {
        var metrics = providerMetrics[provider] ?? IPGeolocationProviderMetrics()
        metrics.totalRequests += 1
        metrics.totalResponseTimeMs += Int(duration * 1000)

        if success {
            metrics.successfulRequests += 1
            metrics.lastSuccess = Date()
        } else {
            metrics.failedRequests += 1
            metrics.lastFailure = Date()
            if let error {
                let errorKey = String(describing: type(of: error))
                metrics.errorsByType[errorKey, default: 0] += 1
            }
        }

        providerMetrics[provider] = metrics

        // Log for structured logging
        if success {
            logger.debug("Provider request succeeded: \(provider.rawValue) in \(Int(duration * 1000))ms")
        } else {
            logger
                .warning("Provider request failed: \(provider.rawValue) - \(error?.localizedDescription ?? "unknown")")
        }
    }

    /// Record a circuit breaker state change
    func recordCircuitOpen(provider: IPGeolocationProvider) {
        var metrics = providerMetrics[provider] ?? IPGeolocationProviderMetrics()
        metrics.circuitOpenCount += 1
        providerMetrics[provider] = metrics

        logger.warning("Circuit breaker opened for: \(provider.rawValue)")
    }

    /// Record a cache hit
    func recordCacheHit() {
        cacheHits += 1
        logger.debug("Cache hit")
    }

    /// Record a cache miss
    func recordCacheMiss() {
        cacheMisses += 1
        logger.debug("Cache miss")
    }

    /// Record a cache invalidation
    func recordCacheInvalidation() {
        cacheInvalidations += 1
        logger.debug("Cache invalidated")
    }

    /// Record a parallel request batch
    func recordParallelBatch(providerCount: Int) {
        parallelRequestBatches += 1
        let currentTotal = averageProvidersPerBatch * Double(parallelRequestBatches - 1)
        averageProvidersPerBatch = (currentTotal + Double(providerCount)) / Double(parallelRequestBatches)
    }

    /// Record a service-level request
    func recordServiceRequest() {
        totalServiceRequests += 1
    }

    // MARK: - Retrieval Methods

    /// Get metrics for a specific provider
    func metrics(for provider: IPGeolocationProvider) -> IPGeolocationProviderMetrics {
        providerMetrics[provider] ?? IPGeolocationProviderMetrics()
    }

    /// Get metrics for all providers
    func allProviderMetrics() -> [IPGeolocationProvider: IPGeolocationProviderMetrics] {
        providerMetrics
    }

    /// Get overall service summary
    func serviceSummary() -> ServiceMetricsSummary {
        let totalProviderRequests = providerMetrics.values.reduce(0) { $0 + $1.totalRequests }
        let totalSuccesses = providerMetrics.values.reduce(0) { $0 + $1.successfulRequests }

        return ServiceMetricsSummary(
            totalServiceRequests: totalServiceRequests,
            totalProviderRequests: totalProviderRequests,
            overallSuccessRate: totalProviderRequests > 0
                ? Double(totalSuccesses) / Double(totalProviderRequests)
                : 0,
            cacheHitRate: (cacheHits + cacheMisses) > 0
                ? Double(cacheHits) / Double(cacheHits + cacheMisses)
                : 0,
            cacheHits: cacheHits,
            cacheMisses: cacheMisses,
            cacheInvalidations: cacheInvalidations,
            parallelBatches: parallelRequestBatches,
            avgProvidersPerBatch: averageProvidersPerBatch,
            sessionDuration: Date().timeIntervalSince(sessionStart),
            providerCount: providerMetrics.count,
        )
    }

    // MARK: - Reset

    /// Reset all metrics (for testing or new session)
    func reset() {
        providerMetrics.removeAll()
        cacheHits = 0
        cacheMisses = 0
        cacheInvalidations = 0
        totalServiceRequests = 0
        parallelRequestBatches = 0
        averageProvidersPerBatch = 0

        logger.info("Metrics reset")
    }

    /// Reset metrics for a specific provider
    func reset(provider: IPGeolocationProvider) {
        providerMetrics[provider] = IPGeolocationProviderMetrics()
        logger.info("Metrics reset for: \(provider.rawValue)")
    }
}

// MARK: - Service Metrics Summary

/// Summary of overall IP geolocation service metrics
struct ServiceMetricsSummary: Sendable {
    let totalServiceRequests: Int
    let totalProviderRequests: Int
    let overallSuccessRate: Double
    let cacheHitRate: Double
    let cacheHits: Int
    let cacheMisses: Int
    let cacheInvalidations: Int
    let parallelBatches: Int
    let avgProvidersPerBatch: Double
    let sessionDuration: TimeInterval
    let providerCount: Int

    /// Formatted summary for logging
    var formattedSummary: String {
        """
        IP Geolocation Metrics Summary:
        - Service Requests: \(totalServiceRequests)
        - Provider Requests: \(totalProviderRequests)
        - Success Rate: \(String(format: "%.1f", overallSuccessRate * 100))%
        - Cache Hit Rate: \(String(format: "%.1f", cacheHitRate * 100))%
        - Cache: \(cacheHits) hits, \(cacheMisses) misses, \(cacheInvalidations) invalidations
        - Parallel Batches: \(parallelBatches) (avg \(String(format: "%.1f", avgProvidersPerBatch)) providers)
        - Session Duration: \(String(format: "%.0f", sessionDuration))s
        - Active Providers: \(providerCount)
        """
    }
}

// MARK: - Health Status

/// Health status for the IP geolocation service
struct IPGeolocationHealthStatus: Sendable {
    let isHealthy: Bool
    let availableProviders: [IPGeolocationProvider]
    let unavailableProviders: [IPGeolocationProvider]
    let circuitBreakerStates: [IPGeolocationProvider: String]
    let cacheStatus: CacheStatus
    let lastSuccessfulRequest: Date?
    let metrics: ServiceMetricsSummary

    struct CacheStatus: Sendable {
        let hasValidCache: Bool
        let cacheAge: TimeInterval?
        let cacheConfidence: LocationConfidence?
    }

    /// Whether at least one provider is available
    var hasAvailableProvider: Bool {
        !availableProviders.isEmpty
    }

    /// Formatted status for display
    var statusDescription: String {
        if isHealthy {
            "Healthy (\(availableProviders.count) providers available)"
        } else if cacheStatus.hasValidCache {
            "Degraded (using cache)"
        } else {
            "Unhealthy (\(unavailableProviders.count) providers failed)"
        }
    }
}

// MARK: - Convenience Extensions

extension IPGeolocationMetrics {
    /// Log current metrics summary
    func logSummary() async {
        let summary = serviceSummary()
        logger.info("\(summary.formattedSummary)")
    }

    /// Get provider health ranking (best performing first)
    func rankedProviders() -> [IPGeolocationProvider] {
        providerMetrics
            .sorted { lhs, rhs in
                // Rank by success rate, then by response time
                if lhs.value.successRate != rhs.value.successRate {
                    return lhs.value.successRate > rhs.value.successRate
                }
                return lhs.value.averageResponseTimeMs < rhs.value.averageResponseTimeMs
            }
            .map(\.key)
    }

    /// Check if a provider is healthy based on recent metrics
    func isProviderHealthy(_ provider: IPGeolocationProvider) -> Bool {
        let metrics = providerMetrics[provider] ?? IPGeolocationProviderMetrics()

        // No requests yet - consider healthy
        if metrics.totalRequests == 0 {
            return true
        }

        // Check success rate threshold
        if metrics.successRate < 0.5 {
            return false
        }

        // Check for recent failures
        if let lastFailure = metrics.lastFailure,
           let lastSuccess = metrics.lastSuccess,
           lastFailure > lastSuccess {
            // Last action was a failure
            return false
        }

        return true
    }
}

#endif
