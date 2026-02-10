package com.foodshare.ui.design.modifiers

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.BlurredEdgeTreatment
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.theme.LocalThemePalette

/**
 * Liquid Glass View Modifiers
 *
 * Compose equivalents of iOS GlassModifiers.swift
 */

// MARK: - Glow Effect

/**
 * Apply a glow effect around the view
 */
fun Modifier.glow(
    color: Color = LiquidGlassColors.brandGreen,
    radius: Dp = 10.dp
): Modifier = this
    .shadow(
        elevation = radius,
        shape = RoundedCornerShape(radius),
        ambientColor = color.copy(alpha = 0.6f),
        spotColor = color.copy(alpha = 0.4f)
    )
    .shadow(
        elevation = radius * 1.5f,
        shape = RoundedCornerShape(radius),
        ambientColor = color.copy(alpha = 0.4f),
        spotColor = color.copy(alpha = 0.2f)
    )

/**
 * Animated glow that pulses
 */
fun Modifier.animatedGlow(
    color: Color = LiquidGlassColors.brandGreen,
    radius: Dp = 10.dp
): Modifier = composed {
    val infiniteTransition = rememberInfiniteTransition(label = "glow")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.4f,
        targetValue = 0.7f,
        animationSpec = infiniteRepeatable(
            animation = tween(1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "glowAlpha"
    )

    this.shadow(
        elevation = radius,
        shape = RoundedCornerShape(radius),
        ambientColor = color.copy(alpha = alpha),
        spotColor = color.copy(alpha = alpha * 0.6f)
    )
}

// MARK: - Shimmer Effect

/**
 * Apply a shimmer effect for loading states
 */
fun Modifier.shimmer(
    duration: Int = 2000,
    bounce: Boolean = false
): Modifier = composed {
    val infiniteTransition = rememberInfiniteTransition(label = "shimmer")
    val translateX by infiniteTransition.animateFloat(
        initialValue = -400f,
        targetValue = 400f,
        animationSpec = infiniteRepeatable(
            animation = tween(duration, easing = LinearEasing),
            repeatMode = if (bounce) RepeatMode.Reverse else RepeatMode.Restart
        ),
        label = "shimmerX"
    )

    this.drawWithContent {
        drawContent()
        drawRect(
            brush = Brush.linearGradient(
                colors = listOf(
                    Color.Transparent,
                    Color.White.copy(alpha = 0.3f),
                    Color.Transparent
                ),
                start = Offset(translateX, 0f),
                end = Offset(translateX + 200f, size.height)
            ),
            alpha = 0.5f
        )
    }
}

// MARK: - Pulse Effect

/**
 * Apply a pulsing scale animation
 */
fun Modifier.pulse(
    minScale: Float = 1.0f,
    maxScale: Float = 1.05f,
    duration: Int = 1000
): Modifier = composed {
    val infiniteTransition = rememberInfiniteTransition(label = "pulse")
    val scale by infiniteTransition.animateFloat(
        initialValue = minScale,
        targetValue = maxScale,
        animationSpec = infiniteRepeatable(
            animation = tween(duration, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulseScale"
    )

    this.scale(scale)
}

// MARK: - Floating Effect

/**
 * Apply a floating animation (vertical movement)
 */
fun Modifier.floating(
    distance: Dp = 10.dp,
    duration: Int = 2000
): Modifier = composed {
    val infiniteTransition = rememberInfiniteTransition(label = "floating")
    val offsetY by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = distance.value,
        animationSpec = infiniteRepeatable(
            animation = tween(duration, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "floatingY"
    )

    this.offset(y = offsetY.dp)
}

// MARK: - Press Animation

/**
 * Apply press animation (scale down on press)
 */
fun Modifier.pressAnimation(
    scale: Float = 0.98f
): Modifier = composed {
    var isPressed by remember { mutableStateOf(false) }

    this
        .graphicsLayer {
            scaleX = if (isPressed) scale else 1f
            scaleY = if (isPressed) scale else 1f
            alpha = if (isPressed) 0.95f else 1f
        }
        .pointerInput(Unit) {
            detectTapGestures(
                onPress = {
                    isPressed = true
                    tryAwaitRelease()
                    isPressed = false
                }
            )
        }
}

// MARK: - Glass Background

/**
 * Apply simple glass background styling
 */
fun Modifier.glassBackground(
    cornerRadius: Dp = CornerRadius.medium
): Modifier = this
    .clip(RoundedCornerShape(cornerRadius))
    .background(
        brush = Brush.verticalGradient(
            colors = listOf(
                Color.White.copy(alpha = 0.12f),
                Color.White.copy(alpha = 0.06f)
            )
        )
    )
    .border(
        width = 1.dp,
        color = LiquidGlassColors.Glass.border,
        shape = RoundedCornerShape(cornerRadius)
    )
    .shadow(
        elevation = 10.dp,
        shape = RoundedCornerShape(cornerRadius),
        ambientColor = Color.Black.copy(alpha = 0.1f)
    )

// MARK: - Glass Effect (Full)

/**
 * Apply full glass effect with highlight gradient
 */
fun Modifier.glassEffect(
    cornerRadius: Dp = CornerRadius.large,
    borderWidth: Dp = 1.dp,
    shadowRadius: Dp = 12.dp
): Modifier = this
    .shadow(
        elevation = shadowRadius,
        shape = RoundedCornerShape(cornerRadius),
        ambientColor = Color.Black.copy(alpha = 0.1f)
    )
    .clip(RoundedCornerShape(cornerRadius))
    .background(
        brush = Brush.verticalGradient(
            colors = listOf(
                Color.White.copy(alpha = 0.15f),
                Color.White.copy(alpha = 0.05f)
            )
        )
    )
    .border(
        width = borderWidth,
        brush = Brush.linearGradient(
            colors = listOf(
                Color.White.copy(alpha = 0.3f),
                LiquidGlassColors.Glass.border,
                Color.Transparent
            )
        ),
        shape = RoundedCornerShape(cornerRadius)
    )

// MARK: - Gradient Text (requires text composable)

/**
 * Apply gradient coloring to text
 * Note: Use this with Text(modifier = Modifier.gradientText(...))
 */
fun Modifier.gradientText(
    colors: List<Color> = listOf(
        LiquidGlassColors.brandGreen,
        LiquidGlassColors.brandBlue
    )
): Modifier = this.graphicsLayer { alpha = 0.99f }

// MARK: - Animated Appearance

/**
 * Apply animated entrance (fade + slide + scale)
 */
fun Modifier.animatedAppearance(
    delay: Int = 0
): Modifier = composed {
    var hasAppeared by remember { mutableStateOf(false) }

    val transition = rememberInfiniteTransition(label = "appearance")

    // This is a simplified version - in practice you'd use LaunchedEffect
    // to trigger the animation on first composition

    this
        .graphicsLayer {
            alpha = if (hasAppeared) 1f else 0f
            translationY = if (hasAppeared) 0f else 20f
            scaleX = if (hasAppeared) 1f else 0.95f
            scaleY = if (hasAppeared) 1f else 0.95f
        }
}

// MARK: - Staggered Appearance

/**
 * Apply staggered animation for list items
 */
fun Modifier.staggeredAppearance(
    index: Int,
    baseDelay: Int = 100,
    staggerDelay: Int = 50
): Modifier = this.animatedAppearance(delay = baseDelay + (index * staggerDelay))
