package com.foodshare.ui.components

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.onClick
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import com.foodshare.core.accessibility.AccessibilityAuditBridge
import com.foodshare.core.accessibility.AccessibilityBridge
import com.foodshare.core.accessibility.AccessibilityElement
import com.foodshare.core.accessibility.ContrastResult
import com.foodshare.core.accessibility.AuditElement
import com.foodshare.core.accessibility.AuditElementRole
import com.foodshare.core.accessibility.WCAGComplianceLevel

/**
 * Compose Modifier extensions for accessibility integration with Swift FoodshareCore.
 *
 * These modifiers connect Jetpack Compose accessibility semantics with the
 * unified Swift accessibility logic shared across iOS and Android.
 */

// =============================================================================
// MARK: - Label Modifiers
// =============================================================================

/**
 * Apply Swift-generated accessibility label for a food listing.
 */
fun Modifier.listingAccessibility(
    title: String,
    quantity: Int,
    distance: Double? = null,
    expiresIn: String? = null,
    isFavorite: Boolean = false
): Modifier = composed {
    val element = remember(title, quantity, distance, expiresIn, isFavorite) {
        AccessibilityBridge.getListingLabel(title, quantity, distance, expiresIn, isFavorite)
    }
    this.then(
        Modifier.semantics {
            contentDescription = element.label
            if (element.hint.isNotEmpty()) {
                stateDescription = element.hint
            }
        }
    )
}

/**
 * Apply Swift-generated accessibility label for a user profile.
 */
fun Modifier.userAccessibility(
    displayName: String,
    rating: Double? = null,
    reviewCount: Int = 0,
    listingsCount: Int = 0,
    isVerified: Boolean = false
): Modifier = composed {
    val element = remember(displayName, rating, reviewCount, listingsCount, isVerified) {
        AccessibilityBridge.getUserLabel(displayName, rating, reviewCount, listingsCount, isVerified)
    }
    this.then(
        Modifier.semantics {
            contentDescription = element.label
            if (element.hint.isNotEmpty()) {
                stateDescription = element.hint
            }
        }
    )
}

/**
 * Apply Swift-generated accessibility label for a chat message.
 */
fun Modifier.chatMessageAccessibility(
    content: String,
    senderName: String,
    timestamp: String,
    isOwnMessage: Boolean,
    isRead: Boolean
): Modifier = composed {
    val element = remember(content, senderName, timestamp, isOwnMessage, isRead) {
        AccessibilityBridge.getChatMessageLabel(content, senderName, timestamp, isOwnMessage, isRead)
    }
    this.then(
        Modifier.semantics {
            contentDescription = element.label
            if (element.hint.isNotEmpty()) {
                stateDescription = element.hint
            }
        }
    )
}

/**
 * Apply a Swift AccessibilityElement to a Compose modifier.
 */
fun Modifier.swiftAccessibility(element: AccessibilityElement): Modifier = composed {
    this.then(
        Modifier.semantics {
            contentDescription = element.label
            if (element.hint.isNotEmpty()) {
                stateDescription = element.hint
            }
        }
    )
}

// =============================================================================
// MARK: - Heading Modifier
// =============================================================================

/**
 * Mark a composable as a heading for accessibility navigation.
 */
fun Modifier.accessibilityHeading(
    label: String,
    level: Int = 1
): Modifier = composed {
    this.then(
        Modifier.semantics {
            heading()
            contentDescription = label
        }
    )
}

// =============================================================================
// MARK: - Interactive Element Modifiers
// =============================================================================

/**
 * Apply accessibility for a button with Swift-consistent hint.
 */
fun Modifier.buttonAccessibility(
    label: String,
    hint: String? = null,
    onClickLabel: String? = null
): Modifier = composed {
    val swiftHint = hint ?: AccessibilityBridge.getFocusHint(
        com.foodshare.core.accessibility.FocusHintKey.DOUBLE_TAP_TO_ACTIVATE
    )
    this.then(
        Modifier.semantics {
            contentDescription = label
            stateDescription = swiftHint
            if (onClickLabel != null) {
                onClick(label = onClickLabel) { false }
            }
        }
    )
}

/**
 * Apply accessibility for an editable field.
 */
fun Modifier.editableAccessibility(
    label: String,
    isRequired: Boolean = false,
    hasError: Boolean = false,
    errorMessage: String? = null
): Modifier = composed {
    val hintKey = when {
        hasError -> com.foodshare.core.accessibility.FocusHintKey.HAS_ERROR
        isRequired -> com.foodshare.core.accessibility.FocusHintKey.REQUIRED
        else -> com.foodshare.core.accessibility.FocusHintKey.DOUBLE_TAP_TO_EDIT
    }
    val hint = AccessibilityBridge.getFocusHint(hintKey)

    this.then(
        Modifier.semantics {
            contentDescription = if (hasError && errorMessage != null) {
                "$label, error: $errorMessage"
            } else {
                label
            }
            stateDescription = hint
        }
    )
}

// =============================================================================
// MARK: - Touch Target Enforcement
// =============================================================================

/**
 * Ensure minimum touch target size per WCAG guidelines.
 * Default is 48dp (Material Design), WCAG AAA recommends 44dp minimum.
 */
fun Modifier.ensureMinTouchTarget(
    minSize: Dp = 48.dp,
    wcagLevel: WCAGComplianceLevel = WCAGComplianceLevel.AA
): Modifier = composed {
    val minSizeForLevel = when (wcagLevel) {
        WCAGComplianceLevel.A, WCAGComplianceLevel.AA -> 24.dp
        WCAGComplianceLevel.AAA -> 44.dp
    }
    val effectiveMinSize = maxOf(minSize, minSizeForLevel)
    this.then(Modifier.size(effectiveMinSize))
}

