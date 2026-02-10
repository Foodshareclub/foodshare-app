package com.foodshare.core.validation

import org.swift.swiftkit.core.SwiftArena
import java.util.Optional
import java.util.UUID
import com.foodshare.swift.generated.ListingValidator as SwiftListingValidator
import com.foodshare.swift.generated.AuthValidator as SwiftAuthValidator
import com.foodshare.swift.generated.ProfileValidator as SwiftProfileValidator
import com.foodshare.swift.generated.ReviewValidator as SwiftReviewValidator
import com.foodshare.swift.generated.InputSanitizer as SwiftInputSanitizer
import com.foodshare.swift.generated.TextSanitizer as SwiftTextSanitizer
import com.foodshare.swift.generated.CrossFieldValidator as SwiftCrossFieldValidator
import com.foodshare.swift.generated.CrossValidationResult as SwiftCrossValidationResult
import com.foodshare.swift.generated.Coordinate as SwiftCoordinate
import com.foodshare.swift.generated.DistanceFormatter as SwiftDistanceFormatter
import com.foodshare.swift.generated.RelativeDateFormatter as SwiftRelativeDateFormatter

/**
 * Bridge to Swift validation logic using swift-java generated classes.
 *
 * This provides a Kotlin-friendly API for the Swift validators.
 * Uses swift-java generated classes for type-safe bindings with SwiftArena memory management.
 *
 * Architecture (Frameo pattern - fully swift-java):
 * - All validators use generated Java classes from swift-java
 * - SwiftArena manages memory lifecycle automatically
 * - No manual JNI code required
 *
 * The validation rules are defined in Swift:
 * - foodshare-core/Sources/FoodshareCore/Validation/ListingValidator.swift
 * - foodshare-core/Sources/FoodshareCore/Validation/ProfileValidator.swift
 * - foodshare-core/Sources/FoodshareCore/Validation/ReviewValidator.swift
 * - foodshare-core/Sources/FoodshareCore/Validation/AuthValidator.swift
 */
object ValidationBridge {

    // SwiftArena for memory management - auto-releases when objects are no longer needed
    private val arena: SwiftArena by lazy { SwiftArena.ofAuto() }

    // Lazily initialized validators using swift-java generated classes
    private val listingValidator: SwiftListingValidator by lazy {
        SwiftListingValidator.init(arena)
    }

    private val authValidator: SwiftAuthValidator by lazy {
        SwiftAuthValidator.init(arena)
    }

    private val profileValidator: SwiftProfileValidator by lazy {
        SwiftProfileValidator.init(arena)
    }

    private val reviewValidator: SwiftReviewValidator by lazy {
        SwiftReviewValidator.init(arena)
    }

    // ========================================================================
    // Listing Validation Constants (synced with Swift ListingValidator)
    // ========================================================================

    const val MIN_TITLE_LENGTH = 3
    const val MAX_TITLE_LENGTH = 100
    const val MAX_DESCRIPTION_LENGTH = 500

    // ========================================================================
    // Profile Validation Constants (synced with Swift ProfileValidator)
    // ========================================================================

    const val MIN_NICKNAME_LENGTH = 2
    const val MAX_NICKNAME_LENGTH = 50
    const val MAX_BIO_LENGTH = 300

    // ========================================================================
    // Listing Validation (using swift-java generated classes)
    // ========================================================================

    /**
     * Validate a food listing using swift-java generated classes.
     *
     * @param title The listing title
     * @param description The listing description
     * @param quantity Number of items (default 1)
     * @return ValidationResult with isValid and list of errors
     */
    fun validateListing(
        title: String,
        description: String,
        quantity: Int = 1
    ): ValidationResult {
        val errors = mutableListOf<ValidationError>()

        // Validate title using generated ListingValidator
        listingValidator.validateTitle(title).ifPresent {
            errors.add(ValidationError.Custom(it))
        }

        // Validate description using generated ListingValidator
        listingValidator.validateDescription(description).ifPresent {
            errors.add(ValidationError.Custom(it))
        }

        // Validate quantity (local check - mirrors Swift logic)
        if (quantity < 1) {
            errors.add(ValidationError.InvalidQuantity)
        }

        return ValidationResult(
            isValid = errors.isEmpty(),
            errors = errors
        )
    }

