package com.foodshare.features.admin.data

import com.foodshare.features.admin.domain.model.AdminAuditLog
import com.foodshare.features.admin.domain.model.AdminDashboardStats
import com.foodshare.features.admin.domain.model.AdminUserProfile
import com.foodshare.features.admin.domain.model.ModerationQueueItem
import com.foodshare.features.admin.domain.model.ModerationResolution
import com.foodshare.features.admin.domain.model.Role
import com.foodshare.features.admin.domain.repository.AdminRepository
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import io.github.jan.supabase.postgrest.rpc
import kotlinx.serialization.SerialName
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SupabaseAdminRepository @Inject constructor(
    private val supabaseClient: SupabaseClient
) : AdminRepository {

    // Dashboard

    override suspend fun fetchDashboardStats(): Result<AdminDashboardStats> = runCatching {
        supabaseClient.postgrest.rpc("get_dashboard_stats")
            .decodeSingle<AdminDashboardStats>()
    }

    // Users

    override suspend fun fetchUsers(
        query: String,
        role: String?,
        limit: Int,
        offset: Int
    ): Result<List<AdminUserProfile>> = runCatching {
        supabaseClient.from("profiles")
            .select {
                filter {
                    if (query.isNotBlank()) {
                        or {
                            ilike("display_name", "%$query%")
                            ilike("email", "%$query%")
                        }
                    }
                }
                limit(limit.toLong())
                range(offset.toLong(), (offset + limit - 1).toLong())
                order("created_at", io.github.jan.supabase.postgrest.query.Order.DESCENDING)
            }
            .decodeList<AdminUserProfile>()
    }

    override suspend fun fetchUser(id: String): Result<AdminUserProfile> = runCatching {
        supabaseClient.from("profiles")
            .select {
                filter { eq("id", id) }
                limit(1)
            }
            .decodeSingle<AdminUserProfile>()
    }

    override suspend fun banUser(userId: String, reason: String): Result<Unit> = runCatching {
        supabaseClient.from("profiles")
            .update(
                buildJsonObject {
                    put("is_banned", true)
                    put("ban_reason", reason)
                    put("banned_at", java.time.Instant.now().toString())
                }
            ) {
                filter { eq("id", userId) }
            }
        logAction("ban_user", "user", userId, "Banned: $reason")
    }

    override suspend fun unbanUser(userId: String): Result<Unit> = runCatching {
        supabaseClient.from("profiles")
            .update(
                buildJsonObject {
                    put("is_banned", false)
                    put("ban_reason", null as String?)
                    put("banned_at", null as String?)
                }
            ) {
                filter { eq("id", userId) }
            }
        logAction("unban_user", "user", userId, null)
    }

    // Roles

    override suspend fun fetchRoles(): Result<List<Role>> = runCatching {
        supabaseClient.from("roles")
            .select()
            .decodeList<Role>()
    }

    override suspend fun assignRole(userId: String, roleId: Int): Result<Unit> = runCatching {
        val adminId = supabaseClient.auth.currentUserOrNull()?.id
        supabaseClient.from("user_roles")
            .insert(
                buildJsonObject {
                    put("user_id", userId)
                    put("role_id", roleId)
                    put("assigned_by", adminId)
                }
            )
        logAction("assign_role", "role", "$userId:$roleId", null)
    }

    override suspend fun revokeRole(userId: String, roleId: Int): Result<Unit> = runCatching {
        supabaseClient.from("user_roles")
            .delete {
                filter {
                    eq("user_id", userId)
                    eq("role_id", roleId)
                }
            }
        logAction("revoke_role", "role", "$userId:$roleId", null)
    }

    // Moderation

    override suspend fun fetchModerationQueue(
        status: String?,
        limit: Int,
        offset: Int
    ): Result<List<ModerationQueueItem>> = runCatching {
        supabaseClient.from("forum_moderation_queue")
            .select {
                filter {
                    status?.let { eq("status", it) }
                }
                limit(limit.toLong())
                range(offset.toLong(), (offset + limit - 1).toLong())
                order("created_at", io.github.jan.supabase.postgrest.query.Order.DESCENDING)
            }
            .decodeList<ModerationQueueItem>()
    }

    override suspend fun resolveModerationItem(
        itemId: Int,
        resolution: ModerationResolution,
        notes: String
    ): Result<Unit> = runCatching {
        val adminId = supabaseClient.auth.currentUserOrNull()?.id
        supabaseClient.from("forum_moderation_queue")
            .update(
                buildJsonObject {
                    put("status", "resolved")
                    put("resolution", resolution.name.lowercase())
                    put("resolved_by", adminId)
                    put("resolved_at", java.time.Instant.now().toString())
                    put("resolution_notes", notes)
                }
            ) {
                filter { eq("id", itemId) }
            }
        logAction("resolve_moderation", "moderation", itemId.toString(), "${resolution.name}: $notes")
    }

    // Content

    override suspend fun deletePost(postId: Int): Result<Unit> = runCatching {
        supabaseClient.from("posts")
            .update(
                buildJsonObject { put("is_active", false) }
            ) {
                filter { eq("id", postId) }
            }
        logAction("delete_post", "post", postId.toString(), null)
    }

    override suspend fun restorePost(postId: Int): Result<Unit> = runCatching {
        supabaseClient.from("posts")
            .update(
                buildJsonObject { put("is_active", true) }
            ) {
                filter { eq("id", postId) }
            }
        logAction("restore_post", "post", postId.toString(), null)
    }

    override suspend fun deleteComment(commentId: Int): Result<Unit> = runCatching {
        supabaseClient.from("comments")
            .delete {
                filter { eq("id", commentId) }
            }
        logAction("delete_comment", "comment", commentId.toString(), null)
    }

    // Audit

    override suspend fun fetchAuditLogs(limit: Int, offset: Int): Result<List<AdminAuditLog>> = runCatching {
        supabaseClient.from("admin_audit_log")
            .select {
                limit(limit.toLong())
                range(offset.toLong(), (offset + limit - 1).toLong())
                order("created_at", io.github.jan.supabase.postgrest.query.Order.DESCENDING)
            }
            .decodeList<AdminAuditLog>()
    }

    override suspend fun logAction(
        action: String,
        resourceType: String,
        resourceId: String?,
        details: String?
    ): Result<Unit> = runCatching {
        val adminId = supabaseClient.auth.currentUserOrNull()?.id ?: return@runCatching
        supabaseClient.from("admin_audit_log")
            .insert(
                buildJsonObject {
                    put("admin_id", adminId)
                    put("action", action)
                    put("resource_type", resourceType)
                    resourceId?.let { put("resource_id", it) }
                    details?.let { put("details", it) }
                }
            )
    }

    // Auth

    override suspend fun hasAdminAccess(): Boolean {
        return try {
            val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return false
            val roles = supabaseClient.from("user_roles")
                .select(Columns.raw("role_id, roles(name)")) {
                    filter { eq("user_id", userId) }
                }
                .decodeList<UserRoleWithName>()
            roles.any { it.roleName in listOf("admin", "super_admin", "moderator") }
        } catch (e: Exception) {
            false
        }
    }

    override suspend fun hasSuperAdminAccess(): Boolean {
        return try {
            val userId = supabaseClient.auth.currentUserOrNull()?.id ?: return false
            val roles = supabaseClient.from("user_roles")
                .select(Columns.raw("role_id, roles(name)")) {
                    filter { eq("user_id", userId) }
                }
                .decodeList<UserRoleWithName>()
            roles.any { it.roleName == "super_admin" }
        } catch (e: Exception) {
            false
        }
    }
}

@kotlinx.serialization.Serializable
private data class UserRoleWithName(
    @SerialName("role_id") val roleId: Int,
    @SerialName("roles") val roles: RoleName? = null
) {
    val roleName: String get() = roles?.name ?: ""
}

@kotlinx.serialization.Serializable
private data class RoleName(val name: String)
