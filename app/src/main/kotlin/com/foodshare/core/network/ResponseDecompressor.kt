package com.foodshare.core.network

import okhttp3.MediaType.Companion.toMediaType
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.util.zip.GZIPInputStream
import java.util.zip.Inflater
import java.util.zip.InflaterInputStream

/**
 * Compression algorithm types
 */
enum class CompressionAlgorithm {
    GZIP,
    DEFLATE,
    NONE;

    companion object {
        fun fromHeader(contentEncoding: String?): CompressionAlgorithm {
            return when (contentEncoding?.lowercase()) {
                "gzip" -> GZIP
                "deflate" -> DEFLATE
                else -> NONE
            }
        }
    }
}

/**
 * Decompression statistics
 */
data class DecompressionStats(
    val compressedSize: Int,
    val decompressedSize: Int,
    val ratio: Double,
    val algorithm: CompressionAlgorithm,
    val timeMs: Long
)

/**
 * Response decompressor for handling compressed API responses
 */
object ResponseDecompressor {

    /**
     * Decompress data based on content encoding
     */
    fun decompress(
        data: ByteArray,
        contentEncoding: String?
    ): Pair<ByteArray, DecompressionStats> {
        val algorithm = CompressionAlgorithm.fromHeader(contentEncoding)
        val startTime = System.currentTimeMillis()

        val decompressed = when (algorithm) {
            CompressionAlgorithm.GZIP -> decompressGzip(data)
            CompressionAlgorithm.DEFLATE -> decompressDeflate(data)
            CompressionAlgorithm.NONE -> data
        }

        val timeMs = System.currentTimeMillis() - startTime

        val stats = DecompressionStats(
            compressedSize = data.size,
            decompressedSize = decompressed.size,
            ratio = if (data.isNotEmpty()) decompressed.size.toDouble() / data.size else 1.0,
            algorithm = algorithm,
            timeMs = timeMs
        )

        return decompressed to stats
    }

    /**
     * Decompress gzip data
     */
    private fun decompressGzip(data: ByteArray): ByteArray {
        return GZIPInputStream(ByteArrayInputStream(data)).use { gis ->
            ByteArrayOutputStream().use { bos ->
                val buffer = ByteArray(8192)
                var len: Int
                while (gis.read(buffer).also { len = it } != -1) {
                    bos.write(buffer, 0, len)
                }
                bos.toByteArray()
            }
        }
    }

    /**
     * Decompress deflate data
     */
    private fun decompressDeflate(data: ByteArray): ByteArray {
        return InflaterInputStream(ByteArrayInputStream(data), Inflater(true)).use { iis ->
            ByteArrayOutputStream().use { bos ->
                val buffer = ByteArray(8192)
                var len: Int
                while (iis.read(buffer).also { len = it } != -1) {
                    bos.write(buffer, 0, len)
                }
                bos.toByteArray()
            }
        }
    }

    /**
     * Check if response should be decompressed
     */
    fun shouldDecompress(contentEncoding: String?): Boolean {
        return contentEncoding != null &&
                (contentEncoding.contains("gzip", ignoreCase = true) ||
                        contentEncoding.contains("deflate", ignoreCase = true))
    }
}

/**
 * Shortened key mappings (matches backend)
 */
object KeyMapping {
    private val shortToLong = mapOf(
        "i" to "id",
        "c" to "created_at",
        "u" to "updated_at",
        "ui" to "user_id",
        "t" to "title",
        "d" to "description",
        "img" to "image_url",
        "imgs" to "image_urls",
        "lat" to "latitude",
        "lng" to "longitude",
        "dn" to "display_name",
        "av" to "avatar_url",
        "s" to "status",
        "tp" to "type",
        "cat" to "category",
        "q" to "quantity",
        "exp" to "expires_at",
        "loc" to "location_name",
        "di" to "dietary_info",
        "ia" to "is_active",
        "m" to "message",
        "cnt" to "content",
        "r" to "rating",
        "n" to "count"
    )

    fun expandKey(shortKey: String): String = shortToLong[shortKey] ?: shortKey

    fun shortenKey(longKey: String): String =
        shortToLong.entries.find { it.value == longKey }?.key ?: longKey
}

/**
 * Payload expander for handling optimized responses
 */
object PayloadExpander {

    private val json = Json { ignoreUnknownKeys = true }

    /**
     * Expand shortened keys in JSON
     */
    fun expandKeys(jsonString: String): String {
        return try {
            val element = json.parseToJsonElement(jsonString)
            val expanded = expandElement(element)
            expanded.toString()
        } catch (e: Exception) {
            jsonString
        }
    }

    /**
     * Expand a compact array format to objects
     */
    fun expandCompactArray(jsonString: String): String {
        return try {
            val element = json.parseToJsonElement(jsonString).jsonObject
            val keys = element["keys"]?.jsonArray?.map { it.jsonPrimitive.content } ?: return jsonString
            val values = element["values"]?.jsonArray ?: return jsonString

            val expanded = values.map { row ->
                buildJsonObject {
                    row.jsonArray.forEachIndexed { index, value ->
                        if (index < keys.size) {
                            put(keys[index], value)
                        }
                    }
                }
            }

            JsonArray(expanded).toString()
        } catch (e: Exception) {
            jsonString
        }
    }

