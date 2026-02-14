//
//  GlassSearchBar.swift
//  Foodshare
//
//  Liquid Glass search bar with animated focus states
//  Matches web app search functionality
//

import SwiftUI
import FoodShareDesignSystem

struct GlassSearchBar: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: (() -> Void)?
    let onClear: (() -> Void)?

    // Internal or external focus state
    @FocusState private var internalIsFocused: Bool
    private var externalIsFocused: FocusState<Bool>.Binding?
    private var externalIsActive: Binding<Bool>?

    @State private var isAnimating = false
    @Environment(\.translationService) private var t

    // Computed property to use either external or internal focus state
    private var isFocused: Bool {
        externalIsFocused?.wrappedValue ?? internalIsFocused
    }

    init(
        text: Binding<String>,
        placeholder: String = "Search food, fridges, volunteers...",
        onSubmit: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil,
    ) {
        _text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onClear = onClear
        self.externalIsFocused = nil
        self.externalIsActive = nil
    }

    // New initializer with external focus state bindings for GlassSearchHeader
    init(
        text: Binding<String>,
        placeholder: String = "Search food, fridges, volunteers...",
        isActive: Binding<Bool>,
        isFocused: FocusState<Bool>.Binding,
        onSubmit: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil,
    ) {
        _text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onClear = onClear
        self.externalIsFocused = isFocused
        self.externalIsActive = isActive
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Search Icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isFocused ? .DesignSystem.brandGreen : .DesignSystem.textSecondary)
                .animation(.interpolatingSpring(stiffness: 400, damping: 20), value: isFocused)

            // Text Field
            TextField(placeholder, text: $text)
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.text)
                .focused(externalIsFocused ?? $internalIsFocused)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit {
                    onSubmit?()
                }
                .onChange(of: text) { _, newValue in
                    // Update isActive when using external bindings
                    externalIsActive?.wrappedValue = !newValue.isEmpty || isFocused
                }
                .onChange(of: isFocused) { _, focused in
                    // Update isActive when focus changes
                    externalIsActive?.wrappedValue = focused || !text.isEmpty
                }
                .accessibilityLabel("Search")
                .accessibilityHint(placeholder)

            // Clear Button
            if !text.isEmpty {
                Button {
                    withAnimation(.interpolatingSpring(stiffness: 400, damping: 20)) {
                        text = ""
                    }
                    onClear?()
                    HapticManager.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm + 2)
        .background(searchBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    isFocused ? Color.DesignSystem.brandGreen.opacity(0.5) : Color.DesignSystem.glassBorder,
                    lineWidth: isFocused ? 2 : 1,
                ),
        )
        .shadow(
            color: isFocused ? Color.DesignSystem.brandGreen.opacity(0.15) : .clear,
            radius: 12,
            y: 4,
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
    }

    private var searchBackground: some View {
        Capsule()
            .fill(.ultraThinMaterial)
    }
}

// MARK: - Expandable Search Bar

struct ExpandableSearchBar: View {
    @Binding var text: String
    @Binding var isExpanded: Bool
    let placeholder: String
    let onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool
    @Environment(\.translationService) private var t

    init(
        text: Binding<String>,
        isExpanded: Binding<Bool>,
        placeholder: String = "Search...",
        onSubmit: (() -> Void)? = nil,
    ) {
        _text = text
        _isExpanded = isExpanded
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if isExpanded {
                GlassSearchBar(
                    text: $text,
                    placeholder: placeholder,
                    onSubmit: onSubmit,
                    onClear: {
                        if text.isEmpty {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isExpanded = false
                            }
                        }
                    },
                )
                .focused($isFocused)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity),
                ))

                Button(t.t("common.cancel")) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        text = ""
                        isExpanded = false
                        isFocused = false
                    }
                }
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.brandGreen)
            } else {
                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(100))
                        isFocused = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.DesignSystem.text)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    Circle()
                                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                ),
                        )
                }
            }
        }
        .onChange(of: isExpanded) { _, newValue in
            if newValue {
                isFocused = true
            }
        }
    }
}

// MARK: - Search Suggestions

struct GlassSearchSuggestions: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    onSelect(suggestion)
                    HapticManager.selection()
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.DesignSystem.textSecondary)

                        Text(suggestion)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.text)

                        Spacer()

                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 12))
                            .foregroundColor(.DesignSystem.textTertiary)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                }

                if suggestion != suggestions.last {
                    Divider()
                        .background(Color.DesignSystem.glassBorder)
                        .padding(.leading, Spacing.xl + Spacing.md)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                ),
        )
        .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
    }
}

// MARK: - Recent Searches

struct RecentSearchesView: View {
    let searches: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(t.t("search.recent_searches"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundColor(.DesignSystem.textSecondary)

                Spacer()

                Button(t.t("common.clear")) {
                    onClear()
                }
                .font(.DesignSystem.labelSmall)
                .foregroundColor(.DesignSystem.brandGreen)
            }
            .padding(.horizontal, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(searches, id: \.self) { search in
                        Button {
                            onSelect(search)
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 12))
                                Text(search)
                                    .font(.DesignSystem.bodySmall)
                            }
                            .foregroundColor(.DesignSystem.text)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                Capsule()
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                                    ),
                            )
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }
}

#Preview("Search Bar") {
    VStack(spacing: Spacing.xl) {
        GlassSearchBar(text: .constant(""))

        GlassSearchBar(text: .constant("apples"))

        GlassSearchSuggestions(
            suggestions: ["Fresh apples", "Apple pie", "Apple cider"],
            onSelect: { _ in },
        )
        .padding(.horizontal)

        RecentSearchesView(
            searches: ["bread", "vegetables", "community fridge"],
            onSelect: { _ in },
            onClear: {},
        )
    }
    .padding()
    .background(Color.DesignSystem.background)
}
