//
//  SearchView.swift
//  Foodshare
//
//  Complete search view with filters and suggestions
//  Enhanced with Liquid Glass Design System v26
//


#if !SKIP
import SwiftUI



struct SearchView: View {
    
    @Environment(\.translationService) private var t
    @State private var viewModel: SearchViewModel
    @State private var showFilters = false
    @State private var hasAppeared = false
    @FocusState private var isSearchFocused: Bool

    init(viewModel: SearchViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                Color.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                        .staggeredAppearance(index: 0, baseDelay: 0.1)

                    // Filter chips
                    if viewModel.activeFiltersCount > 0 {
                        filterChips
                            .staggeredAppearance(index: 1, baseDelay: 0.1)
                    }

                    // Voice search overlay
                    if viewModel.isVoiceSearchActive {
                        voiceSearchOverlay
                    }

                    // Content
                    if viewModel.isSearching {
                        loadingView
                    } else if viewModel.hasResults {
                        resultsView
                    } else if viewModel.searchQuery.isEmpty, !viewModel.savedSearches.isEmpty {
                        savedSearchesView
                    } else if viewModel.searchQuery.isEmpty, !viewModel.recentSearches.isEmpty {
                        recentSearchesView
                    } else if viewModel.searchQuery.isEmpty {
                        emptyStateView
                    } else {
                        noResultsView
                    }
                }
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 20)
            }
            .navigationTitle(t.t("search.title._title"))
            .navigationBarTitleDisplayMode(.large)
            .glassNavigationBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.light()
                        showFilters.toggle()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.DesignSystem.glassBackground)
                                .frame(width: 36.0, height: 36)

                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 16))
                                .foregroundColor(viewModel.activeFiltersCount > 0
                                    ? .DesignSystem.primary
                                    : .DesignSystem.textSecondary)

                            if viewModel.activeFiltersCount > 0 {
                                Circle()
                                    .fill(Color.DesignSystem.primary)
                                    .frame(width: 8.0, height: 8)
                                    .offset(x: 10, y: -10)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showFilters) {
                SearchFilterView(viewModel: viewModel)
                    .glassSheet()
            }
            .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
                Button(t.t("common.ok"), role: .cancel) {
                    viewModel.dismissError()
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                hasAppeared = true
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.DesignSystem.textSecondary)

            TextField(t.t("search.placeholder._title"), text: $viewModel.searchQuery)
                .font(.DesignSystem.bodyLarge)
                .foregroundColor(.DesignSystem.text)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    Task { await viewModel.search() }
                }
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.searchDebounced()
                }

            if !viewModel.searchQuery.isEmpty {
                Button {
                    HapticManager.light()
                    viewModel.clearSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Voice search button
            voiceSearchButton
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.searchQuery.isEmpty)
    }

    private var voiceSearchButton: some View {
        Button {
            HapticManager.medium()
            if viewModel.isVoiceSearchActive {
                viewModel.stopVoiceSearch()
            } else {
                Task {
                    let granted = await viewModel.requestVoiceSearchPermission()
                    if granted {
                        viewModel.startVoiceSearch()
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(viewModel.isVoiceSearchActive
                        ? Color.DesignSystem.error
                        : Color.DesignSystem.glassBackground)
                    .frame(width: 36.0, height: 36)

                if viewModel.isVoiceSearchActive {
                    // Pulsing animation when recording
                    Circle()
                        .stroke(Color.DesignSystem.error.opacity(0.5), lineWidth: 2)
                        .frame(width: 36.0, height: 36)
                        .scaleEffect(viewModel.isVoiceSearchActive ? 1.3 : 1.0)
                        .opacity(viewModel.isVoiceSearchActive ? 0 : 1)
                        .animation(
                            .easeOut(duration: 1.0)
                                .repeatForever(autoreverses: false),
                            value: viewModel.isVoiceSearchActive,
                        )
                }

                Image(systemName: viewModel.isVoiceSearchActive ? "stop.fill" : "mic.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(viewModel.isVoiceSearchActive ? .white : .DesignSystem.textSecondary)
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                if viewModel.filters.categoryId != nil {
                    SearchFilterChip(title: t.t("search.filter.category"), onRemove: {
                        viewModel.selectCategory(nil)
                        Task { await viewModel.search() }
                    })
                }

                if viewModel.filters.maxDistanceKm != 10.0 {
                    SearchFilterChip(title: "\(Int(viewModel.filters.maxDistanceKm))km", onRemove: {
                        viewModel.filters.maxDistanceKm = 10.0
                        Task { await viewModel.search() }
                    })
                }

                if viewModel.filters.postType != nil {
                    SearchFilterChip(title: viewModel.filters.postType ?? "", onRemove: {
                        viewModel.filters.postType = nil
                        Task { await viewModel.search() }
                    })
                }

                Button(t.t("search.clear_all")) {
                    viewModel.clearFilters()
                    Task { await viewModel.search() }
                }
                .font(.DesignSystem.caption)
                .foregroundColor(.DesignSystem.primary)
            }
            .padding(.horizontal)
        }
        .padding(.bottom, Spacing.sm)
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(width: 80.0, height: 80)

                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.DesignSystem.primary)
            }

            Text(t.t("search.searching"))
                .font(.DesignSystem.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var resultsView: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                // Results header with save search button
                HStack {
                    Text(t.t("search.results_count", args: ["count": String(viewModel.filteredResults.count)]))
                        .font(.DesignSystem.labelMedium)
                        .foregroundColor(.DesignSystem.textSecondary)

                    Spacer()

                    // Save search button
                    Button {
                        HapticManager.success()
                        viewModel.saveCurrentSearch()
                    } label: {
                        HStack(spacing: Spacing.xxs) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 12))
                            Text(t.t("common.save"))
                                .font(.DesignSystem.labelSmall)
                        }
                        .foregroundColor(.DesignSystem.primary)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(Color.DesignSystem.primary.opacity(0.1)),
                        )
                    }
                }
                .padding(.horizontal, Spacing.md)
                .staggeredAppearance(index: 0, baseDelay: 0.05)

                // Search stats
                if viewModel.searchStats.totalResults > 0 {
                    searchStatsBar
                        .staggeredAppearance(index: 1, baseDelay: 0.05)
                }

                ForEach(Array(viewModel.filteredResults.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        FoodItemDetailView(item: item)
                    } label: {
                        SearchResultCard(item: item)
                    }
                    .buttonStyle(.plain)
                    .staggeredAppearance(index: index + 2, baseDelay: 0.05)
                }
            }
            .padding(Spacing.md)
        }
    }

    private var searchStatsBar: some View {
        HStack(spacing: Spacing.md) {
            ForEach(Array(viewModel.searchStats.categoryBreakdown.prefix(4)), id: \.key) { category, count in
                HStack(spacing: Spacing.xxs) {
                    Text(category.capitalized)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)

                    Text("\(count)")
                        .font(.DesignSystem.captionSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(.DesignSystem.text)
                }
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xxs)
                .background(
                    Capsule()
                        .fill(Color.DesignSystem.glassBackground),
                )
            }

            Spacer()
        }
        .padding(.horizontal, Spacing.md)
    }

    private var recentSearchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14))
                        Text(t.t("search.recent._title"))
                            .font(.DesignSystem.labelLarge)
                    }
                    .foregroundColor(.DesignSystem.textSecondary)

                    Spacer()

                    if !viewModel.recentSearches.isEmpty {
                        Button {
                            HapticManager.light()
                            viewModel.clearRecentSearches()
                        } label: {
                            Text(t.t("common.clear"))
                                .font(.DesignSystem.labelSmall)
                                .foregroundColor(.DesignSystem.primary)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .staggeredAppearance(index: 0, baseDelay: 0.1)

                ForEach(Array(viewModel.recentSearches.enumerated()), id: \.element) { index, search in
                    Button {
                        HapticManager.light()
                        viewModel.selectRecentSearch(search)
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: "clock")
                                .font(.system(size: 16))
                                .foregroundColor(.DesignSystem.textSecondary)

                            Text(search)
                                .font(.DesignSystem.bodyMedium)
                                .foregroundColor(.DesignSystem.text)

                            Spacer()

                            Image(systemName: "arrow.up.left")
                                .font(.system(size: 12))
                                .foregroundColor(.DesignSystem.textTertiary)
                        }
                        .padding(Spacing.md)
                        .glassEffect(cornerRadius: CornerRadius.medium)
                    }
                    .buttonStyle(.plain)
                    .pressAnimation()
                    .padding(.horizontal, Spacing.md)
                    .staggeredAppearance(index: index + 1, baseDelay: 0.1)
                }
            }
            .padding(.top, Spacing.md)
        }
    }

    // MARK: - Voice Search Overlay

    private var voiceSearchOverlay: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            // Voice waveform visualization
            GlassVoiceWaveform(
                isActive: Binding.constant(viewModel.isVoiceSearchActive),
                amplitude: 0.7,
                style: GlassVoiceWaveform.WaveformStyle.circular,
                barCount: 32,
                primaryColor: Color.DesignSystem.brandGreen,
                secondaryColor: Color.DesignSystem.error,
                micSize: 70,
                showMic: true
            )
            .frame(height: 220.0)

            VStack(spacing: Spacing.sm) {
                Text(t.t("search.listening"))
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(.DesignSystem.text)

                if !viewModel.voiceSearchText.isEmpty {
                    Text("\"\(viewModel.voiceSearchText)\"")
                        .font(.DesignSystem.bodyLarge)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .italic()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.xl)
                } else {
                    Text(t.t("search.voice_prompt"))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                if let error = viewModel.voiceSearchError {
                    Text(error)
                        .font(.DesignSystem.caption)
                        .foregroundColor(.DesignSystem.error)
                }
            }

            Button {
                HapticManager.light()
                viewModel.stopVoiceSearch()
            } label: {
                Text(t.t("common.cancel"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.DesignSystem.glassBackground),
                    )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.DesignSystem.background.opacity(0.95))
        .transition(.opacity)
    }

    // MARK: - Saved Searches View

    private var savedSearchesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Saved searches section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    HStack {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "bookmark.fill")
                                .font(.system(size: 14))
                            Text(t.t("search.saved_searches"))
                                .font(.DesignSystem.labelLarge)
                        }
                        .foregroundColor(.DesignSystem.textSecondary)

                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)

                    ForEach(Array(viewModel.savedSearches.prefix(5).enumerated()), id: \.element.id) { index, saved in
                        SavedSearchRow(saved: saved) {
                            viewModel.applySavedSearch(saved)
                        } onDelete: {
                            viewModel.deleteSavedSearch(saved)
                        }
                        .padding(.horizontal, Spacing.md)
                        .staggeredAppearance(index: index, baseDelay: 0.05)
                    }
                }

                // Recent searches section
                if !viewModel.recentSearches.isEmpty {
                    recentSearchesContent
                }

                // Popular searches
                popularSearchesSection
            }
            .padding(.top, Spacing.md)
        }
    }

    private var popularSearchesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 14))
                Text(t.t("search.popular"))
                    .font(.DesignSystem.labelLarge)
            }
            .foregroundColor(.DesignSystem.textSecondary)
            .padding(.horizontal, Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(viewModel.popularSearches, id: \.self) { search in
                        Button {
                            HapticManager.light()
                            viewModel.searchQuery = search
                            Task { await viewModel.search() }
                        } label: {
                            Text(search)
                                .font(.DesignSystem.labelSmall)
                                .foregroundColor(.DesignSystem.text)
                                .padding(.horizontal, Spacing.md)
                                .padding(.vertical, Spacing.sm)
                                .background(
                                    Capsule()
                                        .fill(Color.DesignSystem.glassBackground)
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

    private var recentSearchesContent: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14))
                    Text(t.t("search.recent._title"))
                        .font(.DesignSystem.labelLarge)
                }
                .foregroundColor(.DesignSystem.textSecondary)

                Spacer()

                Button {
                    HapticManager.light()
                    viewModel.clearRecentSearches()
                } label: {
                    Text(t.t("search.clear"))
                        .font(.DesignSystem.labelSmall)
                        .foregroundColor(.DesignSystem.primary)
                }
            }
            .padding(.horizontal, Spacing.md)

            ForEach(Array(viewModel.recentSearches.prefix(5).enumerated()), id: \.element) { _, search in
                Button {
                    HapticManager.light()
                    viewModel.selectRecentSearch(search)
                } label: {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                            .foregroundColor(.DesignSystem.textSecondary)

                        Text(search)
                            .font(.DesignSystem.bodyMedium)
                            .foregroundColor(.DesignSystem.text)

                        Spacer()

                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 12))
                            .foregroundColor(.DesignSystem.textTertiary)
                    }
                    .padding(Spacing.md)
                    .glassEffect(cornerRadius: CornerRadius.medium)
                }
                .buttonStyle(.plain)
                .pressAnimation()
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.primary.opacity(0.2),
                                Color.DesignSystem.primary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 100.0, height: 100)

                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.DesignSystem.primary.opacity(0.7))
            }

            VStack(spacing: Spacing.sm) {
                Text(t.t("search.search_for_food"))
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(.DesignSystem.text)

                Text(t.t("search.find_surplus_food"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            // Popular searches
            popularSearchesSection

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.DesignSystem.textSecondary.opacity(0.15),
                                Color.DesignSystem.textSecondary.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        ),
                    )
                    .frame(width: 100.0, height: 100)

                Image(systemName: "tray")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.DesignSystem.textSecondary.opacity(0.7))
            }

            VStack(spacing: Spacing.sm) {
                Text(t.t("search.no_results"))
                    .font(.DesignSystem.headlineMedium)
                    .foregroundColor(.DesignSystem.text)

                Text(t.t("search.adjust_filters"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // Suggestion button
            Button {
                HapticManager.light()
                showFilters = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "slider.horizontal.3")
                    Text(t.t("search.adjust_filters"))
                }
                .font(.DesignSystem.labelMedium)
                .foregroundColor(.DesignSystem.primary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
                .background(
                    Capsule()
                        .fill(Color.DesignSystem.primary.opacity(0.15)),
                )
            }
            .pressAnimation()

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Views

private struct SearchFilterChip: View {
    let title: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Text(title)
                .font(.DesignSystem.labelSmall)
                .fontWeight(.medium)

            Button {
                HapticManager.light()
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                .fill(Color.DesignSystem.primary.opacity(0.15))
                .overlay(
                    Capsule()
                        .strokeBorder(Color.DesignSystem.primary.opacity(0.3), lineWidth: 1),
                ),
        )
        .foregroundColor(.DesignSystem.primary)
    }
}

struct SearchResultCard: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Image with glass border
            ZStack {
                AsyncImage(url: URL(string: item.primaryImageUrl ?? "")) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 24))
                            .foregroundColor(.DesignSystem.textSecondary)
                    case .empty:
                        ProgressView()
                            .tint(.DesignSystem.textSecondary)
                    @unknown default:
                        Color.DesignSystem.glassBackground
                    }
                }
            }
            .frame(width: 80.0, height: 80)
            .background(Color.DesignSystem.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(Color.glassBorder, lineWidth: 1),
            )

            // Details
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.title)
                    .font(.DesignSystem.bodyLarge)
                    .fontWeight(.semibold)
                    .foregroundColor(.DesignSystem.text)
                    .lineLimit(1)

                if let description = item.description {
                    Text(description)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: Spacing.xxs)

                // Location (uses stripped address for privacy)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(item.displayAddress ?? "Pickup location")
                        .font(.DesignSystem.caption)
                        .lineLimit(1)
                }
                .foregroundColor(.DesignSystem.textTertiary)
            }

            Spacer(minLength: 0)

            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.DesignSystem.textTertiary)
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

