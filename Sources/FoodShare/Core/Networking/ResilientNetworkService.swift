//
//  ResilientNetworkService.swift
//  Foodshare
//
//  Network service wrapper with resilience patterns:
//  - Circuit breaker for cascade failure prevention
//  - Request deduplication for duplicate request prevention
//  - Exponential backoff retry for transient failures
//  - GET request caching for improved performance
//


#if !SKIP
import Foundation
import OSLog

/// Network service with integrated resilience patterns
actor ResilientNetworkService: NetworkService {
    private let underlying: NetworkService
    private let circuitBreaker: CircuitBreaker
    private let deduplicator: RequestDeduplicator
    private let cache: MemoryCache<String, CachedResponse>
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "ResilientNetwork")

    // Configuration
    private let maxRetries: Int
    private let baseDelay: TimeInterval
    private let maxDelay: TimeInterval
    private let cacheTTL: TimeInterval

    /// Cached response wrapper
    struct CachedResponse: Sendable {
        let data: Data
        let timestamp: Date
    }

    init(
        underlying: NetworkService,
        circuitBreaker: CircuitBreaker = .supabase,
        deduplicator: RequestDeduplicator = .shared,
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 16.0,
        cacheTTL: TimeInterval = 300 // 5 minutes
    ) {
        self.underlying = underlying
        self.circuitBreaker = circuitBreaker
        self.deduplicator = deduplicator
        self.maxRetries = maxRetries
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.cacheTTL = cacheTTL
        self.cache = MemoryCache<String, CachedResponse>(expirationInterval: cacheTTL)
    }

    // MARK: - NetworkService

    func execute<Request: NetworkRequest>(_ request: Request) async throws -> Request.Response {
        let cacheKey = buildCacheKey(for: request)
        let isGetRequest = request.method == .get

        // For GET requests, check cache first
        if isGetRequest {
            if let cached = await getCachedResponse(for: cacheKey, as: Request.Response.self) {
                logger.debug("Cache hit for \(request.path)")
                return cached
            }
        }

        // Deduplicate requests
        do {
            return try await deduplicator.deduplicate(key: cacheKey) {
                try await self.executeWithResilience(request, cacheKey: cacheKey)
            }
        } catch let error as DeduplicationError where error.isDeduplicated {
            // Request was deduplicated - wait and retry to get the result
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            if let cached = await getCachedResponse(for: cacheKey, as: Request.Response.self) {
                return cached
            }
            // Fall through to execute if no cache
            return try await executeWithResilience(request, cacheKey: cacheKey)
        }
    }

    // MARK: - Private

    private func executeWithResilience<Request: NetworkRequest>(
        _ request: Request,
        cacheKey: String
    ) async throws -> Request.Response {
        var lastError: Error?
        var attempt = 0

        while attempt <= maxRetries {
            // Check circuit breaker
            let canProceed = await circuitBreaker.prepareRequest()
            guard canProceed else {
                throw CircuitBreakerError.circuitOpen(
                    name: "network",
                    retryAfter: 30
                )
            }

            let startTime = Date()
            do {
                try Task.checkCancellation()

                let result = try await underlying.execute(request)
                let duration = Date().timeIntervalSince(startTime)

                // Report success to circuit breaker
                await circuitBreaker.reportSuccess(duration: duration)

                // Cache GET responses if response is Encodable
                if request.method == .get, let encodable = result as? any Encodable {
                    await cacheEncodableResponse(encodable, for: cacheKey)
                }

                return result
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                let duration = Date().timeIntervalSince(startTime)
                await circuitBreaker.reportFailure(error: error, duration: duration)
                lastError = error

                // Check if error is retryable
                if !isRetryableError(error) {
                    throw error
                }

                attempt += 1
                if attempt <= maxRetries {
                    let delay = calculateBackoffDelay(attempt: attempt)
                    logger.info("Retry \(attempt)/\(self.maxRetries) in \(String(format: "%.1f", delay))s for \(request.path)")
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? NetworkError.unknown(NSError(domain: "ResilientNetworkService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]))
    }

    private func isRetryableError(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .timeout, .noData, .noInternetConnection:
                return true
            case .serverError(let statusCode, _, _):
                // Retry on 5xx errors and 429 (rate limited)
                return statusCode >= 500 || statusCode == 429
            case .rateLimited:
                return true
            case .unknown:
                return true
            case .invalidURL, .decodingError, .encodingError, .unauthorized, .forbidden, .notFound:
                return false
            }
        }

        let nsError = error as NSError
        let retryableCodes = [
            NSURLErrorTimedOut,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorNotConnectedToInternet,
            NSURLErrorCannotFindHost,
            NSURLErrorCannotConnectToHost,
        ]
        return retryableCodes.contains(nsError.code)
    }

    private func calculateBackoffDelay(attempt: Int) -> TimeInterval {
        // Exponential backoff: 1s → 2s → 4s → 8s → 16s (max)
        let delay = baseDelay * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.3) * delay // Add up to 30% jitter
        return min(delay + jitter, maxDelay)
    }

    private func buildCacheKey<Request: NetworkRequest>(for request: Request) -> String {
        var key = "\(request.method.rawValue):\(request.path)"
        if let queryItems = request.queryItems, !queryItems.isEmpty {
            let queryString = queryItems
                .sorted { $0.name < $1.name }
                .map { "\($0.name)=\($0.value ?? "")" }
                .joined(separator: "&")
            key += "?\(queryString)"
        }
        return key
    }

    private func getCachedResponse<T: Decodable>(for key: String, as type: T.Type) async -> T? {
        guard let cached = await cache.get(key) else { return nil }

        // Check if still valid
        guard Date().timeIntervalSince(cached.timestamp) < cacheTTL else {
            await cache.remove(key)
            return nil
        }

        // Decode
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: cached.data)
    }

    private func cacheResponse<T: Encodable>(_ response: T, for key: String) async {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(response) {
            await cache.set(key, value: CachedResponse(data: data, timestamp: Date()))
            logger.debug("Cached response for \(key)")
        }
    }

    private func cacheEncodableResponse(_ response: any Encodable, for key: String) async {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601

        if let data = try? encoder.encode(response) {
            await cache.set(key, value: CachedResponse(data: data, timestamp: Date()))
            logger.debug("Cached response for \(key)")
        }
    }

    // MARK: - Cache Management

    /// Clear all cached responses
    func clearCache() async {
        await cache.clear()
        logger.info("Cache cleared")
    }

    /// Get circuit breaker statistics
    func circuitBreakerStats() async -> CircuitBreaker.Statistics {
        await circuitBreaker.statistics
    }

    /// Get deduplicator statistics
    func deduplicatorStats() async -> RequestDeduplicator.Statistics {
        await deduplicator.statistics
    }
}

// MARK: - NetworkError Extension

extension NetworkError {
    static let noConnection = NetworkError.noInternetConnection
}

#endif
