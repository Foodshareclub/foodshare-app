//
//  SettingsSearchBar.swift
//  Foodshare
//
//  Glass-styled search bar for settings search functionality
//

import SwiftUI
import FoodShareDesignSystem

/// Glass-styled search bar for filtering settings
struct SettingsSearchBar: View {
    @Binding var searchQuery: String
    @FocusState private var isFocused: Bool
    @Environment(\.translationService) private var t

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.DesignSystem.textSecondary)

            // Text field
            TextField(t.t("search_settings"), text: $searchQuery)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isFocused)
                .submitLabel(.search)

            // Clear button
            if !searchQuery.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        searchQuery = ""
                    }
                    HapticManager.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.DesignSystem.textTertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(
                            isFocused ? Color.DesignSystem.brandGreen.opacity(0.5) : Color.DesignSystem.glassBorder,
                            lineWidth: 1
                        )
                )
        )
        .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: isFocused)
        .animation(.interpolatingSpring(stiffness: 300, damping: 24), value: searchQuery.isEmpty)
    }
}

// MARK: - Search Results Header

/// Header shown when search results are displayed
struct SettingsSearchResultsHeader: View {
    let resultCount: Int
    let query: String
    @Environment(\.translationService) private var t

    var body: some View {
        HStack {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Color.DesignSystem.textSecondary)

            if resultCount > 0 {
                Text(t.t("search_results_count", args: ["count": String(resultCount), "query": query]))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            } else {
                Text(t.t("no_results_for", args: ["query": query]))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Search Highlight

/// Text view that highlights matching search terms
struct SearchHighlightedText: View {
    let text: String
    let query: String
    let baseColor: Color
    let highlightColor: Color

    init(
        _ text: String,
        query: String,
        baseColor: Color = .DesignSystem.text,
        highlightColor: Color = .DesignSystem.brandGreen
    ) {
        self.text = text
        self.query = query
        self.baseColor = baseColor
        self.highlightColor = highlightColor
    }

    var body: some View {
        if query.isEmpty {
            Text(text)
                .foregroundStyle(baseColor)
        } else {
            highlightedText
        }
    }

    private var highlightedText: some View {
        let lowercasedText = text.lowercased()
        let lowercasedQuery = query.lowercased()

        var result = Text("")

        if let range = lowercasedText.range(of: lowercasedQuery) {
            let startIndex = lowercasedText.distance(from: lowercasedText.startIndex, to: range.lowerBound)
            let endIndex = lowercasedText.distance(from: lowercasedText.startIndex, to: range.upperBound)

            let beforeText = String(text.prefix(startIndex))
            let matchText = String(text[text.index(text.startIndex, offsetBy: startIndex)..<text.index(text.startIndex, offsetBy: endIndex)])
            let afterText = String(text.suffix(text.count - endIndex))

            result = Text(beforeText).foregroundStyle(baseColor)
                + Text(matchText).foregroundStyle(highlightColor).bold()
                + Text(afterText).foregroundStyle(baseColor)
        } else {
            result = Text(text).foregroundStyle(baseColor)
        }

        return result
    }
}

// MARK: - Empty Search State

/// View shown when search has no results
struct SettingsSearchEmptyState: View {
    let query: String
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(Color.DesignSystem.textTertiary)

            Text(t.t("no_settings_found"))
                .font(.DesignSystem.headlineSmall)
                .foregroundStyle(Color.DesignSystem.text)

            Text(t.t("try_different_keywords"))
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        SettingsSearchBar(searchQuery: .constant(""))
        SettingsSearchBar(searchQuery: .constant("notification"))
        SettingsSearchResultsHeader(resultCount: 5, query: "notification")
        SettingsSearchResultsHeader(resultCount: 0, query: "xyz")
        SearchHighlightedText("Push Notifications", query: "notif")
            .font(.DesignSystem.bodyMedium)
        SettingsSearchEmptyState(query: "xyz")
    }
    .padding()
    .background(Color.DesignSystem.background)
}
