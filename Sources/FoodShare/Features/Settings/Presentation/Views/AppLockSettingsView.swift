//
//  AppLockSettingsView.swift
//  Foodshare
//
//  Settings view for configuring app lock with biometric authentication
//

import SwiftUI
import FoodShareDesignSystem

struct AppLockSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.translationService) private var t

    @State private var appLockService = AppLockService.shared
    @State private var showEnableConfirmation = false
    @State private var showDisableConfirmation = false
    @State private var isProcessing = false

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Header with biometric icon
                headerSection

                // Main toggle section
                mainToggleSection

                // Options section (only shown when enabled)
                if appLockService.isEnabled {
                    optionsSection
                }

                // Info section
                infoSection
            }
            .padding(Spacing.md)
        }
        .background(Color.DesignSystem.background)
        .navigationTitle(t.t("app_lock"))
        .navigationBarTitleDisplayMode(.large)
        .alert(t.t("enable_app_lock"), isPresented: $showEnableConfirmation) {
            Button(t.t("common.cancel"), role: .cancel) {}
            Button(t.t("enable")) {
                enableAppLock()
            }
        } message: {
            Text(t.t("enable_app_lock_message", args: ["biometric": appLockService.biometricDisplayName]))
        }
        .alert(t.t("disable_app_lock"), isPresented: $showDisableConfirmation) {
            Button(t.t("common.cancel"), role: .cancel) {}
            Button(t.t("disable"), role: .destructive) {
                appLockService.disable()
                HapticManager.success()
            }
        } message: {
            Text(t.t("disable_app_lock_message"))
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: Spacing.md) {
            // Biometric icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.DesignSystem.brandBlue, .DesignSystem.brandTeal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: appLockService.biometricIconName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
            }

            Text(appLockService.biometricDisplayName)
                .font(.DesignSystem.headlineMedium)
                .foregroundStyle(Color.DesignSystem.text)

            if appLockService.isBiometricAvailable {
                Text(t.t("biometric_available"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.success)
            } else {
                Text(t.t("biometric_not_available"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.error)
            }
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

    // MARK: - Main Toggle Section

    private var mainToggleSection: some View {
        GlassSettingsSection(title: t.t("security"), icon: "lock.shield.fill") {
            HStack(spacing: Spacing.md) {
                Image(systemName: appLockService.biometricIconName)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.DesignSystem.brandBlue)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(t.t("require_biometric", args: ["biometric": appLockService.biometricDisplayName]))
                        .font(.DesignSystem.bodyMedium)
                        .foregroundStyle(Color.DesignSystem.text)

                    Text(t.t("unlock_app_description"))
                        .font(.DesignSystem.caption)
                        .foregroundStyle(Color.DesignSystem.textSecondary)
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Toggle("", isOn: Binding(
                        get: { appLockService.isEnabled },
                        set: { newValue in
                            if newValue {
                                showEnableConfirmation = true
                            } else {
                                showDisableConfirmation = true
                            }
                        }
                    ))
                    .tint(.DesignSystem.brandGreen)
                    .labelsHidden()
                    .disabled(!appLockService.isBiometricAvailable)
                    .sensoryFeedback(.selection, trigger: appLockService.isEnabled)
                }
            }
            .padding(Spacing.md)
        }
    }

    // MARK: - Options Section

    private var optionsSection: some View {
        GlassSettingsSection(title: t.t("options"), icon: "gearshape.fill") {
            // Lock on background
            GlassSettingsToggle(
                icon: "rectangle.portrait.and.arrow.right",
                iconColor: .DesignSystem.accentOrange,
                title: t.t("lock_on_background"),
                isOn: $appLockService.lockOnBackground
            )
            .sensoryFeedback(.selection, trigger: appLockService.lockOnBackground)

            // Lock on launch
            GlassSettingsToggle(
                icon: "power",
                iconColor: .DesignSystem.brandGreen,
                title: t.t("lock_on_launch"),
                isOn: $appLockService.lockOnLaunch
            )
            .sensoryFeedback(.selection, trigger: appLockService.lockOnLaunch)

            // Lock delay
            HStack(spacing: Spacing.md) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.DesignSystem.brandTeal)
                    .frame(width: 28)

                Text(t.t("lock_delay"))
                    .font(.DesignSystem.bodyMedium)
                    .foregroundStyle(Color.DesignSystem.text)

                Spacer()

                Picker("", selection: $appLockService.lockDelay) {
                    ForEach(LockDelayOption.options) { option in
                        Text(option.displayName).tag(option.seconds)
                    }
                }
                .pickerStyle(.menu)
                .tint(.DesignSystem.brandGreen)
            }
            .padding(Spacing.md)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Color.DesignSystem.textSecondary)
                Text(t.t("app_lock_info_title"))
                    .font(.DesignSystem.caption)
                    .foregroundStyle(Color.DesignSystem.textSecondary)
            }

            Text(t.t("app_lock_info_description"))
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

    private func enableAppLock() {
        isProcessing = true

        Task {
            let success = await appLockService.enable()

            isProcessing = false

            if success {
                HapticManager.success()
            } else {
                HapticManager.error()
            }
        }
    }
}

#Preview {
    NavigationStack {
        AppLockSettingsView()
    }
}
