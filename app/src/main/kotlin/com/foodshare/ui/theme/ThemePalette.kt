package com.foodshare.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * Theme color palette - matches iOS ThemePalette structure
 *
 * Each theme defines both light and dark variants of these colors.
 */
data class ThemePalette(
    // Primary brand colors
    val primaryColor: Color,
    val secondaryColor: Color,

    // Accent colors for highlights and CTAs
    val accentPrimary: Color,
    val accentSecondary: Color,

    // Gradient colors
    val gradientStart: Color,
    val gradientEnd: Color,

    // Effects
    val glowColor: Color,
    val highlightColor: Color,

    // Backgrounds
    val background: Color,
    val surfaceBackground: Color,

    // Glass effect colors
    val glassBackground: Color,
    val glassBorder: Color,

    // Text colors
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color
)

/**
 * Theme ID enum matching iOS ThemeID
 */
enum class ThemeId(val displayName: String, val icon: String, val description: String) {
    NATURE("Nature", "🌿", "Earthy greens and sky blues"),
    BRAND("Brand", "💖", "Signature pink and teal"),
    OCEAN("Ocean", "🌊", "Deep blues and aquas"),
    SUNSET("Sunset", "🌅", "Warm oranges and purples"),
    FOREST("Forest", "🌲", "Deep greens and browns"),
    CORAL("Coral", "🪸", "Vibrant coral and turquoise"),
    MIDNIGHT("Midnight", "🌙", "Deep purples and blues"),
    MONOCHROME("Monochrome", "⚫", "Elegant grayscale")
}

/**
 * Color scheme preference
 */
enum class ColorSchemePreference {
    SYSTEM,
    LIGHT,
    DARK
}
