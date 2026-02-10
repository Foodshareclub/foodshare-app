package com.foodshare.core.moderation

import kotlinx.serialization.Serializable

/**
 * Content moderation logic.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for content moderation
 * - Pattern matching, profanity detection, spam detection are pure functions
 * - No JNI required for these stateless operations
 *
 * Features:
 * - Text content analysis with pattern matching
 * - Profanity and spam detection
 * - Content sanitization
 * - Severity-based decision making
 */
object ModerationBridge {

    // Profanity patterns (simplified set - production would use more comprehensive list)
    private val profanityPatterns = listOf(
        Regex("\\b(f+u+c+k+|sh+i+t+|a+s+s+h+o+l+e+|b+i+t+c+h+|d+a+m+n+)\\b", RegexOption.IGNORE_CASE),
        Regex("\\b(bastard|crap|dick|piss)\\b", RegexOption.IGNORE_CASE)
    )

    // Hate speech patterns
    private val hateSpeechPatterns = listOf(
        Regex("\\b(hate|kill|die|death to)\\s+(all\\s+)?(jews|muslims|christians|blacks|whites|gays|immigrants)\\b", RegexOption.IGNORE_CASE),
        Regex("\\b(n+i+g+g+e+r+|f+a+g+g+o+t+|k+i+k+e+|c+h+i+n+k+)\\b", RegexOption.IGNORE_CASE)
    )

    // Spam patterns
    private val spamPatterns = listOf(
        Regex("(click here|free money|winner|lottery|prize|urgent|act now)", RegexOption.IGNORE_CASE),
        Regex("\\$\\d+[,.]?\\d*\\s*(per|a)\\s*(day|hour|week)", RegexOption.IGNORE_CASE),
        Regex("(buy now|limited offer|call now|subscribe)", RegexOption.IGNORE_CASE),
        Regex("(.{1,3})\\1{4,}", RegexOption.IGNORE_CASE)  // Repeated characters
    )

    // Contact info patterns (PII)
    private val contactInfoPatterns = listOf(
        Regex("\\b\\d{3}[-.]?\\d{3}[-.]?\\d{4}\\b"),  // Phone numbers
        Regex("[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"),  // Email
        Regex("(whatsapp|telegram|signal|snapchat|instagram|facebook)[:\\s]*[@]?[a-zA-Z0-9._]+", RegexOption.IGNORE_CASE)
    )

    // Prohibited content patterns
    private val prohibitedPatterns = listOf(
        Regex("\\b(drugs|cocaine|heroin|meth|weed|marijuana)\\b", RegexOption.IGNORE_CASE),
        Regex("\\b(weapon|gun|firearm|knife|explosive)\\s*(for sale|selling|buy)", RegexOption.IGNORE_CASE),
        Regex("\\b(counterfeit|fake|replica)\\s*(money|bills|currency)", RegexOption.IGNORE_CASE)
    )

    // ========================================================================
    // Text Moderation
    // ========================================================================

