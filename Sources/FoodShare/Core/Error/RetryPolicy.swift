//
//  RetryPolicy.swift
//  Foodshare
//
//  Production-ready retry policy with exponential backoff and jitter.
//  Provides intelligent retry strategies for transient failures.
//
//  Features:
//  - Exponential backoff with configurable base and max delays
//  - Decorrelated jitter to prevent thundering herd
//  - Retryable error classification
//  - Retry budget for circuit breaker integration
//  - Async/await support with cancellation
//
//  Usage:
//  ```swift
//  let policy = RetryPolicy.exponentialBackoff(maxAttempts: 3)
//
//  let result = try await policy.execute {
//      try await networkCall()
//  }
//  ```
//


#if !SKIP
import Foundation
import OSLog

// MARK: - Retry Error

/// Errors from retry operations
public enum RetryError: LocalizedError, Sendable {
    /// All retry attempts exhausted
    case exhausted(attempts: Int, lastError: Error)

    /// Operation was cancelled
    case cancelled

    /// Error is not retryable
    case notRetryable(Error)

    /// Retry budget exceeded
    case budgetExceeded

    /// No error recorded (should not occur in normal operation)
    case noError

    public var errorDescription: String? {
        switch self {
        case let .exhausted(attempts, lastError):
            "Retry exhausted after \(attempts) attempts. Last error: \(lastError.localizedDescription)"
        case .cancelled:
            "Retry operation was cancelled"
        case let .notRetryable(error):
            "Error is not retryable: \(error.localizedDescription)"
        case .budgetExceeded:
            "Retry budget exceeded - too many retries in time window"
        case .noError:
            "No error occurred"
        }
    }
}

// MARK: - Retryable Protocol

/// Protocol for errors that can indicate retryability
public protocol RetryableError: Error {
    /// Whether this error is retryable
    var isRetryable: Bool { get }

    /// Suggested retry delay (if any)
    var retryAfter: TimeInterval? { get }
}

extension RetryableError {
    public var retryAfter: TimeInterval? {
        nil
    }
}

// MARK: - Retry Classification

/// Classification of errors for retry decisions
public enum RetryClassification: Sendable {
    /// Retry immediately
    case retryImmediately

    /// Retry after backoff delay
    case retryWithBackoff

    /// Retry after specific delay
    case retryAfter(TimeInterval)

    /// Do not retry
    case doNotRetry
}

/// Protocol for custom retry classification
public protocol RetryClassifier: Sendable {
    func classify(_ error: Error, attempt: Int) -> RetryClassification
}

// MARK: - Default Retry Classifier

/// Default classifier that handles common error types
public struct DefaultRetryClassifier: RetryClassifier {
    public init() {}

    public func classify(_ error: Error, attempt: Int) -> RetryClassification {
        // Check for RetryableError protocol
        if let retryable = error as? RetryableError {
            if !retryable.isRetryable {
                return .doNotRetry
            }
            if let delay = retryable.retryAfter {
                return .retryAfter(delay)
            }
            return .retryWithBackoff
        }

        // Check for URLError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return .retryWithBackoff
            case .cancelled:
                return .doNotRetry
            default:
                return .doNotRetry
            }
        }

        // Check for NSError
        let nsError = error as NSError

        // Network errors (NSURLErrorDomain)
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet:
                return .retryWithBackoff
            default:
                return .doNotRetry
            }
        }

        // Default: don't retry unknown errors
        return .doNotRetry
    }
}

// MARK: - Retry Policy Configuration

/// Configuration for retry behavior
public struct RetryPolicyConfig: Sendable {
    /// Maximum number of retry attempts (not counting initial attempt)
    public let maxAttempts: Int

    /// Base delay for exponential backoff
    public let baseDelay: TimeInterval

    /// Maximum delay between retries
    public let maxDelay: TimeInterval

    /// Multiplier for exponential backoff
    public let multiplier: Double

    /// Whether to add jitter to delays
    public let jitterEnabled: Bool

    /// Maximum jitter factor (0.0 to 1.0)
    public let jitterFactor: Double

    /// Default configuration
    public static let `default` = RetryPolicyConfig(
        maxAttempts: 3,
        baseDelay: 0.5,
        maxDelay: 30.0,
        multiplier: 2.0,
        jitterEnabled: true,
        jitterFactor: 0.25,
    )

    /// Aggressive retry for critical operations
    public static let aggressive = RetryPolicyConfig(
        maxAttempts: 5,
        baseDelay: 0.25,
        maxDelay: 60.0,
        multiplier: 2.0,
        jitterEnabled: true,
        jitterFactor: 0.3,
    )

    /// Conservative retry for non-critical operations
    public static let conservative = RetryPolicyConfig(
        maxAttempts: 2,
        baseDelay: 1.0,
        maxDelay: 10.0,
        multiplier: 2.0,
        jitterEnabled: true,
        jitterFactor: 0.2,
    )

