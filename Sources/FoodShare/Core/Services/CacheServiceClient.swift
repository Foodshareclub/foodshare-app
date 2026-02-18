//
//  CacheServiceClient.swift
//  Foodshare
//
//  Secure cache service client that routes all Redis operations through Edge Functions.
//  This eliminates direct client access to Vault secrets, following enterprise security best practices.
//
//  Security Features:
//  - No client-side access to Redis credentials
//  - All operations authenticated and audited server-side
//  - Rate limiting enforced server-side (60 requests/minute)
//  - User-scoped keys prevent cross-user cache access
//


#if !SKIP
import Foundation
import OSLog
import Supabase

// MARK: - Cache Operation Types

/// Operations supported by the cache Edge Function
enum CacheOperation: String, Codable, Sendable {
    case get
    case set
    case delete
    case incr
    case expire
    case exists
    case ttl
}

/// Request payload for cache operations
struct CacheRequest: Codable, Sendable {
    let operation: CacheOperation
    let key: String
    let value: String?
    let ttl: Int?

    init(operation: CacheOperation, key: String, value: String? = nil, ttl: Int? = nil) {
        self.operation = operation
        self.key = key
        self.value = value
        self.ttl = ttl
    }
}

/// Response from cache Edge Function
struct CacheResponse: Codable, Sendable {
    let success: Bool
    let operation: String
    let result: CacheResult
    let userId: String?

    private enum CodingKeys: String, CodingKey {
        case success, operation, result
        case userId = "user_id"
    }
}

/// Cache operation result - handles different result types
struct CacheResult: Codable, Sendable {
    let value: CacheAnyCodable?
    let deleted: Int?
    let exists: Bool?
    let ttl: Int?
    let success: Bool?
}

/// Type-erased Codable for handling dynamic JSON values in cache operations
/// Note: Uses @unchecked Sendable as values are only used for JSON encoding/decoding
internal struct CacheAnyCodable: Codable, @unchecked Sendable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([CacheAnyCodable].self) {
            value = array.map(\.value)
        } else if let dict = try? container.decode([String: CacheAnyCodable].self) {
            value = dict.mapValues(\.value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { CacheAnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { CacheAnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(
                codingPath: encoder.codingPath,
                debugDescription: "Unsupported type",
            ))
        }
    }
}

// MARK: - Cache Service Error

/// Errors from cache service operations
enum CacheServiceError: LocalizedError, Sendable {
    case unauthorized
    case rateLimitExceeded
    case invalidKey(String)
    case operationFailed(String)
    case networkError(String)
    case decodingError(String)
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Authentication required for cache operations"
        case .rateLimitExceeded:
            "Rate limit exceeded. Maximum 60 requests per minute."
        case let .invalidKey(reason):
            "Invalid cache key: \(reason)"
        case let .operationFailed(message):
            "Cache operation failed: \(message)"
        case let .networkError(message):
            "Network error: \(message)"
        case let .decodingError(message):
            "Failed to decode cache response: \(message)"
        case .serviceUnavailable:
            "Cache service is temporarily unavailable"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .serviceUnavailable:
            true
        case .unauthorized, .rateLimitExceeded, .invalidKey, .operationFailed, .decodingError:
            false
        }
    }
}

// MARK: - Cache Service Client Protocol

/// Protocol for cache operations via Edge Function
protocol CacheServiceClientProtocol: Sendable {
    func get(_ key: String) async throws -> String?
    func set(_ key: String, value: String, ttl: Int) async throws
    func delete(_ key: String) async throws
    func incr(_ key: String) async throws -> Int
    func expire(_ key: String, ttl: Int) async throws -> Bool
    func exists(_ key: String) async throws -> Bool
    func ttl(_ key: String) async throws -> Int
}

// MARK: - Cache Service Client Implementation

