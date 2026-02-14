import Foundation
import Supabase
import FoodShareRepository

// MARK: - Supabase Admin Repository

/// Supabase implementation of AdminRepository
@MainActor
final class SupabaseAdminRepository: BaseSupabaseRepository, AdminRepository {
    private let adminAPI: AdminAPIService
    
    init(supabase: Supabase.SupabaseClient, adminAPI: AdminAPIService = .shared) {
        self.adminAPI = adminAPI
        super.init(supabase: supabase, subsystem: "com.flutterflow.foodshare", category: "AdminRepository")
    }

    // MARK: - Dashboard (Server-Side)

    func fetchDashboardStats() async throws -> AdminDashboardStats {
        let dto: DashboardStatsDTO = try await executeRPC("get_dashboard_stats", params: EmptyParams())
        
        return AdminDashboardStats(
            totalUsers: dto.totalUsers,
            activeUsers: dto.activeUsers,
            totalPosts: dto.totalPosts,
            activePosts: dto.activePosts,
            pendingReports: dto.pendingReports,
            totalMessages: dto.totalMessages,
            newUsersToday: dto.newUsersToday,
            newPostsToday: dto.newPostsToday
        )
    }

    // MARK: - Moderation Stats (Server-Side)

    func fetchModerationStats() async throws -> ModerationStatsResult {
        let dto: ModerationStatsDTO = try await executeRPC("get_moderation_stats", params: EmptyParams())
        
        return ModerationStatsResult(
            pendingCount: dto.pendingCount,
            highPriorityCount: dto.highPriorityCount,
            resolvedToday: dto.resolvedToday,
            totalReports: dto.totalReports
        )
    }

    // MARK: - Users

    func fetchUsers(
        searchQuery: String?,
        roleFilter: String?,
        limit: Int,
        offset: Int
    ) async throws -> [AdminUserProfile] {
        do {
            return try await adminAPI.getUsers(
                search: searchQuery,
                role: roleFilter,
                limit: limit,
                offset: offset
            )
        } catch {
            // Fallback to direct RPC if Edge Function is unavailable
            return try await executeRPC(
                "get_admin_users",
                params: AdminUsersParams(
                    pSearchQuery: searchQuery,
                    pRoleFilter: roleFilter,
                    pLimit: limit,
                    pOffset: offset
                )
            )
        }
    }

    func fetchUser(id: UUID) async throws -> AdminUserProfile {
        try await fetchOne(
            from: "profiles",
            select: """
                id, nickname, email, avatar_url, is_verified, is_active, created_time, last_seen_at,
                user_roles(role_id, role:roles(id, name))
            """,
            id: id.hashValue
        )
    }

    func updateUserStatus(userId: UUID, isActive: Bool) async throws {
        try await update(
            table: "profiles",
            id: userId.hashValue,
            value: ["is_active": isActive]
        )
    }

    func banUser(userId: UUID, reason: String) async throws {
        do {
            try await adminAPI.banUser(userId: userId, reason: reason)
        } catch {
            // Fallback to direct Supabase if Edge Function is unavailable
            try await supabase
                .from("profiles")
                .update(["is_active": false])
                .eq("id", value: userId)
                .execute()

            try await supabase
                .from("forum_user_warnings")
                .insert([
                    "profile_id": userId.uuidString,
                    "warning_type": "perm_ban",
                    "reason": reason,
                ])
                .execute()
        }
    }

    func unbanUser(userId: UUID) async throws {
        do {
            try await adminAPI.unbanUser(userId: userId)
        } catch {
            // Fallback to direct Supabase if Edge Function is unavailable
            try await supabase
                .from("profiles")
                .update(["is_active": true])
                .eq("id", value: userId)
                .execute()
        }
    }

    // MARK: - Roles

    func fetchRoles() async throws -> [Role] {
        let response: [Role] = try await supabase
            .from("roles")
            .select()
            .order("id", ascending: true)
            .execute()
            .value

        return response
    }

    func fetchUserRoles(userId: UUID) async throws -> [UserRole] {
        let response: [UserRole] = try await supabase
            .from("user_roles")
            .select("*, role:roles(*)")
            .eq("profile_id", value: userId)
            .execute()
            .value

        return response
    }

    func assignRole(userId: UUID, roleId: Int, grantedBy: UUID) async throws {
        try await supabase
            .from("user_roles")
            .insert([
                "profile_id": userId.uuidString,
                "role_id": String(roleId),
                "granted_by": grantedBy.uuidString
            ])
            .execute()
    }

    func revokeRole(userId: UUID, roleId: Int) async throws {
        try await supabase
            .from("user_roles")
            .delete()
            .eq("profile_id", value: userId)
            .eq("role_id", value: roleId)
            .execute()
    }

    // MARK: - Moderation

    func fetchModerationQueue(
        status: String?,
        contentType: String?,
        limit: Int,
        offset: Int,
    ) async throws -> [ModerationQueueItem] {
        var query = supabase
            .from("forum_moderation_queue")
            .select("""
                *,
                reporter:profiles!forum_moderation_queue_reporter_id_fkey(id, nickname, avatar_url),
                target_user:profiles!forum_moderation_queue_profile_id_fkey(id, nickname, avatar_url)
            """)

        if let status {
            query = query.eq("status", value: status)
        }

        if let contentType {
            query = query.eq("content_type", value: contentType)
        }

        let response: [ModerationQueueItem] = try await query
            .order("priority", ascending: false)
            .order("created_at", ascending: true)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return response
    }

