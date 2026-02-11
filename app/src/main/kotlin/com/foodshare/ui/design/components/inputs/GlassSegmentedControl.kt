package com.foodshare.ui.design.components.inputs

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.tokens.*

/**
 * Segmented control with glass styling (iOS-style segmented buttons)
 * Features animated selection indicator and smooth transitions
 */
@Composable
fun GlassSegmentedControl(
    options: List<String>,
    selectedIndex: Int,
    onOptionSelected: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    require(options.isNotEmpty()) { "Options list cannot be empty" }
    require(selectedIndex in options.indices) { "Selected index must be within options bounds" }

    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(44.dp)
            .clip(RoundedCornerShape(CornerRadius.large))
            .background(LiquidGlassColors.Glass.surface)
            .border(
                width = 1.dp,
                color = LiquidGlassColors.Glass.border,
                shape = RoundedCornerShape(CornerRadius.large)
            )
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        options.forEachIndexed { index, option ->
            val isSelected = index == selectedIndex

            val backgroundColor by animateColorAsState(
                targetValue = if (isSelected) Color.Transparent else Color.Transparent,
                animationSpec = tween(durationMillis = LiquidGlassAnimations.Duration.standard),
                label = "background_color_$index"
            )

            val textColor by animateColorAsState(
                targetValue = if (isSelected) {
                    Color.White
                } else {
                    LiquidGlassColors.Text.secondary
                },
                animationSpec = tween(durationMillis = LiquidGlassAnimations.Duration.standard),
                label = "text_color_$index"
            )

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(CornerRadius.medium))
                    .then(
                        if (isSelected) {
                            Modifier.background(
                                brush = LiquidGlassGradients.brand
                            )
                        } else {
                            Modifier.background(backgroundColor)
                        }
                    )
                    .clickable { onOptionSelected(index) },
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = option,
                    style = MaterialTheme.typography.bodyMedium,
                    color = textColor,
                    textAlign = TextAlign.Center,
                    maxLines = 1
                )
            }
        }
    }
}
