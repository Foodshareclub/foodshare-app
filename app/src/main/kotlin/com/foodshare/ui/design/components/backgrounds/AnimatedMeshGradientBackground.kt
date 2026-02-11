package com.foodshare.ui.design.components.backgrounds

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassAnimations
import kotlin.math.cos
import kotlin.math.sin

/**
 * Animated radial gradient background with mesh effect
 * Creates a dynamic, flowing background using multiple animated radial gradients
 */
@Composable
fun AnimatedMeshGradientBackground(
    modifier: Modifier = Modifier
) {
    val infiniteTransition = rememberInfiniteTransition(label = "mesh_gradient")

    // Animate multiple gradient positions
    val offset1 by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = LiquidGlassAnimations.Duration.slow,
                easing = LinearEasing
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "offset1"
    )

    val offset2 by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = LiquidGlassAnimations.Duration.slow + 2000,
                easing = LinearEasing
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "offset2"
    )

    val offset3 by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(
                durationMillis = LiquidGlassAnimations.Duration.slow + 4000,
                easing = LinearEasing
            ),
            repeatMode = RepeatMode.Restart
        ),
        label = "offset3"
    )

    Canvas(modifier = modifier.fillMaxSize()) {
        val width = size.width
        val height = size.height
        val centerX = width / 2
        val centerY = height / 2
        val radius = width.coerceAtLeast(height) * 0.6f

        // Calculate animated positions using circular motion
        val pos1X = centerX + radius * cos(Math.toRadians(offset1.toDouble())).toFloat() * 0.5f
        val pos1Y = centerY + radius * sin(Math.toRadians(offset1.toDouble())).toFloat() * 0.5f

        val pos2X = centerX + radius * cos(Math.toRadians(offset2.toDouble())).toFloat() * 0.4f
        val pos2Y = centerY + radius * sin(Math.toRadians(offset2.toDouble())).toFloat() * 0.4f

        val pos3X = centerX + radius * cos(Math.toRadians(offset3.toDouble())).toFloat() * 0.3f
        val pos3Y = centerY + radius * sin(Math.toRadians(offset3.toDouble())).toFloat() * 0.3f

        // Draw multiple overlapping radial gradients
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    LiquidGlassColors.brandPink.copy(alpha = 0.15f),
                    Color.Transparent
                ),
                center = Offset(pos1X, pos1Y),
                radius = width * 0.6f
            )
        )

        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    LiquidGlassColors.brandTeal.copy(alpha = 0.2f),
                    Color.Transparent
                ),
                center = Offset(pos2X, pos2Y),
                radius = width * 0.5f
            )
        )

        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    LiquidGlassColors.brandBlue.copy(alpha = 0.1f),
                    Color.Transparent
                ),
                center = Offset(pos3X, pos3Y),
                radius = width * 0.7f
            )
        )
    }
}
