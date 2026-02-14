//
//  AdminAPIService.swift
//  Foodshare
//
//  REST API client for admin operations via api-v1-admin edge function.
//  Routes use path-based routing: api-v1-admin/users, api-v1-admin/listings, etc.
//

import Foundation
import OSLog

actor AdminAPIService {
    nonisolated static let shared = AdminAPIService()
    private let client: APIClient
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AdminAPI")

    init(client: APIClient = .shared) {
        self.client = client
    }

    // MARK: - Users

    /// List users with optional search, role filter, and pagination
    func getUsers(
        search: String? = nil,
        role: String? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [AdminUserProfile] {
        var params: [String: String] = [
            "limit": "\(limit)",
            "offset": "\(offset)",
        ]
        if let search, !search.isEmpty { params["search"] = search }
        if let role, !role.isEmpty { params["role"] = role }

        return try await client.get("api-v1-admin/users", params: params)
    }

    /// Ban a user by ID with a reason
    func banUser(userId: UUID, reason: String) async throws {
        let body = BanUserBody(reason: reason)
        try await client.postVoid("api-v1-admin/users/\(userId.uuidString)/ban", body: body)
    }

    /// Unban a user by ID
    func unbanUser(userId: UUID) async throws {
        try await client.postVoid("api-v1-admin/users/\(userId.uuidString)/unban")
    }

    /// Update a single role for a user
    func updateUserRole(userId: UUID, roleId: Int) async throws {
        let body = UpdateRoleBody(roleId: roleId)
        try await client.putVoid("api-v1-admin/users/\(userId.uuidString)/role", body: body)
    }

    // MARK: - Listings

    /// Activate a listing by ID
    func activateListing(id: Int) async throws {
        try await client.putVoid("api-v1-admin/listings/\(id)/activate", body: EmptyBody())
    }

    /// Deactivate a listing by ID
    func deactivateListing(id: Int) async throws {
        try await client.putVoid("api-v1-admin/listings/\(id)/deactivate", body: EmptyBody())
    }

    /// Delete a listing by ID
    func deleteListing(id: Int) async throws {
        try await client.deleteVoid("api-v1-admin/listings/\(id)")
    }

    /// Bulk activate listings by IDs
    func bulkActivate(ids: [Int]) async throws {
        let body = BulkIdsBody(ids: ids)
        try await client.postVoid("api-v1-admin/listings/bulk/activate", body: body)
    }

    /// Bulk deactivate listings by IDs
    func bulkDeactivate(ids: [Int]) async throws {
        let body = BulkIdsBody(ids: ids)
        try await client.postVoid("api-v1-admin/listings/bulk/deactivate", body: body)
    }

    /// Bulk delete listings by IDs
    func bulkDelete(ids: [Int]) async throws {
        let body = BulkIdsBody(ids: ids)
        try await client.postVoid("api-v1-admin/listings/bulk/delete", body: body)
    }
}

// MARK: - Request Bodies

private struct BanUserBody: Encodable {
    let reason: String
}

private struct UpdateRoleBody: Encodable {
    let roleId: Int
}

private struct BulkIdsBody: Encodable {
    let ids: [Int]
}
