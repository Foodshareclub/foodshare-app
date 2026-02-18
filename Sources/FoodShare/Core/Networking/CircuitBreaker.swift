//
//  CircuitBreaker.swift
//  Foodshare
//
//  Enterprise circuit breaker pattern for resilient network operations
//
//  Prevents cascading failures by:
//  - Stopping requests to failing services
//  - Allowing recovery time for unhealthy services
//  - Gradually testing if services have recovered
//


#if !SKIP
import Foundation
import OSLog

// MARK: - Circuit Breaker

/// Enterprise-grade circuit breaker for network resilience
///
/// Implements the circuit breaker pattern with three states:
/// - **Closed**: Normal operation, requests flow through
/// - **Open**: Circuit tripped, requests fail fast
/// - **Half-Open**: Testing if service has recovered
///
/// Usage:
/// ```swift
/// let breaker = CircuitBreaker(name: "supabase-api")
///
/// do {
///     let result = try await breaker.execute {
///         try await apiClient.fetchProfile()
///     }
/// } catch CircuitBreakerError.circuitOpen {
///     // Service is known to be down, fail fast
///     showOfflineBanner()
/// }
/// ```
actor CircuitBreaker {
    // MARK: - Types

    /// Circuit breaker states
    enum State: String, Sendable {
        case closed // Normal operation
        case open // Failing fast
        case halfOpen // Testing recovery
    }

    /// Configuration for circuit breaker behavior
    struct Configuration: Sendable {
        /// Number of failures before opening the circuit
        let failureThreshold: Int

        /// Time to wait before attempting recovery (seconds)
        let resetTimeout: TimeInterval

        /// Number of successful calls needed to close from half-open
        let successThreshold: Int

        /// Window for counting failures (seconds)
        let failureWindow: TimeInterval

        /// Whether to track slow calls as failures
        let trackSlowCalls: Bool

        /// Threshold for slow call duration (seconds)
        let slowCallThreshold: TimeInterval

        /// Percentage of slow calls that triggers circuit open
        let slowCallRateThreshold: Double

        static let `default` = Configuration(
            failureThreshold: 5,
            resetTimeout: 30,
            successThreshold: 3,
            failureWindow: 60,
            trackSlowCalls: true,
            slowCallThreshold: 5.0,
            slowCallRateThreshold: 0.5,
        )

        static let aggressive = Configuration(
            failureThreshold: 3,
            resetTimeout: 60,
            successThreshold: 5,
            failureWindow: 30,
            trackSlowCalls: true,
            slowCallThreshold: 3.0,
            slowCallRateThreshold: 0.3,
        )

        static let lenient = Configuration(
            failureThreshold: 10,
            resetTimeout: 15,
            successThreshold: 2,
            failureWindow: 120,
            trackSlowCalls: false,
            slowCallThreshold: 10.0,
            slowCallRateThreshold: 0.7,
        )
    }

    /// Statistics about circuit breaker performance
    struct Statistics: Sendable {
        let name: String
        let state: State
        let totalCalls: Int
        let successfulCalls: Int
        let failedCalls: Int
        let rejectedCalls: Int
        let slowCalls: Int
        let averageResponseTime: TimeInterval
        let lastFailure: Date?
        let lastSuccess: Date?
        let stateChangedAt: Date

        var successRate: Double {
            guard totalCalls > 0 else { return 1.0 }
            return Double(successfulCalls) / Double(totalCalls)
        }

        var failureRate: Double {
            guard totalCalls > 0 else { return 0.0 }
            return Double(failedCalls) / Double(totalCalls)
        }
    }

    // MARK: - Properties

    let name: String
    private let config: Configuration
    private let logger: Logger

    private var state: State = .closed
    private var stateChangedAt = Date()

    // Failure tracking
    private var failureCount = 0
    private var failureTimestamps: [Date] = []
    private var lastFailure: Date?

    // Success tracking (for half-open state)
    private var halfOpenSuccessCount = 0
    private var lastSuccess: Date?

    // Statistics
    private var totalCalls = 0
    private var successfulCalls = 0
    private var failedCalls = 0
    private var rejectedCalls = 0
    private var slowCalls = 0
    private var responseTimes: [TimeInterval] = []

    // MARK: - Initialization

    init(name: String, config: Configuration = .default) {
        self.name = name
        self.config = config
        self.logger = Logger(subsystem: Constants.bundleIdentifier, category: "CircuitBreaker[\(name)]")
    }

    // MARK: - Execute

    /// Execute an operation through the circuit breaker
    ///
    /// - Parameter operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: `CircuitBreakerError.circuitOpen` if circuit is open,
    ///           or the original error if the operation fails
    func execute<T>(_ operation: () async throws -> T) async throws -> T {
        totalCalls += 1

        // Check if we should allow the request
        switch state {
        case .open:
            if shouldAttemptReset() {
                logger.info("Transitioning to half-open state")
                transitionTo(.halfOpen)
            } else {
                rejectedCalls += 1
                logger.debug("Circuit open - rejecting request")
                throw CircuitBreakerError.circuitOpen(name: name, retryAfter: timeUntilReset())
            }

        case .halfOpen:
            // Allow limited requests through for testing
            break

        case .closed:
            // Normal operation
            break
        }

        // Execute the operation
        let startTime = Date()
        do {
            let result = try await operation()
            recordSuccess(duration: Date().timeIntervalSince(startTime))
            return result
        } catch {
            recordFailure(error: error, duration: Date().timeIntervalSince(startTime))
            throw error
        }
    }

    // MARK: - State Management

    private func recordSuccess(duration: TimeInterval) {
        successfulCalls += 1
        lastSuccess = Date()
        responseTimes.append(duration)

        // Trim response times array
        if responseTimes.count > 100 {
            responseTimes.removeFirst(responseTimes.count - 100)
        }

        // Check for slow call
        if config.trackSlowCalls, duration > config.slowCallThreshold {
            slowCalls += 1
            logger.warning("Slow call detected: \(String(format: "%.2f", duration))s")
        }

        switch state {
        case .halfOpen:
            halfOpenSuccessCount += 1
            if halfOpenSuccessCount >= config.successThreshold {
                logger.info("Circuit recovered - closing")
                transitionTo(.closed)
            }

        case .closed:
            // Reset failure count on success in closed state
            cleanupOldFailures()

        case .open:
            // Shouldn't happen, but handle gracefully
            break
        }
    }

    private func recordFailure(error: Error, duration: TimeInterval) {
        failedCalls += 1
        lastFailure = Date()
        responseTimes.append(duration)

        switch state {
        case .closed:
            failureCount += 1
            failureTimestamps.append(Date())
            cleanupOldFailures()

            logger
                .warning(
                    "Failure recorded (\(self.failureCount)/\(self.config.failureThreshold)): \(error.localizedDescription)",
                )

            if failureCount >= config.failureThreshold {
                logger.error("Failure threshold reached - opening circuit")
                transitionTo(.open)
            }

        case .halfOpen:
            logger.warning("Failure in half-open state - reopening circuit")
            transitionTo(.open)

        case .open:
            // Already open
            break
        }
    }

    private func transitionTo(_ newState: State) {
        let oldState = state
        state = newState
        stateChangedAt = Date()

        // Reset counters on state change
        switch newState {
        case .closed:
            failureCount = 0
            failureTimestamps.removeAll()
            halfOpenSuccessCount = 0

        case .open:
            halfOpenSuccessCount = 0

        case .halfOpen:
            halfOpenSuccessCount = 0
        }

        logger.info("State changed: \(oldState.rawValue) -> \(newState.rawValue)")
    }

    private func shouldAttemptReset() -> Bool {
        guard state == .open else { return false }
        return Date().timeIntervalSince(stateChangedAt) >= config.resetTimeout
    }

    private func timeUntilReset() -> TimeInterval {
        guard state == .open else { return 0 }
        let elapsed = Date().timeIntervalSince(stateChangedAt)
        return max(0.0, config.resetTimeout - elapsed)
    }

    private func cleanupOldFailures() {
        let cutoff = Date().addingTimeInterval(-config.failureWindow)
        failureTimestamps.removeAll { $0 < cutoff }
        failureCount = failureTimestamps.count
    }

    // MARK: - Manual Controls

    /// Force the circuit to open (for testing or manual intervention)
    func forceOpen() {
        logger.warning("Circuit manually opened")
        transitionTo(.open)
    }

    /// Force the circuit to close (for testing or manual intervention)
    func forceClose() {
        logger.info("Circuit manually closed")
        transitionTo(.closed)
    }

    /// Reset all statistics and state
    func reset() {
        transitionTo(.closed)
        totalCalls = 0
        successfulCalls = 0
        failedCalls = 0
        rejectedCalls = 0
        slowCalls = 0
        responseTimes.removeAll()
        lastFailure = nil
        lastSuccess = nil
        logger.info("Circuit breaker reset")
    }

    // MARK: - Statistics

    /// Get current statistics
    var statistics: Statistics {
        Statistics(
            name: name,
            state: state,
            totalCalls: totalCalls,
            successfulCalls: successfulCalls,
            failedCalls: failedCalls,
            rejectedCalls: rejectedCalls,
            slowCalls: slowCalls,
            averageResponseTime: responseTimes.isEmpty ? 0 : responseTimes.reduce(0, +) / Double(responseTimes.count),
            lastFailure: lastFailure,
            lastSuccess: lastSuccess,
            stateChangedAt: stateChangedAt,
        )
    }

    /// Current state of the circuit
    var currentState: State {
        state
    }

    /// Whether requests are currently being allowed
    var isAllowingRequests: Bool {
        switch state {
        case .closed, .halfOpen:
            true
        case .open:
            shouldAttemptReset()
        }
    }

    // MARK: - Public Outcome Recording

    /// Record a successful operation outcome (for use when not using execute())
    /// - Parameter duration: The duration of the operation
    func reportSuccess(duration: TimeInterval) {
        recordSuccess(duration: duration)
    }

    /// Record a failed operation outcome (for use when not using execute())
    /// - Parameters:
    ///   - error: The error that occurred
    ///   - duration: The duration of the operation
    func reportFailure(error: Error, duration: TimeInterval) {
        recordFailure(error: error, duration: duration)
    }

    /// Prepares to execute a request - returns whether request should proceed
    /// Call this before executing an operation, then call reportSuccess/reportFailure after
    /// - Returns: true if the request can proceed, false if circuit is open
    func prepareRequest() -> Bool {
        totalCalls += 1

        switch state {
        case .open:
            if shouldAttemptReset() {
                logger.info("Transitioning to half-open state")
                transitionTo(.halfOpen)
                return true
            } else {
                rejectedCalls += 1
                logger.debug("Circuit open - rejecting request")
                return false
            }

        case .halfOpen, .closed:
            return true
        }
    }
}

