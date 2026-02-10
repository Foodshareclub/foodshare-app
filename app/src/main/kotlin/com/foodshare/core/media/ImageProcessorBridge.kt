package com.foodshare.core.media

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.util.UUID
import com.foodshare.swift.generated.ImageProcessorEngine as SwiftEngine
import com.foodshare.swift.generated.SwiftImageDimensions
import com.foodshare.swift.generated.SwiftHashComparison
import com.foodshare.swift.generated.SwiftImageValidation

/**
 * Image processing, validation, and hashing.
 *
 * Architecture (Frameo pattern - swift-java):
 * - Uses Swift ImageProcessorEngine via swift-java generated classes
 * - Ensures identical image processing across iOS and Android
 * - Kotlin data classes provide API compatibility
 *
 * Swift implementation:
 * - foodshare-core/Sources/FoodshareCore/Media/ImageProcessorEngine.swift
 *
 * Features:
 * - Format detection from magic bytes (Swift)
 * - Dimension extraction from image headers (Swift)
 * - Upload validation with policy enforcement
 * - SHA-256 hash generation and comparison (Swift)
 * - Storage path generation
 */
object ImageProcessorBridge {

    // MARK: - Format Detection

    /**
     * Detect image format from raw bytes using magic bytes.
     * Delegates to Swift ImageProcessorEngine for cross-platform consistency.
     */
    fun detectFormat(data: ByteArray): ImageFormat {
        if (data.isEmpty()) return ImageFormat.UNKNOWN

        // Delegate to Swift engine
        val formatString = SwiftEngine.detectFormat(data)
        return ImageFormat.fromString(formatString)
    }

    /**
     * Detect format from file extension.
     */
    fun detectFormat(extension: String): ImageFormat {
        return when (extension.lowercase()) {
            "jpg", "jpeg" -> ImageFormat.JPEG
            "png" -> ImageFormat.PNG
            "webp" -> ImageFormat.WEBP
            "heic", "heif" -> ImageFormat.HEIC
            "gif" -> ImageFormat.GIF
            "bmp" -> ImageFormat.BMP
            "tiff", "tif" -> ImageFormat.TIFF
            else -> ImageFormat.UNKNOWN
        }
    }

    // MARK: - Dimensions

    /**
     * Extract image dimensions from raw bytes.
     * Delegates to Swift ImageProcessorEngine for cross-platform consistency.
     */
    fun getDimensions(data: ByteArray): ImageDimensions {
        if (data.isEmpty()) return ImageDimensions(0, 0)

        // Delegate to Swift engine
        val swiftResult: SwiftImageDimensions = SwiftEngine.getDimensions(data)
        return swiftResult.use { result ->
            ImageDimensions(result.width, result.height)
        }
    }

    /**
     * Calculate target dimensions for resizing.
     * Delegates to Swift ImageProcessorEngine for cross-platform consistency.
     */
    fun calculateResize(
        width: Int,
        height: Int,
        maxDimension: Int
    ): ImageDimensions {
        val swiftResult: SwiftImageDimensions = SwiftEngine.calculateTargetDimensions(width, height, maxDimension)
        return swiftResult.use { result ->
            ImageDimensions(result.width, result.height)
        }
    }

    // MARK: - Metadata

    /**
     * Get comprehensive image metadata.
     */
    fun getMetadata(data: ByteArray): ImageMetadata {
        val format = detectFormat(data)
        val dimensions = getDimensions(data)

        // Check for alpha channel
        val hasAlpha = when (format) {
            ImageFormat.PNG, ImageFormat.WEBP, ImageFormat.GIF -> true
            else -> false
        }

        // Check for animation (GIF)
        val isAnimated = format == ImageFormat.GIF && checkGifAnimation(data)

        return ImageMetadata(
            format = format,
            dimensions = dimensions,
            orientation = 1,  // Default, would need EXIF parsing for JPEG
            colorSpace = "sRGB",
            hasAlpha = hasAlpha,
            isAnimated = isAnimated,
            frameCount = if (isAnimated) countGifFrames(data) else 1,
            bitDepth = 8,
            fileSize = data.size
        )
    }

