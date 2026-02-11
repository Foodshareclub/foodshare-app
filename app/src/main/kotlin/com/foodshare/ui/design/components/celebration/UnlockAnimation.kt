package com.foodshare.ui.design.components.celebration

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing
import kotlinx.coroutines.delay

/**
 * Badge unlock animation with scale and glow effect
 *
 * @param icon The icon representing the unlocked badge
 * @param title The title of the unlocked achievement
 * @param isPlaying Whether the animation is playing
 * @param onComplete Callback when the animation completes
 * @param modifier Optional modifier for the animation container
 */
@Composable
fun UnlockAnimation(
    icon: ImageVector,
    title: String,
    isPlaying: Boolean,
    onComplete: () -> Unit,
    modifier: Modifier = Modifier
) {
    var showBurst by remember { mutableStateOf(false) }
    val scaleAnimatable = remember { Animatable(0f) }
    val glowAnimatable = remember { Animatable(0f) }

    LaunchedEffect(isPlaying) {
        if (isPlaying) {
            // Reset animations
            scaleAnimatable.snapTo(0f)
            glowAnimatable.snapTo(0f)
            showBurst = false

            // Trigger particle burst
            showBurst = true

            // Scale animation: 0 -> 1.1 -> 1.0 with spring
            scaleAnimatable.animateTo(
                targetValue = 1.1f,
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioMediumBouncy,
                    stiffness = Spring.StiffnessMedium
                )
            )
            scaleAnimatable.animateTo(
                targetValue = 1.0f,
                animationSpec = spring(
                    dampingRatio = Spring.DampingRatioLowBouncy,
                    stiffness = Spring.StiffnessMedium
                )
            )

            // Glow pulse animation
            glowAnimatable.animateTo(
                targetValue = 1f,
                animationSpec = repeatable(
                    iterations = 3,
                    animation = tween(500, easing = FastOutSlowInEasing),
                    repeatMode = RepeatMode.Reverse
                )
            )

            // Wait a bit then complete
            delay(1500)
            onComplete()
        }
    }

    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        // Particle burst effect
        if (showBurst) {
            ParticleBurst(
                isPlaying = isPlaying,
                center = androidx.compose.ui.geometry.Offset(0f, 0f), // Will be relative to Box center
                modifier = Modifier.fillMaxSize()
            )
        }

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(Spacing.md),
            modifier = Modifier.scale(scaleAnimatable.value)
        ) {
            // Badge icon with glow effect
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(120.dp)
                    .shadow(
                        elevation = (20.dp * glowAnimatable.value),
                        shape = CircleShape,
                        ambientColor = LiquidGlassColors.brandPink,
                        spotColor = LiquidGlassColors.brandPink
                    )
                    .background(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                LiquidGlassColors.brandPink.copy(alpha = 0.4f),
                                LiquidGlassColors.brandPink.copy(alpha = 0.2f),
                                LiquidGlassColors.brandPink.copy(alpha = 0.0f)
                            )
                        ),
                        shape = CircleShape
                    )
            ) {
                // Inner circle background
                Box(
                    modifier = Modifier
                        .size(100.dp)
                        .background(
                            brush = Brush.verticalGradient(
                                colors = listOf(
                                    LiquidGlassColors.Glass.background,
                                    LiquidGlassColors.Glass.background.copy(alpha = 0.9f)
                                )
                            ),
                            shape = CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = null,
                        modifier = Modifier.size(50.dp),
                        tint = LiquidGlassColors.brandPink
                    )
                }
            }

            // Title
            Text(
                text = title,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = LiquidGlassColors.Text.primary
            )
        }
    }
}
