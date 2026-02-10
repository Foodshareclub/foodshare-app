package com.foodshare.ui.design.tokens

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

/**
 * Liquid Glass Design System v27 - Color Tokens
 * Single source of truth for all colors in the app
 *
 * Ported from iOS: LiquidGlassColors.swift
 */
object LiquidGlassColors {

    // MARK: - Opacity Tokens
    object Opacity {
        const val micro = 0.05f
        const val extraSubtle = 0.08f
        const val subtle = 0.1f
        const val semiLight = 0.12f
        const val light = 0.15f
        const val medium = 0.2f
        const val emphasized = 0.3f
        const val moderate = 0.4f
        const val prominent = 0.5f
        const val strong = 0.7f
        const val almostOpaque = 0.9f
    }

    // MARK: - Brand Colors (Foodshare Website Palette)
    val brandPink = Color(0xFFFF2D55)
    val brandTeal = Color(0xFF00A699)
    val brandOrange = Color(0xFFFC642D)
    val brandGreen = Color(0xFF2ECC71)
    val brandBlue = Color(0xFF3498DB)

    // MARK: - Primary Colors
    val primary = brandPink
    val primaryLight = brandPink.copy(alpha = Opacity.strong)
    val primaryDark = Color(0xFFE6284C)

    // MARK: - Status Colors
    val success = Color(0xFF27AE60)
    val warning = Color(0xFFF39C12)
    val error = Color(0xFFE74C3C)
    val info = Color(0xFF3498DB)

    // MARK: - Accent Colors
    val accentBlue = Color(0xFF007AFF)
    val accentCyan = Color(0xFF32D4DE)
    val accentPink = Color(0xFFE91E63)
    val accentPurple = Color(0xFF9B59B6)
    val accentYellow = Color(0xFFF1C40F)
    val accentOrange = Color(0xFFE67E22)
    val accentBrown = Color(0xFF8D6E63)
    val accentGray = Color(0xFF95A5A6)

    // MARK: - Glass Effect Colors
    object Glass {
        val micro = Color.White.copy(alpha = Opacity.micro)
        val extraSubtle = Color.White.copy(alpha = Opacity.extraSubtle)
        val background = Color.White.copy(alpha = Opacity.subtle)
        val semiLight = Color.White.copy(alpha = Opacity.semiLight)
        val surface = Color.White.copy(alpha = Opacity.light)
        val border = Color.White.copy(alpha = Opacity.medium)
        val highlight = Color.White.copy(alpha = Opacity.emphasized)
        val stroke = Color.White.copy(alpha = Opacity.medium)
        val overlay = Color.White.copy(alpha = Opacity.subtle)
    }

    // MARK: - Overlay Colors
    object Overlay {
        val light = Color.White.copy(alpha = 0.6f)
        val medium = Color.White.copy(alpha = 0.7f)
        val strong = Color.White.copy(alpha = 0.8f)
        val dark = Color.Black.copy(alpha = 0.3f)
        val shadow = Color.Black.copy(alpha = 0.15f)
        val scrim = Color.Black.copy(alpha = 0.4f)
    }

    // MARK: - Category Colors (Post Types)
    object Category {
        val food = Color(0xFF27AE60)        // Green - free food
        val thing = Color(0xFF3498DB)       // Blue - non-food items
        val borrow = Color(0xFF9B59B6)      // Purple - borrow items
        val wanted = Color(0xFFE67E22)      // Orange - wanted posts
        val fridge = Color(0xFF1ABC9C)      // Teal - community fridges
        val foodbank = Color(0xFF2980B9)    // Dark blue - food banks
        val business = Color(0xFF8E44AD)    // Purple - businesses
        val volunteer = Color(0xFFE91E63)   // Pink - volunteer
        val challenge = Color(0xFFF39C12)   // Yellow/Gold - challenges
        val zerowaste = Color(0xFF16A085)   // Teal - zero waste
        val vegan = Color(0xFF2ECC71)       // Bright green - vegan
        val community = Color(0xFF3498DB)   // Blue - community events
    }

