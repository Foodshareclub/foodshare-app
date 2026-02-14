//
//  ThemeEnvironment.swift
//  Foodshare
//
//  Enterprise Theme System - SwiftUI Environment Integration
//  Provides environment keys and view modifiers for theme injection
//

import SwiftUI

// MARK: - Environment Keys

/// Environment key for the current theme
private struct ThemeKey: EnvironmentKey {
    static let defaultValue: any Theme = NatureTheme()
}

/// Environment key for the current theme palette
private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue: ThemePalette = NatureTheme().palette(for: .dark)
}

/// Environment key for the effective color scheme
private struct EffectiveColorSchemeKey: EnvironmentKey {
    static let defaultValue: ColorScheme = .dark
}

// MARK: - Environment Values Extension

extension EnvironmentValues {
    /// The current app theme
    var theme: any Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }

    /// The current theme's palette (for the active color scheme)
    var themePalette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }

    /// The effective color scheme (respecting user preference)
    var effectiveColorScheme: ColorScheme {
        get { self[EffectiveColorSchemeKey.self] }
        set { self[EffectiveColorSchemeKey.self] = newValue }
    }
}

// MARK: - Theme Root View Modifier

/// View modifier that injects theme state into the environment
/// and handles system color scheme changes
struct ThemeRootModifier: ViewModifier {
    @Environment(\.colorScheme) private var systemColorScheme
    private var themeManager = ThemeManager.shared

    func body(content: Content) -> some View {
        content
            .environment(\.theme, themeManager.currentTheme)
            .environment(\.themePalette, themeManager.currentPalette)
            .environment(\.effectiveColorScheme, themeManager.effectiveColorScheme)
            .preferredColorScheme(themeManager.preferredColorScheme)
            .onChange(of: systemColorScheme, initial: true) { _, newScheme in
                themeManager.updateFromSystemScheme(newScheme)
            }
    }
}

// MARK: - View Extension

extension View {
    /// Apply theme system to the view hierarchy
    /// Call this at the app root (typically in FoodShareApp.swift)
    func withTheme() -> some View {
        modifier(ThemeRootModifier())
    }

    /// Access themed gradient for primary elements
    @MainActor
    func themedGradient() -> LinearGradient {
        let palette = ThemeManager.shared.currentPalette
        return LinearGradient(
            colors: [palette.gradientStart, palette.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
    }
}

// MARK: - Themed Gradient View

/// A gradient view that uses the current theme colors
struct ThemedGradient: View {
    @Environment(\.themePalette) private var palette

    var opacity = 1.0
    var startPoint: UnitPoint = .topLeading
    var endPoint: UnitPoint = .bottomTrailing

    var body: some View {
        LinearGradient(
            colors: [
                palette.gradientStart.opacity(opacity),
                palette.gradientEnd.opacity(opacity)
            ],
            startPoint: startPoint,
            endPoint: endPoint,
        )
    }
}

// MARK: - Themed Glow View

/// A glow effect view using the current theme's glow color
struct ThemedGlow: View {
    @Environment(\.themePalette) private var palette

    var size: CGFloat = 200
    var blur: CGFloat = 40
    var opacity = 0.6

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        palette.glowColor.opacity(opacity),
                        palette.glowColor.opacity(opacity * 0.5),
                        palette.glowColor.opacity(opacity * 0.1),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2,
                ),
            )
            .frame(width: size, height: size)
            .blur(radius: blur)
    }
}

// MARK: - Preview Helpers

extension View {
    /// Preview a view with a specific theme
    func previewWithTheme(_ theme: any Theme, scheme: ColorScheme = .dark) -> some View {
        environment(\.theme, theme)
            .environment(\.themePalette, theme.palette(for: scheme))
            .environment(\.effectiveColorScheme, scheme)
            .preferredColorScheme(scheme)
    }
}

// MARK: - Previews

#Preview("Theme Environment - Nature Dark") {
    VStack(spacing: 20) {
        ThemedGradient()
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 16))

        ThemedGlow(size: 150, blur: 30)
    }
    .padding()
    .background(Color.black)
    .previewWithTheme(NatureTheme(), scheme: .dark)
}

#Preview("Theme Environment - Nature Light") {
    VStack(spacing: 20) {
        ThemedGradient()
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 16))

        ThemedGlow(size: 150, blur: 30)
    }
    .padding()
    .background(Color.white)
    .previewWithTheme(NatureTheme(), scheme: .light)
}
