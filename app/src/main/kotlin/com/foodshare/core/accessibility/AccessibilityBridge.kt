package com.foodshare.core.accessibility

import android.content.Context
import android.view.View
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import androidx.compose.ui.semantics.SemanticsPropertyKey
import androidx.compose.ui.semantics.SemanticsPropertyReceiver
import androidx.core.view.AccessibilityDelegateCompat
import androidx.core.view.ViewCompat
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.serialization.Serializable
import java.util.UUID
import kotlin.math.pow

/**
 * Accessibility helpers for screen readers and WCAG compliance.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for label generation, announcements, focus management
 * - Contrast calculation using W3C formulas
 * - No JNI required for these stateless operations
 *
 * Features:
 * - Accessibility label generation for listings, users, messages
 * - Screen reader announcements with priority
 * - Focus group and trap management
 * - WCAG contrast ratio checking
 * - Color blindness simulation
 */
object AccessibilityBridge {

    private var accessibilityManager: AccessibilityManager? = null

    private val _announcementFlow = MutableStateFlow<Announcement?>(null)
    val announcementFlow: StateFlow<Announcement?> = _announcementFlow

    /**
     * Initialize with application context
     */
    fun initialize(context: Context) {
        accessibilityManager = context.getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
    }

    /**
     * Check if accessibility services are enabled
     */
    val isAccessibilityEnabled: Boolean
        get() = accessibilityManager?.isEnabled == true

    /**
     * Check if TalkBack is enabled
     */
    val isTalkBackEnabled: Boolean
        get() = accessibilityManager?.isTouchExplorationEnabled == true

    // MARK: - Labels

    /**
     * Get accessibility label for a food listing
     */
    fun getListingLabel(
        title: String,
        quantity: Int,
        distance: Double? = null,
        expiresIn: String? = null,
        isFavorite: Boolean = false
    ): AccessibilityElement {
        val parts = mutableListOf<String>()
        parts.add(title)

        if (quantity > 1) {
            parts.add("$quantity items")
        }

        distance?.let { d ->
            if (d >= 0) {
                val distanceStr = if (d < 1) {
                    "${(d * 1000).toInt()} meters away"
                } else {
                    "%.1f km away".format(d)
                }
                parts.add(distanceStr)
            }
        }

        expiresIn?.let { parts.add("expires $it") }

        val label = parts.joinToString(", ")
        val hint = if (isFavorite) "Double tap to view. In your favorites." else "Double tap to view details"

        return AccessibilityElement(
            identifier = "listing",
            label = label,
            hint = hint,
            isAccessibilityElement = true,
            actions = listOf("activate", if (isFavorite) "unfavorite" else "favorite")
        )
    }

    /**
     * Get accessibility label for a user profile
     */
    fun getUserLabel(
        displayName: String,
        rating: Double? = null,
        reviewCount: Int = 0,
        listingsCount: Int = 0,
        isVerified: Boolean = false
    ): AccessibilityElement {
        val parts = mutableListOf<String>()
        parts.add(displayName)

        if (isVerified) {
            parts.add("Verified")
        }

        rating?.let { r ->
            if (r >= 0) {
                parts.add("${"%.1f".format(r)} stars")
                if (reviewCount > 0) {
                    parts.add("$reviewCount ${if (reviewCount == 1) "review" else "reviews"}")
                }
            }
        }

        if (listingsCount > 0) {
            parts.add("$listingsCount ${if (listingsCount == 1) "listing" else "listings"}")
        }

        return AccessibilityElement(
            identifier = "user_profile",
            label = parts.joinToString(", "),
            hint = "Double tap to view profile",
            isAccessibilityElement = true,
            actions = listOf("activate", "message")
        )
    }

    /**
     * Get accessibility label for a chat message
     */
    fun getChatMessageLabel(
        content: String,
        senderName: String,
        timestamp: String,
        isOwnMessage: Boolean,
        isRead: Boolean
    ): AccessibilityElement {
        val sender = if (isOwnMessage) "You" else senderName
        val readStatus = if (!isOwnMessage) "" else if (isRead) ", read" else ", delivered"
        val label = "$sender: $content, $timestamp$readStatus"

        return AccessibilityElement(
            identifier = "chat_message",
            label = label,
            hint = if (isOwnMessage) "Your message" else "Message from $senderName",
            isAccessibilityElement = true,
            actions = listOf("copy", "reply")
        )
    }

    /**
     * Get accessibility label for badge
     */
    fun getBadgeLabel(count: Int, type: String): String {
        return when {
            count == 0 -> "No $type"
            count == 1 -> "1 $type"
            count > 99 -> "More than 99 $type"
            else -> "$count $type"
        }
    }

    // MARK: - Announcements

    /**
     * Make a screen reader announcement
     */
    fun announce(
        message: String,
        priority: AnnouncementPriority = AnnouncementPriority.DEFAULT
    ) {
        val announcement = createAnnouncement(message, priority, AnnouncementType.INFORMATION)
        _announcementFlow.value = announcement

        // Also announce via Android accessibility
        accessibilityManager?.let { manager ->
            if (manager.isEnabled) {
                val event = AccessibilityEvent.obtain(AccessibilityEvent.TYPE_ANNOUNCEMENT)
                event.text.add(message)
                manager.sendAccessibilityEvent(event)
            }
        }
    }

