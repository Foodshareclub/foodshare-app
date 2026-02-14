//
//  FilterSheet.swift
//  Foodshare
//
//  Filter and settings sheet for customizing feed display
//  Extracted from FeedView for better organization
//

import FoodShareDesignSystem
import OSLog
import SwiftUI

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @Environment(FeedViewModel.self) private var viewModel
    @State private var radiusLocalized = 5.0 // In user's locale unit (km or mi)
    @State private var showResetConfirmation = false
    @State private var sectionAppearStates: [String: Bool] = [:]
    @AccessibilityFocusState private var isResetFocused: Bool

    /// Current distance unit based on locale
    private var distanceUnit: DistanceUnit {
        .current
    }

    /// Logger for production debugging
    private let logger = Logger(subsystem: Constants.bundleIdentifier, category: "FilterSheet")

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                mainContent
            }
            .navigationTitle(t.t("search.filters_settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                toolbarLeading
                toolbarTrailing
            }
            .confirmationDialog(t.t("filter.reset_confirmation_title"), isPresented: $showResetConfirmation) {
                Button(t.t("filter.reset_to_defaults"), role: .destructive) {
                    resetFilters()
                }
                Button(t.t("common.cancel"), role: .cancel) {
                    HapticManager.soft()
                }
            } message: {
                Text(t.t("filter.reset_confirmation_message"))
            }
            .onAppear {
                let initialRadius = distanceUnit.convert(fromKilometers: viewModel.searchRadius)
                radiusLocalized = max(distanceUnit.minSliderValue, min(initialRadius, distanceUnit.maxSliderValue))
                logger
                    .info(
                        "FilterSheet appeared - radius: \(viewModel.searchRadius)km (\(radiusLocalized) \(distanceUnit.symbol))",
                    )
                animateSectionsIn()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(CornerRadius.xl)
        .presentationBackgroundInteraction(.enabled(upThrough: .large))
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                viewModeSection
                sortBySection
                radiusSection
                statsSection
            }
            .padding(Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Section Views

    private var viewModeSection: some View {
        filterSection(
            id: "viewMode",
            icon: "rectangle.grid.1x2",
            title: t.t("filter.view_mode"),
        ) {
            HStack(spacing: Spacing.sm) {
                ForEach(FeedViewMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation(ProMotionAnimation.smooth) {
                            viewModel.setViewMode(mode)
                        }
                        HapticManager.selection()
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .medium))
                                .symbolEffect(.bounce, value: viewModel.viewMode == mode)
                            Text(mode == .list ? t.t("filter.view_list") : t.t("filter.view_grid"))
                                .font(.DesignSystem.bodySmall)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(viewModel.viewMode == mode ? .white : .DesignSystem.text)
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(
                                    viewModel.viewMode == mode
                                        ? Color.DesignSystem.brandGreen
                                        : Color.clear,
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                                        .fill(.ultraThinMaterial),
                                ),
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .stroke(
                                    viewModel.viewMode == mode
                                        ? Color.DesignSystem.brandGreen.opacity(0.5)
                                        : Color.DesignSystem.glassBorder,
                                    lineWidth: 1,
                                ),
                        )
                        .shadow(
                            color: viewModel.viewMode == mode
                                ? Color.DesignSystem.brandGreen.opacity(0.3)
                                : .clear,
                            radius: 8,
                            y: 2,
                        )
                    }
                    .buttonStyle(ProMotionButtonStyle())
                    .accessibilityLabel(mode == .list
                        ? t.t("accessibility.list_view_mode")
                        : t.t("accessibility.grid_view_mode"))
                        .accessibilityAddTraits(viewModel.viewMode == mode ? [.isSelected] : [])
                }
            }
        }
    }

    private var sortBySection: some View {
        filterSection(
            id: "sortBy",
            icon: "arrow.up.arrow.down",
            title: t.t("filter.sort_by"),
        ) {
            VStack(spacing: Spacing.sm) {
                ForEach(FeedSortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(ProMotionAnimation.smooth) {
                            viewModel.setSortOption(option)
                        }
                        HapticManager.selection()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Image(systemName: option.icon)
                                .font(.system(size: 14))
                                .foregroundColor(
                                    viewModel.sortOption == option
                                        ? .DesignSystem.brandGreen
                                        : .DesignSystem.textSecondary,
                                )
                                .frame(width: 24)
                                .symbolEffect(
                                    .pulse, options: .repeating, value: viewModel.sortOption == option,
                                )

                            Text(option.rawValue)
                                .font(.DesignSystem.bodySmall)
                                .foregroundColor(.DesignSystem.text)

                            Spacer()

                            if viewModel.sortOption == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.DesignSystem.brandGreen)
                                    .symbolEffect(.bounce, value: viewModel.sortOption)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: CornerRadius.medium)
                                .fill(
                                    viewModel.sortOption == option
                                        ? Color.DesignSystem.brandGreen.opacity(0.1)
                                        : Color.clear,
                                ),
                        )
                    }
                    .buttonStyle(ProMotionButtonStyle())
                    .accessibilityLabel("Sort by \(option.rawValue)")
                    .accessibilityAddTraits(viewModel.sortOption == option ? [.isSelected] : [])
                }
            }
        }
    }

    private var radiusSection: some View {
        filterSection(
            id: "radius",
            icon: "location.circle.fill",
            title: t.t("filter.search_radius"),
        ) {
            GlassSearchRadiusSection(
                radiusLocalized: $radiusLocalized,
                distanceUnit: distanceUnit,
                style: .full,
                onRadiusChange: { radiusKm in
                    await viewModel.updateSearchRadius(radiusKm)
                },
            )
        }
    }

    private var statsSection: some View {
        filterSection(
            id: "stats",
            icon: "chart.bar.fill",
            title: t.t("filter.feed_statistics"),
        ) {
            HStack(spacing: Spacing.lg) {
                // Total
                VStack(spacing: Spacing.xs) {
                    Text("\(viewModel.feedStats.totalItems)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .contentTransition(.numericText())
                    Text(t.t("stats.total"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Total items: \(viewModel.feedStats.totalItems)")

                // Divider
                Rectangle()
                    .fill(Color.DesignSystem.glassBorder)
                    .frame(width: 1, height: 40)

                // Available
                VStack(spacing: Spacing.xs) {
                    Text("\(viewModel.feedStats.availableItems)")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                startPoint: .leading,
                                endPoint: .trailing,
                            ),
                        )
                        .contentTransition(.numericText())
                    Text(t.t("stats.available"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Available items: \(viewModel.feedStats.availableItems)")

                // Divider
                Rectangle()
                    .fill(Color.DesignSystem.glassBorder)
                    .frame(width: 1, height: 40)

                // Last Updated with animated clock icon
                VStack(spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.DesignSystem.textSecondary)
                            .symbolEffect(.pulse, options: .repeating)
                        Text(viewModel.feedStats.formattedLastUpdated)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.DesignSystem.text)
                    }
                    Text(t.t("stats.updated"))
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Last updated: \(viewModel.feedStats.formattedLastUpdated)")
            }
        }
    }

    // MARK: - Toolbar Items

    private var toolbarLeading: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                HapticManager.soft()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel("Close filters")
        }
    }

    private var toolbarTrailing: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showResetConfirmation = true
            } label: {
                HStack(spacing: Spacing.xxs) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .medium))
                        .symbolEffect(.rotate, value: showResetConfirmation)
                    Text(t.t("common.reset"))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)
                }
                .foregroundColor(.DesignSystem.brandGreen)
            }
            .accessibilityLabel("Reset all filters to defaults")
            .accessibilityFocused($isResetFocused)
        }
    }

    // MARK: - Background

    /// Modern gradient background with subtle depth
    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.DesignSystem.background,
                    Color.DesignSystem.surface.opacity(0.9),
                    Color.DesignSystem.background.opacity(0.95),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.DesignSystem.surface.opacity(0.3),
                    Color.clear,
                ],
                center: .topTrailing,
                startRadius: 50,
                endRadius: 400,
            )
            .ignoresSafeArea()
            .blendMode(.softLight)
        }
    }

    // MARK: - Helper Methods

    /// Reset all filters to default values with animation and haptics
    private func resetFilters() {
        logger.info("Resetting filters to defaults")
        HapticManager.medium()

        let configDefaultRadius = AppConfiguration.shared.defaultSearchRadiusKm
        let defaultRadius = distanceUnit.convert(fromKilometers: configDefaultRadius)
        let clampedRadius = max(
            distanceUnit.minSliderValue, min(defaultRadius, distanceUnit.maxSliderValue),
        )

        withAnimation(ProMotionAnimation.smooth) {
            radiusLocalized = clampedRadius
            viewModel.setViewMode(.list)
            viewModel.setSortOption(.nearest)
        }

        Task {
            await viewModel.updateSearchRadius(configDefaultRadius)
            logger.info("Filters reset successfully")

            // Success haptic after reset completes
            try? await Task.sleep(for: .milliseconds(300))
            HapticManager.success()
        }
    }

    /// Animate sections in with staggered delays for delightful entrance
    private func animateSectionsIn() {
        let sections = ["viewMode", "sortBy", "radius", "stats"]
        let baseDelay = 0.08

        Task {
            for (index, section) in sections.enumerated() {
                let delayMs = Int(Double(index) * baseDelay * 1000)

                if delayMs > 0 {
                    try? await Task.sleep(for: .milliseconds(delayMs))
                }

                withAnimation(ProMotionAnimation.smooth) {
                    sectionAppearStates[section] = true
                }
            }
            logger.debug("Section animations completed")
        }
    }

    // MARK: - Filter Section Helper

    private func filterSection(
        id: String,
        icon: String,
        title: String,
        @ViewBuilder content: () -> some View,
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Section header with animated icon
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .DesignSystem.brandGreen.opacity(0.2),
                                    .DesignSystem.brandBlue.opacity(0.2),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ),
                        )
                        .symbolEffect(
                            .bounce, options: .nonRepeating, value: sectionAppearStates[id] ?? false,
                        )
                }

                Text(title)
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)
            }
            .accessibilityAddTraits(.isHeader)

            content()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1),
                )
                .shadow(
                    color: .black.opacity(0.05),
                    radius: 8,
                    y: 2,
                ),
        )
        .opacity(sectionAppearStates[id] == true ? 1 : 0)
        .offset(y: sectionAppearStates[id] == true ? 0 : 20)
        .animation(ProMotionAnimation.smooth, value: sectionAppearStates[id])
    }
}