    /**
     * Expand a JSON element recursively
     */
    private fun expandElement(element: JsonElement): JsonElement {
        return when (element) {
            is JsonObject -> expandObject(element)
            is JsonArray -> JsonArray(element.map { expandElement(it) })
            else -> element
        }
    }

    /**
     * Expand an object's keys
     */
    private fun expandObject(obj: JsonObject): JsonObject {
        return buildJsonObject {
            obj.forEach { (key, value) ->
                val expandedKey = KeyMapping.expandKey(key)
                put(expandedKey, expandElement(value))
            }
        }
    }

    /**
     * Convert Unix timestamp to ISO date string
     */
    fun unixToIso(timestamp: Long): String {
        return java.time.Instant.ofEpochSecond(timestamp).toString()
    }

    /**
     * Convert relative time string to approximate timestamp
     */
    fun relativeToApproximate(relative: String): Long {
        val now = System.currentTimeMillis()
        val value = relative.dropLast(1).toIntOrNull() ?: return now
        val unit = relative.last()

        val millisToSubtract = when (unit) {
            's' -> value * 1000L
            'm' -> value * 60 * 1000L
            'h' -> value * 60 * 60 * 1000L
            'd' -> value * 24 * 60 * 60 * 1000L
            'w' -> value * 7 * 24 * 60 * 60 * 1000L
            else -> 0L
        }

        return now - millisToSubtract
    }
}

/**
 * Response processor for handling optimized API responses
 */
class OptimizedResponseProcessor {

    private var expandShortKeys: Boolean = true
    private var expandCompactArrays: Boolean = true
    private var convertUnixDates: Boolean = true

    fun configure(
        expandShortKeys: Boolean = true,
        expandCompactArrays: Boolean = true,
        convertUnixDates: Boolean = true
    ): OptimizedResponseProcessor {
        this.expandShortKeys = expandShortKeys
        this.expandCompactArrays = expandCompactArrays
        this.convertUnixDates = convertUnixDates
        return this
    }

    /**
     * Process a response body
     */
    fun process(
        body: ByteArray,
        contentEncoding: String? = null,
        isCompactFormat: Boolean = false
    ): ProcessedResponse {
        // Decompress if needed
        val (decompressed, decompressionStats) = ResponseDecompressor.decompress(body, contentEncoding)

        // Convert to string
        var jsonString = String(decompressed, Charsets.UTF_8)

        // Expand compact array format
        if (isCompactFormat && expandCompactArrays) {
            jsonString = PayloadExpander.expandCompactArray(jsonString)
        }

        // Expand shortened keys
        if (expandShortKeys) {
            jsonString = PayloadExpander.expandKeys(jsonString)
        }

        return ProcessedResponse(
            data = jsonString,
            decompressionStats = decompressionStats,
            originalSize = body.size,
            processedSize = jsonString.length
        )
    }
}

/**
 * Processed response data
 */
data class ProcessedResponse(
    val data: String,
    val decompressionStats: DecompressionStats,
    val originalSize: Int,
    val processedSize: Int
) {
    val totalExpansionRatio: Double
        get() = if (originalSize > 0) processedSize.toDouble() / originalSize else 1.0
}

/**
 * OkHttp interceptor for automatic decompression and expansion
 */
class OptimizedResponseInterceptor(
    private val expandShortKeys: Boolean = true
) : okhttp3.Interceptor {

    private val processor = OptimizedResponseProcessor().configure(
        expandShortKeys = expandShortKeys
    )

    override fun intercept(chain: okhttp3.Interceptor.Chain): okhttp3.Response {
        val response = chain.proceed(chain.request())

        // Check if we should process
        val contentEncoding = response.header("Content-Encoding")
        val originalSize = response.header("X-Original-Size")?.toIntOrNull()

        // If not compressed and no indication of optimization, return as-is
        if (!ResponseDecompressor.shouldDecompress(contentEncoding) && originalSize == null) {
            return response
        }

        // Get response body
        val body = response.body ?: return response
        val bytes = body.bytes()

        // Check if compact format
        val isCompactFormat = response.header("X-Compact-Format") == "true"

        // Process
        val processed = processor.process(bytes, contentEncoding, isCompactFormat)

        // Return new response with processed body
        val newBody = okhttp3.ResponseBody.create(
            "application/json; charset=utf-8".toMediaType(),
            processed.data
        )

        return response.newBuilder()
            .body(newBody)
            .removeHeader("Content-Encoding")
            .header("Content-Length", processed.data.length.toString())
            .header("X-Decompression-Ratio", processed.decompressionStats.ratio.toString())
            .build()
    }
}

/**
 * Extension function for OkHttp client builder
 */
fun okhttp3.OkHttpClient.Builder.addOptimizedResponseInterceptor(
    expandShortKeys: Boolean = true
): okhttp3.OkHttpClient.Builder {
    return addInterceptor(OptimizedResponseInterceptor(expandShortKeys))
}