    /**
     * Validate title only using swift-java generated ListingValidator.
     *
     * @return Error message if invalid, null if valid
     */
    fun validateTitle(title: String): String? {
        return listingValidator.validateTitle(title).orElse(null)
    }

    /**
     * Validate description only using swift-java generated ListingValidator.
     *
     * @return Error message if invalid, null if valid
     */
    fun validateDescription(description: String): String? {
        return listingValidator.validateDescription(description).orElse(null)
    }

    // ========================================================================
    // Profile Validation (using swift-java generated classes)
    // ========================================================================

    /**
     * Validate a user profile.
     *
     * @param nickname Optional nickname to validate
     * @param bio Optional bio to validate
     * @return ValidationResult with isValid and list of errors
     */
    fun validateProfile(
        nickname: String?,
        bio: String?
    ): ValidationResult {
        val swiftResult = profileValidator.validate(
            Optional.ofNullable(nickname),
            Optional.ofNullable(bio),
            arena
        )
        return ValidationResult(
            isValid = swiftResult.isValid(),
            errors = swiftResult.getErrorMessages().map { ValidationError.Custom(it) }
        )
    }

    /**
     * Validate nickname only using swift-java generated ProfileValidator.
     *
     * @return Error message if invalid, null if valid
     */
    fun validateNickname(nickname: String): String? {
        return profileValidator.validateNickname(nickname).orElse(null)
    }

    /**
     * Validate bio only using swift-java generated ProfileValidator.
     *
     * @return Error message if invalid, null if valid
     */
    fun validateBio(bio: String): String? {
        return profileValidator.validateBio(bio).orElse(null)
    }

    // ========================================================================
    // Review Validation Constants (synced with Swift ReviewValidator)
    // ========================================================================

    const val MIN_RATING = 1
    const val MAX_RATING = 5
    const val MAX_COMMENT_LENGTH = 500

    // ========================================================================
    // Review Validation (using swift-java generated classes)
    // ========================================================================

    /**
     * Validate a review using swift-java generated classes.
     *
     * @param rating Rating (1-5)
     * @param comment Optional comment text
     * @return ValidationResult with isValid and list of errors
     */
    fun validateReview(
        rating: Int,
        comment: String? = null
    ): ValidationResult {
        val errors = mutableListOf<ValidationError>()

        // Validate rating (local check - mirrors Swift logic)
        if (rating < MIN_RATING || rating > MAX_RATING) {
            errors.add(ValidationError.InvalidRating(MIN_RATING, MAX_RATING))
        }

        // Validate comment if provided using generated ReviewValidator
        comment?.let {
            reviewValidator.validateComment(Optional.of(it)).ifPresent { error ->
                errors.add(ValidationError.Custom(error))
            }
        }

        return ValidationResult(
            isValid = errors.isEmpty(),
            errors = errors
        )
    }

    /**
     * Validate review comment only using swift-java generated ReviewValidator.
     *
     * @return Error message if invalid, null if valid
     */
    fun validateReviewComment(comment: String?): String? {
        return reviewValidator.validateComment(Optional.ofNullable(comment)).orElse(null)
    }

    // ========================================================================
    // Auth Validation Constants (synced with Swift AuthValidator)
    // ========================================================================

    const val MIN_PASSWORD_LENGTH = 8
    const val MAX_PASSWORD_LENGTH = 128

    // ========================================================================
    // Auth Validation (using swift-java generated classes)
    // ========================================================================

    /**
     * Validate email format using swift-java generated AuthValidator.
     *
     * @param email Email address to validate
     * @return Error message if invalid, null if valid
     */
    fun validateEmail(email: String): String? {
        // Use static method from generated class
        val isValid = SwiftAuthValidator.validateEmail(email)
        return if (isValid) null else "Please enter a valid email address"
    }

    /**
     * Validate email with detailed message using swift-java generated AuthValidator.
     *
     * @param email Email address to validate
     * @return Error message if invalid, null if valid
     */
    fun validateEmailWithMessage(email: String): String? {
        return authValidator.validateEmailWithMessage(email).orElse(null)
    }

