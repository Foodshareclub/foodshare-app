package com.foodshare.core.security

import com.foodshare.core.network.EdgeFunctionClient
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.from
import kotlinx.coroutines.delay
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Service for GDPR data export operations
 */
@Singleton
class GDPRExportService @Inject constructor(
    private val supabaseClient: SupabaseClient,
    private val edgeFunctionClient: EdgeFunctionClient
) {

    /**
     * Request a GDPR data export
     *
     * @return Export request ID
     */
    suspend fun requestExport(): Result<String> {
        return try {
            val userId = supabaseClient.auth.currentUserOrNull()?.id
                ?: return Result.failure(Exception("User not authenticated"))

            val payload = buildJsonObject {
                put("userId", userId)
            }

            val response = edgeFunctionClient.invoke<ExportResponse>(
                functionName = "gdpr-export"
            ).getOrThrow()

            Result.success(response.exportId)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Check the status of a data export
     *
     * @param exportId Export request ID
     * @return Export status
     */
    suspend fun checkExportStatus(exportId: String): Result<ExportStatus> {
        return try {
            val response = supabaseClient.from("data_exports")
                .select {
                    filter {
                        eq("id", exportId)
                    }
                }
                .decodeSingle<ExportStatusRecord>()

            Result.success(
                ExportStatus(
                    id = response.id,
                    status = response.status,
                    downloadUrl = response.download_url,
                    expiresAt = response.expires_at,
                    createdAt = response.created_at
                )
            )
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Get download URL for completed export
     *
     * @param exportId Export request ID
     * @return Download URL or null if not ready
     */
    suspend fun getExportDownloadUrl(exportId: String): String? {
        return try {
            val status = checkExportStatus(exportId).getOrNull()
            if (status?.status == "completed") {
                status.downloadUrl
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    /**
     * Poll export status until completed or failed
     *
     * @param exportId Export request ID
     * @param maxAttempts Maximum number of polling attempts
     * @param delayMs Delay between polls in milliseconds
     * @return Final export status
     */
    suspend fun pollExportStatus(
        exportId: String,
        maxAttempts: Int = 30,
        delayMs: Long = 2000
    ): Result<ExportStatus> {
        repeat(maxAttempts) {
            val statusResult = checkExportStatus(exportId)
            val status = statusResult.getOrNull()

            when (status?.status) {
                "completed", "failed", "expired" -> return statusResult
                else -> delay(delayMs)
            }
        }

        return Result.failure(Exception("Export polling timeout"))
    }
}

/**
 * Export response from Edge Function
 */
@Serializable
data class ExportResponse(
    val exportId: String,
    val message: String
)

/**
 * Export status model
 */
data class ExportStatus(
    val id: String,
    val status: String,
    val downloadUrl: String?,
    val expiresAt: String?,
    val createdAt: String
)

/**
 * Export status database record
 */
@Serializable
data class ExportStatusRecord(
    val id: String,
    val user_id: String,
    val status: String,
    val download_url: String? = null,
    val expires_at: String? = null,
    val created_at: String
)
