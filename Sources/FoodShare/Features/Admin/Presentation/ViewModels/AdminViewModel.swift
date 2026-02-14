import Foundation
import SwiftUI

// MARK: - Admin ViewModel

@MainActor
@Observable
final class AdminViewModel {
    // MARK: - Properties

    // Dashboard
    var stats = AdminDashboardStats.empty
    var isLoadingStats = false

    // Users
    var users: [AdminUserProfile] = []
    var selectedUser: AdminUserProfile?
    var userFilters = AdminUserFilters()
    var isLoadingUsers = false
    var isLoadingMoreUsers = false

    // Roles
    var roles: [Role] = []
    var userRoles: [UserRole] = []

    // Moderation
    var moderationQueue: [ModerationQueueItem] = []
    var moderationFilters = ModerationFilters()
    var isLoadingModeration = false

    // Audit Log
    var auditLogs: [AdminAuditLog] = []
    var isLoadingAuditLogs = false

    // General
    var error: AppError?
    var showError = false
    var successMessage: String?
    var showSuccess = false

    // Authorization
    var hasAdminAccess = false
    var hasSuperAdminAccess = false

    private var usersOffset = 0
    private var moderationOffset = 0
    private var auditLogsOffset = 0
    private var pageSize: Int { AppConfiguration.shared.pageSize }

    private let repository: AdminRepository
    private let currentUserId: UUID

    // MARK: - Computed Properties

    var pendingModerationCount: Int {
        moderationQueue.count(where: { $0.isPending })
    }

    var highPriorityCount: Int {
        moderationQueue.count(where: { $0.isHighPriority && $0.isPending })
    }

    // MARK: - Initialization

    init(repository: AdminRepository, currentUserId: UUID) {
        self.repository = repository
        self.currentUserId = currentUserId
    }

    // MARK: - Authorization

    func checkAccess() async {
        do {
            hasAdminAccess = try await repository.hasAdminAccess(userId: currentUserId)
            hasSuperAdminAccess = try await repository.hasSuperAdminAccess(userId: currentUserId)
        } catch {
            hasAdminAccess = false
            hasSuperAdminAccess = false
        }
    }

    // MARK: - Dashboard

