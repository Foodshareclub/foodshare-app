//
//  FeedSearchSheet.swift
//  Foodshare
//
//  Full-screen search sheet with Airbnb-style tabs
//  Extracted from FeedView for better organization
//


#if !SKIP
import SwiftUI

// MARK: - Full Search Sheet (Airbnb-style)

struct FeedSearchSheet: View {
    @Environment(\.dismiss) private var dismiss: DismissAction
    @Environment(\.translationService) private var t
    @Binding var searchText: String
    @FocusState private var isSearchFocused: Bool
    @State private var selectedTab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search tabs
                HStack(spacing: Spacing.xl) {
                    SearchTab(title: t.t("search.tab.food"), isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    SearchTab(title: t.t("search.tab.location"), isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    SearchTab(title: t.t("search.tab.category"), isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.md)

                Divider()
                    .padding(.top, Spacing.md)

                // Search content
                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        // Search input card
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text(searchTabTitle)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.DesignSystem.text)

                            HStack(spacing: Spacing.sm) {
                                AppLogoView(size: .small, showGlow: false)
                                    .clipShape(Circle())

                                TextField(searchTabPlaceholder, text: $searchText)
                                    .font(.system(size: 16))
                                    .foregroundColor(.DesignSystem.text)
                                    .focused($isSearchFocused)
                            }
                            .padding(Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: CornerRadius.medium)
                                    .fill(Color.DesignSystem.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                                            .stroke(
                                                isSearchFocused
                                                    ? Color.DesignSystem.text
                                                    : Color.DesignSystem.glassBorder,
                                                lineWidth: isSearchFocused ? 2 : 1,
                                            ),
                                    ),
                            )
                        }
                        .padding(Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.large)
                                .fill(Color.DesignSystem.background)
                                .shadow(color: .black.opacity(0.08), radius: 16, y: 4),
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.lg)

                        // Recent searches
                        if !searchText.isEmpty {
                            // Show search suggestions
                        } else {
                            recentSearches
                        }
                    }
                }

                Spacer()

                // Bottom action bar
                HStack {
                    GlassButton(t.t("common.clear_all"), style: .ghost) {
                        searchText = ""
                        HapticManager.light()
                    }

                    Spacer()

                    Button {
                        HapticManager.success()
                        dismiss()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16, weight: .semibold))

                            Text(t.t("common.search"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [
                                    .DesignSystem.brandGreen, .DesignSystem.brandGreen.opacity(0.8)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .background(
                    Rectangle()
                        .fill(Color.DesignSystem.background)
                        .shadow(color: .black.opacity(0.05), radius: 8, y: -4),
                )
            }
            .background(Color.DesignSystem.surface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.DesignSystem.text)
                            .frame(width: 30.0, height: 30)
                            .background(
                                Circle()
                                    .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                            )
                    }
                }
            }
            .onAppear {
                isSearchFocused = true
            }
        }
        #if !SKIP
        .presentationDragIndicator(.visible)
        #endif
    }

    private var searchTabTitle: String {
        switch selectedTab {
        case 0: t.t("search.title.food")
        case 1: t.t("search.title.location")
        case 2: t.t("search.title.category")
        default: t.t("common.search")
        }
    }

    private var searchTabPlaceholder: String {
        switch selectedTab {
        case 0: t.t("search.placeholder.food")
        case 1: t.t("search.placeholder.location")
        case 2: t.t("search.placeholder.category")
        default: t.t("search.placeholder.default")
        }
    }

    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(t.t("search.recent_searches"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.DesignSystem.textSecondary)
                .padding(.horizontal, Spacing.lg)

            VStack(spacing: 0) {
                RecentSearchRow(icon: "🍎", title: t.t("search.recent.fresh_produce"), subtitle: t.t("search.recent.near_you"))
                RecentSearchRow(icon: "❄️", title: t.t("search.recent.community_fridges"), subtitle: t.t("search.recent.within_distance", args: ["distance": "5 km"]))
                RecentSearchRow(icon: "🙌🏻", title: t.t("search.recent.volunteer"), subtitle: t.t("search.recent.any_location"))
            }
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.large)
                    .fill(Color.DesignSystem.background),
            )
            .padding(.horizontal, Spacing.md)
        }
    }
}

// MARK: - Search Tab

private struct SearchTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .DesignSystem.text : .DesignSystem.textSecondary)

                Rectangle()
                    .fill(isSelected ? Color.DesignSystem.text : Color.clear)
                    .frame(height: 2.0)
            }
        }
    }
}

// MARK: - Recent Search Row

private struct RecentSearchRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(icon)
                .font(.system(size: 24))
                .frame(width: 44.0, height: 44)
                .background(
                    Circle()
                        .fill(Color.DesignSystem.surface),
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.DesignSystem.text)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Type Alias for Backward Compatibility

typealias FullSearchSheet = FeedSearchSheet

#endif
