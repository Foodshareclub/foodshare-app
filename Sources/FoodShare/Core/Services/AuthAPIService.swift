//
//  AuthAPIService.swift
//  Foodshare
//
//  Centralized API service for authentication
//

import Foundation

actor AuthAPIService {
    nonisolated static let shared = AuthAPIService()
    private let client: APIClient
    
    init(client: APIClient = .shared) {
        self.client = client
    }
    
    func signUp(email: String, password: String, name: String) async throws -> AuthResponse {
        try await client.post("api-v1-auth/signup", body: [
            "email": email,
            "password": password,
            "name": name
        ])
    }
    
    func signIn(email: String, password: String) async throws -> AuthResponse {
        try await client.post("api-v1-auth/signin", body: [
            "email": email,
            "password": password
        ])
    }
    
    func refreshSession() async throws -> AuthResponse {
        try await client.post("api-v1-auth/refresh", body: EmptyBody())
    }
    
    func signOut() async throws {
        let _: EmptyResponse = try await client.post("api-v1-auth/signout", body: EmptyBody())
    }
    
    func getSession() async throws -> SessionInfo {
        try await client.get("api-v1-auth/session")
    }
    
    func updateSession(locale: String) async throws {
        let _: EmptyResponse = try await client.put("api-v1-auth/session", body: ["locale": locale])
    }
    
    func deleteAccount() async throws {
        let _: EmptyResponse = try await client.post("api-v1-auth/delete-account", body: EmptyBody())
    }
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
}

struct AuthUser: Codable {
    let id: String
    let email: String
    let name: String
}

struct SessionInfo: Codable {
    let userId: String
    let locale: String
    let localeSource: String
}
