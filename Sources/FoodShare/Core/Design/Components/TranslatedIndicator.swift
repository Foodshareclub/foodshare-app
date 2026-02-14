//
//  TranslatedIndicator.swift
//  Foodshare
//
//  Subtle indicator showing content was auto-translated from English
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Translated Indicator

/// Subtle indicator showing content was translated from English
struct TranslatedIndicator: View {
    // MARK: - Properties

    @Environment(\.translationService) private var t

    // MARK: - Body

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Image(systemName: "globe")
                .font(.system(size: 11, weight: .medium))

            Text(t.t("common.translatedFromEnglish"))
                .font(.DesignSystem.caption)
        }
        .foregroundColor(.DesignSystem.textTertiary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Content translated from English")
    }
}

// MARK: - Preview

#Preview("Translated Indicator") {
    VStack(spacing: Spacing.lg) {
        // In context
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Manzanas orgánicas frescas de mi jardín, perfectas para hacer pasteles o comer frescas.")
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.DesignSystem.textSecondary)

            TranslatedIndicator()
        }
        .padding()
        .background(Color.DesignSystem.glassBackground)
        .cornerRadius(CornerRadius.medium)

        // Standalone
        TranslatedIndicator()
    }
    .padding()
    .background(Color.DesignSystem.background)
}
