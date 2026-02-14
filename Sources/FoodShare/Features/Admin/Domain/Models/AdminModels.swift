import Foundation
import SwiftUI

// MARK: - User Role

/// Represents a role from the `roles` table
struct Role: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let description: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case createdAt = "created_at"
    }

    var isAdmin: Bool {
        name == "admin" || name == "super_admin"
    }

    var isSuperAdmin: Bool {
        name == "super_admin"
    }
}

// MARK: - User Role Assignment

/// Represents a user-role assignment from `user_roles` table
struct UserRole: Codable, Identifiable, Hashable, Sendable {
    var id: String { "\(profileId)-\(roleId)" }
    let profileId: UUID
    let roleId: Int
    let grantedAt: Date?
    let grantedBy: UUID?

    // Joined data
    var role: Role?
    var profile: AdminUserProfile?

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case roleId = "role_id"
        case grantedAt = "granted_at"
        case grantedBy = "granted_by"
        case role
        case profile
    }
}

// MARK: - Admin User Profile

/// Lightweight profile for admin views
struct AdminUserProfile: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let nickname: String
    let email: String?
    let avatarUrl: String?
    let isVerified: Bool?
    let isActive: Bool?
    let createdTime: Date?
    let lastSeenAt: Date?

    /// Joined user roles from user_roles table
    let userRoles: [UserRoleInfo]?

    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case email
        case avatarUrl = "avatar_url"
        case isVerified = "is_verified"
        case isActive = "is_active"
        case createdTime = "created_time"
        case lastSeenAt = "last_seen_at"
        case userRoles = "user_roles"
    }

    var displayName: String {
        nickname.isEmpty ? "Anonymous" : nickname
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        nickname.isEmpty ? t.t("common.anonymous") : nickname
    }

    var avatarURL: URL? {
        guard let urlString = avatarUrl else { return nil }
        return URL(string: urlString)
    }

    /// Primary role name (first assigned role)
    var primaryRole: String? {
        userRoles?.first?.role?.name
    }

    /// Check if user has admin role
    var isAdmin: Bool {
        userRoles?.contains { $0.role?.name == "admin" || $0.role?.name == "super_admin" } ?? false
    }

    /// Check if user has super admin role
    var isSuperAdmin: Bool {
        userRoles?.contains { $0.role?.name == "super_admin" } ?? false
    }

    /// All role names as comma-separated string
    var roleNames: String {
        guard let roles = userRoles, !roles.isEmpty else { return "Member" }
        return roles.compactMap { $0.role?.name.capitalized }.joined(separator: ", ")
    }
}

// MARK: - User Role Info (for joined queries)

/// Lightweight role info for profile queries
struct UserRoleInfo: Codable, Hashable, Sendable {
    let roleId: Int
    let role: RoleInfo?

    enum CodingKeys: String, CodingKey {
        case roleId = "role_id"
        case role
    }

    struct RoleInfo: Codable, Hashable, Sendable {
        let id: Int
        let name: String
    }
}

// MARK: - Admin Audit Log

/// Represents an audit log entry from `admin_audit_log` table
struct AdminAuditLog: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let adminId: UUID
    let action: String
    let resourceType: String
    let resourceId: String?
    let metadata: [String: String]?
    let ipAddress: String?
    let userAgent: String?
    let success: Bool
    let errorMessage: String?
    let createdAt: Date

    // Joined data
    var admin: AdminUserProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case adminId = "admin_id"
        case action
        case resourceType = "resource_type"
        case resourceId = "resource_id"
        case metadata
        case ipAddress = "ip_address"
        case userAgent = "user_agent"
        case success
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case admin
    }
}

// MARK: - Admin Action Types

enum AdminAction: String, CaseIterable, Sendable {
    case viewUser = "view_user"
    case editUser = "edit_user"
    case banUser = "ban_user"
    case unbanUser = "unban_user"
    case deletePost = "delete_post"
    case restorePost = "restore_post"
    case deleteComment = "delete_comment"
    case assignRole = "assign_role"
    case revokeRole = "revoke_role"
    case viewAuditLog = "view_audit_log"
    case exportData = "export_data"

