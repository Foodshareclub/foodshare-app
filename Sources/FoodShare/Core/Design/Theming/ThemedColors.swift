//
//  ThemedColors.swift
//  Foodshare
//
//  Dynamic color provider bridging themes and design tokens
//


#if !SKIP
import SwiftUI

// MARK: - Themed Colors Extension

extension Color.DesignSystem {
    /// Access current theme's colors dynamically
    /// Usage: Color.DesignSystem.themed.primary
    @MainActor
    static var themed: ThemedColors { ThemedColors.current }
}

// MARK: - ThemedColors

/// Dynamic color provider that returns colors from the current theme
/// All properties are computed from ThemeManager's current palette
@MainActor
struct ThemedColors {
    /// Current themed colors instance
    static var current: ThemedColors { ThemedColors() }

    private var palette: ThemePalette { ThemeManager.shared.currentPalette }

    // MARK: - Primary Gradient Colors

    /// Primary theme color
    var primary: Color { palette.primaryColor }
    /// Secondary theme color
    var secondary: Color { palette.secondaryColor }

    // MARK: - Accent Colors

    /// Primary accent color
    var accentPrimary: Color { palette.accentPrimary }
    /// Secondary accent color
    var accentSecondary: Color { palette.accentSecondary }

    // MARK: - Gradient Colors

    /// Start color for main gradients
    var gradientStart: Color { palette.gradientStart }
    /// End color for main gradients
    var gradientEnd: Color { palette.gradientEnd }
    /// Glow effect color
    var glow: Color { palette.glowColor }
    /// Highlight color for selected states
    var highlight: Color { palette.highlightColor }

    // MARK: - Background Colors (Scheme-Aware)

    /// Main background color
    var background: Color { palette.background }
    /// Elevated surface background
    var surface: Color { palette.surfaceBackground }
    /// Glass effect background
    var glass: Color { palette.glassBackground }
    /// Glass border color
    var glassBorder: Color { palette.glassBorder }

    // MARK: - Text Colors (Scheme-Aware)

    /// Primary text color
    var textPrimary: Color { palette.textPrimary }
    /// Secondary text color
    var textSecondary: Color { palette.textSecondary }
    /// Tertiary text color
    var textTertiary: Color { palette.textTertiary }

    // MARK: - Gradient Helpers

    /// Primary gradient using theme colors
    var primaryGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart, gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    /// Subtle gradient for backgrounds
    var subtleGradient: LinearGradient {
        LinearGradient(
            colors: [gradientStart.opacity(0.3), gradientEnd.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }

    /// Glow gradient for effects
    var glowGradient: RadialGradient {
        RadialGradient(
            colors: [glow.opacity(0.6), glow.opacity(0.2), Color.clear],
            center: .center,
            startRadius: 0,
            endRadius: 100,
        )
    }
}

#endif
