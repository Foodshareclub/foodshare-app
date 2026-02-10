package com.foodshare.ui.design.components.cards

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.foodshare.ui.design.tokens.CornerRadius
import com.foodshare.ui.design.tokens.LiquidGlassColors
import com.foodshare.ui.design.tokens.LiquidGlassGradients

/**
 * Glassmorphism card component - Core of Liquid Glass design system
 *
 * Ported from iOS: GlassCard.swift
 *
 * Features:
 * - Frosted glass effect with gradient background
 * - Subtle border for depth
 * - Configurable shadow levels
 * - GPU-optimized rendering
 */
@Composable
fun GlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = CornerRadius.medium,
    shadow: GlassShadow = GlassShadow.Medium,
    content: @Composable BoxScope.() -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)

    Box(
        modifier = modifier
            .shadow(
                elevation = shadow.elevation,
                shape = shape,
                spotColor = Color.Black.copy(alpha = shadow.opacity)
            )
            .clip(shape)
            .background(brush = LiquidGlassGradients.glassSurface)
            .border(
                width = 1.dp,
                color = LiquidGlassColors.Glass.border,
                shape = shape
            ),
        content = content
    )
}

/**
 * Glass card with solid background (for accessibility/reduced transparency)
 */
@Composable
fun SolidGlassCard(
    modifier: Modifier = Modifier,
    cornerRadius: Dp = CornerRadius.medium,
    shadow: GlassShadow = GlassShadow.Medium,
    backgroundColor: Color = Color.White.copy(alpha = 0.95f),
    content: @Composable BoxScope.() -> Unit
) {
    val shape = RoundedCornerShape(cornerRadius)

    Box(
        modifier = modifier
            .shadow(
                elevation = shadow.elevation,
                shape = shape,
                spotColor = Color.Black.copy(alpha = shadow.opacity)
            )
            .clip(shape)
            .background(color = backgroundColor)
            .border(
                width = 1.dp,
                color = LiquidGlassColors.Glass.border,
                shape = shape
            ),
        content = content
    )
}

/**
 * Shadow presets for glass cards
 */
enum class GlassShadow(
    val elevation: Dp,
    val opacity: Float,
    val radius: Dp,
    val offset: Dp
) {
    /** Subtle shadow for minimal depth */
    Subtle(
        elevation = 4.dp,
        opacity = 0.10f,
        radius = 10.dp,
        offset = 4.dp
    ),

    /** Medium shadow for standard cards */
    Medium(
        elevation = 8.dp,
        opacity = 0.15f,
        radius = 20.dp,
        offset = 8.dp
    ),

    /** Strong shadow for emphasized elements */
    Strong(
        elevation = 12.dp,
        opacity = 0.20f,
        radius = 30.dp,
        offset = 12.dp
    )
}

/**
 * Modifier extension for glass card effect
 */
fun Modifier.glassCard(
    cornerRadius: Dp = CornerRadius.medium,
    shadow: GlassShadow = GlassShadow.Medium
): Modifier {
    val shape = RoundedCornerShape(cornerRadius)
    return this
        .shadow(
            elevation = shadow.elevation,
            shape = shape,
            spotColor = Color.Black.copy(alpha = shadow.opacity)
        )
        .clip(shape)
        .background(brush = LiquidGlassGradients.glassSurface)
        .border(
            width = 1.dp,
            color = LiquidGlassColors.Glass.border,
            shape = shape
        )
}

/**
 * Modifier for glass background only (without shadow)
 */
fun Modifier.glassBackground(
    cornerRadius: Dp = CornerRadius.medium
): Modifier {
    val shape = RoundedCornerShape(cornerRadius)
    return this
        .clip(shape)
        .background(brush = LiquidGlassGradients.glassSurface)
        .border(
            width = 1.dp,
            color = LiquidGlassColors.Glass.border,
            shape = shape
        )
}
