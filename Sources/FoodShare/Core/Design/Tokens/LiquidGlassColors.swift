//
//  LiquidGlassColors.swift
//  Foodshare
//
//  Liquid Glass Design System v27 - Color Tokens
//  Single source of truth for all colors in the app
//
//  Usage: Always use Color.DesignSystem.* for colors
//

import SwiftUI

#if SKIP
// MARK: - Skip-compatible Color.DesignSystem

/// Helper to create Color from hex Int on Skip
private func _colorFromHex(_ hex: Int) -> Color {
    let r = Double((hex >> 16) & 0xFF) / 255.0
    let g = Double((hex >> 8) & 0xFF) / 255.0
    let b = Double(hex & 0xFF) / 255.0
    return Color(red: r, green: g, blue: b)
}

/// Opacity tokens for Skip
enum _ColorOpacity {
    static let micro = 0.05
    static let extraSubtle = 0.08
    static let subtle = 0.1
    static let semiLight = 0.12
    static let light = 0.15
    static let medium = 0.2
    static let emphasized = 0.3
    static let moderate = 0.4
    static let prominent = 0.5
    static let strong = 0.7
    static let almostOpaque = 0.9
    static let fillQuaternary = 0.04
    static let fillTertiary = 0.07
    static let fillSecondary = 0.10
    static let fill = 0.15
    static let separator = 0.24
}

/// Standalone namespace for design system colors (Skip cannot nest types in external type extensions)
enum _ColorDesignSystem {
    // MARK: - Opacity
    typealias Opacity = _ColorOpacity

    // MARK: - Brand Colors
    static var brandPink: Color { _colorFromHex(0xFF2D55) }
    static var brandTeal: Color { _colorFromHex(0x00A699) }
    static var brandOrange: Color { _colorFromHex(0xFC642D) }
    static var brandGreen: Color { _colorFromHex(0x30D158) }
    static var brandBlue: Color { _colorFromHex(0x3498DB) }

    // MARK: - Primary Colors
    static var primary: Color { brandPink }
    static var primaryLight: Color { brandPink.opacity(Opacity.strong) }
    static var primaryDark: Color { _colorFromHex(0xE6284C) }

    // MARK: - Semantic Background Colors
    static var background: Color { Color(red: Double(0x1C)/255.0, green: Double(0x1C)/255.0, blue: Double(0x1E)/255.0) }
    static var surface: Color { Color(red: Double(0x1C)/255.0, green: Double(0x1C)/255.0, blue: Double(0x1E)/255.0) }
    static var surfaceElevated: Color { Color(red: Double(0x2C)/255.0, green: Double(0x2C)/255.0, blue: Double(0x2E)/255.0) }

    // MARK: - Text Colors
    static var text: Color { Color.primary }
    static var textPrimary: Color { Color.primary }
    static var textSecondary: Color { Color.secondary }
    static var textTertiary: Color { Color.primary.opacity(Opacity.prominent) }

    // MARK: - Status Colors
    static var success: Color { _colorFromHex(0x30D158) }
    static var warning: Color { _colorFromHex(0xF39C12) }
    static var error: Color { _colorFromHex(0xE74C3C) }
    static var info: Color { _colorFromHex(0x3498DB) }

    // MARK: - Accent Colors
    static var accentBlue: Color { _colorFromHex(0x0A84FF) }
    static var accentCyan: Color { _colorFromHex(0x32D4DE) }
    static var accentPink: Color { _colorFromHex(0xE91E63) }
    static var accentPurple: Color { _colorFromHex(0x9B59B6) }
    static var accentYellow: Color { _colorFromHex(0xF1C40F) }
    static var accentOrange: Color { _colorFromHex(0xE67E22) }
    static var accentBrown: Color { _colorFromHex(0x8D6E63) }
    static var accentGray: Color { _colorFromHex(0x95A5A6) }

    // MARK: - Glass Effect Colors
    static var glassMicro: Color { Color.white.opacity(Opacity.micro) }
    static var glassExtraSubtle: Color { Color.white.opacity(Opacity.extraSubtle) }
    static var glassBackground: Color { Color.white.opacity(Opacity.subtle) }
    static var glassSemiLight: Color { Color.white.opacity(Opacity.semiLight) }
    static var glassSurface: Color { Color.white.opacity(Opacity.light) }
    static var glassBorder: Color { Color.white.opacity(Opacity.medium) }
    static var glassHighlight: Color { Color.white.opacity(Opacity.emphasized) }
    static var glassStroke: Color { Color.white.opacity(Opacity.medium) }
    static var glassOverlay: Color { Color.white.opacity(Opacity.subtle) }

