//
//  ForestTheme.swift
//  Foodshare
//
//  Forest Theme - Emerald/Moss
//  Deep forest greens, natural and grounded
//

import SwiftUI
import FoodShareDesignSystem

/// Forest theme with emerald and moss green colors
struct ForestTheme: Theme {
    let id = ThemeID.forest.rawValue
    let displayName = "Forest"
    let icon = "tree.fill"
    let description = "Deep forest greens"

    var previewColors: [Color] {
        [Color(hex: "2D6A4F"), Color(hex: "40916C")]
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
            // Primary gradient (emerald to moss)
            primaryColor: Color(hex: "2D6A4F"),
            secondaryColor: Color(hex: "40916C"),

            // Accents
            accentPrimary: Color(hex: "52B788"),
            accentSecondary: Color(hex: "74C69D"),

            // Gradients
            gradientStart: Color(hex: "2D6A4F"),
            gradientEnd: Color(hex: "40916C"),
            glowColor: Color(hex: "52B788"),
            highlightColor: Color(hex: "40916C").opacity(0.4),

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
            primaryColor: Color(hex: "1B4332"),
            secondaryColor: Color(hex: "2D6A4F"),

            // Accents
            accentPrimary: Color(hex: "40916C"),
            accentSecondary: Color(hex: "52B788"),

            // Gradients
            gradientStart: Color(hex: "1B4332"),
            gradientEnd: Color(hex: "2D6A4F"),
            glowColor: Color(hex: "40916C").opacity(0.5),
            highlightColor: Color(hex: "52B788").opacity(0.2),

            // Backgrounds (light with green tint)
            background: Color(hex: "F0FFF4"),
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
