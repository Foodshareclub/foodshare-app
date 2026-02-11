package com.foodshare.ui.design.components.layout

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassAnimations
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.LiquidGlassTypography
import com.foodshare.ui.design.tokens.Spacing

/**
 * Expandable/collapsible section with glass styling
 *
 * Features:
 * - Animated expand/collapse with rotating chevron
 * - Glass micro background on header
 * - AnimatedVisibility for smooth content transitions
 */
@Composable
fun GlassExpander(
    title: String,
    isExpanded: Boolean,
    onToggle: () -> Unit,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    val chevronRotation by animateFloatAsState(
        targetValue = if (isExpanded) 180f else 0f,
        animationSpec = LiquidGlassAnimations.smooth,
        label = "chevron_rotation"
    )

    Column(modifier = modifier.fillMaxWidth()) {
        // Header row with glass micro background
        val headerShape = RoundedCornerShape(CornerRadius.medium)
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(headerShape)
                .background(brush = LiquidGlassGradients.glassSurface)
                .border(
                    width = 1.dp,
                    color = LiquidGlassColors.Glass.border,
                    shape = headerShape
                )
                .clickable(role = Role.Button, onClick = onToggle)
                .padding(horizontal = Spacing.md, vertical = Spacing.sm),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                style = LiquidGlassTypography.titleMedium,
                color = Color.White
            )

            Icon(
                imageVector = Icons.Default.KeyboardArrowDown,
                contentDescription = if (isExpanded) "Collapse" else "Expand",
                tint = Color.White.copy(alpha = 0.7f),
                modifier = Modifier.rotate(chevronRotation)
            )
        }

        // Animated content
        AnimatedVisibility(
            visible = isExpanded,
            enter = expandVertically(animationSpec = spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMediumLow)) + fadeIn(),
            exit = shrinkVertically(animationSpec = spring(dampingRatio = 0.8f, stiffness = Spring.StiffnessMediumLow)) + fadeOut()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = Spacing.sm)
            ) {
                content()
            }
        }
    }
}
