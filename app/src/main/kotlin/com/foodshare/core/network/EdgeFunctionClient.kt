package com.foodshare.core.network

import android.util.Log
import com.foodshare.core.error.AppError
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.functions.functions
import io.ktor.client.statement.bodyAsText
import io.ktor.utils.io.InternalAPI
import kotlinx.coroutines.delay
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.encodeToJsonElement
import kotlinx.serialization.json.put
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Client for invoking Supabase Edge Functions.
 *
 * Features:
 * - Type-safe function invocation
 * - Automatic retry with exponential backoff
 * - Rate limiting integration
 * - Request/response logging
 *
 * SYNC: This mirrors Swift FoodshareCore.EdgeFunctionClient
 */
@Singleton
class EdgeFunctionClient @Inject constructor(
    private val supabaseClient: SupabaseClient
) {
    companion object {
        private const val TAG = "EdgeFunctionClient"
        private const val MAX_RETRIES = 3
        private const val INITIAL_RETRY_DELAY_MS = 500L
    }

    @PublishedApi
    internal val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    /**
     * Invoke an Edge Function with typed request/response.
     *
     * @param functionName Name of the Edge Function
     * @param body Request body (will be serialized to JSON)
     * @param headers Additional headers
     * @return Result containing the response or error
     */
    suspend inline fun <reified T : Any, reified R> invoke(
        functionName: String,
        body: T? = null,
        headers: Map<String, String> = emptyMap()
    ): Result<R> {
        val bodyJson = body?.let { json.encodeToJsonElement(it) }
        return invokeInternal(functionName, bodyJson, headers) { responseBody ->
            json.decodeFromString<R>(responseBody)
        }
    }

    /**
     * Invoke an Edge Function without a request body.
     */
    suspend inline fun <reified R> invoke(
        functionName: String,
        headers: Map<String, String> = emptyMap()
    ): Result<R> {
        return invokeInternal(functionName, null, headers) { responseBody ->
            json.decodeFromString<R>(responseBody)
        }
    }

    /**
     * Invoke an Edge Function returning raw JSON.
     */
    suspend fun invokeRaw(
        functionName: String,
        body: JsonElement? = null,
        headers: Map<String, String> = emptyMap()
    ): Result<JsonElement> {
        return invokeInternal(functionName, body, headers) { responseBody ->
            json.parseToJsonElement(responseBody)
        }
    }

    /**
     * Internal invoke with retry logic.
     */
    @OptIn(InternalAPI::class)
    @PublishedApi
    internal suspend fun <R> invokeInternal(
        functionName: String,
        body: JsonElement?,
        headers: Map<String, String>,
        decoder: (String) -> R
    ): Result<R> {
        val requestId = UUID.randomUUID().toString().take(8)
        Log.d(TAG, "[$requestId] Invoking $functionName")

        var lastException: Exception? = null

        for (attempt in 0 until MAX_RETRIES) {
            try {
                val response = supabaseClient.functions.invoke(functionName) {
                    body?.let { this.body = it }
                    headers.forEach { (key, value) ->
                        this.headers.append(key, value)
                    }
                }

                val responseBody = response.bodyAsText()
                val result = decoder(responseBody)
                Log.d(TAG, "[$requestId] $functionName succeeded (attempt ${attempt + 1})")
                return Result.success(result)
            } catch (e: Exception) {
                lastException = e
                val shouldRetry = isRetryable(e) && attempt < MAX_RETRIES - 1

                if (shouldRetry) {
                    val delayMs = INITIAL_RETRY_DELAY_MS * (1 shl attempt)
                    Log.w(TAG, "[$requestId] $functionName failed (attempt ${attempt + 1}), retrying in ${delayMs}ms: ${e.message}")
                    delay(delayMs)
                } else {
                    Log.e(TAG, "[$requestId] $functionName failed permanently: ${e.message}")
                }
            }
        }

        return Result.failure(
            lastException?.let { AppError.from(it) }
                ?: AppError.Unknown("Unknown error invoking $functionName")
        )
    }

    /**
     * Check if an exception is retryable.
     */
    private fun isRetryable(e: Exception): Boolean {
        return when (e) {
            is java.net.SocketTimeoutException,
            is java.net.UnknownHostException,
            is java.net.ConnectException,
            is java.io.IOException -> true
            else -> {
                val message = e.message?.lowercase() ?: return false
                message.contains("500") ||
                message.contains("502") ||
                message.contains("503") ||
                message.contains("504") ||
                message.contains("timeout")
            }
        }
    }
}