/// Production cache client that routes all operations through Edge Functions
///
/// This client provides secure access to Upstash Redis without exposing credentials to the iOS app.
/// All operations are authenticated, rate-limited, and audit-logged server-side.
///
/// Usage:
/// ```swift
/// let cacheClient = CacheServiceClient(supabase: supabaseClient, userId: currentUserId)
/// let value = try await cacheClient.get("preferences")
/// try await cacheClient.set("preferences", value: jsonString, ttl: 3600)
/// ```
actor CacheServiceClient: CacheServiceClientProtocol {
    private let supabase: SupabaseClient
    private let userId: UUID
    private let logger: Logger

    // Retry configuration
    private let maxRetries: Int
    private let initialBackoff: TimeInterval

    init(
        supabase: Supabase.SupabaseClient,
        userId: UUID,
        maxRetries: Int = 3,
        initialBackoff: TimeInterval = 0.5,
        logger: Logger = Logger(subsystem: "com.flutterflow.foodshare", category: "cache"),
    ) {
        self.supabase = supabase
        self.userId = userId
        self.maxRetries = maxRetries
        self.initialBackoff = initialBackoff
        self.logger = logger

        logger.debug("CacheServiceClient initialized for user: \(userId.uuidString)")
    }

    // MARK: - Public API

    /// Get a cached value
    func get(_ key: String) async throws -> String? {
        let scopedKey = scopeKey(key)
        let response = try await executeOperation(.get, key: scopedKey)

        guard let value = response.result.value?.value else {
            return nil
        }

        if value is NSNull {
            return nil
        }

        return value as? String
    }

    /// Set a cached value with TTL (default 1 hour)
    func set(_ key: String, value: String, ttl: Int = 3600) async throws {
        let scopedKey = scopeKey(key)
        _ = try await executeOperation(.set, key: scopedKey, value: value, ttl: ttl)
    }

    /// Delete a cached key
    func delete(_ key: String) async throws {
        let scopedKey = scopeKey(key)
        _ = try await executeOperation(.delete, key: scopedKey)
    }

    /// Increment a counter and return new value
    func incr(_ key: String) async throws -> Int {
        let scopedKey = scopeKey(key)
        let response = try await executeOperation(.incr, key: scopedKey)

        guard let value = response.result.value?.value as? Int else {
            throw CacheServiceError.decodingError("Expected integer result from INCR")
        }

        return value
    }

    /// Set expiration on existing key
    func expire(_ key: String, ttl: Int) async throws -> Bool {
        let scopedKey = scopeKey(key)
        let response = try await executeOperation(.expire, key: scopedKey, ttl: ttl)
        return response.result.success ?? false
    }

    /// Check if key exists
    func exists(_ key: String) async throws -> Bool {
        let scopedKey = scopeKey(key)
        let response = try await executeOperation(.exists, key: scopedKey)
        return response.result.exists ?? false
    }

    /// Get TTL for key (-1 no expiry, -2 key doesn't exist)
    func ttl(_ key: String) async throws -> Int {
        let scopedKey = scopeKey(key)
        let response = try await executeOperation(.ttl, key: scopedKey)
        return response.result.ttl ?? -2
    }

    // MARK: - Private Implementation

    /// Scope key to current user (required by Edge Function)
    private func scopeKey(_ key: String) -> String {
        "user:\(userId.uuidString):\(key)"
    }

    /// Execute cache operation via Edge Function
    private func executeOperation(
        _ operation: CacheOperation,
        key: String,
        value: String? = nil,
        ttl: Int? = nil,
    ) async throws -> CacheResponse {
        try await executeWithRetry {
            try await self.performRequest(operation: operation, key: key, value: value, ttl: ttl)
        }
    }

    /// Perform the actual HTTP request to Edge Function
    private func performRequest(
        operation: CacheOperation,
        key: String,
        value: String?,
        ttl: Int?,
    ) async throws -> CacheResponse {
        let request = CacheRequest(operation: operation, key: key, value: value, ttl: ttl)

        logger.debug("Cache operation: \(operation.rawValue) key: \(key)")

        do {
            let cacheResponse: CacheResponse = try await supabase.functions.invoke(
                "cache-operation",
                options: FunctionInvokeOptions(body: request),
            )

            if cacheResponse.success {
                logger.debug("Cache operation successful: \(operation.rawValue)")
                return cacheResponse
            } else {
                throw CacheServiceError.operationFailed("Operation returned success=false")
            }
        } catch let error as FunctionsError {
            throw mapFunctionsError(error)
        } catch let error as CacheServiceError {
            throw error
        } catch let error as DecodingError {
            logger.error("Failed to decode cache response: \(error.localizedDescription)")
            throw CacheServiceError.decodingError(error.localizedDescription)
        } catch {
            logger.error("Cache request failed: \(error.localizedDescription)")
            throw CacheServiceError.networkError(error.localizedDescription)
        }
    }

    /// Map Supabase Functions errors to CacheServiceError
    private func mapFunctionsError(_ error: FunctionsError) -> CacheServiceError {
        switch error {
        case let .httpError(code, _) where code == 401:
            return .unauthorized
        case let .httpError(code, _) where code == 429:
            return .rateLimitExceeded
        case let .httpError(code, _) where code == 403:
            return .invalidKey("Access denied - check key format")
        case let .httpError(code, data):
            let message = String(data: data, encoding: .utf8) ?? "HTTP \(code)"
            return .operationFailed(message)
        case .relayError:
            return .serviceUnavailable
        }
    }

    /// Execute with exponential backoff retry
    private func executeWithRetry<T: Sendable>(
        operation: @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?
        var backoff = initialBackoff

        for attempt in 0 ... maxRetries {
            do {
                return try await operation()
            } catch let error as CacheServiceError {
                // Don't retry non-retryable errors
                if !error.isRetryable {
                    throw error
                }
                lastError = error
            } catch {
                lastError = error
            }

            if attempt < maxRetries {
                logger.debug("Cache retry attempt \(attempt + 1)/\(self.maxRetries)")
                try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                backoff *= 2 // Exponential backoff
            }
        }

        throw lastError ?? CacheServiceError.networkError("Unknown error")
    }
}

