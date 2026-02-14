//
//  SettingsBackupView.swift
//  Foodshare
//
//  View for backing up and restoring app settings
//

import SwiftUI
import FoodShareDesignSystem
import UniformTypeIdentifiers

struct SettingsBackupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t

    @State private var isCreatingBackup = false
    @State private var isRestoringBackup = false
    @State private var backups: [URL] = []
    @State private var selectedBackup: URL?
    @State private var showRestoreConfirmation = false
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var showDocumentPicker = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header
                headerSection

                // Actions section
                actionsSection

                // Recent backups section
                if !backups.isEmpty {
                    recentBackupsSection
                }

                // Info section
                infoSection
            }
            .padding(Spacing.md)
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("backup_restore"))
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadBackups()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(types: [.json]) { url in
                restoreFromFile(url)
            }
        }
        .alert(t.t("restore_settings"), isPresented: $showRestoreConfirmation) {
            Button(t.t("common.cancel"), role: .cancel) {}
            Button(t.t("restore"), role: .destructive) {
                if let backup = selectedBackup {
                    restoreBackup(backup)
                }
            }
        } message: {
            Text(t.t("restore_settings_confirm"))
        }
        .alert(t.t("error"), isPresented: $showError) {
            Button(t.t("common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert(t.t("success"), isPresented: $showSuccess) {
            Button(t.t("common.ok"), role: .cancel) {}
        } message: {
            Text(successMessage)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.DesignSystem.brandBlue, .DesignSystem.brandGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "externaldrive.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text(t.t("settings_backup"))
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            Text(t.t("backup_description"))
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

    // MARK: - Actions Section

    private var actionsSection: some View {
        GlassSettingsSection(title: t.t("actions"), icon: "gearshape.fill") {
            // Create backup
            Button {
                createBackup()
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.DesignSystem.brandGreen)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("create_backup"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.text)

                        Text(t.t("create_backup_description"))
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    Spacer()

                    if isCreatingBackup {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.DesignSystem.textTertiary)
                    }
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isCreatingBackup || isRestoringBackup)

            // Restore from file
            Button {
                showDocumentPicker = true
            } label: {
                HStack(spacing: Spacing.md) {
                    Image(systemName: "square.and.arrow.down.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.DesignSystem.brandBlue)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(t.t("restore_from_file"))
                            .font(.DesignSystem.bodyMedium)
                            .foregroundStyle(Color.DesignSystem.text)

                        Text(t.t("restore_from_file_description"))
                            .font(.DesignSystem.caption)
                            .foregroundStyle(Color.DesignSystem.textSecondary)
                    }

                    Spacer()

                    if isRestoringBackup {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.DesignSystem.textTertiary)
                    }
                }
                .padding(Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isCreatingBackup || isRestoringBackup)
        }
    }

    // MARK: - Recent Backups Section

    private var recentBackupsSection: some View {
        GlassSettingsSection(title: t.t("recent_backups"), icon: "clock.fill") {
            ForEach(backups, id: \.absoluteString) { backup in
                backupRow(for: backup)
            }
        }
    }

    private func backupRow(for url: URL) -> some View {
        let filename = url.lastPathComponent
        let date = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate

        return HStack(spacing: Spacing.md) {
            Image(systemName: "doc.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color.DesignSystem.brandTeal)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(filename)
                    .font(.DesignSystem.bodySmall)
                    .foregroundStyle(Color.DesignSystem.text)
                    .lineLimit(1)

                if let date {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }
            }

            Spacer()

            // Restore button
            Button {
                selectedBackup = url
                showRestoreConfirmation = true
            } label: {
                Text(t.t("restore"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.brandGreen)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: CornerRadius.small)
                            .fill(Color.DesignSystem.brandGreen.opacity(0.15))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                Text(t.t("backup_info_title"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Text(t.t("backup_info_description"))
                .font(.DesignSystem.caption)
                .foregroundStyle(Color.DesignSystem.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .fill(Color.DesignSystem.brandBlue.opacity(0.1))
        )
    }

    // MARK: - Actions

    private func loadBackups() {
        Task {
            let urls = await SettingsBackupService.shared.listBackups()
            await MainActor.run {
                backups = Array(urls.prefix(5))
            }
        }
    }

    private func createBackup() {
        isCreatingBackup = true

        Task {
            do {
                let url = try await SettingsBackupService.shared.createBackup()

                await MainActor.run {
                    exportedFileURL = url
                    isCreatingBackup = false
                    showShareSheet = true
                    loadBackups()
                    HapticManager.success()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isCreatingBackup = false
                    showError = true
                    HapticManager.error()
                }
            }
        }
    }

    private func restoreBackup(_ url: URL) {
        isRestoringBackup = true

        Task {
            do {
                try await SettingsBackupService.shared.restoreBackup(from: url)

                await MainActor.run {
                    successMessage = t.t("settings_restored_successfully")
                    isRestoringBackup = false
                    showSuccess = true
                    HapticManager.success()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRestoringBackup = false
                    showError = true
                    HapticManager.error()
                }
            }
        }
    }

    private func restoreFromFile(_ url: URL) {
        selectedBackup = url
        showRestoreConfirmation = true
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    let types: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsBackupView()
    }
}