    /// No retry - fail immediately
    public static let noRetry = RetryPolicyConfig(
        maxAttempts: 0,
        baseDelay: 0,
        maxDelay: 0,
        multiplier: 1.0,
        jitterEnabled: false,
        jitterFactor: 0,
    )

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 30.0,
        multiplier: Double = 2.0,
        jitterEnabled: Bool = true,
        jitterFactor: Double = 0.25,
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.jitterEnabled = jitterEnabled
        self.jitterFactor = min(max(jitterFactor, 0), 1.0)
    }
}

// MARK: - Retry Budget

/// Tracks retry budget to prevent excessive retrying
public actor RetryBudget {
    private let maxRetries: Int
    private let windowDuration: TimeInterval
    private var retryTimestamps: [Date] = []

    public init(maxRetries: Int = 10, windowDuration: TimeInterval = 60) {
        self.maxRetries = maxRetries
        self.windowDuration = windowDuration
    }

    /// Check if retry is allowed within budget
    public func canRetry() -> Bool {
        cleanupOldEntries()
        return retryTimestamps.count < maxRetries
    }

    /// Record a retry attempt
    public func recordRetry() {
        cleanupOldEntries()
        retryTimestamps.append(Date())
    }

    /// Reset the budget
    public func reset() {
        retryTimestamps.removeAll()
    }

    /// Get remaining retries in current window
    public func remainingRetries() -> Int {
        cleanupOldEntries()
        return max(0, maxRetries - retryTimestamps.count)
    }

    private func cleanupOldEntries() {
        let cutoff = Date().addingTimeInterval(-windowDuration)
        retryTimestamps.removeAll { $0 < cutoff }
    }
}

// MARK: - Retry Policy

/// Production-ready retry policy with exponential backoff and jitter
public struct RetryPolicy: Sendable {
    private let config: RetryPolicyConfig
    private let classifier: RetryClassifier
    private let logger: Logger

    public init(
        config: RetryPolicyConfig = .default,
        classifier: RetryClassifier = DefaultRetryClassifier(),
        logger: Logger = Logger(subsystem: "com.flutterflow.foodshare", category: "retry"),
    ) {
        self.config = config
        self.classifier = classifier
        self.logger = logger
    }

    // MARK: - Factory Methods

    /// Create exponential backoff policy
    public static func exponentialBackoff(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5,
        maxDelay: TimeInterval = 30.0,
    ) -> RetryPolicy {
        RetryPolicy(config: RetryPolicyConfig(
            maxAttempts: maxAttempts,
            baseDelay: baseDelay,
            maxDelay: maxDelay,
        ))
    }

    /// Create fixed delay policy
    public static func fixedDelay(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
    ) -> RetryPolicy {
        RetryPolicy(config: RetryPolicyConfig(
            maxAttempts: maxAttempts,
            baseDelay: delay,
            maxDelay: delay,
            multiplier: 1.0,
            jitterEnabled: false,
        ))
    }

    /// Create immediate retry policy (no delay)
    public static func immediate(maxAttempts: Int = 3) -> RetryPolicy {
        RetryPolicy(config: RetryPolicyConfig(
            maxAttempts: maxAttempts,
            baseDelay: 0,
            maxDelay: 0,
            jitterEnabled: false,
        ))
    }

    // MARK: - Execution

