//
//  MidnightTheme.swift
//  Foodshare
//
//  Midnight Theme - Indigo/Purple
//  Night sky elegance with deep, luxurious colors
//


#if !SKIP
import SwiftUI

/// Midnight theme with indigo and purple colors
struct MidnightTheme: Theme {
    let id = ThemeID.midnight.rawValue
    let displayName = "Midnight"
    let icon = "moon.stars.fill"
    let description = "Night sky elegance"

    var previewColors: [Color] {
        [Color(hex: "4F46E5"), Color.DesignSystem.accentPurple]
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
            // Primary gradient (indigo to purple)
            primaryColor: Color(hex: "4F46E5"),
            secondaryColor: Color.DesignSystem.accentPurple,

            // Accents
            accentPrimary: Color(hex: "6366F1"),
            accentSecondary: Color(hex: "A855F7"),

            // Gradients
            gradientStart: Color(hex: "4F46E5"),
            gradientEnd: Color.DesignSystem.accentPurple,
            glowColor: Color(hex: "6366F1"),
            highlightColor: Color.DesignSystem.accentPurple.opacity(0.4),

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
            primaryColor: Color(hex: "4338CA"),
            secondaryColor: Color(hex: "7C3AED"),

            // Accents
            accentPrimary: Color(hex: "4F46E5"),
            accentSecondary: Color(hex: "8B5CF6"),

            // Gradients
            gradientStart: Color(hex: "4338CA"),
            gradientEnd: Color(hex: "7C3AED"),
            glowColor: Color(hex: "4F46E5").opacity(0.5),
            highlightColor: Color(hex: "8B5CF6").opacity(0.2),

            // Backgrounds (light with purple tint)
            background: Color(hex: "F5F3FF"),
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
