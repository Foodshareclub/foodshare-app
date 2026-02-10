package com.foodshare.features.feed.presentation.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AllInclusive
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Kitchen
import androidx.compose.material.icons.filled.LocalFlorist
import androidx.compose.material.icons.filled.RestaurantMenu
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Store
import androidx.compose.material.icons.filled.SwapHoriz
import androidx.compose.material.icons.filled.VolunteerActivism
import androidx.compose.material3.Icon
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.foodshare.domain.model.PostType
import com.foodshare.ui.design.tokens.LiquidGlassAnimations
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Horizontal scrollable category filter bar
 *
 * Displays post type filters with glass styling
 */
@Composable
fun CategoryBar(
    selectedCategory: PostType?,
    onCategorySelected: (PostType?) -> Unit,
    modifier: Modifier = Modifier
) {
    val scrollState = rememberScrollState()

    Row(
        modifier = modifier
            .horizontalScroll(scrollState)
            .padding(horizontal = Spacing.md, vertical = Spacing.sm),
        horizontalArrangement = Arrangement.spacedBy(Spacing.sm)
    ) {
        // "All" chip
        CategoryChip(
            label = "All",
            icon = Icons.Default.AllInclusive,
            isSelected = selectedCategory == null,
            color = LiquidGlassColors.brandPink,
            onClick = { onCategorySelected(null) }
        )

        // Category chips
        mainCategories.forEach { category ->
            CategoryChip(
                label = category.displayName,
                icon = getCategoryIcon(category),
                isSelected = selectedCategory == category,
                color = getCategoryColor(category),
                onClick = { onCategorySelected(category) }
            )
        }
    }
}

@Composable
private fun CategoryChip(
    label: String,
    icon: ImageVector,
    isSelected: Boolean,
    color: Color,
    onClick: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isPressed by interactionSource.collectIsPressedAsState()

    val scale by animateFloatAsState(
        targetValue = if (isPressed) LiquidGlassAnimations.Scale.pressed else 1f,
        animationSpec = LiquidGlassAnimations.quickPress,
        label = "chipScale"
    )

    val backgroundColor by animateColorAsState(
        targetValue = if (isSelected) color else LiquidGlassColors.Glass.surface,
        label = "chipBackground"
    )

    val contentColor by animateColorAsState(
        targetValue = if (isSelected) Color.White else Color.White.copy(alpha = 0.8f),
        label = "chipContent"
    )

    Box(
        modifier = Modifier
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .clip(CircleShape)
            .background(
                if (isSelected) {
                    Brush.linearGradient(
                        colors = listOf(color, color.copy(alpha = 0.8f))
                    )
                } else {
                    Brush.linearGradient(
                        colors = listOf(
                            LiquidGlassColors.Glass.surface,
                            LiquidGlassColors.Glass.background
                        )
                    )
                }
            )
            .border(
                width = 1.dp,
                color = if (isSelected) Color.Transparent else LiquidGlassColors.Glass.border,
                shape = CircleShape
            )
            .clickable(
                interactionSource = interactionSource,
                indication = null,
                onClick = onClick
            )
            .padding(horizontal = Spacing.md, vertical = Spacing.xs),
        contentAlignment = Alignment.Center
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = contentColor,
                modifier = Modifier.size(16.dp)
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                color = contentColor
            )
        }
    }
}

// Main categories shown in the bar (subset of all PostTypes)
private val mainCategories = listOf(
    PostType.FOOD,
    PostType.FRIDGE,
    PostType.THING,
    PostType.WANTED,
    PostType.VOLUNTEER,
    PostType.ZEROWASTE,
    PostType.VEGAN,
    PostType.COMMUNITY
)

private fun getCategoryIcon(category: PostType): ImageVector = when (category) {
    PostType.FOOD -> Icons.Default.RestaurantMenu
    PostType.THING -> Icons.Default.CardGiftcard
    PostType.BORROW -> Icons.Default.SwapHoriz
    PostType.WANTED -> Icons.Default.Search
    PostType.FRIDGE -> Icons.Default.Kitchen
    PostType.FOODBANK -> Icons.Default.Store
    PostType.BUSINESS -> Icons.Default.Store
    PostType.VOLUNTEER -> Icons.Default.VolunteerActivism
    PostType.CHALLENGE -> Icons.Default.EmojiEvents
    PostType.ZEROWASTE -> Icons.Default.AllInclusive
    PostType.VEGAN -> Icons.Default.LocalFlorist
    PostType.COMMUNITY -> Icons.Default.Event
}

private fun getCategoryColor(category: PostType): Color = when (category) {
    PostType.FOOD -> LiquidGlassColors.Category.food
    PostType.THING -> LiquidGlassColors.Category.thing
    PostType.BORROW -> LiquidGlassColors.Category.borrow
    PostType.WANTED -> LiquidGlassColors.Category.wanted
    PostType.FRIDGE -> LiquidGlassColors.Category.fridge
    PostType.FOODBANK -> LiquidGlassColors.Category.foodbank
    PostType.BUSINESS -> LiquidGlassColors.Category.business
    PostType.VOLUNTEER -> LiquidGlassColors.Category.volunteer
    PostType.CHALLENGE -> LiquidGlassColors.Category.challenge
    PostType.ZEROWASTE -> LiquidGlassColors.Category.zerowaste
    PostType.VEGAN -> LiquidGlassColors.Category.vegan
    PostType.COMMUNITY -> LiquidGlassColors.Category.community
}