    private fun checkGifAnimation(data: ByteArray): Boolean {
        // Look for multiple image blocks (0x2C marker)
        var count = 0
        for (i in 0 until data.size - 1) {
            if (data[i] == 0x2C.toByte()) {
                count++
                if (count > 1) return true
            }
        }
        return false
    }

    private fun countGifFrames(data: ByteArray): Int {
        var count = 0
        for (i in 0 until data.size - 1) {
            if (data[i] == 0x2C.toByte()) {
                count++
            }
        }
        return maxOf(1, count)
    }

    // MARK: - Upload Policy

    /**
     * Get upload policy for a context.
     */
    fun getUploadPolicy(context: UploadContext): UploadPolicy {
        return UploadPolicy.default(context)
    }

    // MARK: - Validation

    /**
     * Validate image for upload.
     */
    fun validateUpload(data: ByteArray, context: UploadContext): UploadValidationResult {
        val errors = mutableListOf<UploadValidationError>()
        val warnings = mutableListOf<String>()
        val recommendations = mutableListOf<UploadRecommendation>()

        val policy = getUploadPolicy(context)

        // Check file size
        if (data.size > policy.maxFileSize) {
            errors.add(UploadValidationError.FILE_TOO_LARGE)
        }

        // Check format
        val format = detectFormat(data)
        if (format == ImageFormat.UNKNOWN) {
            errors.add(UploadValidationError.CORRUPTED_FILE)
        } else if (format.value !in policy.allowedFormats) {
            errors.add(UploadValidationError.UNSUPPORTED_FORMAT)
        }

        // Check dimensions
        val dimensions = getDimensions(data)
        if (dimensions.width <= 0 || dimensions.height <= 0) {
            errors.add(UploadValidationError.CORRUPTED_FILE)
        } else if (dimensions.width > policy.maxDimension || dimensions.height > policy.maxDimension) {
            errors.add(UploadValidationError.DIMENSIONS_TOO_LARGE)
            recommendations.add(
                UploadRecommendation(
                    type = "resize",
                    message = "Image will be resized to fit within ${policy.maxDimension}px",
                    suggestedValue = policy.maxDimension.toString()
                )
            )
        }

        // Add warnings for large files that are still valid
        if (errors.isEmpty() && data.size > policy.maxFileSize / 2) {
            warnings.add("Large file may take longer to upload")
        }

        return UploadValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            warnings = warnings,
            recommendations = recommendations
        )
    }

    /**
     * Quick validation without full processing.
     */
    fun quickValidate(data: ByteArray, context: UploadContext): Boolean {
        val result = validateUpload(data, context)
        return result.isValid
    }

    /**
     * Validate image using Swift engine directly.
     * Delegates to Swift ImageProcessorEngine for cross-platform consistency.
     */
    fun validateWithSwift(
        data: ByteArray,
        maxFileSize: Int,
        maxDimension: Int,
        allowedFormats: List<String>
    ): UploadValidationResult {
        val swiftResult: SwiftImageValidation = SwiftEngine.validateImage(
            data,
            maxFileSize,
            maxDimension,
            allowedFormats.joinToString(",")
        )

        return swiftResult.use { result ->
            val errors = result.errors
                .split(",")
                .filter { it.isNotEmpty() }
                .map { errorString ->
                    when (errorString) {
                        "FILE_TOO_LARGE" -> UploadValidationError.FILE_TOO_LARGE
                        "DIMENSIONS_TOO_LARGE" -> UploadValidationError.DIMENSIONS_TOO_LARGE
                        "UNSUPPORTED_FORMAT" -> UploadValidationError.UNSUPPORTED_FORMAT
                        "CORRUPTED_FILE" -> UploadValidationError.CORRUPTED_FILE
                        else -> UploadValidationError.CORRUPTED_FILE
                    }
                }

            UploadValidationResult(
                isValid = result.isValid,
                errors = errors,
                warnings = emptyList(),
                recommendations = emptyList()
            )
        }
    }

    // MARK: - Hashing

    /**
     * Generate image hash.
     * Uses SHA-256 for duplicate detection via Swift ImageProcessorEngine.
     */
    fun generateHash(data: ByteArray, type: HashType = HashType.CONTENT): ImageHash? {
        if (data.isEmpty()) return null

        // Delegate to Swift engine for cross-platform consistency
        val hashValue = SwiftEngine.generateContentHash(data)
        if (hashValue.isEmpty()) return null

        val timestamp = DateTimeFormatter.ISO_INSTANT.format(Instant.now())

        return ImageHash(
            hashType = type.value,
            hashValue = hashValue,
            hashSize = 256,
            timestamp = timestamp
        )
    }

    /**
     * Compare two hashes and get similarity.
     * Delegates to Swift ImageProcessorEngine for cross-platform consistency.
     */
    fun compareHashes(hash1: ImageHash, hash2: ImageHash): HashComparisonResult {
        val swiftResult: SwiftHashComparison = SwiftEngine.compareHashes(hash1.hashValue, hash2.hashValue)
        return swiftResult.use { result ->
            HashComparisonResult(
                similarity = result.similarity,
                isDuplicate = result.isDuplicate
            )
        }
    }

    /**
     * Calculate Hamming distance between two hashes.
     * Delegates to Swift ImageProcessorEngine for cross-platform consistency.
     */
    fun hammingDistance(hash1: String, hash2: String): Int {
        return SwiftEngine.hammingDistance(hash1, hash2)
    }

    /**
     * Check if two images are duplicates.
     */
    fun areDuplicates(data1: ByteArray, data2: ByteArray): Boolean {
        val hash1 = generateHash(data1) ?: return false
        val hash2 = generateHash(data2) ?: return false
        val result = compareHashes(hash1, hash2)
        return result.isDuplicate
    }

    // MARK: - Storage Path

    /**
     * Generate storage path for upload.
     */
    fun getStoragePath(
        context: UploadContext,
        userId: String,
        entityId: String?,
        filename: String
    ): String {
        val bucket = context.bucket
        val uuid = UUID.randomUUID().toString()
        val extension = filename.substringAfterLast('.', "jpg")

        return if (entityId != null) {
            "$bucket/$userId/$entityId/${uuid}.$extension"
        } else {
            "$bucket/$userId/${uuid}.$extension"
        }
    }
}