    /**
     * Validate password meets requirements using swift-java generated AuthValidator.
     *
     * @param password Password to validate
     * @return Error message if invalid, null if valid
     */
    fun validatePassword(password: String): String? {
        val result = SwiftAuthValidator.validatePassword(password, arena)
        return if (result.isValid()) null else result.getFirstError().orElse("Invalid password")
    }

    /**
     * Validate password with detailed message using swift-java generated AuthValidator.
     *
     * @param password Password to validate
     * @return Error message if invalid, null if valid
     */
    fun validatePasswordWithMessage(password: String): String? {
        return authValidator.validatePasswordWithMessage(password).orElse(null)
    }

    /**
     * Evaluate password strength using swift-java generated AuthValidator.
     *
     * @param password Password to evaluate
     * @return PasswordStrengthLevel indicating strength
     */
    fun evaluatePasswordStrength(password: String): PasswordStrengthLevel {
        val strength = SwiftAuthValidator.evaluatePasswordStrength(password, arena)
        // Convert from SwiftPasswordStrength to Kotlin enum
        return when (strength.getDiscriminator()) {
            com.foodshare.swift.generated.PasswordStrength.Discriminator.NONE -> PasswordStrengthLevel.NONE
            com.foodshare.swift.generated.PasswordStrength.Discriminator.WEAK -> PasswordStrengthLevel.WEAK
            com.foodshare.swift.generated.PasswordStrength.Discriminator.MEDIUM -> PasswordStrengthLevel.MEDIUM
            com.foodshare.swift.generated.PasswordStrength.Discriminator.STRONG -> PasswordStrengthLevel.STRONG
            com.foodshare.swift.generated.PasswordStrength.Discriminator.VERYSTRONG -> PasswordStrengthLevel.VERY_STRONG
            else -> PasswordStrengthLevel.NONE
        }
    }

    // ========================================================================
    // Sanitization (using swift-java generated classes)
    // ========================================================================

    /**
     * Sanitize text using swift-java generated InputSanitizer.
     */
    fun sanitizeText(input: String): String {
        return SwiftInputSanitizer.sanitizeText(input)
    }

    /**
     * Escape HTML using swift-java generated InputSanitizer.
     */
    fun escapeHTML(input: String): String {
        return SwiftInputSanitizer.escapeHTML(input)
    }

    /**
     * Strip HTML using swift-java generated InputSanitizer.
     */
    fun stripHTML(input: String): String {
        return SwiftInputSanitizer.stripHTML(input)
    }

    /**
     * Sanitize text using swift-java generated TextSanitizer.
     */
    fun sanitize(input: String): String {
        return SwiftTextSanitizer.sanitize(input)
    }

    /**
     * Check if input contains dangerous URL schemes using swift-java generated TextSanitizer.
     */
    fun containsDangerousURLScheme(input: String): Boolean {
        return SwiftTextSanitizer.containsDangerousURLScheme(input)
    }

    /**
     * Remove dangerous URL schemes using swift-java generated TextSanitizer.
     */
    fun removeDangerousURLSchemes(input: String): String {
        return SwiftTextSanitizer.removeDangerousURLSchemes(input)
    }

    // ========================================================================
    // Coordinate Validation (using swift-java generated Coordinate)
    // ========================================================================

    /**
     * Validate if coordinates are within valid ranges.
     *
     * @param latitude Latitude value (-90 to 90)
     * @param longitude Longitude value (-180 to 180)
     * @return true if valid, false otherwise
     */
    fun isValidCoordinate(latitude: Double, longitude: Double): Boolean {
        return SwiftCoordinate.isValid(latitude, longitude)
    }

    // ========================================================================
    // Message Validation Constants (synced with Swift)
    // ========================================================================

    const val MAX_MESSAGE_LENGTH = 2000

    // ========================================================================
    // Message Validation (local implementation using generated sanitizers)
    // ========================================================================

    /**
     * Validate chat message content.
     */
    fun validateMessage(content: String): ValidationResult {
        val errors = mutableListOf<ValidationError>()
        val trimmed = content.trim()

        if (trimmed.isEmpty()) {
            errors.add(ValidationError.Custom("Message cannot be empty"))
        } else if (trimmed.length > MAX_MESSAGE_LENGTH) {
            errors.add(ValidationError.Custom("Message cannot exceed $MAX_MESSAGE_LENGTH characters"))
        }

        return ValidationResult(
            isValid = errors.isEmpty(),
            errors = errors
        )
    }