    /**
     * Announce a standard message
     */
    fun announceStandard(key: StandardAnnouncementKey, param: String? = null) {
        val message = getStandardAnnouncementMessage(key, param)
        val announcement = Announcement(
            id = UUID.randomUUID().toString(),
            message = message,
            priority = "default",
            type = "information",
            delay = 0.0
        )
        _announcementFlow.value = announcement

        accessibilityManager?.let { manager ->
            if (manager.isEnabled) {
                val event = AccessibilityEvent.obtain(AccessibilityEvent.TYPE_ANNOUNCEMENT)
                event.text.add(announcement.message)
                manager.sendAccessibilityEvent(event)
            }
        }
    }

    private fun getStandardAnnouncementMessage(key: StandardAnnouncementKey, param: String?): String {
        return when (key) {
            StandardAnnouncementKey.LOADING -> "Loading"
            StandardAnnouncementKey.LOADING_COMPLETE -> "Loading complete"
            StandardAnnouncementKey.REFRESHING -> "Refreshing"
            StandardAnnouncementKey.REFRESH_COMPLETE -> "Refresh complete"
            StandardAnnouncementKey.NO_RESULTS -> "No results found"
            StandardAnnouncementKey.NO_MORE_ITEMS -> "No more items"
            StandardAnnouncementKey.ITEM_ADDED -> param?.let { "$it added" } ?: "Item added"
            StandardAnnouncementKey.ITEM_REMOVED -> param?.let { "$it removed" } ?: "Item removed"
            StandardAnnouncementKey.FAVORITE_ADDED -> "Added to favorites"
            StandardAnnouncementKey.FAVORITE_REMOVED -> "Removed from favorites"
            StandardAnnouncementKey.MESSAGE_SENT -> "Message sent"
            StandardAnnouncementKey.LISTING_CREATED -> "Listing created"
            StandardAnnouncementKey.LISTING_UPDATED -> "Listing updated"
            StandardAnnouncementKey.LISTING_DELETED -> "Listing deleted"
            StandardAnnouncementKey.PROFILE_UPDATED -> "Profile updated"
            StandardAnnouncementKey.NETWORK_ERROR -> "Network error"
            StandardAnnouncementKey.ONLINE -> "You are back online"
            StandardAnnouncementKey.OFFLINE -> "You are offline"
            StandardAnnouncementKey.SYNC_COMPLETE -> "Sync complete"
            StandardAnnouncementKey.SCREEN_CHANGED -> param?.let { "Navigated to $it" } ?: "Screen changed"
            StandardAnnouncementKey.TAB_SELECTED -> param?.let { "$it tab selected" } ?: "Tab selected"
            StandardAnnouncementKey.MODAL_OPENED -> param?.let { "$it opened" } ?: "Dialog opened"
            StandardAnnouncementKey.MODAL_CLOSED -> "Dialog closed"
            StandardAnnouncementKey.NEW_MESSAGE -> param?.let { "New message from $it" } ?: "New message"
            StandardAnnouncementKey.ERROR -> param ?: "An error occurred"
        }
    }

    /**
     * Create an announcement
     */
    fun createAnnouncement(
        message: String,
        priority: AnnouncementPriority = AnnouncementPriority.DEFAULT,
        type: AnnouncementType = AnnouncementType.INFORMATION,
        delaySeconds: Double = 0.0
    ): Announcement {
        return Announcement(
            id = UUID.randomUUID().toString(),
            message = message,
            priority = priority.swiftValue,
            type = type.swiftValue,
            delay = delaySeconds
        )
    }

    // MARK: - Focus Management

    /**
     * Create a focus group
     */
    fun createFocusGroup(
        id: String,
        elements: List<String>,
        isCircular: Boolean = false,
        escapeAction: String? = null
    ): FocusGroup {
        return FocusGroup(
            id = id,
            elements = elements,
            isCircular = isCircular,
            escapeAction = escapeAction ?: ""
        )
    }

    /**
     * Create a focus request
     */
    fun createFocusRequest(
        targetElement: String? = null,
        targetGroup: String? = null,
        direction: FocusDirection? = null,
        shouldAnnounce: Boolean = true,
        delaySeconds: Double = 0.0
    ): FocusRequest {
        return FocusRequest(
            targetElement = targetElement,
            targetGroup = targetGroup,
            direction = direction?.swiftValue,
            shouldAnnounce = shouldAnnounce,
            delay = delaySeconds
        )
    }

    /**
     * Create a focus trap for modals
     */
    fun createFocusTrap(
        id: String,
        elements: List<String>,
        initialFocus: String? = null,
        returnFocus: String? = null
    ): FocusTrap {
        return FocusTrap(
            id = id,
            elements = elements,
            initialFocus = initialFocus,
            returnFocus = returnFocus
        )
    }