struct SearchFilterView: View {
    @Environment(\.translationService) private var t
    @Bindable var viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss: DismissAction

    // Collapsible section state
    @State private var isSortExpanded = true
    @State private var isDistanceExpanded = true
    @State private var isTypeExpanded = true

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.md) {
                        // Sort By Section (Collapsible)
                        GlassExpander(
                            title: t.t("search.sort_by"),
                            subtitle: viewModel.filters.sortBy.rawValue,
                            icon: "arrow.up.arrow.down",
                            iconColor: .DesignSystem.brandGreen,
                            isExpanded: $isSortExpanded
                        ) {
                            VStack(spacing: Spacing.xs) {
                                ForEach(SearchFilters.SortOption.allCases, id: \.self) { option in
                                    filterOptionRow(
                                        title: option.rawValue,
                                        isSelected: viewModel.filters.sortBy == option
                                    ) {
                                        HapticManager.light()
                                        viewModel.filters.sortBy = option
                                    }
                                }
                            }
                            .padding(.top, Spacing.sm)
                        }

                        // Distance Section (Collapsible)
                        GlassExpander(
                            title: t.t("search.distance"),
                            subtitle: "\(Int(viewModel.filters.maxDistanceKm)) km",
                            icon: "location.circle",
                            iconColor: .DesignSystem.info,
                            isExpanded: $isDistanceExpanded
                        ) {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                HStack {
                                    Text("\(Int(viewModel.filters.maxDistanceKm))")
                                        .font(.DesignSystem.displaySmall)
                                        .fontWeight(.bold)
                                        .foregroundColor(.DesignSystem.primary)
                                        #if !SKIP
                                        .contentTransition(.numericText())
                                        #endif
                                        .animation(Animation.interpolatingSpring(stiffness: 280, damping: 25), value: viewModel.filters.maxDistanceKm)

                                    Text(t.t("common.km"))
                                        .font(.DesignSystem.bodyLarge)
                                        .foregroundColor(.DesignSystem.textSecondary)
                                }

                                Slider(value: $viewModel.filters.maxDistanceKm, in: 1 ... 50, step: 1)
                                    .tint(.DesignSystem.primary)
                                    #if !SKIP
                                    .sensoryFeedback(.selection, trigger: viewModel.filters.maxDistanceKm)
                                    #endif

                                HStack {
                                    Text(t.t("search.distance_min"))
                                        .font(.DesignSystem.caption)
                                        .foregroundColor(.DesignSystem.textTertiary)
                                    Spacer()
                                    Text(t.t("search.distance_max"))
                                        .font(.DesignSystem.caption)
                                        .foregroundColor(.DesignSystem.textTertiary)
                                }
                            }
                            .padding(.top, Spacing.sm)
                        }

                        // Post Type Section (Collapsible)
                        GlassExpander(
                            title: t.t("search.post_type"),
                            subtitle: viewModel.filters.postType?.capitalized ?? t.t("search.all_types"),
                            icon: "square.grid.2x2",
                            iconColor: .DesignSystem.warning,
                            isExpanded: $isTypeExpanded
                        ) {
                            VStack(spacing: Spacing.xs) {
                                filterOptionRow(
                                    title: t.t("search.all_types"),
                                    isSelected: viewModel.filters.postType == nil
                                ) {
                                    HapticManager.light()
                                    viewModel.filters.postType = nil
                                }

                                ForEach(["food", "fridge", "foodbank", "thing"], id: \.self) { type in
                                    filterOptionRow(
                                        title: type.capitalized,
                                        icon: iconForType(type),
                                        isSelected: viewModel.filters.postType == type
                                    ) {
                                        HapticManager.light()
                                        viewModel.filters.postType = type
                                    }
                                }
                            }
                            .padding(.top, Spacing.sm)
                        }
                    }
                    .padding(Spacing.md)
                }
            }
            .navigationTitle(t.t("search.filters"))
            .navigationBarTitleDisplayMode(.inline)
            .glassNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        HapticManager.light()
                        viewModel.clearFilters()
                    } label: {
                        Text(t.t("common.reset"))
                            .font(.DesignSystem.labelMedium)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        HapticManager.medium()
                        dismiss()
                        Task {
                            await viewModel.search()
                        }
                    } label: {
                        Text(t.t("common.apply"))
                            .font(.DesignSystem.labelMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.DesignSystem.primary)
                    }
                }
            }
        }
    }

    private func filterOptionRow(
        title: String,
        icon: String? = nil,
        isSelected: Bool,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(isSelected ? .DesignSystem.primary : .DesignSystem.textSecondary)
                        .frame(width: 24.0)
                }

                Text(title)
                    .font(.DesignSystem.bodyMedium)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.DesignSystem.primary)
                } else {
                    Circle()
                        .strokeBorder(Color.DesignSystem.textTertiary, lineWidth: 1.5)
                        .frame(width: 20.0, height: 20)
                }
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isSelected ? Color.DesignSystem.primary.opacity(0.1) : Color.clear),
            )
        }
        .buttonStyle(.plain)
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "food": "leaf.fill"
        case "fridge": "refrigerator.fill"
        case "foodbank": "building.2.fill"
        case "thing": "cube.fill"
        default: "circle.fill"
        }
    }
}