// ============================================================================
// Common Edge Function Wrappers
// ============================================================================

/**
 * Send email via Edge Function.
 */
suspend fun EdgeFunctionClient.sendEmail(
    to: String,
    templateId: String,
    variables: Map<String, String> = emptyMap()
): Result<Unit> {
    return invoke(
        functionName = "send-email",
        body = buildJsonObject {
            put("to", to)
            put("template_id", templateId)
            put("variables", Json.encodeToJsonElement(variables))
        }
    )
}

/**
 * Send push notification via Edge Function.
 */
suspend fun EdgeFunctionClient.sendPushNotification(
    userId: String,
    title: String,
    body: String,
    type: String = "system",
    deepLink: String? = null,
    data: Map<String, String> = emptyMap()
): Result<Unit> {
    return invoke(
        functionName = "send-push-notification",
        body = buildJsonObject {
            put("user_id", userId)
            put("title", title)
            put("body", body)
            put("type", type)
            deepLink?.let { put("deep_link", it) }
            if (data.isNotEmpty()) {
                put("data", Json.encodeToJsonElement(data))
            }
        }
    )
}

/**
 * Perform cache operation via Edge Function.
 */
suspend fun EdgeFunctionClient.cacheOperation(
    operation: CacheOperation,
    key: String,
    value: JsonElement? = null,
    ttlSeconds: Int? = null
): Result<JsonElement?> {
    return invoke(
        functionName = "cache-operation",
        body = buildJsonObject {
            put("operation", operation.name.lowercase())
            put("key", key)
            value?.let { put("value", it) }
            ttlSeconds?.let { put("ttl_seconds", it) }
        }
    )
}

enum class CacheOperation {
    GET,
    SET,
    DELETE,
    INVALIDATE
}

/**
 * Upload file via Edge Function (for large files with presigned URLs).
 */
suspend fun EdgeFunctionClient.getUploadUrl(
    bucket: String,
    path: String,
    contentType: String
): Result<UploadUrlResponse> {
    return invoke(
        functionName = "get-upload-url",
        body = buildJsonObject {
            put("bucket", bucket)
            put("path", path)
            put("content_type", contentType)
        }
    )
}

@kotlinx.serialization.Serializable
data class UploadUrlResponse(
    val uploadUrl: String,
    val publicUrl: String,
    val expiresAt: String
)

/**
 * Process image via Edge Function.
 */
suspend fun EdgeFunctionClient.processImage(
    imageUrl: String,
    operations: List<ImageOperation>
): Result<ProcessedImageResponse> {
    return invoke(
        functionName = "process-image",
        body = buildJsonObject {
            put("image_url", imageUrl)
            put("operations", Json.encodeToJsonElement(operations))
        }
    )
}

@kotlinx.serialization.Serializable
data class ImageOperation(
    val type: String,  // "resize", "crop", "blur", etc.
    val params: Map<String, String> = emptyMap()
)

@kotlinx.serialization.Serializable
data class ProcessedImageResponse(
    val url: String,
    val width: Int,
    val height: Int,
    val format: String
)

/**
 * Geocode address via Edge Function.
 */
suspend fun EdgeFunctionClient.geocodeAddress(
    address: String
): Result<GeocodeResponse> {
    return invoke(
        functionName = "geocode",
        body = buildJsonObject {
            put("address", address)
        }
    )
}

@kotlinx.serialization.Serializable
data class GeocodeResponse(
    val latitude: Double,
    val longitude: Double,
    val formattedAddress: String,
    val city: String?,
    val country: String?
)

/**
 * Reverse geocode coordinates via Edge Function.
 */
suspend fun EdgeFunctionClient.reverseGeocode(
    latitude: Double,
    longitude: Double
): Result<GeocodeResponse> {
    return invoke(
        functionName = "reverse-geocode",
        body = buildJsonObject {
            put("latitude", latitude)
            put("longitude", longitude)
        }
    )
}
