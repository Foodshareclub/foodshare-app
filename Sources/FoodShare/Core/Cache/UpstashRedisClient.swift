//
//  UpstashRedisClient.swift
//  Foodshare
//
//  Upstash Redis REST API client for serverless caching and rate limiting.
//  Provides production-ready HTTP-based Redis operations optimized for iOS.
//
//  Features:
//  - REST API based (no persistent connections)
//  - Automatic retry with exponential backoff
//  - Connection pooling via URLSession
//  - Type-safe operations
//  - Error handling and logging
//

import Foundation
import OSLog
import Supabase

// MARK: - Upstash Redis Client Protocol

/// Protocol defining Redis operations via Upstash REST API
protocol UpstashRedisClient: Sendable {
    /// Get value from Redis
    func get(_ key: String) async throws -> String?

    /// Set value in Redis
    func set(_ key: String, value: String) async throws

    /// Set value with expiration (TTL in seconds)
    func setex(_ key: String, value: String, ttl: Int) async throws

    /// Delete key from Redis
    func delete(_ key: String) async throws

    /// Set expiration on existing key
    func expire(_ key: String, ttl: Int) async throws

    /// Check if key exists
    func exists(_ key: String) async throws -> Bool

    /// Increment counter (returns new value)
    func incr(_ key: String) async throws -> Int

    /// Increment counter by amount
    func incrby(_ key: String, amount: Int) async throws -> Int

    /// Get TTL for key (-1 if no expiry, -2 if key doesn't exist)
    func ttl(_ key: String) async throws -> Int

    /// Execute pipeline of commands (batch operations)
    func pipeline(_ commands: [RedisCommand]) async throws -> [RedisResponse]
}

// MARK: - Redis Command

/// Represents a Redis command for pipeline execution
struct RedisCommand: Sendable {
    let command: String
    let args: [String]

    init(_ command: String, _ args: String...) {
        self.command = command.uppercased()
        self.args = args
    }

    var commandArray: [String] {
        [command] + args
    }
}

// MARK: - Redis Response

/// Response from Redis command execution
enum RedisResponse: Sendable {
    case string(String)
    case integer(Int)
    case null
    case error(String)
    case array([RedisResponse])

    var stringValue: String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    var intValue: Int? {
        if case let .integer(value) = self {
            return value
        }
        return nil
    }
}

// MARK: - Redis Error

enum RedisError: LocalizedError, Sendable {
    case invalidURL
    case invalidCredentials
    case requestFailed(String)
    case decodingError(String)
    case rateLimitExceeded
    case connectionTimeout
    case invalidResponse
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid Upstash Redis URL"
        case .invalidCredentials:
            "Invalid Upstash Redis credentials"
        case let .requestFailed(message):
            "Redis request failed: \(message)"
        case let .decodingError(message):
            "Failed to decode Redis response: \(message)"
        case .rateLimitExceeded:
            "Redis rate limit exceeded"
        case .connectionTimeout:
            "Connection to Redis timed out"
        case .invalidResponse:
            "Invalid response from Redis"
        case let .serverError(message):
            "Redis server error: \(message)"
        }
    }
}

// MARK: - Upstash Redis Client Implementation