    /**
     * Get focus hint
     */
    fun getFocusHint(key: FocusHintKey): String {
        return when (key) {
            FocusHintKey.SWIPE_TO_NAVIGATE -> "Swipe left or right to navigate"
            FocusHintKey.DOUBLE_TAP_TO_ACTIVATE -> "Double tap to activate"
            FocusHintKey.DOUBLE_TAP_TO_EDIT -> "Double tap to edit"
            FocusHintKey.DOUBLE_TAP_TO_OPEN -> "Double tap to open"
            FocusHintKey.DOUBLE_TAP_TO_CLOSE -> "Double tap to close"
            FocusHintKey.DOUBLE_TAP_AND_HOLD -> "Double tap and hold for more options"
            FocusHintKey.SCROLLABLE_LIST -> "Scrollable list"
            FocusHintKey.PULL_TO_REFRESH -> "Pull down to refresh"
            FocusHintKey.LOAD_MORE -> "Scroll to load more"
            FocusHintKey.REQUIRED -> "Required field"
            FocusHintKey.OPTIONAL -> "Optional field"
            FocusHintKey.HAS_ERROR -> "Has validation error"
            FocusHintKey.ADJUSTABLE -> "Swipe up or down to adjust"
            FocusHintKey.PICKER -> "Double tap to select from options"
            FocusHintKey.SLIDER -> "Swipe up or down to adjust value"
        }
    }

    // MARK: - Contrast Checking

    /**
     * Check color contrast using W3C WCAG formula
     */
    fun checkContrast(
        foregroundHex: String,
        backgroundHex: String,
        textSize: TextSize = TextSize.NORMAL
    ): ContrastResult {
        val fgLuminance = calculateRelativeLuminance(foregroundHex)
        val bgLuminance = calculateRelativeLuminance(backgroundHex)

        val lighter = maxOf(fgLuminance, bgLuminance)
        val darker = minOf(fgLuminance, bgLuminance)
        val ratio = (lighter + 0.05) / (darker + 0.05)

        val isLargeText = textSize == TextSize.LARGE
        val passesAA = if (isLargeText) ratio >= 3.0 else ratio >= 4.5
        val passesAAA = if (isLargeText) ratio >= 4.5 else ratio >= 7.0

        val level = when {
            passesAAA -> "AAA"
            passesAA -> "AA"
            ratio >= 3.0 -> "Large text only"
            else -> "Fail"
        }

        val recommendations = mutableListOf<String>()
        if (!passesAA) {
            val neededRatio = if (isLargeText) 3.0 else 4.5
            recommendations.add("Increase contrast ratio to at least $neededRatio:1 for $textSize text")
        }

        return ContrastResult(
            ratio = ratio,
            formattedRatio = "%.2f:1".format(ratio),
            passesAA = passesAA,
            passesAAA = passesAAA,
            level = level,
            recommendations = recommendations
        )
    }

