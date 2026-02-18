//
//  UserListingsView.swift
//  Foodshare
//
//  Refactored with Swift 6 bleeding-edge practices:
//  - Extracted ViewModel for state management
//  - Composable view architecture
//  - Type-safe enums for filters and sorting
//  - Efficient LazyVGrid with proper identity
//


#if !SKIP
import SwiftUI



// MARK: - User Listings ViewModel

@MainActor
@Observable
final class UserListingsViewModel {
    // MARK: - State

    private(set) var listings: [FoodItem] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    var selectedTab: ListingTab = .active
    var searchText = ""
    var sortOption: SortOption = .newest
    var isSelectionMode = false
    var selectedListings: Set<Int> = []

    // MARK: - Computed Properties

    var activeListings: [FoodItem] { listings.filter { $0.isActive && !$0.isArranged } }
    var arrangedListings: [FoodItem] { listings.filter(\.isArranged) }
    var inactiveListings: [FoodItem] { listings.filter { !$0.isActive && !$0.isArranged } }

    var displayedListings: [FoodItem] {
        let filtered = filteredByTab.filter(bySearch: searchText)
        return filtered.sorted(by: sortOption)
    }

    var totalViews: Int { listings.reduce(0) { $0 + $1.postViews } }
    var totalLikes: Int { listings.reduce(0) { $0 + ($1.postLikeCounter ?? 0) } }

    private var filteredByTab: [FoodItem] {
        switch selectedTab {
        case .active: return activeListings
        case .arranged: return arrangedListings
        case .inactive: return inactiveListings
        }
    }

    // MARK: - Dependencies

    private let userId: UUID
    private let repository: ListingRepository

    init(userId: UUID, repository: ListingRepository) {
        self.userId = userId
        self.repository = repository
    }

    // MARK: - Actions

    func loadListings() async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            listings = try await repository.fetchUserListings(userId: userId)
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .networkError(error.localizedDescription)
        }
    }

    func refresh() async {
        do {
            listings = try await repository.fetchUserListings(userId: userId)
            HapticManager.light()
        } catch {
            // Keep existing data on refresh failure
        }
    }

    func deleteListing(_ listing: FoodItem) async {
        do {
            try await repository.deleteListing(listing.id)
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                listings.removeAll { $0.id == listing.id }
            }
            HapticManager.success()
        } catch {
            HapticManager.error()
            self.error = .networkError("Failed to delete listing")
        }
    }

    func deleteSelectedListings() async {
        for listingId in selectedListings {
            if let listing = listings.first(where: { $0.id == listingId }) {
                try? await repository.deleteListing(listing.id)
            }
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            listings.removeAll { selectedListings.contains($0.id) }
            selectedListings.removeAll()
            isSelectionMode = false
        }
        HapticManager.success()
    }

    func toggleSelection(for listing: FoodItem) {
        withAnimation(.spring(response: 0.2)) {
            if selectedListings.contains(listing.id) {
                selectedListings.remove(listing.id)
            } else {
                selectedListings.insert(listing.id)
            }
        }
        HapticManager.selection()
    }

    func selectAll() {
        withAnimation(.spring(response: 0.3)) {
            selectedListings = Set(displayedListings.map(\.id))
        }
        HapticManager.selection()
    }

    func exitSelectionMode() {
        withAnimation(.spring(response: 0.3)) {
            isSelectionMode = false
            selectedListings.removeAll()
        }
        HapticManager.selection()
    }
}

// MARK: - Supporting Types

enum ListingTab: String, CaseIterable {
    case active
    case arranged
    case inactive

    var titleKey: String {
        switch self {
        case .active: "listings.tab.active"
        case .arranged: "listings.tab.arranged"
        case .inactive: "listings.tab.inactive"
        }
    }
}

enum SortOption: String, CaseIterable {
    case newest
    case oldest
    case mostViewed
    case mostLiked