// MARK: - Saved Search Row

struct SavedSearchRow: View {
    let saved: SavedSearch
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.sm) {
                // Bookmark icon
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.DesignSystem.primary)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(saved.query)
                        .font(.DesignSystem.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.DesignSystem.text)

                    HStack(spacing: Spacing.xs) {
                        // Show active filters
                        if saved.filters.maxDistanceKm != 10.0 {
                            FilterBadge(text: "\(Int(saved.filters.maxDistanceKm))km")
                        }
                        if let postType = saved.filters.postType {
                            FilterBadge(text: postType.capitalized)
                        }
                        if saved.filters.sortBy != .distance {
                            FilterBadge(text: saved.filters.sortBy.rawValue)
                        }

                        Spacer()

                        Text(saved.formattedDate)
                            .font(.DesignSystem.captionSmall)
                            .foregroundColor(.DesignSystem.textTertiary)
                    }
                }

                Spacer()

                // Delete button
                Button {
                    HapticManager.light()
                    onDelete()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.DesignSystem.textTertiary)
                        .frame(width: 24.0, height: 24)
                        .background(
                            Circle()
                                .fill(Color.DesignSystem.glassBackground),
                        )
                }
            }
            .padding(Spacing.md)
            .glassEffect(cornerRadius: CornerRadius.medium)
        }
        .buttonStyle(.plain)
        .pressAnimation()
    }
}