    /**
     * Sanitize message content for display.
     */
    fun sanitizeMessage(content: String): String {
        // Use generated sanitizers: sanitize text and strip dangerous HTML
        return SwiftTextSanitizer.sanitize(SwiftInputSanitizer.stripHTML(content))
    }

    // ========================================================================
    // Search Validation Constants (synced with Swift)
    // ========================================================================

    const val MAX_SEARCH_QUERY_LENGTH = 200
    const val MIN_SEARCH_RADIUS_KM = 0.1
    const val MAX_SEARCH_RADIUS_KM = 100.0

    // ========================================================================
    // Search Validation (local implementation)
    // ========================================================================

    /**
     * Validate search query.
     */
    fun validateSearchQuery(query: String): ValidationResult {
        val errors = mutableListOf<ValidationError>()
        val trimmed = query.trim()

        if (trimmed.isEmpty()) {
            errors.add(ValidationError.Custom("Search query cannot be empty"))
        } else if (trimmed.length > MAX_SEARCH_QUERY_LENGTH) {
            errors.add(ValidationError.Custom("Search query cannot exceed $MAX_SEARCH_QUERY_LENGTH characters"))
        }

        return ValidationResult(
            isValid = errors.isEmpty(),
            errors = errors
        )
    }

    /**
     * Validate search radius in kilometers.
     */
    fun validateSearchRadius(radiusKm: Double): Boolean {
        return radiusKm >= MIN_SEARCH_RADIUS_KM && radiusKm <= MAX_SEARCH_RADIUS_KM
    }

    /**
     * Clamp search radius to valid range.
     */
    fun clampSearchRadius(radiusKm: Double): Double {
        return radiusKm.coerceIn(MIN_SEARCH_RADIUS_KM, MAX_SEARCH_RADIUS_KM)
    }

    // ========================================================================
    // Forum Validation Constants (synced with Swift)
    // ========================================================================

    const val MIN_FORUM_TITLE_LENGTH = 5
    const val MAX_FORUM_TITLE_LENGTH = 200
    const val MIN_FORUM_CONTENT_LENGTH = 20
    const val MAX_FORUM_CONTENT_LENGTH = 10000

    // ========================================================================
    // Forum Validation (local implementation)
    // ========================================================================

    /**
     * Validate forum post title.
     */
    fun validateForumTitle(title: String): ValidationResult {
        val errors = mutableListOf<ValidationError>()
        val trimmed = title.trim()

        when {
            trimmed.isEmpty() -> errors.add(ValidationError.Custom("Title is required"))
            trimmed.length < MIN_FORUM_TITLE_LENGTH ->
                errors.add(ValidationError.Custom("Title must be at least $MIN_FORUM_TITLE_LENGTH characters"))
            trimmed.length > MAX_FORUM_TITLE_LENGTH ->
                errors.add(ValidationError.Custom("Title cannot exceed $MAX_FORUM_TITLE_LENGTH characters"))
        }

        return ValidationResult(isValid = errors.isEmpty(), errors = errors)
    }

    /**
     * Validate forum post content.
     */
    fun validateForumContent(content: String): ValidationResult {
        val errors = mutableListOf<ValidationError>()
        val trimmed = content.trim()

        when {
            trimmed.isEmpty() -> errors.add(ValidationError.Custom("Content is required"))
            trimmed.length < MIN_FORUM_CONTENT_LENGTH ->
                errors.add(ValidationError.Custom("Content must be at least $MIN_FORUM_CONTENT_LENGTH characters"))
            trimmed.length > MAX_FORUM_CONTENT_LENGTH ->
                errors.add(ValidationError.Custom("Content cannot exceed $MAX_FORUM_CONTENT_LENGTH characters"))
        }

        return ValidationResult(isValid = errors.isEmpty(), errors = errors)
    }

    // ========================================================================
    // Forum Sanitization (using generated sanitizers)
    // ========================================================================

    fun sanitizeForumTitle(title: String): String {
        return SwiftTextSanitizer.sanitize(SwiftInputSanitizer.stripHTML(title))
    }