    var titleKey: String {
        switch self {
        case .newest: "listings.sort.newest"
        case .oldest: "listings.sort.oldest"
        case .mostViewed: "listings.sort.most_viewed"
        case .mostLiked: "listings.sort.most_liked"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "arrow.down.circle"
        case .oldest: return "arrow.up.circle"
        case .mostViewed: return "eye.circle"
        case .mostLiked: return "heart.circle"
        }
    }
}

// MARK: - Array Extensions

private extension Array where Element == FoodItem {
    func filter(bySearch query: String) -> [FoodItem] {
        guard !query.isEmpty else { return self }
        let lowercased = query.lowercased()
        return filter { $0.postName.lowercased().contains(lowercased) || ($0.postDescription?.lowercased().contains(lowercased) ?? false) }
    }

    func sorted(by option: SortOption) -> [FoodItem] {
        switch option {
        case .newest: return sorted { $0.createdAt > $1.createdAt }
        case .oldest: return sorted { $0.createdAt < $1.createdAt }
        case .mostViewed: return sorted { $0.postViews > $1.postViews }
        case .mostLiked: return sorted { ($0.postLikeCounter ?? 0) > ($1.postLikeCounter ?? 0) }
        }
    }
}

// MARK: - User Listings View

struct UserListingsView: View {
    
    @Environment(\.translationService) private var t
    let userId: UUID
    let repository: ListingRepository

    @State private var viewModel: UserListingsViewModel
    @State private var showDeleteConfirmation = false
    @State private var listingToDelete: FoodItem?

    init(userId: UUID, repository: ListingRepository) {
        self.userId = userId
        self.repository = repository
        _viewModel = State(initialValue: UserListingsViewModel(userId: userId, repository: repository))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isLoading && !viewModel.listings.isEmpty && viewModel.searchText.isEmpty {
                ListingsStatsHeader(viewModel: viewModel)
            }

            ListingsSearchBar(searchText: $viewModel.searchText)
            ListingsTabSelector(viewModel: viewModel)

            ListingsContent(
                viewModel: viewModel,
                listingToDelete: $listingToDelete,
                showDeleteConfirmation: $showDeleteConfirmation
            )
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("profile.my_listings"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar { listingsToolbar }
        .task { await viewModel.loadListings() }
        .refreshable { await viewModel.refresh() }
        .alert(t.t("listings.delete.title"), isPresented: $showDeleteConfirmation) {
            Button(t.t("common.cancel"), role: .cancel) { listingToDelete = nil }
            Button(t.t("common.delete"), role: .destructive) {
                if let listing = listingToDelete {
                    Task { await viewModel.deleteListing(listing) }
                }
            }
        } message: {
            Text(t.t("listings.delete.confirmation"))
        }
    }

    @ToolbarContentBuilder
    private var listingsToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Section(t.t("listings.sort_by")) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3)) { viewModel.sortOption = option }
                            HapticManager.selection()
                        } label: {
                            Label(t.t(option.titleKey), systemImage: viewModel.sortOption == option ? "checkmark" : option.icon)
                        }
                    }
                }

                Section {
                    Button {
                        if viewModel.isSelectionMode {
                            viewModel.exitSelectionMode()
                        } else {
                            withAnimation(.spring(response: 0.3)) { viewModel.isSelectionMode = true }
                            HapticManager.selection()
                        }
                    } label: {
                        Label(
                            viewModel.isSelectionMode ? t.t("listings.cancel_selection") : t.t("listings.select_multiple"),
                            systemImage: viewModel.isSelectionMode ? "xmark.circle" : "checkmark.circle"
                        )
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.DesignSystem.text)
            }
        }
    }
}

// MARK: - Stats Header

private struct ListingsStatsHeader: View {
    @Environment(\.translationService) private var t
    let viewModel: UserListingsViewModel

    var body: some View {
        HStack(spacing: Spacing.lg) {
            StatPill(icon: "list.bullet.rectangle", value: "\(viewModel.listings.count)", label: t.t("listings.stats.total"), color: .DesignSystem.brandGreen)
            StatPill(icon: "eye.fill", value: "\(viewModel.totalViews)", label: t.t("listings.stats.views"), color: .DesignSystem.brandBlue)
            StatPill(icon: "heart.fill", value: "\(viewModel.totalLikes)", label: t.t("listings.stats.likes"), color: .DesignSystem.brandPink)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.DesignSystem.labelMedium)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.DesignSystem.text)
                    #if !SKIP
                    .contentTransition(.numericText())
                    #endif