    /**
     * Calculate relative luminance per WCAG 2.1
     */
    private fun calculateRelativeLuminance(hex: String): Double {
        val rgb = parseHexColor(hex)

        fun sRGBToLinear(value: Int): Double {
            val s = value / 255.0
            return if (s <= 0.03928) s / 12.92 else ((s + 0.055) / 1.055).pow(2.4)
        }

        val r = sRGBToLinear(rgb.first)
        val g = sRGBToLinear(rgb.second)
        val b = sRGBToLinear(rgb.third)

        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /**
     * Parse hex color to RGB triple
     */
    private fun parseHexColor(hex: String): Triple<Int, Int, Int> {
        val cleanHex = hex.removePrefix("#")
        return when (cleanHex.length) {
            3 -> Triple(
                cleanHex[0].toString().repeat(2).toInt(16),
                cleanHex[1].toString().repeat(2).toInt(16),
                cleanHex[2].toString().repeat(2).toInt(16)
            )
            6 -> Triple(
                cleanHex.substring(0, 2).toInt(16),
                cleanHex.substring(2, 4).toInt(16),
                cleanHex.substring(4, 6).toInt(16)
            )
            else -> Triple(0, 0, 0)
        }
    }

    /**
     * Suggest a compliant foreground color
     */
    fun suggestForegroundColor(
        backgroundHex: String,
        targetRatio: Double = 4.5,
        preferLight: Boolean? = null
    ): SuggestedColor {
        val bgLuminance = calculateRelativeLuminance(backgroundHex)

        // Determine if we should use light or dark foreground
        val useLightFg = preferLight ?: (bgLuminance < 0.5)

        if (useLightFg) {
            // Start with white and darken if needed
            return SuggestedColor(hex = "#FFFFFF", red = 1.0, green = 1.0, blue = 1.0)
        } else {
            // Start with black and lighten if needed
            return SuggestedColor(hex = "#000000", red = 0.0, green = 0.0, blue = 0.0)
        }
    }

    /**
     * Simulate color blindness using approximate transformation matrices
     */
    fun simulateColorBlindness(
        colorHex: String,
        type: ColorBlindnessType
    ): ColorBlindnessSimulation {
        val rgb = parseHexColor(colorHex)
        val r = rgb.first / 255.0
        val g = rgb.second / 255.0
        val b = rgb.third / 255.0

        val (sr, sg, sb) = when (type) {
            ColorBlindnessType.PROTANOPIA -> Triple(
                0.567 * r + 0.433 * g + 0.0 * b,
                0.558 * r + 0.442 * g + 0.0 * b,
                0.0 * r + 0.242 * g + 0.758 * b
            )
            ColorBlindnessType.DEUTERANOPIA -> Triple(
                0.625 * r + 0.375 * g + 0.0 * b,
                0.7 * r + 0.3 * g + 0.0 * b,
                0.0 * r + 0.3 * g + 0.7 * b
            )
            ColorBlindnessType.TRITANOPIA -> Triple(
                0.95 * r + 0.05 * g + 0.0 * b,
                0.0 * r + 0.433 * g + 0.567 * b,
                0.0 * r + 0.475 * g + 0.525 * b
            )
            ColorBlindnessType.ACHROMATOPSIA -> {
                val gray = 0.299 * r + 0.587 * g + 0.114 * b
                Triple(gray, gray, gray)
            }
        }

        val simulatedHex = "#%02X%02X%02X".format(
            (sr.coerceIn(0.0, 1.0) * 255).toInt(),
            (sg.coerceIn(0.0, 1.0) * 255).toInt(),
            (sb.coerceIn(0.0, 1.0) * 255).toInt()
        )

        return ColorBlindnessSimulation(
            originalHex = colorHex,
            simulatedHex = simulatedHex,
            type = type.swiftValue
        )
    }

    /**
     * Get recommended text color for background
     */
    fun getTextColorForBackground(backgroundHex: String): String {
        val luminance = calculateRelativeLuminance(backgroundHex)
        return if (luminance > 0.179) "#000000" else "#FFFFFF"
    }

    // MARK: - View Extensions

    /**
     * Apply accessibility properties to a View
     */
    fun View.applyAccessibility(element: AccessibilityElement) {
        contentDescription = element.label

        if (element.hint.isNotEmpty()) {
            ViewCompat.setAccessibilityDelegate(this, object : AccessibilityDelegateCompat() {
                override fun onInitializeAccessibilityNodeInfo(
                    host: View,
                    info: AccessibilityNodeInfoCompat
                ) {
                    super.onInitializeAccessibilityNodeInfo(host, info)
                    info.hintText = element.hint
                }
            })
        }

        importantForAccessibility = if (element.isAccessibilityElement) {
            View.IMPORTANT_FOR_ACCESSIBILITY_YES
        } else {
            View.IMPORTANT_FOR_ACCESSIBILITY_NO
        }
    }
}

// MARK: - Data Classes

@Serializable
data class AccessibilityElement(
    val identifier: String = "",
    val label: String = "",
    val hint: String = "",
    val value: String = "",
    val traits: Int = 0,
    val isAccessibilityElement: Boolean = true,
    val actions: List<String> = emptyList(),
    val customActions: List<String> = emptyList()
)

@Serializable
data class Announcement(
    val id: String = "",
    val message: String = "",
    val priority: String = "default",
    val type: String = "information",
    val delay: Double = 0.0
)

@Serializable
data class FocusGroup(
    val id: String = "",
    val elements: List<String> = emptyList(),
    val isCircular: Boolean = false,
    val escapeAction: String = ""
)

@Serializable
data class FocusRequest(
    val targetElement: String? = null,
    val targetGroup: String? = null,
    val direction: String? = null,
    val shouldAnnounce: Boolean = true,
    val delay: Double = 0.0
)

@Serializable
data class FocusTrap(
    val id: String = "",
    val elements: List<String> = emptyList(),
    val initialFocus: String? = null,
    val returnFocus: String? = null
)

@Serializable
data class ContrastResult(
    val ratio: Double = 0.0,
    val formattedRatio: String = "",
    val passesAA: Boolean = false,
    val passesAAA: Boolean = false,
    val level: String = "",
    val recommendations: List<String> = emptyList()
)

@Serializable
data class SuggestedColor(
    val hex: String = "",
    val red: Double = 0.0,
    val green: Double = 0.0,
    val blue: Double = 0.0
)

@Serializable
data class ColorBlindnessSimulation(
    val originalHex: String = "",
    val simulatedHex: String = "",
    val type: String = ""
)

// MARK: - Enums

enum class AnnouncementPriority(val swiftValue: String) {
    LOW("low"),
    DEFAULT("default"),
    HIGH("high"),
    ASSERTIVE("assertive")
}

enum class AnnouncementType(val swiftValue: String) {
    INFORMATION("information"),
    SUCCESS("success"),
    WARNING("warning"),
    ERROR("error"),
    PROGRESS("progress"),
    NAVIGATION("navigation"),
    ACTION("action"),
    UPDATE("update")
}

enum class FocusDirection(val swiftValue: String) {
    NEXT("next"),
    PREVIOUS("previous"),
    UP("up"),
    DOWN("down"),
    LEFT("left"),
    RIGHT("right"),
    FIRST("first"),
    LAST("last")
}

enum class TextSize(val swiftValue: String) {
    NORMAL("normal"),
    LARGE("large")
}

enum class ColorBlindnessType(val swiftValue: String) {
    PROTANOPIA("protanopia"),
    DEUTERANOPIA("deuteranopia"),
    TRITANOPIA("tritanopia"),
    ACHROMATOPSIA("achromatopsia")
}

enum class StandardAnnouncementKey(val swiftKey: String) {
    LOADING("loading"),
    LOADING_COMPLETE("loadingComplete"),
    REFRESHING("refreshing"),
    REFRESH_COMPLETE("refreshComplete"),
    NO_RESULTS("noResults"),
    NO_MORE_ITEMS("noMoreItems"),
    ITEM_ADDED("itemAdded"),
    ITEM_REMOVED("itemRemoved"),
    FAVORITE_ADDED("favoriteAdded"),
    FAVORITE_REMOVED("favoriteRemoved"),
    MESSAGE_SENT("messageSent"),
    LISTING_CREATED("listingCreated"),
    LISTING_UPDATED("listingUpdated"),
    LISTING_DELETED("listingDeleted"),
    PROFILE_UPDATED("profileUpdated"),
    NETWORK_ERROR("networkError"),
    ONLINE("online"),
    OFFLINE("offline"),
    SYNC_COMPLETE("syncComplete"),
    SCREEN_CHANGED("screenChanged"),
    TAB_SELECTED("tabSelected"),
    MODAL_OPENED("modalOpened"),
    MODAL_CLOSED("modalClosed"),
    NEW_MESSAGE("newMessage"),
    ERROR("error")
}

enum class FocusHintKey(val swiftKey: String) {
    SWIPE_TO_NAVIGATE("swipeToNavigate"),
    DOUBLE_TAP_TO_ACTIVATE("doubleTapToActivate"),
    DOUBLE_TAP_TO_EDIT("doubleTapToEdit"),
    DOUBLE_TAP_TO_OPEN("doubleTapToOpen"),
    DOUBLE_TAP_TO_CLOSE("doubleTapToClose"),
    DOUBLE_TAP_AND_HOLD("doubleTapAndHold"),
    SCROLLABLE_LIST("scrollableList"),
    PULL_TO_REFRESH("pullToRefresh"),
    LOAD_MORE("loadMore"),
    REQUIRED("required"),
    OPTIONAL("optional"),
    HAS_ERROR("hasError"),
    ADJUSTABLE("adjustable"),
    PICKER("picker"),
    SLIDER("slider")
}

// MARK: - Compose Extensions

/**
 * Custom semantics property for accessibility hints
 */
val AccessibilityHint = SemanticsPropertyKey<String>("AccessibilityHint")
var SemanticsPropertyReceiver.accessibilityHint by AccessibilityHint

/**
 * Custom semantics property for custom actions
 */
val CustomAccessibilityActions = SemanticsPropertyKey<List<String>>("CustomAccessibilityActions")
var SemanticsPropertyReceiver.customAccessibilityActions by CustomAccessibilityActions

// MARK: - Localized Labels

object LocalizedAccessibilityLabels {
    // Common actions
    const val CLOSE = "Close"
    const val BACK = "Back"
    const val CANCEL = "Cancel"
    const val DONE = "Done"
    const val SAVE = "Save"
    const val DELETE = "Delete"
    const val EDIT = "Edit"
    const val SHARE = "Share"
    const val REFRESH = "Refresh"
    const val SEARCH = "Search"
    const val FILTER = "Filter"
    const val SORT = "Sort"
    const val MORE = "More options"

