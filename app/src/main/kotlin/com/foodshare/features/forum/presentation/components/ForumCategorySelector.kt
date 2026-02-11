package com.foodshare.features.forum.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.foodshare.features.forum.domain.model.ForumCategory
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing
import com.foodshare.ui.theme.LocalThemePalette

@Composable
fun ForumCategoryChip(
    category: ForumCategory,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palette = LocalThemePalette.current

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(
                if (isSelected) palette.primaryColor.copy(alpha = 0.2f)
                else LiquidGlassColors.Glass.background
            )
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = if (isSelected) palette.primaryColor else LiquidGlassColors.Glass.border,
                shape = RoundedCornerShape(50)
            )
            .clickable { onClick() }
            .padding(horizontal = Spacing.md, vertical = Spacing.sm)
    ) {
        Text(
            text = category.name,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
            color = if (isSelected) palette.primaryColor else Color.White.copy(alpha = 0.8f)
        )
    }
}
