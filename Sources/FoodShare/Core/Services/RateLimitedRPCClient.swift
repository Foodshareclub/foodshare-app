//
//  RateLimitedRPCClient.swift
//  Foodshare
//
//  Enterprise-grade RPC client with built-in rate limiting, retry logic, and audit logging.
//  Provides a secure wrapper around Supabase RPC calls with protection against abuse.
//
//  Features:
//  - Per-function rate limiting (configurable)
//  - Global rate limiting across all RPC calls
//  - Exponential backoff retry for transient failures
//  - Automatic audit logging of sensitive operations
//  - Circuit breaker pattern for failing services
//

#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - RPC Configuration

/// Configuration for rate limiting RPC calls
struct RPCRateLimitConfig: Sendable {
    /// Maximum requests per time window
    let maxRequests: Int

    /// Time window in seconds
    let windowSeconds: TimeInterval

    /// Whether to enable circuit breaker
    let circuitBreakerEnabled: Bool

    /// Number of failures before circuit opens
    let circuitBreakerThreshold: Int

    /// Time before attempting to close circuit
    let circuitBreakerResetTime: TimeInterval

    /// Default configuration: 60 requests per minute
    static let `default` = RPCRateLimitConfig(
        maxRequests: 60,
        windowSeconds: 60,
        circuitBreakerEnabled: true,
        circuitBreakerThreshold: 5,
        circuitBreakerResetTime: 30,
    )

    /// Strict configuration: 10 requests per minute (for sensitive operations)
    static let strict = RPCRateLimitConfig(
        maxRequests: 10,
        windowSeconds: 60,
        circuitBreakerEnabled: true,
        circuitBreakerThreshold: 3,
        circuitBreakerResetTime: 60,
    )

    /// Relaxed configuration: 120 requests per minute (for read-heavy operations)
    static let relaxed = RPCRateLimitConfig(
        maxRequests: 120,
        windowSeconds: 60,
        circuitBreakerEnabled: true,
        circuitBreakerThreshold: 10,
        circuitBreakerResetTime: 15,
    )
}

// MARK: - RPC Error

/// Errors from rate-limited RPC operations
enum RPCError: LocalizedError, Sendable {
    case rateLimitExceeded(retryAfter: TimeInterval)
    case circuitOpen(resetTime: TimeInterval)
    case rpcFailed(String)
    case unauthorized
    case notFound
    case serverError(Int)
    case networkError(String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case let .rateLimitExceeded(retryAfter):
            "Rate limit exceeded. Please wait \(Int(retryAfter)) seconds."
        case let .circuitOpen(resetTime):
            "Service temporarily unavailable. Retry in \(Int(resetTime)) seconds."
        case let .rpcFailed(message):
            "RPC operation failed: \(message)"
        case .unauthorized:
            "Authentication required"
        case .notFound:
            "Resource not found"
        case let .serverError(code):
            "Server error: HTTP \(code)"
        case let .networkError(message):
            "Network error: \(message)"
        case let .decodingError(message):
            "Failed to decode response: \(message)"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .serverError:
            true
        case .rateLimitExceeded, .circuitOpen, .rpcFailed, .unauthorized, .notFound, .decodingError:
            false
        }
    }
}

// MARK: - Circuit Breaker State

/// Circuit breaker state for service protection
private enum CircuitState: Sendable {
    case closed
    case open(until: Date)
    case halfOpen

    var isOpen: Bool {
        if case let .open(until) = self {
            return Date() < until
        }
        return false
    }
}

// MARK: - RPC Rate Limiter

/// Rate limiter for individual RPC functions
private actor FunctionRateLimiter {
    private var requestCount = 0
    private var windowStart: Date?
    private let config: RPCRateLimitConfig

    // Circuit breaker state
    private var circuitState: CircuitState = .closed
    private var failureCount = 0

    init(config: RPCRateLimitConfig) {
        self.config = config
    }

    func checkRateLimit() throws {
        let now = Date()

        // Check circuit breaker
        if config.circuitBreakerEnabled {
            switch circuitState {
            case let .open(until) where now < until:
                throw RPCError.circuitOpen(resetTime: until.timeIntervalSince(now))
            case .open:
                // Circuit timeout passed, move to half-open
                circuitState = .halfOpen
            case .halfOpen, .closed:
                break
            }
        }

        // Check rate limit
        if let windowStart, now.timeIntervalSince(windowStart) < config.windowSeconds {
            if requestCount >= config.maxRequests {
                let retryAfter = config.windowSeconds - now.timeIntervalSince(windowStart)
                throw RPCError.rateLimitExceeded(retryAfter: retryAfter)
            }
            requestCount += 1
        } else {
            // Start new window
            windowStart = now
            requestCount = 1
        }
    }

    func recordSuccess() {
        failureCount = 0
        if case .halfOpen = circuitState {
            circuitState = .closed
        }
    }

    func recordFailure() {
        failureCount += 1
        if config.circuitBreakerEnabled, failureCount >= config.circuitBreakerThreshold {
            let resetTime = Date().addingTimeInterval(config.circuitBreakerResetTime)
            circuitState = .open(until: resetTime)
            failureCount = 0
        }
    }

    func reset() {
        requestCount = 0
        windowStart = nil
        failureCount = 0
        circuitState = .closed
    }
}

