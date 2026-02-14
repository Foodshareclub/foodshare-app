//
//  IPGeolocationRetryPolicy.swift
//  Foodshare
//
//  Retry logic with exponential backoff for IP geolocation requests.
//

import Foundation

// MARK: - Retry Policy

/// Configuration for retry behavior with exponential backoff
struct IPGeolocationRetryPolicy: Sendable {
    /// Maximum number of retry attempts
    let maxRetries: Int

    /// Base delay in milliseconds for first retry
    let baseDelayMs: Int

    /// Maximum delay cap in milliseconds
    let maxDelayMs: Int

    /// Multiplier for exponential backoff
    let backoffMultiplier: Double

    /// Random jitter factor (0.0 - 1.0) to prevent thundering herd
    let jitterFactor: Double

    // MARK: - Presets

    /// Default retry policy for IP geolocation
    static let `default` = IPGeolocationRetryPolicy(
        maxRetries: 2,
        baseDelayMs: 200,
        maxDelayMs: 2000,
        backoffMultiplier: 2.0,
        jitterFactor: 0.1,
    )

    /// Aggressive retry policy for critical operations
    static let aggressive = IPGeolocationRetryPolicy(
        maxRetries: 3,
        baseDelayMs: 100,
        maxDelayMs: 1000,
        backoffMultiplier: 1.5,
        jitterFactor: 0.15,
    )

    /// Conservative retry policy for low-priority or rate-limited scenarios
    static let conservative = IPGeolocationRetryPolicy(
        maxRetries: 1,
        baseDelayMs: 500,
        maxDelayMs: 3000,
        backoffMultiplier: 2.5,
        jitterFactor: 0.2,
    )

    /// No retries (fail immediately)
    static let none = IPGeolocationRetryPolicy(
        maxRetries: 0,
        baseDelayMs: 0,
        maxDelayMs: 0,
        backoffMultiplier: 1.0,
        jitterFactor: 0.0,
    )

    // MARK: - Delay Calculation

    /// Calculate delay before the specified retry attempt
    ///
    /// - Parameter attempt: The retry attempt number (1-based, so first retry is attempt 1)
    /// - Returns: Delay in seconds before this attempt
    func delay(for attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }

        // Calculate exponential delay
        let exponentialDelay = Double(baseDelayMs) * pow(backoffMultiplier, Double(attempt - 1))

        // Cap at maximum
        let cappedDelay = min(exponentialDelay, Double(maxDelayMs))

        // Add jitter to prevent thundering herd
        let jitterRange = cappedDelay * jitterFactor
        let jitter = Double.random(in: -jitterRange ... jitterRange)
        let finalDelay = max(0, cappedDelay + jitter)

        // Convert to seconds
        return finalDelay / 1000.0
    }

    /// Calculate total maximum time including all retries
    var maxTotalDelay: TimeInterval {
        var total: TimeInterval = 0
        for attempt in 1 ... maxRetries {
            total += delay(for: attempt)
        }
        return total
    }

    // MARK: - Retry Decision

    /// Determine if another retry should be attempted
    ///
    /// - Parameters:
    ///   - attempt: Current attempt number (0-based, so first attempt is 0)
    ///   - error: The error that occurred
    /// - Returns: Whether to retry
    func shouldRetry(attempt: Int, error: Error) -> Bool {
        // Check attempt limit
        guard attempt < maxRetries else {
            return false
        }

        // Check if error is retryable
        if let geoError = error as? IPGeolocationError {
            return isRetryable(geoError)
        }

        // URLError is generally retryable for transient issues
        if let urlError = error as? URLError {
            return isRetryable(urlError)
        }

        // Unknown errors - don't retry by default
        return false
    }

    /// Check if a geolocation error is retryable
    private func isRetryable(_ error: IPGeolocationError) -> Bool {
        switch error {
        case .timeout, .networkError:
            // Transient errors - retry
            true

        case let .httpError(_, statusCode):
            // Server errors are retryable, client errors are not
            statusCode >= 500

        case .rateLimited, .circuitOpen:
            // These have their own backoff mechanisms - don't retry immediately
            false

        case .invalidResponse, .parsingError, .coordinatesInvalid:
            // Data errors - retrying won't help
            false

        case .vpnDetected, .serviceDisabled, .noProvidersConfigured:
            // Configuration issues - don't retry
            false

        case .allProvidersUnavailable, .cacheExpiredRefreshFailed:
            // Already exhausted - don't retry
            false
        }
    }

    /// Check if a URL error is retryable
    private func isRetryable(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut,
             .networkConnectionLost,
             .notConnectedToInternet,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed:
            // Network transient errors - retry
            true

        case .cancelled,
             .badURL,
             .unsupportedURL,
             .badServerResponse,
             .userCancelledAuthentication:
            // Permanent errors - don't retry
            false

        default:
            // Unknown - be conservative, don't retry
            false
        }
    }
}

// MARK: - Retry Executor

/// Executes operations with retry logic
struct RetryExecutor<T: Sendable>: Sendable {
    let policy: IPGeolocationRetryPolicy
    let operation: @Sendable () async throws -> T

    /// Execute the operation with retries
    func execute() async throws -> T {
        var lastError: Error?

        for attempt in 0 ... policy.maxRetries {
            // Wait before retry (skip for first attempt)
            if attempt > 0 {
                let delay = policy.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }

            do {
                return try await operation()
            } catch {
                lastError = error

                // Check if we should retry
                if !policy.shouldRetry(attempt: attempt, error: error) {
                    throw error
                }

                // Will retry on next iteration
            }
        }

        // Should not reach here, but throw last error if we do
        throw lastError ?? IPGeolocationError.serviceDisabled
    }
}

// MARK: - Convenience Extensions

extension IPGeolocationRetryPolicy {
    /// Execute an operation with this policy's retry logic
    func execute<T: Sendable>(
        _ operation: @escaping @Sendable () async throws -> T,
    ) async throws -> T {
        try await RetryExecutor(policy: self, operation: operation).execute()
    }
}

// MARK: - Retry Statistics

/// Statistics about retry behavior for monitoring
struct RetryStatistics: Sendable {
    let totalAttempts: Int
    let successfulAttempt: Int?
    let totalDuration: TimeInterval
    let errors: [String]

    var wasSuccessful: Bool {
        successfulAttempt != nil
    }

    var retryCount: Int {
        guard let success = successfulAttempt else {
            return totalAttempts - 1
        }
        return success
    }
}
