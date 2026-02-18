//
//  CacheAPIService.swift
//  Foodshare
//
//  Centralized API service for cache operations
//


#if !SKIP
import Foundation

actor CacheAPIService {
    nonisolated static let shared = CacheAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func get(key: String) async throws -> CacheValue? {
        try await client.get("api-v1-cache", params: ["key": key])
    }
    
    func set(key: String, value: String, ttl: Int? = nil) async throws {
        let body = CacheSetRequest(key: key, value: value, ttl: ttl)
        let _: EmptyResponse = try await client.post("api-v1-cache", body: body)
    }
    
    func delete(key: String) async throws {
        let _: EmptyResponse = try await client.delete("api-v1-cache", params: ["key": key])
    }
    
    func invalidate(pattern: String) async throws {
        let _: EmptyResponse = try await client.post("api-v1-cache/invalidate", body: ["pattern": pattern])
    }
    
    func increment(key: String) async throws -> Int {
        let response: IncrementResponse = try await client.post("api-v1-cache/increment", body: ["key": key])
        return response.value
    }
    
    func expire(key: String, seconds: Int) async throws {
        let _: EmptyResponse = try await client.post("api-v1-cache/expire", body: CacheExpireRequest(key: key, seconds: seconds))
    }
    
    func exists(key: String) async throws -> Bool {
        let response: ExistsResponse = try await client.get("api-v1-cache/exists", params: ["key": key])
        return response.exists
    }
    
    func ttl(key: String) async throws -> Int {
        let response: TTLResponse = try await client.get("api-v1-cache/ttl", params: ["key": key])
        return response.ttl
    }
}

struct CacheSetRequest: Encodable {
    let key: String
    let value: String
    let ttl: Int?
}

struct CacheExpireRequest: Encodable {
    let key: String
    let seconds: Int
}

struct CacheValue: Codable {
    let value: String
    let ttl: Int?
}

struct IncrementResponse: Codable {
    let value: Int
}

struct ExistsResponse: Codable {
    let exists: Bool
}

struct TTLResponse: Codable {
    let ttl: Int
}

#endif
