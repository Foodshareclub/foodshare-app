import Foundation

// MARK: - Moderation Stats Result

struct ModerationStatsResult: Sendable {
    let pendingCount: Int
    let highPriorityCount: Int
    let resolvedToday: Int
    let totalReports: Int

    static let empty = ModerationStatsResult(
        pendingCount: 0,
        highPriorityCount: 0,
        resolvedToday: 0,
        totalReports: 0,
    )
}

// MARK: - Admin Repository Protocol

/// Repository protocol for admin operations
protocol AdminRepository: Sendable {
    // MARK: - Dashboard

    /// Fetch dashboard statistics
    func fetchDashboardStats() async throws -> AdminDashboardStats

    /// Fetch moderation stats (server-side counts)
    func fetchModerationStats() async throws -> ModerationStatsResult

    // MARK: - Users

    /// Fetch users with pagination
    func fetchUsers(
        searchQuery: String?,
        roleFilter: String?,
        limit: Int,
        offset: Int,
    ) async throws -> [AdminUserProfile]

    /// Fetch a single user by ID
    func fetchUser(id: UUID) async throws -> AdminUserProfile

    /// Update user status (active/inactive)
    func updateUserStatus(userId: UUID, isActive: Bool) async throws

    /// Ban a user
    func banUser(userId: UUID, reason: String) async throws

    /// Unban a user
    func unbanUser(userId: UUID) async throws

    // MARK: - Roles

    /// Fetch all available roles
    func fetchRoles() async throws -> [Role]

    /// Fetch user's roles
    func fetchUserRoles(userId: UUID) async throws -> [UserRole]

    /// Assign a role to a user
    func assignRole(userId: UUID, roleId: Int, grantedBy: UUID) async throws

    /// Revoke a role from a user
    func revokeRole(userId: UUID, roleId: Int) async throws

    // MARK: - Moderation

    /// Fetch moderation queue
    func fetchModerationQueue(
        status: String?,
        contentType: String?,
        limit: Int,
        offset: Int,
    ) async throws -> [ModerationQueueItem]

    /// Resolve a moderation item
    func resolveModerationItem(
        itemId: UUID,
        resolution: String,
        notes: String?,
        resolvedBy: UUID,
    ) async throws

    // MARK: - Content Management

    /// Delete a post
    func deletePost(postId: Int, reason: String) async throws

    /// Restore a deleted post
    func restorePost(postId: Int) async throws

    /// Delete a comment
    func deleteComment(commentId: Int, reason: String) async throws

    // MARK: - Audit Log

    /// Fetch audit logs
    func fetchAuditLogs(
        adminId: UUID?,
        action: String?,
        resourceType: String?,
        limit: Int,
        offset: Int,
    ) async throws -> [AdminAuditLog]

    /// Log an admin action
    func logAction(
        adminId: UUID,
        action: AdminAction,
        resourceType: AdminResourceType,
        resourceId: String?,
        metadata: [String: String]?,
        success: Bool,
        errorMessage: String?,
    ) async throws

    // MARK: - Authorization

    /// Check if user has admin access
    func hasAdminAccess(userId: UUID) async throws -> Bool

    /// Check if user has super admin access
    func hasSuperAdminAccess(userId: UUID) async throws -> Bool
}

// MARK: - Admin Filters

struct AdminUserFilters: Equatable, Sendable {
    var searchQuery = ""
    var roleFilter: String?
    var statusFilter: UserStatusFilter = .all
    var sortBy: AdminUserSortOption = .newest

    var hasActiveFilters: Bool {
        !searchQuery.isEmpty || roleFilter != nil || statusFilter != .all
    }

    mutating func reset() {
        searchQuery = ""
        roleFilter = nil
        statusFilter = .all
        sortBy = .newest
    }
}

enum UserStatusFilter: String, CaseIterable, Sendable {
    case all
    case active
    case inactive
    case banned

    var displayName: String {
        rawValue.capitalized
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .all: t.t("admin.user_status.all")
        case .active: t.t("admin.user_status.active")
        case .inactive: t.t("admin.user_status.inactive")
        case .banned: t.t("admin.user_status.banned")
        }
    }
}

enum AdminUserSortOption: String, CaseIterable, Sendable {
    case newest
    case oldest
    case alphabetical
    case lastActive = "last_active"

    var displayName: String {
        switch self {
        case .newest: "Newest First"
        case .oldest: "Oldest First"
        case .alphabetical: "A-Z"
        case .lastActive: "Last Active"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .newest: t.t("admin.sort.newest")
        case .oldest: t.t("admin.sort.oldest")
        case .alphabetical: t.t("admin.sort.alphabetical")
        case .lastActive: t.t("admin.sort.last_active")
        }
    }
}

// MARK: - Moderation Filters

struct ModerationFilters: Equatable, Sendable {
    var status: ModerationStatus = .pending
    var contentType: ModerationContentType?
    var priority: ModerationPriority?

    var hasActiveFilters: Bool {
        status != .pending || contentType != nil || priority != nil
    }
}

enum ModerationStatus: String, CaseIterable, Sendable {
    case pending
    case inReview = "in_review"
    case resolved
    case escalated
    case dismissed