// MARK: - Image Format

enum class ImageFormat(val value: String) {
    JPEG("jpeg"),
    PNG("png"),
    WEBP("webp"),
    HEIC("heic"),
    GIF("gif"),
    BMP("bmp"),
    TIFF("tiff"),
    UNKNOWN("unknown");

    val fileExtension: String
        get() = when (this) {
            JPEG -> "jpg"
            PNG -> "png"
            WEBP -> "webp"
            HEIC -> "heic"
            GIF -> "gif"
            BMP -> "bmp"
            TIFF -> "tiff"
            UNKNOWN -> "bin"
        }

    val mimeType: String
        get() = when (this) {
            JPEG -> "image/jpeg"
            PNG -> "image/png"
            WEBP -> "image/webp"
            HEIC -> "image/heic"
            GIF -> "image/gif"
            BMP -> "image/bmp"
            TIFF -> "image/tiff"
            UNKNOWN -> "application/octet-stream"
        }

    val supportsTransparency: Boolean
        get() = this in listOf(PNG, WEBP, GIF)

    val isLossy: Boolean
        get() = this in listOf(JPEG, WEBP, HEIC)

    companion object {
        fun fromString(value: String): ImageFormat {
            return entries.find { it.value == value.lowercase() } ?: UNKNOWN
        }
    }
}

// MARK: - Image Dimensions

