package com.foodshare.ui.design.components.cards

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.ui.semantics.Role
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.LiquidGlassTypography
import com.foodshare.ui.design.tokens.Spacing

/**
 * Glass profile card with avatar circle + name + subtitle
 *
 * Features:
 * - 64dp circular avatar with brand gradient background
 * - Coil AsyncImage for avatar URL (with initials fallback)
 * - Name and subtitle text layout
 * - Glass card wrapper for consistent design
 */
@Composable
fun GlassProfileCard(
    name: String,
    subtitle: String,
    initials: String,
    modifier: Modifier = Modifier,
    avatarUrl: String? = null,
    onClick: (() -> Unit)? = null
) {
    GlassCard(
        modifier = modifier
            .then(
                if (onClick != null) {
                    Modifier.clickable(role = Role.Button, onClick = onClick)
                } else {
                    Modifier
                }
            ),
        cornerRadius = CornerRadius.medium,
        shadow = GlassShadow.Medium
    ) {
        Row(
            modifier = Modifier
                .padding(Spacing.md),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Avatar circle
            Box(
                modifier = Modifier
                    .size(64.dp)
                    .clip(CircleShape)
                    .background(brush = LiquidGlassGradients.brand),
                contentAlignment = Alignment.Center
            ) {
                if (avatarUrl != null) {
                    AsyncImage(
                        model = avatarUrl,
                        contentDescription = "Avatar for $name",
                        modifier = Modifier
                            .size(64.dp)
                            .clip(CircleShape)
                    )
                } else {
                    Text(
                        text = initials,
                        style = LiquidGlassTypography.titleLarge,
                        color = LiquidGlassColors.Text.primary
                    )
                }
            }

            Spacer(modifier = Modifier.width(Spacing.md))

            // Name and subtitle column
            Column {
                Text(
                    text = name,
                    style = LiquidGlassTypography.titleMedium,
                    color = LiquidGlassColors.Text.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Text(
                    text = subtitle,
                    style = LiquidGlassTypography.bodyMedium,
                    color = LiquidGlassColors.Text.secondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}
