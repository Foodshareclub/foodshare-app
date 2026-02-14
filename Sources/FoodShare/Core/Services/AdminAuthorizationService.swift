//
//  AdminAuthorizationService.swift
//  Foodshare
//
//  Role-based authorization service following CareEcho pattern
//  Handles admin and super admin permissions
//

import Foundation
import OSLog
import Supabase

// MARK: - User Role Check (for querying user_roles table)

/// Lightweight struct for checking user roles from user_roles table
private struct UserRoleCheck: Codable {
    let roleId: Int
    let role: RoleInfo?

    enum CodingKeys: String, CodingKey {
        case roleId = "role_id"
        case role
    }

    struct RoleInfo: Codable {
        let name: String
    }
}

/// Lightweight struct for querying roles table
private struct RoleRecord: Codable {
    let id: Int
    let name: String
}

// MARK: - Admin Permission

/// Permissions available in the admin system
enum AdminPermission: String, CaseIterable, Sendable {
    // Standard admin permissions
    case viewAnalytics
    case viewUsers
    case viewListings
    case manageListings
    case manageReports

    // Super admin only permissions
    case manageUsers
    case manageSettings
    case viewSystemLogs
}

// MARK: - Admin Authorization Service

@MainActor
@Observable
final class AdminAuthorizationService {
    static let shared = AdminAuthorizationService()

    // MARK: - State

    private(set) var isAdminUser = false
    private(set) var isSuperAdminUser = false
    private(set) var currentUserRole = "user"
    private(set) var isLoading = false

    // MARK: - Dependencies

    private let authService: AuthenticationService
    private let logger = Logger(subsystem: "com.flutterflow.foodshare", category: "AdminAuthorizationService")

    // MARK: - Initialization

    private init(authService: AuthenticationService = .shared) {
        self.authService = authService
        logger.info("🔐 [ADMIN] AdminAuthorizationService initialized")
    }

    // MARK: - Role Checking

    /// Check if the current user is an admin (includes super admin)
    /// Queries the user_roles table joined with roles
    func isAdmin() async throws -> Bool {
        guard authService.isAuthenticated else {
            logger.warning("⚠️ [ADMIN] User not authenticated")
            return false
        }

        guard let userId = authService.currentUser?.id else {
            logger.warning("⚠️ [ADMIN] No current user profile")
            return false
        }

        // Query user_roles table to check for admin role
        let isAdmin = try await checkUserHasAdminRole(userId: userId)

        await MainActor.run {
            self.isAdminUser = isAdmin
            self.currentUserRole = isAdmin ? "admin" : "user"
        }

        logger.debug("🔐 [ADMIN] isAdmin check: \(isAdmin)")
        return isAdmin
    }

    /// Check if the current user is a super admin
    /// Queries the user_roles table joined with roles
    func isSuperAdmin() async throws -> Bool {
        guard authService.isAuthenticated else {
            logger.warning("⚠️ [ADMIN] User not authenticated")
            return false
        }

        guard let userId = authService.currentUser?.id else {
            logger.warning("⚠️ [ADMIN] No current user profile")
            return false
        }

        // Query user_roles table to check for super_admin role
        let isSuperAdmin = try await checkUserHasSuperAdminRole(userId: userId)
        let hasAdminRole = try await checkUserHasAdminRole(userId: userId)
        let isAdmin = isSuperAdmin || hasAdminRole

        await MainActor.run {
            self.isSuperAdminUser = isSuperAdmin
            self.currentUserRole = isSuperAdmin ? "super_admin" : (isAdmin ? "admin" : "user")
        }

        logger.debug("🔐 [ADMIN] isSuperAdmin check: \(isSuperAdmin)")
        return isSuperAdmin
    }

    /// Query user_roles table to check if user has admin role
    private func checkUserHasAdminRole(userId: UUID) async throws -> Bool {
        let response: [UserRoleCheck] = try await authService.supabase
            .from("user_roles")
            .select("role_id, role:roles(name)")
            .eq("profile_id", value: userId.uuidString)
            .execute()
            .value

        return response.contains { $0.role?.name == "admin" || $0.role?.name == "super_admin" }
    }

    /// Query user_roles table to check if user has super_admin role
    private func checkUserHasSuperAdminRole(userId: UUID) async throws -> Bool {
        let response: [UserRoleCheck] = try await authService.supabase
            .from("user_roles")
            .select("role_id, role:roles(name)")
            .eq("profile_id", value: userId.uuidString)
            .execute()
            .value

        return response.contains { $0.role?.name == "super_admin" }
    }

    // MARK: - Permission Checking

    /// Check if the current user has a specific permission
    func hasPermission(_ permission: AdminPermission) async throws -> Bool {
        let isAdmin = try await isAdmin()

        // Super admins have all permissions
        if isSuperAdminUser {
            logger.debug("🔐 [ADMIN] Super admin has all permissions")
            return true
        }

        guard isAdmin else {
            logger.debug("🔐 [ADMIN] Non-admin lacks permission: \(permission.rawValue)")
            return false
        }

        // Regular admins have most permissions
        switch permission {
        case .viewAnalytics, .viewUsers, .viewListings:
            return true
        case .manageListings, .manageReports:
            return true
        case .manageUsers, .manageSettings, .viewSystemLogs:
            // Super admin only permissions
            return isSuperAdminUser
        }
    }