// MARK: - Mock Client for Testing

#if DEBUG
    /// Mock cache client for testing
    actor MockCacheServiceClient: CacheServiceClientProtocol {
        private var storage: [String: (value: String, expiry: Date?)] = [:]

        func get(_ key: String) async throws -> String? {
            guard let entry = storage[key] else {
                return nil
            }

            if let expiry = entry.expiry, expiry < Date() {
                storage.removeValue(forKey: key)
                return nil
            }

            return entry.value
        }

        func set(_ key: String, value: String, ttl: Int) async throws {
            let expiry = Date().addingTimeInterval(TimeInterval(ttl))
            storage[key] = (value, expiry)
        }

        func delete(_ key: String) async throws {
            storage.removeValue(forKey: key)
        }

        func incr(_ key: String) async throws -> Int {
            let current = try await Int(get(key) ?? "0") ?? 0
            let new = current + 1
            try await set(key, value: String(new), ttl: 3600)
            return new
        }

        func expire(_ key: String, ttl: Int) async throws -> Bool {
            guard let entry = storage[key] else { return false }
            let expiry = Date().addingTimeInterval(TimeInterval(ttl))
            storage[key] = (entry.value, expiry)
            return true
        }

        func exists(_ key: String) async throws -> Bool {
            guard let entry = storage[key] else {
                return false
            }

            if let expiry = entry.expiry, expiry < Date() {
                storage.removeValue(forKey: key)
                return false
            }

            return true
        }

        func ttl(_ key: String) async throws -> Int {
            guard let entry = storage[key] else {
                return -2
            }

            guard let expiry = entry.expiry else {
                return -1
            }

            let remaining = expiry.timeIntervalSinceNow
            return remaining > 0 ? Int(remaining) : -2
        }

        /// Reset storage for testing
        func reset() {
            storage.removeAll()
        }
    }
#endif

#endif
