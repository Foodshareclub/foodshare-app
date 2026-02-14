//
//  AppIconPickerView.swift
//  Foodshare
//
//  View for selecting alternate app icons
//

import SwiftUI
import FoodShareDesignSystem

struct AppIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t
    @Environment(AppState.self) private var appState

    @State private var selectedIcon: AppIconOption = AppIconOption.currentIcon
    @State private var isChanging = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {
                    // Current icon preview
                    currentIconPreview

                    // Free icons section
                    iconSection(
                        title: t.t("free_icons"),
                        icons: AppIconOption.freeIcons
                    )

                    // Premium icons section
                    if !AppIconOption.premiumIcons.isEmpty {
                        iconSection(
                            title: t.t("premium_icons"),
                            icons: AppIconOption.premiumIcons,
                            isPremium: true
                        )
                    }
                }
                .padding(Spacing.md)
            }
            .background(Color.DesignSystem.background)
            .navigationTitle(t.t("app_icon"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(t.t("done")) {
                        dismiss()
                    }
                }
            }
            .alert(t.t("error"), isPresented: $showError) {
                Button(t.t("common.ok"), role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Current Icon Preview

    private var currentIconPreview: some View {
        VStack(spacing: Spacing.md) {
            // Large preview
            iconPreview(for: selectedIcon, size: 100)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)

            Text(selectedIcon.displayName)
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Text(selectedIcon.description)
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textSecondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.large)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large)
                        .stroke(Color.DesignSystem.glassBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Icon Section

    private func iconSection(title: String, icons: [AppIconOption], isPremium: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text(title)
                    .font(.DesignSystem.headlineSmall)
                    .foregroundStyle(Color.DesignSystem.text)

                if isPremium {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.DesignSystem.brandPink)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.sm)

            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(icons) { icon in
                    iconCell(for: icon, isPremium: isPremium && !appState.isPremium)
                }
            }
        }
    }

    // MARK: - Icon Cell

    private func iconCell(for icon: AppIconOption, isPremium: Bool) -> some View {
        let isSelected = selectedIcon.id == icon.id
        let isCurrent = AppIconOption.currentIcon.id == icon.id

        return Button {
            if isPremium {
                // Show premium upsell
                errorMessage = t.t("premium_required_icon")
                showError = true
            } else {
                selectIcon(icon)
            }
        } label: {
            VStack(spacing: Spacing.sm) {
                ZStack(alignment: .topTrailing) {
                    iconPreview(for: icon, size: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isSelected ? Color.DesignSystem.brandGreen : Color.clear,
                                    lineWidth: 3
                                )
                        )

                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.DesignSystem.brandGreen)
                            .background(Circle().fill(Color.white))
                            .offset(x: 5, y: -5)
                    }

                    if isPremium {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(Color.DesignSystem.brandPink))
                            .offset(x: 5, y: -5)
                    }
                }

                Text(icon.displayName)
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.text)
                    .lineLimit(1)
            }
            .padding(Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.medium)
                    .fill(isSelected ? Color.DesignSystem.brandGreen.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isChanging)
        .opacity(isPremium ? 0.6 : 1)
    }

    // MARK: - Icon Preview

    private func iconPreview(for icon: AppIconOption, size: CGFloat) -> some View {
        Group {
            if icon.previewColors.count >= 2 {
                LinearGradient(
                    colors: icon.previewColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.DesignSystem.brandGreen
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        .overlay(
            // Food icon overlay
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.4))
                .foregroundStyle(.white.opacity(0.9))
        )
    }

    // MARK: - Actions

    private func selectIcon(_ icon: AppIconOption) {
        selectedIcon = icon

        guard icon.id != AppIconOption.currentIcon.id else { return }

        isChanging = true

        Task {
            do {
                try await AppIconManager.shared.setIcon(icon)
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
                selectedIcon = AppIconOption.currentIcon
                HapticManager.error()
            }

            isChanging = false
        }
    }
}

#Preview {
    AppIconPickerView()
        .environment(AppState.preview)
}