    func loadDashboardStats() async {
        guard !isLoadingStats else { return }

        isLoadingStats = true
        defer { isLoadingStats = false }

        do {
            stats = try await repository.fetchDashboardStats()
        } catch let appError as AppError {
            error = appError
            showError = true
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Users

    func loadUsers() async {
        guard !isLoadingUsers else { return }

        isLoadingUsers = true
        usersOffset = 0
        defer { isLoadingUsers = false }

        do {
            users = try await repository.fetchUsers(
                searchQuery: userFilters.searchQuery.isEmpty ? nil : userFilters.searchQuery,
                roleFilter: userFilters.roleFilter,
                limit: pageSize,
                offset: 0,
            )

            // Log action
            try await repository.logAction(
                adminId: currentUserId,
                action: .viewUser,
                resourceType: .user,
                resourceId: nil,
                metadata: ["filter": userFilters.searchQuery],
                success: true,
                errorMessage: nil,
            )
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func loadMoreUsers() async {
        guard !isLoadingMoreUsers else { return }

        isLoadingMoreUsers = true
        defer { isLoadingMoreUsers = false }

        do {
            let newOffset = usersOffset + pageSize
            let newUsers = try await repository.fetchUsers(
                searchQuery: userFilters.searchQuery.isEmpty ? nil : userFilters.searchQuery,
                roleFilter: userFilters.roleFilter,
                limit: pageSize,
                offset: newOffset,
            )

            users.append(contentsOf: newUsers)
            usersOffset = newOffset
        } catch {
            // Silently fail for pagination
        }
    }

    func searchUsers(query: String) async {
        userFilters.searchQuery = query
        await loadUsers()
    }

    func selectUser(_ user: AdminUserProfile) async {
        selectedUser = user
        await loadUserRoles(userId: user.id)
    }

    func loadUserRoles(userId: UUID) async {
        do {
            userRoles = try await repository.fetchUserRoles(userId: userId)
        } catch {
            userRoles = []
        }
    }

    func banUser(_ user: AdminUserProfile, reason: String) async {
        do {
            try await repository.banUser(userId: user.id, reason: reason)

            // Log action
            try await repository.logAction(
                adminId: currentUserId,
                action: .banUser,
                resourceType: .user,
                resourceId: user.id.uuidString,
                metadata: ["reason": reason],
                success: true,
                errorMessage: nil,
            )

            successMessage = "User banned successfully"
            showSuccess = true

            // Refresh users
            await loadUsers()
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func unbanUser(_ user: AdminUserProfile) async {
        do {
            try await repository.unbanUser(userId: user.id)

            // Log action
            try await repository.logAction(
                adminId: currentUserId,
                action: .unbanUser,
                resourceType: .user,
                resourceId: user.id.uuidString,
                metadata: nil,
                success: true,
                errorMessage: nil,
            )

            successMessage = "User unbanned successfully"
            showSuccess = true

            await loadUsers()
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Roles

    func loadRoles() async {
        do {
            roles = try await repository.fetchRoles()
        } catch {
            roles = []
        }
    }

    func assignRole(to user: AdminUserProfile, roleId: Int) async {
        do {
            try await repository.assignRole(userId: user.id, roleId: roleId, grantedBy: currentUserId)

            // Log action
            try await repository.logAction(
                adminId: currentUserId,
                action: .assignRole,
                resourceType: .role,
                resourceId: "\(roleId)",
                metadata: ["user_id": user.id.uuidString],
                success: true,
                errorMessage: nil,
            )

            successMessage = "Role assigned successfully"
            showSuccess = true

            await loadUserRoles(userId: user.id)
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func revokeRole(from user: AdminUserProfile, roleId: Int) async {
        do {
            try await repository.revokeRole(userId: user.id, roleId: roleId)

            // Log action
            try await repository.logAction(
                adminId: currentUserId,
                action: .revokeRole,
                resourceType: .role,
                resourceId: "\(roleId)",
                metadata: ["user_id": user.id.uuidString],
                success: true,
                errorMessage: nil,
            )

            successMessage = "Role revoked successfully"
            showSuccess = true

            await loadUserRoles(userId: user.id)
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Moderation

    func loadModerationQueue() async {
        guard !isLoadingModeration else { return }

        isLoadingModeration = true
        moderationOffset = 0
        defer { isLoadingModeration = false }

        do {
            moderationQueue = try await repository.fetchModerationQueue(
                status: moderationFilters.status.rawValue,
                contentType: moderationFilters.contentType?.rawValue,
                limit: pageSize,
                offset: 0,
            )
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func resolveModerationItem(_ item: ModerationQueueItem, resolution: ModerationResolution, notes: String?) async {
        do {
            try await repository.resolveModerationItem(
                itemId: item.id,
                resolution: resolution.rawValue,
                notes: notes,
                resolvedBy: currentUserId,
            )

            successMessage = "Item resolved successfully"
            showSuccess = true

            await loadModerationQueue()
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Content Management

    func deletePost(postId: Int, reason: String) async {
        do {
            try await repository.deletePost(postId: postId, reason: reason)

            // Log action
            try await repository.logAction(
                adminId: currentUserId,
                action: .deletePost,
                resourceType: .post,
                resourceId: "\(postId)",
                metadata: ["reason": reason],
                success: true,
                errorMessage: nil,
            )

            successMessage = "Post deleted successfully"
            showSuccess = true
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    func restorePost(postId: Int) async {
        do {
            try await repository.restorePost(postId: postId)

            // Log action
            try await repository.logAction(
                adminId: currentUserId,
                action: .restorePost,
                resourceType: .post,
                resourceId: "\(postId)",
                metadata: nil,
                success: true,
                errorMessage: nil,
            )

            successMessage = "Post restored successfully"
            showSuccess = true
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Audit Log

    func loadAuditLogs() async {
        guard !isLoadingAuditLogs else { return }

        isLoadingAuditLogs = true
        auditLogsOffset = 0
        defer { isLoadingAuditLogs = false }

        do {
            auditLogs = try await repository.fetchAuditLogs(
                adminId: nil,
                action: nil,
                resourceType: nil,
                limit: pageSize,
                offset: 0,
            )

            // Log the view action
            try await repository.logAction(
                adminId: currentUserId,
                action: .viewAuditLog,
                resourceType: .system,
                resourceId: nil,
                metadata: nil,
                success: true,
                errorMessage: nil,
            )
        } catch {
            self.error = .networkError(error.localizedDescription)
            showError = true
        }
    }

    // MARK: - Helpers

    func dismissError() {
        showError = false
        error = nil
    }

    func dismissSuccess() {
        showSuccess = false
        successMessage = nil
    }
}
