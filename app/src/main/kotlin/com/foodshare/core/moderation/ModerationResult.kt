package com.foodshare.core.moderation

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Content moderation decision
 */
@Serializable
enum class ModerationDecision {
    @SerialName("approve")
    APPROVE,

    @SerialName("approve_with_warning")
    APPROVE_WITH_WARNING,

    @SerialName("require_review")
    REQUIRE_REVIEW,

    @SerialName("auto_reject")
    AUTO_REJECT,

    @SerialName("shadowban")
    SHADOWBAN
}

/**
 * Moderation action to take
 */
@Serializable
enum class ModerationAction {
    @SerialName("none")
    NONE,

    @SerialName("sanitize")
    SANITIZE,

    @SerialName("blur_image")
    BLUR_IMAGE,

    @SerialName("remove_pii")
    REMOVE_PII,

    @SerialName("flag_for_review")
    FLAG_FOR_REVIEW,

    @SerialName("reject")
    REJECT,

    @SerialName("suspend_user")
    SUSPEND_USER,

    @SerialName("notify_admins")
    NOTIFY_ADMINS
}

/**
 * Content type for moderation
 */
@Serializable
enum class ModerationContentType(val value: String) {
    @SerialName("listing")
    LISTING("listing"),

    @SerialName("message")
    MESSAGE("message"),

    @SerialName("review")
    REVIEW("review"),

    @SerialName("forum_post")
    FORUM_POST("forum_post"),

    @SerialName("forum_comment")
    FORUM_COMMENT("forum_comment"),

    @SerialName("profile")
    PROFILE("profile"),

    @SerialName("report")
    REPORT("report")
}

/**
 * Severity level
 */
@Serializable
enum class ModerationSeverity {
    @SerialName("none")
    NONE,

    @SerialName("low")
    LOW,

    @SerialName("medium")
    MEDIUM,

    @SerialName("high")
    HIGH,

    @SerialName("critical")
    CRITICAL
}

// Top-level function to get severity from ordinal
fun moderationSeverityFromOrdinal(ordinal: Int): ModerationSeverity {
    return ModerationSeverity.entries.getOrNull(ordinal) ?: ModerationSeverity.NONE
}

/**
 * Text moderation category
 */
@Serializable
enum class TextCategory {
    @SerialName("profanity")
    PROFANITY,

    @SerialName("hate_speech")
    HATE_SPEECH,

    @SerialName("harassment")
    HARASSMENT,

    @SerialName("spam")
    SPAM,

    @SerialName("pii")
    PII,

    @SerialName("contact_info")
    CONTACT_INFO,

    @SerialName("prohibited")
    PROHIBITED,

    @SerialName("safe")
    SAFE
}

/**
 * Image moderation category
 */
@Serializable
enum class ImageCategory {
    @SerialName("food")
    FOOD,

    @SerialName("non_food")
    NON_FOOD,

    @SerialName("nsfw")
    NSFW,

    @SerialName("violence")
    VIOLENCE,

    @SerialName("text_heavy")
    TEXT_HEAVY,

    @SerialName("low_quality")
    LOW_QUALITY,

    @SerialName("unknown")
    UNKNOWN
}

/**
 * Text analysis result from moderation
 */
@Serializable
data class TextAnalysisSummary(
    val isClean: Boolean,
    val severity: ModerationSeverity,
    val flagCount: Int,
    val sanitizedAvailable: Boolean
)

/**
 * Image analysis result from moderation
 */
@Serializable
data class ImageAnalysisSummary(
    val isAcceptable: Boolean,
    val category: ImageCategory,
    val flagCount: Int
)

/**
 * Moderation result details
 */
@Serializable
data class ModerationDetails(
    val textAnalysis: TextAnalysisSummary? = null,
    val imageAnalyses: List<ImageAnalysisSummary> = emptyList(),
    val overallSeverity: ModerationSeverity = ModerationSeverity.NONE
)

/**
 * Sanitized content after moderation
 */
