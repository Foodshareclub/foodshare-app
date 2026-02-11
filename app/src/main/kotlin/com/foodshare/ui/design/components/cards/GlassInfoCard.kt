package com.foodshare.ui.design.components.cards

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.LiquidGlassTypography
import com.foodshare.ui.design.tokens.Spacing

/**
 * Glass info card for settings rows and information display
 *
 * Features:
 * - Icon in 40dp circular glass surface
 * - Title and optional description text
 * - Optional trailing composable slot (for chevrons, toggles, etc.)
 * - Clickable with glass micro background
 * - Row layout for consistent alignment
 */
@Composable
fun GlassInfoCard(
    icon: ImageVector,
    title: String,
    modifier: Modifier = Modifier,
    description: String? = null,
    onClick: (() -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null
) {
    GlassCard(
        modifier = modifier
            .fillMaxWidth()
            .then(
                if (onClick != null) {
                    Modifier.clickable(role = Role.Button, onClick = onClick)
                } else {
                    Modifier
                }
            ),
        cornerRadius = CornerRadius.medium,
        shadow = GlassShadow.Subtle
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(brush = LiquidGlassGradients.glassSurface)
                .padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Icon in circular glass surface
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(color = LiquidGlassColors.Glass.micro),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = title,
                    tint = LiquidGlassColors.Text.primary,
                    modifier = Modifier.size(24.dp)
                )
            }

            Spacer(modifier = Modifier.width(Spacing.md))

            // Title and description column
            Column(
                modifier = Modifier.weight(1f)
            ) {
                Text(
                    text = title,
                    style = LiquidGlassTypography.titleMedium,
                    color = LiquidGlassColors.Text.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                if (description != null) {
                    Text(
                        text = description,
                        style = LiquidGlassTypography.bodySmall,
                        color = LiquidGlassColors.Text.secondary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            // Trailing content slot
            if (trailing != null) {
                Spacer(modifier = Modifier.width(Spacing.sm))
                trailing()
            }
        }
    }
}