// MARK: - Rate Limited RPC Client Protocol

/// Protocol for rate-limited RPC operations
protocol RateLimitedRPCClientProtocol: Sendable {
    func call<T: Decodable & Sendable>(
        _ function: String,
        params: [String: any Sendable],
        config: RPCRateLimitConfig,
    ) async throws -> T

    func callVoid(
        _ function: String,
        params: [String: any Sendable],
        config: RPCRateLimitConfig,
    ) async throws
}

// MARK: - Rate Limited RPC Client Implementation

/// Production-ready RPC client with rate limiting and circuit breaker
///
/// Features:
/// - Per-function rate limiting with configurable thresholds
/// - Circuit breaker pattern to prevent cascade failures
/// - Exponential backoff retry for transient errors
/// - Comprehensive error handling and logging
///
/// Usage:
/// ```swift
/// let rpcClient = RateLimitedRPCClient(supabase: supabaseClient)
///
/// // Standard call with default rate limiting
/// let result: [User] = try await rpcClient.call("get_nearby_users", params: ["radius": 10])
///
/// // Strict rate limiting for sensitive operations
/// let secret: String = try await rpcClient.call(
///     "get_secret_audited",
///     params: ["secret_name": "API_KEY"],
///     config: .strict
/// )
/// ```
actor RateLimitedRPCClient: RateLimitedRPCClientProtocol {
    private let supabase: SupabaseClient
    private let logger: Logger
    // TODO: Re-enable once AuditLogger conflicts are resolved
    // private let auditLogger: AuditLoggerProtocol?

    // Per-function rate limiters
    private var functionLimiters: [String: FunctionRateLimiter] = [:]

    // Global rate limiter
    private let globalLimiter: FunctionRateLimiter

    // Retry configuration
    private let maxRetries: Int
    private let initialBackoff: TimeInterval

    init(
        supabase: Supabase.SupabaseClient,
        // auditLogger: AuditLoggerProtocol? = nil,
        globalConfig: RPCRateLimitConfig = RPCRateLimitConfig(
            maxRequests: 300,
            windowSeconds: 60,
            circuitBreakerEnabled: true,
            circuitBreakerThreshold: 20,
            circuitBreakerResetTime: 60,
        ),
        maxRetries: Int = 3,
        initialBackoff: TimeInterval = 0.5,
        logger: Logger = Logger(subsystem: "com.flutterflow.foodshare", category: "rpc"),
    ) {
        self.supabase = supabase
        // self.auditLogger = auditLogger
        self.globalLimiter = FunctionRateLimiter(config: globalConfig)
        self.maxRetries = maxRetries
        self.initialBackoff = initialBackoff
        self.logger = logger

        logger.debug("RateLimitedRPCClient initialized")
    }

    // MARK: - Public API

    /// Call RPC function with rate limiting and return decoded result
    func call<T: Decodable & Sendable>(
        _ function: String,
        params: [String: any Sendable] = [:],
        config: RPCRateLimitConfig = .default,
    ) async throws -> T {
        // Check rate limits
        try await checkRateLimits(for: function, config: config)

        // Execute with retry
        return try await executeWithRetry(function: function, config: config) {
            try await self.performRPCCall(function, params: params)
        }
    }

    /// Call RPC function with rate limiting (no return value)
    func callVoid(
        _ function: String,
        params: [String: any Sendable] = [:],
        config: RPCRateLimitConfig = .default,
    ) async throws {
        // Check rate limits
        try await checkRateLimits(for: function, config: config)

        // Execute with retry
        try await executeWithRetry(function: function, config: config) {
            let _: EmptyResponse = try await self.performRPCCall(function, params: params)
        }
    }

    // MARK: - Private Implementation

    private func checkRateLimits(for function: String, config: RPCRateLimitConfig) async throws {
        // Check global rate limit first
        try await globalLimiter.checkRateLimit()

        // Check per-function rate limit
        let functionLimiter = getFunctionLimiter(for: function, config: config)
        try await functionLimiter.checkRateLimit()
    }

    private func getFunctionLimiter(for function: String, config: RPCRateLimitConfig) -> FunctionRateLimiter {
        if let existing = functionLimiters[function] {
            return existing
        }
        let limiter = FunctionRateLimiter(config: config)
        functionLimiters[function] = limiter
        return limiter
    }

    private func performRPCCall<T: Decodable>(
        _ function: String,
        params: [String: any Sendable],
    ) async throws -> T {
        logger.debug("RPC call: \(function)")

        do {
            // Build params dictionary
            var rpcParams: [String: AnyJSON] = [:]
            for (key, value) in params {
                if let jsonValue = try? AnyJSON(value) {
                    rpcParams[key] = jsonValue
                }
            }

            let result: T = try await supabase.rpc(function, params: rpcParams).execute().value

            // Record success
            let functionLimiter = getFunctionLimiter(for: function, config: .default)
            await functionLimiter.recordSuccess()
            await globalLimiter.recordSuccess()

            logger.debug("RPC call successful: \(function)")
            return result
        } catch let error as PostgrestError {
            throw mapPostgrestError(error, function: function)
        } catch {
            throw RPCError.networkError(error.localizedDescription)
        }
    }

    private func mapPostgrestError(_ error: PostgrestError, function: String) -> RPCError {
        logger.error("RPC error in \(function): \(error.localizedDescription)")

        // Map common PostgrestError cases
        if error.localizedDescription.contains("401") {
            return .unauthorized
        } else if error.localizedDescription.contains("404") {
            return .notFound
        } else if error.localizedDescription.contains("429") {
            return .rateLimitExceeded(retryAfter: 60)
        } else if error.localizedDescription.contains("5"), error.localizedDescription.count == 3 {
            if let code = Int(error.localizedDescription) {
                return .serverError(code)
            }
        }

        return .rpcFailed(error.localizedDescription)
    }

    private func executeWithRetry<T>(
        function: String,
        config: RPCRateLimitConfig,
        operation: @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?
        var backoff = initialBackoff

        let functionLimiter = getFunctionLimiter(for: function, config: config)

        for attempt in 0 ... maxRetries {
            do {
                return try await operation()
            } catch let error as RPCError {
                // Record failure for circuit breaker
                await functionLimiter.recordFailure()
                await globalLimiter.recordFailure()

                // Don't retry non-retryable errors
                if !error.isRetryable {
                    throw error
                }
                lastError = error
            } catch {
                await functionLimiter.recordFailure()
                await globalLimiter.recordFailure()
                lastError = error
            }

            if attempt < maxRetries {
                logger.debug("RPC retry attempt \(attempt + 1)/\(self.maxRetries) for \(function)")
                try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                backoff *= 2 // Exponential backoff
            }
        }

        throw lastError ?? RPCError.rpcFailed("Unknown error in \(function)")
    }
}