                Text(label)
                    .font(.DesignSystem.captionSmall)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            Capsule()
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
        )
    }
}

// MARK: - Search Bar

private struct ListingsSearchBar: View {
    @Environment(\.translationService) private var t
    @Binding var searchText: String

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .font(.system(size: 16))

            TextField(t.t("listings.search.placeholder"), text: $searchText)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.text)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    HapticManager.light()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                        .font(.system(size: 16))
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(Color.DesignSystem.glassBorder, lineWidth: 1))
        )
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Tab Selector

private struct ListingsTabSelector: View {
    @Environment(\.translationService) private var t
    @Bindable var viewModel: UserListingsViewModel

    var body: some View {
        HStack(spacing: 0) {
            tabButton(tab: .active, count: viewModel.activeListings.count)
            tabButton(tab: .arranged, count: viewModel.arrangedListings.count)
            tabButton(tab: .inactive, count: viewModel.inactiveListings.count)
        }
        .padding(Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(Color.DesignSystem.glassBorder, lineWidth: 1))
        )
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private func tabButton(tab: ListingTab, count: Int) -> some View {
        let isSelected = viewModel.selectedTab == tab

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.selectedTab = tab }
            HapticManager.selection()
        } label: {
            HStack(spacing: Spacing.xs) {
                Text(t.t(tab.titleKey))
                    .font(.DesignSystem.bodyMedium)
                    .fontWeight(isSelected ? .semibold : .regular)

                Text("\(count)")
                    .font(.DesignSystem.captionSmall)
                    .fontWeight(.bold)
                    .foregroundStyle(isSelected ? .white : Color.DesignSystem.textSecondary)
                    .padding(.horizontal, Spacing.xs)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(isSelected ? Color.DesignSystem.brandGreen : Color.DesignSystem.glassBackground))
            }
            .foregroundStyle(isSelected ? Color.DesignSystem.text : Color.DesignSystem.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(RoundedRectangle(cornerRadius: CornerRadius.medium).fill(isSelected ? Color.DesignSystem.glassHighlight : Color.clear))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(t.t("listings.tab.accessibility", args: ["tab": t.t(tab.titleKey), "count": "\(count)"]))
    }
}

// MARK: - Listings Content

private struct ListingsContent: View {
    @Bindable var viewModel: UserListingsViewModel
    @Binding var listingToDelete: FoodItem?
    @Binding var showDeleteConfirmation: Bool

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.listings.isEmpty {
                ListingsLoadingView()
            } else if let error = viewModel.error, viewModel.listings.isEmpty {
                ListingsErrorView(error: error) {
                    Task { await viewModel.loadListings() }
                }
            } else if viewModel.displayedListings.isEmpty {
                ListingsEmptyView(tab: viewModel.selectedTab)
            } else {
                ListingsGridView(
                    viewModel: viewModel,
                    listingToDelete: $listingToDelete,
                    showDeleteConfirmation: $showDeleteConfirmation
                )
            }
        }
    }
}

// MARK: - Listings Grid View