// MARK: - Filter Badge

private struct FilterBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.DesignSystem.captionSmall)
            .foregroundColor(.DesignSystem.textSecondary)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(Color.DesignSystem.glassBackground),
            )
    }
}

// MARK: - Food Item Card (Reusable)

struct SearchFoodItemCard: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Image with glass effect
            ZStack {
                AsyncImage(url: URL(string: item.primaryImageUrl ?? "")) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        Image(systemName: "photo")
                            .font(.system(size: 28))
                            .foregroundColor(.DesignSystem.textSecondary)
                    case .empty:
                        ProgressView()
                            .tint(.DesignSystem.textSecondary)
                    @unknown default:
                        Color.DesignSystem.glassBackground
                    }
                }
            }
            .frame(width: 100.0, height: 100)
            .background(Color.DesignSystem.glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .strokeBorder(Color.glassBorder, lineWidth: 1),
            )

            // Details
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(item.title)
                    .font(.DesignSystem.titleMedium)
                    .foregroundColor(.DesignSystem.text)
                    .lineLimit(1)

                if let description = item.description {
                    Text(description)
                        .font(.DesignSystem.bodySmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: Spacing.xxs)

                // Location (uses stripped address for privacy)
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(item.displayAddress ?? "Pickup location")
                        .font(.DesignSystem.labelSmall)
                        .lineLimit(1)
                }
                .foregroundColor(.DesignSystem.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .glassEffect(cornerRadius: CornerRadius.large)
    }
}