@Serializable
data class ImageDimensions(
    val width: Int,
    val height: Int
) {
    val aspectRatio: Double
        get() = if (height > 0) width.toDouble() / height else 0.0

    val pixelCount: Int
        get() = width * height

    val megapixels: Double
        get() = pixelCount / 1_000_000.0

    val isLandscape: Boolean
        get() = width > height

    val isPortrait: Boolean
        get() = height > width

    val isSquare: Boolean
        get() = width == height

    /**
     * Calculate dimensions that fit within max bounds.
     */
    fun fitting(maxWidth: Int, maxHeight: Int): ImageDimensions {
        if (width <= 0 || height <= 0) return this
        val widthRatio = maxWidth.toDouble() / width
        val heightRatio = maxHeight.toDouble() / height
        val scale = minOf(widthRatio, heightRatio, 1.0)
        return ImageDimensions(
            width = (width * scale).toInt(),
            height = (height * scale).toInt()
        )
    }

    /**
     * Calculate dimensions scaled to max dimension.
     */
    fun scaledTo(maxDimension: Int): ImageDimensions {
        return fitting(maxDimension, maxDimension)
    }
}

// MARK: - Image Metadata

@Serializable
data class ImageMetadata(
    val format: ImageFormat = ImageFormat.UNKNOWN,
    val dimensions: ImageDimensions = ImageDimensions(0, 0),
    val orientation: Int = 1,
    val colorSpace: String = "sRGB",
    val hasAlpha: Boolean = false,
    val isAnimated: Boolean = false,
    val frameCount: Int = 1,
    val bitDepth: Int = 8,
    val fileSize: Int = 0,
    val creationDate: String? = null,
    val modificationDate: String? = null,
    val cameraModel: String? = null,
    val location: GeoLocation? = null
) {
    val correctedDimensions: ImageDimensions
        get() = if (orientation in listOf(5, 6, 7, 8)) {
            ImageDimensions(dimensions.height, dimensions.width)
        } else {
            dimensions
        }

    val estimatedMemoryUsage: Int
        get() {
            val bytesPerPixel = if (hasAlpha) 4 else 3
            return correctedDimensions.pixelCount * bytesPerPixel * frameCount
        }

    @Serializable
    data class GeoLocation(
        val latitude: Double,
        val longitude: Double,
        val altitude: Double? = null
    )
}

// MARK: - Upload Context

enum class UploadContext(val value: String) {
    LISTING_PHOTO("listing_photo"),
    PROFILE_AVATAR("profile_avatar"),
    PROFILE_BANNER("profile_banner"),
    CHAT_MESSAGE("chat_message"),
    FORUM_POST("forum_post"),
    FORUM_COMMENT("forum_comment"),
    CHALLENGE_PROOF("challenge_proof"),
    REPORT("report");

    val bucket: String
        get() = when (this) {
            LISTING_PHOTO -> "listings"
            PROFILE_AVATAR, PROFILE_BANNER -> "avatars"
            CHAT_MESSAGE -> "chat-media"
            FORUM_POST, FORUM_COMMENT -> "forum-media"
            CHALLENGE_PROOF -> "challenges"
            REPORT -> "reports"
        }

    companion object {
        fun fromString(value: String): UploadContext? {
            return entries.find { it.value == value }
        }
    }
}

// MARK: - Upload Policy

@Serializable
data class UploadPolicy(
    val context: String,
    val maxFileSize: Int,
    val maxDimension: Int,
    val allowedFormats: List<String>,
    val outputFormat: String = "jpeg",
    val outputQuality: Double = 0.85,
    val generateThumbnail: Boolean = true,
    val thumbnailSize: Int = 200,
    val stripMetadata: Boolean = true,
    val maxUploadsPerHour: Int = 20,
    val requireModeration: Boolean = false
) {
    companion object {
        fun default(context: UploadContext): UploadPolicy {
            return when (context) {
                UploadContext.LISTING_PHOTO -> UploadPolicy(
                    context = context.value,
                    maxFileSize = 10 * 1024 * 1024,
                    maxDimension = 2048,
                    allowedFormats = listOf("jpeg", "png", "webp", "heic"),
                    maxUploadsPerHour = 30,
                    requireModeration = true
                )
                UploadContext.PROFILE_AVATAR -> UploadPolicy(
                    context = context.value,
                    maxFileSize = 5 * 1024 * 1024,
                    maxDimension = 512,
                    allowedFormats = listOf("jpeg", "png", "webp", "heic"),
                    thumbnailSize = 100,
                    maxUploadsPerHour = 10
                )
                UploadContext.CHAT_MESSAGE -> UploadPolicy(
                    context = context.value,
                    maxFileSize = 5 * 1024 * 1024,
                    maxDimension = 1200,
                    allowedFormats = listOf("jpeg", "png", "webp", "heic", "gif"),
                    outputQuality = 0.8,
                    thumbnailSize = 150,
                    maxUploadsPerHour = 50
                )
                else -> UploadPolicy(
                    context = context.value,
                    maxFileSize = 8 * 1024 * 1024,
                    maxDimension = 1600,
                    allowedFormats = listOf("jpeg", "png", "webp")
                )
            }
        }
    }
}