    /**
     * Moderate text content fully.
     *
     * @param text Text to moderate
     * @param contentType Type of content
     * @return TextModerationResult with analysis details
     */
    fun moderateText(
        text: String,
        contentType: ModerationContentType = ModerationContentType.LISTING
    ): TextModerationBridgeResult {
        if (text.isBlank()) {
            return TextModerationBridgeResult.clean()
        }

        val flags = mutableListOf<ContentFlagResult>()
        val categories = mutableListOf<String>()

        // Check profanity
        profanityPatterns.forEach { pattern ->
            pattern.findAll(text).forEach { match ->
                flags.add(ContentFlagResult(
                    category = "profanity",
                    severity = 2,  // MEDIUM
                    description = "Profanity detected",
                    offset = match.range.first
                ))
                if (!categories.contains("profanity")) categories.add("profanity")
            }
        }

        // Check hate speech
        hateSpeechPatterns.forEach { pattern ->
            pattern.findAll(text).forEach { match ->
                flags.add(ContentFlagResult(
                    category = "hate_speech",
                    severity = 4,  // CRITICAL
                    description = "Hate speech detected",
                    offset = match.range.first
                ))
                if (!categories.contains("hate_speech")) categories.add("hate_speech")
            }
        }

        // Check spam
        spamPatterns.forEach { pattern ->
            pattern.findAll(text).forEach { match ->
                flags.add(ContentFlagResult(
                    category = "spam",
                    severity = 1,  // LOW
                    description = "Spam-like content detected",
                    offset = match.range.first
                ))
                if (!categories.contains("spam")) categories.add("spam")
            }
        }

        // Check contact info (PII)
        contactInfoPatterns.forEach { pattern ->
            pattern.findAll(text).forEach { match ->
                flags.add(ContentFlagResult(
                    category = "contact_info",
                    severity = 2,  // MEDIUM
                    description = "Contact information detected",
                    offset = match.range.first
                ))
                if (!categories.contains("contact_info")) categories.add("contact_info")
            }
        }

        // Check prohibited content
        prohibitedPatterns.forEach { pattern ->
            pattern.findAll(text).forEach { match ->
                flags.add(ContentFlagResult(
                    category = "prohibited",
                    severity = 4,  // CRITICAL
                    description = "Prohibited content detected",
                    offset = match.range.first
                ))
                if (!categories.contains("prohibited")) categories.add("prohibited")
            }
        }

        // Calculate overall severity
        val maxSeverity = flags.maxOfOrNull { it.severity } ?: 0

        // Apply content type modifiers
        val adjustedSeverity = when (contentType) {
            ModerationContentType.MESSAGE -> maxSeverity  // Messages are personal
            ModerationContentType.FORUM_POST, ModerationContentType.FORUM_COMMENT -> {
                // Public content - slightly stricter
                if (maxSeverity > 0) (maxSeverity + 1).coerceAtMost(4) else 0
            }
            else -> maxSeverity
        }

        // Sanitize text if needed
        val sanitizedText = if (flags.isNotEmpty()) sanitizeText(text) else null

        return TextModerationBridgeResult(
            isClean = flags.isEmpty(),
            severity = adjustedSeverity,
            categories = categories,
            flags = flags,
            sanitizedText = sanitizedText
        )
    }

    /**
     * Sanitize text by replacing flagged content.
     */
    private fun sanitizeText(text: String): String {
        var result = text

        // Replace profanity with asterisks
        profanityPatterns.forEach { pattern ->
            result = pattern.replace(result) { match ->
                "*".repeat(match.value.length)
            }
        }

        // Replace hate speech
        hateSpeechPatterns.forEach { pattern ->
            result = pattern.replace(result) { match ->
                "[removed]"
            }
        }

        // Mask contact info
        contactInfoPatterns.forEach { pattern ->
            result = pattern.replace(result) { match ->
                "[contact info removed]"
            }
        }

        return result
    }

    /**
     * Quick check if text is clean (fast path).
     *
     * @param text Text to check
     * @return QuickCheckBridgeResult with clean status and severity
     */
    fun quickTextCheck(text: String): QuickCheckBridgeResult {
        if (text.isBlank()) {
            return QuickCheckBridgeResult(isClean = true, severity = 0)
        }

        // Quick check - stop at first match for performance
        for (pattern in hateSpeechPatterns) {
            if (pattern.containsMatchIn(text)) {
                return QuickCheckBridgeResult(isClean = false, severity = 4)
            }
        }

        for (pattern in prohibitedPatterns) {
            if (pattern.containsMatchIn(text)) {
                return QuickCheckBridgeResult(isClean = false, severity = 4)
            }
        }

        for (pattern in profanityPatterns) {
            if (pattern.containsMatchIn(text)) {
                return QuickCheckBridgeResult(isClean = false, severity = 2)
            }
        }

        for (pattern in contactInfoPatterns) {
            if (pattern.containsMatchIn(text)) {
                return QuickCheckBridgeResult(isClean = false, severity = 2)
            }
        }

        for (pattern in spamPatterns) {
            if (pattern.containsMatchIn(text)) {
                return QuickCheckBridgeResult(isClean = false, severity = 1)
            }
        }

        return QuickCheckBridgeResult(isClean = true, severity = 0)
    }

    /**
     * Check if text is clean (fastest path).
     *
     * @param text Text to check
     * @return true if clean
     */
    fun isTextClean(text: String): Boolean {
        if (text.isBlank()) return true

        // Check patterns in order of severity (most severe first)
        val allPatterns = hateSpeechPatterns + prohibitedPatterns + profanityPatterns +
                         contactInfoPatterns + spamPatterns

        return allPatterns.none { it.containsMatchIn(text) }
    }

