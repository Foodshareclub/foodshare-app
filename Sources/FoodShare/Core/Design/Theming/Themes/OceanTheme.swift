//
//  OceanTheme.swift
//  Foodshare
//
//  Ocean Theme - Blue/Cyan
//  Deep sea vibes with cool, calming colors
//

import SwiftUI
import FoodShareDesignSystem

/// Ocean theme with blue and cyan colors
struct OceanTheme: Theme {
    let id = ThemeID.ocean.rawValue
    let displayName = "Ocean"
    let icon = "water.waves"
    let description = "Deep sea vibes"

    var previewColors: [Color] {
        [Color.DesignSystem.accentBlue, Color.DesignSystem.accentCyan]
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
            primaryColor: Color.DesignSystem.accentBlue,
            secondaryColor: Color.DesignSystem.accentCyan,

            // Accents
            accentPrimary: Color.DesignSystem.accentBlue,
            accentSecondary: Color.DesignSystem.accentCyan,

            // Gradients
            gradientStart: Color.DesignSystem.accentBlue,
            gradientEnd: Color.DesignSystem.accentCyan,
            glowColor: Color.DesignSystem.accentCyan,
            highlightColor: Color.DesignSystem.accentBlue.opacity(0.4),

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
            // Primary gradient
            primaryColor: Color(hex: "0066CC"),
            secondaryColor: Color(hex: "00A3CC"),

            // Accents
            accentPrimary: Color(hex: "0066CC"),
            accentSecondary: Color(hex: "00A3CC"),

            // Gradients
            gradientStart: Color(hex: "0066CC"),
            gradientEnd: Color(hex: "00A3CC"),
            glowColor: Color(hex: "0066CC").opacity(0.5),
            highlightColor: Color(hex: "00A3CC").opacity(0.2),

            // Backgrounds (light with blue tint)
            background: Color(hex: "F0F8FF"),
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