    // Navigation
    const val FEED_TAB = "Feed"
    const val SEARCH_TAB = "Search"
    const val CREATE_TAB = "Create listing"
    const val MESSAGES_TAB = "Messages"
    const val PROFILE_TAB = "Profile"

    // States
    const val LOADING = "Loading"
    const val LOADING_MORE = "Loading more items"
    const val NO_RESULTS = "No results found"
    const val ERROR = "An error occurred"
    const val OFFLINE = "You are offline"

    // Listings
    const val FAVORITE = "Add to favorites"
    const val UNFAVORITE = "Remove from favorites"
    const val CONTACT_SELLER = "Contact seller"
    const val VIEW_ON_MAP = "View on map"
    const val REPORT_LISTING = "Report listing"

    // User
    const val VIEW_PROFILE = "View profile"
    const val SEND_MESSAGE = "Send message"
    const val WRITE_REVIEW = "Write a review"
}

// =============================================================================
// MARK: - Accessibility Audit (Phase 19)
// =============================================================================

/**
 * Accessibility auditing for WCAG compliance.
 *
 * Architecture (Frameo pattern):
 * - Local Kotlin implementations for auditing logic
 * - WCAG 2.1 guidelines built-in
 * - No JNI required for these stateless operations
 */
object AccessibilityAuditBridge {

    // ========================================================================
    // Screen Auditing
    // ========================================================================

    /**
     * Perform a full accessibility audit on a screen.
     */
    fun auditScreen(
        elements: List<AuditElement>,
        screenName: String,
        level: WCAGComplianceLevel = WCAGComplianceLevel.AA
    ): AccessibilityAuditResult {
        val allIssues = mutableListOf<AccessibilityIssue>()

        for (element in elements) {
            allIssues.addAll(auditElement(element, level))
        }

        val criticalCount = allIssues.count { it.severity == AuditIssueSeverity.CRITICAL }
        val majorCount = allIssues.count { it.severity == AuditIssueSeverity.MAJOR }
        val minorCount = allIssues.count { it.severity == AuditIssueSeverity.MINOR }

        val score = calculateScore(allIssues, elements.size)
        val passed = criticalCount == 0 && majorCount == 0

        return AccessibilityAuditResult(
            screenName = screenName,
            passed = passed,
            score = score,
            issues = allIssues,
            criticalCount = criticalCount,
            majorCount = majorCount,
            minorCount = minorCount,
            auditedElementCount = elements.size,
            wcagLevel = level
        )
    }