/// Production-ready Upstash Redis client using REST API
actor UpstashRedisClientImpl: UpstashRedisClient {
    private let restURL: URL
    private let token: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let logger: Logger

    // Retry configuration
    private let maxRetries: Int
    private let initialBackoff: TimeInterval

    init(
        restURL: URL,
        token: String,
        session: URLSession = .shared,
        maxRetries: Int = 3,
        initialBackoff: TimeInterval = 0.5,
        logger: Logger = Logger(subsystem: "com.flutterflow.foodshare", category: "redis"),
    ) {
        self.restURL = restURL
        self.token = token
        self.session = session
        self.maxRetries = maxRetries
        self.initialBackoff = initialBackoff
        self.logger = logger

        decoder = JSONDecoder()

        logger.debug("Upstash Redis client initialized")
    }

    // SECURITY: Direct Vault access removed - use CacheServiceClient instead
    //
    // The previous `fromVault()` method exposed a critical security vulnerability:
    // - Any authenticated user could call get_secret() RPC to enumerate all secrets
    // - No audit logging of secret access
    // - Secrets persisted in app memory
    //
    // Use CacheServiceClient for production which routes through the secure
    // cache-operation Edge Function with proper authentication, rate limiting,
    // and audit logging.
    //
    // For local development/testing, use environment variables:
    //   - UPSTASH_REDIS_URL
    //   - UPSTASH_REDIS_TOKEN
    //
    // Or use the MockUpstashRedisClient in DEBUG builds.

    /// Initialize from environment variables (for local development only)
    static func fromEnvironment() throws -> UpstashRedisClientImpl {
        guard let urlString = ProcessInfo.processInfo.environment["UPSTASH_REDIS_URL"],
              let token = ProcessInfo.processInfo.environment["UPSTASH_REDIS_TOKEN"],
              let url = URL(string: urlString) else {
            throw RedisError.invalidCredentials
        }

        return UpstashRedisClientImpl(restURL: url, token: token)
    }

    // MARK: - Public API

    func get(_ key: String) async throws -> String? {
        let response = try await execute(["GET", key])
        return response.stringValue
    }

    func set(_ key: String, value: String) async throws {
        _ = try await execute(["SET", key, value])
    }

    func setex(_ key: String, value: String, ttl: Int) async throws {
        _ = try await execute(["SETEX", key, String(ttl), value])
    }

    func delete(_ key: String) async throws {
        _ = try await execute(["DEL", key])
    }

    func expire(_ key: String, ttl: Int) async throws {
        _ = try await execute(["EXPIRE", key, String(ttl)])
    }

    func exists(_ key: String) async throws -> Bool {
        let response = try await execute(["EXISTS", key])
        return response.intValue == 1
    }

    func incr(_ key: String) async throws -> Int {
        let response = try await execute(["INCR", key])
        guard let value = response.intValue else {
            throw RedisError.invalidResponse
        }
        return value
    }

    func incrby(_ key: String, amount: Int) async throws -> Int {
        let response = try await execute(["INCRBY", key, String(amount)])
        guard let value = response.intValue else {
            throw RedisError.invalidResponse
        }
        return value
    }

    func ttl(_ key: String) async throws -> Int {
        let response = try await execute(["TTL", key])
        guard let value = response.intValue else {
            throw RedisError.invalidResponse
        }
        return value
    }

    func pipeline(_ commands: [RedisCommand]) async throws -> [RedisResponse] {
        let commandArrays = commands.map(\.commandArray)
        return try await executePipeline(commandArrays)
    }

    // MARK: - Private Implementation

    private func execute(_ command: [String]) async throws -> RedisResponse {
        try await executeWithRetry {
            try await self.performRequest(command)
        }
    }

    private func executePipeline(_ commands: [[String]]) async throws -> [RedisResponse] {
        try await executeWithRetry {
            try await self.performPipelineRequest(commands)
        }
    }

    private func performRequest(_ command: [String]) async throws -> RedisResponse {
        var request = URLRequest(url: restURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = try JSONSerialization.data(withJSONObject: command)
        request.httpBody = body

        logger.debug("Redis command: \(command.joined(separator: " "))")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RedisError.invalidResponse
        }

        try validateResponse(httpResponse)

        return try parseResponse(data)
    }

    private func performPipelineRequest(_ commands: [[String]]) async throws -> [RedisResponse] {
        var request = URLRequest(url: restURL.appendingPathComponent("pipeline"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let body = try JSONSerialization.data(withJSONObject: commands)
        request.httpBody = body

        logger.debug("Redis pipeline: \(commands.count) commands")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RedisError.invalidResponse
        }

        try validateResponse(httpResponse)

        return try parsePipelineResponse(data)
    }

    private func validateResponse(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200 ... 299:
            return
        case 401, 403:
            throw RedisError.invalidCredentials
        case 429:
            throw RedisError.rateLimitExceeded
        case 500 ... 599:
            throw RedisError.serverError("HTTP \(response.statusCode)")
        default:
            throw RedisError.requestFailed("HTTP \(response.statusCode)")
        }
    }

    private func parseResponse(_ data: Data) throws -> RedisResponse {
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            throw RedisError.decodingError("Invalid JSON response")
        }

        return try parseValue(json)
    }

    private func parsePipelineResponse(_ data: Data) throws -> [RedisResponse] {
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
            throw RedisError.decodingError("Invalid pipeline response")
        }

        return try jsonArray.map { try parseValue($0) }
    }

    private func parseValue(_ value: Any) throws -> RedisResponse {
        if let string = value as? String {
            return .string(string)
        } else if let int = value as? Int {
            return .integer(int)
        } else if let array = value as? [Any] {
            return try .array(array.map { try parseValue($0) })
        } else if value is NSNull {
            return .null
        } else {
            throw RedisError.decodingError("Unknown value type: \(type(of: value))")
        }
    }

    private func executeWithRetry<T>(
        operation: @Sendable () async throws -> T,
    ) async throws -> T {
        var lastError: Error?
        var backoff = initialBackoff

        for attempt in 0 ... maxRetries {
            do {
                return try await operation()
            } catch let error as RedisError {
                // Don't retry authentication or rate limit errors
                switch error {
                case .invalidCredentials, .rateLimitExceeded:
                    throw error
                default:
                    lastError = error
                }
            } catch {
                lastError = error
            }

            if attempt < self.maxRetries {
                logger.debug("Retry attempt \(attempt + 1)/\(self.maxRetries)")
                try await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
                backoff *= 2 // Exponential backoff
            }
        }

        throw lastError ?? RedisError.requestFailed("Unknown error")
    }
}

// MARK: - Mock Client for Testing

#if DEBUG
    actor MockUpstashRedisClient: UpstashRedisClient {
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

        func set(_ key: String, value: String) async throws {
            storage[key] = (value, nil)
        }

        func setex(_ key: String, value: String, ttl: Int) async throws {
            let expiry = Date().addingTimeInterval(TimeInterval(ttl))
            storage[key] = (value, expiry)
        }

        func delete(_ key: String) async throws {
            storage.removeValue(forKey: key)
        }

        func expire(_ key: String, ttl: Int) async throws {
            guard let entry = storage[key] else { return }
            let expiry = Date().addingTimeInterval(TimeInterval(ttl))
            storage[key] = (entry.value, expiry)
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

        func incr(_ key: String) async throws -> Int {
            let current = try await Int(get(key) ?? "0") ?? 0
            let new = current + 1
            try await set(key, value: String(new))
            return new
        }

        func incrby(_ key: String, amount: Int) async throws -> Int {
            let current = try await Int(get(key) ?? "0") ?? 0
            let new = current + amount
            try await set(key, value: String(new))
            return new
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

        func pipeline(_ commands: [RedisCommand]) async throws -> [RedisResponse] {
            var results: [RedisResponse] = []

            for command in commands {
                switch command.command {
                case "GET":
                    if let value = try await get(command.args[0]) {
                        results.append(.string(value))
                    } else {
                        results.append(.null)
                    }
                case "SET":
                    try await set(command.args[0], value: command.args[1])
                    results.append(.string("OK"))
                case "INCR":
                    let value = try await incr(command.args[0])
                    results.append(.integer(value))
                default:
                    results.append(.error("Unsupported command"))
                }
            }

            return results
        }
    }
#endif
