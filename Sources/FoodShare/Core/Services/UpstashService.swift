//
//  UpstashService.swift
//  Foodshare
//
//  Upstash Redis service wrapper via CacheAPIService
//



#if !SKIP
import Foundation
import OSLog

// MARK: - Upstash Service
// Note: CacheError is defined in Core/Cache/CacheStrategy.swift

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
            throw CacheError.encodingFailed
        }
        try await set(key, value: jsonString, expirationSeconds: expirationSeconds)
    }

    func getJSON<T: Decodable>(_ key: String, as type: T.Type) async throws -> T? {
        guard let jsonString = try await get(key) else {
            return nil
        }
        guard let data = jsonString.data(using: .utf8) else {
            throw CacheError.decodingFailed
        }
        let decoder = JSONDecoder()
        return try decoder.decode(type, from: data)
    }
}


#endif
