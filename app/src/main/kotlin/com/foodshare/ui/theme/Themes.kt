package com.foodshare.ui.theme

import androidx.compose.ui.graphics.Color
import com.foodshare.ui.design.tokens.LiquidGlassColors

/**
 * Theme definitions matching iOS themes
 *
 * Each theme provides light and dark palettes.
 */
sealed class FoodShareTheme(
    val id: ThemeId,
    val previewColors: List<Color>
) {
    abstract fun palette(isDark: Boolean): ThemePalette

    // ============================================================================
    // Nature Theme - Earthy greens and sky blues
    // ============================================================================
    data object Nature : FoodShareTheme(
        id = ThemeId.NATURE,
        previewColors = listOf(LiquidGlassColors.brandGreen, LiquidGlassColors.brandBlue)
    ) {
        override fun palette(isDark: Boolean): ThemePalette = if (isDark) {
            ThemePalette(
                primaryColor = Color(0xFF2ECC71),
                secondaryColor = Color(0xFF3498DB),
                accentPrimary = Color(0xFF27AE60),
                accentSecondary = Color(0xFF2980B9),
                gradientStart = Color(0xFF2ECC71),
                gradientEnd = Color(0xFF3498DB),
                glowColor = Color(0xFF2ECC71).copy(alpha = 0.4f),
                highlightColor = Color(0xFF3498DB).copy(alpha = 0.3f),
                background = Color(0xFF0F1A14),
                surfaceBackground = Color(0xFF1A2A1F),
                glassBackground = Color.White.copy(alpha = 0.08f),
                glassBorder = Color.White.copy(alpha = 0.15f),
                textPrimary = Color.White,
                textSecondary = Color.White.copy(alpha = 0.7f),
                textTertiary = Color.White.copy(alpha = 0.5f)
            )
        } else {
            ThemePalette(
                primaryColor = Color(0xFF27AE60),
                secondaryColor = Color(0xFF2980B9),
                accentPrimary = Color(0xFF2ECC71),
                accentSecondary = Color(0xFF3498DB),
                gradientStart = Color(0xFF2ECC71),
                gradientEnd = Color(0xFF3498DB),
                glowColor = Color(0xFF2ECC71).copy(alpha = 0.25f),
                highlightColor = Color(0xFF3498DB).copy(alpha = 0.2f),
                background = Color(0xFFF0FAF4),
                surfaceBackground = Color.White,
                glassBackground = Color.White.copy(alpha = 0.7f),
                glassBorder = Color.White.copy(alpha = 0.5f),
                textPrimary = Color(0xFF1A1A1A),
                textSecondary = Color(0xFF1A1A1A).copy(alpha = 0.7f),
                textTertiary = Color(0xFF1A1A1A).copy(alpha = 0.5f)
            )
        }
    }

    // ============================================================================
    // Brand Theme - Signature pink and teal
    // ============================================================================
    data object Brand : FoodShareTheme(
        id = ThemeId.BRAND,
        previewColors = listOf(LiquidGlassColors.brandPink, LiquidGlassColors.brandTeal)
    ) {
        override fun palette(isDark: Boolean): ThemePalette = if (isDark) {
            ThemePalette(
                primaryColor = LiquidGlassColors.brandPink,
                secondaryColor = LiquidGlassColors.brandTeal,
                accentPrimary = Color(0xFFFF4D6D),
                accentSecondary = Color(0xFF00C9B7),
                gradientStart = LiquidGlassColors.brandPink,
                gradientEnd = LiquidGlassColors.brandTeal,
                glowColor = LiquidGlassColors.brandPink.copy(alpha = 0.4f),
                highlightColor = LiquidGlassColors.brandTeal.copy(alpha = 0.3f),
                background = Color(0xFF121212),
                surfaceBackground = Color(0xFF1E1E1E),
                glassBackground = Color.White.copy(alpha = 0.08f),
                glassBorder = Color.White.copy(alpha = 0.15f),
                textPrimary = Color.White,
                textSecondary = Color.White.copy(alpha = 0.7f),
                textTertiary = Color.White.copy(alpha = 0.5f)
            )
        } else {
            ThemePalette(
                primaryColor = LiquidGlassColors.brandPink,
                secondaryColor = LiquidGlassColors.brandTeal,
                accentPrimary = Color(0xFFE6284C),
                accentSecondary = Color(0xFF008F80),
                gradientStart = LiquidGlassColors.brandPink,
                gradientEnd = LiquidGlassColors.brandTeal,
                glowColor = LiquidGlassColors.brandPink.copy(alpha = 0.25f),
                highlightColor = LiquidGlassColors.brandTeal.copy(alpha = 0.2f),
                background = Color(0xFFF5F5F5),
                surfaceBackground = Color.White,
                glassBackground = Color.White.copy(alpha = 0.7f),
                glassBorder = Color.White.copy(alpha = 0.5f),
                textPrimary = Color(0xFF1A1A1A),
                textSecondary = Color(0xFF1A1A1A).copy(alpha = 0.7f),
                textTertiary = Color(0xFF1A1A1A).copy(alpha = 0.5f)
            )
        }
    }

    // ============================================================================
    // Ocean Theme - Deep blues and aquas
    // ============================================================================
    data object Ocean : FoodShareTheme(
        id = ThemeId.OCEAN,
        previewColors = listOf(Color(0xFF0077B6), Color(0xFF00B4D8))
    ) {
        override fun palette(isDark: Boolean): ThemePalette = if (isDark) {
            ThemePalette(
                primaryColor = Color(0xFF0077B6),
                secondaryColor = Color(0xFF00B4D8),
                accentPrimary = Color(0xFF0096C7),
                accentSecondary = Color(0xFF48CAE4),
                gradientStart = Color(0xFF0077B6),
                gradientEnd = Color(0xFF00B4D8),
                glowColor = Color(0xFF00B4D8).copy(alpha = 0.4f),
                highlightColor = Color(0xFF48CAE4).copy(alpha = 0.3f),
                background = Color(0xFF0A1929),
                surfaceBackground = Color(0xFF0D2137),
                glassBackground = Color.White.copy(alpha = 0.08f),
                glassBorder = Color.White.copy(alpha = 0.15f),
                textPrimary = Color.White,
                textSecondary = Color.White.copy(alpha = 0.7f),
                textTertiary = Color.White.copy(alpha = 0.5f)
            )
        } else {
            ThemePalette(
                primaryColor = Color(0xFF0077B6),
                secondaryColor = Color(0xFF00B4D8),
                accentPrimary = Color(0xFF005F8A),
                accentSecondary = Color(0xFF0096C7),
                gradientStart = Color(0xFF0077B6),
                gradientEnd = Color(0xFF00B4D8),
                glowColor = Color(0xFF00B4D8).copy(alpha = 0.25f),
                highlightColor = Color(0xFF48CAE4).copy(alpha = 0.2f),
                background = Color(0xFFE8F4F8),
                surfaceBackground = Color.White,
                glassBackground = Color.White.copy(alpha = 0.7f),
                glassBorder = Color.White.copy(alpha = 0.5f),
                textPrimary = Color(0xFF0A1929),
                textSecondary = Color(0xFF0A1929).copy(alpha = 0.7f),
                textTertiary = Color(0xFF0A1929).copy(alpha = 0.5f)
            )
        }
    }

    // ============================================================================
    // Sunset Theme - Warm oranges and purples
    // ============================================================================
    data object Sunset : FoodShareTheme(
        id = ThemeId.SUNSET,
        previewColors = listOf(Color(0xFFFF6B35), Color(0xFF9B59B6))
    ) {
        override fun palette(isDark: Boolean): ThemePalette = if (isDark) {
            ThemePalette(
                primaryColor = Color(0xFFFF6B35),
                secondaryColor = Color(0xFF9B59B6),
                accentPrimary = Color(0xFFFF8C5A),
                accentSecondary = Color(0xFFB370CF),
                gradientStart = Color(0xFFFF6B35),
                gradientEnd = Color(0xFF9B59B6),
                glowColor = Color(0xFFFF6B35).copy(alpha = 0.4f),
                highlightColor = Color(0xFF9B59B6).copy(alpha = 0.3f),
                background = Color(0xFF1A0F14),
                surfaceBackground = Color(0xFF2A1A22),
                glassBackground = Color.White.copy(alpha = 0.08f),
                glassBorder = Color.White.copy(alpha = 0.15f),
                textPrimary = Color.White,
                textSecondary = Color.White.copy(alpha = 0.7f),
                textTertiary = Color.White.copy(alpha = 0.5f)
            )
        } else {
            ThemePalette(
                primaryColor = Color(0xFFE65A2E),
                secondaryColor = Color(0xFF8E44AD),
                accentPrimary = Color(0xFFFF6B35),
                accentSecondary = Color(0xFF9B59B6),
                gradientStart = Color(0xFFFF6B35),
                gradientEnd = Color(0xFF9B59B6),
                glowColor = Color(0xFFFF6B35).copy(alpha = 0.25f),
                highlightColor = Color(0xFF9B59B6).copy(alpha = 0.2f),
                background = Color(0xFFFFF5F0),
                surfaceBackground = Color.White,
                glassBackground = Color.White.copy(alpha = 0.7f),
                glassBorder = Color.White.copy(alpha = 0.5f),
                textPrimary = Color(0xFF1A1A1A),
                textSecondary = Color(0xFF1A1A1A).copy(alpha = 0.7f),
                textTertiary = Color(0xFF1A1A1A).copy(alpha = 0.5f)
            )
        }
    }

    // ============================================================================
    // Forest Theme - Deep greens and browns
    // ============================================================================
    data object Forest : FoodShareTheme(
        id = ThemeId.FOREST,
        previewColors = listOf(Color(0xFF1B4332), Color(0xFF8B4513))
    ) {
        override fun palette(isDark: Boolean): ThemePalette = if (isDark) {
            ThemePalette(
                primaryColor = Color(0xFF2D6A4F),
                secondaryColor = Color(0xFFA0522D),
                accentPrimary = Color(0xFF40916C),
                accentSecondary = Color(0xFFCD853F),
                gradientStart = Color(0xFF2D6A4F),
                gradientEnd = Color(0xFFA0522D),
                glowColor = Color(0xFF40916C).copy(alpha = 0.4f),
                highlightColor = Color(0xFFCD853F).copy(alpha = 0.3f),
                background = Color(0xFF0D1F17),
                surfaceBackground = Color(0xFF142E22),
                glassBackground = Color.White.copy(alpha = 0.08f),
                glassBorder = Color.White.copy(alpha = 0.15f),
                textPrimary = Color.White,
                textSecondary = Color.White.copy(alpha = 0.7f),
                textTertiary = Color.White.copy(alpha = 0.5f)
            )
        } else {
            ThemePalette(
                primaryColor = Color(0xFF1B4332),
                secondaryColor = Color(0xFF8B4513),
                accentPrimary = Color(0xFF2D6A4F),
                accentSecondary = Color(0xFFA0522D),
                gradientStart = Color(0xFF2D6A4F),
                gradientEnd = Color(0xFFA0522D),
                glowColor = Color(0xFF2D6A4F).copy(alpha = 0.25f),
                highlightColor = Color(0xFFA0522D).copy(alpha = 0.2f),
                background = Color(0xFFF0F5F2),
                surfaceBackground = Color.White,
                glassBackground = Color.White.copy(alpha = 0.7f),
                glassBorder = Color.White.copy(alpha = 0.5f),
                textPrimary = Color(0xFF1A1A1A),
                textSecondary = Color(0xFF1A1A1A).copy(alpha = 0.7f),
                textTertiary = Color(0xFF1A1A1A).copy(alpha = 0.5f)
            )
        }
    }

    // ============================================================================
    // Coral Theme - Vibrant coral and turquoise
    // ============================================================================
    data object Coral : FoodShareTheme(
        id = ThemeId.CORAL,
        previewColors = listOf(Color(0xFFFF7F7F), Color(0xFF40E0D0))
    ) {
        override fun palette(isDark: Boolean): ThemePalette = if (isDark) {
            ThemePalette(
                primaryColor = Color(0xFFFF6B6B),
                secondaryColor = Color(0xFF4ECDC4),
                accentPrimary = Color(0xFFFF8A8A),
                accentSecondary = Color(0xFF6FE7DE),
                gradientStart = Color(0xFFFF6B6B),
                gradientEnd = Color(0xFF4ECDC4),
                glowColor = Color(0xFFFF6B6B).copy(alpha = 0.4f),
                highlightColor = Color(0xFF4ECDC4).copy(alpha = 0.3f),
                background = Color(0xFF1A1214),
                surfaceBackground = Color(0xFF2A1C20),
                glassBackground = Color.White.copy(alpha = 0.08f),
                glassBorder = Color.White.copy(alpha = 0.15f),
                textPrimary = Color.White,
                textSecondary = Color.White.copy(alpha = 0.7f),
                textTertiary = Color.White.copy(alpha = 0.5f)
            )
        } else {
            ThemePalette(
                primaryColor = Color(0xFFFF5252),
                secondaryColor = Color(0xFF26A69A),
                accentPrimary = Color(0xFFFF6B6B),
                accentSecondary = Color(0xFF4ECDC4),
                gradientStart = Color(0xFFFF6B6B),
                gradientEnd = Color(0xFF4ECDC4),
                glowColor = Color(0xFFFF6B6B).copy(alpha = 0.25f),
                highlightColor = Color(0xFF4ECDC4).copy(alpha = 0.2f),
                background = Color(0xFFFFF5F5),
                surfaceBackground = Color.White,
                glassBackground = Color.White.copy(alpha = 0.7f),
                glassBorder = Color.White.copy(alpha = 0.5f),
                textPrimary = Color(0xFF1A1A1A),
                textSecondary = Color(0xFF1A1A1A).copy(alpha = 0.7f),
                textTertiary = Color(0xFF1A1A1A).copy(alpha = 0.5f)
            )
        }
    }

    // ============================================================================
    // Midnight Theme - Deep purples and blues
    // ============================================================================
    data object Midnight : FoodShareTheme(
        id = ThemeId.MIDNIGHT,
        previewColors = listOf(Color(0xFF6C5CE7), Color(0xFF0984E3))
    ) {
        override fun palette(isDark: Boolean): ThemePalette = if (isDark) {
            ThemePalette(
                primaryColor = Color(0xFF6C5CE7),
                secondaryColor = Color(0xFF0984E3),
                accentPrimary = Color(0xFF8B7CF7),
                accentSecondary = Color(0xFF3498DB),
                gradientStart = Color(0xFF6C5CE7),
                gradientEnd = Color(0xFF0984E3),
                glowColor = Color(0xFF6C5CE7).copy(alpha = 0.4f),
                highlightColor = Color(0xFF0984E3).copy(alpha = 0.3f),
                background = Color(0xFF0F0A1A),
                surfaceBackground = Color(0xFF1A1428),
                glassBackground = Color.White.copy(alpha = 0.08f),
                glassBorder = Color.White.copy(alpha = 0.15f),
                textPrimary = Color.White,
                textSecondary = Color.White.copy(alpha = 0.7f),
                textTertiary = Color.White.copy(alpha = 0.5f)
            )
        } else {
            ThemePalette(
                primaryColor = Color(0xFF5B4BD5),
                secondaryColor = Color(0xFF0773D0),
                accentPrimary = Color(0xFF6C5CE7),
                accentSecondary = Color(0xFF0984E3),
                gradientStart = Color(0xFF6C5CE7),
                gradientEnd = Color(0xFF0984E3),
                glowColor = Color(0xFF6C5CE7).copy(alpha = 0.25f),
                highlightColor = Color(0xFF0984E3).copy(alpha = 0.2f),
                background = Color(0xFFF5F3FF),
                surfaceBackground = Color.White,
                glassBackground = Color.White.copy(alpha = 0.7f),
                glassBorder = Color.White.copy(alpha = 0.5f),
                textPrimary = Color(0xFF1A1A1A),
                textSecondary = Color(0xFF1A1A1A).copy(alpha = 0.7f),
                textTertiary = Color(0xFF1A1A1A).copy(alpha = 0.5f)
            )
        }
    }

    // ============================================================================
    // Monochrome Theme - Elegant grayscale
    // ============================================================================
    data object Monochrome : FoodShareTheme(
        id = ThemeId.MONOCHROME,
        previewColors = listOf(Color(0xFF2D2D2D), Color(0xFF6E6E6E))
    ) {
        override fun palette(isDark: Boolean): ThemePalette = if (isDark) {
            ThemePalette(
                primaryColor = Color(0xFF9E9E9E),
                secondaryColor = Color(0xFF757575),
                accentPrimary = Color(0xFFBDBDBD),
                accentSecondary = Color(0xFF9E9E9E),
                gradientStart = Color(0xFF616161),
                gradientEnd = Color(0xFF424242),
                glowColor = Color.White.copy(alpha = 0.2f),
                highlightColor = Color.White.copy(alpha = 0.15f),
                background = Color(0xFF121212),
                surfaceBackground = Color(0xFF1E1E1E),
                glassBackground = Color.White.copy(alpha = 0.08f),
                glassBorder = Color.White.copy(alpha = 0.15f),
                textPrimary = Color.White,
                textSecondary = Color.White.copy(alpha = 0.7f),
                textTertiary = Color.White.copy(alpha = 0.5f)
            )
        } else {
            ThemePalette(
                primaryColor = Color(0xFF424242),
                secondaryColor = Color(0xFF616161),
                accentPrimary = Color(0xFF212121),
                accentSecondary = Color(0xFF424242),
                gradientStart = Color(0xFF424242),
                gradientEnd = Color(0xFF757575),
                glowColor = Color(0xFF424242).copy(alpha = 0.2f),
                highlightColor = Color(0xFF757575).copy(alpha = 0.15f),
                background = Color(0xFFFAFAFA),
                surfaceBackground = Color.White,
                glassBackground = Color.White.copy(alpha = 0.7f),
                glassBorder = Color.White.copy(alpha = 0.5f),
                textPrimary = Color(0xFF212121),
                textSecondary = Color(0xFF212121).copy(alpha = 0.7f),
                textTertiary = Color(0xFF212121).copy(alpha = 0.5f)
            )
        }
    }

    companion object {
        /** All available themes */
        val allThemes: List<FoodShareTheme> = listOf(
            Nature, Brand, Ocean, Sunset, Forest, Coral, Midnight, Monochrome
        )

        /** Get theme by ID */
        fun fromId(id: ThemeId): FoodShareTheme = when (id) {
            ThemeId.NATURE -> Nature
            ThemeId.BRAND -> Brand
            ThemeId.OCEAN -> Ocean
            ThemeId.SUNSET -> Sunset
            ThemeId.FOREST -> Forest
            ThemeId.CORAL -> Coral
            ThemeId.MIDNIGHT -> Midnight
            ThemeId.MONOCHROME -> Monochrome
        }

        /** Get theme by string ID */
        fun fromIdString(idString: String): FoodShareTheme {
            val themeId = ThemeId.entries.find { it.name == idString.uppercase() } ?: ThemeId.BRAND
            return fromId(themeId)
        }
    }
}
