//
//  MockAdminRepository.swift
//  Foodshare
//
//  Mock admin repository for testing and previews
//

import Foundation

#if DEBUG
    final class MockAdminRepository: AdminRepository, @unchecked Sendable {
        nonisolated(unsafe) var mockUsers: [AdminUserProfile] = []
        nonisolated(unsafe) var mockRoles: [Role] = []
        nonisolated(unsafe) var mockModerationQueue: [ModerationQueueItem] = []
        nonisolated(unsafe) var mockAuditLogs: [AdminAuditLog] = []
        nonisolated(unsafe) var mockStats = AdminDashboardStats.empty
        nonisolated(unsafe) var bannedUsers: Set<UUID> = []
        nonisolated(unsafe) var userRoles: [UUID: [Int]] = [:]
        nonisolated(unsafe) var shouldFail = false

        init() {
            // Initialize with sample data
            mockRoles = [
                Role.fixture(id: 1, name: "member"),
                Role.fixture(id: 2, name: "admin"),
                Role.fixture(id: 3, name: "super_admin")
            ]

            mockUsers = [
                AdminUserProfile.fixture(nickname: "FoodHero"),
                AdminUserProfile.fixture(nickname: "EcoSaver"),
                AdminUserProfile.fixture(nickname: "ShareMaster")
            ]

            mockStats = AdminDashboardStats(
                totalUsers: 150,
                activeUsers: 120,
                totalPosts: 450,
                activePosts: 380,
                pendingReports: 5,
                totalMessages: 1200,
                newUsersToday: 8,
                newPostsToday: 25,
            )
        }

        // MARK: - Dashboard

        func fetchDashboardStats() async throws -> AdminDashboardStats {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 200_000_000)
            return mockStats
        }

        func fetchModerationStats() async throws -> ModerationStatsResult {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 200_000_000)

            // Calculate stats from mock moderation queue
            let pendingCount = mockModerationQueue.count(where: { $0.status == "pending" })
            let highPriorityCount = mockModerationQueue.count(where: { $0.priority >= 5 })

            return ModerationStatsResult(
                pendingCount: pendingCount,
                highPriorityCount: highPriorityCount,
                resolvedToday: 3,
                totalReports: mockModerationQueue.count,
            )
        }

        // MARK: - Users

        func fetchUsers(
            searchQuery: String?,
            roleFilter: String?,
            limit: Int,
            offset: Int,
        ) async throws -> [AdminUserProfile] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 300_000_000)

            var users = mockUsers

            if let query = searchQuery, !query.isEmpty {
                users = users.filter {
                    $0.nickname.localizedCaseInsensitiveContains(query) ||
                        ($0.email?.localizedCaseInsensitiveContains(query) ?? false)
                }
            }

            let startIndex = min(offset, users.count)
            let endIndex = min(offset + limit, users.count)
            return Array(users[startIndex ..< endIndex])
        }

        func fetchUser(id: UUID) async throws -> AdminUserProfile {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            guard let user = mockUsers.first(where: { $0.id == id }) else {
                throw AppError.notFound(resource: "User")
            }
            return user
        }

        func updateUserStatus(userId: UUID, isActive: Bool) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
        }

        func banUser(userId: UUID, reason: String) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            bannedUsers.insert(userId)
        }

        func unbanUser(userId: UUID) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            bannedUsers.remove(userId)
        }

        // MARK: - Roles

        func fetchRoles() async throws -> [Role] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            return mockRoles
        }

        func fetchUserRoles(userId: UUID) async throws -> [UserRole] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            let roleIds = userRoles[userId] ?? [1] // Default to member role
            return roleIds.map { roleId in
                UserRole(
                    profileId: userId,
                    roleId: roleId,
                    grantedAt: Date(),
                    grantedBy: nil,
                    role: mockRoles.first { $0.id == roleId },
                )
            }
        }

        func assignRole(userId: UUID, roleId: Int, grantedBy: UUID) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            var roles = userRoles[userId] ?? []
            if !roles.contains(roleId) {
                roles.append(roleId)
                userRoles[userId] = roles
            }
        }

        func revokeRole(userId: UUID, roleId: Int) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            userRoles[userId]?.removeAll { $0 == roleId }
        }

        // MARK: - Moderation

        func fetchModerationQueue(
            status: String?,
            contentType: String?,
            limit: Int,
            offset: Int,
        ) async throws -> [ModerationQueueItem] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 200_000_000)

            var items = mockModerationQueue

            if let status {
                items = items.filter { $0.status == status }
            }
            if let contentType {
                items = items.filter { $0.contentType == contentType }
            }

            let startIndex = min(offset, items.count)
            let endIndex = min(offset + limit, items.count)
            return Array(items[startIndex ..< endIndex])
        }

        func resolveModerationItem(
            itemId: UUID,
            resolution: String,
            notes: String?,
            resolvedBy: UUID,
        ) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            mockModerationQueue.removeAll { $0.id == itemId }
        }

        // MARK: - Content Management

        func deletePost(postId: Int, reason: String) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
        }

        func restorePost(postId: Int) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
        }

        func deleteComment(commentId: Int, reason: String) async throws {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
        }

        // MARK: - Audit Log

        func fetchAuditLogs(
            adminId: UUID?,
            action: String?,
            resourceType: String?,
            limit: Int,
            offset: Int,
        ) async throws -> [AdminAuditLog] {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            try await Task.sleep(nanoseconds: 200_000_000)

            var logs = mockAuditLogs

            if let adminId {
                logs = logs.filter { $0.adminId == adminId }
            }
            if let action {
                logs = logs.filter { $0.action == action }
            }
            if let resourceType {
                logs = logs.filter { $0.resourceType == resourceType }
            }

            let startIndex = min(offset, logs.count)
            let endIndex = min(offset + limit, logs.count)
            return Array(logs[startIndex ..< endIndex])
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
            if shouldFail {
                throw AppError.networkError("Mock error")
            }

            let log = AdminAuditLog(
                id: UUID(),
                adminId: adminId,
                action: action.rawValue,
                resourceType: resourceType.rawValue,
                resourceId: resourceId,
                metadata: metadata,
                ipAddress: nil,
                userAgent: nil,
                success: success,
                errorMessage: errorMessage,
                createdAt: Date(),
            )
            mockAuditLogs.insert(log, at: 0)
        }

        // MARK: - Authorization

        func hasAdminAccess(userId: UUID) async throws -> Bool {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            let roles = userRoles[userId] ?? []
            return roles.contains(2) || roles.contains(3) // admin or super_admin
        }

        func hasSuperAdminAccess(userId: UUID) async throws -> Bool {
            if shouldFail {
                throw AppError.networkError("Mock error")
            }
            let roles = userRoles[userId] ?? []
            return roles.contains(3) // super_admin
        }
    }

    // MARK: - Test Fixtures

    extension Role {
        static func fixture(
            id: Int = 1,
            name: String = "member",
            description: String? = nil,
            createdAt: Date? = Date(),
        ) -> Role {
            Role(
                id: id,
                name: name,
                description: description,
                createdAt: createdAt,
            )
        }
    }

    extension AdminUserProfile {
        static func fixture(
            id: UUID = UUID(),
            nickname: String = "TestUser",
            email: String? = "test@example.com",
            avatarUrl: String? = nil,
            isVerified: Bool? = true,
            isActive: Bool? = true,
            createdTime: Date? = Date(),
            lastSeenAt: Date? = Date(),
            userRoles: [UserRoleInfo]? = nil,
        ) -> AdminUserProfile {
            AdminUserProfile(
                id: id,
                nickname: nickname,
                email: email,
                avatarUrl: avatarUrl,
                isVerified: isVerified,
                isActive: isActive,
                createdTime: createdTime,
                lastSeenAt: lastSeenAt,
                userRoles: userRoles,
            )
        }
    }

    extension ModerationQueueItem {
        static func fixture(
            id: UUID = UUID(),
            forumId: Int? = nil,
            commentId: Int? = nil,
            profileId: UUID? = UUID(),
            queueType: String = "report",
            contentType: String = "post",
            priority: Int = 5,
            status: String = "pending",
            flagReason: String? = "Inappropriate content",
            flagScore: Double? = 0.8,
            createdAt: Date = Date(),
        ) -> ModerationQueueItem {
            ModerationQueueItem(
                id: id,
                forumId: forumId,
                commentId: commentId,
                profileId: profileId,
                queueType: queueType,
                contentType: contentType,
                priority: priority,
                status: status,
                flagReason: flagReason,
                flagScore: flagScore,
                createdAt: createdAt,
            )
        }
    }

    extension AdminAuditLog {
        static func fixture(
            id: UUID = UUID(),
            adminId: UUID = UUID(),
            action: String = "view_user",
            resourceType: String = "user",
            resourceId: String? = nil,
            metadata: [String: String]? = nil,
            ipAddress: String? = nil,
            userAgent: String? = nil,
            success: Bool = true,
            errorMessage: String? = nil,
            createdAt: Date = Date(),
        ) -> AdminAuditLog {
            AdminAuditLog(
                id: id,
                adminId: adminId,
                action: action,
                resourceType: resourceType,
                resourceId: resourceId,
                metadata: metadata,
                ipAddress: ipAddress,
                userAgent: userAgent,
                success: success,
                errorMessage: errorMessage,
                createdAt: createdAt,
            )
        }
    }
#endif