// =============================================================================
// MARK: - Contrast Checking Modifier
// =============================================================================

/**
 * Debug modifier that visually indicates contrast issues.
 * Only enabled in debug builds.
 */
fun Modifier.checkContrast(
    foregroundHex: String,
    backgroundHex: String,
    isLargeText: Boolean = false,
    showOverlay: Boolean = false
): Modifier = composed {
    if (!showOverlay) return@composed this

    val result = remember(foregroundHex, backgroundHex, isLargeText) {
        AccessibilityBridge.checkContrast(
            foregroundHex,
            backgroundHex,
            if (isLargeText) com.foodshare.core.accessibility.TextSize.LARGE
            else com.foodshare.core.accessibility.TextSize.NORMAL
        )
    }

    val borderColor = when {
        result.passesAAA -> Color.Green.copy(alpha = 0.5f)
        result.passesAA -> Color.Yellow.copy(alpha = 0.5f)
        else -> Color.Red.copy(alpha = 0.8f)
    }

    this.then(
        if (!result.passesAA) {
            Modifier.border(BorderStroke(2.dp, borderColor))
        } else {
            Modifier
        }
    )
}

// =============================================================================
// MARK: - Audit Composables
// =============================================================================

/**
 * Data class to hold audit element information from a Composable.
 */
data class AuditableElement(
    val id: String,
    val role: AuditElementRole,
    val contentDescription: String?,
    val isInteractive: Boolean,
    val width: Float,
    val height: Float,
    val contrastRatio: Double? = null,
    val hasText: Boolean = false,
    val fontSize: Float? = null,
    val isBoldText: Boolean = false,
    val supportsTextScaling: Boolean = true
)

/**
 * Collect accessibility information from a Composable for auditing.
 */
fun Modifier.collectForAudit(
    id: String,
    role: AuditElementRole,
    contentDescription: String? = null,
    isInteractive: Boolean = false,
    hasText: Boolean = false,
    fontSize: Float? = null,
    isBoldText: Boolean = false,
    onCollect: (AuditableElement) -> Unit
): Modifier = composed {
    var size by remember { mutableStateOf(IntSize.Zero) }
    val density = LocalDensity.current

    LaunchedEffect(size) {
        if (size.width > 0 && size.height > 0) {
            val widthDp = with(density) { size.width.toDp().value }
            val heightDp = with(density) { size.height.toDp().value }

            onCollect(
                AuditableElement(
                    id = id,
                    role = role,
                    contentDescription = contentDescription,
                    isInteractive = isInteractive,
                    width = widthDp,
                    height = heightDp,
                    hasText = hasText,
                    fontSize = fontSize,
                    isBoldText = isBoldText
                )
            )
        }
    }

    this.then(
        Modifier.onGloballyPositioned { coordinates ->
            size = coordinates.size
        }
    )
}

/**
 * Convert AuditableElement to Swift-compatible AuditElement.
 */
fun AuditableElement.toAuditElement(): AuditElement {
    return AuditElement(
        id = id,
        role = role,
        contentDescription = contentDescription,
        isInteractive = isInteractive,
        width = width.toDouble(),
        height = height.toDouble(),
        hasText = hasText,
        fontSize = fontSize?.toDouble(),
        isBoldText = isBoldText,
        supportsTextScaling = supportsTextScaling
    )
}

// =============================================================================
// MARK: - Visibility Modifier for Screen Readers
// =============================================================================

/**
 * Hide an element from screen readers (decorative content).
 */
fun Modifier.accessibilityHidden(): Modifier = composed {
    this.then(
        Modifier.clearAndSetSemantics { }
    )
}

/**
 * Mark content as decorative (hidden from screen readers).
 */
fun Modifier.decorative(): Modifier = accessibilityHidden()

// =============================================================================
// MARK: - Focus Indicator Modifier
// =============================================================================

/**
 * Add a visible focus indicator for keyboard/switch navigation.
 */
fun Modifier.focusIndicator(
    isFocused: Boolean,
    color: Color = Color(0xFF1976D2),
    width: Dp = 2.dp
): Modifier = composed {
    if (isFocused) {
        this.then(
            Modifier
                .border(BorderStroke(width, color))
                .padding(width)
        )
    } else {
        this
    }
}

// =============================================================================
// MARK: - Debug Overlay
// =============================================================================

/**
 * Debug overlay showing accessibility information.
 * Only use in debug builds.
 */
fun Modifier.accessibilityDebugOverlay(
    showTouchTargets: Boolean = true,
    showContrastIssues: Boolean = true,
    minTouchTargetDp: Float = 48f
): Modifier = composed {
    var size by remember { mutableStateOf(IntSize.Zero) }
    val density = LocalDensity.current

    val widthDp = with(density) { size.width.toDp().value }
    val heightDp = with(density) { size.height.toDp().value }

    val isTouchTargetTooSmall = showTouchTargets &&
        (widthDp < minTouchTargetDp || heightDp < minTouchTargetDp)

    this
        .onGloballyPositioned { coordinates ->
            size = coordinates.size
        }
        .then(
            if (isTouchTargetTooSmall) {
                Modifier.drawBehind {
                    // Draw diagonal red line to indicate undersized touch target
                    drawLine(
                        color = Color.Red.copy(alpha = 0.7f),
                        start = Offset.Zero,
                        end = Offset(this.size.width, this.size.height),
                        strokeWidth = 4f
                    )
                    drawLine(
                        color = Color.Red.copy(alpha = 0.7f),
                        start = Offset(this.size.width, 0f),
                        end = Offset(0f, this.size.height),
                        strokeWidth = 4f
                    )
                }
            } else {
                Modifier
            }
        )
}
