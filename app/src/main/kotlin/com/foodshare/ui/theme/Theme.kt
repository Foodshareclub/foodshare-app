package com.foodshare.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat
import com.foodshare.ui.design.tokens.LiquidGlassColors

/**
 * FoodShare Theme - Liquid Glass Design System
 *
 * Uses dynamic theme colors from ThemeManager with 8 switchable themes.
 */

// Composition local for theme palette access
val LocalThemePalette = compositionLocalOf<ThemePalette> {
    error("No ThemePalette provided")
}

/**
 * Build Material 3 light color scheme from theme palette
 */
private fun buildLightColorScheme(palette: ThemePalette) = lightColorScheme(
    primary = palette.primaryColor,
    onPrimary = Color.White,
    primaryContainer = palette.primaryColor.copy(alpha = 0.12f),
    onPrimaryContainer = palette.primaryColor,
    secondary = palette.secondaryColor,
    onSecondary = Color.White,
    secondaryContainer = palette.secondaryColor.copy(alpha = 0.12f),
    onSecondaryContainer = palette.secondaryColor,
    tertiary = palette.accentPrimary,
    onTertiary = Color.White,
    tertiaryContainer = palette.accentPrimary.copy(alpha = 0.12f),
    onTertiaryContainer = palette.accentPrimary,
    background = palette.background,
    onBackground = palette.textPrimary,
    surface = palette.surfaceBackground,
    onSurface = palette.textPrimary,
    surfaceVariant = palette.glassBackground,
    onSurfaceVariant = palette.textSecondary,
    error = LiquidGlassColors.error,
    onError = Color.White,
    errorContainer = LiquidGlassColors.error.copy(alpha = 0.12f),
    onErrorContainer = LiquidGlassColors.error,
    outline = palette.glassBorder,
    outlineVariant = palette.glassBorder.copy(alpha = 0.5f),
    scrim = Color.Black.copy(alpha = 0.4f)
)

/**
 * Build Material 3 dark color scheme from theme palette
 */
private fun buildDarkColorScheme(palette: ThemePalette) = darkColorScheme(
    primary = palette.primaryColor,
    onPrimary = Color.White,
    primaryContainer = palette.primaryColor.copy(alpha = 0.24f),
    onPrimaryContainer = palette.primaryColor.copy(alpha = 0.9f),
    secondary = palette.secondaryColor,
    onSecondary = Color.White,
    secondaryContainer = palette.secondaryColor.copy(alpha = 0.24f),
    onSecondaryContainer = palette.secondaryColor.copy(alpha = 0.9f),
    tertiary = palette.accentPrimary,
    onTertiary = Color.White,
    tertiaryContainer = palette.accentPrimary.copy(alpha = 0.24f),
    onTertiaryContainer = palette.accentPrimary.copy(alpha = 0.9f),
    background = palette.background,
    onBackground = palette.textPrimary,
    surface = palette.surfaceBackground,
    onSurface = palette.textPrimary,
    surfaceVariant = palette.glassBackground,
    onSurfaceVariant = palette.textSecondary,
    error = LiquidGlassColors.error,
    onError = Color.White,
    errorContainer = LiquidGlassColors.error.copy(alpha = 0.24f),
    onErrorContainer = LiquidGlassColors.error.copy(alpha = 0.9f),
    outline = palette.glassBorder,
    outlineVariant = palette.glassBorder.copy(alpha = 0.5f),
    scrim = Color.Black.copy(alpha = 0.6f)
)

@Composable
fun FoodShareTheme(
    content: @Composable () -> Unit
) {
    // Get theme state from ThemeManager
    val currentTheme by ThemeManager.currentTheme.collectAsState()
    val schemePreference by ThemeManager.colorSchemePreference.collectAsState()

    // Determine if dark mode is active
    val isDark = when (schemePreference) {
        ColorSchemePreference.LIGHT -> false
        ColorSchemePreference.DARK -> true
        ColorSchemePreference.SYSTEM -> isSystemInDarkTheme()
    }

    // Get palette for current theme and color scheme
    val palette = currentTheme.palette(isDark)
    val colorScheme = if (isDark) buildDarkColorScheme(palette) else buildLightColorScheme(palette)

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !isDark
        }
    }

    CompositionLocalProvider(LocalThemePalette provides palette) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = Typography,
            content = content
        )
    }
}