    // MARK: - Legacy Category Colors (for backward compatibility)
    val categoryProduce = Color(0xFF27AE60)
    val categoryDairy = Color(0xFF3498DB)
    val categoryBakedGoods = Color(0xFFE67E22)
    val categoryPreparedMeals = Color(0xFFE74C3C)
    val categoryPantryItems = Color(0xFF95A5A6)

    // MARK: - Text Colors
    object Text {
        val primary = Color.White
        val secondary = Color.White.copy(alpha = 0.7f)
        val tertiary = Color.White.copy(alpha = 0.5f)
        val disabled = Color.White.copy(alpha = 0.3f)
    }

    // MARK: - Medal Colors (Leaderboard)
    val medalGold = Color(0xFFFFD700)
    val medalSilver = Color(0xFFC0C0C0)
    val medalBronze = Color(0xFFCD7F32)

    // MARK: - Contrast Colors
    val contrastText = Color.White
    val contrastTextSecondary = Color.White.copy(alpha = Opacity.almostOpaque)
    val contrastSubtle = Color.White.copy(alpha = Opacity.medium)
    val contrastShadow = Color.Black.copy(alpha = Opacity.light)

    // MARK: - Dark Auth Background Colors
    val darkAuthBase = Color.Black
    val darkAuthMid = Color(0xFF0D141F) // rgb(0.05, 0.08, 0.12)
    val darkAuthLight = Color(0xFF141F2E) // rgb(0.08, 0.12, 0.18)

    // MARK: - Legacy Colors
    val blueDark = Color(0xFF2C3E50)
    val blueLight = Color(0xFF5DADE2)
    val brandCyan = Color(0xFF1ABC9C)
    val brandPurple = Color(0xFF9B59B6)
}

/**
 * Liquid Glass Gradients
 */
object LiquidGlassGradients {

    /** Brand gradient (Pink -> Teal) */
    val brand = Brush.linearGradient(
        colors = listOf(
            LiquidGlassColors.brandPink.copy(alpha = 0.95f),
            LiquidGlassColors.brandTeal.copy(alpha = 0.9f)
        )
    )

    /** Primary gradient (Pink -> Darker Pink) */
    val primary = Brush.linearGradient(
        colors = listOf(
            LiquidGlassColors.primary,
            LiquidGlassColors.primaryDark
        )
    )

    /** Pink to Teal gradient */
    val pinkTeal = Brush.linearGradient(
        colors = listOf(
            LiquidGlassColors.brandPink,
            LiquidGlassColors.brandTeal
        )
    )

    /** Blue to Cyan gradient */
    val blueCyan = Brush.linearGradient(
        colors = listOf(
            LiquidGlassColors.accentBlue.copy(alpha = 0.95f),
            LiquidGlassColors.accentCyan.copy(alpha = 0.9f)
        )
    )

    /** Auth screen background gradient */
    val darkAuth = Brush.linearGradient(
        colors = listOf(
            LiquidGlassColors.darkAuthBase,
            LiquidGlassColors.darkAuthMid,
            LiquidGlassColors.darkAuthLight
        )
    )

    /** Nature accent gradient overlay */
    val natureAccent = Brush.verticalGradient(
        colors = listOf(
            LiquidGlassColors.brandGreen.copy(alpha = 0.35f),
            Color.Transparent,
            LiquidGlassColors.brandBlue.copy(alpha = 0.25f)
        )
    )

    /** Star rating gradient (gold -> orange) */
    val starRating = Brush.linearGradient(
        colors = listOf(
            LiquidGlassColors.medalGold,
            LiquidGlassColors.accentOrange
        )
    )

    /** Glass surface gradient (for cards) */
    val glassSurface = Brush.verticalGradient(
        colors = listOf(
            LiquidGlassColors.Glass.surface,
            LiquidGlassColors.Glass.background
        )
    )

    /** Glass border gradient */
    val glassBorder = Brush.linearGradient(
        colors = listOf(
            Color.White.copy(alpha = 0.4f),
            Color.White.copy(alpha = 0.15f)
        )
    )
}
