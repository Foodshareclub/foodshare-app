//
//  BrandTheme.swift
//  Foodshare
//
//  Brand Theme - Pink/Teal
//  Original Foodshare brand colors from the website
//


#if !SKIP
import SwiftUI

/// Original Foodshare brand theme with pink and teal
struct BrandTheme: Theme {
    let id = ThemeID.brand.rawValue
    let displayName = "Foodshare"
    let icon = "heart.fill"
    let description = "Original brand colors"

    var previewColors: [Color] {
        [Color.DesignSystem.brandPink, Color.DesignSystem.brandTeal]
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
            primaryColor: Color.DesignSystem.brandPink,
            secondaryColor: Color.DesignSystem.brandTeal,

            // Accents
            accentPrimary: Color.DesignSystem.brandPink,
            accentSecondary: Color.DesignSystem.brandTeal,

            // Gradients
            gradientStart: Color.DesignSystem.brandPink,
            gradientEnd: Color.DesignSystem.brandTeal,
            glowColor: Color.DesignSystem.brandPink,
            highlightColor: Color.DesignSystem.brandTeal.opacity(0.4),

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
            primaryColor: Color(hex: "E6284C"), // Darker pink
            secondaryColor: Color(hex: "009688"), // Darker teal

            // Accents
            accentPrimary: Color(hex: "E6284C"),
            accentSecondary: Color(hex: "009688"),

            // Gradients
            gradientStart: Color(hex: "E6284C"),
            gradientEnd: Color(hex: "009688"),
            glowColor: Color(hex: "E6284C").opacity(0.5),
            highlightColor: Color(hex: "009688").opacity(0.2),

            // Backgrounds (light)
            background: Color(hex: "FFF5F7"),
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

#endif