// MARK: - Upload Validation

@Serializable
data class UploadValidationResult(
    val isValid: Boolean,
    val errors: List<UploadValidationError> = emptyList(),
    val warnings: List<String> = emptyList(),
    val recommendations: List<UploadRecommendation> = emptyList()
) {
    companion object {
        val valid = UploadValidationResult(isValid = true)

        fun invalid(vararg errors: UploadValidationError) = UploadValidationResult(
            isValid = false,
            errors = errors.toList()
        )
    }
}

@Serializable
enum class UploadValidationError {
    FILE_TOO_LARGE,
    DIMENSIONS_TOO_LARGE,
    UNSUPPORTED_FORMAT,
    CORRUPTED_FILE,
    RATE_LIMIT_EXCEEDED,
    INSUFFICIENT_PERMISSIONS,
    DUPLICATE_DETECTED,
    CONTENT_POLICY_VIOLATION,
    MISSING_METADATA,
    INVALID_ORIENTATION;

    val message: String
        get() = when (this) {
            FILE_TOO_LARGE -> "File size exceeds the maximum allowed"
            DIMENSIONS_TOO_LARGE -> "Image dimensions exceed the maximum allowed"
            UNSUPPORTED_FORMAT -> "Image format is not supported"
            CORRUPTED_FILE -> "File appears to be corrupted"
            RATE_LIMIT_EXCEEDED -> "Upload rate limit exceeded"
            INSUFFICIENT_PERMISSIONS -> "You don't have permission to upload"
            DUPLICATE_DETECTED -> "This image has already been uploaded"
            CONTENT_POLICY_VIOLATION -> "Image violates content policy"
            MISSING_METADATA -> "Required metadata is missing"
            INVALID_ORIENTATION -> "Image orientation is invalid"
        }
}

@Serializable
data class UploadRecommendation(
    val type: String,
    val message: String,
    val suggestedValue: String? = null
)

// MARK: - Hash Types

enum class HashType(val value: String) {
    AVERAGE("average"),
    PERCEPTUAL("perceptual"),
    DIFFERENCE("difference"),
    CONTENT("content")
}

@Serializable
data class ImageHash(
    val hashType: String,
    val hashValue: String,
    val hashSize: Int = 64,
    val timestamp: String? = null
)

@Serializable
data class HashComparisonResult(
    val similarity: Double,
    val isDuplicate: Boolean
)

// MARK: - Processing Options

@Serializable
data class ImageProcessingOptions(
    val maxWidth: Int? = null,
    val maxHeight: Int? = null,
    val quality: Double = 0.85,
    val outputFormat: String = "jpeg",
    val stripMetadata: Boolean = true,
    val autoOrient: Boolean = true,
    val generateThumbnail: Boolean = false,
    val thumbnailSize: Int = 200
) {
    companion object {
        fun from(policy: UploadPolicy) = ImageProcessingOptions(
            maxWidth = policy.maxDimension,
            maxHeight = policy.maxDimension,
            quality = policy.outputQuality,
            outputFormat = policy.outputFormat,
            stripMetadata = policy.stripMetadata,
            generateThumbnail = policy.generateThumbnail,
            thumbnailSize = policy.thumbnailSize
        )
    }
}

