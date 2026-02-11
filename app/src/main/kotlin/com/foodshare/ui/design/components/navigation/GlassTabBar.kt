package com.foodshare.ui.design.components.navigation

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing
import com.foodshare.ui.theme.LocalThemePalette
import kotlin.math.sin

/**
 * Glass Tab Bar - Premium glassmorphism navigation
 *
 * Features:
 * - Breathing animation for selected state
 * - Capsule shape with glass background
 * - Badge support
 * - Smooth spring animations
 */
@Composable
fun GlassTabBar(
    tabs: List<GlassTabItem>,
    selectedIndex: Int,
    onTabSelected: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    // Breathing animation
    val infiniteTransition = rememberInfiniteTransition(label = "breathing")
    val breathingPhase by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = (Math.PI * 2).toFloat(),
        animationSpec = infiniteRepeatable(
            animation = tween(2500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Restart
        ),
        label = "breathingPhase"
    )

    val palette = LocalThemePalette.current

    Box(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = Spacing.lg, vertical = Spacing.sm)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(80.dp)
                .shadow(
                    elevation = 20.dp,
                    shape = RoundedCornerShape(40.dp),
                    ambientColor = Color.Black.copy(alpha = 0.15f)
                )
                .clip(RoundedCornerShape(40.dp))
                .background(
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.15f),
                            Color.White.copy(alpha = 0.08f)
                        )
                    )
                )
                .border(
                    width = 1.dp,
                    brush = Brush.linearGradient(
                        colors = listOf(
                            Color.White.copy(alpha = 0.6f),
                            Color.White.copy(alpha = 0.2f),
                            Color.White.copy(alpha = 0.1f)
                        )
                    ),
                    shape = RoundedCornerShape(40.dp)
                )
                .padding(horizontal = Spacing.sm, vertical = Spacing.sm),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            tabs.forEachIndexed { index, tab ->
                GlassTabButton(
                    tab = tab,
                    isSelected = selectedIndex == index,
                    breathingPhase = breathingPhase,
                    accentColor = palette.primaryColor,
                    onClick = { onTabSelected(index) },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun GlassTabButton(
    tab: GlassTabItem,
    isSelected: Boolean,
    breathingPhase: Float,
    accentColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    // Scale animation
    val scale by animateFloatAsState(
        targetValue = when {
            isPressed -> 0.92f
            isSelected -> 1.0f
            else -> 0.95f
        },
        animationSpec = spring(dampingRatio = 0.5f, stiffness = 400f),
        label = "scale"
    )

    // Color animation
    val iconColor by animateColorAsState(
        targetValue = if (isSelected) Color.White else Color.White.copy(alpha = 0.6f),
        animationSpec = tween(200),
        label = "iconColor"
    )

    val textColor by animateColorAsState(
        targetValue = if (isSelected) accentColor else Color.White.copy(alpha = 0.6f),
        animationSpec = tween(200),
        label = "textColor"
    )

    Column(
        modifier = modifier
            .scale(scale)
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                role = Role.Tab
            ) { onClick() },
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(contentAlignment = Alignment.Center) {
            // Selection background with pulse effect
            if (isSelected) {
                // Outer glow pulse
                val glowScale = 1.0f + 0.1f * sin(breathingPhase)
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .scale(glowScale)
                        .blur(4.dp)
                        .background(
                            color = accentColor.copy(alpha = 0.3f),
                            shape = CircleShape
                        )
                )

                // Main selection circle
                val shadowAlpha = 0.4f + 0.2f * sin(breathingPhase)
                val shadowRadius = 8.dp + (4 * sin(breathingPhase)).dp
                Box(
                    modifier = Modifier
                        .size(48.dp)
                        .shadow(
                            elevation = shadowRadius,
                            shape = CircleShape,
                            ambientColor = accentColor.copy(alpha = shadowAlpha)
                        )
                        .background(
                            color = accentColor,
                            shape = CircleShape
                        )
                )
            }

            // Icon
            Icon(
                imageVector = if (isSelected) tab.selectedIcon else tab.icon,
                contentDescription = tab.label,
                tint = iconColor,
                modifier = Modifier.size(24.dp)
            )

            // Badge
            if (tab.badge != null && tab.badge > 0) {
                GlassBadge(
                    count = tab.badge,
                    breathingPhase = breathingPhase,
                    modifier = Modifier
                        .align(Alignment.TopEnd)
                        .offset(x = 14.dp, y = (-14).dp)
                )
            }
        }

        Spacer(Modifier.height(4.dp))

        // Label
        val labelOpacity = if (isSelected) 1f else 0.8f + 0.2f * sin(breathingPhase)
        Text(
            text = tab.label,
            fontSize = 10.sp,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            color = textColor.copy(alpha = labelOpacity)
        )
    }
}

@Composable
private fun GlassBadge(
    count: Int,
    breathingPhase: Float,
    modifier: Modifier = Modifier
) {
    val pulseScale = 1.0f + 0.15f * sin(breathingPhase * 1.5f)

    Box(modifier = modifier, contentAlignment = Alignment.Center) {
        // Pulsing glow
        Box(
            modifier = Modifier
                .size(24.dp)
                .scale(pulseScale)
                .blur(2.dp)
                .background(
                    color = LiquidGlassColors.error.copy(alpha = 0.4f),
                    shape = CircleShape
                )
        )

        // Badge circle
        Box(
            modifier = Modifier
                .size(18.dp)
                .shadow(4.dp, CircleShape, ambientColor = LiquidGlassColors.error.copy(alpha = 0.5f))
                .background(LiquidGlassColors.error, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = if (count > 99) "99+" else count.toString(),
                fontSize = if (count > 99) 8.sp else 10.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White
            )
        }
    }
}

/**
 * Tab item for GlassTabBar
 */
data class GlassTabItem(
    val label: String,
    val icon: ImageVector,
    val selectedIcon: ImageVector = icon,
    val badge: Int? = null
)