    fun sanitizeForumContent(content: String): String {
        return SwiftTextSanitizer.sanitize(SwiftInputSanitizer.stripHTML(content))
    }

    // ========================================================================
    // Forum Comment Validation Constants (synced with Swift)
    // ========================================================================

    const val MIN_FORUM_COMMENT_LENGTH = 5
    const val MAX_FORUM_COMMENT_LENGTH = 5000
    const val MAX_COMMENT_DEPTH = 5

    // ========================================================================
    // Forum Comment Validation & Sanitization (local implementation)
    // ========================================================================

    fun validateForumComment(content: String): ValidationResult {
        val errors = mutableListOf<ValidationError>()
        val trimmed = content.trim()

        when {
            trimmed.isEmpty() -> errors.add(ValidationError.Custom("Comment is required"))
            trimmed.length < MIN_FORUM_COMMENT_LENGTH ->
                errors.add(ValidationError.Custom("Comment must be at least $MIN_FORUM_COMMENT_LENGTH characters"))
            trimmed.length > MAX_FORUM_COMMENT_LENGTH ->
                errors.add(ValidationError.Custom("Comment cannot exceed $MAX_FORUM_COMMENT_LENGTH characters"))
        }

        return ValidationResult(isValid = errors.isEmpty(), errors = errors)
    }

    fun sanitizeForumComment(content: String): String {
        return SwiftTextSanitizer.sanitize(SwiftInputSanitizer.stripHTML(content))
    }

    fun validateCommentDepth(depth: Int): Boolean {
        return depth in 0..MAX_COMMENT_DEPTH
    }

    // ========================================================================
    // Profile Sanitization (using generated sanitizers)
    // ========================================================================

    fun sanitizeBio(bio: String): String {
        return SwiftTextSanitizer.sanitize(SwiftInputSanitizer.stripHTML(bio))
    }

    fun sanitizeDisplayName(name: String): String {
        return SwiftTextSanitizer.sanitize(SwiftInputSanitizer.stripHTML(name))
    }

    // ========================================================================
    // Review Sanitization (using generated sanitizers)
    // ========================================================================

    fun sanitizeReviewComment(comment: String): String {
        return SwiftTextSanitizer.sanitize(SwiftInputSanitizer.stripHTML(comment))
    }

    // ========================================================================
    // Listing Sanitization (using generated sanitizers)
    // ========================================================================

    fun sanitizeListingTitle(title: String): String {
        return SwiftTextSanitizer.sanitize(SwiftInputSanitizer.stripHTML(title))
    }

    fun sanitizeListingDescription(description: String): String {
        return SwiftTextSanitizer.sanitize(SwiftInputSanitizer.stripHTML(description))
    }

    // ========================================================================
    // Generic Sanitization (using generated sanitizers)
    // ========================================================================

    fun sanitizeAndEscapeHTML(input: String): String {
        return SwiftInputSanitizer.escapeHTML(SwiftTextSanitizer.sanitize(input))
    }

    // ========================================================================
    // URL Validation (using generated InputSanitizer + local regex)
    // ========================================================================

    private val urlPattern = Regex(
        "^https?://[\\w\\-.]+(:\\d+)?(/[\\w\\-./?%&=+#]*)?$",
        RegexOption.IGNORE_CASE
    )

    private val imageExtensions = setOf("jpg", "jpeg", "png", "gif", "webp", "bmp", "svg")

    fun isValidURL(url: String): Boolean {
        return url.isNotBlank() && urlPattern.matches(url.trim())
    }

    fun isValidImageURL(url: String): Boolean {
        if (!isValidURL(url)) return false
        val lowercaseUrl = url.lowercase()
        return imageExtensions.any { lowercaseUrl.endsWith(".$it") }
    }

    fun sanitizeURL(url: String): String {
        return SwiftInputSanitizer.sanitizeURL(url).orElse(url.trim())
    }

    // ========================================================================
    // Filename Utilities (using generated InputSanitizer)
    // ========================================================================

    /**
     * Sanitize a filename using swift-java generated InputSanitizer.
     */
    fun sanitizeFilename(filename: String): String {
        return SwiftInputSanitizer.sanitizeFilename(filename)
    }