// MARK: - Upload Request

data class UploadRequest(
    val context: UploadContext,
    val userId: String,
    val entityId: String? = null,
    val filename: String,
    val mimeType: String,
    val fileSize: Int,
    val metadata: ImageMetadata? = null
) {
    /**
     * Generate storage path for this upload.
     */
    fun storagePath(): String {
        return ImageProcessorBridge.getStoragePath(context, userId, entityId, filename)
    }
}

// MARK: - Upload Result

@Serializable
data class UploadResult(
    val success: Boolean,
    val url: String? = null,
    val thumbnailUrl: String? = null,
    val storagePath: String? = null,
    val fileSize: Int = 0,
    val processedMetadata: ImageMetadata? = null,
    val error: String? = null,
    val uploadedAt: String? = null
) {
    companion object {
        fun success(
            url: String,
            thumbnailUrl: String? = null,
            storagePath: String,
            fileSize: Int,
            metadata: ImageMetadata?
        ) = UploadResult(
            success = true,
            url = url,
            thumbnailUrl = thumbnailUrl,
            storagePath = storagePath,
            fileSize = fileSize,
            processedMetadata = metadata
        )

        fun failure(error: String) = UploadResult(
            success = false,
            error = error
        )
    }
}

// MARK: - Image Manager

/**
 * High-level image management with caching and processing.
 */
class ImageManager {
    private val hashCache = mutableMapOf<String, ImageHash>()

    /**
     * Prepare image for upload with validation and processing.
     */
    suspend fun prepareForUpload(
        data: ByteArray,
        context: UploadContext
    ): PreparedUpload {
        // Validate
        val validation = ImageProcessorBridge.validateUpload(data, context)
        if (!validation.isValid) {
            return PreparedUpload(
                isValid = false,
                errors = validation.errors,
                recommendations = validation.recommendations
            )
        }

        // Get metadata
        val metadata = ImageProcessorBridge.getMetadata(data)

        // Generate hash
        val hash = ImageProcessorBridge.generateHash(data)

        // Get policy
        val policy = ImageProcessorBridge.getUploadPolicy(context)

        // Calculate target dimensions
        val targetDimensions = metadata.dimensions.scaledTo(policy.maxDimension)

        return PreparedUpload(
            isValid = true,
            originalData = data,
            metadata = metadata,
            targetDimensions = targetDimensions,
            hash = hash,
            policy = policy,
            needsResize = targetDimensions != metadata.dimensions
        )
    }

    /**
     * Check if image is duplicate of existing uploads.
     */
    fun isDuplicate(hash: ImageHash, existingHashes: List<ImageHash>): Boolean {
        return existingHashes.any { existing ->
            val result = ImageProcessorBridge.compareHashes(hash, existing)
            result.isDuplicate
        }
    }

    /**
     * Cache hash for quick duplicate detection.
     */
    fun cacheHash(id: String, hash: ImageHash) {
        hashCache[id] = hash
    }

    /**
     * Clear hash cache.
     */
    fun clearHashCache() {
        hashCache.clear()
    }
}

/**
 * Result of preparing an image for upload.
 */
data class PreparedUpload(
    val isValid: Boolean,
    val originalData: ByteArray? = null,
    val metadata: ImageMetadata? = null,
    val targetDimensions: ImageDimensions? = null,
    val hash: ImageHash? = null,
    val policy: UploadPolicy? = null,
    val needsResize: Boolean = false,
    val errors: List<UploadValidationError> = emptyList(),
    val recommendations: List<UploadRecommendation> = emptyList()
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false
        other as PreparedUpload
        return isValid == other.isValid &&
                originalData.contentEquals(other.originalData) &&
                metadata == other.metadata
    }

    override fun hashCode(): Int {
        var result = isValid.hashCode()
        result = 31 * result + (originalData?.contentHashCode() ?: 0)
        result = 31 * result + (metadata?.hashCode() ?: 0)
        return result
    }
}