    // MARK: - Require Role (Throws if not authorized)

    /// Require the current user to be an admin, throws if not
    func requireAdmin() async throws {
        let isAdmin = try await isAdmin()
        guard isAdmin else {
            logger.error("❌ [ADMIN] Admin access required but user is not admin")
            throw AdminAuthorizationError.adminRequired
        }
        logger.debug("✅ [ADMIN] Admin requirement satisfied")
    }

    /// Require the current user to be a super admin, throws if not
    func requireSuperAdmin() async throws {
        let isSuperAdmin = try await isSuperAdmin()
        guard isSuperAdmin else {
            logger.error("❌ [ADMIN] Super admin access required but user is not super admin")
            throw AdminAuthorizationError.superAdminRequired
        }
        logger.debug("✅ [ADMIN] Super admin requirement satisfied")
    }

    /// Require the current user to have a specific permission
    func requirePermission(_ permission: AdminPermission) async throws {
        let hasPermission = try await hasPermission(permission)
        guard hasPermission else {
            logger.error("❌ [ADMIN] Permission required: \(permission.rawValue)")
            throw AdminAuthorizationError.permissionDenied(permission)
        }
        logger.debug("✅ [ADMIN] Permission requirement satisfied: \(permission.rawValue)")
    }

    // MARK: - Role Management (Super Admin Only)

    /// Grant admin role to a user (super admin only)
    /// Inserts a row into user_roles table linking profile to admin role
    func grantAdminRole(to userId: UUID) async throws {
        try await requireSuperAdmin()

        guard let grantedBy = authService.currentUser?.id else {
            throw AdminAuthorizationError.userNotAuthenticated
        }

        logger.info("🔐 [ADMIN] Granting admin role to user: \(userId, privacy: .private(mask: .hash))")

        do {
            // First, get the admin role ID from roles table
            let roles: [RoleRecord] = try await authService.supabase
                .from("roles")
                .select("id, name")
                .eq("name", value: "admin")
                .execute()
                .value

            guard let adminRole = roles.first else {
                throw AdminAuthorizationError.adminRequired // Role doesn't exist
            }

            // Insert into user_roles table
            try await authService.supabase
                .from("user_roles")
                .insert([
                    "profile_id": userId.uuidString,
                    "role_id": String(adminRole.id),
                    "granted_by": grantedBy.uuidString
                ])
                .execute()

            logger.info("✅ [ADMIN] Admin role granted to user: \(userId, privacy: .private(mask: .hash))")
        } catch {
            logger.error("❌ [ADMIN] Failed to grant admin role: \(error.localizedDescription)")
            throw error
        }
    }

    /// Revoke admin role from a user (super admin only)
    /// Deletes the row from user_roles table
    func revokeAdminRole(from userId: UUID) async throws {
        try await requireSuperAdmin()

        logger.info("🔐 [ADMIN] Revoking admin role from user: \(userId, privacy: .private(mask: .hash))")

        do {
            // Get the admin role ID
            let roles: [RoleRecord] = try await authService.supabase
                .from("roles")
                .select("id, name")
                .eq("name", value: "admin")
                .execute()
                .value

            guard let adminRole = roles.first else {
                throw AdminAuthorizationError.adminRequired
            }

            // Delete from user_roles table
            try await authService.supabase
                .from("user_roles")
                .delete()
                .eq("profile_id", value: userId.uuidString)
                .eq("role_id", value: adminRole.id)
                .execute()

            logger.info("✅ [ADMIN] Admin role revoked from user: \(userId, privacy: .private(mask: .hash))")
        } catch {
            logger.error("❌ [ADMIN] Failed to revoke admin role: \(error.localizedDescription)")
            throw error
        }
    }

    // MARK: - Refresh

    /// Refresh the admin status from the current user profile
    func refresh() async throws {
        logger.debug("🔄 [ADMIN] Refreshing admin status...")

        // Reload user profile to get fresh role data
        try await authService.reloadUserProfile()

        // Re-check admin status
        _ = try await isAdmin()
        _ = try await isSuperAdmin()

        logger.debug("✅ [ADMIN] Admin status refreshed")
    }
}

// MARK: - Admin Authorization Error

enum AdminAuthorizationError: LocalizedError, Sendable {
    case adminRequired
    case superAdminRequired
    case permissionDenied(AdminPermission)
    case userNotAuthenticated

    var errorDescription: String? {
        switch self {
        case .adminRequired:
            "Admin access is required for this action"
        case .superAdminRequired:
            "Super admin access is required for this action"
        case let .permissionDenied(permission):
            "Permission denied: \(permission.rawValue)"
        case .userNotAuthenticated:
            "User is not authenticated"
        }
    }
}