#else
// MARK: - Android SearchView (Skip)

import SwiftUI

struct SearchView: View {
    @State private var searchQuery = ""
    @State private var results: [FoodItem] = []
    @State private var isSearching = false
    @State private var recentSearches: [String] = []
    @State private var hasSearched = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0.0) {
                // Search bar
                HStack(spacing: 10.0) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.white.opacity(0.5))
                    TextField("Search for food nearby...", text: $searchQuery)
                        .foregroundStyle(Color.white)
                        .submitLabel(.search)
                        .onSubmit {
                            Task { await performSearch() }
                        }

                    if !searchQuery.isEmpty {
                        Button(action: {
                            searchQuery = ""
                            results = []
                            hasSearched = false
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.white.opacity(0.5))
                        }
                    }
                }
                .padding(12.0)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12.0))
                .padding(.horizontal, 16.0)
                .padding(.top, 8.0)

                // Content
                if isSearching {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Text("Searching...")
                        .font(.system(size: 14.0))
                        .foregroundStyle(Color.gray)
                        .padding(.top, 8.0)
                    Spacer()
                } else if hasSearched && results.isEmpty {
                    Spacer()
                    VStack(spacing: 12.0) {
                        Image(systemName: "tray")
                            .font(.system(size: 48.0))
                            .foregroundStyle(Color.white.opacity(0.2))
                        Text("No results found")
                            .font(.system(size: 18.0, weight: .semibold))
                            .foregroundStyle(Color.white)
                        Text("Try different search terms")
                            .font(.system(size: 14.0))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    Spacer()
                } else if !results.isEmpty {
                    ScrollView {
                        LazyVStack(spacing: 8.0) {
                            Text("\(results.count) results")
                                .font(.system(size: 13.0))
                                .foregroundStyle(Color.white.opacity(0.5))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16.0)
                                .padding(.top, 8.0)

                            ForEach(results) { item in
                                NavigationLink(destination: FoodItemDetailView(item: item)) {
                                    SearchResultRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16.0)
                            }
                        }
                    }
                } else {
                    // Empty state with popular suggestions
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20.0) {
                            if !recentSearches.isEmpty {
                                VStack(alignment: .leading, spacing: 10.0) {
                                    HStack {
                                        Text("Recent Searches")
                                            .font(.system(size: 15.0, weight: .medium))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                        Spacer()
                                        Button("Clear") {
                                            recentSearches = []
                                        }
                                        .font(.system(size: 13.0))
                                        .foregroundStyle(Color(red: 0.2, green: 0.7, blue: 0.4))
                                    }

                                    ForEach(recentSearches, id: \.self) { search in
                                        Button(action: {
                                            searchQuery = search
                                            Task { await performSearch() }
                                        }) {
                                            HStack(spacing: 10.0) {
                                                Image(systemName: "clock")
                                                    .foregroundStyle(Color.white.opacity(0.4))
                                                Text(search)
                                                    .foregroundStyle(Color.white.opacity(0.7))
                                                Spacer()
                                            }
                                            .padding(12.0)
                                            .background(Color.white.opacity(0.05))
                                            .clipShape(RoundedRectangle(cornerRadius: 8.0))
                                        }
                                    }
                                }
                            }

                            // Popular searches
                            VStack(alignment: .leading, spacing: 10.0) {
                                Text("Popular Searches")
                                    .font(.system(size: 15.0, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.6))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8.0) {
                                        ForEach(["Fresh bread", "Vegetables", "Fruit", "Meals", "Dairy", "Snacks"], id: \.self) { term in
                                            Button(action: {
                                                searchQuery = term
                                                Task { await performSearch() }
                                            }) {
                                                Text(term)
                                                    .font(.system(size: 13.0))
                                                    .foregroundStyle(Color.white.opacity(0.7))
                                                    .padding(.horizontal, 14.0)
                                                    .padding(.vertical, 8.0)
                                                    .background(Color.white.opacity(0.08))
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16.0)
                        .padding(.top, 8.0)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))
            .navigationTitle("Search")
        }
    }

    private func performSearch() async {
        let query = searchQuery
        guard !query.isEmpty else { return }
        isSearching = true
        hasSearched = true

        // Save to recent searches
        if !recentSearches.contains(query) {
            recentSearches.insert(query, at: 0)
            if recentSearches.count > 5 {
                recentSearches = Array(recentSearches.prefix(5))
            }
        }

        let baseURL = AppEnvironment.supabaseURL ?? "https://api.foodshare.club"
        let apiKey = AppEnvironment.supabasePublishableKey ?? ""

        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(baseURL)/functions/v1/api-v1-search?q=\(encodedQuery)&limit=30") else {
            isSearching = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = AuthenticationService.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            decoder.dateDecodingStrategy = .iso8601

            // Try envelope format first
            if let envelope = try? decoder.decode(SearchEnvelope.self, from: data), let items = envelope.data {
                results = items
            } else if let items = try? decoder.decode([FoodItem].self, from: data) {
                results = items
            } else {
                results = []
            }
        } catch {
            results = []
        }

        isSearching = false
    }
}

