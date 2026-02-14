//
//  DataExportView.swift
//  Foodshare
//
//  View for GDPR data export (Right to Data Portability)
//  Uses existing GDPRExportService
//

import SwiftUI
import FoodShareDesignSystem

struct DataExportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t

    // Export options
    @State private var includeProfile = true
    @State private var includeListings = true
    @State private var includeMessages = true
    @State private var includeActivity = true
    @State private var includePreferences = true
    @State private var includeLocalCache = false

    // State
    @State private var isExporting = false
    @State private var progress: GDPRExportProgress?
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header
                headerSection

                // Data categories
                dataCategoriesSection

                // Export button
                exportButtonSection

                // Info section
                infoSection
            }
            .padding(Spacing.md)
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("export_data"))
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .alert(t.t("export_failed"), isPresented: $showError) {
            Button(t.t("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.DesignSystem.accentPurple, .DesignSystem.brandPink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text(t.t("your_data"))
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Text(t.t("gdpr_export_description"))
                .font(.DesignSystem.bodySmall)
                .foregroundStyle(Color.DesignSystem.textSecondary)
                .multilineTextAlignment(.center)
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

    // MARK: - Data Categories Section

    private var dataCategoriesSection: some View {
        GlassSettingsSection(title: t.t("select_data"), icon: "checklist") {
            // Profile
            GlassSettingsToggle(
                icon: "person.fill",
                iconColor: .DesignSystem.brandBlue,
                title: t.t("profile_data"),
                isOn: $includeProfile
            )
            .sensoryFeedback(.selection, trigger: includeProfile)

            // Listings
            GlassSettingsToggle(
                icon: "square.grid.2x2.fill",
                iconColor: .DesignSystem.brandGreen,
                title: t.t("listings_data"),
                isOn: $includeListings
            )
            .sensoryFeedback(.selection, trigger: includeListings)

            // Messages
            GlassSettingsToggle(
                icon: "message.fill",
                iconColor: .DesignSystem.brandTeal,
                title: t.t("messages_data"),
                isOn: $includeMessages
            )
            .sensoryFeedback(.selection, trigger: includeMessages)

            // Activity
            GlassSettingsToggle(
                icon: "clock.fill",
                iconColor: .DesignSystem.accentOrange,
                title: t.t("activity_history"),
                isOn: $includeActivity
            )
            .sensoryFeedback(.selection, trigger: includeActivity)

            // Preferences
            GlassSettingsToggle(
                icon: "slider.horizontal.3",
                iconColor: .DesignSystem.accentPurple,
                title: t.t("preferences_data"),
                isOn: $includePreferences
            )
            .sensoryFeedback(.selection, trigger: includePreferences)

            // Local cache
            GlassSettingsToggle(
                icon: "internaldrive.fill",
                iconColor: .DesignSystem.textSecondary,
                title: t.t("local_cache_data"),
                isOn: $includeLocalCache
            )
            .sensoryFeedback(.selection, trigger: includeLocalCache)
        }
    }

    // MARK: - Export Button Section

    private var exportButtonSection: some View {
        VStack(spacing: Spacing.md) {
            // Progress indicator
            if isExporting, let progress = progress {
                VStack(spacing: Spacing.sm) {
                    ProgressView(value: progress.percentComplete, total: 100)
                        .tint(.DesignSystem.brandGreen)

                    Text(progress.currentStep)
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(Color.DesignSystem.brandGreen.opacity(0.1))
                )
            }

            // Export button
            Button {
                startExport()
            } label: {
                HStack(spacing: Spacing.sm) {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Text(isExporting ? t.t("exporting") : t.t("export_my_data"))
                }
                .font(.DesignSystem.bodyMedium.bold())
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: CornerRadius.medium)
                        .fill(
                            LinearGradient(
                                colors: [.DesignSystem.brandGreen, .DesignSystem.brandTeal],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .disabled(isExporting || !hasAnySelection)
            .opacity(hasAnySelection ? 1 : 0.5)
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                Text(t.t("gdpr_info_title"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Text(t.t("gdpr_info_description"))
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.accentPurple.opacity(0.1))
        )
    }

    // MARK: - Computed Properties

    private var hasAnySelection: Bool {
        includeProfile || includeListings || includeMessages ||
        includeActivity || includePreferences || includeLocalCache
    }

    // MARK: - Actions

    private func startExport() {
        isExporting = true
        progress = nil

        Task {
            // Start listening to progress
            let progressTask = Task {
                for await update in await GDPRExportService.shared.progressStream() {
                    await MainActor.run {
                        self.progress = update
                    }
                }
            }

            do {
                let config = GDPRExportConfiguration(
                    includeProfile: includeProfile,
                    includeListings: includeListings,
                    includeMessages: includeMessages,
                    includeActivity: includeActivity,
                    includePreferences: includePreferences,
                    includeLocalCache: includeLocalCache
                )

                let url = try await GDPRExportService.shared.exportUserData(configuration: config)

                progressTask.cancel()

                await MainActor.run {
                    exportedFileURL = url
                    isExporting = false
                    showShareSheet = true
                    HapticManager.success()
                }
            } catch {
                progressTask.cancel()

                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isExporting = false
                    showError = true
                    HapticManager.error()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DataExportView()
    }
}
