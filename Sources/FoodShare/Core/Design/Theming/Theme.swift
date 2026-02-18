//
//  Theme.swift
//  Foodshare
//
//  Enterprise Theme System - Theme Protocol & Palette
//  Defines the contract for all themes with dark/light mode support
//


#if !SKIP
import SwiftUI

// MARK: - Theme Palette

/// Color palette for a specific appearance mode (dark/light)
/// Each theme provides a palette for both color schemes
struct ThemePalette: Sendable, Equatable {
    // MARK: - Primary Gradient Colors

    /// Primary theme color (used for main gradients, CTAs)
    let primaryColor: Color
    /// Secondary theme color (complements primary in gradients)
    let secondaryColor: Color

    // MARK: - Accent Colors

    /// Primary accent for highlights and interactive elements
    let accentPrimary: Color
    /// Secondary accent for subtle highlights
    let accentSecondary: Color

    // MARK: - Semantic Gradient Mappings

    /// Start color for main gradients
    let gradientStart: Color
    /// End color for main gradients
    let gradientEnd: Color
    /// Color for glow effects (behind buttons, cards)
    let glowColor: Color
    /// Highlight color for selected states
    let highlightColor: Color

    // MARK: - Background Colors (Scheme-Dependent)

    /// Main app background
    let background: Color
    /// Elevated surface background (cards, sheets)
    let surfaceBackground: Color
    /// Glass effect background with transparency
    let glassBackground: Color
    /// Glass border/stroke color
    let glassBorder: Color

    // MARK: - Text Colors (Scheme-Dependent)

    /// Primary text color
    let textPrimary: Color
    /// Secondary/subdued text color
    let textSecondary: Color
    /// Tertiary/hint text color
    let textTertiary: Color
}

// MARK: - Theme Protocol

/// Protocol defining a switchable app theme
/// Each theme must provide palettes for both dark and light modes
protocol Theme: Sendable, Identifiable {
    /// Unique identifier for persistence
    var id: String { get }
    /// User-facing display name
    var displayName: String { get }
    /// SF Symbol icon name for theme picker
    var icon: String { get }
    /// Brief description of the theme
    var description: String { get }

    /// Returns the color palette for the specified color scheme
    /// - Parameter scheme: The current system color scheme
    /// - Returns: A complete ThemePalette for that scheme
    func palette(for scheme: ColorScheme) -> ThemePalette

    /// Preview gradient colors for theme picker UI
    var previewColors: [Color] { get }
}

// MARK: - Default Implementations

extension Theme {
    /// Default description if not provided
    var description: String { displayName }
}

// MARK: - Color Scheme Preference

/// User preference for color scheme
enum ColorSchemePreference: String, CaseIterable, Sendable {
    case system
    case dark
    case light

    /// Display name for UI
    var displayName: String {
        switch self {
        case .system: "System"
        case .dark: "Dark"
        case .light: "Light"
        }
    }

    /// Localized display name using translation service
    @MainActor
    func localizedDisplayName(using t: EnhancedTranslationService) -> String {
        switch self {
        case .system: t.t("theme.preference.system")
        case .dark: t.t("theme.preference.dark")
        case .light: t.t("theme.preference.light")
        }
    }

    /// SF Symbol icon
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .dark: "moon.fill"
        case .light: "sun.max.fill"
        }
    }

    /// Convert to SwiftUI ColorScheme (nil for system)
    var toColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

// MARK: - Theme Identifiers

/// Type-safe theme identifiers
enum ThemeID: String, CaseIterable, Sendable {
    case nature
    case brand
    case ocean
    case sunset
    case forest
    case coral
    case midnight
    case monochrome
}

#endif
