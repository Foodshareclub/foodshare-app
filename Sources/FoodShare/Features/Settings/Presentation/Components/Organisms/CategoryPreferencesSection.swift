// MARK: - CategoryPreferencesSection.swift
// Organism Component: All Categories with Search/Filter
// FoodShare iOS - Liquid Glass Design System
// Version: 1.0 - Enterprise Grade



#if !SKIP
import SwiftUI

/// A section displaying all notification category preferences with search and filter.
///
/// This organism component provides:
/// - Searchable category list
/// - Category cards with channel breakdowns
/// - Bulk actions
/// - Loading states
/// - Empty states
///
/// ## Usage
/// ```swift
/// CategoryPreferencesSection(viewModel: viewModel)
/// ```
@MainActor
public struct CategoryPreferencesSection: View {
    // MARK: - Properties

    @Bindable private var viewModel: NotificationPreferencesViewModel

    // MARK: - State

    @State private var expandedCategories: Set<NotificationCategory> = []

    // MARK: - Initialization

    /// Creates a new category preferences section.
    ///
    /// - Parameter viewModel: The notification preferences view model
    public init(viewModel: NotificationPreferencesViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: Spacing.md) {
            // Section header
            sectionHeader

            // Search bar
            searchBar

            // Category cards
            if viewModel.filteredCategories.isEmpty {
                emptyState
            } else {
                categoryCards
            }

            // Bulk actions
            if !viewModel.filteredCategories.isEmpty {
                bulkActions
            }
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Notification Preferences")
                    .font(.DesignSystem.headlineLarge)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text("Fine-tune notifications for each category")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.DesignSystem.textTertiary)

            TextField("Search categories", text: $viewModel.searchQuery)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textPrimary)
                .autocorrectionDisabled()

            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.DesignSystem.textTertiary)
                }
            }
        }
        .padding(Spacing.sm)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Category Cards

    private var categoryCards: some View {
        LazyVStack(spacing: Spacing.sm) {
            ForEach(viewModel.filteredCategories, id: \.self) { category in
                CategoryPreferenceCard(
                    category: category,
                    preferences: buildPreferences(for: category),
                    isExpanded: expandedCategories.contains(category),
                    onToggle: { channel in
                        await viewModel.togglePreference(category: category, channel: channel)
                    },
                    onFrequencyChange: { channel, frequency in
                        await viewModel.updateFrequency(category: category, channel: channel, frequency: frequency)
                    },
                    isLoading: { channel in
                        viewModel.isUpdating(category: category, channel: channel)
                    },
                    isChannelAvailable: { channel in
                        switch channel {
                        case .push:
                            viewModel.isPushAvailable
                        case .email:
                            viewModel.isEmailAvailable
                        case .sms:
                            viewModel.isSMSAvailable
                        case .inApp:
                            true
                        }
                    },
                )
                .onTapGesture {
                    withAnimation(.smooth) {
                        if expandedCategories.contains(category) {
                            expandedCategories.remove(category)
                        } else {
                            expandedCategories.insert(category)
                        }
                    }
                    HapticFeedback.light()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.DesignSystem.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("No categories found")
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.textPrimary)

                Text("Try adjusting your search")
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Button("Clear Search") {
                viewModel.searchQuery = ""
            }
            .buttonStyle(.bordered)
            .tint(.DesignSystem.brandBlue)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.xl)
        .background(Color.DesignSystem.glassBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Bulk Actions

    private var bulkActions: some View {
        VStack(spacing: Spacing.sm) {
            Text("Quick Actions")
                .font(.DesignSystem.bodySmall)
                .foregroundColor(.DesignSystem.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.sm) {
                // Expand all
                Button {
                    withAnimation(.smooth) {
                        expandedCategories = Set(viewModel.filteredCategories)
                    }
                    HapticFeedback.light()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                        Text("Expand All")
                    }
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.brandBlue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.DesignSystem.brandBlue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Collapse all
                Button {
                    withAnimation(.smooth) {
                        expandedCategories.removeAll()
                    }
                    HapticFeedback.light()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                        Text("Collapse All")
                    }
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.DesignSystem.textSecondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Helpers

    private func buildPreferences(for category: NotificationCategory) -> [NotificationChannel: CategoryPreference] {
        var dict: [NotificationChannel: CategoryPreference] = [:]

        for channel in NotificationChannel.allCases {
            dict[channel] = viewModel.preferences.preference(for: category, channel: channel)
        }

        return dict
    }
}

// MARK: - Preview

#Preview("Category Preferences Section") {
    ScrollView {
        CategoryPreferencesSection(viewModel: .preview)
            .padding(Spacing.md)
    }
    .background(Color.DesignSystem.background)
}

#Preview("With Search") {
    struct PreviewContainer: View {
        @State private var viewModel = NotificationPreferencesViewModel.preview

        var body: some View {
            ScrollView {
                CategoryPreferencesSection(viewModel: viewModel)
                    .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .onAppear {
                viewModel.searchQuery = "post"
            }
        }
    }

    return PreviewContainer()
}

#Preview("Empty State") {
    struct PreviewContainer: View {
        @State private var viewModel = NotificationPreferencesViewModel.preview

        var body: some View {
            ScrollView {
                CategoryPreferencesSection(viewModel: viewModel)
                    .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .onAppear {
                viewModel.searchQuery = "nonexistent"
            }
        }
    }

    return PreviewContainer()
}


#endif
