package com.foodshare.features.forum.presentation.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Campaign
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Help
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.foodshare.features.forum.domain.model.ForumPostType
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.Spacing
import com.foodshare.ui.theme.LocalThemePalette

@Composable
fun ForumPostTypeChip(
    postType: ForumPostType,
    isSelected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val palette = LocalThemePalette.current

    val icon = when (postType) {
        ForumPostType.DISCUSSION -> Icons.Default.Forum
        ForumPostType.QUESTION -> Icons.Default.Help
        ForumPostType.ANNOUNCEMENT -> Icons.Default.Campaign
        ForumPostType.GUIDE -> Icons.Default.MenuBook
    }

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(
                if (isSelected) palette.primaryColor.copy(alpha = 0.2f)
                else LiquidGlassColors.Glass.background
            )
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = if (isSelected) palette.primaryColor else LiquidGlassColors.Glass.border,
                shape = RoundedCornerShape(12.dp)
            )
            .clickable { onClick() }
            .padding(horizontal = Spacing.md, vertical = Spacing.sm)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Spacing.xs)
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = if (isSelected) palette.primaryColor else Color.White.copy(alpha = 0.7f)
            )
            Text(
                text = postType.displayName,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                color = if (isSelected) palette.primaryColor else Color.White.copy(alpha = 0.8f)
            )
        }
    }
}