@Serializable
data class SanitizedContent(
    val title: String? = null,
    val description: String? = null,
    val content: String? = null,
    val imagesRemoved: Int? = null,
    val fieldsModified: List<String> = emptyList()
)

/**
 * Full moderation result
 */
@Serializable
data class ModerationResult(
    val decision: ModerationDecision,
    val actions: List<ModerationAction>,
    val reason: String? = null,
    val message: String,
    val requiresReview: Boolean,
    val details: ModerationDetails? = null,
    val sanitizedContent: SanitizedContent? = null
) {
    /**
     * Check if content was approved
     */
    val isApproved: Boolean
        get() = decision == ModerationDecision.APPROVE ||
                decision == ModerationDecision.APPROVE_WITH_WARNING

    /**
     * Check if content was rejected
     */
    val isRejected: Boolean
        get() = decision == ModerationDecision.AUTO_REJECT

    /**
     * Check if content needs modification
     */
    val needsModification: Boolean
        get() = actions.any { it == ModerationAction.SANITIZE || it == ModerationAction.REMOVE_PII }

    /**
     * Check if there are image issues
     */
    val hasImageIssues: Boolean
        get() = actions.contains(ModerationAction.BLUR_IMAGE) ||
                details?.imageAnalyses?.any { !it.isAcceptable } == true

    /**
     * Get user-friendly status message
     */
    fun getStatusMessage(): String {
        return when (decision) {
            ModerationDecision.APPROVE -> "Your content has been published."
            ModerationDecision.APPROVE_WITH_WARNING -> "Your content has been published with some modifications."
            ModerationDecision.REQUIRE_REVIEW -> "Your content is being reviewed and will be published shortly."
            ModerationDecision.AUTO_REJECT -> "Your content could not be published as it violates our community guidelines."
            ModerationDecision.SHADOWBAN -> "Your content has been submitted for review."
        }
    }
}

/**
 * Text moderation request
 */
@Serializable
data class TextModerationRequest(
    val text: String,
    val contentType: ModerationContentType,
    val userId: String? = null,
    val quick: Boolean = false
)

/**
 * Image moderation request
 */
@Serializable
data class ImageModerationRequest(
    val imageUrl: String? = null,
    val imageBase64: String? = null,
    val contentType: ModerationContentType,
    val userId: String? = null,
    val quick: Boolean = false
)

/**
 * Full content moderation request
 */
@Serializable
data class ContentModerationRequest(
    val contentType: ModerationContentType,
    val contentId: String? = null,
    val userId: String? = null,
    val title: String? = null,
    val description: String? = null,
    val content: String? = null,
    val imageUrls: List<String>? = null
)

/**
 * Content report request
 */
@Serializable
data class ContentReportRequest(
    val contentType: ModerationContentType,
    val contentId: String,
    val reporterId: String,
    val reason: ReportReason,
    val details: String? = null
)

/**
 * Report reasons
 */
@Serializable
enum class ReportReason {
    @SerialName("hate_speech")
    HATE_SPEECH,

    @SerialName("harassment")
    HARASSMENT,

    @SerialName("violence")
    VIOLENCE,

    @SerialName("nsfw")
    NSFW,

    @SerialName("fraud")
    FRAUD,

    @SerialName("spam")
    SPAM,

    @SerialName("inappropriate")
    INAPPROPRIATE,

    @SerialName("other")
    OTHER
}

/**
 * Report submission response
 */
@Serializable
data class ReportResponse(
    val success: Boolean,
    val reportId: String? = null,
    val message: String
)

/**
 * Moderation status check response
 */
@Serializable
data class ModerationStatus(
    val contentId: String,
    val decision: ModerationDecision? = null,
    val status: String,
    val createdAt: String? = null,
    val updatedAt: String? = null
)

/**
 * Quick text check result
 */
@Serializable
data class QuickTextCheckResult(
    val isClean: Boolean,
    val severity: ModerationSeverity,
    val quick: Boolean = true
)

/**
 * Quick image check result
 */
@Serializable
data class QuickImageCheckResult(
    val acceptable: Boolean,
    val reason: String? = null,
    val quick: Boolean = true
)
