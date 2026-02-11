package com.foodshare.ui.design.components.feedback

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.foodshare.ui.design.components.buttons.GlassButton
import com.foodshare.ui.design.components.buttons.GlassButtonStyle
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Glass error view component with error message and retry button
 *
 * Ported from iOS: GlassErrorView.swift (pattern)
 *
 * Features:
 * - Supports inline and fullscreen modes
 * - Error icon with glass background
 * - Optional retry button with Destructive style
 * - Consistent error messaging design
 */
@Composable
fun GlassErrorView(
    message: String,
    modifier: Modifier = Modifier,
    onRetry: (() -> Unit)? = null,
    isFullScreen: Boolean = false
) {
    val containerModifier = if (isFullScreen) {
        modifier.fillMaxSize()
    } else {
        modifier
    }

    Column(
        modifier = containerModifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        // Error icon in glass circle
        Box(
            modifier = Modifier
                .size(64.dp)
                .clip(CircleShape)
                .background(brush = LiquidGlassGradients.glassSurface),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = Icons.Default.ErrorOutline,
                contentDescription = "Error",
                tint = LiquidGlassColors.error,
                modifier = Modifier.size(32.dp)
            )
        }

        Spacer(modifier = Modifier.height(Spacing.md))

        // Error message
        Text(
            text = message,
            color = Color.White,
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            textAlign = TextAlign.Center
        )

        // Optional retry button
        onRetry?.let {
            Spacer(modifier = Modifier.height(Spacing.lg))
            GlassButton(
                text = "Retry",
                onClick = it,
                style = GlassButtonStyle.Destructive
            )
        }
    }
}
