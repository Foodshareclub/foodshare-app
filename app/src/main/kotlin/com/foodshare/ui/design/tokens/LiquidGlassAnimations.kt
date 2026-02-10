package com.foodshare.ui.design.tokens

import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween

/**
 * Liquid Glass Animation System
 *
 * Spring-based animations optimized for 120Hz displays
 * Matches iOS ProMotion animation characteristics
 */
object LiquidGlassAnimations {

    // MARK: - Spring Specs (matching iOS interpolatingSpring)

    /** Quick press animation - high stiffness, responsive */
    val quickPress = spring<Float>(
        dampingRatio = 0.75f,
        stiffness = Spring.StiffnessHigh
    )

    /** Card press animation - medium stiffness */
    val cardPress = spring<Float>(
        dampingRatio = 0.7f,
        stiffness = Spring.StiffnessMedium
    )

    /** Appear transition - smooth entrance */
    val appearTransition = spring<Float>(
        dampingRatio = 0.8f,
        stiffness = Spring.StiffnessMediumLow
    )

    /** Bouncy animation - for playful interactions */
    val bouncy = spring<Float>(
        dampingRatio = 0.6f,
        stiffness = Spring.StiffnessMedium
    )

    /** Smooth animation - for subtle transitions */
    val smooth = spring<Float>(
        dampingRatio = 0.85f,
        stiffness = Spring.StiffnessLow
    )

    /** Snappy animation - for quick feedback */
    val snappy = spring<Float>(
        dampingRatio = 0.9f,
        stiffness = Spring.StiffnessHigh
    )

    // MARK: - Tween Specs

    /** Fast fade animation */
    val fastFade = tween<Float>(durationMillis = 150)

    /** Standard transition */
    val standardTransition = tween<Float>(durationMillis = 300)

    /** Slow fade animation */
    val slowFade = tween<Float>(durationMillis = 500)

    // MARK: - Duration Constants (in milliseconds)

    object Duration {
        const val instant = 50
        const val fast = 150
        const val standard = 300
        const val slow = 500
        const val verySlow = 800
    }

    // MARK: - Scale Values

    object Scale {
        const val pressed = 0.96f
        const val cardPressed = 0.97f
        const val normal = 1.0f
        const val highlighted = 1.02f
        const val enlarged = 1.05f
    }

    // MARK: - Offset Values (in dp)

    object Offset {
        const val appearY = 20f
        const val slideX = 50f
        const val slideY = 30f
    }
}