    /**
     * Generate a unique filename (local implementation using UUID).
     */
    fun generateUniqueFilename(originalFilename: String): String {
        val sanitized = sanitizeFilename(originalFilename)
        val uuid = UUID.randomUUID().toString().take(8)
        val extension = sanitized.substringAfterLast('.', "")
        val nameWithoutExt = sanitized.substringBeforeLast('.', sanitized)
        return if (extension.isNotEmpty()) {
            "${nameWithoutExt}_$uuid.$extension"
        } else {
            "${sanitized}_$uuid"
        }
    }

    // ========================================================================
    // Formatting Utilities (local implementation)
    // ========================================================================

    fun formatCompactNumber(count: Long): String {
        return when {
            count >= 1_000_000_000 -> String.format("%.1fB", count / 1_000_000_000.0)
            count >= 1_000_000 -> String.format("%.1fM", count / 1_000_000.0)
            count >= 1_000 -> String.format("%.1fK", count / 1_000.0)
            else -> count.toString()
        }
    }

    fun formatDuration(seconds: Long): String {
        val hours = seconds / 3600
        val minutes = (seconds % 3600) / 60
        val secs = seconds % 60

        return when {
            hours > 0 -> "${hours}h ${minutes}m"
            minutes > 0 -> "${minutes}m ${secs}s"
            else -> "${secs}s"
        }
    }

    fun formatDateShort(isoDate: String): String {
        return try {
            val instant = java.time.Instant.parse(isoDate)
            val formatter = java.time.format.DateTimeFormatter
                .ofPattern("MMM d")
                .withZone(java.time.ZoneId.systemDefault())
            formatter.format(instant)
        } catch (e: Exception) {
            isoDate
        }
    }

    fun formatDateFull(isoDate: String): String {
        return try {
            val instant = java.time.Instant.parse(isoDate)
            val formatter = java.time.format.DateTimeFormatter
                .ofPattern("MMMM d, yyyy")
                .withZone(java.time.ZoneId.systemDefault())
            formatter.format(instant)
        } catch (e: Exception) {
            isoDate
        }
    }

    fun formatDateAndTime(isoDate: String): String {
        return try {
            val instant = java.time.Instant.parse(isoDate)
            val formatter = java.time.format.DateTimeFormatter
                .ofPattern("MMM d, yyyy 'at' h:mm a")
                .withZone(java.time.ZoneId.systemDefault())
            formatter.format(instant)
        } catch (e: Exception) {
            isoDate
        }
    }

    // ========================================================================
    // Cross-Field Validation (using swift-java generated CrossFieldValidator)
    // ========================================================================

    fun validatePasswordMatch(password: String, confirmPassword: String): String? {
        return SwiftCrossFieldValidator.validatePasswordMatch(password, confirmPassword).orElse(null)
    }

    fun validateDateRange(startDateISO: String, endDateISO: String): String? {
        return SwiftCrossFieldValidator.validateDateRangeStrings(startDateISO, endDateISO).orElse(null)
    }

    fun validatePickupBeforeExpiration(pickupTime: String?, expirationDate: String?): String? {
        return SwiftCrossFieldValidator.validatePickupBeforeExpiration(
            Optional.ofNullable(pickupTime),
            Optional.ofNullable(expirationDate)
        ).orElse(null)
    }

    fun validateListingCrossFields(
        pickupTime: String?,
        expirationDate: String?,
        quantity: Int,
        maxQuantity: Int = 0
    ): CrossValidationResultKotlin {
        val errors = mutableListOf<String>()

        // Validate pickup before expiration
        validatePickupBeforeExpiration(pickupTime, expirationDate)?.let {
            errors.add(it)
        }

        // Validate quantity vs maxQuantity
        if (maxQuantity > 0 && quantity > maxQuantity) {
            errors.add("Quantity cannot exceed $maxQuantity")
        }

        return CrossValidationResultKotlin(
            isValid = errors.isEmpty(),
            errors = errors
        )
    }

    fun validateAuthCrossFields(
        email: String,
        password: String,
        confirmPassword: String?,
        isSignup: Boolean
    ): CrossValidationResultKotlin {
        val swiftResult = SwiftCrossFieldValidator.validateAuthCrossFields(
            email,
            password,
            Optional.ofNullable(confirmPassword),
            isSignup,
            arena
        )
        return CrossValidationResultKotlin(
            isValid = swiftResult.isValid(),
            errors = swiftResult.getErrors().toList()
        )
    }
}