    var displayName: String {
        switch self {
        case .viewUser: "View User"
        case .editUser: "Edit User"
        case .banUser: "Ban User"
        case .unbanUser: "Unban User"
        case .deletePost: "Delete Post"
        case .restorePost: "Restore Post"
        case .deleteComment: "Delete Comment"
        case .assignRole: "Assign Role"
        case .revokeRole: "Revoke Role"
        case .viewAuditLog: "View Audit Log"
        case .exportData: "Export Data"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .viewUser: t.t("admin.actions.view_user")
        case .editUser: t.t("admin.actions.edit_user")
        case .banUser: t.t("admin.actions.ban_user")
        case .unbanUser: t.t("admin.actions.unban_user")
        case .deletePost: t.t("admin.actions.delete_post")
        case .restorePost: t.t("admin.actions.restore_post")
        case .deleteComment: t.t("admin.actions.delete_comment")
        case .assignRole: t.t("admin.actions.assign_role")
        case .revokeRole: t.t("admin.actions.revoke_role")
        case .viewAuditLog: t.t("admin.actions.view_audit_log")
        case .exportData: t.t("admin.actions.export_data")
        }
    }

    var iconName: String {
        switch self {
        case .viewUser: "person.circle"
        case .editUser: "pencil.circle"
        case .banUser: "person.crop.circle.badge.xmark"
        case .unbanUser: "person.crop.circle.badge.checkmark"
        case .deletePost: "trash"
        case .restorePost: "arrow.uturn.backward"
        case .deleteComment: "bubble.left.and.exclamationmark.bubble.right"
        case .assignRole: "person.badge.plus"
        case .revokeRole: "person.badge.minus"
        case .viewAuditLog: "list.bullet.clipboard"
        case .exportData: "square.and.arrow.up"
        }
    }
}

// MARK: - Resource Types

enum AdminResourceType: String, CaseIterable, Sendable {
    case user
    case post
    case comment
    case role
    case report
    case system

    var displayName: String {
        rawValue.capitalized
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .user: t.t("admin.resource.user")
        case .post: t.t("admin.resource.post")
        case .comment: t.t("admin.resource.comment")
        case .role: t.t("admin.resource.role")
        case .report: t.t("admin.resource.report")
        case .system: t.t("admin.resource.system")
        }
    }
}

// MARK: - Moderation Queue Item

struct ModerationQueueItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let forumId: Int?
    let commentId: Int?
    let profileId: UUID?
    let queueType: String
    let contentType: String
    let priority: Int
    let status: String
    let flagReason: String?
    let flagScore: Double?
    let createdAt: Date

    // Joined data
    var reporter: AdminUserProfile?
    var targetUser: AdminUserProfile?

    enum CodingKeys: String, CodingKey {
        case id
        case forumId = "forum_id"
        case commentId = "comment_id"
        case profileId = "profile_id"
        case queueType = "queue_type"
        case contentType = "content_type"
        case priority
        case status
        case flagReason = "flag_reason"
        case flagScore = "flag_score"
        case createdAt = "created_at"
        case reporter
        case targetUser = "target_user"
    }

    var isPending: Bool {
        status == "pending"
    }

    var isHighPriority: Bool {
        priority >= 5
    }
}

// MARK: - Admin Dashboard Stats

struct AdminDashboardStats: Sendable {
    let totalUsers: Int
    let activeUsers: Int
    let totalPosts: Int
    let activePosts: Int
    let pendingReports: Int
    let totalMessages: Int
    let newUsersToday: Int
    let newPostsToday: Int

    static let empty = AdminDashboardStats(
        totalUsers: 0,
        activeUsers: 0,
        totalPosts: 0,
        activePosts: 0,
        pendingReports: 0,
        totalMessages: 0,
        newUsersToday: 0,
        newPostsToday: 0,
    )
}
