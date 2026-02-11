package com.foodshare.ui.design.components.inputs

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.tokens.*

/**
 * Custom toggle switch with glass styling
 * Features smooth animations and optional label
 */
@Composable
fun GlassToggle(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    label: String? = null,
    enabled: Boolean = true
) {
    val interactionSource = remember { MutableInteractionSource() }

    val trackColor by animateColorAsState(
        targetValue = if (checked && enabled) {
            Color.Transparent
        } else {
            LiquidGlassColors.Glass.surface
        },
        animationSpec = tween(durationMillis = LiquidGlassAnimations.Duration.standard),
        label = "track_color"
    )

    val thumbOffset by animateDpAsState(
        targetValue = if (checked) 24.dp else 0.dp,
        animationSpec = tween(durationMillis = LiquidGlassAnimations.Duration.standard),
        label = "thumb_offset"
    )

    Row(
        modifier = modifier
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                enabled = enabled,
                role = Role.Switch,
                onClick = { onCheckedChange(!checked) }
            ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Spacing.md)
    ) {
        // Optional label
        label?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                color = if (enabled) {
                    LiquidGlassColors.Text.primary
                } else {
                    LiquidGlassColors.Text.secondary.copy(alpha = 0.5f)
                }
            )
        }

        // Toggle track
        Box(
            modifier = Modifier
                .width(52.dp)
                .height(32.dp)
                .clip(RoundedCornerShape(16.dp))
                .then(
                    if (checked && enabled) {
                        Modifier.background(
                            brush = LiquidGlassGradients.brand
                        )
                    } else {
                        Modifier.background(trackColor)
                    }
                )
                .border(
                    width = 1.dp,
                    color = if (checked && enabled) {
                        Color.Transparent
                    } else {
                        LiquidGlassColors.Glass.border
                    },
                    shape = RoundedCornerShape(16.dp)
                )
                .padding(4.dp)
        ) {
            // Toggle thumb
            Box(
                modifier = Modifier
                    .offset(x = thumbOffset)
                    .size(24.dp)
                    .clip(CircleShape)
                    .background(Color.White)
                    .align(Alignment.CenterStart)
            )
        }
    }
}
