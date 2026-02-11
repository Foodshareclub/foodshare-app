package com.foodshare.ui.design.components.feedback

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Glass empty state component with icon, title, subtitle, and optional action
 *
 * Ported from iOS: GlassEmptyState.swift (pattern)
 *
 * Features:
 * - Centered layout with glass icon container
 * - Optional subtitle and action button
 * - Consistent spacing and typography
 * - Follows Liquid Glass design system
 */
@Composable
fun GlassEmptyState(
    icon: ImageVector,
    title: String,
    modifier: Modifier = Modifier,
    subtitle: String? = null,
    actionText: String? = null,
    onAction: (() -> Unit)? = null
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Icon in glass surface circle
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(brush = LiquidGlassGradients.glassSurface),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = icon,
                contentDescription = title,
                tint = Color.White,
                modifier = Modifier.size(32.dp)
            )
        }

        Spacer(modifier = Modifier.height(Spacing.md))

        // Title
        Text(
            text = title,
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.SemiBold,
            textAlign = TextAlign.Center
        )

        // Optional subtitle
        subtitle?.let {
            Spacer(modifier = Modifier.height(Spacing.xs))
            Text(
                text = it,
                color = Color.White.copy(alpha = 0.7f),
                fontSize = 14.sp,
                fontWeight = FontWeight.Normal,
                textAlign = TextAlign.Center
            )
        }

        // Optional action button
        if (actionText != null && onAction != null) {
            Spacer(modifier = Modifier.height(Spacing.lg))
            GlassButton(
                text = actionText,
                onClick = onAction,
                style = GlassButtonStyle.Primary
            )
        }
    }
}