/**
 * Password strength levels.
 */
enum class PasswordStrengthLevel {
    NONE,
    WEAK,
    MEDIUM,
    STRONG,
    VERY_STRONG;

    val displayText: String
        get() = when (this) {
            NONE -> ""
            WEAK -> "Weak"
            MEDIUM -> "Medium"
            STRONG -> "Strong"
            VERY_STRONG -> "Very Strong"
        }

    val color: Long
        get() = when (this) {
            NONE -> 0xFF9E9E9E  // Gray
            WEAK -> 0xFFF44336  // Red
            MEDIUM -> 0xFFFF9800  // Orange
            STRONG -> 0xFF4CAF50  // Green
            VERY_STRONG -> 0xFF2E7D32  // Dark Green
        }

    val progress: Float
        get() = when (this) {
            NONE -> 0f
            WEAK -> 0.25f
            MEDIUM -> 0.5f
            STRONG -> 0.75f
            VERY_STRONG -> 1f
        }

    companion object {
        /**
         * Convert from Swift PasswordStrength rawValue.
         * Swift enum: none=0, weak=1, medium=2, strong=3, veryStrong=4
         */
        fun fromSwiftValue(value: Int): PasswordStrengthLevel {
            return when (value) {
                0 -> NONE
                1 -> WEAK
                2 -> MEDIUM
                3 -> STRONG
                4 -> VERY_STRONG
                else -> NONE
            }
        }
    }
}

/**
 * Result of validation.
 */
data class ValidationResult(
    val isValid: Boolean,
    val errors: List<ValidationError>
) {
    val errorMessages: List<String>
        get() = errors.map { it.message }

    val firstError: String?
        get() = errors.firstOrNull()?.message

    companion object {
        val valid = ValidationResult(isValid = true, errors = emptyList())
    }
}

/**
 * Validation errors matching Swift ValidationError enum.
 */
sealed class ValidationError {
    abstract val message: String

    // Listing errors
    object TitleEmpty : ValidationError() {
        override val message = "Title is required"
    }

    data class TitleTooShort(val minLength: Int) : ValidationError() {
        override val message = "Title must be at least $minLength characters"
    }

    data class TitleTooLong(val maxLength: Int) : ValidationError() {
        override val message = "Title cannot exceed $maxLength characters"
    }

    object DescriptionEmpty : ValidationError() {
        override val message = "Description is required"
    }

    data class DescriptionTooLong(val maxLength: Int) : ValidationError() {
        override val message = "Description cannot exceed $maxLength characters"
    }

    object InvalidQuantity : ValidationError() {
        override val message = "Quantity must be at least 1"
    }

    object ExpirationInPast : ValidationError() {
        override val message = "Expiration date cannot be in the past"
    }

    data class ExpirationTooFarFuture(val maxDays: Int) : ValidationError() {
        override val message = "Expiration date cannot be more than $maxDays days from now"
    }

    // Profile errors
    data class NicknameTooShort(val minLength: Int) : ValidationError() {
        override val message = "Nickname must be at least $minLength characters"
    }

    data class NicknameTooLong(val maxLength: Int) : ValidationError() {
        override val message = "Nickname cannot exceed $maxLength characters"
    }

    data class BioTooLong(val maxLength: Int) : ValidationError() {
        override val message = "Bio cannot exceed $maxLength characters"
    }

    // Review errors
    data class InvalidRating(val minRating: Int, val maxRating: Int) : ValidationError() {
        override val message = "Rating must be between $minRating and $maxRating"
    }

    data class CommentTooLong(val maxLength: Int) : ValidationError() {
        override val message = "Comment cannot exceed $maxLength characters"
    }

    // Generic error from Swift
    data class Custom(override val message: String) : ValidationError()
}

/**
 * Cross-field validation result (Kotlin-native replacement for FoodshareCore type).
 */
data class CrossValidationResultKotlin(
    val isValid: Boolean,
    val errors: List<String>
) {
    val firstError: String?
        get() = errors.firstOrNull()

    companion object {
        val valid = CrossValidationResultKotlin(isValid = true, errors = emptyList())
    }
}