    /**
     * Audit a single element.
     */
    fun auditElement(
        element: AuditElement,
        level: WCAGComplianceLevel = WCAGComplianceLevel.AA
    ): List<AccessibilityIssue> {
        val issues = mutableListOf<AccessibilityIssue>()

        // Check content description
        if (element.isInteractive && element.contentDescription.isNullOrBlank() && element.isDecorative != true) {
            issues.add(AccessibilityIssue(
                elementId = element.id,
                rule = AuditRule.MISSING_CONTENT_DESCRIPTION,
                severity = AuditIssueSeverity.CRITICAL,
                wcagCriteria = "1.1.1",
                message = "Interactive element missing content description",
                suggestion = "Add a contentDescription that describes the element's purpose"
            ))
        }

        // Check for unhelpful descriptions
        val unhelpfulDescriptions = listOf("button", "image", "click here", "tap", "icon")
        if (element.contentDescription?.lowercase() in unhelpfulDescriptions) {
            issues.add(AccessibilityIssue(
                elementId = element.id,
                rule = AuditRule.UNHELPFUL_CONTENT_DESCRIPTION,
                severity = AuditIssueSeverity.MAJOR,
                wcagCriteria = "1.1.1",
                message = "Content description is not descriptive",
                suggestion = "Provide a meaningful description of the element's purpose or action"
            ))
        }

        // Check touch target size
        if (element.isInteractive && element.width != null && element.height != null) {
            if (!checkTouchTargetSize(element.width, element.height, level)) {
                issues.add(AccessibilityIssue(
                    elementId = element.id,
                    rule = AuditRule.INSUFFICIENT_TOUCH_TARGET,
                    severity = AuditIssueSeverity.MAJOR,
                    wcagCriteria = "2.5.5",
                    message = "Touch target size too small",
                    suggestion = "Increase touch target to at least ${getMinimumTouchTargetSize(level)}dp"
                ))
            }
        }

        // Check contrast
        if (element.contrastRatio != null && element.hasText) {
            val isLargeText = (element.fontSize ?: 0.0) >= 18 || ((element.fontSize ?: 0.0) >= 14 && element.isBoldText == true)
            if (!checkContrastRatio(element.contrastRatio, isLargeText, level)) {
                issues.add(AccessibilityIssue(
                    elementId = element.id,
                    rule = AuditRule.INSUFFICIENT_CONTRAST,
                    severity = AuditIssueSeverity.MAJOR,
                    wcagCriteria = "1.4.3",
                    message = "Insufficient color contrast",
                    suggestion = "Increase contrast ratio to at least ${getMinimumContrastRatio(isLargeText, level)}:1"
                ))
            }
        }

        // Check text scaling support
        if (element.hasText && element.supportsTextScaling == false) {
            issues.add(AccessibilityIssue(
                elementId = element.id,
                rule = AuditRule.TEXT_SCALING_UNSUPPORTED,
                severity = AuditIssueSeverity.MAJOR,
                wcagCriteria = "1.4.4",
                message = "Text does not support scaling",
                suggestion = "Use scalable text units (sp) instead of fixed units (dp/px)"
            ))
        }

        // Check focus indicator
        if (element.isInteractive && element.hasFocusIndicator == false) {
            issues.add(AccessibilityIssue(
                elementId = element.id,
                rule = AuditRule.MISSING_FOCUS_INDICATOR,
                severity = AuditIssueSeverity.MAJOR,
                wcagCriteria = "2.4.7",
                message = "Missing focus indicator",
                suggestion = "Add a visible focus state for keyboard/accessibility navigation"
            ))
        }

        // Check image alt text
        if (element.role == AuditElementRole.IMAGE && element.contentDescription.isNullOrBlank() && element.isDecorative != true) {
            issues.add(AccessibilityIssue(
                elementId = element.id,
                rule = AuditRule.MISSING_IMAGE_ALT_TEXT,
                severity = AuditIssueSeverity.CRITICAL,
                wcagCriteria = "1.1.1",
                message = "Image missing alternative text",
                suggestion = "Add contentDescription or mark as decorative"
            ))
        }

        return issues
    }

    // ========================================================================
    // Dynamic Type / Text Scaling
    // ========================================================================

