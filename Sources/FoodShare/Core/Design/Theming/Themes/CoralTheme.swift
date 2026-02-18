//
//  CoralTheme.swift
//  Foodshare
//
//  Coral Theme - Coral/Peach
//  Tropical warmth with soft, inviting colors
//


#if !SKIP
import SwiftUI

/// Coral theme with coral and peach colors
struct CoralTheme: Theme {
    let id = ThemeID.coral.rawValue
    let displayName = "Coral"
    let icon = "sparkles"
    let description = "Tropical warmth"

    var previewColors: [Color] {
        [Color(hex: "FF6B6B"), Color(hex: "FFB347")]
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
            // Primary gradient (coral to peach)
            primaryColor: Color(hex: "FF6B6B"),
            secondaryColor: Color(hex: "FFB347"),

            // Accents
            accentPrimary: Color(hex: "FF8E8E"),
            accentSecondary: Color(hex: "FFC875"),

            // Gradients
            gradientStart: Color(hex: "FF6B6B"),
            gradientEnd: Color(hex: "FFB347"),
            glowColor: Color(hex: "FF6B6B"),
            highlightColor: Color(hex: "FFB347").opacity(0.4),

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
            primaryColor: Color(hex: "E85555"),
            secondaryColor: Color(hex: "E89F30"),

            // Accents
            accentPrimary: Color(hex: "FF6B6B"),
            accentSecondary: Color(hex: "FFB347"),

            // Gradients
            gradientStart: Color(hex: "E85555"),
            gradientEnd: Color(hex: "E89F30"),
            glowColor: Color(hex: "E85555").opacity(0.5),
            highlightColor: Color(hex: "E89F30").opacity(0.2),

            // Backgrounds (light with coral tint)
            background: Color(hex: "FFF5F5"),
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
