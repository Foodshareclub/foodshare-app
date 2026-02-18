//
//  MonochromeTheme.swift
//  Foodshare
//
//  Monochrome Theme - Gray/White
//  Minimalist grayscale for a clean, professional look
//


#if !SKIP
import SwiftUI

/// Monochrome theme with grayscale colors
struct MonochromeTheme: Theme {
    let id = ThemeID.monochrome.rawValue
    let displayName = "Monochrome"
    let icon = "circle.lefthalf.filled"
    let description = "Minimalist grayscale"

    var previewColors: [Color] {
        [Color(hex: "4A5568"), Color(hex: "718096")]
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
            // Primary gradient (dark gray to medium gray)
            primaryColor: Color(hex: "4A5568"),
            secondaryColor: Color(hex: "718096"),

            // Accents
            accentPrimary: Color(hex: "A0AEC0"),
            accentSecondary: Color(hex: "CBD5E0"),

            // Gradients
            gradientStart: Color(hex: "4A5568"),
            gradientEnd: Color(hex: "718096"),
            glowColor: Color(hex: "A0AEC0"),
            highlightColor: Color(hex: "718096").opacity(0.4),

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
            primaryColor: Color(hex: "2D3748"),
            secondaryColor: Color(hex: "4A5568"),

            // Accents
            accentPrimary: Color(hex: "4A5568"),
            accentSecondary: Color(hex: "718096"),

            // Gradients
            gradientStart: Color(hex: "2D3748"),
            gradientEnd: Color(hex: "4A5568"),
            glowColor: Color(hex: "4A5568").opacity(0.5),
            highlightColor: Color(hex: "718096").opacity(0.2),

            // Backgrounds (pure light)
            background: Color(hex: "F7FAFC"),
            surfaceBackground: Color.white,
            glassBackground: Color.black.opacity(0.04),
            glassBorder: Color.black.opacity(0.12),

            // Text (dark on light)
            textPrimary: Color(hex: "1A202C"),
            textSecondary: Color(hex: "1A202C").opacity(0.7),
            textTertiary: Color(hex: "1A202C").opacity(0.5),
        )
    }
}

#endif
