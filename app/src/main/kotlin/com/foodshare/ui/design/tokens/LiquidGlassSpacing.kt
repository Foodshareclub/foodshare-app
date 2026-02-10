package com.foodshare.ui.design.tokens

import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Liquid Glass Spacing & Layout System v26
 *
 * Based on 8pt grid system
 * Ported from iOS: LiquidGlassSpacing.swift
 */
object Spacing {
    // MARK: - Base Unit (8dp grid)
    val unit: Dp = 8.dp

    // MARK: - Semantic Spacing
    val xxxs: Dp = 4.dp   // unit * 0.5
    val xxs: Dp = 8.dp    // unit
    val xs: Dp = 12.dp    // unit * 1.5
    val sm: Dp = 16.dp    // unit * 2
    val md: Dp = 24.dp    // unit * 3
    val lg: Dp = 32.dp    // unit * 4
    val xl: Dp = 40.dp    // unit * 5
    val xxl: Dp = 48.dp   // unit * 6
    val xxxl: Dp = 64.dp  // unit * 8

    // MARK: - Component-specific spacing
    val buttonPaddingHorizontal: Dp = md
    val buttonPaddingVertical: Dp = sm
    val cardPadding: Dp = md
    val listItemPadding: Dp = sm
    val screenPadding: Dp = md
    val sectionSpacing: Dp = lg
}

/**
 * Corner Radius tokens for consistent rounding
 */
object CornerRadius {
    /** 4dp - extra small (badges, pills) */
    val xs: Dp = 4.dp

    /** 8dp - small (chips, small cards) */
    val small: Dp = 8.dp

    /** 12dp - medium (cards, inputs) */
    val medium: Dp = 12.dp

    /** 16dp - large (modals, sheets) */
    val large: Dp = 16.dp

    /** 20dp - extra large */
    val xl: Dp = 20.dp

    /** 24dp - extra extra large (full-screen overlays) */
    val xxl: Dp = 24.dp

    /** 28dp - for large buttons */
    val button: Dp = 28.dp

    /** 9999dp - fully rounded (pills, avatars) */
    val full: Dp = 9999.dp
}

/**
 * Shadow elevation tokens
 */
object Elevation {
    val none: Dp = 0.dp
    val xs: Dp = 1.dp
    val sm: Dp = 2.dp
    val md: Dp = 4.dp
    val lg: Dp = 8.dp
    val xl: Dp = 16.dp
    val xxl: Dp = 24.dp
}

/**
 * Component size tokens
 */
object ComponentSize {
    // Buttons
    val buttonHeightSmall: Dp = 36.dp
    val buttonHeightMedium: Dp = 48.dp
    val buttonHeightLarge: Dp = 56.dp
    val buttonHeightXLarge: Dp = 58.dp

    // Icons
    val iconXs: Dp = 16.dp
    val iconSm: Dp = 20.dp
    val iconMd: Dp = 24.dp
    val iconLg: Dp = 32.dp
    val iconXl: Dp = 48.dp

    // Avatars
    val avatarSm: Dp = 32.dp
    val avatarMd: Dp = 48.dp
    val avatarLg: Dp = 64.dp
    val avatarXl: Dp = 100.dp

    // Cards
    val cardImageHeightCompact: Dp = 120.dp
    val cardImageHeightStandard: Dp = 180.dp
    val cardImageHeightFeatured: Dp = 220.dp

    // Inputs
    val inputHeight: Dp = 56.dp
    val inputHeightLarge: Dp = 64.dp

    // Bottom navigation
    val bottomNavHeight: Dp = 80.dp
    val tabBarHeight: Dp = 56.dp
}
