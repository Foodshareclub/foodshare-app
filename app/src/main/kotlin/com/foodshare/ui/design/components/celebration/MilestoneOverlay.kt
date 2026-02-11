package com.foodshare.ui.design.components.celebration

import androidx.compose.animation.*
import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing
import kotlinx.coroutines.delay

/**
 * Fullscreen overlay displaying a milestone achievement with confetti
 *
 * @param title The main milestone title
 * @param subtitle Additional milestone description
 * @param icon The icon representing the milestone
 * @param onDismiss Callback when the overlay is dismissed
 * @param isVisible Whether the overlay is visible
 */
@Composable
fun MilestoneOverlay(
    title: String,
    subtitle: String,
    icon: ImageVector,
    onDismiss: () -> Unit,
    isVisible: Boolean
) {
    // Auto-dismiss after 3 seconds
    LaunchedEffect(isVisible) {
        if (isVisible) {
            delay(3000)
            onDismiss()
        }
    }

    AnimatedVisibility(
        visible = isVisible,
        enter = fadeIn(animationSpec = tween(300)) + scaleIn(
            initialScale = 0.8f,
            animationSpec = spring(
                dampingRatio = Spring.DampingRatioMediumBouncy,
                stiffness = Spring.StiffnessLow
            )
        ),
        exit = fadeOut(animationSpec = tween(200)) + scaleOut(
            targetScale = 0.9f,
            animationSpec = tween(200)
        )
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(LiquidGlassColors.Overlay.scrim)
                .clickable(role = Role.Button, onClick = onDismiss),
            contentAlignment = Alignment.Center
        ) {
            // Confetti background
            ConfettiView(
                isPlaying = isVisible,
                modifier = Modifier.fillMaxSize()
            )

            // Milestone card
            Column(
                modifier = Modifier
                    .padding(Spacing.xl)
                    .clip(RoundedCornerShape(CornerRadius.large))
                    .background(
                        brush = Brush.verticalGradient(
                            colors = listOf(
                                LiquidGlassColors.Glass.background,
                                LiquidGlassColors.Glass.background.copy(alpha = 0.95f)
                            )
                        )
                    )
                    .padding(Spacing.xl),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(Spacing.md)
            ) {
                // Icon with gradient background
                Box(
                    modifier = Modifier
                        .size(80.dp)
                        .clip(RoundedCornerShape(CornerRadius.full))
                        .background(
                            brush = Brush.radialGradient(
                                colors = listOf(
                                    LiquidGlassColors.brandPink.copy(alpha = 0.3f),
                                    LiquidGlassColors.brandPink.copy(alpha = 0.1f)
                                )
                            )
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = icon,
                        contentDescription = "Milestone achievement",
                        modifier = Modifier.size(40.dp),
                        tint = LiquidGlassColors.brandPink
                    )
                }

                // Title
                Text(
                    text = title,
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    color = LiquidGlassColors.Text.primary,
                    textAlign = TextAlign.Center
                )

                // Subtitle
                Text(
                    text = subtitle,
                    fontSize = 16.sp,
                    color = LiquidGlassColors.Text.secondary,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}
