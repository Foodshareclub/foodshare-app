package com.foodshare.ui.design.components.buttons

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.foodshare.ui.design.tokens.LiquidGlassAnimations
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients
import com.foodshare.ui.design.tokens.Spacing

/**
 * Liquid Glass Button Component with ProMotion-optimized animations
 *
 * Ported from iOS: GlassButton.swift
 *
 * Features:
 * - Multiple gradient styles (primary, secondary, blueCyan, etc.)
 * - Layered glass effects
 * - Scale animation on press
 * - Loading state with spinner
 * - Icon support
 */
@Composable
fun GlassButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    iconContentDescription: String? = null,
    style: GlassButtonStyle = GlassButtonStyle.Primary,
    isLoading: Boolean = false,
    enabled: Boolean = true
) {
    var isPressed by remember { mutableStateOf(false) }

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) LiquidGlassAnimations.Scale.pressed else 1f,
        animationSpec = LiquidGlassAnimations.quickPress,
        label = "buttonScale"
    )

    val buttonHeight = when (style) {
        GlassButtonStyle.PinkTeal, GlassButtonStyle.BlueCyan, GlassButtonStyle.Nature -> 58.dp
        else -> 56.dp
    }

    val buttonShape = RoundedCornerShape(18.dp)

    Button(
        onClick = {
            if (!isLoading && enabled) onClick()
        },
        modifier = modifier
            .scale(scale)
            .height(buttonHeight)
            .fillMaxWidth()
            .pointerInput(enabled) {
                detectTapGestures(
                    onPress = {
                        if (enabled) {
                            isPressed = true
                            tryAwaitRelease()
                            isPressed = false
                        }
                    }
                )
            },
        enabled = enabled && !isLoading,
        shape = buttonShape,
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Transparent,
            contentColor = style.foregroundColor,
            disabledContainerColor = Color.Transparent,
            disabledContentColor = style.foregroundColor.copy(alpha = 0.55f)
        ),
        contentPadding = PaddingValues(horizontal = Spacing.md)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    // Enable GPU rasterization for layered gradient effects
                    compositingStrategy = androidx.compose.ui.graphics.CompositingStrategy.Offscreen
                }
                .background(
                    brush = style.gradient,
                    shape = buttonShape
                )
                .border(
                    width = 1.5.dp,
                    brush = LiquidGlassGradients.glassBorder,
                    shape = buttonShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(22.dp),
                        color = style.foregroundColor,
                        strokeWidth = 2.dp
                    )
                } else {
                    icon?.let {
                        Icon(
                            imageVector = it,
                            contentDescription = iconContentDescription,
                            tint = style.foregroundColor,
                            modifier = Modifier.size(22.dp)
                        )
                        Spacer(Modifier.width(14.dp))
                    }
                    Text(
                        text = text,
                        color = style.foregroundColor,
                        fontWeight = FontWeight.SemiBold,
                        fontSize = 18.sp
                    )
                }
            }
        }
    }
}

/**
 * Smaller glass button variant
 */