    /**
     * Validate dynamic type/text scaling support.
     */
    fun validateDynamicType(
        elements: List<DynamicTypeElementData>,
        scaleFactor: Double
    ): DynamicTypeValidation {
        val issues = mutableListOf<DynamicTypeIssueData>()

        for (element in elements) {
            if (element.isTruncatedAtScale) {
                issues.add(DynamicTypeIssueData(
                    elementId = element.id,
                    issue = DynamicTypeIssueKind.TEXT_TRUNCATION,
                    scaleFactor = scaleFactor,
                    message = "Text is truncated at ${scaleFactor}x scale",
                    suggestion = "Allow text to wrap or expand container"
                ))
            }
            if (element.hasOverlap) {
                issues.add(DynamicTypeIssueData(
                    elementId = element.id,
                    issue = DynamicTypeIssueKind.LAYOUT_OVERLAP,
                    scaleFactor = scaleFactor,
                    message = "Element overlaps with other content at ${scaleFactor}x scale",
                    suggestion = "Use flexible layouts that adapt to content size"
                ))
            }
            if (element.isOffScreen) {
                issues.add(DynamicTypeIssueData(
                    elementId = element.id,
                    issue = DynamicTypeIssueKind.CONTENT_OFF_SCREEN,
                    scaleFactor = scaleFactor,
                    message = "Content goes off-screen at ${scaleFactor}x scale",
                    suggestion = "Ensure content remains accessible with scrolling"
                ))
            }
            if (element.hasFixedHeight) {
                issues.add(DynamicTypeIssueData(
                    elementId = element.id,
                    issue = DynamicTypeIssueKind.FIXED_HEIGHT_CONTAINER,
                    scaleFactor = scaleFactor,
                    message = "Container has fixed height that clips text at ${scaleFactor}x scale",
                    suggestion = "Use wrap_content or minimum height instead of fixed"
                ))
            }
        }

        val score = if (elements.isEmpty()) 100.0 else (1.0 - issues.size.toDouble() / elements.size) * 100
        val passed = issues.isEmpty()

        return DynamicTypeValidation(
            passed = passed,
            score = score.coerceIn(0.0, 100.0),
            testedScaleFactor = scaleFactor,
            issues = issues
        )
    }

    // ========================================================================
    // Individual Checks
    // ========================================================================

    /**
     * Check if color contrast is sufficient.
     */
    fun checkContrastRatio(
        contrastRatio: Double,
        isLargeText: Boolean = false,
        level: WCAGComplianceLevel = WCAGComplianceLevel.AA
    ): Boolean {
        val required = getMinimumContrastRatio(isLargeText, level)
        return contrastRatio >= required
    }

    /**
     * Check if touch target size is sufficient.
     */
    fun checkTouchTargetSize(
        width: Double,
        height: Double,
        level: WCAGComplianceLevel = WCAGComplianceLevel.AA
    ): Boolean {
        val minSize = getMinimumTouchTargetSize(level)
        return width >= minSize && height >= minSize
    }

    /**
     * Calculate accessibility score from issues.
     */
    fun calculateScore(
        issues: List<AccessibilityIssue>,
        elementCount: Int
    ): Double {
        if (elementCount == 0) return 100.0

        // Weight by severity
        val penaltyPoints = issues.sumOf { issue ->
            when (issue.severity) {
                AuditIssueSeverity.CRITICAL -> 30.0
                AuditIssueSeverity.MAJOR -> 15.0
                AuditIssueSeverity.MINOR -> 5.0
            }
        }

        val maxPenalty = elementCount * 30.0 // All critical
        val score = 100.0 - (penaltyPoints / maxPenalty * 100.0)
        return score.coerceIn(0.0, 100.0)
    }

    // ========================================================================
    // Convenience Methods
    // ========================================================================

    /**
     * Get minimum touch target size for WCAG level.
     */
    fun getMinimumTouchTargetSize(level: WCAGComplianceLevel): Int {
        return when (level) {
            WCAGComplianceLevel.A, WCAGComplianceLevel.AA -> 24
            WCAGComplianceLevel.AAA -> 44
        }
    }