    // MARK: - Semantic Overlay Colors
    static var overlayLight: Color { Color.white.opacity(0.6) }
    static var overlayMedium: Color { Color.white.opacity(0.7) }
    static var overlayStrong: Color { Color.white.opacity(0.8) }
    static var overlayDark: Color { Color.black.opacity(0.3) }
    static var overlayShadow: Color { Color.black.opacity(0.15) }
    static var scrim: Color { Color.black.opacity(0.4) }

    // MARK: - Category Colors
    static var categoryProduce: Color { _colorFromHex(0x27AE60) }
    static var categoryDairy: Color { _colorFromHex(0x3498DB) }
    static var categoryBakedGoods: Color { _colorFromHex(0xE67E22) }
    static var categoryPreparedMeals: Color { _colorFromHex(0xE74C3C) }
    static var categoryPantryItems: Color { _colorFromHex(0x95A5A6) }

    // MARK: - Medal Colors
    static var medalGold: Color { _colorFromHex(0xFFD700) }
    static var medalSilver: Color { _colorFromHex(0xC0C0C0) }
    static var medalBronze: Color { _colorFromHex(0xCD7F32) }

    // MARK: - Contrast Colors
    static var contrastText: Color { Color.white }
    static var contrastTextSecondary: Color { Color.white.opacity(Opacity.almostOpaque) }
    static var contrastSubtle: Color { Color.white.opacity(Opacity.medium) }
    static var contrastShadow: Color { Color.black.opacity(Opacity.light) }

    // MARK: - Dark/Light Mode Palette
    static var lightPrimaryColor: Color { _colorFromHex(0x9168FF) }
    static var lightBackgroundColor: Color { _colorFromHex(0xEDFBFF) }
    static var lightTextColor: Color { _colorFromHex(0x14151F) }
    static var lightAccentColor: Color { _colorFromHex(0x87FFB5) }
    static var darkPrimaryColor: Color { _colorFromHex(0xBB86FC) }
    static var darkBackgroundColor: Color { _colorFromHex(0x000000) }
    static var darkTextColor: Color { _colorFromHex(0xE0E0E0) }
    static var darkAccentColor: Color { _colorFromHex(0x00FF7F) }

    // MARK: - Dark Auth Background Colors
    static var darkAuthBase: Color { _colorFromHex(0x000000) }
    static var darkAuthMid: Color { _colorFromHex(0x1C1C1E) }
    static var darkAuthLight: Color { _colorFromHex(0x2C2C2E) }

    // MARK: - Legacy Compatibility
    static var blueDark: Color { _colorFromHex(0x2C3E50) }
    static var blueLight: Color { _colorFromHex(0x5DADE2) }
    static var mainColor: Color { accentBlue }
    static var brandCyan: Color { _colorFromHex(0x1ABC9C) }
    static var brandPurple: Color { _colorFromHex(0x9B59B6) }

