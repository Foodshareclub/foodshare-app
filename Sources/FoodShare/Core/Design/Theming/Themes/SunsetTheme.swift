//
//  SunsetTheme.swift
//  Foodshare
//
//  Sunset Theme - Orange/Pink
//  Warm sunset glow with vibrant colors
//


#if !SKIP
import SwiftUI

/// Sunset theme with orange and pink colors
struct SunsetTheme: Theme {
    let id = ThemeID.sunset.rawValue
    let displayName = "Sunset"
    let icon = "sunset.fill"
    let description = "Warm sunset glow"

    var previewColors: [Color] {
        [Color.DesignSystem.brandOrange, Color.DesignSystem.accentPink]
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
            primaryColor: Color.DesignSystem.brandOrange,
            secondaryColor: Color.DesignSystem.accentPink,

            // Accents
            accentPrimary: Color.DesignSystem.brandOrange,
            accentSecondary: Color.DesignSystem.accentPink,

            // Gradients
            gradientStart: Color.DesignSystem.brandOrange,
            gradientEnd: Color.DesignSystem.accentPink,
            glowColor: Color.DesignSystem.brandOrange,
            highlightColor: Color.DesignSystem.accentPink.opacity(0.4),

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
            primaryColor: Color(hex: "E65C00"),
            secondaryColor: Color(hex: "CC1B5E"),

            // Accents
            accentPrimary: Color(hex: "E65C00"),
            accentSecondary: Color(hex: "CC1B5E"),

            // Gradients
            gradientStart: Color(hex: "E65C00"),
            gradientEnd: Color(hex: "CC1B5E"),
            glowColor: Color(hex: "E65C00").opacity(0.5),
            highlightColor: Color(hex: "CC1B5E").opacity(0.2),

            // Backgrounds (light with warm tint)
            background: Color(hex: "FFF8F5"),
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