    var displayName: String {
        switch self {
        case .pending: "Pending"
        case .inReview: "In Review"
        case .resolved: "Resolved"
        case .escalated: "Escalated"
        case .dismissed: "Dismissed"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .pending: t.t("admin.moderation_status.pending")
        case .inReview: t.t("admin.moderation_status.in_review")
        case .resolved: t.t("admin.moderation_status.resolved")
        case .escalated: t.t("admin.moderation_status.escalated")
        case .dismissed: t.t("admin.moderation_status.dismissed")
        }
    }
}

enum ModerationContentType: String, CaseIterable, Sendable {
    case post
    case comment
    case message
    case profile

    var displayName: String {
        rawValue.capitalized
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .post: t.t("admin.resource.post")
        case .comment: t.t("admin.resource.comment")
        case .message: t.t("common.message")
        case .profile: t.t("tabs.profile")
        }
    }

    /// Get localized name from raw string value
    @MainActor
    static func localizedName(for rawValue: String, using t: EnhancedTranslationService) -> String {
        if let contentType = ModerationContentType(rawValue: rawValue) {
            return contentType.localizedDisplayName(using: t)
        }
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

enum ModerationPriority: Int, CaseIterable, Sendable {
    case low = 1
    case medium = 3
    case high = 5
    case critical = 10

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .critical: "Critical"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .low: t.t("admin.moderation_priority.low")
        case .medium: t.t("admin.moderation_priority.medium")
        case .high: t.t("admin.moderation_priority.high")
        case .critical: t.t("admin.moderation_priority.critical")
        }
    }
}

enum ModerationResolution: String, CaseIterable, Sendable {
    case approved
    case removed
    case edited
    case warningIssued = "warning_issued"
    case userBanned = "user_banned"
    case noAction = "no_action"
    case escalated

    var displayName: String {
        switch self {
        case .approved: "Approve"
        case .removed: "Remove Content"
        case .edited: "Edit Content"
        case .warningIssued: "Issue Warning"
        case .userBanned: "Ban User"
        case .noAction: "No Action Needed"
        case .escalated: "Escalate"
        }
    }

    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .approved: t.t("admin.moderation_resolution.approved")
        case .removed: t.t("admin.moderation_resolution.removed")
        case .edited: t.t("admin.moderation_resolution.edited")
        case .warningIssued: t.t("admin.moderation_resolution.warning_issued")
        case .userBanned: t.t("admin.moderation_resolution.user_banned")
        case .noAction: t.t("admin.moderation_resolution.no_action")
        case .escalated: t.t("admin.moderation_resolution.escalated")
        }
    }
}

// MARK: - Localization Helpers

/// Helper for localizing moderation status strings
enum ModerationStatusHelper {
    @MainActor
    static func localizedName(for rawValue: String, using t: EnhancedTranslationService) -> String {
        switch rawValue {
        case "pending": t.t("admin.moderation_status.pending")
        case "in_review": t.t("admin.moderation_status.in_review")
        case "resolved": t.t("admin.moderation_status.resolved")
        case "escalated": t.t("admin.moderation_status.escalated")
        case "dismissed": t.t("admin.moderation_status.dismissed")
        default: rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

/// Helper for localizing queue type strings
enum QueueTypeHelper {
    @MainActor
    static func localizedName(for rawValue: String, using t: EnhancedTranslationService) -> String {
        switch rawValue {
        case "user_report": t.t("admin.queue_type.user_report")
        case "auto_flag": t.t("admin.queue_type.auto_flag")
        case "content_review": t.t("admin.queue_type.content_review")
        case "spam_detection": t.t("admin.queue_type.spam_detection")
        default: rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

/// Helper for localizing admin action strings
enum AdminActionHelper {
    @MainActor
    static func localizedName(for rawValue: String, using t: EnhancedTranslationService) -> String {
        switch rawValue {
        case "ban_user": t.t("admin.actions.ban_user")
        case "unban_user": t.t("admin.actions.unban_user")
        case "delete_post": t.t("admin.actions.delete_post")
        case "restore_post": t.t("admin.actions.restore_post")
        case "delete_comment": t.t("admin.actions.delete_comment")
        case "assign_role": t.t("admin.actions.assign_role")
        case "revoke_role": t.t("admin.actions.revoke_role")
        case "edit_user": t.t("admin.actions.edit_user")
        case "view_user": t.t("admin.actions.view_user")
        case "view_audit_log": t.t("admin.actions.view_audit_log")
        case "export_data": t.t("admin.actions.export_data")
        default: rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }
}

/// Helper for localizing resource type strings
enum ResourceTypeHelper {
    @MainActor
    static func localizedName(for rawValue: String, using t: EnhancedTranslationService) -> String {
        switch rawValue {
        case "user": t.t("admin.resource.user")
        case "post": t.t("admin.resource.post")
        case "comment": t.t("admin.resource.comment")
        case "report": t.t("admin.resource.report")
        case "role": t.t("admin.resource.role")
        case "system": t.t("admin.resource.system")
        default: rawValue.capitalized
        }
    }
}