    /// Execute operation with retry policy
    public func execute<T: Sendable>(
        operation: String = "operation",
        _ body: @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?
        let totalAttempts = config.maxAttempts + 1 // Initial + retries

        for attempt in 1 ... totalAttempts {
            // Check for cancellation
            try Task.checkCancellation()

            do {
                let result = try await body()

                if attempt > 1 {
                    logger.info("Retry succeeded for '\(operation)' on attempt \(attempt)")
                }

                return result
            } catch {
                lastError = error

                // Check if this is the last attempt
                if attempt >= totalAttempts {
                    break
                }

                // Classify the error
                let classification = classifier.classify(error, attempt: attempt)

                switch classification {
                case .doNotRetry:
                    throw RetryError.notRetryable(error)

                case .retryImmediately:
                    logger.debug("Retrying '\(operation)' immediately (attempt \(attempt)/\(totalAttempts))")
                    continue

                case .retryWithBackoff:
                    let delay = calculateDelay(for: attempt)
                    logger
                        .debug(
                            "Retrying '\(operation)' after \(delay)s (attempt \(attempt)/\(totalAttempts)): \(error.localizedDescription)",
                        )
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                case let .retryAfter(delay):
                    logger.debug("Retrying '\(operation)' after \(delay)s (server requested)")
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw RetryError.exhausted(attempts: totalAttempts, lastError: lastError ?? RetryError.noError)
    }

    /// Execute operation with retry policy and budget tracking
    public func execute<T: Sendable>(
        operation: String = "operation",
        budget: RetryBudget,
        _ body: @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?
        let totalAttempts = config.maxAttempts + 1

        for attempt in 1 ... totalAttempts {
            try Task.checkCancellation()

            // Check budget before retry (not initial attempt)
            if attempt > 1 {
                guard await budget.canRetry() else {
                    throw RetryError.budgetExceeded
                }
                await budget.recordRetry()
            }

            do {
                return try await body()
            } catch {
                lastError = error

                if attempt >= totalAttempts {
                    break
                }

                let classification = classifier.classify(error, attempt: attempt)

                switch classification {
                case .doNotRetry:
                    throw RetryError.notRetryable(error)

                case .retryImmediately:
                    continue

                case .retryWithBackoff:
                    let delay = calculateDelay(for: attempt)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                case let .retryAfter(delay):
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw RetryError.exhausted(attempts: totalAttempts, lastError: lastError ?? RetryError.noError)
    }

    // MARK: - Delay Calculation

    /// Calculate delay for the given attempt using exponential backoff with optional jitter
    public func calculateDelay(for attempt: Int) -> TimeInterval {
        guard config.baseDelay > 0 else { return 0 }

        // Exponential backoff: baseDelay * (multiplier ^ (attempt - 1))
        let exponentialDelay = config.baseDelay * pow(config.multiplier, Double(attempt - 1))

        // Cap at max delay
        let cappedDelay = min(exponentialDelay, config.maxDelay)

        // Add jitter if enabled
        if config.jitterEnabled {
            return addJitter(to: cappedDelay)
        }

        return cappedDelay
    }

    /// Add decorrelated jitter to prevent thundering herd
    private func addJitter(to delay: TimeInterval) -> TimeInterval {
        let jitterRange = delay * config.jitterFactor
        let jitter = Double.random(in: -jitterRange ... jitterRange)
        return max(0.0, delay + jitter)
    }
}

// MARK: - Retry Policy Builder

/// Fluent builder for retry policies
public final class RetryPolicyBuilder: @unchecked Sendable {
    private var maxAttempts = 3
    private var baseDelay: TimeInterval = 0.5
    private var maxDelay: TimeInterval = 30.0
    private var multiplier = 2.0
    private var jitterEnabled = true
    private var jitterFactor = 0.25
    private var classifier: RetryClassifier = DefaultRetryClassifier()

    public init() {}

    public func maxAttempts(_ attempts: Int) -> RetryPolicyBuilder {
        maxAttempts = attempts
        return self
    }

    public func baseDelay(_ delay: TimeInterval) -> RetryPolicyBuilder {
        baseDelay = delay
        return self
    }

    public func maxDelay(_ delay: TimeInterval) -> RetryPolicyBuilder {
        maxDelay = delay
        return self
    }

    public func multiplier(_ mult: Double) -> RetryPolicyBuilder {
        multiplier = mult
        return self
    }

    public func withJitter(_ factor: Double = 0.25) -> RetryPolicyBuilder {
        jitterEnabled = true
        jitterFactor = factor
        return self
    }

    public func withoutJitter() -> RetryPolicyBuilder {
        jitterEnabled = false
        return self
    }

    public func classifier(_ classifier: RetryClassifier) -> RetryPolicyBuilder {
        self.classifier = classifier
        return self
    }

    public func build() -> RetryPolicy {
        RetryPolicy(
            config: RetryPolicyConfig(
                maxAttempts: maxAttempts,
                baseDelay: baseDelay,
                maxDelay: maxDelay,
                multiplier: multiplier,
                jitterEnabled: jitterEnabled,
                jitterFactor: jitterFactor,
            ),
            classifier: classifier,
        )
    }
}

// MARK: - Convenience Extensions

extension RetryPolicy {
    /// Execute with Result return type instead of throwing
    public func executeToResult<T: Sendable>(
        operation: String = "operation",
        _ body: @Sendable () async throws -> T,
    ) async -> Result<T, Error> {
        do {
            let result = try await execute(operation: operation, body)
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    /// Execute with optional return (nil on failure)
    public func executeOrNil<T: Sendable>(
        operation: String = "operation",
        _ body: @Sendable () async throws -> T,
    ) async -> T? {
        try? await execute(operation: operation, body)
    }
}

// MARK: - Global Retry Helpers

/// Execute with default retry policy
public func withRetry<T: Sendable>(
    maxAttempts: Int = 3,
    operation: String = "operation",
    _ body: @Sendable () async throws -> T,
) async throws -> T {
    let policy = RetryPolicy.exponentialBackoff(maxAttempts: maxAttempts)
    return try await policy.execute(operation: operation, body)
}

/// Execute with retry and capture errors
public func withRetryAndCapture<T: Sendable>(
    maxAttempts: Int = 3,
    operation: String,
    file: String = #file,
    function: String = #function,
    line: Int = #line,
    _ body: @Sendable () async throws -> T,
) async throws -> T {
    let policy = RetryPolicy.exponentialBackoff(maxAttempts: maxAttempts)

    do {
        return try await policy.execute(operation: operation, body)
    } catch {
        // Capture the final error
        await captureError(
            error,
            operation: "\(operation) (after \(maxAttempts + 1) attempts)",
            file: file,
            function: function,
            line: line,
        )
        throw error
    }
}

#endif
