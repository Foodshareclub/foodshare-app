
#if !SKIP
import Foundation

// MARK: - Rate Limiter

/// Actor-based rate limiter for API calls
actor RateLimiter {
    // MARK: - Properties

    private var lastRequestTime: Date?
    private let minimumInterval: TimeInterval
    private var requestCount = 0
    private var windowStart: Date?
    private let maxRequestsPerWindow: Int
    private let windowDuration: TimeInterval

    // MARK: - Initialization

    /// Initialize with simple interval-based limiting
    init(minimumInterval: TimeInterval = 1.0) {
        self.minimumInterval = minimumInterval
        maxRequestsPerWindow = Int.max
        windowDuration = 0
    }

    /// Initialize with window-based limiting
    init(maxRequests: Int, perSeconds: TimeInterval) {
        minimumInterval = 0
        maxRequestsPerWindow = maxRequests
        windowDuration = perSeconds
    }

    // MARK: - Rate Limiting

    /// Check if request is allowed, throws if rate limited
    func checkRateLimit() async throws {
        let now = Date()

        // Check minimum interval
        if minimumInterval > 0, let lastTime = lastRequestTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                throw RateLimitError.tooManyRequests(
                    retryAfter: minimumInterval - elapsed,
                )
            }
        }

        // Check window-based limit
        if windowDuration > 0 {
            if let windowStart, now.timeIntervalSince(windowStart) < windowDuration {
                if requestCount >= maxRequestsPerWindow {
                    let retryAfter = windowDuration - now.timeIntervalSince(windowStart)
                    throw RateLimitError.tooManyRequests(retryAfter: retryAfter)
                }
                requestCount += 1
            } else {
                // Start new window
                windowStart = now
                requestCount = 1
            }
        }

        lastRequestTime = now
    }

    /// Wait until rate limit allows request
    func waitForRateLimit() async {
        let now = Date()

        if minimumInterval > 0, let lastTime = lastRequestTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < minimumInterval {
                let waitTime = minimumInterval - elapsed
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }

        lastRequestTime = Date()
    }

    /// Reset rate limiter state
    func reset() {
        lastRequestTime = nil
        requestCount = 0
        windowStart = nil
    }
}

// MARK: - Rate Limit Error

/// Errors that can occur when rate limiting is triggered.
///
/// Thread-safe for Swift 6 concurrency.
enum RateLimitError: LocalizedError, Sendable {
    /// Request was rejected due to rate limiting
    case tooManyRequests(retryAfter: TimeInterval)

    var errorDescription: String? {
        switch self {
        case let .tooManyRequests(retryAfter):
            "Too many requests. Please wait \(Int(retryAfter)) seconds."
        }
    }

    var retryAfter: TimeInterval {
        switch self {
        case let .tooManyRequests(interval):
            interval
        }
    }
}

// MARK: - Throttler

/// Throttles function calls to prevent rapid execution
actor Throttler {
    private var lastExecutionTime: Date?
    private let interval: TimeInterval

    init(interval: TimeInterval) {
        self.interval = interval
    }

    /// Execute action if enough time has passed
    func throttle(_ action: @escaping () async -> Void) async {
        let now = Date()

        if let lastTime = lastExecutionTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < interval {
                return // Skip execution
            }
        }

        lastExecutionTime = now
        await action()
    }
}

// MARK: - Debouncer

/// Debounces function calls to wait for pause in activity
actor Debouncer {
    private var task: Task<Void, Never>?
    private let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    /// Debounce action - only executes after delay with no new calls
    func debounce(_ action: @escaping @Sendable () async -> Void) {
        task?.cancel()

        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

            guard !Task.isCancelled else { return }
            await action()
        }
    }

    /// Cancel pending debounced action
    func cancel() {
        task?.cancel()
        task = nil
    }
}

// MARK: - API Rate Limiter

/// Specialized rate limiter for API endpoints
final class APIRateLimiter: @unchecked Sendable {
    static let shared = APIRateLimiter()

    private var limiters: [String: RateLimiter] = [:]
    private let lock = NSLock()

    private init() {}

    /// Get or create rate limiter for endpoint
    func limiter(for endpoint: String, maxRequests: Int = 60, perSeconds: TimeInterval = 60) -> RateLimiter {
        lock.lock()
        defer { lock.unlock() }

        if let existing = limiters[endpoint] {
            return existing
        }

        let limiter = RateLimiter(maxRequests: maxRequests, perSeconds: perSeconds)
        limiters[endpoint] = limiter
        return limiter
    }

    /// Check rate limit for endpoint
    func checkLimit(for endpoint: String) async throws {
        let limiter = limiter(for: endpoint)
        try await limiter.checkRateLimit()
    }
}

#endif