// MARK: - Circuit Breaker Error

/// Errors thrown by the circuit breaker
enum CircuitBreakerError: Error, LocalizedError {
    case circuitOpen(name: String, retryAfter: TimeInterval)

    var errorDescription: String? {
        switch self {
        case let .circuitOpen(name, retryAfter):
            "Service '\(name)' is temporarily unavailable. Retry in \(Int(retryAfter)) seconds."
        }
    }

    var retryAfter: TimeInterval? {
        switch self {
        case let .circuitOpen(_, retryAfter):
            retryAfter
        }
    }
}

// MARK: - Circuit Breaker Registry

/// Global registry for managing multiple circuit breakers
actor CircuitBreakerRegistry {
    static let shared = CircuitBreakerRegistry()

    private var breakers: [String: CircuitBreaker] = [:]

    private init() {}

    /// Get or create a circuit breaker for a service
    func breaker(for service: String, config: CircuitBreaker.Configuration = .default) -> CircuitBreaker {
        if let existing = breakers[service] {
            return existing
        }

        let newBreaker = CircuitBreaker(name: service, config: config)
        breakers[service] = newBreaker
        return newBreaker
    }

    /// Get all registered circuit breakers
    var allBreakers: [CircuitBreaker] {
        Array(breakers.values)
    }

    /// Get statistics for all circuit breakers
    func allStatistics() async -> [CircuitBreaker.Statistics] {
        var stats: [CircuitBreaker.Statistics] = []
        for breaker in breakers.values {
            await stats.append(breaker.statistics)
        }
        return stats
    }

    /// Reset all circuit breakers
    func resetAll() async {
        for breaker in breakers.values {
            await breaker.reset()
        }
    }
}

// MARK: - Convenience Extension

extension CircuitBreaker {
    /// Pre-configured circuit breaker for Supabase API calls
    static let supabase = CircuitBreaker(name: "supabase-api", config: .default)

    /// Pre-configured circuit breaker for image loading
    static let images = CircuitBreaker(name: "images", config: .lenient)

    /// Pre-configured circuit breaker for real-time connections
    static let realtime = CircuitBreaker(name: "realtime", config: .aggressive)
}

#endif