    // MARK: - Gradients
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [brandPink.opacity(0.95), brandTeal.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var primaryGradient: LinearGradient {
        LinearGradient(colors: [primary, primaryDark], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var pinkTealGradient: LinearGradient {
        LinearGradient(colors: [brandPink, brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var authGradient: LinearGradient {
        LinearGradient(colors: [brandPink, brandTeal], startPoint: .leading, endPoint: .trailing)
    }
    static var blueGradient: LinearGradient {
        LinearGradient(colors: [accentBlue, accentCyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var blueCyanGradient: LinearGradient {
        LinearGradient(colors: [accentBlue.opacity(0.95), accentCyan.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var surfaceGradient: LinearGradient {
        LinearGradient(colors: [surface, surfaceElevated], startPoint: .top, endPoint: .bottom)
    }
    static var backgroundGradient: LinearGradient {
        LinearGradient(colors: [background, surface], startPoint: .top, endPoint: .bottom)
    }
    static var starRatingGradient: LinearGradient {
        LinearGradient(colors: [medalGold, accentOrange], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var starEmptyGradient: LinearGradient {
        LinearGradient(colors: [accentGray.opacity(0.3), accentGray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var darkAuthGradient: LinearGradient {
        LinearGradient(colors: [darkAuthBase, darkAuthMid, darkAuthLight], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    static var natureAccentGradient: LinearGradient {
        LinearGradient(colors: [brandGreen.opacity(0.35), Color.clear, brandBlue.opacity(0.25)], startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    /// Provides `Color.DesignSystem.xxx` access for Skip
    static var DesignSystem: _ColorDesignSystem.Type { _ColorDesignSystem.self }

    // Backward compat aliases
    static var brandPink: Color { _ColorDesignSystem.brandPink }
    static var brandTeal: Color { _ColorDesignSystem.brandTeal }
    static var brandOrange: Color { _ColorDesignSystem.brandOrange }
    static var brandGreen: Color { _ColorDesignSystem.brandGreen }
    static var brandBlue: Color { _ColorDesignSystem.brandBlue }
    static var blueDark: Color { _ColorDesignSystem.blueDark }
    static var blueLight: Color { _ColorDesignSystem.blueLight }
    static var success: Color { _ColorDesignSystem.success }
    static var warning: Color { _ColorDesignSystem.warning }
    static var error: Color { _ColorDesignSystem.error }
    static var info: Color { _ColorDesignSystem.info }
    static var background: Color { _ColorDesignSystem.background }
    static var backgroundSecondary: Color { _ColorDesignSystem.surface }
    static var backgroundGradient: LinearGradient { _ColorDesignSystem.backgroundGradient }
    static var glassBackground: Color { _ColorDesignSystem.glassBackground }
    static var glassBorder: Color { _ColorDesignSystem.glassBorder }
    static var glassStroke: Color { _ColorDesignSystem.glassStroke }
    static var glassOverlay: Color { _ColorDesignSystem.glassOverlay }
    static var textPrimary: Color { _ColorDesignSystem.textPrimary }
    static var textSecondary: Color { _ColorDesignSystem.textSecondary }
    static var textTertiary: Color { _ColorDesignSystem.textTertiary }
    static var categoryProduce: Color { _ColorDesignSystem.categoryProduce }
    static var categoryDairy: Color { _ColorDesignSystem.categoryDairy }
    static var categoryBakedGoods: Color { _ColorDesignSystem.categoryBakedGoods }
    static var categoryPreparedMeals: Color { _ColorDesignSystem.categoryPreparedMeals }
    static var categoryPantryItems: Color { _ColorDesignSystem.categoryPantryItems }
}

#else
// MARK: - Design System Colors

extension Color {
    /// Design System namespace - Single source of truth for all app colors
    enum DesignSystem {
        // MARK: - Opacity Tokens

        /// Standardized opacity values for consistent transparency across the app
        enum Opacity {
            static let micro = 0.05
            static let extraSubtle = 0.08
            static let subtle = 0.1
            static let semiLight = 0.12
            static let light = 0.15
            static let medium = 0.2
            static let emphasized = 0.3
            static let moderate = 0.4
            static let prominent = 0.5
            static let strong = 0.7
            static let almostOpaque = 0.9

            // Apple HIG Fill Opacities (Dark Mode)
            static let fillQuaternary = 0.04
            static let fillTertiary = 0.07
            static let fillSecondary = 0.10
            static let fill = 0.15
            static let separator = 0.24
        }

        // MARK: - Brand Colors (Foodshare Website Palette)

        /// Primary brand - Pink #FF2D55
        static let brandPink = Color(0xFF2D55)
        /// Secondary brand - Teal #00A699
        static let brandTeal = Color(0x00A699)
        /// Tertiary brand - Orange #FC642D
        static let brandOrange = Color(0xFC642D)
        /// Legacy green (eco themes) - Apple System Green Dark
        static let brandGreen = Color(0x30D158)
        /// Legacy blue
        static let brandBlue = Color(0x3498DB)

        // MARK: - Primary Colors

        static let primary = brandPink
        static let primaryLight = brandPink.opacity(Opacity.strong)
        static let primaryDark = Color(0xE6284C)

        // MARK: - Semantic Background Colors (Apple HIG dark mode palette)

        static let background = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor.secondarySystemBackground // #1C1C1E (Apple dark mode)
                : .systemBackground
        })
        static let surface = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255, alpha: 1) // #1C1C1E (secondarySystemBg)
                : .secondarySystemBackground
        })
        static let surfaceElevated = Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255, alpha: 1) // #2C2C2E (tertiarySystemBg)
                : .tertiarySystemBackground
        })

        // MARK: - Text Colors

        static let text = Color.primary
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.primary.opacity(Opacity.prominent)

        // MARK: - Status Colors

        static let success = Color(0x30D158)
        static let warning = Color(0xF39C12)
        static let error = Color(0xE74C3C)
        static let info = Color(0x3498DB)

        // MARK: - Accent Colors

        static let accentBlue = Color(0x0A84FF)
        static let accentCyan = Color(0x32D4DE)
        static let accentPink = Color(0xE91E63)
        static let accentPurple = Color(0x9B59B6)
        static let accentYellow = Color(0xF1C40F)
        static let accentOrange = Color(0xE67E22)
        static let accentBrown = Color(0x8D6E63)
        static let accentGray = Color(0x95A5A6)

        // MARK: - Glass Effect Colors

        /// Micro glass surface (0.05) - Very subtle background
        static let glassMicro = Color.white.opacity(Opacity.micro)
        /// Extra subtle glass surface (0.08) - Subtle backgrounds
        static let glassExtraSubtle = Color.white.opacity(Opacity.extraSubtle)
        /// Standard glass background (0.1) - Default glass background
        static let glassBackground = Color.white.opacity(Opacity.subtle)
        /// Semi-light glass surface (0.12) - Slightly more visible
        static let glassSemiLight = Color.white.opacity(Opacity.semiLight)
        /// Glass surface (0.15) - Secondary glass elements
        static let glassSurface = Color.white.opacity(Opacity.light)
        /// Glass border (0.2) - Borders and dividers
        static let glassBorder = Color.white.opacity(Opacity.medium)
        /// Glass highlight (0.3) - Highlights and accents
        static let glassHighlight = Color.white.opacity(Opacity.emphasized)
        /// Glass stroke (0.2) - Stroke color
        static let glassStroke = Color.white.opacity(Opacity.medium)
        /// Glass overlay (0.1) - Subtle overlays
        static let glassOverlay = Color.white.opacity(Opacity.subtle)

        // MARK: - Semantic Overlay Colors

        /// Light overlay for dark backgrounds (0.6 opacity)
        static let overlayLight = Color.white.opacity(0.6)
        /// Medium overlay for dark backgrounds (0.7 opacity)
        static let overlayMedium = Color.white.opacity(0.7)
        /// Strong overlay for dark backgrounds (0.8 opacity)
        static let overlayStrong = Color.white.opacity(0.8)
        /// Dark overlay for light backgrounds (0.3 opacity)
        static let overlayDark = Color.black.opacity(0.3)
        /// Shadow overlay (0.15 opacity)
        static let overlayShadow = Color.black.opacity(0.15)
        /// Scrim for modal backgrounds (0.4 opacity)
        static let scrim = Color.black.opacity(0.4)

        // MARK: - Category Colors

        static let categoryProduce = Color(0x27AE60)
        static let categoryDairy = Color(0x3498DB)
        static let categoryBakedGoods = Color(0xE67E22)
        static let categoryPreparedMeals = Color(0xE74C3C)
        static let categoryPantryItems = Color(0x95A5A6)

        // MARK: - Medal Colors (Leaderboard)

        static let medalGold = Color(0xFFD700)
        static let medalSilver = Color(0xC0C0C0)
        static let medalBronze = Color(0xCD7F32)

        // MARK: - Contrast Colors (For use on colored/gradient backgrounds)

        /// Text that contrasts on dark/colored backgrounds
        static let contrastText = Color.white
        /// Secondary contrast text with slight transparency
        static let contrastTextSecondary = Color.white.opacity(Opacity.almostOpaque)
        /// Subtle element on colored backgrounds
        static let contrastSubtle = Color.white.opacity(Opacity.medium)
        /// Shadow for elements on colored backgrounds
        static let contrastShadow = Color.black.opacity(Opacity.light)

        // MARK: - Dark/Light Mode Palette

        static let lightPrimaryColor = Color(0x9168FF)
        static let lightBackgroundColor = Color(0xEDFBFF)
        static let lightTextColor = Color(0x14151F)
        static let lightAccentColor = Color(0x87FFB5)

        static let darkPrimaryColor = Color(0xBB86FC)
        static let darkBackgroundColor = Color(0x000000)
        static let darkTextColor = Color(0xE0E0E0)
        static let darkAccentColor = Color(0x00FF7F)

        // MARK: - Dark Auth Background Colors (Apple HIG dark mode)

        /// True black for auth backgrounds (#000000)
        static let darkAuthBase = Color(0x000000)
        /// Secondary system background (#1C1C1E) for auth gradients
        static let darkAuthMid = Color(0x1C1C1E)
        /// Tertiary system background (#2C2C2E) for auth gradients
        static let darkAuthLight = Color(0x2C2C2E)

        // MARK: - Legacy Compatibility

        static let blueDark = Color(0x2C3E50)
        static let blueLight = Color(0x5DADE2)
        static let mainColor = accentBlue
        static let brandCyan = Color(0x1ABC9C)
        static let brandPurple = Color(0x9B59B6)
    }
}

// MARK: - Gradients

extension Color.DesignSystem {
    /// Brand gradient (Pink → Teal)
    static let brandGradient = LinearGradient(
        colors: [brandPink.opacity(0.95), brandTeal.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing,
    )

    /// Primary gradient (Pink → Darker Pink)
    static let primaryGradient = LinearGradient(
        colors: [primary, primaryDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing,
    )

    /// Pink to Teal gradient
    static let pinkTealGradient = LinearGradient(
        colors: [brandPink, brandTeal],
        startPoint: .topLeading,
        endPoint: .bottomTrailing,
    )

    /// Auth screen gradient
    static let authGradient = LinearGradient(
        colors: [brandPink, brandTeal],
        startPoint: .leading,
        endPoint: .trailing,
    )

    /// Blue to Cyan gradient
    static let blueGradient = LinearGradient(
        colors: [accentBlue, accentCyan],
        startPoint: .topLeading,
        endPoint: .bottomTrailing,
    )

    /// Blue/Cyan gradient for CTAs
    static let blueCyanGradient = LinearGradient(
        colors: [accentBlue.opacity(0.95), accentCyan.opacity(0.9)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing,
    )

    /// Surface gradient
    static let surfaceGradient = LinearGradient(
        colors: [surface, surfaceElevated],
        startPoint: .top,
        endPoint: .bottom,
    )

    /// Background gradient
    static let backgroundGradient = LinearGradient(
        colors: [background, surface],
        startPoint: .top,
        endPoint: .bottom,
    )

    /// Star rating gradient (gold → orange)
    static let starRatingGradient = LinearGradient(
        colors: [medalGold, accentOrange],
        startPoint: .topLeading,
        endPoint: .bottomTrailing,
    )

    /// Empty star gradient (subtle gray)
    static let starEmptyGradient = LinearGradient(
        colors: [accentGray.opacity(0.3), accentGray.opacity(0.2)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing,
    )

    /// Dark auth background gradient (for onboarding/verification screens)
    static let darkAuthGradient = LinearGradient(
        colors: [darkAuthBase, darkAuthMid, darkAuthLight],
        startPoint: .topLeading,
        endPoint: .bottomTrailing,
    )

    /// Nature accent gradient overlay (for auth backgrounds)
    static let natureAccentGradient = LinearGradient(
        colors: [
            brandGreen.opacity(0.35),
            Color.clear,
            brandBlue.opacity(0.25)
        ],
        startPoint: .top,
        endPoint: .bottom,
    )
}

// MARK: - Backward Compatibility Aliases

extension Color {
    // Brand colors - redirect to DesignSystem
    static var brandPink: Color { DesignSystem.brandPink }
    static var brandTeal: Color { DesignSystem.brandTeal }
    static var brandOrange: Color { DesignSystem.brandOrange }
    static var brandGreen: Color { DesignSystem.brandGreen }
    static var brandBlue: Color { DesignSystem.brandBlue }
    static var blueDark: Color { DesignSystem.blueDark }
    static var blueLight: Color { DesignSystem.blueLight }

    // Semantic colors
    static var success: Color { DesignSystem.success }
    static var warning: Color { DesignSystem.warning }
    static var error: Color { DesignSystem.error }
    static var info: Color { DesignSystem.info }

    // Background colors
    static var background: Color { DesignSystem.background }
    static var backgroundSecondary: Color { DesignSystem.surface }

    static var backgroundGradient: LinearGradient {
        DesignSystem.backgroundGradient
    }

    // Glass colors
    static var glassBackground: Color { DesignSystem.glassBackground }
    static var glassBorder: Color { DesignSystem.glassBorder }
    static var glassStroke: Color { DesignSystem.glassStroke }
    static var glassOverlay: Color { DesignSystem.glassOverlay }

    // Text colors
    static var textPrimary: Color { DesignSystem.textPrimary }
    static var textSecondary: Color { DesignSystem.textSecondary }
    static var textTertiary: Color { DesignSystem.textTertiary }

    // Category colors
    static var categoryProduce: Color { DesignSystem.categoryProduce }
    static var categoryDairy: Color { DesignSystem.categoryDairy }
    static var categoryBakedGoods: Color { DesignSystem.categoryBakedGoods }
    static var categoryPreparedMeals: Color { DesignSystem.categoryPreparedMeals }
    static var categoryPantryItems: Color { DesignSystem.categoryPantryItems }
}

// MARK: - LiquidGlassColors (Deprecated)

@available(*, deprecated, message: "Use Color.DesignSystem instead")
enum LiquidGlassColors {
    static var primary: Color { Color.DesignSystem.primary }
    static var primaryLight: Color { Color.DesignSystem.primaryLight }
    static var primaryDark: Color { Color.DesignSystem.primaryDark }
    static var background: Color { Color.DesignSystem.background }
    static var surface: Color { Color.DesignSystem.surface }
    static var surfaceElevated: Color { Color.DesignSystem.surfaceElevated }
    static var text: Color { Color.DesignSystem.text }
    static var textSecondary: Color { Color.DesignSystem.textSecondary }
    static var textTertiary: Color { Color.DesignSystem.textTertiary }
    static var success: Color { Color.DesignSystem.success }
    static var warning: Color { Color.DesignSystem.warning }
    static var error: Color { Color.DesignSystem.error }
    static var info: Color { Color.DesignSystem.info }
    static var glassBackground: Color { Color.DesignSystem.glassBackground }
    static var glassSurface: Color { Color.DesignSystem.glassSurface }
    static var glassBorder: Color { Color.DesignSystem.glassBorder }
    static var glassHighlight: Color { Color.DesignSystem.glassHighlight }
    static var glassOverlay: Color { Color.DesignSystem.glassOverlay }
    static var primaryGradient: LinearGradient { Color.DesignSystem.primaryGradient }
    static var surfaceGradient: LinearGradient { Color.DesignSystem.surfaceGradient }
    static var backgroundGradient: LinearGradient { Color.DesignSystem.backgroundGradient }
    static var categoryProduce: Color { Color.DesignSystem.categoryProduce }
    static var categoryDairy: Color { Color.DesignSystem.categoryDairy }
    static var categoryBakedGoods: Color { Color.DesignSystem.categoryBakedGoods }
    static var categoryPreparedMeals: Color { Color.DesignSystem.categoryPreparedMeals }
    static var categoryPantryItems: Color { Color.DesignSystem.categoryPantryItems }
    static var accentPink: Color { Color.DesignSystem.accentPink }
    static var accentPurple: Color { Color.DesignSystem.accentPurple }
    static var accentYellow: Color { Color.DesignSystem.accentYellow }
    static var accentOrange: Color { Color.DesignSystem.accentOrange }
    static var accentBrown: Color { Color.DesignSystem.accentBrown }
    static var accentGray: Color { Color.DesignSystem.accentGray }
    static var medalGold: Color { Color.DesignSystem.medalGold }
    static var medalSilver: Color { Color.DesignSystem.medalSilver }
    static var medalBronze: Color { Color.DesignSystem.medalBronze }
    static var accentBlue: Color { Color.DesignSystem.accentBlue }
    static var accentCyan: Color { Color.DesignSystem.accentCyan }
    static var mainColor: Color { Color.DesignSystem.mainColor }
    static var lightPrimaryColor: Color { Color.DesignSystem.lightPrimaryColor }
    static var lightAccentColor: Color { Color.DesignSystem.lightAccentColor }
    static var darkPrimaryColor: Color { Color.DesignSystem.darkPrimaryColor }
    static var darkAccentColor: Color { Color.DesignSystem.darkAccentColor }
    static var blueGradient: LinearGradient { Color.DesignSystem.blueGradient }
    static var blueCyanGradient: LinearGradient { Color.DesignSystem.blueCyanGradient }
}
#endif