    /**
     * Get moderation decision for severity level.
     *
     * @param severity Severity level
     * @return ModerationDecision
     */
    fun getDecision(severity: ModerationSeverity): ModerationDecision {
        return when (severity) {
            ModerationSeverity.NONE -> ModerationDecision.APPROVE
            ModerationSeverity.LOW -> ModerationDecision.APPROVE_WITH_WARNING
            ModerationSeverity.MEDIUM -> ModerationDecision.APPROVE_WITH_WARNING
            ModerationSeverity.HIGH -> ModerationDecision.REQUIRE_REVIEW
            ModerationSeverity.CRITICAL -> ModerationDecision.AUTO_REJECT
        }
    }

    // ========================================================================
    // Pre-Submission Checks
    // ========================================================================

    /**
     * Check content before submission (pre-flight).
     *
     * @param title Optional title
     * @param description Optional description
     * @param content Optional content
     * @param contentType Type of content
     * @return PreSubmissionResult with approval status
     */
    fun checkBeforeSubmission(
        title: String? = null,
        description: String? = null,
        content: String? = null,
        contentType: ModerationContentType = ModerationContentType.LISTING
    ): PreSubmissionResult {
        val checks = mutableListOf<TextModerationBridgeResult>()

        title?.let { checks.add(moderateText(it, contentType)) }
        description?.let { checks.add(moderateText(it, contentType)) }
        content?.let { checks.add(moderateText(it, contentType)) }

        if (checks.isEmpty()) {
            return PreSubmissionResult(
                canSubmit = true,
                severity = ModerationSeverity.NONE,
                issues = emptyList(),
                sanitizedTitle = title,
                sanitizedDescription = description,
                sanitizedContent = content
            )
        }

        val maxSeverity = checks.maxOfOrNull { it.severity } ?: 0
        val severity = moderationSeverityFromOrdinal(maxSeverity)
        val decision = getDecision(severity)

        val issues = checks.flatMap { result ->
            result.flags.map { flag ->
                ModerationIssue(
                    category = flag.category,
                    description = flag.description,
                    severity = moderationSeverityFromOrdinal(flag.severity)
                )
            }
        }

        return PreSubmissionResult(
            canSubmit = decision == ModerationDecision.APPROVE ||
                       decision == ModerationDecision.APPROVE_WITH_WARNING,
            severity = severity,
            issues = issues,
            sanitizedTitle = checks.getOrNull(0)?.sanitizedText ?: title,
            sanitizedDescription = checks.getOrNull(1)?.sanitizedText ?: description,
            sanitizedContent = checks.getOrNull(2)?.sanitizedText ?: content
        )
    }
}

// ========================================================================
// Bridge-Specific Data Classes
// ========================================================================

/**
 * Result from text moderation (matches Swift output).
 */
@Serializable
data class TextModerationBridgeResult(
    val isClean: Boolean,
    val severity: Int = 0,
    val categories: List<String> = emptyList(),
    val flags: List<ContentFlagResult> = emptyList(),
    val sanitizedText: String? = null
) {
    companion object {
        fun clean() = TextModerationBridgeResult(isClean = true)
    }
}

/**
 * Content flag from moderation analysis.
 */
@Serializable
data class ContentFlagResult(
    val category: String,
    val severity: Int,
    val description: String,
    val offset: Int? = null
)

/**
 * Quick check result.
 */
@Serializable
data class QuickCheckBridgeResult(
    val isClean: Boolean,
    val severity: Int = 0
)

/**
 * Pre-submission check result.
 */
data class PreSubmissionResult(
    val canSubmit: Boolean,
    val severity: ModerationSeverity,
    val issues: List<ModerationIssue>,
    val sanitizedTitle: String?,
    val sanitizedDescription: String?,
    val sanitizedContent: String?
) {
    val hasIssues: Boolean
        get() = issues.isNotEmpty()

    val issueCount: Int
        get() = issues.size
}

/**
 * Individual moderation issue.
 */
data class ModerationIssue(
    val category: String,
    val description: String,
    val severity: ModerationSeverity
)

// ========================================================================
// Extension Functions
// ========================================================================

/** Quick moderation check for this string. */
fun String.moderationQuickCheck(): QuickCheckBridgeResult =
    ModerationBridge.quickTextCheck(this)

/** Check if this string is clean. */
fun String.isModerationClean(): Boolean =
    ModerationBridge.isTextClean(this)

/** Full moderation analysis for this string. */
fun String.moderate(contentType: ModerationContentType = ModerationContentType.LISTING): TextModerationBridgeResult =
    ModerationBridge.moderateText(this, contentType)
