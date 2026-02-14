//
//  GlassSearchHeader.swift
//  FoodShare
//
//  Created by Claude Code on 2025-12-29.
//

import SwiftUI
import FoodShareDesignSystem

/// DEPRECATED: Use GlassSearchBar directly with AppLogoView and filter button pattern instead.
///
/// This component is deprecated in favor of the simpler pattern used in ExploreTabView and MessagingView:
/// ```swift
/// HStack(spacing: Spacing.sm) {
///     AppLogoView(size: .custom(56), showGlow: false, circular: true)
///     GlassSearchBar(text: $searchText, placeholder: "Search...", ...)
///     filterButton // 56x56 circular glass button
/// }
/// ```
///
/// A reusable search header component that encapsulates the search bar + trailing buttons pattern
/// used across ForumView, MessagingView, and ProfileView.
///
/// Features:
/// - Integrated GlassSearchBar with consistent styling
/// - Automatic cancel button on search activation
/// - Generic trailing content for view-specific actions
/// - Optional debounced search callback
/// - Smooth transitions and animations
@available(*, deprecated, message: "Use GlassSearchBar directly with AppLogoView and filter button pattern instead")
struct GlassSearchHeader<TrailingContent: View>: View {
    // MARK: - Properties

    /// The search text binding
    @Binding var searchText: String

    /// Whether the search is active (determines cancel button visibility)
    @Binding var isSearchActive: Bool

    /// Focus state binding for the search field
    @FocusState.Binding var isSearchFocused: Bool

    /// Placeholder text for the search bar
    let placeholder: String

    /// Optional callback triggered on search text changes (debounced)
    let onSearch: ((String) async -> Void)?

    /// Debounce delay in milliseconds (default: 300ms)
    let debounceMs: Int

    /// Trailing buttons content (visible when search is inactive)
    @ViewBuilder let trailingButtons: () -> TrailingContent

    // MARK: - State

    @State private var searchTask: Task<Void, Never>?
    @Environment(\.translationService) private var t

    // MARK: - Initialization

    /// Creates a new search header
    /// - Parameters:
    ///   - searchText: Binding to the search text
    ///   - isSearchActive: Binding to the search active state
    ///   - isSearchFocused: FocusState binding for the search field
    ///   - placeholder: Placeholder text for the search bar
    ///   - onSearch: Optional callback for search text changes
    ///   - debounceMs: Debounce delay in milliseconds (default: 300)
    ///   - trailingButtons: View builder for trailing action buttons
    init(
        searchText: Binding<String>,
        isSearchActive: Binding<Bool>,
        isSearchFocused: FocusState<Bool>.Binding,
        placeholder: String,
        onSearch: ((String) async -> Void)? = nil,
        debounceMs: Int = 300,
        @ViewBuilder trailingButtons: @escaping () -> TrailingContent,
    ) {
        self._searchText = searchText
        self._isSearchActive = isSearchActive
        self._isSearchFocused = isSearchFocused
        self.placeholder = placeholder
        self.onSearch = onSearch
        self.debounceMs = debounceMs
        self.trailingButtons = trailingButtons
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Search bar
            GlassSearchBar(
                text: $searchText,
                placeholder: placeholder,
                isActive: $isSearchActive,
                isFocused: $isSearchFocused,
            )
            .onChange(of: searchText) { _, newValue in
                handleSearchTextChange(newValue)
            }

            // Trailing buttons (visible when search inactive)
            if !isSearchActive {
                trailingButtons()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // Cancel button (visible when search active)
            if isSearchActive {
                Button {
                    cancelSearch()
                } label: {
                    Text(t.t("common.cancel"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(Color.DesignSystem.themed.primary)
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .padding(.top, Spacing.md)
        .background(
            Color.DesignSystem.background
                .ignoresSafeArea(edges: .top),
        )
        .animation(.smooth(duration: 0.3), value: isSearchActive)
    }

    // MARK: - Private Methods

    /// Handles search text changes with debouncing
    private func handleSearchTextChange(_ newValue: String) {
        guard let onSearch else { return }

        // Cancel previous search task
        searchTask?.cancel()

        // Create new debounced search task
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(debounceMs))

            guard !Task.isCancelled else { return }

            await onSearch(newValue)
        }
    }

    /// Cancels the search and resets state
    private func cancelSearch() {
        withAnimation(.smooth(duration: 0.3)) {
            searchText = ""
            isSearchActive = false
            isSearchFocused = false
        }

        // Cancel any pending search
        searchTask?.cancel()
        searchTask = nil
    }
}

// MARK: - Convenience Initializer (No Trailing Content)

extension GlassSearchHeader where TrailingContent == EmptyView {
    /// Creates a search header without trailing buttons
    /// - Parameters:
    ///   - searchText: Binding to the search text
    ///   - isSearchActive: Binding to the search active state
    ///   - isSearchFocused: FocusState binding for the search field
    ///   - placeholder: Placeholder text for the search bar
    ///   - onSearch: Optional callback for search text changes
    ///   - debounceMs: Debounce delay in milliseconds (default: 300)
    init(
        searchText: Binding<String>,
        isSearchActive: Binding<Bool>,
        isSearchFocused: FocusState<Bool>.Binding,
        placeholder: String,
        onSearch: ((String) async -> Void)? = nil,
        debounceMs: Int = 300,
    ) {
        self.init(
            searchText: searchText,
            isSearchActive: isSearchActive,
            isSearchFocused: isSearchFocused,
            placeholder: placeholder,
            onSearch: onSearch,
            debounceMs: debounceMs,
            trailingButtons: { EmptyView() },
        )
    }
}

// MARK: - Preview

#Preview("With Trailing Buttons") {
    @Previewable @State var searchText = ""
    @Previewable @State var isSearchActive = false
    @Previewable @FocusState var isSearchFocused: Bool

    VStack(spacing: 0) {
        GlassSearchHeader(
            searchText: $searchText,
            isSearchActive: $isSearchActive,
            isSearchFocused: $isSearchFocused,
            placeholder: "Search messages...",
            onSearch: { query in
                print("Searching for: \(query)")
            },
        ) {
            Button {
                print("Settings tapped")
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 20))
                    .foregroundColor(Color.DesignSystem.themed.primary)
                    .frame(width: 44, height: 44)
            }
        }

        Spacer()
    }
    .background(Color.DesignSystem.background)
}

#Preview("Without Trailing Buttons") {
    @Previewable @State var searchText = ""
    @Previewable @State var isSearchActive = false
    @Previewable @FocusState var isSearchFocused: Bool

    VStack(spacing: 0) {
        GlassSearchHeader(
            searchText: $searchText,
            isSearchActive: $isSearchActive,
            isSearchFocused: $isSearchFocused,
            placeholder: "Search forum...",
            onSearch: { query in
                print("Searching for: \(query)")
            },
        )

        Spacer()
    }
    .background(Color.DesignSystem.background)
}

#Preview("Search Active") {
    @Previewable @State var searchText = "test query"
    @Previewable @State var isSearchActive = true
    @Previewable @FocusState var isSearchFocused: Bool

    VStack(spacing: 0) {
        GlassSearchHeader(
            searchText: $searchText,
            isSearchActive: $isSearchActive,
            isSearchFocused: $isSearchFocused,
            placeholder: "Search...",
            onSearch: { query in
                print("Searching for: \(query)")
            },
        ) {
            Button {
                print("Filter tapped")
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20))
                    .foregroundColor(Color.DesignSystem.themed.primary)
                    .frame(width: 44, height: 44)
            }
        }

        Spacer()
    }
    .background(Color.DesignSystem.background)
}