private struct SearchEnvelope: Codable {
    let success: Bool
    let data: [FoodItem]?
}

private struct SearchResultRow: View {
    let item: FoodItem

    var body: some View {
        HStack(spacing: 12.0) {
            if let imageUrl = item.displayImageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: ContentMode.fill)
                            .frame(width: 72.0, height: 72.0)
                            .clipShape(RoundedRectangle(cornerRadius: 8.0))
                    default:
                        searchImagePlaceholder
                    }
                }
            } else {
                searchImagePlaceholder
            }

            VStack(alignment: .leading, spacing: 4.0) {
                Text(item.title)
                    .font(.system(size: 15.0, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)

                if let desc = item.description {
                    Text(desc)
                        .font(.system(size: 13.0))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(2)
                }

                if let address = item.displayAddress {
                    HStack(spacing: 4.0) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10.0))
                        Text(address)
                            .font(.system(size: 12.0))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Color.white.opacity(0.4))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12.0))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(12.0)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10.0))
    }

    private var searchImagePlaceholder: some View {
        ZStack {
            Color.white.opacity(0.05)
            Image(systemName: "leaf.fill")
                .font(.system(size: 24.0))
                .foregroundStyle(Color.white.opacity(0.15))
        }
        .frame(width: 72.0, height: 72.0)
        .clipShape(RoundedRectangle(cornerRadius: 8.0))
    }
}

#endif
