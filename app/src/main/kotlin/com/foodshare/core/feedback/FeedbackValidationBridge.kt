package com.foodshare.core.feedback

import kotlinx.serialization.Serializable

/**
 * Feedback validation bridge.
 *
 * Architecture (Frameo pattern):
 * - Pure Kotlin implementation mirroring Swift FeedbackValidator
 * - Ensures cross-platform validation consistency
 * - Ready for swift-java migration when bindings are regenerated
 *
 * Swift source: foodshare-core/Sources/FoodshareCore/Validation/FeedbackValidator.swift
 */
object FeedbackValidationBridge {

    // ========================================================================
    // Configuration (synced with Swift FeedbackValidator)
    // ========================================================================

    const val MIN_FEEDBACK_LENGTH = 10
    const val MAX_FEEDBACK_LENGTH = 5000
    const val MIN_SUBJECT_LENGTH = 3
    const val MAX_SUBJECT_LENGTH = 200
    val VALID_RATINGS = 1..5

    // Email regex pattern
    private val EMAIL_REGEX = Regex("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$")

    // ========================================================================
    // Feedback Validation
    // ========================================================================

    /**
     * Validate feedback submission.
     *
     * @param type Feedback type
     * @param subject Optional subject
     * @param message Feedback message
     * @param rating Optional rating (1-5)
     * @param email Optional contact email
     * @return Validation result
     */
    fun validateFeedback(
        type: FeedbackType,
        subject: String?,
        message: String,
        rating: Int? = null,
        email: String? = null
    ): FeedbackValidationResult {
        val errors = mutableListOf<FeedbackValidationError>()

        // Validate subject if provided
        subject?.let { subj ->
            validateSubject(subj)?.let { errors.add(it) }
        }

        // Validate message
        validateMessage(message)?.let { errors.add(it) }

        // Validate rating if provided
        rating?.let { r ->
            validateRating(r)?.let { errors.add(it) }
        }

        // Validate email if provided
        email?.takeIf { it.isNotEmpty() }?.let { e ->
            validateEmail(e)?.let { errors.add(it) }
        }

        return FeedbackValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            feedbackType = type
        )
    }

    /**
     * Validate subject.
     *
     * @param subject The subject to validate
     * @return Error if invalid, null if valid
     */
    fun validateSubject(subject: String): FeedbackValidationError? {
        val trimmed = subject.trim()

        return when {
            trimmed.length < MIN_SUBJECT_LENGTH -> FeedbackValidationError(
                field = "subject",
                code = "too_short",
                message = "Subject must be at least $MIN_SUBJECT_LENGTH characters"
            )
            trimmed.length > MAX_SUBJECT_LENGTH -> FeedbackValidationError(
                field = "subject",
                code = "too_long",
                message = "Subject cannot exceed $MAX_SUBJECT_LENGTH characters"
            )
            else -> null
        }
    }

    /**
     * Validate message.
     *
     * @param message The message to validate
     * @return Error if invalid, null if valid
     */
    fun validateMessage(message: String): FeedbackValidationError? {
        val trimmed = message.trim()

        return when {
            trimmed.isEmpty() -> FeedbackValidationError(
                field = "message",
                code = "required",
                message = "Message is required"
            )
            trimmed.length < MIN_FEEDBACK_LENGTH -> FeedbackValidationError(
                field = "message",
                code = "too_short",
                message = "Message must be at least $MIN_FEEDBACK_LENGTH characters"
            )
            trimmed.length > MAX_FEEDBACK_LENGTH -> FeedbackValidationError(
                field = "message",
                code = "too_long",
                message = "Message cannot exceed $MAX_FEEDBACK_LENGTH characters"
            )
            else -> null
        }
    }

    /**
     * Validate rating (1-5).
     *
     * @param rating The rating to validate
     * @return Error if invalid, null if valid
     */
    fun validateRating(rating: Int): FeedbackValidationError? {
        return if (rating !in VALID_RATINGS) {
            FeedbackValidationError(
                field = "rating",
                code = "invalid",
                message = "Rating must be between ${VALID_RATINGS.first} and ${VALID_RATINGS.last}"
            )
        } else {
            null
        }
    }

    /**
     * Validate email.
     *
     * @param email The email to validate
     * @return Error if invalid, null if valid
     */
    fun validateEmail(email: String): FeedbackValidationError? {
        val trimmed = email.trim()

        return if (!EMAIL_REGEX.matches(trimmed)) {
            FeedbackValidationError(
                field = "email",
                code = "invalid",
                message = "Please enter a valid email address"
            )
        } else {
            null
        }
    }

    // ========================================================================
    // Bug Report Validation
    // ========================================================================

    /**
     * Validate a bug report.
     *
     * @param title Bug report title
     * @param description Bug description
     * @param stepsToReproduce Optional steps to reproduce
     * @param expectedBehavior Optional expected behavior
     * @param actualBehavior Optional actual behavior
     * @return Validation result
     */
    fun validateBugReport(
        title: String,
        description: String,
        stepsToReproduce: String? = null,
        expectedBehavior: String? = null,
        actualBehavior: String? = null
    ): FeedbackValidationResult {
        val errors = mutableListOf<FeedbackValidationError>()

        // Validate title
        validateSubject(title)?.let { errors.add(it) }

        // Validate description
        validateMessage(description)?.let { errors.add(it) }

        return FeedbackValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            feedbackType = FeedbackType.BUG_REPORT
        )
    }

    // ========================================================================
    // Feature Request Validation
    // ========================================================================

    /**
     * Validate a feature request.
     *
     * @param title Feature title
     * @param description Feature description
     * @param useCase Optional use case
     * @return Validation result
     */
    fun validateFeatureRequest(
        title: String,
        description: String,
        useCase: String? = null
    ): FeedbackValidationResult {
        val errors = mutableListOf<FeedbackValidationError>()

        // Validate title
        validateSubject(title)?.let { errors.add(it) }

        // Validate description
        validateMessage(description)?.let { errors.add(it) }

        return FeedbackValidationResult(
            isValid = errors.isEmpty(),
            errors = errors,
            feedbackType = FeedbackType.FEATURE_REQUEST
        )
    }
}

// ========================================================================
// Data Classes
// ========================================================================

/**
 * Type of feedback.
 */
@Serializable
enum class FeedbackType(val displayName: String) {
    GENERAL("General Feedback"),
    BUG_REPORT("Bug Report"),
    FEATURE_REQUEST("Feature Request"),
    SUPPORT("Support Request"),
    COMPLAINT("Complaint"),
    PRAISE("Praise")
}

/**
 * Feedback validation result.
 */
@Serializable
data class FeedbackValidationResult(
    val isValid: Boolean,
    val errors: List<FeedbackValidationError>,
    val feedbackType: FeedbackType
) {
    val firstError: FeedbackValidationError?
        get() = errors.firstOrNull()

    fun errorFor(field: String): FeedbackValidationError? =
        errors.find { it.field == field }
}

/**
 * Feedback validation error.
 */
@Serializable
data class FeedbackValidationError(
    val field: String,
    val code: String,
    val message: String
)