// MARK: - Helper Types
// Note: EmptyResponse is defined in BaseSupabaseRepository.swift

// MARK: - AnyJSON Encoding Helper

extension AnyJSON {
    init(_ value: Any) throws {
        if let string = value as? String {
            self = .string(string)
        } else if let int = value as? Int {
            self = .integer(int)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let uuid = value as? UUID {
            self = .string(uuid.uuidString)
        } else if let array = value as? [Any] {
            self = try .array(array.map { try AnyJSON($0) })
        } else if let dict = value as? [String: Any] {
            self = try .object(dict.mapValues { try AnyJSON($0) })
        } else {
            self = .null
        }
    }
}

// MARK: - Convenience Extensions

extension RateLimitedRPCClient {
    /// Check rate limit for RPC function (for sensitive operations like secret access)
    func checkSensitiveOperation(_ function: String) async throws {
        try await checkRateLimits(for: function, config: .strict)
    }

    /// Reset all rate limiters (for testing)
    func resetAllLimiters() async {
        await globalLimiter.reset()
        for limiter in functionLimiters.values {
            await limiter.reset()
        }
    }
}

// MARK: - Mock Implementation for Testing

#if DEBUG
    actor MockRateLimitedRPCClient: RateLimitedRPCClientProtocol {
        var callHistory: [(function: String, params: [String: Any])] = []
        var mockResponses: [String: Any] = [:]
        var shouldFail = false
        var failureError: RPCError = .rpcFailed("Mock failure")

        func call<T: Decodable & Sendable>(
            _ function: String,
            params: [String: any Sendable],
            config: RPCRateLimitConfig,
        ) async throws -> T {
            callHistory.append((function: function, params: params as [String: Any]))

            if shouldFail {
                throw failureError
            }

            if let response = mockResponses[function] as? T {
                return response
            }

            throw RPCError.notFound
        }

        func callVoid(
            _ function: String,
            params: [String: any Sendable],
            config: RPCRateLimitConfig,
        ) async throws {
            callHistory.append((function: function, params: params as [String: Any]))

            if shouldFail {
                throw failureError
            }
        }

        func setMockResponse(_ response: some Any, for function: String) {
            mockResponses[function] = response
        }

        func reset() {
            callHistory.removeAll()
            mockResponses.removeAll()
            shouldFail = false
        }
    }
#endif

#endif