    /**
     * Get minimum contrast ratio for text.
     */
    fun getMinimumContrastRatio(
        isLargeText: Boolean,
        level: WCAGComplianceLevel
    ): Double {
        return when (level) {
            WCAGComplianceLevel.A, WCAGComplianceLevel.AA ->
                if (isLargeText) 3.0 else 4.5
            WCAGComplianceLevel.AAA ->
                if (isLargeText) 4.5 else 7.0
        }
    }
}

// =============================================================================
// MARK: - Audit Data Classes
// =============================================================================

@Serializable
enum class WCAGComplianceLevel(val value: String) {
    @kotlinx.serialization.SerialName("A") A("A"),
    @kotlinx.serialization.SerialName("AA") AA("AA"),
    @kotlinx.serialization.SerialName("AAA") AAA("AAA")
}

@Serializable
enum class AuditElementRole(val value: String) {
    @kotlinx.serialization.SerialName("button") BUTTON("button"),
    @kotlinx.serialization.SerialName("link") LINK("link"),
    @kotlinx.serialization.SerialName("textField") TEXT_FIELD("textField"),
    @kotlinx.serialization.SerialName("image") IMAGE("image"),
    @kotlinx.serialization.SerialName("heading") HEADING("heading"),
    @kotlinx.serialization.SerialName("text") TEXT("text"),
    @kotlinx.serialization.SerialName("container") CONTAINER("container"),
    @kotlinx.serialization.SerialName("list") LIST("list"),
    @kotlinx.serialization.SerialName("listItem") LIST_ITEM("listItem"),
    @kotlinx.serialization.SerialName("checkbox") CHECKBOX("checkbox"),
    @kotlinx.serialization.SerialName("radioButton") RADIO_BUTTON("radioButton"),
    @kotlinx.serialization.SerialName("slider") SLIDER("slider"),
    @kotlinx.serialization.SerialName("switch") SWITCH("switch"),
    @kotlinx.serialization.SerialName("tab") TAB("tab"),
    @kotlinx.serialization.SerialName("menu") MENU("menu"),
    @kotlinx.serialization.SerialName("menuItem") MENU_ITEM("menuItem"),
    @kotlinx.serialization.SerialName("dialog") DIALOG("dialog"),
    @kotlinx.serialization.SerialName("alert") ALERT("alert"),
    @kotlinx.serialization.SerialName("progressBar") PROGRESS_BAR("progressBar"),
    @kotlinx.serialization.SerialName("unknown") UNKNOWN("unknown")
}

@Serializable
data class AuditElement(
    val id: String,
    val role: AuditElementRole,
    val contentDescription: String? = null,
    val isInteractive: Boolean = false,
    val width: Double? = null,
    val height: Double? = null,
    val contrastRatio: Double? = null,
    val hasText: Boolean = false,
    val fontSize: Double? = null,
    val isBoldText: Boolean? = null,
    val supportsTextScaling: Boolean? = null,
    val hasFocusIndicator: Boolean? = null,
    val headingLevel: Int? = null,
    val isDecorative: Boolean? = null
)

@Serializable
enum class AuditIssueSeverity {
    @kotlinx.serialization.SerialName("critical") CRITICAL,
    @kotlinx.serialization.SerialName("major") MAJOR,
    @kotlinx.serialization.SerialName("minor") MINOR
}

@Serializable
enum class AuditRule(val value: String) {
    @kotlinx.serialization.SerialName("missing_content_description") MISSING_CONTENT_DESCRIPTION("missing_content_description"),
    @kotlinx.serialization.SerialName("unhelpful_content_description") UNHELPFUL_CONTENT_DESCRIPTION("unhelpful_content_description"),
    @kotlinx.serialization.SerialName("insufficient_touch_target") INSUFFICIENT_TOUCH_TARGET("insufficient_touch_target"),
    @kotlinx.serialization.SerialName("insufficient_contrast") INSUFFICIENT_CONTRAST("insufficient_contrast"),
    @kotlinx.serialization.SerialName("text_scaling_unsupported") TEXT_SCALING_UNSUPPORTED("text_scaling_unsupported"),
    @kotlinx.serialization.SerialName("text_too_small") TEXT_TOO_SMALL("text_too_small"),
    @kotlinx.serialization.SerialName("missing_focus_indicator") MISSING_FOCUS_INDICATOR("missing_focus_indicator"),
    @kotlinx.serialization.SerialName("missing_heading_level") MISSING_HEADING_LEVEL("missing_heading_level"),
    @kotlinx.serialization.SerialName("missing_image_alt_text") MISSING_IMAGE_ALT_TEXT("missing_image_alt_text"),
    @kotlinx.serialization.SerialName("missing_heading") MISSING_HEADING("missing_heading")
}

@Serializable
data class AccessibilityIssue(
    val elementId: String,
    val rule: AuditRule,
    val severity: AuditIssueSeverity,
    val wcagCriteria: String,
    val message: String,
    val suggestion: String,
    val affectedProperty: String? = null
)

@Serializable
data class AccessibilityAuditResult(
    val screenName: String,
    val passed: Boolean,
    val score: Double,
    val issues: List<AccessibilityIssue> = emptyList(),
    val criticalCount: Int = 0,
    val majorCount: Int = 0,
    val minorCount: Int = 0,
    val auditedElementCount: Int = 0,
    val wcagLevel: WCAGComplianceLevel = WCAGComplianceLevel.AA,
    val timestamp: Long = System.currentTimeMillis(),
    val error: String? = null
) {
    val hasCriticalIssues: Boolean get() = criticalCount > 0
    val summary: String
        get() = if (passed) {
            "Accessibility audit passed with score ${score.toInt()}"
        } else {
            "$criticalCount critical, $majorCount major, $minorCount minor issues found"
        }
}

@Serializable
data class DynamicTypeElementData(
    val id: String,
    val isTruncatedAtScale: Boolean = false,
    val hasOverlap: Boolean = false,
    val isOffScreen: Boolean = false,
    val hasFixedHeight: Boolean = false
)

@Serializable
enum class DynamicTypeIssueKind(val value: String) {
    @kotlinx.serialization.SerialName("text_truncation") TEXT_TRUNCATION("text_truncation"),
    @kotlinx.serialization.SerialName("layout_overlap") LAYOUT_OVERLAP("layout_overlap"),
    @kotlinx.serialization.SerialName("content_off_screen") CONTENT_OFF_SCREEN("content_off_screen"),
    @kotlinx.serialization.SerialName("fixed_height_container") FIXED_HEIGHT_CONTAINER("fixed_height_container")
}

@Serializable
data class DynamicTypeIssueData(
    val elementId: String,
    val issue: DynamicTypeIssueKind,
    val scaleFactor: Double,
    val message: String,
    val suggestion: String
)

@Serializable
data class DynamicTypeValidation(
    val passed: Boolean,
    val score: Double,
    val testedScaleFactor: Double,
    val issues: List<DynamicTypeIssueData> = emptyList()
)
