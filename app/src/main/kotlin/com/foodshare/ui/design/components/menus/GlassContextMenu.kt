package com.foodshare.ui.design.components.menus

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.LiquidGlassTypography

/**
 * Data class representing a menu item
 *
 * @param label Text to display
 * @param icon Optional icon to show
 * @param onClick Action to perform when clicked
 * @param isDestructive Whether this is a destructive action (shows in error color)
 */
data class GlassMenuItem(
    val label: String,
    val icon: ImageVector? = null,
    val onClick: () -> Unit,
    val isDestructive: Boolean = false
)

/**
 * DropdownMenu with glass styling
 *
 * Features:
 * - Frosted glass background with gradient
 * - Subtle border for depth
 * - Icon + text for each item
 * - Destructive items shown in error color
 */
@Composable
fun GlassContextMenu(
    expanded: Boolean,
    onDismissRequest: () -> Unit,
    items: List<GlassMenuItem>,
    modifier: Modifier = Modifier
) {
    val menuShape = RoundedCornerShape(CornerRadius.medium)

    DropdownMenu(
        expanded = expanded,
        onDismissRequest = onDismissRequest,
        modifier = modifier
            .clip(menuShape)
            .background(brush = LiquidGlassGradients.glassSurface)
            .border(
                width = 1.dp,
                color = LiquidGlassColors.Glass.border,
                shape = menuShape
            )
    ) {
        items.forEach { item ->
            DropdownMenuItem(
                text = {
                    Text(
                        text = item.label,
                        style = LiquidGlassTypography.bodyMedium,
                        color = if (item.isDestructive) {
                            LiquidGlassColors.error
                        } else {
                            Color.White
                        }
                    )
                },
                onClick = {
                    item.onClick()
                    onDismissRequest()
                },
                leadingIcon = item.icon?.let { icon ->
                    {
                        Icon(
                            imageVector = icon,
                            contentDescription = item.label,
                            tint = if (item.isDestructive) {
                                LiquidGlassColors.error
                            } else {
                                Color.White.copy(alpha = 0.7f)
                            }
                        )
                    }
                }
            )
        }
    }
}
