//
//  ThemePickerView.swift
//  Foodshare
//
//  Theme Picker UI for selecting app themes
//  Displays all available themes with visual previews
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Theme Picker View

/// Full-screen theme picker with visual previews
struct ThemePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @State private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Current Theme Preview
                    currentThemePreview

                    // Theme Grid
                    themeGrid

                    // Info Text
                    infoText
                }
                .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("settings.choose_theme"))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("common.done")) {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Current Theme Preview

    private var currentThemePreview: some View {
        VStack(spacing: Spacing.md) {
            // Large preview gradient
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(
                    LinearGradient(
                        colors: themeManager.currentTheme.previewColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing,
                    ),
                )
                .frame(height: 120)
                .overlay(
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: themeManager.currentTheme.icon)
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(.white)

                        Text(themeManager.currentTheme.displayName)
                            .font(.DesignSystem.headlineMedium)
                            .foregroundColor(.white)

                        Text("Current Theme")
                            .font(.DesignSystem.caption)
                            .foregroundColor(.white.opacity(0.8))
                    },
                )
                .shadow(color: themeManager.currentTheme.previewColors.first?.opacity(0.4) ?? .clear, radius: 20)

            Text(themeManager.currentTheme.description)
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
    }

    // MARK: - Theme Grid

    private var themeGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: Spacing.md),
            GridItem(.flexible(), spacing: Spacing.md)
        ], spacing: Spacing.md) {
            ForEach(themeManager.availableThemes, id: \.id) { theme in
                ThemeCard(
                    theme: theme,
                    isSelected: themeManager.isThemeActive(theme.id),
                ) {
                    themeManager.setTheme(theme)
                }
            }
        }
    }

    // MARK: - Info Text

    private var infoText: some View {
        Text(
            "Themes affect gradients, accents, and glow effects throughout the app. Background and text colors adapt to your appearance mode setting.",
        )
        .font(.DesignSystem.caption)
        .foregroundColor(.DesignSystem.textTertiary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
}

// MARK: - Theme Card

/// Individual theme card for the picker grid
private struct ThemeCard: View {
    let theme: any Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                // Gradient Preview
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(
                        LinearGradient(
                            colors: theme.previewColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(height: 80)
                    .overlay(
                        Image(systemName: theme.icon)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white),
                    )

                // Theme Name
                HStack {
                    Text(theme.displayName)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.text)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.DesignSystem.success)
                    }
                }
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.large)
                            .stroke(
                                isSelected ? Color.DesignSystem.success : Color.DesignSystem.glassBorder,
                                lineWidth: isSelected ? 2 : 1,
                            ),
                    ),
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.interpolatingSpring(stiffness: 300, damping: 20), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Theme Picker") {
    ThemePickerView()
}

#Preview("Theme Card - Selected") {
    ThemeCard(theme: NatureTheme(), isSelected: true) {}
        .frame(width: 160)
        .padding()
        .background(Color.black)
}

#Preview("Theme Card - Unselected") {
    ThemeCard(theme: OceanTheme(), isSelected: false) {}
        .frame(width: 160)
        .padding()
        .background(Color.black)
}