private struct ListingsGridView: View {
    @Bindable var viewModel: UserListingsViewModel
    @Binding var listingToDelete: FoodItem?
    @Binding var showDeleteConfirmation: Bool

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            if viewModel.isSelectionMode && !viewModel.selectedListings.isEmpty {
                SelectionToolbar(viewModel: viewModel)
            }

            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(viewModel.displayedListings) { listing in
                    listingCard(for: listing)
                }
            }
            .padding()
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.displayedListings.count)
        }
    }

    @ViewBuilder
    private func listingCard(for listing: FoodItem) -> some View {
        if viewModel.isSelectionMode {
            SelectableListingCard(
                listing: listing,
                isSelected: viewModel.selectedListings.contains(listing.id),
                onToggle: { viewModel.toggleSelection(for: listing) }
            )
        } else {
            NavigationLink {
                FoodItemDetailView(item: listing)
            } label: {
                UserListingCard(listing: listing) {
                    listingToDelete = listing
                    showDeleteConfirmation = true
                }
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Selection Toolbar

private struct SelectionToolbar: View {
    @Environment(\.translationService) private var t
    @Bindable var viewModel: UserListingsViewModel

    var body: some View {
        HStack(spacing: Spacing.md) {
            Text(t.t("listings.selection.count", args: ["count": "\(viewModel.selectedListings.count)"]))
                .font(.DesignSystem.bodyMedium)
                .fontWeight(.semibold)
                .foregroundStyle(Color.DesignSystem.text)

            Spacer()

            Button {
                viewModel.selectAll()
            } label: {
                Text(t.t("listings.select_all"))
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.brandGreen)
            }

            Button {
                Task { await viewModel.deleteSelectedListings() }
            } label: {
                Label(t.t("common.delete"), systemImage: "trash")
                    .font(.DesignSystem.labelMedium)
                    .foregroundStyle(Color.DesignSystem.error)
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(Color.DesignSystem.glassBorder, lineWidth: 1))
        )
        .padding(.horizontal, Spacing.md)
    }
}

// MARK: - Selectable Listing Card

struct SelectableListingCard: View {
    @Environment(\.translationService) private var t
    let listing: FoodItem
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .topLeading) {
                UserListingCard(listing: listing, onDelete: nil)
                    .opacity(isSelected ? 0.8 : 1.0)

                Circle()
                    .fill(isSelected ? Color.DesignSystem.brandGreen : Color.white.opacity(0.8))
                    .frame(width: 24.0, height: 24)
                    .overlay(Circle().stroke(isSelected ? Color.DesignSystem.brandGreen : Color.DesignSystem.glassBorder, lineWidth: 2))
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(Spacing.sm)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 0.98 : 1.0)
        .animation(.spring(response: 0.2), value: isSelected)
        .accessibilityLabel(t.t("listings.card.accessibility", args: ["name": listing.postName, "status": isSelected ? t.t("common.selected") : t.t("common.not_selected")]))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - User Listing Card

struct UserListingCard: View {
    let listing: FoodItem
    let onDelete: (() -> Void)?

    init(listing: FoodItem, onDelete: (() -> Void)? = nil) {
        self.listing = listing
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ListingImageView(imageUrl: listing.images?.first)
                LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .center, endPoint: .bottom)

                VStack {
                    HStack {
                        Spacer()
                        ListingStatusBadge(listing: listing)
                            .padding(Spacing.xs)
                    }
                    Spacer()
                }
            }
            .frame(height: 130.0)
            .clipShape(.rect(topLeadingRadius: CornerRadius.large, topTrailingRadius: CornerRadius.large))

            ListingDetailsView(listing: listing, onDelete: onDelete)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(Color.DesignSystem.glassBorder, lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Listing Image View

private struct ListingImageView: View {
    let imageUrl: String?

    var body: some View {
        Group {
            if let imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ShimmerPlaceholder()
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        ImagePlaceholder()
                    @unknown default:
                        ImagePlaceholder()
                    }
                }
            } else {
                ImagePlaceholder()
            }
        }
    }
}

// MARK: - Listing Status Badge

private struct ListingStatusBadge: View {
    @Environment(\.translationService) private var t
    let listing: FoodItem

    private var statusInfo: (key: String, color: Color) {
        if listing.isArranged {
            return ("listings.status.arranged", .orange)
        } else if listing.isActive {
            return ("listings.status.active", .DesignSystem.success)
        } else {
            return ("listings.status.inactive", .gray)
        }
    }

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            Circle().fill(statusInfo.color).frame(width: 6.0, height: 6)
            Text(t.t(statusInfo.key))
                .font(.DesignSystem.captionSmall)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(Capsule().fill(statusInfo.color.opacity(0.9)).background(Capsule().fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)))
    }
}

// MARK: - Listing Details View

