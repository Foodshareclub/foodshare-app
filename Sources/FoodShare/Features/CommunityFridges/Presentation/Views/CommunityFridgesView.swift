//
//  CommunityFridgesView.swift
//  Foodshare
//
//  Main view for browsing community fridges
//

#if !SKIP
import MapKit
#endif
import SwiftUI
import FoodShareDesignSystem



struct CommunityFridgesView: View {
    
    @Environment(\.translationService) private var t
    @State private var viewModel: CommunityFridgesViewModel
    @State private var showMap = false

    init(viewModel: CommunityFridgesViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.backgroundGradient
                    .ignoresSafeArea()

                if viewModel.isLoading, viewModel.fridges.isEmpty {
                    loadingView
                } else if viewModel.fridges.isEmpty {
                    emptyState
                } else {
                    fridgesList
                }
            }
            .navigationTitle(t.t("navigation.community_fridges"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showMap.toggle()
                    } label: {
                        Image(systemName: showMap ? "list.bullet" : "map")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Toggle(t.t("fridges.filter.active_only"), isOn: $viewModel.showActiveOnly)
                        Toggle(t.t("fridges.filter.with_food_only"), isOn: $viewModel.showWithFoodOnly)
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
            .task {
                await viewModel.loadFridges()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(item: $viewModel.selectedFridge) { fridge in
                CommunityFridgeDetailView(fridge: fridge)
            }
            .alert(t.t("common.error.title"), isPresented: $viewModel.showError) {
                Button(t.t("common.ok")) { viewModel.dismissError() }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.5)
            Text(t.t("fridges.finding_nearby"))
                .font(.LiquidGlass.bodyMedium)
                .foregroundColor(.DesignSystem.textSecondary)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            t.t("fridges.no_nearby"),
            systemImage: "refrigerator",
            description: Text(t.t("fridges.no_fridges_within", args: ["distance": viewModel.searchRadius.formatAsDistance()])),
        )
    }

    private var fridgesList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                // Stats header
                statsHeader

                // Fridge cards
                ForEach(viewModel.filteredFridges) { fridge in
                    CommunityFridgeCard(fridge: fridge)
                        .onTapGesture {
                            viewModel.selectFridge(fridge)
                        }
                }
            }
            .padding(Spacing.md)
        }
    }

    private var statsHeader: some View {
        HStack(spacing: Spacing.md) {
            StatBadge(
                value: "\(viewModel.activeFridgesCount)",
                label: t.t("fridges.stat.active"),
                icon: "checkmark.circle.fill",
                color: .green,
            )

            StatBadge(
                value: "\(viewModel.fridgesWithFood)",
                label: t.t("fridges.stat.with_food"),
                icon: "leaf.fill",
                color: .DesignSystem.primary,
            )

            StatBadge(
                value: viewModel.searchRadius.formatAsDistance(),
                label: t.t("fridges.stat.radius"),
                icon: "location.circle.fill",
                color: .blue,
            )
        }
        .padding(.bottom, Spacing.sm)
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(value)
                    .font(.LiquidGlass.headlineMedium)
            }
            Text(label)
                .font(.LiquidGlass.caption)
                .foregroundColor(.DesignSystem.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.sm)
        .glassBackground()
    }
}

// MARK: - Community Fridge Card

struct CommunityFridgeCard: View {
    let fridge: CommunityFridge
    @State private var showMapPreview = false
    @Environment(\.translationService) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(fridge.name)
                        .font(.LiquidGlass.headlineMedium)
                        .foregroundColor(.DesignSystem.text)

                    if let city = fridge.city {
                        Text(city)
                            .font(.LiquidGlass.bodySmall)
                            .foregroundColor(.DesignSystem.textSecondary)
                    }
                }

                Spacer()

                // Status badge
                FridgeStatusBadge(status: fridge.status)
            }

            // Inline map preview (collapsible)
            if showMapPreview, let coordinate = fridge.coordinate {
                Map(initialPosition: .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                ))) {
                    Marker(fridge.name, coordinate: coordinate)
                        .tint(Color.DesignSystem.primary)
                }
                .frame(height: 100)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
                .allowsHitTesting(false)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Condition indicator with multiple badges
            HStack(spacing: Spacing.sm) {
                // Food status badge
                if let foodStatus = fridge.latestFoodStatus {
                    ConditionBadge(
                        icon: foodStatusIcon(foodStatus),
                        text: foodStatus.capitalized,
                        color: foodStatusColor(foodStatus)
                    )
                }

                // Cleanliness badge
                if let cleanStatus = fridge.latestCleanlinessStatus {
                    ConditionBadge(
                        icon: cleanlinessIcon(cleanStatus),
                        text: cleanStatus.capitalized,
                        color: cleanlinessColor(cleanStatus)
                    )
                }
            }

            // Info row
            HStack(spacing: Spacing.md) {
                if let distance = fridge.distanceDisplay {
                    Label(distance, systemImage: "location.fill")
                        .font(.LiquidGlass.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                if let hours = fridge.availableHours {
                    Label(hours, systemImage: "clock.fill")
                        .font(.LiquidGlass.caption)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                if fridge.hasPantry {
                    Label(t.t("fridges.pantry"), systemImage: "cabinet.fill")
                        .font(.LiquidGlass.caption)
                        .foregroundColor(.DesignSystem.primary)
                }
            }

            // Footer row with check-ins and map toggle
            HStack {
                Label(t.t("fridges.check_ins_count", args: ["count": String(fridge.totalCheckIns)]), systemImage: "person.2.fill")
                    .font(.LiquidGlass.caption)
                    .foregroundColor(.DesignSystem.textSecondary)

                Spacer()

                // Map preview toggle
                if fridge.coordinate != nil {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showMapPreview.toggle()
                        }
                    } label: {
                        Image(systemName: showMapPreview ? "map.fill" : "map")
                            .font(.caption)
                            .foregroundColor(.DesignSystem.primary)
                    }
                    .buttonStyle(.plain)
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.DesignSystem.textSecondary)
            }
        }
        .padding(Spacing.md)
        .glassBackground()
    }

    private func foodStatusIcon(_ status: String) -> String {
        switch status.lowercased() {
        case "nearly empty": "exclamationmark.triangle.fill"
        case "room for more": "arrow.up.circle.fill"
        case "plenty of food": "checkmark.circle.fill"
        case "overflowing": "star.fill"
        default: "questionmark.circle.fill"
        }
    }

    private func foodStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "nearly empty": .red
        case "room for more": .orange
        case "plenty of food": .green
        case "overflowing": .blue
        default: .gray
        }
    }

    private func cleanlinessIcon(_ status: String) -> String {
        switch status.lowercased() {
        case "clean": "sparkles"
        case "needs cleaning": "exclamationmark.circle.fill"
        case "dirty": "xmark.circle.fill"
        default: "questionmark.circle.fill"
        }
    }

    private func cleanlinessColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "clean": .green
        case "needs cleaning": .orange
        case "dirty": .red
        default: .gray
        }
    }
}

// MARK: - Condition Badge

struct ConditionBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.LiquidGlass.caption)
        }
        .foregroundColor(color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Fridge Status Badge

struct FridgeStatusBadge: View {
    let status: FridgeStatus

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
            Text(status.displayName)
        }
        .font(.LiquidGlass.caption)
        .foregroundColor(statusColor)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .active: .green
        case .inactive: .red
        case .pending: .orange
        }
    }
}
