//
//  NatureTheme.swift
//  Foodshare
//
//  Nature Theme - Green/Blue
//  Earthy and fresh, inspired by nature and sustainability
//  Current default theme for the app
//

import SwiftUI
import FoodShareDesignSystem

/// Nature theme with green and blue colors
/// Represents sustainability and freshness
struct NatureTheme: Theme {
    let id = ThemeID.nature.rawValue
    let displayName = "Nature"
    let icon = "leaf.fill"
    let description = "Earthy greens and sky blues"

    var previewColors: [Color] {
        [Color.DesignSystem.brandGreen, Color.DesignSystem.brandBlue]
    }

    func palette(for scheme: ColorScheme) -> ThemePalette {
        switch scheme {
        case .dark:
            return darkPalette
        case .light:
            return lightPalette
        @unknown default:
            return darkPalette
        }
    }

    // MARK: - Dark Palette

    private var darkPalette: ThemePalette {
        ThemePalette(
            // Primary gradient
            primaryColor: Color.DesignSystem.brandGreen,
            secondaryColor: Color.DesignSystem.brandBlue,

            // Accents
            accentPrimary: Color.DesignSystem.brandGreen,
            accentSecondary: Color.DesignSystem.brandBlue,

            // Gradients
            gradientStart: Color.DesignSystem.brandGreen,
            gradientEnd: Color.DesignSystem.brandBlue,
            glowColor: Color.DesignSystem.brandGreen,
            highlightColor: Color.DesignSystem.brandBlue.opacity(0.4),

            // Backgrounds (Apple HIG dark mode)
            background: Color(hex: "1C1C1E"),
            surfaceBackground: Color(hex: "2C2C2E"),
            glassBackground: Color.white.opacity(0.10),
            glassBorder: Color.white.opacity(0.10),

            // Text (Apple HIG dark mode labels)
            textPrimary: Color.white,
            textSecondary: Color.white.opacity(0.6),
            textTertiary: Color.white.opacity(0.3),
        )
    }

    // MARK: - Light Palette

    private var lightPalette: ThemePalette {
        ThemePalette(
            // Primary gradient (slightly adjusted for light mode)
            primaryColor: Color(hex: "27AE60"), // Slightly darker green
            secondaryColor: Color(hex: "2980B9"), // Slightly darker blue

            // Accents
            accentPrimary: Color(hex: "27AE60"),
            accentSecondary: Color(hex: "2980B9"),

            // Gradients
            gradientStart: Color(hex: "27AE60"),
            gradientEnd: Color(hex: "2980B9"),
            glowColor: Color(hex: "27AE60").opacity(0.5),
            highlightColor: Color(hex: "2980B9").opacity(0.2),

            // Backgrounds (light)
            background: Color(hex: "F8F9FA"),
            surfaceBackground: Color.white,
            glassBackground: Color.black.opacity(0.05),
            glassBorder: Color.black.opacity(0.15),

            // Text (dark on light)
            textPrimary: Color(hex: "1A1A1A"),
            textSecondary: Color(hex: "1A1A1A").opacity(0.7),
            textTertiary: Color(hex: "1A1A1A").opacity(0.5),
        )
    }
}