@Composable
fun GlassButtonSmall(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    iconContentDescription: String? = null,
    style: GlassButtonStyle = GlassButtonStyle.Primary,
    isLoading: Boolean = false,
    enabled: Boolean = true
) {
    var isPressed by remember { mutableStateOf(false) }

    val scale by animateFloatAsState(
        targetValue = if (isPressed && enabled) LiquidGlassAnimations.Scale.pressed else 1f,
        animationSpec = LiquidGlassAnimations.quickPress,
        label = "buttonScale"
    )

    val buttonShape = RoundedCornerShape(12.dp)

    Button(
        onClick = {
            if (!isLoading && enabled) onClick()
        },
        modifier = modifier
            .scale(scale)
            .height(40.dp)
            .pointerInput(enabled) {
                detectTapGestures(
                    onPress = {
                        if (enabled) {
                            isPressed = true
                            tryAwaitRelease()
                            isPressed = false
                        }
                    }
                )
            },
        enabled = enabled && !isLoading,
        shape = buttonShape,
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Transparent,
            contentColor = style.foregroundColor,
            disabledContainerColor = Color.Transparent,
            disabledContentColor = style.foregroundColor.copy(alpha = 0.55f)
        ),
        contentPadding = PaddingValues(horizontal = Spacing.sm)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .graphicsLayer {
                    // Enable GPU rasterization for layered gradient effects
                    compositingStrategy = androidx.compose.ui.graphics.CompositingStrategy.Offscreen
                }
                .background(
                    brush = style.gradient,
                    shape = buttonShape
                )
                .border(
                    width = 1.dp,
                    brush = LiquidGlassGradients.glassBorder,
                    shape = buttonShape
                ),
            contentAlignment = Alignment.Center
        ) {
            Row(
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        color = style.foregroundColor,
                        strokeWidth = 2.dp
                    )
                } else {
                    icon?.let {
                        Icon(
                            imageVector = it,
                            contentDescription = iconContentDescription,
                            tint = style.foregroundColor,
                            modifier = Modifier.size(16.dp)
                        )
                        Spacer(Modifier.width(8.dp))
                    }
                    Text(
                        text = text,
                        color = style.foregroundColor,
                        fontWeight = FontWeight.Medium,
                        fontSize = 14.sp
                    )
                }
            }
        }
    }
}

/**
 * Button style presets matching iOS GlassButton.ButtonStyle
 */
enum class GlassButtonStyle(
    val gradient: Brush,
    val foregroundColor: Color
) {
    /** Foodshare brand (Pink/Teal gradient) */
    Primary(
        gradient = LiquidGlassGradients.brand,
        foregroundColor = Color.White
    ),

    /** Full Foodshare brand CTA style */
    PinkTeal(
        gradient = LiquidGlassGradients.pinkTeal,
        foregroundColor = Color.White
    ),

    /** Blue/Cyan gradient */
    BlueCyan(
        gradient = LiquidGlassGradients.blueCyan,
        foregroundColor = Color.White
    ),

    /** Glass background (secondary) */
    Secondary(
        gradient = Brush.linearGradient(
            colors = listOf(
                LiquidGlassColors.Glass.surface,
                LiquidGlassColors.Glass.background
            )
        ),
        foregroundColor = Color.White
    ),

    /** Outline style (clear with border) */
    Outline(
        gradient = Brush.linearGradient(
            colors = listOf(
                Color.Transparent,
                Color.Transparent
            )
        ),
        foregroundColor = LiquidGlassColors.brandPink
    ),

    /** Ghost style (clear, no visible background) */
    Ghost(
        gradient = Brush.linearGradient(
            colors = listOf(
                Color.Transparent,
                Color.Transparent
            )
        ),
        foregroundColor = LiquidGlassColors.brandPink
    ),

    /** Destructive (red gradient) */
    Destructive(
        gradient = Brush.linearGradient(
            colors = listOf(
                LiquidGlassColors.error.copy(alpha = 0.95f),
                LiquidGlassColors.error.copy(alpha = 0.8f)
            )
        ),
        foregroundColor = Color.White
    ),

    /** Success/Eco green style */
    Green(
        gradient = Brush.linearGradient(
            colors = listOf(
                LiquidGlassColors.success.copy(alpha = 0.95f),
                LiquidGlassColors.brandGreen.copy(alpha = 0.9f)
            )
        ),
        foregroundColor = Color.White
    ),

    /** Nature theme (Green/Blue gradient) */
    Nature(
        gradient = Brush.linearGradient(
            colors = listOf(
                LiquidGlassColors.brandGreen.copy(alpha = 0.95f),
                LiquidGlassColors.brandBlue.copy(alpha = 0.9f)
            )
        ),
        foregroundColor = Color.White
    )
}
