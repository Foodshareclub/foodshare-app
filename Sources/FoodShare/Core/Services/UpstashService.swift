//
//  UpstashService.swift
//  Foodshare
//
//  Upstash Redis service wrapper via CacheAPIService
//

import Foundation
import OSLog

// MARK: - Cache Errors

enum CacheError: Error, LocalizedError {
    case notAuthenticated
    case invalidKey(String)
    case operationFailed(String)
    case networkError(Error)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            "User must be authenticated to use cache"
        case let .invalidKey(reason):
            "Invalid cache key: \(reason)"
        case let .operationFailed(message):
            "Cache operation failed: \(message)"
        case let .networkError(error):
            "Network error: \(error.localizedDescription)"
        case .decodingError:
            "Failed to decode cache response"
        }
    }
}

// MARK: - Upstash Service

final class UpstashService: Sendable {
    static let shared = UpstashService()

    private let api: CacheAPIService
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "UpstashService")

    private init(api: CacheAPIService = .shared) {
        self.api = api
    }

    // MARK: - Public API

    func get(_ key: String) async throws -> String? {
        try await api.get(key: key)?.value
    }

    func set(_ key: String, value: String, expirationSeconds: Int? = nil) async throws {
        try await api.set(key: key, value: value, ttl: expirationSeconds ?? 3600)
        logger.debug("✅ [CACHE] Set key: \(key)")
    }

    func delete(_ key: String) async throws {
        try await api.delete(key: key)
        logger.debug("✅ [CACHE] Deleted key: \(key)")
    }

    func increment(_ key: String) async throws -> Int {
        try await api.increment(key: key)
    }

    func expire(_ key: String, seconds: Int) async throws {
        try await api.expire(key: key, seconds: seconds)
    }

    func exists(_ key: String) async throws -> Bool {
        try await api.exists(key: key)
    }

    func ttl(_ key: String) async throws -> Int {
        try await api.ttl(key: key)
    }
}

// MARK: - Convenience Extensions

extension UpstashService {
    func setJSON(_ key: String, value: some Encodable, expirationSeconds: Int? = nil) async throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CacheError.operationFailed("Failed to encode value to JSON")
        }
        try await set(key, value: jsonString, expirationSeconds: expirationSeconds)
    }

    func getJSON<T: Decodable>(_ key: String, as type: T.Type) async throws -> T? {
        guard let jsonString = try await get(key) else {
            return nil
        }
        guard let data = jsonString.data(using: .utf8) else {
            throw CacheError.decodingError
        }
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}
