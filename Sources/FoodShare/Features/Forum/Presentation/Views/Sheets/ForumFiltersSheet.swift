//
//  ForumFiltersSheet.swift
//  FoodShare
//
//  Filter and sort options for forum posts.
//  Extracted from ForumView for better organization and reusability.
//

import SwiftUI
import FoodShareDesignSystem

// MARK: - Forum Filters Sheet

struct ForumFiltersSheet: View {
    @Environment(\.translationService) private var t
    @Binding var filters: ForumFilters
    let categories: [ForumCategory]
    let onApply: () -> Void
    var onSavedPostsTap: (() -> Void)?
    var onNotificationsTap: (() -> Void)?
    var unreadNotificationCount = 0

    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirmation = false
    @State private var sectionAppearStates: [String: Bool] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                mainContent
            }
            .navigationTitle(t.t("forum.filters.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                toolbarLeading
                toolbarTrailing
            }
            .confirmationDialog(t.t("forum.filters.reset_title"), isPresented: $showResetConfirmation) {
                Button(t.t("forum.filters.reset_to_defaults"), role: .destructive) {
                    resetFilters()
                }
                Button(t.t("common.action.cancel"), role: .cancel) {
                    HapticManager.soft()
                }
            } message: {
                Text(t.t("forum.filters.reset_message"))
            }
            .onAppear {
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
                sortBySection
                postTypeSection
                optionsSection
                yourContentSection
            }
            .padding(Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Sort By Section

    private var sortBySection: some View {
        filterSection(
            id: "sortBy",
            icon: "arrow.up.arrow.down",
            title: t.t("forum.filters.sort_by")
        ) {
            VStack(spacing: Spacing.sm) {
                ForEach(ForumSortOption.allCases, id: \.self) { option in
                    sortOptionButton(option)
                }
            }
        }
    }

    private func sortOptionButton(_ option: ForumSortOption) -> some View {
        Button {
            withAnimation(ProMotionAnimation.smooth) {
                filters.sortBy = option
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: option.icon)
                    .font(.system(size: 14))
                    .foregroundColor(filters.sortBy == option
                        ? .DesignSystem.brandGreen
                        : .DesignSystem.textSecondary)
                    .frame(width: 24)
                    .symbolEffect(.pulse, options: .repeating, value: filters.sortBy == option)

                Text(option.displayName)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                if filters.sortBy == option {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.DesignSystem.brandGreen)
                        .symbolEffect(.bounce, value: filters.sortBy)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(filters.sortBy == option
                        ? Color.DesignSystem.brandGreen.opacity(0.1)
                        : Color.clear)
            )
        }
        .buttonStyle(ProMotionButtonStyle())
    }

    // MARK: - Post Type Section

    private var postTypeSection: some View {
        filterSection(
            id: "postType",
            icon: "doc.text",
            title: t.t("forum.filters.post_type")
        ) {
            VStack(spacing: Spacing.sm) {
                postTypeButton(type: nil, displayName: t.t("forum.filters.all_types"), icon: "square.grid.2x2")

                ForEach(ForumPostType.allCases, id: \.self) { type in
                    postTypeButton(type: type, displayName: type.displayName, icon: type.iconName)
                }
            }
        }
    }

    private func postTypeButton(type: ForumPostType?, displayName: String, icon: String) -> some View {
        Button {
            withAnimation(ProMotionAnimation.smooth) {
                filters.postType = type
            }
            HapticManager.selection()
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(filters.postType == type
                        ? .DesignSystem.brandGreen
                        : .DesignSystem.textSecondary)
                    .frame(width: 24)

                Text(displayName)
                    .font(.DesignSystem.bodySmall)
                    .foregroundColor(.DesignSystem.text)

                Spacer()

                if filters.postType == type {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.DesignSystem.brandGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(filters.postType == type
                        ? Color.DesignSystem.brandGreen.opacity(0.1)
                        : Color.clear)
            )
        }
        .buttonStyle(ProMotionButtonStyle())
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        filterSection(
            id: "options",
            icon: "slider.horizontal.3",
            title: t.t("forum.filters.options")
        ) {
            VStack(spacing: Spacing.md) {
                glassToggle(
                    title: t.t("forum.filters.questions_only"),
                    subtitle: t.t("forum.filters.questions_only_subtitle"),
                    icon: "questionmark.circle",
                    isOn: $filters.showQuestionsOnly
                )

                glassToggle(
                    title: t.t("forum.filters.unanswered_only"),
                    subtitle: t.t("forum.filters.unanswered_only_subtitle"),
                    icon: "exclamationmark.bubble",
                    isOn: $filters.showUnansweredOnly
                )
            }
        }
    }

    // MARK: - Your Content Section

    private var yourContentSection: some View {
        filterSection(
            id: "yourContent",
            icon: "person.crop.circle",
            title: t.t("forum.filters.your_content")
        ) {
            VStack(spacing: Spacing.sm) {
                navigationRow(
                    title: t.t("forum.filters.saved_posts"),
                    subtitle: t.t("forum.filters.saved_posts_subtitle"),
                    icon: "bookmark.fill",
                    iconColor: .DesignSystem.accentOrange
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onSavedPostsTap?()
                    }
                }

                navigationRow(
                    title: t.t("forum.filters.notifications"),
                    subtitle: t.t("forum.filters.notifications_subtitle"),
                    icon: "bell.fill",
                    iconColor: .DesignSystem.brandBlue,
                    badge: unreadNotificationCount
                ) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onNotificationsTap?()
                    }
                }
            }
        }
    }

    // MARK: - Navigation Row

    private func navigationRow(
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        badge: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticManager.light()
            action()
        }) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)
                        .foregroundColor(.DesignSystem.text)

                    Text(subtitle)
                        .font(.DesignSystem.captionSmall)
                        .foregroundColor(.DesignSystem.textSecondary)
                }

                Spacer()

                if badge > 0 {
                    Text(badge > 99 ? "99+" : "\(badge)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xxs)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.DesignSystem.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: CornerRadius.medium)
                            .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(ProMotionButtonStyle())
    }

    // MARK: - Glass Toggle

    private func glassToggle(title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .DesignSystem.brandGreen.opacity(0.15),
                                .DesignSystem.brandBlue.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.DesignSystem.bodySmall)
                    .fontWeight(.medium)
                    .foregroundColor(.DesignSystem.text)

                Text(subtitle)
                    .font(.DesignSystem.captionSmall)
                    .foregroundColor(.DesignSystem.textSecondary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.DesignSystem.brandGreen)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    HapticManager.selection()
                }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Toolbar

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
                    Text(t.t("common.action.reset"))
                        .font(.DesignSystem.bodySmall)
                        .fontWeight(.medium)
                }
                .foregroundColor(.DesignSystem.brandGreen)
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.DesignSystem.background,
                    Color.DesignSystem.surface.opacity(0.5)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.DesignSystem.brandGreen.opacity(0.03), Color.clear],
                center: .topLeading,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [Color.DesignSystem.brandBlue.opacity(0.03), Color.clear],
                center: .bottomTrailing,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Helpers

    private func resetFilters() {
        HapticManager.medium()
        withAnimation(ProMotionAnimation.smooth) {
            filters.reset()
        }
        onApply()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            HapticManager.success()
        }
    }

    private func animateSectionsIn() {
        let sections = ["sortBy", "postType", "options", "yourContent"]
        let baseDelay = 0.08

        Task { @MainActor in
            for (index, section) in sections.enumerated() {
                let delayMs = Int(Double(index) * baseDelay * 1000)

                if delayMs > 0 {
                    try? await Task.sleep(for: .milliseconds(delayMs))
                }

                withAnimation(ProMotionAnimation.smooth) {
                    sectionAppearStates[section] = true
                }
            }
        }
    }

    // MARK: - Filter Section

    @ViewBuilder
    private func filterSection(
        id: String,
        icon: String,
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .DesignSystem.brandGreen.opacity(0.2),
                                    .DesignSystem.brandBlue.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandBlue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.bounce, options: .nonRepeating, value: sectionAppearStates[id] ?? false)
                }

                Text(title)
                    .font(.DesignSystem.headlineSmall)
                    .foregroundColor(.DesignSystem.text)
            }

            content()
        }
        .padding(Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        )
        .opacity(sectionAppearStates[id] == true ? 1 : 0)
        .offset(y: sectionAppearStates[id] == true ? 0 : 20)
        .animation(ProMotionAnimation.smooth, value: sectionAppearStates[id])
    }
}