private struct ListingDetailsView: View {
    @Environment(\.translationService) private var t
    let listing: FoodItem
    let onDelete: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(listing.postName)
                .font(.DesignSystem.bodyMedium)
                .fontWeight(.semibold)
                .foregroundStyle(Color.DesignSystem.text)
                .lineLimit(1)

            HStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "eye.fill").font(.system(size: 10))
                    Text("\(listing.postViews)").font(.DesignSystem.captionSmall)
                }
                .foregroundStyle(Color.DesignSystem.textSecondary)

                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "heart.fill").font(.system(size: 10))
                    Text("\(listing.postLikeCounter)").font(.DesignSystem.captionSmall)
                }
                .foregroundStyle(Color.DesignSystem.error.opacity(0.8))

                Spacer()

                if onDelete != nil {
                    Menu {
                        Button(role: .destructive) { onDelete?() } label: {
                            Label(t.t("common.delete"), systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                            .frame(width: 24.0, height: 24)
                    }
                }
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Loading View

private struct ListingsLoadingView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonListingCard()
                }
            }
            .padding()
        }
    }
}

// MARK: - Error View

private struct ListingsErrorView: View {
    @Environment(\.translationService) private var t
    let error: AppError
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.DesignSystem.warning, .DesignSystem.error], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            Text(t.t("common.error.something_went_wrong"))
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Text(error.localizedDescription)
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)

            GlassButton(t.t("common.try_again"), icon: "arrow.clockwise", style: .primary, action: onRetry)
                .frame(width: 160.0)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Empty View

private struct ListingsEmptyView: View {
    @Environment(\.translationService) private var t
    let tab: ListingTab

    private var titleKey: String {
        switch tab {
        case .active: "listings.empty.active.title"
        case .arranged: "listings.empty.arranged.title"
        case .inactive: "listings.empty.inactive.title"
        }
    }

    private var subtitleKey: String {
        switch tab {
        case .active: "listings.empty.active.subtitle"
        case .arranged: "listings.empty.arranged.subtitle"
        case .inactive: "listings.empty.inactive.subtitle"
        }
    }

    var body: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()

            ZStack {
                Circle()
                    #if !SKIP
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                    #else
                    .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                    #endif
                    .frame(width: 120.0, height: 120)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(colors: [.DesignSystem.brandGreen.opacity(0.5), .DesignSystem.brandBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 2
                        )
                    )

                Image(systemName: tab == .active ? "tray" : "checkmark.circle")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(
                        LinearGradient(colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }

            Text(t.t(titleKey))
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Text(t.t(subtitleKey))
                .font(.DesignSystem.bodyMedium)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Skeleton Listing Card

struct SkeletonListingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ShimmerPlaceholder()
                .frame(height: 130.0)
                .clipShape(.rect(topLeadingRadius: CornerRadius.large, topTrailingRadius: CornerRadius.large))

            VStack(alignment: .leading, spacing: Spacing.xs) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.DesignSystem.glassBackground)
                    .frame(height: 16.0)
                    .frame(maxWidth: .infinity)

                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(width: 40.0, height: 12)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.DesignSystem.glassBackground)
                        .frame(width: 40.0, height: 12)

                    Spacer()
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                #if !SKIP
                .fill(Color.DesignSystem.glassSurface.opacity(0.15) /* ultraThinMaterial fallback */)
                #else
                .fill(Color.DesignSystem.glassSurface.opacity(0.15))
                #endif
                .overlay(RoundedRectangle(cornerRadius: CornerRadius.large).stroke(Color.DesignSystem.glassBorder, lineWidth: 1))
        )
    }
}

// MARK: - Shimmer Placeholder

struct ShimmerPlaceholder: View {
    @State private var isAnimating = false

    var body: some View {
        Rectangle()
            .fill(Color.DesignSystem.glassBackground)
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.2), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.5)
                    .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.5)
                }
            )
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Image Placeholder

struct ImagePlaceholder: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(colors: [.DesignSystem.brandGreen.opacity(0.3), .DesignSystem.brandBlue.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .overlay {
                Image(systemName: "photo")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }
    }
}

#endif
