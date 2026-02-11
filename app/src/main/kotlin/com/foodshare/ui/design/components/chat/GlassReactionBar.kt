package com.foodshare.ui.design.components.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Data class representing a single reaction
 */
data class Reaction(
    val emoji: String,
    val count: Int,
    val isSelected: Boolean
)

/**
 * Glass-style reaction bar for chat messages
 * Displays a horizontal row of emoji reactions with counts
 *
 * @param reactions List of reactions to display
 * @param onReactionClick Callback when a reaction is clicked
 * @param modifier Optional modifier for the reaction bar
 */
@Composable
fun GlassReactionBar(
    reactions: List<Reaction>,
    onReactionClick: (String) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
        contentPadding = PaddingValues(horizontal = Spacing.xs)
    ) {
        items(reactions) { reaction ->
            ReactionChip(
                reaction = reaction,
                onClick = { onReactionClick(reaction.emoji) }
            )
        }
    }
}

/**
 * Individual reaction chip with glass micro background
 *
 * @param reaction The reaction data to display
 * @param onClick Callback when the chip is clicked
 */
@Composable
private fun ReactionChip(
    reaction: Reaction,
    onClick: () -> Unit
) {
    val borderBrush = if (reaction.isSelected) {
        Brush.linearGradient(
            colors = listOf(
                LiquidGlassColors.brandPink,
                LiquidGlassColors.brandPink.copy(alpha = 0.7f)
            )
        )
    } else {
        Brush.linearGradient(
            colors = listOf(
                LiquidGlassColors.Glass.border,
                LiquidGlassColors.Glass.border.copy(alpha = 0.5f)
            )
        )
    }

    val backgroundColor = if (reaction.isSelected) {
        LiquidGlassColors.Glass.micro.copy(alpha = 0.3f)
    } else {
        LiquidGlassColors.Glass.micro
    }

    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(CornerRadius.full))
            .clickable(onClick = onClick)
            .border(
                width = 1.dp,
                brush = borderBrush,
                shape = RoundedCornerShape(CornerRadius.full)
            )
            .background(backgroundColor)
            .padding(horizontal = Spacing.sm, vertical = Spacing.xs),
        horizontalArrangement = Arrangement.spacedBy(Spacing.xxs),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Emoji
        Text(
            text = reaction.emoji,
            fontSize = 16.sp
        )

        // Count
        Text(
            text = reaction.count.toString(),
            fontSize = 12.sp,
            color = if (reaction.isSelected) {
                LiquidGlassColors.brandPink
            } else {
                LiquidGlassColors.Text.primary.copy(alpha = 0.8f)
            }
        )
    }
}