    func resolveModerationItem(
        itemId: UUID,
        resolution: String,
        notes: String?,
        resolvedBy: UUID,
    ) async throws {
        struct ResolveModerationDTO: Encodable {
            let status: String
            let resolution: String
            let resolved_by: String
            let resolved_at: String
            let resolution_notes: String?
        }

        let updateData = ResolveModerationDTO(
            status: "resolved",
            resolution: resolution,
            resolved_by: resolvedBy.uuidString,
            resolved_at: Date().ISO8601Format(),
            resolution_notes: notes,
        )

        try await supabase
            .from("forum_moderation_queue")
            .update(updateData)
            .eq("id", value: itemId)
            .execute()
    }

    // MARK: - Content Management

    func deletePost(postId: Int, reason: String) async throws {
        do {
            try await adminAPI.deactivateListing(id: postId)
        } catch {
            // Fallback to direct Supabase if Edge Function is unavailable
            try await supabase
                .from("posts")
                .update(["is_active": false])
                .eq("id", value: postId)
                .execute()
        }
    }

    func restorePost(postId: Int) async throws {
        do {
            try await adminAPI.activateListing(id: postId)
        } catch {
            // Fallback to direct Supabase if Edge Function is unavailable
            try await supabase
                .from("posts")
                .update(["is_active": true])
                .eq("id", value: postId)
                .execute()
        }
    }

    func deleteComment(commentId: Int, reason: String) async throws {
        try await supabase
            .from("comments")
            .delete()
            .eq("id", value: commentId)
            .execute()
    }

    // MARK: - Audit Log

    func fetchAuditLogs(
        adminId: UUID?,
        action: String?,
        resourceType: String?,
        limit: Int,
        offset: Int,
    ) async throws -> [AdminAuditLog] {
        var query = supabase
            .from("admin_audit_log")
            .select("*, admin:profiles!admin_audit_log_admin_id_fkey(id, nickname, avatar_url)")

        if let adminId {
            query = query.eq("admin_id", value: adminId)
        }

        if let action {
            query = query.eq("action", value: action)
        }

        if let resourceType {
            query = query.eq("resource_type", value: resourceType)
        }

        let response: [AdminAuditLog] = try await query
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value

        return response
    }

    func logAction(
        adminId: UUID,
        action: AdminAction,
        resourceType: AdminResourceType,
        resourceId: String?,
        metadata: [String: String]?,
        success: Bool,
        errorMessage: String?,
    ) async throws {
        struct AuditLogDTO: Encodable {
            let admin_id: String
            let action: String
            let resource_type: String
            let success: Bool
            let resource_id: String?
            let metadata: [String: String]?
            let error_message: String?
        }

        let logData = AuditLogDTO(
            admin_id: adminId.uuidString,
            action: action.rawValue,
            resource_type: resourceType.rawValue,
            success: success,
            resource_id: resourceId,
            metadata: metadata,
            error_message: errorMessage,
        )

        try await supabase
            .from("admin_audit_log")
            .insert(logData)
            .execute()
    }

    // MARK: - Authorization

    func hasAdminAccess(userId: UUID) async throws -> Bool {
        let response: [UserRole] = try await supabase
            .from("user_roles")
            .select("*, role:roles(*)")
            .eq("profile_id", value: userId)
            .execute()
            .value

        return response.contains { $0.role?.isAdmin == true }
    }

    func hasSuperAdminAccess(userId: UUID) async throws -> Bool {
        let response: [UserRole] = try await supabase
            .from("user_roles")
            .select("*, role:roles(*)")
            .eq("profile_id", value: userId)
            .execute()
            .value

        return response.contains { $0.role?.isSuperAdmin == true }
    }
}

// MARK: - DTOs

/// DTO for decoding the get_moderation_stats RPC response
private struct ModerationStatsDTO: Decodable {
    let pendingCount: Int
    let highPriorityCount: Int
    let resolvedToday: Int
    let totalReports: Int

    enum CodingKeys: String, CodingKey {
        case pendingCount = "pending_count"
        case highPriorityCount = "high_priority_count"
        case resolvedToday = "resolved_today"
        case totalReports = "total_reports"
    }
}

/// Parameters for the get_admin_users RPC
private struct AdminUsersParams: Encodable {
    let pSearchQuery: String?
    let pRoleFilter: String?
    let pLimit: Int
    let pOffset: Int

    enum CodingKeys: String, CodingKey {
        case pSearchQuery = "p_search_query"
        case pRoleFilter = "p_role_filter"
        case pLimit = "p_limit"
        case pOffset = "p_offset"
    }
}

/// DTO for decoding the get_dashboard_stats RPC response
private struct DashboardStatsDTO: Decodable {
    let totalUsers: Int
    let activeUsers: Int
    let totalPosts: Int
    let activePosts: Int
    let pendingReports: Int
    let totalMessages: Int
    let newUsersToday: Int
    let newPostsToday: Int

    enum CodingKeys: String, CodingKey {
        case totalUsers = "total_users"
        case activeUsers = "active_users"
        case totalPosts = "total_posts"
        case activePosts = "active_posts"
        case pendingReports = "pending_reports"
        case totalMessages = "total_messages"
        case newUsersToday = "new_users_today"
        case newPostsToday = "new_posts_today"
    }
}
