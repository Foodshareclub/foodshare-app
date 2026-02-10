package com.foodshare.core.network

import android.util.Log
import com.foodshare.core.error.AppError
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.rpc
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.encodeToJsonElement
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Enterprise-grade RPC client with fault tolerance.
 *
 * Features:
 * - Circuit breaker pattern for failing services
 * - Rate limiting with sliding window
 * - Exponential backoff retry
 * - Request batching support
 * - Audit logging for sensitive operations
 *
 * SYNC: This mirrors Swift FoodshareCore.RateLimitedRPCClient
 */
@Singleton
class RateLimitedRPCClient @Inject constructor(
    supabase: SupabaseClient
) {
    @PublishedApi
    internal val supabaseClient: SupabaseClient = supabase
    @PublishedApi
    internal val json = Json { ignoreUnknownKeys = true }

    companion object {
        private const val TAG = "RateLimitedRPCClient"
    }

    /**
     * Call an RPC function with full fault tolerance.
     *
     * @param functionName Name of the RPC function
     * @param params Parameters to pass (will be serialized to JSON)
     * @param config Optional override configuration
     * @return Result containing the response or error
     */
    suspend inline fun <reified T : Any, reified R : Any> call(
        functionName: String,
        params: T? = null,
        config: RPCConfig? = null
    ): Result<R> {
        return callInternal(
            functionName = functionName,
            paramsJson = params?.let { json.encodeToJsonElement(it) },
            config = config,
            rpcCall = { fn, p ->
                if (p != null) {
                    supabaseClient.postgrest.rpc(fn, p).decodeAs<R>()
                } else {
                    supabaseClient.postgrest.rpc(fn).decodeAs<R>()
                }
            }
        )
    }

    /**
     * Internal call implementation (non-inline to access private members).
     */
    @PublishedApi
    internal suspend fun <R> callInternal(
        functionName: String,
        paramsJson: JsonElement?,
        config: RPCConfig?,
        rpcCall: suspend (String, JsonElement?) -> R
    ): Result<R> {
        val effectiveConfig = config ?: RPCFunctionRegistry.getConfig(functionName)
        val requestId = UUID.randomUUID().toString().take(8)

        // Log if audit required
        if (effectiveConfig.requiresAuditLog) {
            logAudit(requestId, functionName, paramsJson)
        }

        // Get or create circuit breaker and rate limiter
        val circuitBreaker = CircuitBreakerRegistry.getOrCreate(
            name = functionName,
            failureThreshold = effectiveConfig.circuitFailureThreshold,
            resetTimeoutMs = effectiveConfig.circuitResetTimeoutMs
        )
        val rateLimiter = RateLimiterRegistry.getOrCreate(
            name = functionName,
            maxRequests = effectiveConfig.maxRequests,
            windowMs = effectiveConfig.windowMs
        )

        // Check circuit breaker
        if (circuitBreaker.currentState == CircuitState.OPEN) {
            val waitTime = circuitBreaker.remainingCooldownMs()
            Log.w(TAG, "[$requestId] Circuit open for $functionName, wait ${waitTime}ms")
            return Result.failure(
                CircuitOpenException(functionName, waitTime)
            )
        }

        // Check rate limiter
        if (!rateLimiter.tryAcquire()) {
            val waitTime = rateLimiter.getWaitTimeMs()
            Log.w(TAG, "[$requestId] Rate limited for $functionName, wait ${waitTime}ms")
            return Result.failure(
                RateLimitException(functionName, waitTime)
            )
        }

        // Execute with retry
        return executeWithRetry(
            requestId = requestId,
            functionName = functionName,
            paramsJson = paramsJson,
            config = effectiveConfig,
            circuitBreaker = circuitBreaker,
            rpcCall = rpcCall
        )
    }

    /**
     * Execute RPC call with exponential backoff retry.
     */
    private suspend fun <R> executeWithRetry(
        requestId: String,
        functionName: String,
        paramsJson: JsonElement?,
        config: RPCConfig,
        circuitBreaker: CircuitBreaker,
        rpcCall: suspend (String, JsonElement?) -> R
    ): Result<R> {
        var lastException: Exception? = null

        for (attempt in 0..config.maxRetries) {
            try {
                Log.d(TAG, "[$requestId] Calling $functionName (attempt ${attempt + 1})")

                val result = rpcCall(functionName, paramsJson)

                circuitBreaker.recordSuccess()
                Log.d(TAG, "[$requestId] $functionName succeeded")
                return Result.success(result)

            } catch (e: Exception) {
                lastException = e
                circuitBreaker.recordFailure()

                val shouldRetry = isRetryable(e) && attempt < config.maxRetries
                if (shouldRetry) {
                    val delayMs = config.getRetryDelay(attempt)
                    Log.w(TAG, "[$requestId] $functionName failed (attempt ${attempt + 1}), retrying in ${delayMs}ms: ${e.message}")
                    delay(delayMs)
                } else {
                    Log.e(TAG, "[$requestId] $functionName failed permanently: ${e.message}")
                }
            }
        }

        return Result.failure(
            lastException?.let { AppError.from(it) }
                ?: AppError.Unknown("Unknown error in $functionName")
        )
    }

    /**
     * Call an RPC function without parameters.
     */
    suspend inline fun <reified R : Any> call(
        functionName: String,
        config: RPCConfig? = null
    ): Result<R> {
        return call<Unit, R>(functionName, null, config)
    }

    /**
     * Batch multiple RPC calls together.
     *
     * Executes calls in parallel with shared rate limiting.
     *
     * @param calls List of function name to params pairs
     * @return List of results in same order as calls
     */
    suspend inline fun <reified T : Any, reified R : Any> batch(
        calls: List<Pair<String, T?>>,
        config: RPCConfig = RPCConfig.bulk
    ): List<Result<R>> = coroutineScope {
        calls.map { (functionName, params) ->
            async {
                call<T, R>(functionName, params, config)
            }
        }.awaitAll()
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
                // Check for retryable HTTP status codes
                val message = e.message ?: return false
                message.contains("500") ||
                message.contains("502") ||
                message.contains("503") ||
                message.contains("504") ||
                message.contains("429")
            }
        }
    }

    /**
     * Log audit event for sensitive operations.
     */
    private fun logAudit(
        requestId: String,
        functionName: String,
        paramsJson: JsonElement?
    ) {
        try {
            Log.i(TAG, "AUDIT [$requestId] $functionName params=$paramsJson")
            // TODO: Send to audit service when available
        } catch (e: Exception) {
            Log.w(TAG, "Failed to log audit: ${e.message}")
        }
    }

    /**
     * Get health status of all circuit breakers.
     */
    fun getHealthStatus(): Map<String, CircuitBreaker.Metrics> {
        return CircuitBreakerRegistry.getAllMetrics()
    }

    /**
     * Get rate limiter status.
     */
    fun getRateLimiterStatus(): Map<String, RateLimiterStatus> {
        return RateLimiterRegistry.getAllStatus()
    }

    /**
     * Force reset a circuit breaker (admin operation).
     */
    suspend fun resetCircuit(functionName: String) {
        CircuitBreakerRegistry.get(functionName)?.reset()
    }

    /**
     * Reset all circuit breakers and rate limiters (for testing).
     */
    suspend fun resetAll() {
        CircuitBreakerRegistry.resetAll()
        RateLimiterRegistry.resetAll()
    }
}

/**
 * Extension function for convenient RPC calls from repositories.
 */
suspend inline fun <reified T : Any, reified R : Any> RateLimitedRPCClient.invoke(
    functionName: String,
    params: T
): R {
    return call<T, R>(functionName, params).getOrThrow()
}

/**
 * Extension function for RPC calls without parameters.
 */
suspend inline fun <reified R : Any> RateLimitedRPCClient.invoke(
    functionName: String
): R {
    return call<Unit, R>(functionName, null).getOrThrow()
}

/**
 * Result wrapper with additional RPC metadata.
 */
data class RPCResult<T>(
    val data: T?,
    val error: AppError?,
    val requestId: String,
    val durationMs: Long,
    val retryCount: Int
) {
    val isSuccess: Boolean get() = error == null

    fun getOrThrow(): T {
        if (error != null) throw error
        return data ?: throw AppError.InvalidData
    }

    fun getOrNull(): T? = data

    fun <R> map(transform: (T) -> R): RPCResult<R> {
        return RPCResult(
            data = data?.let(transform),
            error = error,
            requestId = requestId,
            durationMs = durationMs,
            retryCount = retryCount
        )
    }
}
